import { PublicShell } from '@/components/public-shell';

export default async function SignInPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  return <PublicShell active="profile"><section className="account-page"><p className="overline">Account</p><h1>Sign in.</h1><p>Browsing is open to everyone. An account is only for posting marks, saving gyms, and managing an athlete profile.</p><a className="primary-button" href="/api/auth/login?returnTo=/profile">Continue securely →</a>{error && <div className="form-error">Sign-in could not be completed. Please try again.</div>}<small>Continue securely to your FitCalgary account. Password reset is available on the sign-in page.</small></section></PublicShell>;
}
