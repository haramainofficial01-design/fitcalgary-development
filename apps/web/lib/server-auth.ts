import type { NextRequest, NextResponse } from 'next/server';

export const sessionCookie = 'fitcalgary_session';
export const transactionCookie = 'fitcalgary_oidc_transaction';

export type WebSession = {
  accessToken: string;
  refreshToken?: string;
  idToken?: string;
  expiresAt: number;
};

type OidcConfig = {
  issuer: string;
  clientId: string;
  clientSecret?: string;
  publicUrl: string;
  apiBaseUrl: string;
  cookieSecret: string;
};

export function oidcConfig(): OidcConfig {
  const issuer = process.env.OIDC_ISSUER;
  const clientId = process.env.OIDC_WEB_CLIENT_ID;
  const publicUrl = process.env.WEB_PUBLIC_URL;
  const apiBaseUrl = process.env.API_BASE_URL;
  const cookieSecret = process.env.SESSION_COOKIE_SECRET;
  if (!issuer || !clientId || !publicUrl || !apiBaseUrl || !cookieSecret) {
    throw new Error('Web authentication is awaiting production environment configuration.');
  }
  return {
    issuer: issuer.replace(/\/$/, ''),
    clientId,
    clientSecret: process.env.OIDC_WEB_CLIENT_SECRET,
    publicUrl: publicUrl.replace(/\/$/, ''),
    apiBaseUrl: apiBaseUrl.replace(/\/$/, ''),
    cookieSecret,
  };
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

function fromBase64Url(value: string): Uint8Array {
  const padded = value.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export function randomUrlSafe(bytes = 32): string {
  return base64Url(crypto.getRandomValues(new Uint8Array(bytes)));
}

export async function pkceChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64Url(new Uint8Array(digest));
}

async function key(secret: string): Promise<CryptoKey> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  return crypto.subtle.importKey('raw', digest, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

export async function seal(value: unknown, secret: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    await key(secret),
    new TextEncoder().encode(JSON.stringify(value)),
  );
  return `${base64Url(iv)}.${base64Url(new Uint8Array(ciphertext))}`;
}

export async function open<T>(value: string, secret: string): Promise<T | null> {
  try {
    const [rawIv, rawCiphertext] = value.split('.');
    if (!rawIv || !rawCiphertext) return null;
    const iv = Uint8Array.from(fromBase64Url(rawIv)).buffer;
    const ciphertext = Uint8Array.from(fromBase64Url(rawCiphertext)).buffer;
    const plaintext = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv },
      await key(secret),
      ciphertext,
    );
    return JSON.parse(new TextDecoder().decode(plaintext)) as T;
  } catch {
    return null;
  }
}

export async function readSession(request: NextRequest): Promise<WebSession | null> {
  const raw = request.cookies.get(sessionCookie)?.value;
  if (!raw) return null;
  return open<WebSession>(raw, oidcConfig().cookieSecret);
}

export async function refreshSession(session: WebSession): Promise<{ session: WebSession; changed: boolean }> {
  if (session.expiresAt > Date.now() + 60_000) return { session, changed: false };
  if (!session.refreshToken) throw new Error('Session expired');
  const config = oidcConfig();
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: config.clientId,
    refresh_token: session.refreshToken,
  });
  if (config.clientSecret) body.set('client_secret', config.clientSecret);
  const response = await fetch(`${config.issuer}/protocol/openid-connect/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    cache: 'no-store',
  });
  if (!response.ok) throw new Error('Session refresh failed');
  const tokens = (await response.json()) as Record<string, unknown>;
  return {
    changed: true,
    session: {
      accessToken: String(tokens.access_token),
      refreshToken: String(tokens.refresh_token ?? session.refreshToken),
      idToken: tokens.id_token ? String(tokens.id_token) : session.idToken,
      expiresAt: Date.now() + Number(tokens.expires_in ?? 300) * 1000,
    },
  };
}

export async function setSession(response: NextResponse, session: WebSession): Promise<void> {
  response.cookies.set(sessionCookie, await seal(session, oidcConfig().cookieSecret), {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24 * 30,
  });
}

export function decodeClaims(token: string): Record<string, unknown> {
  try {
    const payload = token.split('.')[1];
    return payload ? (JSON.parse(new TextDecoder().decode(fromBase64Url(payload))) as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}
