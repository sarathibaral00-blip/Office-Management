#!/usr/bin/env node
// DEV ONLY. Node 18+; no packages or dotenv loader. Never run from Flutter.
const PROJECT_REF = 'uuihtzovrlijluahriym';
const ACCOUNTS = [
  { email: 'admin@test.com', role: 'super_admin', fullName: 'Test Admin' },
  { email: 'hr@test.com', role: 'hr', fullName: 'Test HR' },
  { email: 'manager@test.com', role: 'manager', fullName: 'Test Manager' },
  { email: 'employee@test.com', role: 'employee', fullName: 'Test Employee' },
];

class SeedError extends Error {}

async function main() {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== '--reset-passwords')) {
    throw new SeedError('Usage: node scripts/seed_test_users.mjs [--reset-passwords]');
  }
  const resetPasswords = args[0] === '--reset-passwords';
  if (Number(process.versions.node.split('.')[0]) < 18) {
    throw new SeedError('Node.js 18 or newer is required.');
  }
  if (process.env.NODE_ENV === 'production') {
    throw new SeedError('DEV ONLY: refusing to run with NODE_ENV=production.');
  }
  const missing = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'TEST_PASSWORD']
    .filter((name) => !process.env[name]?.trim());
  if (missing.length) throw new SeedError(`Missing environment variables: ${missing.join(', ')}.`);

  let base;
  try {
    base = new URL(process.env.SUPABASE_URL);
  } catch {
    throw new SeedError('SUPABASE_URL must be a valid HTTPS project URL.');
  }
  // Exact host validation prevents sending a service key to a lookalike URL
  // with the project ref merely embedded in a query, path or hostname suffix.
  if (base.protocol !== 'https:' || base.hostname !== `${PROJECT_REF}.supabase.co`
      || base.username || base.password || base.port || base.search || base.hash
      || base.pathname !== '/') {
    throw new SeedError(`Refusing to run: SUPABASE_URL must be https://${PROJECT_REF}.supabase.co.`);
  }
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const password = process.env.TEST_PASSWORD;

  async function request(path, { method = 'GET', body, prefer } = {}) {
    let response;
    try {
      response = await fetch(new URL(path, base), {
        method,
        redirect: 'error',
        signal: AbortSignal.timeout(30_000),
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
          ...(prefer ? { Prefer: prefer } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch {
      throw new SeedError('Supabase request failed or timed out. Check connectivity and rerun safely.');
    }
    // Do not expose server bodies, headers or raw errors: they may contain secrets.
    if (!response.ok) {
      const error = new SeedError(`Supabase ${method} request failed (HTTP ${response.status}). Check credentials, migrations and input requirements, then rerun.`);
      error.status = response.status;
      throw error;
    }
    if (response.status === 204) return null;
    try {
      return await response.json();
    } catch {
      throw new SeedError('Supabase returned an unexpected response format.');
    }
  }

  async function findTestUsers() {
    const found = new Map();
    const wanted = new Set(ACCOUNTS.map((account) => account.email));
    for (let page = 1; ; page++) {
      const data = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`);
      if (!Array.isArray(data.users)) throw new SeedError('Unexpected Auth Admin user-list response.');
      for (const user of data.users) {
        const email = user.email?.toLowerCase();
        if (wanted.has(email)) found.set(email, user);
      }
      if (found.size === wanted.size || data.users.length < 1000) return found;
    }
  }

  // Explicit password-only mode: no account creation or profile/role changes.
  // Resolve every requested identity first, so a missing account causes no reset.
  if (resetPasswords) {
    const targets = ACCOUNTS.filter((account) => ['super_admin', 'hr', 'employee'].includes(account.role));
    const users = await findTestUsers();
    const missingAccounts = targets.filter((account) => !users.has(account.email));
    if (missingAccounts.length) {
      throw new SeedError(`Cannot reset: test accounts not found: ${missingAccounts.map((account) => account.email).join(', ')}.`);
    }
    for (const account of targets) {
      const id = users.get(account.email).id;
      if (!id) throw new SeedError('Auth Admin returned an invalid test user.');
      await request(`/auth/v1/admin/users/${encodeURIComponent(id)}`, {
        method: 'PUT',
        body: { password },
      });
      console.log(`${account.email}: password updated`);
    }
    return;
  }

  const [branches, departments, shifts] = await Promise.all([
    request('/rest/v1/branches?select=id&order=created_at.asc,id.asc&limit=1'),
    request('/rest/v1/departments?select=id&order=created_at.asc,id.asc&limit=1'),
    request('/rest/v1/shifts?select=id&is_default=eq.true&order=id.asc&limit=1'),
  ]);
  // Branch/department have no is_default flag: use the earliest-created entry.
  const defaults = {
    branch_id: branches[0]?.id,
    department_id: departments[0]?.id,
    shift_id: shifts[0]?.id,
  };
  const users = await findTestUsers();
  for (const account of ACCOUNTS) {
    if (users.has(account.email)) continue; // Never reset an existing password.
    let user;
    try {
      user = await request('/auth/v1/admin/users', {
        method: 'POST',
        body: {
          email: account.email,
          password,
          email_confirm: true,
          user_metadata: { full_name: account.fullName },
        },
      });
    } catch (error) {
      // Handle another seeder creating the account between listing and POST.
      if (![409, 422].includes(error.status)) throw error;
      user = (await findTestUsers()).get(account.email);
      if (!user) throw error;
    }
    if (!user?.id) throw new SeedError('Auth Admin did not return a user ID. Rerun after checking Auth.');
    users.set(account.email, user);
  }

  // Roles are assigned in trusted profile writes, never signup metadata.
  // Update manager before employee so manager-validation triggers accept the link.
  for (const account of ACCOUNTS) {
    const id = users.get(account.email).id;
    const path = `/rest/v1/profiles?id=eq.${encodeURIComponent(id)}`;
    const profiles = await request(`${path}&select=id,branch_id,department_id,shift_id`);
    if (profiles.length !== 1) {
      throw new SeedError(`Profile missing for ${account.email}. Check the signup trigger and rerun.`);
    }
    const patch = { role: account.role };
    for (const [column, value] of Object.entries(defaults)) {
      if (value && !profiles[0][column]) patch[column] = value;
    }
    if (account.role === 'employee') patch.manager_id = users.get('manager@test.com').id;
    const updated = await request(`${path}&select=id`, {
      method: 'PATCH', body: patch, prefer: 'return=representation',
    });
    if (!Array.isArray(updated) || updated.length !== 1) {
      throw new SeedError(`Profile update did not complete for ${account.email}. Check migrations and rerun.`);
    }
  }
  for (const { email, role } of ACCOUNTS) console.log(`${email} ${role}`);
}

main().catch((error) => {
  // Only deliberately authored messages are emitted; never dump error objects.
  console.error(error instanceof SeedError ? error.message : 'Unexpected seed failure. Check the dev project and rerun; no credentials were logged.');
  process.exitCode = 1;
});
