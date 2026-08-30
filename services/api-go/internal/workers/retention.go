package workers

import (
	"context"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"fitcalgary.ca/index/api/internal/storage"
)

func RunEvidenceRetention(ctx context.Context, pool *pgxpool.Pool, store storage.EvidenceStore, logger *slog.Logger) {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop()
	for {
		if err := deleteExpiredEvidence(ctx, pool, store); err != nil {
			logger.Error("evidence retention pass failed", "error", err)
		}
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func deleteExpiredEvidence(ctx context.Context, pool *pgxpool.Pool, store storage.EvidenceStore) error {
	rows, err := pool.Query(ctx, `SELECT id,submission_id,storage_key FROM submission_evidence WHERE evidence_deleted_at IS NULL AND retain_until<=now() ORDER BY retain_until LIMIT 100`)
	if err != nil {
		return err
	}
	type expired struct{ id, submissionID, key string }
	items := make([]expired, 0, 100)
	for rows.Next() {
		var item expired
		if err := rows.Scan(&item.id, &item.submissionID, &item.key); err != nil {
			rows.Close()
			return err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return err
	}
	rows.Close()
	for _, item := range items {
		if err := store.Delete(ctx, item.key); err != nil {
			return err
		}
		tx, err := pool.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `UPDATE submission_evidence SET evidence_deleted_at=now() WHERE id=$1 AND evidence_deleted_at IS NULL`, item.id); err != nil {
			tx.Rollback(ctx) //nolint:errcheck
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO audit_logs(action,entity_type,entity_id,metadata) VALUES('EVIDENCE_DELETED_RETENTION','SUBMISSION',$1,$2)`, item.submissionID, map[string]any{"evidenceId": item.id}); err != nil {
			tx.Rollback(ctx) //nolint:errcheck
			return err
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
	}
	return nil
}
