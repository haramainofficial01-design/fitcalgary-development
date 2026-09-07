package notifications

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFCMTransport(t *testing.T) {
	for _, c := range []struct {
		status         int
		body           string
		retry, invalid bool
	}{
		{200, `{"name":"projects/test/messages/1"}`, false, false},
		{503, `{"error":{}}`, true, false},
		{404, `{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}`, false, true},
		{400, `{"error":{}}`, false, false},
	} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "POST" || r.Header.Get("Content-Type") != "application/json" {
				t.Error("invalid transport")
			}
			var body map[string]map[string]any
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Error(err)
			}
			if body["message"]["token"] != "ephemeral-test-device" {
				t.Error("wrong recipient")
			}
			data := body["message"]["data"].(map[string]any)
			if data["deepLink"] != "fitcalgary://submissions/test" || len(data) != 2 {
				t.Error("unsafe or incomplete data payload")
			}
			w.WriteHeader(c.status)
			_, _ = w.Write([]byte(c.body))
		}))
		client := &FCM{client: server.Client(), endpoint: server.URL}
		result := client.Send(context.Background(), "ephemeral-test-device", Message{ID: "notification-id", Title: "Result verified", Body: "View your result", DeepLink: "fitcalgary://submissions/test"})
		server.Close()
		if result.Retry != c.retry || result.InvalidToken != c.invalid {
			t.Fatalf("wrong error handling: %+v", result)
		}
		if c.status == 200 && result.MessageID == "" {
			t.Fatal("success missing provider ID")
		}
	}
}
