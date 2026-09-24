// Command client-data-import loads the Client-approved FitCalgary catalog into
// the existing production-shaped schema. It never guesses missing values and
// retains the full source payload in a non-public provenance table.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	database "fitcalgary.ca/index/api/internal/db"
)

type nullableFloat = *float64

type gymRecord struct {
	GymID          string `json:"gym_id"`
	Category       string `json:"category"`
	Subcategory    string `json:"subcategory"`
	Brand          string `json:"brand"`
	LocationName   string `json:"location_name"`
	Description    string `json:"description"`
	Address        string `json:"address"`
	City           string `json:"city"`
	Quadrant       string `json:"quadrant"`
	Neighbourhood  string `json:"neighbourhood"`
	PostalCode     string `json:"postal_code"`
	Phone          string `json:"phone"`
	Email          string `json:"email"`
	Website        string `json:"website"`
	Instagram      string `json:"instagram"`
	Facebook       string `json:"facebook"`
	TikTok         string `json:"tiktok"`
	YouTube        string `json:"youtube"`
	XTwitter       string `json:"x_twitter"`
	HoursSummary   string `json:"hours_summary"`
	DataConfidence string `json:"data_confidence"`
	Notes          string `json:"notes"`
	Open247        *bool  `json:"open_24_7"`
	Pricing        struct {
		MembershipModel   string        `json:"membership_model"`
		DropInPrice       nullableFloat `json:"drop_in_price"`
		MonthlyPriceLow   nullableFloat `json:"monthly_price_low"`
		MonthlyPriceHigh  nullableFloat `json:"monthly_price_high"`
		AnnualPrice       nullableFloat `json:"annual_price"`
		ClassPackPrice    nullableFloat `json:"class_pack_price"`
		ClassPackSize     *int          `json:"class_pack_size"`
		EnrollmentFee     nullableFloat `json:"enrollment_fee"`
		AnnualFee         nullableFloat `json:"annual_fee"`
		ContractRequired  *bool         `json:"contract_required"`
		MinTermMonths     *int          `json:"min_term_months"`
		StudentDiscount   string        `json:"student_discount"`
		SeniorDiscount    string        `json:"senior_discount"`
		FreeTrial         string        `json:"free_trial"`
		PriceNotes        string        `json:"price_notes"`
		PriceSourceURL    string        `json:"price_source_url"`
		PriceVerifiedDate string        `json:"price_verified_date"`
	} `json:"pricing"`
	Amenities     map[string]any `json:"amenities"`
	Accessibility map[string]any `json:"accessibility"`
	Derived       struct {
		CategoryGroup    string        `json:"category_group"`
		EstMonthlyBasis  string        `json:"est_monthly_basis"`
		PriceTier        string        `json:"price_tier"`
		EstMonthlyCost   nullableFloat `json:"est_monthly_cost"`
		EstFirstYearCost nullableFloat `json:"est_first_year_cost"`
		PerClassCost     nullableFloat `json:"per_class_cost"`
	} `json:"derived"`
	Sources []string `json:"sources"`
}

type clubRecord struct {
	ID                 string   `json:"id"`
	Group              string   `json:"group"`
	Category           string   `json:"category"`
	Sport              string   `json:"sport"`
	ClubName           string   `json:"club_name"`
	OrgType            string   `json:"org_type"`
	Level              string   `json:"level"`
	AgeGroups          string   `json:"age_groups"`
	Gender             string   `json:"gender"`
	City               string   `json:"city"`
	Area               string   `json:"area"`
	HomeVenue          string   `json:"home_venue"`
	Address            string   `json:"address"`
	Website            string   `json:"website"`
	Email              string   `json:"email"`
	Phone              string   `json:"phone"`
	Instagram          string   `json:"instagram"`
	Facebook           string   `json:"facebook"`
	OtherSocials       string   `json:"other_socials"`
	HowToJoin          string   `json:"how_to_join"`
	TryoutsEvaluations string   `json:"tryouts_evaluations"`
	Season             string   `json:"season"`
	FeesApprox         string   `json:"fees_approx"`
	EventsSocials      string   `json:"events_socials"`
	CanEarnMoney       string   `json:"can_earn_money"`
	EarningNotes       string   `json:"earning_notes"`
	Affiliation        string   `json:"affiliation"`
	Description        string   `json:"description"`
	DataConfidence     string   `json:"data_confidence"`
	LastVerified       string   `json:"last_verified"`
	SourceURLs         []string `json:"source_urls"`
}

