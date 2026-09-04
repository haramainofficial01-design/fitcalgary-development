package db

import (
	"context"
	"errors"
	"testing"

	"github.com/pashagolub/pgxmock/v4"
)

func TestRejectDevelopmentData(t *testing.T) {
	for _, tc := range []struct {
		name       string
		present    bool
		queryError bool
		wantError  bool
	}{
		{"unmarked database", false, false, false},
		{"fixture database", true, false, true},
		{"database unavailable fails closed", false, true, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			pool, err := pgxmock.NewPool()
			if err != nil {
				t.Fatal(err)
			}
			defer pool.Close()
			query := pool.ExpectQuery("SELECT EXISTS")
			if tc.queryError {
				query.WillReturnError(errors.New("unavailable"))
			} else {
				query.WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(tc.present))
			}
			err = RejectDevelopmentData(context.Background(), pool)
			if (err != nil) != tc.wantError {
				t.Fatalf("unexpected result: %v", err)
			}
			if err := pool.ExpectationsWereMet(); err != nil {
				t.Fatal(err)
			}
		})
	}
}
