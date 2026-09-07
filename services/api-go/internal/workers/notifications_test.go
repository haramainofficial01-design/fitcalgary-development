package workers

import "testing"

func TestRenderPassedNotification(t *testing.T) {
	got, err := renderNotification(notificationPayload{Type: "LEADERBOARD_PASSED", LeaderboardID: "board", NewRank: 4, PassingAthleteDisplayName: "Alex"})
	if err != nil {
		t.Fatal(err)
	}
	if got.Body != "Alex moved ahead. You are now #4." || got.DeepLink != "fitcalgary://leaderboards/board" {
		t.Fatalf("unexpected notification: %#v", got)
	}
}

func TestRenderRejectsUnknownEvent(t *testing.T) {
	if _, err := renderNotification(notificationPayload{Type: "UNKNOWN"}); err == nil {
		t.Fatal("unknown notification events must not be silently delivered")
	}
}

func TestNotificationPreferences(t *testing.T) {
	preferences := []byte(`{"announcements":false,"eventUpdates":false}`)
	for _, kind := range []string{"SUBMISSION_RECEIVED", "SUBMISSION_APPROVED", "SUBMISSION_CHANGES_REQUESTED", "SUBMISSION_REJECTED"} {
		if !notificationAllowed(kind, preferences) {
			t.Fatal("essential result communication suppressed")
		}
	}
	for _, kind := range []string{"ADMIN_ANNOUNCEMENT", "EVENT_UPDATED"} {
		if notificationAllowed(kind, preferences) {
			t.Fatal("opt-out ignored")
		}
		if !notificationAllowed(kind, []byte(`{}`)) {
			t.Fatal("default preference lost")
		}
	}
	if _, err := renderNotification(notificationPayload{Type: "EVENT_UPDATED", Title: "Event changed", Body: "Check the details", EventID: "//unsafe"}); err == nil {
		t.Fatal("unsafe destination accepted")
	}
}
