import { PublicShell } from '@/components/public-shell';

export default function SubmitPage() {
  return <PublicShell><section className="account-page"><p className="overline">Community result</p><h1>Put a number<br />on it.</h1><p>Private evidence uploads and submission status are available in the FitCalgary iOS and Android apps. Sign in here to continue to your account; evidence never becomes public.</p><a className="primary-button" href="/api/auth/login?returnTo=/admin">Sign in securely →</a><small>Large videos upload directly to private storage using short-lived multipart authorizations. Authorized judges receive audited, time-limited access.</small></section></PublicShell>;
}
