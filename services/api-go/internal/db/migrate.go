package db

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

const initialMigration = "0001_initial.sql"

func ApplyMigrations(ctx context.Context, pool *pgxpool.Pool, directory string) error {
	if _, err := pool.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return fmt.Errorf("create migration ledger: %w", err)
	}
	path := filepath.Join(directory, initialMigration)
	contents, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read migration %s: %w", path, err)
	}
	sum := sha256.Sum256(contents)
	checksum := hex.EncodeToString(sum[:])
	var recorded string
	err = pool.QueryRow(ctx, `SELECT checksum FROM schema_migrations WHERE name=$1`, initialMigration).Scan(&recorded)
	if err == nil {
		if recorded != checksum {
			return fmt.Errorf("migration %s checksum changed after application", initialMigration)
		}
		return nil
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	for _, statement := range SplitMigration(string(contents)) {
		if _, err := tx.Exec(ctx, statement); err != nil {
			return fmt.Errorf("apply %s: %w", initialMigration, err)
		}
	}
	if _, err := tx.Exec(ctx, `INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)`, initialMigration, checksum); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func SplitMigration(contents string) []string {
	raw := strings.Split(contents, "-- statement-breakpoint")
	statements := make([]string, 0, len(raw))
	for _, statement := range raw {
		if trimmed := strings.TrimSpace(statement); trimmed != "" {
			statements = append(statements, trimmed)
		}
	}
	return statements
}
