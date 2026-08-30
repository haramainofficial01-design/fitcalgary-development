package auth

import "testing"

func TestClaimsRolesMergesRealmAndClientClaims(t *testing.T) {
	roles := ClaimsRoles([]string{"user", "judge", "ignored"}, []string{"ADMIN", "judge"})
	for _, required := range []Role{RoleUser, RoleJudge, RoleAdmin} {
		found := false
		for _, got := range roles {
			found = found || got == required
		}
		if !found {
			t.Fatalf("expected role %s in %#v", required, roles)
		}
	}
	if len(roles) != 3 {
		t.Fatalf("expected deduplicated known roles, got %#v", roles)
	}
}

func TestClaimsRolesDefaultsToUser(t *testing.T) {
	roles := ClaimsRoles(nil)
	if len(roles) != 1 || roles[0] != RoleUser {
		t.Fatalf("expected USER default, got %#v", roles)
	}
}

func TestBearer(t *testing.T) {
	if token, ok := Bearer("bearer abc"); !ok || token != "abc" {
		t.Fatalf("expected token, got %q %v", token, ok)
	}
	if _, ok := Bearer("Basic abc"); ok {
		t.Fatal("basic authentication must not be accepted")
	}
}
