// Command storage-configure applies the browser upload policy to the private
// evidence bucket. Credentials are supplied only through the deployment secret
// manager; the command never prints them.
package main

import (
	"context"
	"errors"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func required(name string) (string, error) {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return "", errors.New(name + " is required")
	}
	return value, nil
}

func run() error {
	endpoint, err := required("S3_ENDPOINT")
	if err != nil {
		return err
	}
	region, err := required("S3_REGION")
	if err != nil {
		return err
	}
	bucket, err := required("S3_BUCKET")
	if err != nil {
		return err
	}
	access, err := required("S3_ACCESS_KEY_ID")
	if err != nil {
		return err
	}
	secret, err := required("S3_SECRET_ACCESS_KEY")
	if err != nil {
		return err
	}
	origin, err := required("STORAGE_CORS_ORIGIN")
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	loaded, err := awsconfig.LoadDefaultConfig(ctx,
		awsconfig.WithRegion(region),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(access, secret, "")),
	)
	if err != nil {
		return err
	}
	client := s3.NewFromConfig(loaded, func(options *s3.Options) {
		options.BaseEndpoint = aws.String(endpoint)
		options.UsePathStyle = false
	})
	_, err = client.PutBucketCors(ctx, &s3.PutBucketCorsInput{
		Bucket: &bucket,
		CORSConfiguration: &types.CORSConfiguration{CORSRules: []types.CORSRule{{
			AllowedHeaders: []string{"*"},
			AllowedMethods: []string{"GET", "HEAD", "PUT"},
			AllowedOrigins: []string{origin},
			ExposeHeaders:  []string{"ETag"},
			MaxAgeSeconds:  aws.Int32(3600),
		}}},
	})
	if err != nil {
		return err
	}
	current, err := client.GetBucketCors(ctx, &s3.GetBucketCorsInput{Bucket: &bucket})
	if err != nil {
		return err
	}
	for _, rule := range current.CORSRules {
		if len(rule.AllowedOrigins) == 1 && rule.AllowedOrigins[0] == origin &&
			contains(rule.AllowedMethods, "PUT") && contains(rule.AllowedMethods, "GET") &&
			contains(rule.ExposeHeaders, "ETag") {
			return nil
		}
	}
	return errors.New("storage provider did not retain the required browser policy")
}

func contains(values []string, wanted string) bool {
	for _, value := range values {
		if value == wanted {
			return true
		}
	}
	return false
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
	log.Print("private evidence bucket browser policy configured")
}
