package httpapi

import (
	"github.com/go-chi/chi/v5"
	"net/http"
)

func (s *Server) openNotification(w http.ResponseWriter, r *http.Request) (any, error) {
	id := chi.URLParam(r, "id")
	if !validUUID(id) {
		return nil, validation("Invalid notification ID")
	}
	tag, err := s.db.Exec(r.Context(), `UPDATE notifications SET opened_at=COALESCE(opened_at,now()) WHERE id=$1 AND profile_id=$2`, id, identity(r).ProfileID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() != 1 {
		return nil, &APIError{Status: 404, Code: "NOT_FOUND", Message: "Notification not found"}
	}
	noContent(w)
	return nil, nil
}