type eventRecord struct {
	ID                string `json:"id"`
	Category          string `json:"category"`
	Sport             string `json:"sport"`
	Name              string `json:"name"`
	Organizer         string `json:"organizer"`
	CompetitionType   string `json:"competition_type"`
	Level             string `json:"level"`
	AgeGroup          string `json:"age_group"`
	GenderEligibility string `json:"gender_eligibility"`
	GenderRules       string `json:"gender_rules"`
	EntryType         string `json:"entry_type"`
	SkillTiers        string `json:"skill_tiers"`
	Season            string `json:"season"`
	NextDates         string `json:"next_dates"`
	RegistrationInfo  string `json:"registration_info"`
	Cost              string `json:"cost"`
	PrizeMoney        string `json:"prize_money"`
	Tryouts           string `json:"tryouts"`
	EarningPotential  string `json:"earning_potential"`
	Venues            string `json:"venues"`
	Area              string `json:"area"`
	Website           string `json:"website"`
	Email             string `json:"email"`
	Phone             string `json:"phone"`
	Instagram         string `json:"instagram"`
	Facebook          string `json:"facebook"`
	OtherSocials      string `json:"other_socials"`
	Notes             string `json:"notes"`
	SourceURLs        string `json:"source_urls"`
	DataConfidence    string `json:"data_confidence"`
	LastChecked       string `json:"last_checked"`
}

type summary struct {
	Gyms, Clubs, Events int
	Skipped             int
	DuplicateSourceIDs  int
	DuplicateClubNames  int
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)
var isoDate = regexp.MustCompile(`\b(20\d{2}-\d{2}-\d{2})\b`)

func clean(value string) string {
	v := strings.TrimSpace(value)
	trimmed := strings.Trim(v, "'\"` ")
	lower := strings.ToLower(trimmed)
	if trimmed == "" || lower == "unknown" || lower == "n/a" || lower == "none" || lower == "not available" {
		return ""
	}
	return v
}

func slug(value string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(value) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		} else {
			b.WriteByte('-')
		}
	}
	v := strings.Trim(nonSlug.ReplaceAllString(b.String(), "-"), "-")
	if len(v) > 170 {
		v = strings.Trim(v[:170], "-")
	}
	return v
}

func cents(value nullableFloat) *int {
	if value == nil || *value < 0 {
		return nil
	}
	v := int(math.Round(*value * 100))
	return &v
}

func validURL(value string) string {
	v := clean(value)
	if strings.HasPrefix(v, "https://") || strings.HasPrefix(v, "http://") {
		return v
	}
	return ""
}

func firstURL(values []string) string {
	for _, value := range values {
		if v := validURL(value); v != "" {
			return v
		}
	}
	return ""
}

func parseDate(value string) *time.Time {
	m := isoDate.FindStringSubmatch(value)
	if len(m) != 2 {
		return nil
	}
	t, err := time.Parse("2006-01-02", m[1])
	if err != nil {
		return nil
	}
	return &t
}

// parseEventDay accepts only a complete single-day value. A season, date range,
// expected date, or schedule with multiple events cannot become one start day.
func parseEventDay(value string) *time.Time {
	value = strings.TrimSpace(value)
	for _, layout := range []string{"Jan 2, 2006", "January 2, 2006"} {
		if day, err := time.Parse(layout, value); err == nil {
			return &day
		}
	}
	return nil
}

func optional(value string) any {
	if v := clean(value); v != "" {
		return v
	}
	return nil
}
func optionalTime(value string) any {
	if t := parseDate(value); t != nil {
		return *t
	}
	return nil
}

