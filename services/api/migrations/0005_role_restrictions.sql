-- Application authorization can immediately revoke a privileged identity claim.
-- Existing identity-provider claims and genuine grants are otherwise preserved.
CREATE TABLE user_role_restrictions (
    profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role text NOT NULL CHECK(role IN ('MODERATOR','ADMIN','PERSONAL_TRAINER','JUDGE')),
    restricted_by uuid NOT NULL REFERENCES profiles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(profile_id,role)
);
