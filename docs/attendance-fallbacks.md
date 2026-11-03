# Attendance fallbacks

## Rollout status

Migration `202610280006_attendance_fallbacks.sql` was written before its dependent
function/client changes. Supabase MCP is not connected in this session, so this
migration has **not been applied**, Edge Functions have **not been deployed**,
and security advisors and database integration tests have **not been run**.

Inspect the linked project's migration history first. Apply any missing initial
V1 migrations in order, then apply 006 using Supabase MCP. Never reapply migrations
already recorded in the project's history. Inspect the existing pgcrypto
extension location: this migration uses Supabase's standard `extensions` schema.
Deploy the updated `check-in`, the new `attendance-admin`, and their shared file.
The existing `create-employee` handler needs no change. Gateway legacy JWT checks
are disabled in config; application HR authentication remains mandatory in
`attendance-admin`. The kiosk path authenticates the device credential and PIN
instead of accepting an employee JWT as sufficient device approval.

After application, run Supabase security advisors and address warnings in a new
migration. Run both `supabase/tests/security.sql` and
`supabase/tests/attendance_fallbacks.sql` with postgres privileges on dev. The
latter uses rollback-only fixtures, creates no default PIN, and does not remove
existing data. It covers actual database authorization, private hash access,
manual audits/counts, lockout persistence, token rotation, rate limits and expiry.

## HR workflow

Open **Attendance support** from the HR/super-admin menu.

- **Manual attendance:** select any employee, choose a branch work date and load
  an existing record to edit, or choose check-in/out times to add a record. The
  time pickers use the device's local timezone; the server determines the work
  date in the employee's branch timezone. Editing preserves employee and work
  date. A new reason is mandatory on every save. Future timestamps and checkout
  before check-in are rejected. Checkout may be left open.
- **Monthly policy and HR alerts:** the global default is 3 distinct manual
  records per employee per calendar month, evaluated by attendance work date.
  HR can configure 0–100 with a reason. This is a soft limit: the fourth record
  saves, returns a warning, and creates/updates a persistent HR alert. Editing
  the same manual day does not increment the count. HR can acknowledge alerts;
  subsequent above-limit edits reopen the alert. Alerts are visible in the hub
  and manual screen, with acknowledgement audited. No email is sent.
- **Office kiosks:** sign in as HR on the actual office terminal. Set/reset the
  relevant employee PINs, register the terminal with its label, branch and reason,
  then choose **Sign out HR & open employee terminal**. Registration requires
  that branch's approved public IP. The kiosk screen has no HR session.
- **Temporary approvals:** sign in as HR on the borrowed device, choose one
  employee in the same branch, give a reason, approve for 24 hours, and open the
  terminal after signing HR out. The approval is bound to that employee. PIN and
  office-network verification are still required for every punch.
- **Non-app report:** browse months and load all pages of manual, correction and
  kiosk attendance. Every non-app record has a source badge; records link to the
  manual edit form. Existing employee history also shows these badges.

Employee IDs are generated, immutable `EMP-…` codes, visible to employees on
Home and to HR in the employee dropdown. PINs are 6–12 digits, set/reset by HR,
and cannot be viewed or recovered. HR must communicate an initial/reset PIN to
its intended employee through the organization's normal private process.

## Device and credential rules

The server generates a 256-bit device bearer credential. Only its SHA-256 hash
is saved in a private schema. The one-time credential returned to the approving
terminal stays in process memory; it is not stored in preferences, routes,
audit values, or clipboard. A reload/restart requires HR to sign in and use
**Pair here**, which rotates the credential and invalidates the previous token.
This pairs the terminal holding the credential; it does not claim hardware
attestation. Revoke a missing/untrusted terminal immediately.

PINs are salted bcrypt hashes at cost 12 in `attendance_private.employee_pins`.
That schema has no API-role usage/table grants; even HR reads no PIN hashes.
The PIN is absent from Bloc state and is cleared from terminal input fields
after every submission, on app backgrounding, and after 30 seconds of inactivity.
No PIN or device token is intentionally included in logs or errors.

Five bad PIN attempts for a known employee lock that employee's PIN until HR
resets it. Unknown/unavailable IDs have uniform errors; five such attempts lock
the device until HR rotates it. Each device is also limited to 20 attempts per
minute. Counters are serialized under row locks. Rejections return JSON rather
than raising an exception that would roll back the attempt counter and audit.
A correct PIN resets the consecutive PIN-failure counter even if the punch is
rejected as a duplicate.

Temporary approvals cannot last more than 24 hours or be extended by rotation.
Every server request checks `expires_at` against the server clock, so access
ends at expiry without relying on client time or a cron job. Revocation metadata
and its system audit event are materialized by the expiry sweep at the next
fallback request or HR refresh. Expired devices display as expired immediately
based on their expiry; reapproval creates a new approval record.