func stringsKnown(values ...string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, raw := range values {
		if v := clean(raw); v != "" && !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	return out
}

func amenityNames(values map[string]any) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	out := []string{}
	for _, key := range keys {
		if value, ok := values[key].(bool); ok && value {
			out = append(out, strings.ReplaceAll(key, "_", " "))
		}
	}
	return out
}

func joinKnown(separator string, values ...string) string {
	return strings.Join(stringsKnown(values...), separator)
}

func labelled(label, value string) string {
	if v := clean(value); v != "" {
		return label + v
	}
	return ""
}

func decodeRows(path string, wrapper string) ([]json.RawMessage, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if wrapper == "" {
		var rows []json.RawMessage
		err = json.Unmarshal(raw, &rows)
		return rows, err
	}
	var document map[string]json.RawMessage
	if err = json.Unmarshal(raw, &document); err != nil {
		return nil, err
	}
	part, ok := document[wrapper]
	if !ok {
		return nil, fmt.Errorf("missing %s array", wrapper)
	}
	var rows []json.RawMessage
	err = json.Unmarshal(part, &rows)
	return rows, err
}

func sourceRecord(ctx context.Context, tx pgx.Tx, dataset, sourceID, entityType, entityID, confidence string, checked any, payload json.RawMessage) error {
	_, err := tx.Exec(ctx, `INSERT INTO client_source_records(dataset,source_record_id,entity_type,entity_id,payload,confidence,last_checked) VALUES($1,$2,$3,$4,$5,$6,$7)`, dataset, sourceID, entityType, entityID, payload, optional(confidence), checked)
	return err
}

