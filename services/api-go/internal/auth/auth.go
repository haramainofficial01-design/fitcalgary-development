package auth

import (
	"context"
	"errors"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

type Role string

const (
	RoleUser            Role = "USER"
	RoleModerator       Role = "MODERATOR"
	RoleAdmin           Role = "ADMIN"
	RolePersonalTrainer Role = "PERSONAL_TRAINER"
	RoleJudge           Role = "JUDGE"
)

var knownRoles = map[Role]struct{}{
	RoleUser: {}, RoleModerator: {}, RoleAdmin: {}, RolePersonalTrainer: {}, RoleJudge: {},
}

type Principal struct {
	Subject       string
	Email         string
	EmailVerified bool
	Username      string
	Roles         []Role
}

func (p Principal) HasRole(allowed ...Role) bool {
	for _, current := range p.Roles {
		for _, candidate := range allowed {
			if current == candidate {
				return true
			}
		}
	}
	return false
}

type Verifier interface {
	Verify(context.Context, string) (Principal, error)
}

type OIDCVerifier struct {
	verifier *oidc.IDTokenVerifier
	audience string
}

func NewOIDCVerifier(ctx context.Context, issuer, audience string) (*OIDCVerifier, error) {
	provider, err := oidc.NewProvider(ctx, strings.TrimRight(issuer, "/"))
	if err != nil {
		return nil, err
	}
	return &OIDCVerifier{verifier: provider.Verifier(&oidc.Config{ClientID: audience}), audience: audience}, nil
}

type tokenClaims struct {
	Subject        string            `json:"sub"`
	Email          string            `json:"email"`
	EmailVerified  bool              `json:"email_verified"`
	PreferredName  string            `json:"preferred_username"`
	RealmAccess    access            `json:"realm_access"`
	ResourceAccess map[string]access `json:"resource_access"`
	FitCalgaryRoles []string         `json:"fitcalgary_roles"`
}

type access struct {
	Roles []string `json:"roles"`
}

func (v *OIDCVerifier) Verify(ctx context.Context, raw string) (Principal, error) {
	token, err := v.verifier.Verify(ctx, raw)
	if err != nil {
		return Principal{}, err
	}
	var claims tokenClaims
	if err := token.Claims(&claims); err != nil {
		return Principal{}, err
	}
	if claims.Subject == "" {
		return Principal{}, errors.New("token has no subject")
	}
	roles := ClaimsRoles(claims.RealmAccess.Roles, claims.ResourceAccess[v.audience].Roles, claims.FitCalgaryRoles)
	return Principal{Subject: claims.Subject, Email: claims.Email, EmailVerified: claims.EmailVerified, Username: claims.PreferredName, Roles: roles}, nil
}

func ClaimsRoles(groups ...[]string) []Role {
	seen := map[Role]struct{}{}
	roles := make([]Role, 0, len(knownRoles))
	for _, group := range groups {
		for _, raw := range group {
			role := Role(strings.ToUpper(raw))
			if _, known := knownRoles[role]; !known {
				continue
			}
			if _, duplicate := seen[role]; duplicate {
				continue
			}
			seen[role] = struct{}{}
			roles = append(roles, role)
		}
	}
	if _, found := seen[RoleUser]; !found {
		roles = append(roles, RoleUser)
	}
	return roles
}

func Bearer(header string) (string, bool) {
	parts := strings.Fields(header)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || parts[1] == "" {
		return "", false
	}
	return parts[1], true
}
