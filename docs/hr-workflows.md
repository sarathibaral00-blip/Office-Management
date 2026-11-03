# HR workflows: implementation and acceptance guide

## Current status

All nine requested Flutter feature sections are implemented locally on top of
existing auth, attendance, manual attendance, kiosk and temporary-device flows.
`flutter analyze --no-pub` passed after each numbered item. The integrated web
build also passed. New code uses feature-first Clean Architecture:
`Page → Cubit → UseCase → Repository → DataSource`.

**Remote rollout is unfinished.** Supabase MCP is not connected in this session.
Migrations 007–015 have been written but have not been applied here. Security
advisors, deployed SQL/RLS tests, Storage requests and cron execution have not
been verified. Do not deploy this client against the older schema: apply and
verify its migrations first. Existing live deployments were not changed.

Existing `check-in`, `create-employee`, `attendance-admin` and kiosk/device
handlers were reused without a new parallel device system. No `user_devices`
table or flow was changed. The source enum and existing attendance audit trigger
are reused for corrections. No existing records are dropped or deleted by the
new migrations or UI actions.

## What was built

| Item | Feature | Analyzer after item |
| --- | --- | --- |
| 1 | HR employee search, department/branch/status filters, pagination, add, detail/edit, deactivate/reactivate, assignments, existing PIN reset | Passed |
| 2 | Full/half-day leave, AM/PM, balance cards, pending cancellation, history, manager/HR review comments, team calendar, transactional deduction | Passed |
| 3 | Holiday calendar, HR create/edit/archive, holiday labels and markers in attendance history | Passed |
| 4 | Own-attendance correction requests, HR review, stale-record detection, audited `correction` source | Passed |
| 5 | Company/department announcements, private read receipts, unread badges, edit/archive | Passed |
| 6 | Private in-app inbox, workflow notifications, scheduled missed-checkout reminder | Passed |
| 7 | Role dashboards with fl_chart, personal balances, attendance chart, team today, HR totals and pending requests | Passed |
| 8 | HR daily/monthly reports, department/branch filters, full pagination, summaries and source badges | Passed |
| 9 | Own phone, gallery photo upload to private Storage, password change | Passed |

Employees retain a four-item bottom bar: Today, Attendance, Workspace, Profile.
Workspace links to the new features. Manager/HR/admin drawer and tablet menus
include their permitted workflows and the existing attendance-support screens.

### Important behavior

- Employee IDs continue to come from the existing database generator. Employee
  creation calls the existing `create-employee` Edge Function. PIN reset calls
  the existing `attendance-admin` `set_pin` action; no PIN hash is exposed.
- HR edits use `update_employee`; own role/salary/is_active changes are denied,
  including for HR and super_admin. Only super_admin can manage a super_admin.
  Manager assignments reject cycles and require an active eligible manager.
- Leave units exclude branch/global active holidays and unscheduled weekdays.
  Half days require one scheduled date and AM/PM. Two opposite half days may
  coexist; duplicate sessions and overlapping full days are rejected.
- Paid leave approval deducts balances in a database trigger in the same
  transaction as status approval. Requests serialize on the employee row;
  balance updates enforce available allocation. Cross-year requests charge
  each year's balance. Insufficient balance rolls back the approval. Unpaid
  leave is recorded without deducting a paid allocation. Only pending leave
  can be cancelled; approved leave is not cancellable in this scope.
- Annual allocations default from `leave_types` when a balance is first
  needed. Existing allocations are preserved. Managers see/review direct
  reports; they cannot review their own requests or another manager's team.
- Holiday removal is an archive. Archived holidays disappear from active
  calendars and future leave-unit calculations. Pending requests whose total
  units changed with the calendar must be cancelled and resubmitted.
- A correction targets an existing attendance record. Fully missing workdays
  continue to use the existing HR manual-attendance flow. A correction cannot
  move the record to another work date. HR approval verifies that the row still
  matches the original snapshot, updates it with source `correction`, and logs
  actor, old/new values and reason through the existing audit trigger. Managers
  may see team requests but cannot approve corrections.
- Announcements may target everyone or a department, while respecting any
  existing branch target. RLS protects department/branch messages. Editing a
  notice makes it unread again. Read receipts and notification inboxes are
  private to their owner. Workflow notification bodies do not copy private
  leave reasons or announcement content.
- The cron job `hr-missed-checkout-reminders` runs every 15 minutes. It queues
  one in-app reminder per open attendance record after the branch-local shift
  end plus 30 minutes, including overnight shifts. Dedupe keys prevent repeat
  reminders on subsequent runs. This is an in-app reminder, not a push/email.
- Employee dashboards scope to self; manager totals/team rows scope to direct
  reports; HR/super_admin totals scope to active staff. Absence excludes future
  days, days before joining, holidays, unscheduled weekdays and approved leave.
