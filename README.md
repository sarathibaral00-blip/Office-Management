# Pride People — HR Management V1

Flutter Material 3 foundation with feature-first Clean Architecture:
`Page → Cubit → UseCase → Repository → Supabase DataSource`.

Implemented screens: splash, login, forgot/new password, employee home with
live clock and verified office-network badge, attendance calendar and monthly
summary, and HR/admin office-network CRUD. Employees have bottom navigation;
HR, super admins and managers have a drawer or tablet side menu. System light
and dark themes use maroon and Inter. ScreenUtil uses a 390×844 design size;
phone dimensions scale, while tablet dimensions stay bounded.

## HR workflows

Employee management, full/half-day leave, holidays, correction requests, notices,
in-app notifications, role dashboards, HR reports and profile editing are now
implemented locally. See [HR workflows](docs/hr-workflows.md) for migrations
007–015, tables/policies, rollout status and manual acceptance tests for all roles.
The new client requires those migrations before deployment; remote application
and advisors are pending the Supabase MCP connection.

## Run

1. Resolve packages with `flutter pub get`.
2. Copy `config.example.json` to `config.local.json` and supply the project's
   **public** anon/publishable key. The local configuration is ignored.
3. Run `flutter run --dart-define-from-file=config.local.json`.

Never put the service-role key in Flutter, configuration files, or source control.
The two Edge Functions read it from their Supabase runtime secrets only.
A configuration screen appears if startup configuration is missing or invalid.

## Attendance fallbacks

HR manual attendance, source badges, monthly HR alerts, approved kiosk terminals,
and employee-bound temporary approvals are implemented locally. See
[attendance-fallbacks.md](docs/attendance-fallbacks.md) for migration 006, security
rules, current rollout status and manual acceptance steps.

## Supabase rollout (pending connection)

Target project: `uuihtzovrlijluahriym` (from AGENTS.md).

No remote database or deployment operation was performed in this session:
Supabase MCP is not connected. Before applying, inspect the project's existing
schema and migration history. The initial migration intentionally fails on
conflicting objects rather than silently replacing an existing schema.

Using Supabase MCP, apply the initial five files in `supabase/migrations/` in timestamp
order if not already applied, preserving each migration's name and SQL. Then apply
`202610280006_attendance_fallbacks.sql`. The initial migrations create all 13 requested
tables, enums, indexes, foreign keys, profile/signup/audit/protection triggers,
RLS, default shift and leave types. Existing Auth identities are backfilled
as employees; signup metadata cannot choose a role or salary.

Deploy `check-in` and `create-employee` from `supabase/functions/`, including
`_shared/http.ts`. Both functions validate the bearer token using Auth
`getUser`, then require an active profile. Gateway legacy JWT verification is
disabled in config so publishable keys and current Auth signing keys work;
**application authentication remains mandatory inside both handlers**.

After deployment:

- Run Supabase security advisors, review each finding and fix it with another
  local migration before applying. Also run performance advisors for indexes
  and RLS query plans. Advisor results have not been obtained yet.
- Run `supabase/tests/security.sql` through the SQL tool with postgres access.
  Its fixtures and mutations roll back. It checks signup metadata, RLS,
  employee profile isolation, protected fields and blocked attendance writes.
- Configure Auth redirect allowlists with `hrmanagement://reset-password`.
  For web, set `PASSWORD_RESET_REDIRECT` to your actual HTTPS reset route and
  allowlist it. Android/iOS custom-scheme handling is included.
- Enable production password protections, leaked-password detection where
  available, email confirmation and an appropriate SMTP provider in Auth.
- Bootstrap the first super admin by updating a known existing Auth user's
  profile from a trusted database administrator session. No default admin
  password or privileged signup path is included.
- Create a branch, verify its IANA timezone, and assign each employee's branch,
  department, manager and shift using a trusted HR/admin session. The first
  branch/network is deliberately not seeded with an arbitrary public IP.

## Attendance contract

`POST /functions/v1/check-in`, authenticated JSON:
`{"action":"check_in"}`, `{"action":"check_out"}`, or `{"action":"status"}`.
HR/admin can also use `{"action":"current_ip"}` for the network editor.

