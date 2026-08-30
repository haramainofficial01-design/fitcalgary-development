package security

import "testing"

func TestTokenCipherRoundTripAndNondeterminism(t *testing.T) {
	cipher, err := NewTokenCipher([]byte("0123456789abcdef0123456789abcdef"))
	if err != nil {
		t.Fatal(err)
	}
	first, err := cipher.Encrypt("private-device-token")
	if err != nil {
		t.Fatal(err)
	}
	second, err := cipher.Encrypt("private-device-token")
	if err != nil {
		t.Fatal(err)
	}
	if first == second {
		t.Fatal("AES-GCM encryption must use a fresh nonce")
	}
	plain, err := cipher.Decrypt(first)
	if err != nil || plain != "private-device-token" {
		t.Fatalf("roundtrip failed: %q %v", plain, err)
	}
}

func TestTokenHashIsStableAndDoesNotExposeToken(t *testing.T) {
	first := HashToken("secret")
	if first != HashToken("secret") || first == "secret" {
		t.Fatalf("unexpected hash %q", first)
	}
}
