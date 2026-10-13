# Deployment and release status

## Reachable public surfaces

- Website: https://fitcalgary-web.fitcalgary.workers.dev
- Admin entry: https://fitcalgary-web.fitcalgary.workers.dev/admin
- Privacy: https://fitcalgary-web.fitcalgary.workers.dev/privacy
- Support: https://fitcalgary-web.fitcalgary.workers.dev/support

These pages are HTTPS-reachable. That does not establish authenticated account
or admin operation. The application API and identity provider are unavailable
while the replacement hosting stack awaits deployment.

## Required external configuration

| Item | Required action |
|---|---|
| Hosting | Provide accessible Oracle Free console/session, verify home-region Always Free capacity, and restore the existing databases onto eligible resources |
| Email | Authorize a FitCalgary sending domain, verify its DNS and configure SMTP; receive and open verification and password-reset messages |
| Google | Authorize a dedicated FitCalgary OAuth project/client and register the Keycloak broker callback; test first and returning logins on both mobile platforms |
| Apple | Configure the related Services ID, callback domain/URL, signing key and client-secret rotation; test Apple login on a real iPhone |
| Off-device recovery | Authorize a private encrypted backup destination and verify a restore from it |
| Devices | Complete real iPhone, Android and Watch validation on available hardware |
| Stores | Build against the functioning replacement endpoints, verify reviewer access, upload corrected binaries and confirm actual review/testing status |

Do not reuse unrelated projects, disable email verification, invent credentials
or purchase paid capacity to bypass these requirements.

## Data and recovery

The approved catalog contains 273 gyms, 743 clubs and 531 competitions. Current
application and identity database exports were restored successfully in isolated
PostgreSQL environments, and a real Keycloak realm export was verified. Two
encrypted local backup copies exist outside source control. Production account
data, credentials and evidence are intentionally not shipped in this repository.
Transfer them separately using an authorized secure channel.

Three competition dates have corroborated source evidence; 528 remain undated.
Six confirmed broken registration links have a prepared suppression correction.
These corrections still need controlled production deployment. A record count
is not confirmation that all catalog information is current or complete.

## Verification boundary

Automated source tests and simulator/emulator checks exist. They are not
physical-device verification, live social login, email receipt or store approval.
The native iOS navigation appearance is approved; final device and authenticated
screen checks remain necessary.

The project is **not currently safe for public release** while its API and
authentication are unavailable. Do not treat source delivery as release acceptance.
Preserve the recovered backups and original volumes until the replacement stack
passes actual end-to-end checks.
