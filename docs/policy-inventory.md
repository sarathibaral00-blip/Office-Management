# Schema and policy inventory

This is the intended local schema after migrations 001–023, **not a verified
inventory of the hosted project**. Run `supabase/tests/policy_inventory.sql`
through Supabase MCP and compare every returned policy and grant. PostgreSQL
permissive policies combine with OR: an unexpected pre-existing policy can
invalidate an otherwise restrictive new policy. Never apply duplicate baseline
migrations to an already working project.

All 28 public application tables below have RLS. “HR capability” means an active
HR user with the corresponding enabled permission, or super_admin. Managers are
restricted to direct reports for team data; financial and document access does
not inherit team visibility. SQL privileges also restrict writes; an ALL policy
alone does not grant table mutation privileges.

| Table | Policies and effective access |
|---|---|
| profiles | `profile_read`: own/direct team/HR; `profile_update`: own/HR, with protected-field triggers; own role, salary and active status cannot change |
| departments | `read_active`, `hr_manage`: active readers, HR administration |
| branches | `read_active`, `hr_manage`: active readers, HR administration |
| shifts | `read_active`, `hr_manage`: active readers; authenticated DML revoked in 023; settings RPC writes |
| allowed_networks | `networks_hr`: HR only |
| attendance | `employee_read`: own/direct team/HR; no authenticated insert/update/delete |
| holidays | `read_active`, `hr_manage`: active readers, HR controlled CRUD |
| leave_types | `read_active`, `hr_manage`: active readers, HR administration |
| leave_balances | `employee_read`, `hr_manage`: own/direct team/HR; server deducts on approval |
| leave_requests | `employee_read`, `leave_submit`, `leave_review`: own/direct team/HR reads; direct DML revoked by 008, request/review RPCs enforce workflow |
| payroll | `employee_read`: own locked slips or approved/paid legacy slips; `hr_manage`: payroll.manage; authenticated DML revoked; immutable locked rows/runs |
| announcements | `read_active`: active, published, department/branch audience; `hr_manage`: HR |
| audit_log | `audit_read`: super_admin; `hr_attendance_audit`: HR attendance events. New audit viewer uses capability-scoped RPC, filtering sensitive finance/document events |
| attendance_settings | `hr_read`: HR |
| attendance_devices | `hr_read`: HR; registration/temporary expiry via existing server functions |
| hr_attendance_alerts | `hr_read`: HR |
| attendance_correction_requests | `correction_read`: own/direct team/HR; review RPC writes attendance as correction |
| announcement_reads | `read_own_receipts`: own; server marks read |
| notifications | `own_notifications`: own; server creates/marks read |
| role_permissions | `permission_own_role_read`: own role or super_admin; only super_admin changes supported capabilities via RPC |
| company_settings | `company_hr_read`: settings.manage; settings RPC writes |
| salary_structures | `salary_private_read`: own or payroll.manage; salary RPC blocks own component changes |
| payroll_runs | `runs_hr_read`: payroll.manage; server generates/approves/locks |
| employee_financing | `financing_private`: own or financing.review; server handles requests, review and payment reference |
| payroll_installments | `installment_private`: own posted deductions or financing.review; server reserves/posts immutable installments |
| expense_claims | `expense_private`: own or expenses.review; server handles lifecycle |
| employee_documents | `documents_private`: own or documents.manage; immutable metadata, server registers uploads |
| generated_letters | `letters_hr_read`: letters.issue; server snapshots issue facts |

Two additional private application tables:

| Table | Policy |
|---|---|
| attendance_private.device_credentials | `credential_owner`: postgres only; no authenticated schema usage |
| attendance_private.employee_pins | `pin_owner`: postgres only; bcrypt hash, never returned to clients |

Supabase-managed `auth.users`, `storage.buckets`, `storage.objects` and cron
catalogues are not application-owned tables. Auth identities stay behind Auth
APIs. Storage policies attach to `storage.objects`; bucket records are not
public download permission.

| Private bucket | Object policies |
|---|---|
| profile-photos | `own_profile_photo_read`, `own_profile_photo_insert`: active owner UUID folder only |
| expense-receipts | `receipts_private_read`: owner or expenses.review; `receipts_own_upload`: owner UUID folder |
| employee-documents | `documents_storage_read`: owner or documents.manage; `documents_storage_insert`: owner or documents.manage for a real employee UUID folder |
| company-assets | `company_assets_read`: active users can read logos, only letters.issue/settings.manage can read signatures; `company_assets_insert`: settings.manage, logos/signatures folders |

No new object update/delete policies. Unique immutable paths preserve snapshots.
Receipts/documents permit PDF/JPEG/PNG up to 10 MB; company assets JPEG/PNG up to
2 MB. Payslips are generated locally from private authorized rows, not stored in
a public bucket. Exported/downloaded files leave server access control and must
be handled as confidential by recipients.

Supported capability keys: payroll.manage, financing.review, expenses.review,
documents.manage, letters.issue, reports.export_all, reports.export_team,
reports.export_own, settings.manage, audit.view. These are bounded by fixed role
ceilings; this is not an arbitrary role/permission engine for legacy features.
Super_admin retains recovery authority. Existing role enum remains unchanged.

All new security-definer functions use explicit empty search paths and explicit
API grants; internal trigger functions are not executable by API roles. Trigger
audit records capture actor, old/new values and reasons where applicable. PIN
and terminal secrets are never recorded as plaintext audit values. These local
properties still require live SQL/advisor verification after application.
