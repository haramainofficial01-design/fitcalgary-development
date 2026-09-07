package notifications

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"regexp"
	"time"

	"golang.org/x/oauth2/jwt"
)

type Message struct{ ID, Title, Body, DeepLink string }
type Result struct {
	MessageID, Code     string
	Retry, InvalidToken bool
}
type Sender interface {
	Send(context.Context, string, Message) Result
}
type FCM struct {
	client   *http.Client
	endpoint string
}

// FCM routes Apple registrations through APNs; all registered tokens for this
// adapter must be Firebase registration tokens, never raw APNs device tokens.
func NewFCM(ctx context.Context, project, email, privateKey string) (*FCM, error) {
	if !regexp.MustCompile(`^[a-z][a-z0-9-]{4,62}$`).MatchString(project) || email == "" || privateKey == "" {
		return nil, errors.New("complete Firebase service-account configuration is required")
	}
	credentials := jwt.Config{Email: email, PrivateKey: []byte(privateKey), Scopes: []string{"https://www.googleapis.com/auth/firebase.messaging"}, TokenURL: "https://oauth2.googleapis.com/token"}
	client := credentials.Client(ctx)
	client.Timeout = 15 * time.Second
	return &FCM{client: client, endpoint: "https://fcm.googleapis.com/v1/projects/" + project + "/messages:send"}, nil
}

func (f *FCM) Send(ctx context.Context, token string, message Message) Result {
	payload := map[string]any{"message": map[string]any{
		"token": token, "notification": map[string]string{"title": message.Title, "body": message.Body},
		"data":    map[string]string{"notificationId": message.ID, "deepLink": message.DeepLink},
		"android": map[string]any{"collapse_key": message.ID, "notification": map[string]string{"tag": message.ID}},
		"apns":    map[string]any{"headers": map[string]string{"apns-collapse-id": message.ID, "apns-priority": "10"}, "payload": map[string]any{"aps": map[string]string{"sound": "default"}}},
	}}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return Result{Code: "INVALID_MESSAGE"}
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, f.endpoint, bytes.NewReader(encoded))
	if err != nil {
		return Result{Code: "INVALID_CONFIGURATION"}
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := f.client.Do(request)
	if err != nil {
		return Result{Code: "PROVIDER_UNAVAILABLE", Retry: true}
	}
	defer response.Body.Close()
	var body struct {
		Name  string `json:"name"`
		Error struct {
			Details []struct {
				Code string `json:"errorCode"`
			} `json:"details"`
		} `json:"error"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&body); err != nil {
		return Result{Code: "INVALID_PROVIDER_RESPONSE", Retry: response.StatusCode >= 500}
	}
	if response.StatusCode >= 200 && response.StatusCode < 300 && body.Name != "" {
		return Result{MessageID: body.Name}
	}
	for _, detail := range body.Error.Details {
		if detail.Code == "UNREGISTERED" {
			return Result{Code: "TOKEN_UNREGISTERED", InvalidToken: true}
		}
	}
	if response.StatusCode == 429 || response.StatusCode >= 500 {
		return Result{Code: "PROVIDER_RETRY", Retry: true}
	}
	return Result{Code: "PROVIDER_REJECTED"}
}
