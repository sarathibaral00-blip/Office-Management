# Payroll and administration workflows

## Delivery and rollout status

Implemented locally on top of existing workflows: payroll, advances/loans,
expenses, private employee documents, five letter templates, report exports,
company/shift/policy/capability settings, audit viewer, theme/language preferences
and regression scenarios. Existing check-in, create-employee and attendance-admin
Edge Function business logic has not been rewritten.

New migrations **016–023 have not been applied**. Supabase MCP is unavailable in
this environment. No live security/performance advisor ran, and no hosted policy,
SQL function, Storage upload or payroll calculation was exercised. This is a
reviewable implementation, not a production-certified rollout.

1. Inspect linked project `uuihtzovrlijluahriym` and migration history using MCP.
   The user reports 001–015 are already working: do not reapply those files or
   create alternate device tables. Compare the read-only policy inventory query
   against the live schema first.
2. Apply 016 payroll, 017 financing, 018 expenses, 019 documents, 020 letters,
   021 exports, 022 settings, 023 hardening in order through MCP. Each file is
   transactional. Existing data is preserved; incompatible buckets fail for
   review instead of silently broadening access. Reconcile any live conflicts
   with a new additive migration.
3. Run security advisors, fix findings with migration files, apply, repeat.
   Inspect all function grants, RLS, Storage policies and Auth configuration.
4. Run all SQL scripts under `supabase/tests/` with trusted dev access; fixture
   scripts roll back. `policy_inventory.sql` is read-only. Repeat with real JWTs,
   two unrelated employees, two teams, HR and super_admin. New finance tests
   provide basic privilege/isolation/immutability checks, not complete accounting
   integration coverage.
5. Test office gateway forwarded-IP handling, regular bound devices, approved
   kiosks and temporary approvals on real devices before releasing the client.

Full table/policy listing: [policy-inventory.md](policy-inventory.md).

## Financial behavior

Salary components are basic, house rent, medical and conveyance with bank
account metadata. Missing structures use the existing profile salary as basic.
HR cannot change their own salary components through this API. Configure company
currency and late/absence/OT policy before creating records; currency cannot
change after financial records exist.

Payroll is generated for a fully closed month in chronological order, once per
month. Branch timezone, joining date, assigned/default shift, working days,
holidays, recorded attendance and approved paid/unpaid full/half-day leave feed
the calculation. Open attendance blocks generation. Scheduled workday duration
and a daily cap determine overtime; off-day overtime is not calculated. Overtime
is disabled by default until its multiplier is configured. Deductions are capped
to prevent negative pay. Generation snapshots employee, company, policy and
source facts. Late fees count scheduled days only. Attendance corrections after
generation do not silently rewrite payroll.

Drafts support reasoned bonus/extra deduction adjustments. Approval requires a
different authorized user than the creator. Locking publishes employee payslips
and posts reserved loan installments once; DB triggers reject later edits, even
service-role writes. Generate older runs first; no recalculate, delete or cancel
run action is implemented. Review attendance carefully before generating and
review all adjustments before approval. At least two authorized payroll users
are needed for separation of duties.

Financing requests require HR review and a separate disbursement reference.
Installments reserve against available net pay and remaining principal; unpaid
amounts carry forward. Locking posts them once and settles paid loans. Expense
claims require a private receipt, independent review and reimbursement reference.
Disburse/reimburse actions **record external payments**; no bank transfer is
initiated. Bank CSV is generic and must be reconciled with the receiving bank's
format. There is no statutory tax, provident fund or jurisdiction-specific
compliance engine.

Letters include appointment, confirmation, experience, salary certificate and
NOC, with company logo/signature and immutable issuance facts. Purpose/terms are
entered by HR; templates need company review. Graphic signatures are not digital
PKI signatures. PDFs use rasterized pages for multilingual rendering and are not
searchable/selectable text. Report Excel/CSV exports retain structured values;
spreadsheet formula payloads are neutralized. Oversized PDF table rows return a
clear error directing users to Excel/CSV.

Documents/receipts validate size and basic file signatures, with private buckets
and role-scoped access. Malware scanning is not implemented. Uploaded files can
be orphaned if subsequent metadata registration fails; retention/cleanup is an
operations task. Generated/downloaded files are confidential local artifacts.

Settings capability switches cover the new financial/export/settings features;
legacy role gates are preserved. Bangla/English preference translates shared
labels and navigation, with locale-aware dates; user-entered content and some
dynamic/server messages remain as supplied. Native Bengali font fallback and
large text require device verification. Theme/language preferences persist locally.

## Manual acceptance by role

### Employee