func importGyms(ctx context.Context, tx pgx.Tx, cityID string, rows []json.RawMessage, result *summary) error {
	seen := map[string]bool{}
	for _, raw := range rows {
		var row gymRecord
		if err := json.Unmarshal(raw, &row); err != nil {
			return err
		}
		id, name := clean(row.GymID), clean(row.LocationName)
		if id == "" || name == "" {
			result.Skipped++
			return fmt.Errorf("gym missing required gym_id or location_name")
		}
		if seen[id] {
			result.DuplicateSourceIDs++
			continue
		}
		seen[id] = true
		gymSlug := slug(id)
		if gymSlug == "" {
			gymSlug = slug(name)
		}
		var brandID any
		if brand := clean(row.Brand); brand != "" {
			var value string
			if err := tx.QueryRow(ctx, `INSERT INTO gym_brands(name,slug,website_url) VALUES($1,$2,$3) ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name,website_url=COALESCE(EXCLUDED.website_url,gym_brands.website_url),updated_at=now() RETURNING id::text`, brand, slug(brand), optional(validURL(row.Website))).Scan(&value); err != nil {
				return err
			}
			brandID = value
		}
		categories := stringsKnown(row.Category, row.Subcategory, row.Derived.CategoryGroup)
		opening, _ := json.Marshal(map[string]any{"summary": optional(row.HoursSummary), "open_24_7": row.Open247})
		media, _ := json.Marshal(map[string]any{"email": optional(row.Email), "instagram": optional(validURL(row.Instagram)), "facebook": optional(validURL(row.Facebook)), "tiktok": optional(validURL(row.TikTok)), "youtube": optional(validURL(row.YouTube)), "x": optional(validURL(row.XTwitter)), "accessibility": row.Accessibility})
		source := firstURL(row.Sources)
		if source == "" {
			source = validURL(row.Website)
		}
		var entityID string
		err := tx.QueryRow(ctx, `INSERT INTO gyms(city_id,brand_id,slug,name,operator,description,address_line1,neighbourhood,postal_code,website_url,telephone,categories,amenities,opening_hours,media,source_url,last_verified_at,publish_status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,'PUBLISHED') ON CONFLICT(city_id,slug) DO UPDATE SET brand_id=EXCLUDED.brand_id,name=EXCLUDED.name,operator=EXCLUDED.operator,description=EXCLUDED.description,address_line1=EXCLUDED.address_line1,neighbourhood=EXCLUDED.neighbourhood,postal_code=EXCLUDED.postal_code,website_url=EXCLUDED.website_url,telephone=EXCLUDED.telephone,categories=EXCLUDED.categories,amenities=EXCLUDED.amenities,opening_hours=EXCLUDED.opening_hours,media=EXCLUDED.media,source_url=EXCLUDED.source_url,last_verified_at=EXCLUDED.last_verified_at,publish_status='PUBLISHED',updated_at=now() RETURNING id::text`, cityID, brandID, gymSlug, name, optional(row.Brand), optional(row.Description), optional(row.Address), optional(joinKnown(" / ", row.Neighbourhood, row.Quadrant)), optional(row.PostalCode), optional(validURL(row.Website)), optional(row.Phone), categories, amenityNames(row.Amenities), opening, media, optional(source), optionalTime(row.Pricing.PriceVerifiedDate)).Scan(&entityID)
		if err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `DELETE FROM gym_pricing WHERE gym_id=$1`, entityID); err != nil {
			return err
		}
		recurring, frequency := cents(row.Pricing.MonthlyPriceLow), "MONTHLY"
		if recurring == nil && row.Pricing.AnnualPrice != nil {
			recurring, frequency = cents(row.Pricing.AnnualPrice), "ANNUALLY"
		}
		if recurring != nil {
			ongoing, firstYear := cents(row.Derived.EstMonthlyCost), cents(row.Derived.EstFirstYearCost)
			complete := confirmedAllInPricing(row, ongoing, firstYear)
			if !complete {
				// Unknown mandatory fees are not zero-dollar fees. Keep the
				// advertised rate, but never publish an all-in estimate.
				ongoing, firstYear = nil, nil
			}
			if _, err = tx.Exec(ctx, `INSERT INTO gym_pricing(gym_id,plan_name,recurring_cents,billing_frequency,mandatory_recurring_fee_cents,mandatory_annual_fee_cents,initiation_fee_cents,ongoing_monthly_cents,first_year_monthly_cents,pricing_complete,source_url,last_verified_at,membership_type,contract_months,drop_in_cents,trial_details,notes) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`, entityID, "Membership from", *recurring, frequency, 0, valueOrZero(cents(row.Pricing.AnnualFee)), valueOrZero(cents(row.Pricing.EnrollmentFee)), ongoing, firstYear, complete, optional(validURL(row.Pricing.PriceSourceURL)), optionalTime(row.Pricing.PriceVerifiedDate), optional(row.Pricing.MembershipModel), row.Pricing.MinTermMonths, cents(row.Pricing.DropInPrice), optional(row.Pricing.FreeTrial), optional(row.Pricing.PriceNotes)); err != nil {
				return err
			}
		}
		if err = sourceRecord(ctx, tx, "GYMS", id, "GYM", entityID, row.DataConfidence, optionalTime(row.Pricing.PriceVerifiedDate), raw); err != nil {
			return err
		}
		result.Gyms++
	}
	return nil
}

func confirmedAllInPricing(row gymRecord, ongoing, firstYear *int) bool {
	return ongoing != nil && firstYear != nil &&
		row.Pricing.AnnualFee != nil && row.Pricing.EnrollmentFee != nil
}

func valueOrZero(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}

