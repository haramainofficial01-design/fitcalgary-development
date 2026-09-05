package storage

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"

	"fitcalgary.ca/index/api/internal/config"
)

var safeObjectSegment = regexp.MustCompile(`[^a-zA-Z0-9_-]`)

type CompletedPart struct {
	ETag       string `json:"ETag"`
	PartNumber int32  `json:"PartNumber"`
}

type EvidenceStore interface {
	Begin(context.Context, string, string, string, int64) (key, uploadID string, err error)
	SignPart(context.Context, string, string, int32) (string, error)
	Complete(context.Context, string, string, []CompletedPart) (int64, error)
	PlaybackURL(context.Context, string) (string, error)
	Delete(context.Context, string) error
}

type S3EvidenceStore struct {
	client    *s3.Client
	presigner *s3.PresignClient
	bucket    string
	ttl       time.Duration
	maxBytes  int64
}

func NewS3EvidenceStore(ctx context.Context, cfg config.Config) (*S3EvidenceStore, error) {
	loaded, err := awsconfig.LoadDefaultConfig(ctx,
		awsconfig.WithRegion(cfg.S3Region),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(cfg.S3AccessKeyID, cfg.S3SecretAccessKey, "")),
	)
	if err != nil {
		return nil, err
	}
	client := s3.NewFromConfig(loaded, func(options *s3.Options) {
		options.BaseEndpoint = aws.String(cfg.S3Endpoint)
		options.UsePathStyle = true
	})
	return &S3EvidenceStore{client: client, presigner: s3.NewPresignClient(client), bucket: cfg.S3Bucket, ttl: cfg.SignedURLTTL, maxBytes: cfg.MaxEvidenceBytes}, nil
}

func (s *S3EvidenceStore) validate(contentType string, size int64) error {
	allowed := map[string]bool{"video/mp4": true, "video/quicktime": true, "video/webm": true, "application/gpx+xml": true, "image/jpeg": true, "image/png": true}
	if !allowed[contentType] {
		return errors.New("unsupported evidence content type")
	}
	if size < 1 || size > s.maxBytes {
		return errors.New("evidence size is outside the configured limit")
	}
	return nil
}

func (s *S3EvidenceStore) Begin(ctx context.Context, owner, submissionID, contentType string, size int64) (string, string, error) {
	if err := s.validate(contentType, size); err != nil {
		return "", "", err
	}
	identifier, err := randomID()
	if err != nil {
		return "", "", err
	}
	key := fmt.Sprintf("evidence/%s/%s/%s", safeObjectSegment.ReplaceAllString(owner, "_"), submissionID, identifier)
	created, err := s.client.CreateMultipartUpload(ctx, &s3.CreateMultipartUploadInput{Bucket: &s.bucket, Key: &key, ContentType: &contentType, Metadata: map[string]string{"submission": submissionID}})
	if err != nil {
		return "", "", err
	}
	if created.UploadId == nil {
		return "", "", errors.New("storage provider did not return an upload id")
	}
	return key, *created.UploadId, nil
}

func (s *S3EvidenceStore) SignPart(ctx context.Context, key, uploadID string, part int32) (string, error) {
	if part < 1 || part > 10_000 {
		return "", errors.New("invalid multipart part number")
	}
	result, err := s.presigner.PresignUploadPart(ctx, &s3.UploadPartInput{Bucket: &s.bucket, Key: &key, UploadId: &uploadID, PartNumber: &part}, func(options *s3.PresignOptions) { options.Expires = s.ttl })
	if err != nil {
		return "", err
	}
	return result.URL, nil
}

func (s *S3EvidenceStore) Complete(ctx context.Context, key, uploadID string, completed []CompletedPart) (int64, error) {
	parts := make([]types.CompletedPart, 0, len(completed))
	for _, part := range completed {
		parts = append(parts, types.CompletedPart{ETag: &part.ETag, PartNumber: &part.PartNumber})
	}
	if _, err := s.client.CompleteMultipartUpload(ctx, &s3.CompleteMultipartUploadInput{Bucket: &s.bucket, Key: &key, UploadId: &uploadID, MultipartUpload: &types.CompletedMultipartUpload{Parts: parts}}); err != nil {
		return 0, err
	}
	head, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{Bucket: &s.bucket, Key: &key})
	if err != nil {
		return 0, err
	}
	return aws.ToInt64(head.ContentLength), nil
}

func (s *S3EvidenceStore) PlaybackURL(ctx context.Context, key string) (string, error) {
	result, err := s.presigner.PresignGetObject(ctx, &s3.GetObjectInput{Bucket: &s.bucket, Key: &key}, func(options *s3.PresignOptions) { options.Expires = s.ttl })
	if err != nil {
		return "", err
	}
	return result.URL, nil
}

func (s *S3EvidenceStore) Delete(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &s.bucket, Key: &key})
	return err
}

func randomID() (string, error) {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		return "", err
	}
	return hex.EncodeToString(value), nil
}
