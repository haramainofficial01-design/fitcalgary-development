package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"

	"github.com/pashagolub/pgxmock/v4"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	"fitcalgary.ca/index/api/internal/security"
)

const (
	testProfileID = "11111111-1111-4111-8111-111111111111"
	testDeviceID  = "22222222-2222-4222-8222-222222222222"
)

type testVerifier struct{ principal auth.Principal }

func (v testVerifier) Verify(context.Context, string) (auth.Principal, error) {
	return v.principal, nil
}

func newTestServer(t *testing.T) (*Server, pgxmock.PgxPoolIface) {
	t.Helper()
	database, err := pgxmock.NewPool()
	if err != nil {
		t.Fatal(err)
	}
	cipher, err := security.NewTokenCipher([]byte("0123456789abcdef0123456789abcdef"))
	if err != nil {
		t.Fatal(err)
	}
	server := NewServer(database, testVerifier{principal: auth.Principal{Subject: "keycloak-subject", Email: "athlete@example.ca", Username: "athlete", EmailVerified: true, Roles: []auth.Role{auth.RoleUser}}}, nil, cipher, config.Config{WebPublicURL: "http://localhost:3000"}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	return server, database
}

func expectAuthentication(database pgxmock.PgxPoolIface) {
	database.ExpectQuery(regexp.QuoteMeta(`INSERT INTO profiles(keycloak_subject,email,display_name) VALUES($1,NULLIF($2,''),$3) ON CONFLICT(keycloak_subject) DO UPDATE SET email=COALESCE(EXCLUDED.email,profiles.email),updated_at=now() RETURNING id,account_status`)).
		WithArgs("keycloak-subject", "athlete@example.ca", "athlete").
		WillReturnRows(pgxmock.NewRows([]string{"id", "account_status"}).AddRow(testProfileID, "ACTIVE"))
	database.ExpectQuery(regexp.QuoteMeta(`SELECT role FROM user_roles WHERE profile_id=$1`)).
		WithArgs(testProfileID).
		WillReturnRows(pgxmock.NewRows([]string{"role"}))
}

func TestProtectedRouteRejectsMissingBearerToken(t *testing.T) {
	server, database := newTestServer(t)
	defer database.Close()
	request := httptest.NewRequest(http.MethodGet, "/api/v1/profile", nil)
	recorder := httptest.NewRecorder()
	server.Router().ServeHTTP(recorder, request)
	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d: %s", recorder.Code, recorder.Body.String())
	}
}

func TestNotificationDeviceDeleteIsOwnerScoped(t *testing.T) {
	server, database := newTestServer(t)
	defer database.Close()
	expectAuthentication(database)
	database.ExpectExec(regexp.QuoteMeta(`DELETE FROM notification_devices WHERE id=$1 AND profile_id=$2`)).
		WithArgs(testDeviceID, testProfileID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/notification-devices/"+testDeviceID, nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	server.Router().ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("an unowned device must not be deleted; got %d: %s", recorder.Code, recorder.Body.String())
	}
	if err := database.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestProfileResponseIncludesEffectiveRoles(t *testing.T) {
	server, database := newTestServer(t)
	defer database.Close()
	expectAuthentication(database)
	database.ExpectQuery("SELECT p.id,p.username,p.display_name").
		WithArgs(testProfileID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "username", "display_name", "photo_url", "bio", "date_of_birth", "sex_category", "home_gym_id", "privacy", "created_at", "home_gym_name"}).
			AddRow(testProfileID, "athlete", "Athlete", nil, nil, nil, nil, nil, []byte(`{"publicProfile":true}`), nil, nil))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/profile", nil)
	request.Header.Set("Authorization", "Bearer token")
	recorder := httptest.NewRecorder()
	server.Router().ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", recorder.Code, recorder.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	roles, ok := body["roles"].([]any)
	if !ok || len(roles) != 1 || roles[0] != "USER" {
		t.Fatalf("expected effective roles in profile response, got %#v", body["roles"])
	}
	if err := database.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestNormalizeDatabaseValueSerializesUUIDAndJSON(t *testing.T) {
	rawUUID := [16]byte{0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x41, 0x11, 0x81, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11}
	if got := normalizeDatabaseValue(rawUUID); got != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("unexpected UUID representation: %#v", got)
	}
	jsonValue := normalizeDatabaseValue([]byte(`{"publicProfile":true}`))
	object, ok := jsonValue.(map[string]any)
	if !ok || object["publicProfile"] != true {
		t.Fatalf("unexpected JSON representation: %#v", jsonValue)
	}
}
