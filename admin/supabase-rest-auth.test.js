const assert = require('node:assert/strict');
const test = require('node:test');
const createClient = require('./supabase-rest-auth');

function storage(initial = {}) {
  const values = new Map(Object.entries(initial));
  return {
    getItem: key => values.has(key) ? values.get(key) : null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: key => values.delete(key),
    has: key => values.has(key),
  };
}

function response(status, body = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: name => name === 'content-range' ? null : null },
    text: async () => typeof body === 'string' ? body : JSON.stringify(body),
  };
}

test('login persists access, refresh, and expiry metadata', async () => {
  const store = storage();
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: store, fetch: async () => response(200, {
    access_token: 'access-1', refresh_token: 'refresh-1', expires_in: 3600,
  }) });
  const result = await client.auth.signInWithPassword({ email: 'a@b.test', password: 'secret' });
  assert.equal(result.error, null);
  assert.equal(store.getItem('hourtv_sb_access_token'), 'access-1');
  assert.equal(store.getItem('hourtv_sb_refresh_token'), 'refresh-1');
  assert.ok(Number(store.getItem('hourtv_sb_expires_at')) > Math.floor(Date.now() / 1000));
});

test('refreshes an expired session before the first request', async () => {
  const store = storage({
    hourtv_sb_access_token: 'old', hourtv_sb_refresh_token: 'refresh',
    hourtv_sb_expires_at: String(Math.floor(Date.now() / 1000) - 1),
  });
  const calls = [];
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: store, fetch: async (url, init) => {
    calls.push([url, init]);
    return url.includes('grant_type=refresh_token')
      ? response(200, { access_token: 'new', refresh_token: 'rotated', expires_in: 3600 })
      : response(200, [{ id: 1 }]);
  } });
  const result = await client.from('items').select('*');
  assert.equal(result.error, null);
  assert.equal(store.getItem('hourtv_sb_access_token'), 'new');
  assert.equal(calls.length, 2);
  assert.match(calls[1][1].headers.Authorization, /new$/);
});

test('refreshes once and retries the request after the first 401', async () => {
  const store = storage({ hourtv_sb_access_token: 'old', hourtv_sb_refresh_token: 'refresh', hourtv_sb_expires_at: String(Math.floor(Date.now() / 1000) + 3600) });
  let dataCalls = 0;
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: store, fetch: async (url) => {
    if (url.includes('grant_type=refresh_token')) return response(200, { access_token: 'new', refresh_token: 'refresh-2', expires_in: 3600 });
    dataCalls += 1;
    return dataCalls === 1 ? response(401, { message: 'expired' }) : response(200, [{ id: 2 }]);
  } });
  const result = await client.from('items').select('*');
  assert.equal(result.error, null);
  assert.equal(dataCalls, 2);
  assert.equal(store.getItem('hourtv_sb_access_token'), 'new');
});

test('failed refresh clears every token and reports an expired session', async () => {
  const store = storage({ hourtv_sb_access_token: 'old', hourtv_sb_refresh_token: 'refresh', hourtv_sb_expires_at: '1' });
  let expired = 0;
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: store, onSessionExpired: () => expired++, fetch: async () => response(400, { error_description: 'invalid refresh token' }) });
  await assert.rejects(async () => await client.from('items').select('*'));
  assert.equal(expired, 1);
  assert.equal(store.has('hourtv_sb_access_token'), false);
  assert.equal(store.has('hourtv_sb_refresh_token'), false);
  assert.equal(store.has('hourtv_sb_expires_at'), false);
});

test('logout clears access, refresh, and expiry tokens', async () => {
  const store = storage({ hourtv_sb_access_token: 'a', hourtv_sb_refresh_token: 'r', hourtv_sb_expires_at: '123' });
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: store, fetch: async () => response(200) });
  await client.auth.signOut();
  assert.equal(store.has('hourtv_sb_access_token'), false);
  assert.equal(store.has('hourtv_sb_refresh_token'), false);
  assert.equal(store.has('hourtv_sb_expires_at'), false);
});

test('public session snapshot never exposes refresh or expiry metadata', () => {
  const client = createClient({ url: 'https://example.supabase.co', key: 'anon', storage: storage() });
  const snapshot = client._publicSession({
    access_token: 'access-secret',
    refresh_token: 'refresh-secret',
    expires_at: 123,
    user: { email: 'admin@example.test' },
  });
  assert.deepEqual(snapshot, { user: { email: 'admin@example.test' }, hasSession: true });
  assert.equal(Object.prototype.hasOwnProperty.call(snapshot, 'access_token'), false);
  assert.equal(Object.prototype.hasOwnProperty.call(snapshot, 'refresh_token'), false);
  assert.equal(Object.prototype.hasOwnProperty.call(snapshot, 'expires_at'), false);
});

test('Google OAuth redirects through Supabase authorize endpoint', async () => {
  const store = storage();
  const location = { assigned: '', assign(value) { this.assigned = value; } };
  const client = createClient({ url: 'https://project.supabase.co', key: 'public-key', storage: store, location });
  const result = await client.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: 'https://hourtv-adming.vercel.app/?auth=callback' }
  });
  assert.equal(result.error, null);
  assert.match(location.assigned, /^https:\/\/project\.supabase\.co\/auth\/v1\/authorize\?provider=google&redirect_to=/);
  assert.match(decodeURIComponent(location.assigned), /redirect_to=https:\/\/hourtv-adming\.vercel\.app\/\?auth=callback/);
});

test('getSession remains usable while returning only the public snapshot', async () => {
  const client = createClient({
    url: 'https://example.supabase.co',
    key: 'anon',
    storage: storage({
      hourtv_sb_access_token: 'access-secret',
      hourtv_sb_refresh_token: 'refresh-secret',
      hourtv_sb_expires_at: '123',
    }),
  });
  const result = await client.auth.getSession();
  assert.deepEqual(result.data.session, { user: { email: 'Administrador' }, hasSession: true });
});
