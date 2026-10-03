import { NextRequest, NextResponse } from 'next/server';

import {
  clearTransaction,
  exchangeAuthorizationCode,
  oidcConfig,
  open,
  safeReturnTo,
  setSession,
  transactionCookie,
} from '@/lib/server-auth';

type Transaction = { verifier: string; state: string; returnTo: string };

export async function GET(request: NextRequest) {
  try {
    const config = oidcConfig();
    const failure = (reason: string) => {
      const response = NextResponse.redirect(
        `${config.publicUrl}/signin?error=${encodeURIComponent(reason)}`,
      );
      clearTransaction(response);
      return response;
    };
    const rawTransaction = request.cookies.get(transactionCookie)?.value;
    const transaction = rawTransaction
      ? await open<Transaction>(rawTransaction, config.cookieSecret)
      : null;
    const code = request.nextUrl.searchParams.get('code');
    const state = request.nextUrl.searchParams.get('state');
    if (
      !transaction ||
      !code ||
      !state ||
      state !== transaction.state ||
      typeof transaction.verifier !== 'string' ||
      !transaction.verifier
    )
      return failure('invalid_callback');
    let tokens;
    try {
      tokens = await exchangeAuthorizationCode(code, transaction.verifier);
    } catch {
      return failure('signin_unavailable');
    }
    const response = NextResponse.redirect(
      `${config.publicUrl}${safeReturnTo(transaction.returnTo)}`,
    );
    clearTransaction(response);
    await setSession(response, {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      idToken: tokens.idToken,
      expiresAt: Date.now() + tokens.expiresIn * 1000,
    });
    return response;
  } catch {
    const response = NextResponse.json(
      {
        error: 'Sign-in is temporarily unavailable. Please try again shortly.',
      },
      { status: 503 },
    );
    clearTransaction(response);
    return response;
  }
}
