import { PublicShell } from '@/components/public-shell';
import { publicSupportEmail, publicSupportMailto } from '@/lib/public-config';

export default function PrivacyPage() {
  return (
    <PublicShell active="profile">
      <article className="account-page legal-page">
        <p className="overline">FitCalgary Index</p>
        <h1>Privacy policy.</h1>
        <p className="legal-updated">Effective September 13, 2026</p>
        <h2>Information we collect</h2>
        <p>FitCalgary uses account details, profile information, saved gyms, competition entries, device notification details, and evidence you choose to submit to provide the service.</p>
        <h2>How information is used</h2>
        <p>Information is used to operate accounts, gym and event discovery, leaderboards, result verification, notifications, safety, support, and service administration. Private evidence is available only to the submitting athlete and authorized reviewers.</p>
        <h2>Storage and sharing</h2>
        <p>Service providers may process information only to host and operate FitCalgary. We do not sell personal information. Public profile and leaderboard details follow the visibility choices available in your account.</p>
        <h2>Retention and account deletion</h2>
        <p>Information is retained only as needed for the service, security, legal obligations, and dispute handling. You can delete your account from your profile. <a href="/account-deletion">Read the account deletion instructions</a>.</p>
        <h2>Your choices</h2>
        <p>You may update profile visibility and notification preferences in the application. For access, correction, deletion, or privacy questions, contact <a href={publicSupportMailto}>{publicSupportEmail}</a>.</p>
      </article>
    </PublicShell>
  );
}
