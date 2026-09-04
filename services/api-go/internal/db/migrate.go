package db

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var migrationName = regexp.MustCompile(`^[0-9]{4}_[a-z0-9_]+\.sql$`)

func ApplyMigrations(ctx context.Context, pool *pgxpool.Pool, directory string) error {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return fmt.Errorf("read migration directory: %w", err)
	}
	names := []string{}
	for _, entry := range entries {
		if !entry.IsDir() && migrationName.MatchString(entry.Name()) {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)
	if len(names) == 0 || names[0] != "0001_initial.sql" {
		return errors.New("initial migration is required")
	}
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	// Every service instance uses the same transaction-scoped lock. Ledger checks
	// and schema updates are serialized and commit together.
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(1179210819)`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return err
	}
	for _, name := range names {
		contents, err := os.ReadFile(filepath.Join(directory, name))
		if err != nil {
			return err
		}
		sum := sha256.Sum256(contents)
		checksum := hex.EncodeToString(sum[:])
		var recorded string
		err = tx.QueryRow(ctx, `SELECT checksum FROM schema_migrations WHERE name=$1`, name).Scan(&recorded)
		if err == nil {
			if recorded != checksum {
				return fmt.Errorf("migration %s checksum changed after application", name)
			}
			continue
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("read migration ledger: %w", err)
		}
		for _, statement := range SplitMigration(string(contents)) {
			if _, err = tx.Exec(ctx, statement); err != nil {
				return fmt.Errorf("apply %s: %w", name, err)
			}
		}
		if _, err = tx.Exec(ctx, `INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)`, name, checksum); err != nil {
			return err
		}
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
