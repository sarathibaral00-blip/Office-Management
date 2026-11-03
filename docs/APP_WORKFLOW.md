# Pride People: Roles, Features, and Full Workflow

Pride People manages employee records, attendance, leave, payroll, documents,
and HR requests. Each user signs in with an account assigned a role:
**employee**, **manager**, **HR**, or **super admin**. The role controls which
management screens and data they can access.

## Super admin

Super admin has the broadest administrative access and can also perform HR
tasks. Depending on assigned permissions, super admin can:

- Set up the company profile, branches, departments, shifts, working days,
  holidays, and attendance rules.
- Manage employee and HR access, roles, and permissions.
- Configure office networks and kiosk devices for attendance.
- Review organization-wide dashboards, reports, audit records, and payroll.
- Manage announcements and HR records.

Some sensitive operations still require the relevant permission.

## HR

HR manages employee records and day-to-day people operations:

- Add and edit employees, including designation, department, branch, manager,
  shift, and salary; deactivate employee accounts.
- Set or reset kiosk PINs and manage approved office devices.
- Add or edit attendance manually with a required reason.
- Review attendance corrections, leave requests, expenses, and other HR
  approvals.
- Set salary components, generate monthly payroll, arrange approval by a
  different reviewer, then lock and publish payslips.
- Manage holidays, notices, documents, letters, office networks, and HR
  reports.

## Manager

Managers handle team-related information and requests:

- Check the team attendance dashboard and pending items available to them.
- Review team leave requests and approve or reject them with a comment.
- Review team attendance information available to them.
- Use shared workspace features such as notices and documents.

Managers should only have access to their own team's data.

## Employee

Employees use the app for daily attendance and their own requests and records:

- Check in and check out from **Today** while connected to an allowed office
  network.
- View attendance history and submit a correction request if a record is
  incorrect.
- Apply for full-day or half-day leave, check leave balance, cancel a pending
  request, and view request history.
- Read announcements and notifications.
- View personal payroll, documents, expenses, advances, and profile details.

Employees can view their own payslips after payroll is published. They cannot
view other employees' private records.

## Main workflow

### 1. Set up the company

1. Super admin or HR sets up the company profile and adds branches and
   departments.
2. They configure shifts, working days, holidays, grace time, and attendance
   rules.
3. HR or super admin adds allowed office networks and registers approved
   kiosk devices if the office uses kiosks.

### 2. Set up employees

1. HR opens **Employees** and adds the employee's name and work email.
2. HR assigns the employee's role, designation, salary, department, branch,
   manager, and shift.
3. HR saves the employee record. The employee signs in with their account.
4. If kiosk attendance is needed, HR sets a kiosk PIN. The PIN is stored as a
   hash and is not readable as plain text.

### 3. Record daily attendance

1. The employee opens **Today** and checks in.
2. The attendance service checks the request's client IP against allowed office
   networks and applies the assigned shift's late rules.
3. The employee checks out at the end of the workday.
4. If the employee cannot use their phone, they can use an approved kiosk or
   temporary device. HR can also record attendance manually with a reason.
5. If a record needs correction, the employee submits a request for HR to
   review.

### 4. Request and approve leave

1. The employee submits a full-day or half-day leave request.
2. The manager or HR reviews it and approves or rejects it with a comment.
3. When approved, the database workflow deducts the leave balance.
4. Employees and managers can review the applicable leave calendar and request
   history.

### 5. Run payroll and publish payslips

1. HR sets the employee's salary components. For a total salary of **20,000**,
   the components should add up to 20,000. For example: Basic 14,000, House
   rent 3,000, Medical 2,000, and Conveyance 1,000.
2. After the month closes, HR generates payroll. The calculation uses salary
   components and applicable attendance, leave, late, overtime, bonus, and
   installment rules.
3. A different authorized HR user or super admin approves the payroll run.
4. HR locks and publishes the run.
5. Employees open **Workspace → Payroll** to view their own payslip and
   download or share its PDF.
6. HR can export a bank sheet CSV for the bank payment process. The app
   prepares the sheet; it does not transfer money.

### 6. Use other HR features

- **Notices:** HR or admin publishes company announcements; employees read
  them in the app.
- **Expenses:** Employees submit claims and receipts; authorized reviewers
  process them.
- **Documents:** Employees access their own private documents; HR can manage
  employee documents.
- **Letters:** HR generates employee letters such as appointment or salary
  certificates.
- **Reports:** HR reviews available attendance reports and exports.
- **Notifications:** Users view in-app notifications and reminders available
  to them.

## Where to find features

Use the bottom navigation for the main role-specific screens. Open
**Workspace** for the other features available to your role. HR and super admin
also have employee management, attendance support, and company administration
tools.