- Reports include recorded and inferred employee-days, with distinct off,
  holiday, on-leave, half-leave, not-checked-in and upcoming statuses. Inactive
  staff's recorded historical attendance remains visible. Inferred schedules
  and department filters use current assignments because the existing schema
  has no historical department/shift assignment snapshots. Hours count completed
  checkouts; open records are labelled open rather than inventing final hours.
- Profile photos use new immutable object names in `profile-photos/<user-id>/`.
  The private bucket accepts JPEG/PNG/WebP up to 5 MB; client format checks and
  gallery resizing provide additional validation. Signed image URLs expire
  after five minutes. Old objects remain stored; no automatic photo deletion
  or overwrite policy was added. Phone and photo updates do not overwrite
  each other during concurrent requests. Password changes use Supabase Auth;
  any configured recent-login/reauthentication requirements still apply.

## Migrations, tables and policies

Apply the following existing local files in order, after confirming migrations
001–006 are already in the linked project's migration history:

| Migration | Database change |
| --- | --- |
| 007 | Employee update RPC, manager validation trigger and employee search/status indexes |
| 008 | Leave half-day/session/unit/comment columns, submit/review/cancel RPCs, balance initialization, deduction trigger; direct request mutations revoked |
| 009 | Holiday `is_active`, save/archive RPC; workday calculation excludes archived holidays |
| 010 | New `attendance_correction_requests`, request/review RPCs and indexes |
| 011 | Announcement department/active/update columns; new `announcement_reads`; publish/read RPCs |
| 012 | New `notifications`, workflow triggers, private read RPC, reminder function and pg_cron job |
| 013 | Role-scoped dashboard aggregate RPC |
| 014 | HR-only report aggregate/pagination RPC |
| 015 | Profile phone/photo columns, private photo bucket/policies, validated own-profile RPC |

There are **three new public tables**, not duplicate attendance/device tables:

| Table | Read policy | Mutations |
| --- | --- | --- |
| `attendance_correction_requests` | Employee own; manager own/team; HR/admin all through `can_read_employee` | Authenticated request/review RPCs enforce actor/role; no direct client writes |
| `announcement_reads` | Active employee's own receipts only | Visibility-checked `mark_announcement_read` RPC |
| `notifications` | Active employee's own inbox only | Trusted workflow/reminder functions; own read-state RPC |

The existing announcement read policy now enforces department, branch, active
status and publication time. HR retains its existing management access. Direct
holiday/announcement deletes are revoked. The Storage policies
`own_profile_photo_read` and `own_profile_photo_insert` allow only an active
owner's folder in the private bucket. No photo UPDATE/DELETE policies were added.

All new security-definer functions pin `search_path` and derive authorization
from the authenticated actor. Internal trigger/calculation/reminder functions
are revoked from public/anon/authenticated as appropriate. The reminder function
is service-only; the cron job runs under its trusted database owner. Normal
clients still cannot insert/update attendance directly.

If the `profile-photos` bucket already exists with incompatible visibility/file
limits, migration 015 fails for review rather than overwriting it. Check for
broader pre-existing Storage policies during the remote advisor review.

## Remote rollout and security verification

1. Connect Supabase MCP to project `uuihtzovrlijluahriym` and inspect schema,
   existing functions/policies, extension locations and migration history.
   Reconcile any actual remote differences with local migration files first.
2. Apply each new migration using MCP, preserving its local name/SQL. Do not
   reapply old migrations already recorded remotely. No new Edge Function is
   required for these nine items; existing employee/PIN functions are reused.
3. Run security advisors after application, fix findings in a new migration,
   then rerun advisors. Also check performance advisors for RLS/index findings.
4. Run `supabase/tests/security.sql`, `supabase/tests/attendance_fallbacks.sql`
   and `supabase/tests/hr_workflows.sql` as postgres on dev. Fixtures and edits
   roll back. The workflow test checks all four roles, protected fields, team
   isolation, half-day deduction, double approval, insufficient balance rollback,
   source/audit updates, stale corrections, targeted notices, receipts,
   notifications, private photo metadata, reminder deduplication and cron setup.