func importClubs(ctx context.Context, tx pgx.Tx, cityID string, rows []json.RawMessage, result *summary) error {
	seen, names := map[string]bool{}, map[string]int{}
	for _, raw := range rows {
		var row clubRecord
		if err := json.Unmarshal(raw, &row); err != nil {
			return err
		}
		id, name, sport := clean(row.ID), clean(row.ClubName), clean(row.Sport)
		if id == "" || name == "" || sport == "" {
			result.Skipped++
			return fmt.Errorf("club missing required id, club_name or sport")
		}
		if seen[id] {
			result.DuplicateSourceIDs++
			continue
		}
		seen[id] = true
		names[strings.ToLower(name)]++
		clubSlug := slug(name + "-" + id)
		address := joinKnown(" / ", row.Address, row.HomeVenue, row.Area)
		eligibility := joinKnown(" | ", row.Level, row.AgeGroups, row.Gender, row.HowToJoin, row.TryoutsEvaluations)
		tags := stringsKnown(row.Group, row.OrgType, row.Level)
		source := firstURL(row.SourceURLs)
		if source == "" {
			source = validURL(row.Website)
		}
		var entityID string
		err := tx.QueryRow(ctx, `INSERT INTO clubs(city_id,slug,name,sport,category,description,address,website_url,registration_url,eligibility,age_categories,season_information,tags,source_url,last_verified_at,publish_status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,NULL,$9,$10,$11,$12,$13,$14,'PUBLISHED') ON CONFLICT(city_id,slug) DO UPDATE SET name=EXCLUDED.name,sport=EXCLUDED.sport,category=EXCLUDED.category,description=EXCLUDED.description,address=EXCLUDED.address,website_url=EXCLUDED.website_url,registration_url=NULL,eligibility=EXCLUDED.eligibility,age_categories=EXCLUDED.age_categories,season_information=EXCLUDED.season_information,tags=EXCLUDED.tags,source_url=EXCLUDED.source_url,last_verified_at=EXCLUDED.last_verified_at,publish_status='PUBLISHED',updated_at=now() RETURNING id::text`, cityID, clubSlug, name, sport, optional(row.Category), optional(row.Description), optional(address), optional(validURL(row.Website)), optional(eligibility), stringsKnown(row.AgeGroups), optional(row.Season), tags, optional(source), optionalTime(row.LastVerified)).Scan(&entityID)
		if err != nil {
			return err
		}
		if err = sourceRecord(ctx, tx, "CLUBS", id, "CLUB", entityID, row.DataConfidence, optionalTime(row.LastVerified), raw); err != nil {
			return err
		}
		result.Clubs++
	}
	for _, count := range names {
		if count > 1 {
			result.DuplicateClubNames += count - 1
		}
	}
	return nil
}

func importEvents(ctx context.Context, tx pgx.Tx, cityID string, rows []json.RawMessage, result *summary) error {
	seen := map[string]bool{}
	for _, raw := range rows {
		var row eventRecord
		if err := json.Unmarshal(raw, &row); err != nil {
			return err
		}
		id, name := clean(row.ID), clean(row.Name)
		if id == "" || name == "" {
			result.Skipped++
			return fmt.Errorf("competition missing required id or name")
		}
		if seen[id] {
			result.DuplicateSourceIDs++
			continue
		}
		seen[id] = true
		eventSlug := slug(name + "-" + id)
		entry := joinKnown(" | ", row.EntryType, row.RegistrationInfo, row.AgeGroup, row.GenderEligibility, row.GenderRules, row.SkillTiers, row.Tryouts)
		description := joinKnown("\n\n", row.CompetitionType, row.Level, row.Season, labelled("Schedule: ", row.NextDates), labelled("Cost: ", row.Cost), labelled("Prizes: ", row.PrizeMoney), labelled("Earning potential: ", row.EarningPotential), row.Notes)
		location := joinKnown(" / ", row.Venues, row.Area)
		link := validURL(row.Website)
		source := validURL(row.SourceURLs)
		if source == "" {
			source = link
		}
		registration := "UNKNOWN"
		var entityID string
		err := tx.QueryRow(ctx, `INSERT INTO events(city_id,slug,name,organizer,category,description,start_at,start_date,registration_status,location,external_registration_url,entry_requirements,sport,official_fitcalgary,tags,source_url,event_status,publish_status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,false,$14,$15,'ACTIVE','PUBLISHED') ON CONFLICT(city_id,slug) DO UPDATE SET name=EXCLUDED.name,organizer=EXCLUDED.organizer,category=EXCLUDED.category,description=EXCLUDED.description,start_at=EXCLUDED.start_at,start_date=EXCLUDED.start_date,end_at=NULL,registration_deadline=NULL,registration_status=EXCLUDED.registration_status,location=EXCLUDED.location,external_registration_url=EXCLUDED.external_registration_url,entry_requirements=EXCLUDED.entry_requirements,sport=EXCLUDED.sport,tags=EXCLUDED.tags,source_url=EXCLUDED.source_url,event_status='ACTIVE',publish_status='PUBLISHED',updated_at=now() RETURNING id::text`, cityID, eventSlug, name, optional(row.Organizer), optional(row.Category), optional(description), parseDate(row.NextDates), parseEventDay(row.NextDates), registration, optional(location), optional(link), optional(entry), optional(row.Sport), stringsKnown(row.CompetitionType, row.Level, row.Season), optional(source)).Scan(&entityID)
		if err != nil {
			return err
		}
		if err = sourceRecord(ctx, tx, "COMPETITIONS", id, "EVENT", entityID, row.DataConfidence, optionalTime(row.LastChecked), raw); err != nil {
			return err
		}
		result.Events++
	}
	return nil
}

