# HR Management App (V1) - Flutter

## Stack
Flutter (Dart, Material 3), flutter_bloc (Bloc/Cubit) + equatable,
get_it (DI), go_router, flutter_screenutil, supabase_flutter,
google_fonts (Inter), fl_chart, intl.
Backend: Supabase (Auth, Postgres, RLS, Edge Functions, Storage).
Project ref: uuihtzovrlijluahriym

## Architecture (Clean Architecture, feature-first)
lib/core: theme, constants, router, di, network, error, utils, widgets
lib/features/<feature>/
  data: models, datasources (Supabase), repositories_impl
  domain: entities, repositories (abstract), usecases
  presentation: bloc, pages, widgets
Rules: UI -> Bloc -> UseCase -> Repository -> DataSource.
No Supabase calls inside UI or Bloc. Use Either/Result style error
handling (own Failure classes). One Bloc/Cubit per screen/flow.
Bloc states use Equatable, with Initial/Loading/Success/Failure.

## ScreenUtil rules
Wrap MaterialApp with ScreenUtilInit (designSize 390x844).
ALWAYS use .w .h .r .sp for sizes, padding, radius, font size.
Use SizedBox(height: 16.h), EdgeInsets.symmetric(horizontal: 16.w),
BorderRadius.circular(14.r), fontSize: 14.sp. No hardcoded raw sizes.
Must look good on small phone, big phone and tablet.

## V1 Scope
Auth + roles (super_admin, hr, manager, employee), Employee management,
Attendance (office WiFi public IP check), Leave, Basic payroll, Notice
board, Dashboard, Settings (Allowed IP management).

## Attendance rule
- Check-in/out ONLY via Supabase Edge Function check-in.
- Function reads client IP from x-forwarded-for (first IP), matches
  allowed_networks. No match = reject "Connect to office WiFi".
- Employees must NOT insert into attendance directly (RLS blocks it).
- Client-side WiFi name check is UI hint only, never security.

## Security rules
- RLS on every table. Employee sees own data; HR/admin all; manager own team.
- Users must never be able to change their own role/salary/is_active.
- service_role/secret key ONLY inside Edge Functions (Supabase secrets).
  Never in Flutter code.
- Never commit or print secrets. Keep .env* in .gitignore.
- DB changes: write migration file in supabase/migrations/ first, then
  apply to the linked dev project via Supabase MCP.
- Never drop/truncate/delete existing data without asking me.
- After applying, run Supabase security advisors and fix warnings.

## UI
Maroon theme: primary #800020, dark #5C0A1A, tint #F8EBEE, bg #FAF7F7,
text #1F1A1B, success #2E7D32, warning #ED9B00, danger #D32F2F.
Inter font, rounded 14-16.r, soft shadow, gradient hero cards,
skeleton loaders, empty states, toasts. Light + dark mode.
Employee: bottom nav. Admin/HR/Manager: drawer or side menu.
Reusable widgets in core/widgets (AppButton, AppTextField, AppCard,
StatusBadge, EmptyState, Loader).

## Workflow
Work through the given prompt fully, then summarize what was built,
what is left, and wait for my approval.
