package main

import "testing"

func TestPathStyleConfiguration(t *testing.T) {
	for _, entry := range []struct {
		value   string
		want    bool
		invalid bool
	}{{"", true, false}, {"true", true, false}, {"false", false, false}, {"invalid", false, true}} {
		t.Run(entry.value, func(t *testing.T) {
			t.Setenv("S3_USE_PATH_STYLE", entry.value)
			got, err := pathStyle()
			if (err != nil) != entry.invalid || got != entry.want {
				t.Fatal("storage addressing configuration was not respected")
			}
		})
	}
}
