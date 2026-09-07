package workers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/google/uuid"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type notificationPayload struct {
	Type                      string `json:"type"`
	ProfileID                 string `json:"profileId"`
	SubmissionID              string `json:"submissionId"`
	LeaderboardID             string `json:"leaderboardId"`
	NewRank                   int    `json:"newRank"`
	PassingAthleteDisplayName string `json:"passingAthleteDisplayName"`
	Title                     string `json:"title"`
	Body                      string `json:"body"`
	EventID                   string `json:"eventId"`
}

type renderedNotification struct {
	Title    string
	Body     string
	DeepLink string
}

func RunNotificationOutbox(ctx context.Context, pool *pgxpool.Pool, logger *slog.Logger) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		for i := 0; i < 25; i++ {
			worked, err := processNotification(ctx, pool)
			if err != nil {
				logger.Error("notification outbox failed", "error", err)
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

func processNotification(ctx context.Context, pool *pgxpool.Pool) (bool, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	var id, dedupe string
	var raw []byte
	err = tx.QueryRow(ctx, `SELECT id,dedupe_key,payload FROM outbox_jobs WHERE job_type='NOTIFICATION' AND status IN ('PENDING','FAILED') AND attempt_count<5 AND available_at<=now() ORDER BY available_at,created_at FOR UPDATE SKIP LOCKED LIMIT 1`).Scan(&id, &dedupe, &raw)
	if err == pgx.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if _, err := tx.Exec(ctx, `UPDATE outbox_jobs SET status='PROCESSING',locked_at=now(),attempt_count=attempt_count+1 WHERE id=$1`, id); err != nil {
		return false, err
	}
	var payload notificationPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return false, markOutboxFailure(ctx, tx, id, "INVALID_PAYLOAD")
	}
	rendered, err := renderNotification(payload)
	if err != nil {
		return false, markOutboxFailure(ctx, tx, id, "UNSUPPORTED_NOTIFICATION")
	}
	var preferences []byte
	var status string
	if err := tx.QueryRow(ctx, `SELECT notification_preferences,account_status FROM profiles WHERE id=$1`, payload.ProfileID).Scan(&preferences, &status); err != nil {
		return false, markOutboxFailure(ctx, tx, id, "RECIPIENT_UNAVAILABLE")
	}
	if status == "ACTIVE" && notificationAllowed(payload.Type, preferences) {
		if _, err := tx.Exec(ctx, `INSERT INTO notifications(profile_id,type,title,body,deep_link,dedupe_key) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(profile_id,dedupe_key) DO NOTHING`, payload.ProfileID, payload.Type, rendered.Title, rendered.Body, rendered.DeepLink, dedupe); err != nil {
			return false, err
		}
	}
	if _, err := tx.Exec(ctx, `UPDATE outbox_jobs SET status='COMPLETE',completed_at=now(),locked_at=NULL,last_error=NULL WHERE id=$1`, id); err != nil {
		return false, err
	}
	return true, tx.Commit(ctx)
}

func markOutboxFailure(ctx context.Context, tx pgx.Tx, id, code string) error {
	if _, err := tx.Exec(ctx, `UPDATE outbox_jobs SET status='FAILED',available_at=now()+interval '15 minutes',locked_at=NULL,last_error=$2 WHERE id=$1`, id, code); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func renderNotification(payload notificationPayload) (renderedNotification, error) {
	switch payload.Type {
	case "ADMIN_ANNOUNCEMENT", "EVENT_UPDATED":
		if len(payload.Title) < 1 || len(payload.Title) > 100 || len(payload.Body) < 1 || len(payload.Body) > 1000 {
			return renderedNotification{}, errors.New("invalid message")
		}
		link := "fitcalgary://notifications"
		if payload.Type == "EVENT_UPDATED" {
			if _, err := uuid.Parse(payload.EventID); err != nil {
				return renderedNotification{}, errors.New("invalid event")
			}
			link = "fitcalgary://events/" + payload.EventID
		}
		return renderedNotification{Title: payload.Title, Body: payload.Body, DeepLink: link}, nil
	case "SUBMISSION_RECEIVED":
		return renderedNotification{Title: "Result received", Body: "Your evidence is in the review queue.", DeepLink: "fitcalgary://submissions/" + payload.SubmissionID}, nil
	case "SUBMISSION_APPROVED":
		return renderedNotification{Title: "Result verified", Body: "Your result is now on the leaderboard.", DeepLink: "fitcalgary://submissions/" + payload.SubmissionID}, nil
	case "SUBMISSION_REJECTED", "SUBMISSION_CHANGES_REQUESTED":
		return renderedNotification{Title: "Result needs attention", Body: "Review the judge's feedback in your submission.", DeepLink: "fitcalgary://submissions/" + payload.SubmissionID}, nil
	case "LEADERBOARD_PASSED":
		name := payload.PassingAthleteDisplayName
		if name == "" {
			name = "Another athlete"
		}
		return renderedNotification{Title: "Leaderboard update", Body: fmt.Sprintf("%s moved ahead. You are now #%d.", name, payload.NewRank), DeepLink: "fitcalgary://leaderboards/" + payload.LeaderboardID}, nil
	default:
		return renderedNotification{}, errors.New("unsupported notification type")
	}
}

func notificationAllowed(kind string, raw []byte) bool {
	var preferences map[string]bool
	if json.Unmarshal(raw, &preferences) != nil {
		return false
	}
	key := ""
	switch kind {
	case "ADMIN_ANNOUNCEMENT":
		key = "announcements"
	case "EVENT_UPDATED":
		key = "eventUpdates"
	}
	if key == "" {
		return true
	} // Submission/security communications are essential.
	allowed, present := preferences[key]
	return !present || allowed
}
