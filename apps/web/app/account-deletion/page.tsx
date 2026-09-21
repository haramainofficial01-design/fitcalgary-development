import { PublicShell } from '@/components/public-shell';

export default function AccountDeletionPage() {
  return (
    <PublicShell active="profile">
      <article className="account-page legal-page">
        <p className="overline">Account &amp; privacy</p>
        <h1>Delete your FitCalgary account.</h1>
        <p>
          You can permanently delete your FitCalgary account from the mobile
          app or website after signing in.
        </p>
        <h2>In the FitCalgary app</h2>
        <p>
          Open <strong>Me</strong>, sign in, choose <strong>Account</strong>,
          then select <strong>Delete account</strong> and confirm.
        </p>
        <h2>On the FitCalgary website</h2>
        <p>
          Open <a href="/profile">your profile</a>, sign in, and use the
          account-deletion control shown in the account section.
        </p>
        <h2>What is deleted</h2>
        <p>
          Your account profile, saved gyms, device registrations,
          notifications, and role assignments are removed. Public result
          history is anonymized where it must remain to preserve the integrity
          of published rankings. Private evidence is scheduled for deletion.
        </p>
        <h2>Need help?</h2>
        <p>
          If you cannot access your account, visit <a href="/support">FitCalgary support</a>.
        </p>
      </article>
    </PublicShell>
  );
}