5. Check cron job status/run history and exercise real Storage uploads/downloads
   with employee JWTs. The SQL Storage fixtures test metadata policies, not
   actual uploaded binary transport. Supabase Cron setup follows the official
   [installation](https://supabase.com/docs/guides/cron/install) and
   [scheduling](https://supabase.com/docs/guides/cron/quickstart) guidance.
6. Run the manual checks below before deploying the new Flutter client. Native
   image-picker plugins require a native rebuild. iOS photo-library usage text
   and macOS selected-file read entitlement are included.

## Manual tests by role

### Employee

1. Regression: sign in, restore a session, check in/out on office WiFi, reject
   off-office/forged-IP attempts, and inspect history/source badges. Existing
   kiosk/manual/temporary workflows must behave as before.
2. Open Workspace → Leave. Verify balance cards. Request a full day and then a
   half day, selecting AM/PM. Try overlapping requests and a holiday/off day.
   Cancel a pending request; confirm it remains in history as cancelled.
3. Have a manager approve a half day; verify used balance increases by 0.5.
   Try cancelling it after approval; it must fail. Try an over-balance request;
   approval must fail without changing used balance or pending status.
4. Request a correction to one existing workday. Try another employee's record
   ID via the API; it must fail. After HR approval, verify times and source
   `correction` in history. Missing whole days must use HR manual attendance.
5. Read a company and own-department notice, mark read, and verify the unread
   badge clears. Another department's notice must be inaccessible by API too.
   After a notice edit it must become unread again.
6. Read/mark notifications. Attempts to list or modify another user's inbox or
   receipt must fail. For an open past-end shift, run the cron job as admin and
   verify exactly one reminder despite repeated runs.
7. Check the personal dashboard against attendance/leave rows. Full approved
   leave, holidays and future dates must not count as absent.
8. Update phone, upload a JPEG/PNG/WebP, cancel selection, deny gallery
   permission, and try an oversized/unsupported file. Confirm another user's
   object cannot be listed/read with your JWT. Change password, sign out and
   sign in with it; test any configured reauthentication requirement.
9. Try reading another employee profile, leave, attendance or correction; try
   changing own role, salary, is_active or employee ID, and directly writing
   attendance/request approval. Every attempt must be denied.

### Manager

1. Verify team attendance and pending approvals against direct reports. Search
   the API for a known employee in another manager's team; no personal rows
   should be returned. The HR employee/report/support routes must redirect away.
2. Approve/reject a team leave request with a comment. Missing comments,
   self-approval and outside-team review must fail. Submit simultaneous approval
   requests: one transition/deduction must occur, and retries must fail.
3. Check team leave calendar and review comments. Verify half days, cross-year
   deductions, holidays and insufficient-balance rollback with HR assistance.
4. View team correction requests but attempt approval; it must be denied.
   Verify personal profile, leave, notices and notifications still work.

### HR

1. Search/filter/paginate employees, open details, create through
   `create-employee`, verify automatic ID, assign department/designation/branch/
   manager/shift, edit and deactivate/reactivate. Try a manager cycle. A
   deactivated account must lose backend access. Do not delete its history.
2. Set/reset a kiosk PIN in employee details and use it on an already approved
   kiosk. No PIN/hash should be visible in API reads or Cubit state. Re-run the
   existing five-failure lockout and device-binding tests.
3. Review leave with comments. Approve two concurrent requests against a small
   balance; balance checks must serialize, and only affordable approvals commit.
4. Create/edit/archive a branch holiday. Verify the holiday calendar and
   attendance calendar; the archived row must still exist in the database.
5. Approve/reject a correction, verify old/new audit values and source badge.
   Change the attendance after a request was submitted, then try approval:
   stale approval must fail without overwriting the newer record.
6. Publish company/department notices, edit and archive them. Verify targeted
   visibility with employee accounts and private read receipts.
7. Compare headcount, present, late, on-leave and pending dashboard totals with
   SQL. Test daily/monthly reports with department/branch filters, multiple
   pages, all source badges, completed hours and inferred absence statuses.
8. Try changing your own role/salary/is_active or managing a super admin;
   these operations must be denied. Use a different authorized super admin for
   legitimate privileged account changes.

### Super admin

1. Run all HR checks, then manage another HR/super-admin employee. Own role,
   salary and is_active changes must remain denied.
2. Inspect audit rows for employee edits, leave transitions, holiday changes,
   announcement changes and correction approvals. The attendance audit must
   retain the existing actor/employee/device/source semantics and contain no
   PIN/token values.
3. Run the SQL security suites and advisors; inspect reminder cron executions
   and Storage policies. Confirm no new device tables or alternative kiosk
   authentication path was introduced.
4. Test 320px/390px/tablet widths, dark/light modes, larger text, keyboard-open
   forms, empty/error states and pagination. Confirm original navigation links
   remain available through the drawer or Workspace.

## Local checks and remaining limits

- Per-item and integrated `flutter analyze --no-pub`: passed.
- `dart tool/verify_domain.dart`: 19 scenarios passed, including the original
  attendance/fallback cases and eight new workflow cases.
- `node tool/verify_functions.mjs`: all 20 existing mocked handler/regression
  scenarios passed; this does not prove deployed database authorization.
- `flutter build web --no-pub --no-web-resources-cdn`: passed.
- `flutter test --no-pub`: attempted, but the sandbox denied creation of its
  loopback server socket. The same unit scenarios passed with the Dart runner.
- SQL/RLS/cron/Storage integration, security advisors, native device builds and
  visual/manual acceptance remain pending. No clean advisor report or applied
  database migration is claimed.

Payroll screens, approval/refund of already approved leave cancellations,
historical assignment snapshots, push/email delivery and automatic deletion of
old photos are outside this request. Previously completed device flows remain
unchanged.