The first `x-forwarded-for` address is matched with PostgreSQL CIDR operators
against active networks **for the employee's assigned branch**. Missing IP,
unassigned branch, inactive employee, wrong network, duplicate check-in and
missing open check-in return clear non-2xx errors. Wrong network returns
`OFFICE_WIFI_REQUIRED` / `Connect to office WiFi`.

`record_attendance` is executable only by service_role. It locks the employee
row so concurrent requests serialize, derives the work date in branch timezone,
applies the assigned/default shift and grace interval, supports overnight
shifts, and writes attendance. Unique constraints also prevent duplicate days
and more than one open check-in. Checkout finds the open record even across
month boundaries. Normal users, including HR, cannot write attendance directly.

**Gateway verification required before production:** send a request from an
unapproved connection with a forged `x-forwarded-for` value matching an approved
IP. It must remain rejected. This implementation follows AGENTS.md's first-IP
contract and relies on the hosted gateway replacing untrusted client headers.
Do not expose the function through a proxy that preserves attacker-supplied
forwarded IPs. The UI badge is only the last server verification result; the
server checks again on every punch.

## Employee provisioning

`POST /functions/v1/create-employee`, authenticated as active HR/super_admin:

```json
{
  "email": "employee@example.com",
  "password": "a-strong-initial-password",
  "full_name": "Amina Rahman",
  "role": "employee",
  "branch_id": "existing-branch-uuid"
}
```

Optional fields: department_id, designation, salary, manager_id, shift_id,
joined_at. Only super_admin can create another super_admin. Auth creation
triggers a default employee profile; the server then sets authorized fields.
A failed profile update compensates by removing only the newly created Auth
identity. A failed compensation is logged by user ID for administrator repair.

## Manual acceptance tests

1. Sign in with each role; restart the app to verify session restoration,
   sign out, and attempt `/networks` directly as employee/manager. Only HR/admin
   can access network management. An inactive profile cannot use the app/API.
2. Request a reset email, open the link on Android/iOS (and configured web
   route), set a new password and sign in with it. Invalid credentials and
   offline requests must show readable errors.
3. As HR/admin, create a branch and assign it to the test employee. Add the
   current IP, edit its label/branch/CIDR, deactivate/reactivate it, and delete
   a disposable network using the confirmation dialog.
4. On an unapproved connection, check-in and checkout must show “Connect to
   office WiFi.” Repeat using forged forwarding headers; it must still reject.
5. On the office connection, check in before and after the grace boundary;
   check status `present` / `late`. Tap twice and send concurrent requests:
   exactly one row must exist. Checkout twice: the second request must fail.
6. Check an overnight shift and an open check-in from the previous month.
   Checkout must close that row, and hours must stop advancing afterward.
7. Open attendance history; compare calendar and summaries with database rows.
   Weekends, holidays, dates before joining and future days must not count as
   absences. Device timezone must not change the branch work date.
8. Test 320px, 390px and tablet widths, landscape, keyboard open, larger text,
   and system light/dark modes. Verify drawer/side menu and employee bottom nav.
9. Run the SQL security checks, plus manager team/outside-team and HR/admin
   access checks with real JWTs. Attempt own role/salary/is_active updates as
   every role, direct attendance writes and unauthenticated function calls:
   each must be denied.
10. Call create-employee as employee/manager (403), as HR with role super_admin
    (403), then with a valid HR payload (201). Invalid foreign keys must not
    leave an active partially provisioned account.

## Validation

- Formatting and `flutter analyze --no-pub`: passed with no issues.
- `flutter build web --no-pub --no-web-resources-cdn`: passed.
- `dart tool/verify_domain.dart`: 36 domain/Cubit scenarios passed.
- `node tool/verify_functions.mjs`: 20 mocked handler scenarios passed.
- `flutter test --no-pub`: blocked by sandbox loopback socket restrictions.
- Supabase migration application, hosted deployment, SQL/RLS integration tests,
  Deno checks and security advisors remain pending. See the fallback guide for
  complete acceptance steps and the distinction between unit and hosted checks.

