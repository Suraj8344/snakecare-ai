# Hospital ambulance tracking (foreground pilot)

## How to use

1. Sign in with an individual account. Patients open **Track my ambulance**; drivers open **Driver • Registration & My trips**; hospital/government operators open **Manage ambulances**.
2. A driver selects their managed hospital, enters their name, vehicle number and hospital verification reference, then submits registration.
3. The hospital authority opens **Manage ambulances** and verifies the driver/vehicle outside the app before approving. A government authority can also review. Self-approval is blocked. The current status is omitted from the review-action menu.
4. A patient selects the hospital and explicitly agrees to share pickup GPS before requesting transport. **Requested does not mean an ambulance is coming.** The hospital must assign an approved driver.
5. The driver signs in with their own account, opens this workspace, accepts the assigned trip, and explicitly starts GPS sharing.
6. The patient and responsible authority see recent GPS on the map. The driver marks patient onboard, then completes the trip.

Drivers use a hospital-scoped membership, not a privileged self-selected global account role. Patient/doctor/hospital/government authentication is unchanged. Membership does not grant medical-record access. Revoked/rejected registrations can be resubmitted; pending/approved registrations cannot silently switch hospitals.

The portals now filter trips and forms by purpose. Patient views show only their own requested trips, driver views show assigned trips and registration, and hospital views show their managed fleet. Server-side authorization remains mandatory regardless of which screen is opened. Doctors keep the existing authorized patient-history screen; full AI Q&A is not part of this release.

## Android test build 0.1.5+6

Uses the existing debug signing identity in release mode (not a production Play Store signing setup) and the configured hosted API at https://snakecare-api.onrender.com. On 2026-09-09, the hosted OpenAPI schema returned HTTP 200 but did not contain /api/v1/ambulance-tracking/workspace. The backend and additive migration must be deployed there before phone tracking can work. Do not present this build as an operational ambulance service. Local web testing uses the locally upgraded API instead.

## Current implementation

- Flutter + flutter_map; FastAPI; PostgreSQL via SQLAlchemy; additive migration 20260908_0014.
- Driver GPS sampled roughly every 8 seconds while the workspace is foregrounded. Viewers refresh every 10 seconds; not a guaranteed real-time channel.
- Every write checks the authenticated user, assigned trip and approval. One active trip per driver and patient is enforced by unique partial indexes; row locks protect assignment changes.
- GPS validates coordinate bounds, accuracy, timestamp freshness and monotonic ordering; server rejects updates more often than every 3 seconds.
- Samples older than 60 seconds or a failed refresh are labeled outdated. No fabricated location, movement or ETA.
- Only the latest coordinate is stored (no route-history archive). Completing/cancelling clears pickup and ambulance coordinates. Refreshes use no-store responses.
- Location sharing stops when the screen closes/backgrounds; server rejects further updates after the trip ends. An already in-flight request can finish; its last position becomes stale.
- Hospital registration/approval and assignment are independent of medical-passport grants.

## Important limits before operational deployment

- This is an app-managed fleet workflow, **not a 108/112 integration or confirmed emergency dispatch service**.
- Hospital staff must keep the workspace open; push notifications, escalation, availability scheduling and background driver tracking are not implemented.
- A real two-device GPS/permission/connectivity test is required. Automated tests use synthetic coordinates/accounts, not real ambulance movement.
- Browser GPS on a phone needs HTTPS (localhost is a development exception). A laptop-local URL cannot serve a remote phone; use a configured reachable HTTPS deployment before distributing mobile builds.
- Maps require internet. Default tiles are OpenStreetMap, with attribution; no offline tile downloads. Configure MAP_TILE_URL for a production provider and follow its licensing/attribution requirements. Public tiles have no emergency-service availability guarantee.
- No route/traffic ETA, background GPS service, automatic assignment or outbound emergency calls/messages are included.
- Pending requests have no automated timeout/escalation. Cancel a request if no longer needed and contact emergency services directly when urgent.
- Initial workspace lists are capped at the latest 100 records; a production dispatcher needs pagination, operational monitoring, durable audit history and notifications before larger deployment.

## Verification

Backend integration exercises hospital approval, assignment, patient/stranger write denial, GPS freshness, trip transitions and coordinate deletion after completion using an isolated database. Flutter tests check waiting/GPS-absent messaging and home-screen role behavior. Do not describe these as hardware verification.