- Restore a session, switch English/Bangla and system/light/dark appearance,
  restart and verify persistence. Check phone/tablet layouts and larger text.
- Check in/out on office WiFi, then outside it; duplicate taps remain safe.
  Request leave/correction and confirm existing workflows still work.
- See only your locked payslips; save/share a PDF. Attempt another employee's
  payroll row, salary structure, receipt and document object URL with your JWT:
  access must fail. Draft/approved-unlocked slips must remain hidden.
- Request an advance/loan, inspect status notifications, then verify posted
  installments after payroll lock. Submit a PDF/JPEG/PNG receipt and see review
  and reimbursement status. Invalid/oversized files show friendly errors.
- Upload each document type, reopen it, and verify another employee cannot read
  it. Export own attendance/leave/payroll as appropriate, never another person's.
- Attempt own role/salary/is_active updates, direct attendance insert/update,
  manual/kiosk-source fabrication and private PIN reads: all denied.

### Manager

- View team attendance, leave/calendar and approval queues; approve/reject with
  comments. An unrelated employee must remain invisible through UI and API.
- Export team attendance/leave with department/branch/date filters. Team salary,
  payslips, financial requests, receipts and documents must not become visible.
- Own financial/profile workflows work as for employee. Direct payroll,
  permissions, manual attendance, PIN provisioning and kiosk registration deny.

### HR

- Configure another employee's four salary components and bank fields; own
  component change must fail. Configure a test closed month with holidays,
  part-month joining, paid/unpaid half/full leave, late and missing attendance.
  Compare each deduction/OT/bonus and totals against an independent worksheet.
- Generate once; retry/concurrent generation must not duplicate. Open attendance
  blocks generation. Adjust draft with reason; creator approval must fail.
  Have another payroll operator approve, lock, download employee PDF, annual
  summary, bank CSV and payroll Excel/CSV/PDF. Locked mutations must fail by API
  and trusted SQL. Existing legacy slips remain readable to their owners.
- Approve/disburse a different employee's loan, verify limited-net partial
  installment and remaining balance across two locked months. Self-review,
  duplicate disbursement and duplicate posting must fail.
- Review/reject/reimburse expenses with comments/references. Duplicate payment
  status transitions and self-approval must fail. Inspect private receipts.
- Upload/open all document types for employees, issue all five letter types with
  configured logo/signature, repeat download and compare snapshot facts.
- Change shifts/workdays/grace/late policy; verify existing attendance remains
  unchanged and new punches obey the policy. Inspect audit events and filters.
- Re-test manual reasons/limits, kiosk PIN reset, fifth-failure lock, expired
  temporary approval, corrections preserving source badges and all audit events.

### Super_admin

- Repeat HR actions, then disable individual HR capability keys and verify both
  API and UI errors deny the action. Restore them; employees/managers must not
  gain financial access even if an invalid capability request is attempted.
- Verify audit viewer and raw super-admin audit access, actor/subject/old/new
  values and reasons, no plaintext PIN or device secrets. Test disabled users.
- Run security advisors and all role/storage SQL/API tests. Test device A bound
  to user A with user B credentials: reject on the deployed **normal app path**,
  kiosk and temporary path as applicable. Test forged forwarded IP off office WiFi.

## Local verification

- `flutter analyze`: clean after numbered items, final run clean.
- `dart tool/verify_domain.dart`: 29 passing scenarios including auth, attendance,
  leave, payroll state/error/race handling, export encoding and file validation.
- `node tool/verify_functions.mjs`: 20 passing mocked existing-handler scenarios.
- Synthetic exports rendered in Flutter engine: 3 PDF pages with valid cross
  references/decompressed images, XLSX ZIP/XML integrity and 91 rows, CSV BOM and
  91 parsed rows verified. These are format checks, not real payroll validation.
- Standard `flutter test`: blocked opening localhost test server by sandbox.
- Web release build: see README validation status. Native share/save, physical
  devices, hosted SQL, Storage, Auth settings and security advisors remain manual.

## Remaining security risks and release blockers

Live migration/advisor/security tests are mandatory and pending. Local source
contains `attendance_devices` temporary employee binding, but does not contain
the user's stated `user_devices` normal-app binding implementation. The normal
JWT check-in path in this checkout does not demonstrate a user A/device A versus
user B binding check. Existing kiosk/device code was deliberately preserved;
inspect the hosted implementation and reconcile with the working source before
claiming the required guarantee. No replacement device table or flow was added.

Hosted gateway IP header trust also needs adversarial verification. Private
uploads have no malware scanner. Statutory payroll rules, bank format acceptance,
native behavior, retention and full Bengali coverage need operational review.
No claim that all Supabase warnings are fixed can be made without advisor access.
