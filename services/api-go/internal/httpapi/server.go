package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"fitcalgary.ca/index/api/internal/auth"
	"fitcalgary.ca/index/api/internal/config"
	"fitcalgary.ca/index/api/internal/security"
	"fitcalgary.ca/index/api/internal/storage"
)

type Server struct {
	db       Database
	verifier auth.Verifier
	store    storage.EvidenceStore
	config   config.Config
	logger   *slog.Logger
	cipher   *security.TokenCipher
}

type Database interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
	Begin(context.Context) (pgx.Tx, error)
	Ping(context.Context) error
}

type requestIdentity struct {
	Principal auth.Principal
	ProfileID string
}

type contextKey int

const identityKey contextKey = iota

type APIError struct {
	Status  int
	Code    string
	Message string
	Details any
}

func (e *APIError) Error() string { return e.Message }

func NewServer(db Database, verifier auth.Verifier, store storage.EvidenceStore, cipher *security.TokenCipher, cfg config.Config, logger *slog.Logger) *Server {
	return &Server{db: db, verifier: verifier, store: store, cipher: cipher, config: cfg, logger: logger}
}

func (s *Server) Router() http.Handler {
	router := chi.NewRouter()
	router.Use(middleware.RequestID, middleware.RealIP, middleware.Recoverer)
	router.Use(s.securityHeaders, s.cors, s.accessLog)
	router.Use(s.productMetrics)
	router.Get("/health", s.handle(func(w http.ResponseWriter, _ *http.Request) (any, error) {
		return map[string]any{"status": "ok", "service": "fitcalgary-api-go"}, nil
	}))
	router.Get("/ready", s.handleReady)

	router.Route("/api/v1", func(v1 chi.Router) {
		s.registerPublicRoutes(v1)
		v1.Group(func(protected chi.Router) {
			protected.Use(s.authenticate, s.accountBudget)
			s.registerAccountRoutes(protected)
			s.registerSubmissionRoutes(protected)
			s.registerJudgeRoutes(protected)
			s.registerAdminRoutes(protected)
		})
	})
	return router
}

type handler func(http.ResponseWriter, *http.Request) (any, error)

func (s *Server) handle(next handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		payload, err := next(w, r)
		if err != nil {
			s.writeError(w, r, err)
			return
		}
		if payload == nil || w.Header().Get("X-FitCalgary-Response-Written") == "true" {
			return
		}
		writeJSON(w, http.StatusOK, payload)
	}
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.db.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *Server) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, ok := auth.Bearer(r.Header.Get("Authorization"))
		if !ok {
			s.writeError(w, r, &APIError{Status: http.StatusUnauthorized, Code: "UNAUTHENTICATED", Message: "Authentication required"})
			return
		}
		principal, err := s.verifier.Verify(r.Context(), raw)
		if err != nil {
			s.writeError(w, r, &APIError{Status: http.StatusUnauthorized, Code: "INVALID_TOKEN", Message: "Access token is invalid or expired"})
			return
		}
		name := strings.TrimSpace(principal.Username)
		if name == "" && principal.Email != "" {
			name = strings.Split(principal.Email, "@")[0]
		}
		if name == "" {
			name = "Athlete"
		}
		var profileID, status string
		if err := s.db.QueryRow(r.Context(), `INSERT INTO profiles(keycloak_subject,email,display_name) VALUES($1,NULLIF($2,''),$3) ON CONFLICT(keycloak_subject) DO UPDATE SET email=COALESCE(EXCLUDED.email,profiles.email),updated_at=now() RETURNING id,account_status`, principal.Subject, principal.Email, name).Scan(&profileID, &status); err != nil {
			s.writeError(w, r, err)
			return
		}
		if status != "ACTIVE" {
			s.writeError(w, r, &APIError{Status: http.StatusForbidden, Code: "ACCOUNT_RESTRICTED", Message: "Account is restricted"})
			return
		}
		rows, err := s.db.Query(r.Context(), `SELECT role FROM user_roles WHERE profile_id=$1`, profileID)
		if err != nil {
			s.writeError(w, r, err)
			return
		}
		stored, err := pgx.CollectRows(rows, pgx.RowTo[string])
		if err != nil {
			s.writeError(w, r, err)
			return
		}
		roleNames := make([]string, 0, len(principal.Roles)+len(stored))
		for _, role := range principal.Roles {
			roleNames = append(roleNames, string(role))
		}
		roleNames = append(roleNames, stored...)
		principal.Roles = auth.ClaimsRoles(roleNames)
		restrictionRows, err := s.db.Query(r.Context(), `SELECT role FROM user_role_restrictions WHERE profile_id=$1`, profileID)
		if err != nil {
			s.writeError(w, r, err)
			return
		}
		restricted, err := pgx.CollectRows(restrictionRows, pgx.RowTo[string])
		if err != nil {
			s.writeError(w, r, err)
			return
		}
		denied := map[auth.Role]bool{}
		for _, role := range restricted {
			denied[auth.Role(role)] = true
		}
		effective := make([]auth.Role, 0, len(principal.Roles))
		for _, role := range principal.Roles {
			if !denied[role] {
				effective = append(effective, role)
			}
		}
		principal.Roles = effective
		identity := requestIdentity{Principal: principal, ProfileID: profileID}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), identityKey, identity)))
	})
}

