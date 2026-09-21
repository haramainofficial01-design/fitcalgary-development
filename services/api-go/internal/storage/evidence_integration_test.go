package storage

import (
	"bytes"
	"context"
	"crypto/rand"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"fitcalgary.ca/index/api/internal/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// Real compatible storage is required. This checks transport/privacy, not video codecs.
func TestPrivateMultipartStorage(t *testing.T) {
	endpoint := os.Getenv("STORAGE_TEST_ENDPOINT")
	if endpoint == "" {
		t.Skip("requires isolated loopback S3-compatible storage")
	}
	parsed, err := url.Parse(endpoint)
	if err != nil || parsed.Scheme == "" || parsed.Hostname() == "" {
		t.Fatal("valid storage endpoint required")
	}
	remote := parsed.Hostname() != "127.0.0.1"
	if remote && os.Getenv("STORAGE_TEST_ALLOW_REMOTE") != "true" {
		t.Skip("remote storage smoke test requires STORAGE_TEST_ALLOW_REMOTE=true")
	}
	usePathStyle, err := strconv.ParseBool(valueOrDefault(os.Getenv("STORAGE_TEST_USE_PATH_STYLE"), "true"))
	if err != nil {
		t.Fatal("STORAGE_TEST_USE_PATH_STYLE must be true or false")
	}
	bucket := valueOrDefault(os.Getenv("STORAGE_TEST_BUCKET"), "fitcalgary-evidence-test")
	region := valueOrDefault(os.Getenv("STORAGE_TEST_REGION"), "us-east-1")
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	store, err := NewS3EvidenceStore(ctx, config.Config{S3Endpoint: endpoint, S3Region: region, S3Bucket: bucket, S3AccessKeyID: os.Getenv("STORAGE_TEST_ACCESS_KEY"), S3SecretAccessKey: os.Getenv("STORAGE_TEST_SECRET_KEY"), S3UsePathStyle: usePathStyle, SignedURLTTL: time.Minute, MaxEvidenceBytes: 10 << 20})
	if err != nil {
		t.Fatal(err)
	}
	if !remote {
		if _, err := store.client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &store.bucket}); err != nil {
			if _, headErr := store.client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &store.bucket}); headErr != nil {
				t.Fatal("test bucket unavailable")
			}
		}
	} else if _, err := store.client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &store.bucket}); err != nil {
		t.Fatal("configured remote test bucket unavailable")
	}
	content := make([]byte, 7<<20)
	if _, err := rand.Read(content); err != nil {
		t.Fatal(err)
	}
	key, upload, err := store.Begin(ctx, "transport-test", "submission-test", "video/mp4", int64(len(content)))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Delete(context.Background(), key)
	completed := []CompletedPart{}
	client := &http.Client{Timeout: 15 * time.Second}
	for i, data := range [][]byte{content[:6<<20], content[6<<20:]} {
		signed, err := store.SignPart(ctx, key, upload, int32(i+1))
		if err != nil {
			t.Fatal(err)
		}
		request, _ := http.NewRequestWithContext(ctx, http.MethodPut, signed, bytes.NewReader(data))
		response, err := client.Do(request)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
		if response.StatusCode != 200 || response.Header.Get("ETag") == "" {
			t.Fatalf("part upload status %d", response.StatusCode)
		}
		completed = append(completed, CompletedPart{PartNumber: int32(i + 1), ETag: response.Header.Get("ETag")})
	}
	size, err := store.Complete(ctx, key, upload, completed)
	if err != nil {
		t.Fatal(err)
	}
	if size != int64(len(content)) {
		t.Fatal("stored length differs")
	}
	// Simulate retry after storage succeeded but the application did not commit.
	if repeated, err := store.Complete(ctx, key, upload, completed); err != nil || repeated != size {
		t.Fatal("completed upload retry did not recover the persisted object")
	}
	signed, err := store.PlaybackURL(ctx, key)
	if err != nil {
		t.Fatal(err)
	}
	response, err := client.Get(signed)
	if err != nil {
		t.Fatal(err)
	}
	actual, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil || !bytes.Equal(actual, content) {
		t.Fatal("stored bytes differ")
	}
	unsigned, err := url.Parse(signed)
	if err != nil {
		t.Fatal(err)
	}
	unsigned.RawQuery = ""
	public := unsigned.String()
	response, err = client.Get(public)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 403 {
		t.Fatalf("unsigned object access was not rejected: %d", response.StatusCode)
	}
	tampered, _ := url.Parse(signed)
	q := tampered.Query()
	q.Set("X-Amz-Signature", strings.Repeat("0", 64))
	tampered.RawQuery = q.Encode()
	response, err = client.Get(tampered.String())
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 403 {
		t.Fatalf("tampered signature was not rejected: %d", response.StatusCode)
	}
	request, _ := http.NewRequestWithContext(ctx, http.MethodGet, signed, nil)
	request.Header.Set("Range", "bytes=0-255")
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	part, _ := io.ReadAll(response.Body)
	response.Body.Close()
	if response.StatusCode != 206 || !bytes.Equal(part, content[:256]) {
		t.Fatal("private playback range failed")
	}
	if err := store.Delete(ctx, key); err != nil {
		t.Fatal(err)
	}
	response, err = client.Get(signed)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 404 {
		t.Fatalf("deleted evidence remains available: %d", response.StatusCode)
	}
	t.Log("7 MiB, two real signed parts, exact bytes, unsigned/tampered rejection, range playback and deletion verified")
}

func valueOrDefault(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}
