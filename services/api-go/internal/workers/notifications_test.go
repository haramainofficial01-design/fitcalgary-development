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
