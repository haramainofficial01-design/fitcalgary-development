package httpapi

import (
	"encoding/json"
	"fitcalgary.ca/index/api/internal/domain"
	"fmt"
	"github.com/jackc/pgx/v5"
	"math"
	"net/http"
	"time"
)

func (s *Server) listDivisions(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT id,slug,display_label,minimum_age,maximum_age,minimum_inclusive,maximum_inclusive,open,sex_category FROM divisions WHERE active ORDER BY minimum_age NULLS FIRST,display_label`)
	return map[string]any{"data": rows}, err
}
func (s *Server) listCities(_ http.ResponseWriter, r *http.Request) (any, error) {
	rows, err := queryMaps(r.Context(), s.db, `SELECT id,slug,name,region_id FROM cities WHERE active ORDER BY name`)
	return map[string]any{"data": rows}, err
}

// Division rules are data; callers supply the date used for eligibility.
func divisionEligible(birth *time.Time, sex *string, at time.Time, min, max *int, minInclusive, maxInclusive, open bool, category *string) bool {
	if category != nil && *category != "ALL" && (sex == nil || *sex != *category) {
		return false
	}
	if open {
		return true
	}
	if birth == nil {
		return false
	}
	age := at.Year() - birth.Year()
	if at.Month() < birth.Month() || (at.Month() == birth.Month() && at.Day() < birth.Day()) {
		age--
	}
	if min != nil && (age < *min || (!minInclusive && age == *min)) {
		return false
	}
	if max != nil && (age > *max || (!maxInclusive && age == *max)) {
		return false
	}
	return true
}

func selectDivision(r *http.Request, tx pgx.Tx, owner string, chosen *string) (string, string, string, error) {
	var region string
	var birth *time.Time
	var sex *string
	err := tx.QueryRow(r.Context(), `SELECT c.region_id,p.date_of_birth,p.sex_category FROM profiles p JOIN cities c ON c.id=p.city_id WHERE p.id=$1 AND c.active`, owner).Scan(&region, &birth, &sex)
	if err == pgx.ErrNoRows {
		return "", "", "", validation("Choose your city in your profile before submitting a result")
	}
	if err != nil {
		return "", "", "", err
	}
	var id, label string
	var min, max *int
	var mi, ma, open bool
	var cat *string
	err = tx.QueryRow(r.Context(), `SELECT id,display_label,minimum_age,maximum_age,minimum_inclusive,maximum_inclusive,open,sex_category FROM divisions WHERE active AND (($1::uuid IS NOT NULL AND id=$1) OR ($1::uuid IS NULL AND open AND sex_category='ALL')) ORDER BY id LIMIT 1 FOR SHARE`, chosen).Scan(&id, &label, &min, &max, &mi, &ma, &open, &cat)
	if err == pgx.ErrNoRows {
		return "", "", "", validation("Choose an active division")
	}
	if err != nil {
		return "", "", "", err
	}
	if !divisionEligible(birth, sex, time.Now().UTC(), min, max, mi, ma, open, cat) {
		return "", "", "", validation("Your profile does not meet this division's age/category requirements")
	}
	return region, id, label, nil
}

func validMetric(value, min float64, max *float64, kind string) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value > 0 && value >= min && (max == nil || value <= *max) && (kind != "REPETITIONS" || math.Trunc(value) == value)
}
func resultLabel(value float64, kind, unit string) string {
	if kind == "TIME" {
		return domain.FormatTime(value)
	}
	return fmt.Sprintf("%g %s", value, unit)
}

func (s *Server) recordCommunity(w http.ResponseWriter, r *http.Request) (any, error) {
	var body struct {
		DisciplineID string  `json:"disciplineId"`
		DivisionID   *string `json:"divisionId"`
		Metric       float64 `json:"metric"`
	}
	if err := decodeJSON(r, &body); err != nil {
		return nil, err
	}
	if !validUUID(body.DisciplineID) || (body.DivisionID != nil && !validUUID(*body.DivisionID)) {
		return nil, validation("Invalid discipline or division")
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(r.Context())
	var kind, unit string
	var version int
	var min float64
	var max *float64
	err = tx.QueryRow(r.Context(), `SELECT metric_type,unit,rules_version,minimum_metric,maximum_metric FROM disciplines WHERE id=$1 AND active AND community_eligible FOR SHARE`, body.DisciplineID).Scan(&kind, &unit, &version, &min, &max)
	if err != nil {
		return nil, err
	}
	if !validMetric(body.Metric, min, max, kind) {
		return nil, validation("Result is outside this discipline's allowed values")
	}
	owner := identity(r).ProfileID
	var banned bool
	if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM bans WHERE profile_id=$1 AND lifted_at IS NULL AND starts_at<=now() AND (ends_at IS NULL OR ends_at>now()))`, owner).Scan(&banned); err != nil {
		return nil, err
	}
	if banned {
		return nil, &APIError{Status: 403, Code: "ACCOUNT_RESTRICTED", Message: "This account cannot post results"}
	}
	region, division, label, err := selectDivision(r, tx, owner, body.DivisionID)
	if err != nil {
		return nil, err
	}
	board, err := ensureBoard(r, tx, region, body.DisciplineID, division, "COMMUNITY")
	if err != nil {
		return nil, err
	}
	snapshot, _ := json.Marshal(map[string]any{"id": division, "label": label})
	rows, err := queryMaps(r.Context(), tx, `INSERT INTO results(profile_id,leaderboard_id,normalized_metric,display_metric,verification_type,verified_at,verified_by,division_snapshot,profile_snapshot,discipline_rules_version) VALUES($1,$2,$3,$4,'UNVERIFIED',now(),$1,$5,'{}',$6) RETURNING id,leaderboard_id,display_metric,verification_type`, owner, board, body.Metric, resultLabel(body.Metric, kind, unit), snapshot, version)
	if err != nil {
		return nil, err
	}
	if err = tx.Commit(r.Context()); err != nil {
		return nil, err
	}
	created(w, rows[0])
	return nil, nil
}
func ensureBoard(r *http.Request, tx pgx.Tx, region, discipline, division, kind string) (string, error) {
	if _, err := tx.Exec(r.Context(), `SELECT pg_advisory_xact_lock(hashtext($1))`, region+discipline+division+kind); err != nil {
		return "", err
	}
	var id string
	err := tx.QueryRow(r.Context(), `SELECT id FROM leaderboards WHERE region_id=$1 AND discipline_id=$2 AND division_id=$3 AND board_type=$4 AND event_id IS NULL ORDER BY created_at,id LIMIT 1`, region, discipline, division, kind).Scan(&id)
	if err == pgx.ErrNoRows {
		err = tx.QueryRow(r.Context(), `INSERT INTO leaderboards(region_id,discipline_id,division_id,board_type) VALUES($1,$2,$3,$4) RETURNING id`, region, discipline, division, kind).Scan(&id)
	}
	return id, err
}