func identity(r *http.Request) requestIdentity {
	value, ok := r.Context().Value(identityKey).(requestIdentity)
	if !ok {
		panic("authenticated route has no request identity")
	}
	return value
}

func requireRole(r *http.Request, allowed ...auth.Role) error {
	if !identity(r).Principal.HasRole(allowed...) {
		return &APIError{Status: http.StatusForbidden, Code: "FORBIDDEN", Message: "You do not have permission for this operation"}
	}
	return nil
}

func decodeJSON(r *http.Request, target any) error {
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1_048_577))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return &APIError{Status: http.StatusUnprocessableEntity, Code: "VALIDATION_ERROR", Message: "Request body is invalid", Details: err.Error()}
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return &APIError{Status: http.StatusUnprocessableEntity, Code: "VALIDATION_ERROR", Message: "Request body must contain one JSON value"}
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func noContent(w http.ResponseWriter) {
	w.Header().Set("X-FitCalgary-Response-Written", "true")
	w.WriteHeader(http.StatusNoContent)
}

func created(w http.ResponseWriter, value any) {
	w.Header().Set("X-FitCalgary-Response-Written", "true")
	writeJSON(w, http.StatusCreated, value)
}

func accepted(w http.ResponseWriter, value any) {
	w.Header().Set("X-FitCalgary-Response-Written", "true")
	writeJSON(w, http.StatusAccepted, value)
}

func (s *Server) writeError(w http.ResponseWriter, r *http.Request, err error) {
	apiErr := &APIError{Status: http.StatusInternalServerError, Code: "INTERNAL_ERROR", Message: "An unexpected error occurred"}
	if errors.As(err, &apiErr) {
		// Preserves safe, explicit API errors.
	} else if errors.Is(err, pgx.ErrNoRows) {
		apiErr = &APIError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "Resource not found"}
	} else {
		var constraint *pgconn.PgError
		if errors.As(err, &constraint) && constraint.Code == "23505" {
			apiErr = &APIError{Status: 409, Code: "ALREADY_EXISTS", Message: "A record with these identifiers already exists"}
		} else if errors.As(err, &constraint) && (constraint.Code == "23503" || constraint.Code == "23514") {
			apiErr = &APIError{Status: 422, Code: "INVALID_REFERENCE", Message: "The record references unavailable or invalid configuration"}
		} else {
			s.logger.Error("request failed", "request_id", middleware.GetReqID(r.Context()), "error", err)
		}
	}
	writeJSON(w, apiErr.Status, map[string]any{"error": map[string]any{"code": apiErr.Code, "message": apiErr.Message, "requestId": middleware.GetReqID(r.Context()), "details": apiErr.Details}})
}

func (s *Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && origin == s.config.WebPublicURL {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key, X-Request-ID")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) accessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Info("request", "method", r.Method, "path", r.URL.Path, "request_id", middleware.GetReqID(r.Context()), "duration_ms", time.Since(started).Milliseconds())
	})
}

func queryMaps(ctx context.Context, queryer interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, sql string, args ...any) ([]map[string]any, error) {
	rows, err := queryer.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	result, err := pgx.CollectRows(rows, pgx.RowToMap)
	if err != nil {
		return nil, err
	}
	for _, row := range result {
		for key, value := range row {
			row[key] = normalizeDatabaseValue(value)
		}
	}
	return result, nil
}

func normalizeDatabaseValue(value any) any {
	switch current := value.(type) {
	case [16]byte:
		return uuid.UUID(current).String()
	case []byte:
		if json.Valid(current) {
			var decoded any
			if json.Unmarshal(current, &decoded) == nil {
				return decoded
			}
		}
		return string(current)
	case map[string]any:
		for key, item := range current {
			current[key] = normalizeDatabaseValue(item)
		}
		return current
	case []any:
		for index, item := range current {
			current[index] = normalizeDatabaseValue(item)
		}
		return current
	default:
		return value
	}
}