Payroll and administration features are implemented locally. See
[finance-workflows.md](docs/finance-workflows.md) for migrations 016–023,
financial rules, rollout blockers, tests per role and remaining risks, and
[policy-inventory.md](docs/policy-inventory.md) for all 28 public tables,
two private credential tables and Storage policies. These new migrations
have not been applied because Supabase MCP is unavailable.

## DEV ONLY: seed test accounts

`scripts/seed_test_users.mjs` uses Node.js 18+ built-in `fetch`; no packages are
required. It creates the **four explicitly listed accounts**: `admin@test.com`
(super_admin), `hr@test.com` (hr), `manager@test.com` (manager), and
`employee@test.com` (employee). Use only against the development project.

Provide these environment variables through your local secret manager or secure
shell environment before running manually:

- `SUPABASE_URL`: `https://uuihtzovrlijluahriym.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY`: the development project's service-role key.
- `TEST_PASSWORD`: a strong test password accepted by the project's Auth policy.

```sh
# After securely populating the variables in your shell:
export SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY TEST_PASSWORD
node scripts/seed_test_users.mjs
```

Do not paste credentials into shell history, commit them, put them in Flutter
configuration, or run this script in CI/production. The script reads environment
variables only and does not automatically load `.env` files. `.env*` is ignored
by Git (the existing `.env.example` exception is for secret-free examples only).
It refuses missing variables, `NODE_ENV=production`, and any URL except the
exact HTTPS development project host; redirects are disabled.

To explicitly replace the passwords of existing `admin@test.com`, `hr@test.com`
and `employee@test.com`, securely set `TEST_PASSWORD` to the new shared password
and run:

```sh
node scripts/seed_test_users.mjs --reset-passwords
```

This mode uses the Auth Admin API and preserves account IDs, roles, profile data,
metadata and email confirmation. It does not create missing accounts and leaves
the manager account unchanged. It checks that all three accounts exist before
resetting any password. If a request fails after earlier accounts were updated,
rerun with the same environment value to finish. Passwords are never printed or
stored in SQL migrations. `supabase db push` does **not** rotate Auth passwords.

New accounts are email-confirmed and receive `user_metadata.full_name`. Existing
Auth accounts are skipped without changing their passwords, metadata or email
confirmation. For all four profiles, reruns enforce the listed roles and the
employee-to-manager link. Missing branch/department assignments use the
earliest-created branch/department (those tables have no default flag); missing
shift assignments use the shift marked `is_default`. Existing non-null
assignments are preserved; absent defaults are left unset. No branch, department
or shift is created. The signup trigger and existing migrations must be installed.

Only emails and roles are printed on success. Errors omit server response
bodies and credentials. Auth/profile operations are not a single transaction;
if a step fails, fix the reported issue and rerun to complete setup without
creating duplicate accounts. The script never deletes users or data. It has
been syntax-checked but has **not been executed against Supabase**.

## Dashboard header and weather

Home and role dashboards now use a fixed `AnimatedContainer` header above an
independently scrollable rounded body. The header shrinks over the first part of
the body scroll using a 200 ms ease-out animation. Its optional image uses
`DecorationImage(AssetImage(...), fit: BoxFit.cover)`. There are no custom paths,
custom painters, slivers, overlapping stacks or gradients in this layout.

The background image is intentionally hidden for now. The header uses a solid
maroon surface, white text/icons and a transparent status bar with light icons.
The Home and role-dashboard routes have no AppBar or top SafeArea; status-bar
insets are applied inside the header. Menu, notification count, logout and
profile navigation reuse the existing flows. To use your image, place it under `assets/images/`, declare
its real path in the `flutter.assets` section of `pubspec.yaml`, then pass
`showImage: true, imageAsset: 'assets/images/your-real-file.png'` to
`DashboardLayout`. Image display defaults to false; no missing asset is loaded.
Do not use the literal `[FILE_NAME]` placeholder. Image text uses white, so choose
an image with sufficient contrast behind the title.