func run() error {
	if os.Getenv("CLIENT_DATA_IMPORT") != "true" {
		return errors.New("set CLIENT_DATA_IMPORT=true to confirm the Client-approved import")
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}
	dataDir := os.Getenv("CLIENT_DATA_DIR")
	if dataDir == "" {
		dataDir = filepath.Join("..", "..", "data", "client-approved")
	}
	gyms, err := decodeRows(filepath.Join(dataDir, "fitcalgary_gyms.json"), "")
	if err != nil {
		return err
	}
	clubs, err := decodeRows(filepath.Join(dataDir, "sport_clubs.json"), "clubs")
	if err != nil {
		return err
	}
	events, err := decodeRows(filepath.Join(dataDir, "calgary_sport_competitions.json"), "")
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()
	migrations := os.Getenv("MIGRATIONS_DIR")
	if migrations == "" {
		migrations = filepath.Join("..", "api", "migrations")
	}
	if err = database.ApplyMigrations(ctx, pool, migrations); err != nil {
		return err
	}
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	var cityID string
	if err = tx.QueryRow(ctx, `SELECT id::text FROM cities WHERE slug='calgary'`).Scan(&cityID); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `LOCK TABLE gyms,gym_pricing,clubs,events,client_source_records,app_settings IN EXCLUSIVE MODE`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE gyms SET publish_status='ARCHIVED' WHERE publish_status='PUBLISHED'; UPDATE clubs SET publish_status='ARCHIVED' WHERE publish_status='PUBLISHED'; UPDATE events SET publish_status='ARCHIVED' WHERE publish_status='PUBLISHED'; DELETE FROM client_source_records WHERE dataset IN ('GYMS','CLUBS','COMPETITIONS'); DELETE FROM app_settings WHERE key='development_fixture_batch'`); err != nil {
		return err
	}
	result := summary{}
	if err = importGyms(ctx, tx, cityID, gyms, &result); err != nil {
		return err
	}
	if err = importClubs(ctx, tx, cityID, clubs, &result); err != nil {
		return err
	}
	if err = importEvents(ctx, tx, cityID, events, &result); err != nil {
		return err
	}
	meta, _ := json.Marshal(map[string]any{"batch": "client-approved-catalog-v1", "gyms": result.Gyms, "clubs": result.Clubs, "competitions": result.Events, "source": "Client-approved JSON", "imported_at": time.Now().UTC()})
	if _, err = tx.Exec(ctx, `INSERT INTO app_settings(key,value,public) VALUES('client_data_batch',$1,false) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,public=false,updated_at=now()`, meta); err != nil {
		return err
	}
	if err = tx.Commit(ctx); err != nil {
		return err
	}
	fmt.Printf("Client-approved import complete: gyms=%d clubs=%d competitions=%d skipped=%d duplicate_source_ids=%d duplicate_club_names_retained=%d\n", result.Gyms, result.Clubs, result.Events, result.Skipped, result.DuplicateSourceIDs, result.DuplicateClubNames)
	return nil
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}
