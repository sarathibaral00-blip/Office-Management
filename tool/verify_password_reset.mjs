// Exercises the real script with mocked Auth Admin endpoints; no live passwords.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../scripts/seed_test_users.mjs', import.meta.url), 'utf8');
const identities = ['admin', 'hr', 'manager', 'employee'].map((name) => ({ id: `fixture-${name}`, email: `${name}@test.com` }));
async function run({ users = identities, url = 'https://uuihtzovrlijluahriym.supabase.co', args = ['--reset-passwords'], failureAt } = {}) {
  const calls = [], output = [];
  const fixturePassword = 'fixture-password-only';
  const process = { versions: { node: '22.0.0' }, argv: ['node', 'seed_test_users.mjs', ...args], env: { SUPABASE_URL: url, SUPABASE_SERVICE_ROLE_KEY: 'fixture-key-only', TEST_PASSWORD: fixturePassword } };
  await vm.runInNewContext(source, {
    process, URL, AbortSignal,
    console: { log: (value) => output.push(value), error: (value) => output.push(value) },
    fetch: async (url, options) => {
      calls.push({ path: new URL(url).pathname, ...options });
      return options.method === 'GET'
        ? { ok: true, status: 200, json: async () => ({ users }) }
        : { ok: !failureAt || !url.pathname.endsWith(failureAt), status: failureAt && url.pathname.endsWith(failureAt) ? 400 : 200, json: async () => ({}) };
    },
  });
  assert(!output.some((value) => value.includes(fixturePassword) || value.includes('fixture-key-only')));
  return { calls, output, exitCode: process.exitCode };
}
const success = await run();
const writes = success.calls.filter((call) => call.method !== 'GET');
assert.deepEqual(writes.map((call) => call.path), ['/auth/v1/admin/users/fixture-admin', '/auth/v1/admin/users/fixture-hr', '/auth/v1/admin/users/fixture-employee']);
for (const call of writes) { assert.equal(call.method, 'PUT'); assert.deepEqual(Object.keys(JSON.parse(call.body)), ['password']); }
assert.equal(success.exitCode, undefined);
const missing = await run({ users: identities.filter((user) => user.email !== 'hr@test.com') });
assert.equal(missing.exitCode, 1); assert(missing.calls.every((call) => call.method === 'GET'));
const invalidHost = await run({ url: 'https://example.invalid' });
assert.equal(invalidHost.exitCode, 1); assert.equal(invalidHost.calls.length, 0);
const invalidArgs = await run({ args: ['--unknown'] });
assert.equal(invalidArgs.exitCode, 1); assert.equal(invalidArgs.calls.length, 0);
const rejected = await run({ failureAt: 'fixture-hr' });
assert.equal(rejected.exitCode, 1); assert.equal(rejected.calls.filter((call) => call.method === 'PUT').length, 2);
console.log('PASS: only admin/HR/employee passwords updated, manager/profile data untouched, missing accounts and invalid inputs block writes, server failure stops updates, no credentials logged.');
