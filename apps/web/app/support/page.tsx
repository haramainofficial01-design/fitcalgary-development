import { PublicShell } from '@/components/public-shell';
import { publicSupportEmail, publicSupportMailto } from '@/lib/public-config';

export default function SupportPage() {
  return (
    <PublicShell active="profile">
      <section className="account-page legal-page">
        <p className="overline">Help &amp; support</p>
        <h1>How can we help?</h1>
        <p>For account access, gym or event information, result submissions, evidence review, or a correction to published information, contact the FitCalgary support team.</p>
        <a className="primary-button" href={publicSupportMailto}>Email {publicSupportEmail} →</a>
        <h2>Account and privacy</h2>
        <p>Password reset is available from the secure sign-in experience. Account deletion is available from your profile. Privacy requests can also be sent by email.</p>
        <p><a href="/account-deletion">Account deletion instructions</a></p>
        <h2>Result reviews</h2>
        <p>Include the email used for your account and the relevant discipline or submission. Do not email private video evidence; upload it only through the protected submission flow.</p>
        <h2>Safety</h2>
        <p>FitCalgary support is not an emergency service. Urgent safety concerns should be directed to the appropriate local emergency service.</p>
        <p><a href="/privacy">Read the FitCalgary privacy policy</a></p>
      </section>
    </PublicShell>
  );
}