Every punch still uses the **check-in Edge Function** and the branch IP/shift/
grace/duplicate rules. A temporary terminal records source `app` with a device
ID and explicit temporary-device audit reason. A kiosk records source `kiosk`.
Manual saves always mark `manual`; `correction` is reserved for a future explicit
correction workflow. Mixed app/kiosk checkouts preserve non-app provenance, and
app/kiosk checkout cannot erase a manual/correction source.

The trusted gateway must replace client-supplied `x-forwarded-for` headers,
as required by the original office-IP contract. Verify forged forwarded headers
from an unapproved connection are rejected before production use.

## Audit coverage

Attendance INSERT/UPDATE audit rows identify actor, employee, device, old/new
values and reason. Kiosk actors are employees authenticated by PIN; manual
actors are the authenticated HR user. Device approval, rotation, revocation,
expiry, PIN reset, PIN rejection, device/network rejection, rate limiting,
policy changes, alert creation/acknowledgement, and denied management requests
are logged. System expiry has no human actor and an explicit expiry reason.
Credential hashes and PIN values are never put into audit snapshots.

Direct attendance writes remain unavailable to all authenticated roles.
Fallback RPCs are executable only by service_role. Employees/managers cannot
call them, approve devices, change the policy, or change their Employee ID.
HR management functions recheck the actor's active role inside the transaction.

## Manual acceptance steps

1. Regression: use the existing login/reset/logout, office-IP settings, normal
   app check-in/out and attendance calendar. App attendance must retain source
   `app`; employee/manager access to all HR support URLs must redirect away.
2. As HR, add a manual record for an employee without a phone. Verify source
   `manual`, required reason and correct branch work date. Load and edit it with
   another reason; inspect the audit actor, subject and complete old/new values.
   Empty reasons, reversed/future times and direct client writes must fail.
3. Set monthly limit to 3. Create four different manual workdays for one employee
   in one month. The fourth saves with an HR warning and inbox alert. Edit an
   existing day: count stays 4. Acknowledge the alert and verify its audit row.
4. On office WiFi, register a kiosk and set a test employee's PIN. Open the
   terminal and verify HR is signed out. Correct ID/PIN must check in/out and
   create source `kiosk` with the device/employee in audit. Duplicate check-in
   must fail. Input fields must clear after both success and rejection.
5. Fail the PIN five times. A correct PIN must then remain rejected. Confirm the
   persisted counter and lock metadata, reset the PIN as HR, then retry. Repeat
   with concurrent requests and more than one kiosk; the account lock must hold.
6. Try unknown IDs five times to lock a disposable test device. Pair it again
   as HR. Its old credential must stop working. Send more than 20 attempts in a
   minute with that test device and verify HTTP 429 plus a rate-limit audit row.
7. From an unapproved network, kiosk/temporary punches and device registration
   must fail. Forging an approved forwarding header must not bypass the gateway.
8. Approve a temporary device for one employee. Another employee's ID/PIN must
   fail. Verify `expires_at`, reject expiry beyond one day via the API, then test
   at/after expiry (or use the rollback-only SQL expiry fixture). Client clock
   changes must not extend authorization. Revocation must also block immediately.
9. Use employee and HR JWTs to try reading `employee_pins`, credential hashes,
   direct fallback RPCs and unauthorized device/settings writes. They must fail.
   Inspect audit JSON and Bloc state to confirm no PIN/hash/token is retained.
10. Verify the non-app report against SQL over multiple pages/months and confirm
    badges in employee history. Test phone/tablet widths, dark mode, keyboard,
    terminal inactivity/background clearing and re-pairing after a reload.

## Local verification

- `flutter analyze --no-pub`: passed with no issues.
- `dart format --output=none --set-exit-if-changed lib test tool`: passed.
- `dart tool/verify_domain.dart`: 11 scenarios passed, including existing flows.
- `node tool/verify_functions.mjs`: 20 handler scenarios passed with mocked
  Supabase boundaries, including original handler regression checks.
- `flutter test --no-pub`: attempted; the sandbox denied the loopback server
  socket. The same 11 unit scenarios passed through the direct Dart runner.
- Deno type checks, SQL/RLS integration tests, hosted requests and security
  advisors remain unverified until their runtimes/connection are available.

## DEV test-user branch assignment

Migration `202610280024_assign_dev_test_users.sql` assigns existing Auth accounts
`admin@test.com`, `hr@test.com`, `manager@test.com`, and `employee@test.com` to the
earliest-created branch with an active allowed network. It fills only missing
department and shift assignments using the earliest department/default shift.
Existing branch assignments on these four test profiles are intentionally
replaced so they share the test office. Roles, passwords, active flags and all
other users are untouched. Existing profile audit triggers record the reason.
It does not create Auth accounts or attendance and never bypasses office-IP
verification. If no branch has an active network, it fails with a setup message.

Apply manually with `supabase db push --linked`, then sign out/in and test
check-in from the saved office connection. Verify today's row in Attendance
History, check out, then verify the checkout time. With multiple office branches,
confirm the selected branch under Employee Management matches your current IP's
branch; adjust assignments there if needed. Missing test accounts must first be
created with the manual seed script. Supabase MCP application/advisors for this
migration remain pending in the agent environment.
