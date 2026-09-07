package workers

import (
	"context"
	"fitcalgary.ca/index/api/internal/notifications"
	"fitcalgary.ca/index/api/internal/security"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"log/slog"
	"time"
)

func RunPushDelivery(ctx context.Context, pool *pgxpool.Pool, sender notifications.Sender, cipher *security.TokenCipher, logger *slog.Logger) {
	if sender == nil || cipher == nil {
		return
	}
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		for i := 0; i < 25; i++ {
			worked, err := processPush(ctx, pool, sender, cipher)
			if err != nil {
				logger.Error("push delivery pass failed")
				break
			}
			if !worked {
				break
			}
		}
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func processPush(ctx context.Context, pool *pgxpool.Pool, sender notifications.Sender, cipher *security.TokenCipher) (bool, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)
	// Lock and fan out each queued notification once. No device or provider secret
	// is copied to job payloads. An inbox entry survives all push failures.
	var queued string
	err = tx.QueryRow(ctx, `SELECT id FROM notifications WHERE delivery_status='QUEUED' ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1`).Scan(&queued)
	if err != nil && err != pgx.ErrNoRows {
		return false, err
	}
	if err == nil {
		tag, err := tx.Exec(ctx, `INSERT INTO notification_deliveries(notification_id,device_id) SELECT n.id,d.id FROM notifications n JOIN notification_devices d ON d.profile_id=n.profile_id AND d.enabled WHERE n.id=$1 ON CONFLICT DO NOTHING`, queued)
		if err != nil {
			return false, err
		}
		state := "SENDING"
		if tag.RowsAffected() == 0 {
			state = "SUPPRESSED"
		}
		if _, err := tx.Exec(ctx, `UPDATE notifications SET delivery_status=$2 WHERE id=$1`, queued, state); err != nil {
			return false, err
		}
	}
	var notificationID, deviceID, encrypted, kind, accountStatus string
	var enabled bool
	var preferences []byte
	var attempts int
	var message notifications.Message
	err = tx.QueryRow(ctx, `SELECT nd.notification_id,nd.device_id,nd.attempt_count,d.encrypted_token,(d.enabled AND d.profile_id=n.profile_id),n.type,p.account_status,p.notification_preferences,n.title,n.body,n.deep_link FROM notification_deliveries nd JOIN notifications n ON n.id=nd.notification_id JOIN notification_devices d ON d.id=nd.device_id JOIN profiles p ON p.id=n.profile_id WHERE nd.status='QUEUED' AND nd.available_at<=now() ORDER BY nd.available_at FOR UPDATE OF nd SKIP LOCKED LIMIT 1`).Scan(&notificationID, &deviceID, &attempts, &encrypted, &enabled, &kind, &accountStatus, &preferences, &message.Title, &message.Body, &message.DeepLink)
	if err == pgx.ErrNoRows {
		return queued != "", tx.Commit(ctx)
	}
	if err != nil {
		return false, err
	}
	message.ID = notificationID
	state, code, provider := "SUPPRESSED", "", ""
	retry := false
	if enabled && accountStatus == "ACTIVE" && notificationAllowed(kind, preferences) {
		token, err := cipher.Decrypt(encrypted)
		if err != nil {
			state = "FAILED"
			code = "TOKEN_UNREADABLE"
		} else {
			result := sender.Send(ctx, token, message)
			provider = result.MessageID
			code = result.Code
			if provider != "" {
				state = "DELIVERED"
			} else {
				state = "FAILED"
				retry = result.Retry && attempts < 4
				if retry {
					state = "QUEUED"
				}
			}
			if result.InvalidToken {
				if _, err := tx.Exec(ctx, `UPDATE notification_devices SET enabled=false,invalidated_at=now() WHERE id=$1`, deviceID); err != nil {
					return false, err
				}
			}
		}
	}
	delay := time.Duration(1<<min(attempts, 6)) * time.Minute
	if _, err := tx.Exec(ctx, `UPDATE notification_deliveries SET status=$3,attempt_count=attempt_count+1,available_at=$4,provider_message_id=NULLIF($5,''),last_error_code=NULLIF($6,''),delivered_at=CASE WHEN $3='DELIVERED' THEN now() ELSE NULL END WHERE notification_id=$1 AND device_id=$2`, notificationID, deviceID, state, time.Now().Add(delay), provider, code); err != nil {
		return false, err
	}
	if _, err := tx.Exec(ctx, `UPDATE notifications SET delivery_status=CASE WHEN EXISTS(SELECT 1 FROM notification_deliveries WHERE notification_id=$1 AND status='QUEUED') THEN 'SENDING' WHEN EXISTS(SELECT 1 FROM notification_deliveries WHERE notification_id=$1 AND status='DELIVERED') THEN 'DELIVERED' WHEN EXISTS(SELECT 1 FROM notification_deliveries WHERE notification_id=$1 AND status='FAILED') THEN 'FAILED' ELSE 'SUPPRESSED' END,attempt_count=attempt_count+1,last_error_code=NULLIF($2,''),sent_at=CASE WHEN $3='DELIVERED' THEN now() ELSE sent_at END WHERE id=$1`, notificationID, code, state); err != nil {
		return false, err
	}
	return true, tx.Commit(ctx)
}