The compact top-right weather badge uses Open-Meteo current model conditions,
with a ten-minute cache, fifteen-minute refresh, loading/retry states and a
visible last-reading indicator after a failed refresh. It defaults to **Dhaka**;
configure `WEATHER_CITY`, `WEATHER_LATITUDE` and `WEATHER_LONGITUDE` through
`--dart-define` or the existing local configuration JSON for another location.
No location permissions, employee information or Supabase credentials are sent
to the weather provider. Weather errors never block attendance.

Provider documentation: https://open-meteo.com/en/docs . The public endpoint is
for non-commercial evaluation; production commercial use requires an appropriate
provider subscription/server integration. No paid API key is embedded in Flutter.
The badge attributes Open-Meteo, and its tooltip shows observation time/condition.
Live provider connectivity still needs verification on the target device.

The existing employee edit form uses one column and floating input labels, so
its field decoration, controllers, validators and business logic are unchanged.
The requested two-column label/input alignment is pending identification of the
specific edit screen; no floating labels have been duplicated or restyled.

`tool/verify_dashboard_layout.dart` renders synthetic-weather phone/tablet,
large-text and dark-mode fixtures for standalone Flutter-engine smoke checks.

Latest dashboard validation: `flutter analyze --no-pub` clean, 36 domain/Cubit
scenarios passed, web release build passed, and standalone Flutter-engine
phone/tablet/large-text/dark-mode/header-scroll fixtures passed with synthetic
weather. This does not verify live provider connectivity or the missing PNG.

## Session and dialog lifecycle regression checks

The authenticated shell tolerates a missing profile while the router processes
logout/session loss. Router refresh listens to identity, role, active/recovery
state and initial restoration, rather than rebuilding Navigator for profile-only
updates. Save/review dialogs use `showAppDialog`, which waits for the overlay to
unmount before callers dispose text controllers. `dismissAppDialog` ignores late
callbacks after dismissal so they cannot pop an underlying screen.

Standalone Flutter-engine checks in `tool/verify_dialog_lifecycle.dart` cover
repeated approval dialog dismissal, profile refresh during an overlay, controller
disposal after reverse animation, late callbacks, logout with an overlay/sidebar
open and directly rebuilding the shell without a user. No live data is used.
After updating, fully restart the app and manually test save/approve/cancel,
back during an in-flight save, sign out from the sidebar and session restoration.

## Confirmation and employee provisioning fixes

Review dialogs for leave, attendance corrections, expenses, financing and device
management now validate required comments inline, await the Cubit operation,
disable duplicate submissions, and keep server errors visible for retry.
Holiday, payroll and shift dialogs also give feedback for incomplete input.

New employees use an initial password of exactly six digits. The form and
`create-employee` Edge Function enforce the same rule; existing sign-in passwords
remain valid. The linked Auth project's password policy must allow this format
(the local Supabase configuration sets a six-character minimum without character
requirements). An incompatible hosted policy produces an explicit error.
Failed employee saves preserve the password and entered details for correction.
The department picker includes **Add department**, creates the record through the
existing HR RLS policy, and selects it immediately. Duplicate and permission
errors appear in the dialog. No schema migration is required.

The previously missing `create-employee` and `attendance-admin` functions were
deployed to the linked development project. Both validate the caller's token and
active HR/admin role within the function before accessing privileged operations.

Validation: static analysis passes; 21 mocked Edge Function scenarios and 36
existing domain/Cubit scenarios pass. Standalone engine checks in
`tool/verify_action_flows.dart` and `tool/verify_employee_form.dart` exercise real
widgets for validation, retry, busy controls, department creation/selection,
failed-save recovery and successful employee navigation. Existing dialog
lifecycle regression checks also pass. Database approval, rejection and department
insertion were exercised inside rolled-back transactions, with the pending leave
and department data unchanged afterward. No live employee account was created.

The security advisor still reports existing intentionally exposed, role-checked
SECURITY DEFINER RPCs and disabled leaked-password protection. No database schema
or security policies were changed by these fixes.
