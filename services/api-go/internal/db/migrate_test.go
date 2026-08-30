package db

import "testing"

func TestSplitMigration(t *testing.T) {
	got := SplitMigration("SELECT 1;\n-- statement-breakpoint\n\nSELECT 2;")
	if len(got) != 2 || got[0] != "SELECT 1;" || got[1] != "SELECT 2;" {
		t.Fatalf("unexpected split: %#v", got)
	}
}
