package db

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

type rowReader interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

// RejectDevelopmentData fails closed before production serves any requests.
// Fixture databases are disposable; never promote them into production.
func RejectDevelopmentData(ctx context.Context, reader rowReader) error {
	var present bool
	if err := reader.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM app_settings WHERE key='development_fixture_batch')`).Scan(&present); err != nil {
		return fmt.Errorf("cannot verify database data origin: %w", err)
	}
	if present {
		return errors.New("production cannot use a database containing development fixtures")
	}
	return nil
}
