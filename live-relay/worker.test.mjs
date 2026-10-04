import test from 'node:test';
import assert from 'node:assert/strict';
import relay, {seal, unseal, rewriteManifest, checkUpstream} from './worker.mjs';
import auditedStreams from './audited-streams.mjs';
const env = {RELAY_KEY: 'test-only-secret', ALLOWED_ORIGIN: 'https://hourtv.pages.dev',
  ALLOWED_UPSTREAM_HOSTS: 'example.com', UPSTREAM_CHANNELS: '{"rcn":"http://example.com/private/live.m3u8"}'};
test('media tokens encrypt credentials, expire and resist tampering', async () => {
  const url = 'http://example.com/live/private-user/private-password/1.ts';
  const token = await seal(url, env.RELAY_KEY);
  assert.equal(await unseal(token, env.RELAY_KEY), url);
  assert.ok(!Buffer.from(token, 'base64url').toString().includes('private-password'));
  await assert.rejects(unseal(token.slice(0, -5) + 'aaaaa', env.RELAY_KEY));
  await assert.rejects(unseal(await seal(url, env.RELAY_KEY, 1), env.RELAY_KEY));
});
test('HLS variants, segments and key URIs use only HTTPS encrypted relay URLs', async () => {
  const output = await rewriteManifest('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\nseg.ts\nchild.m3u8',
    'http://example.com/private/list.m3u8', 'https://relay.example', env);
  assert.equal((output.match(/https:\/\/relay.example\/part\//g) || []).length, 3);
  assert.ok(!output.includes('example.com'));
});

test('segment URLs stay stable within a session without extending token expiry', async () => {
  const expires = Date.now() + 600000;
  const manifest = '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:12\n#EXTINF:6,\nsegment.ts';
  const first = await rewriteManifest(manifest, 'http://example.com/list.m3u8', 'https://relay.example', env, expires);
  const second = await rewriteManifest(manifest, 'http://example.com/list.m3u8', 'https://relay.example', env, expires);
  assert.equal(first, second);
  const one = await seal('http://example.com/one.ts', env.RELAY_KEY, expires, true);
  const two = await seal('http://example.com/two.ts', env.RELAY_KEY, expires, true);
  assert.notDeepEqual(Buffer.from(one, 'base64url').subarray(0,12), Buffer.from(two, 'base64url').subarray(0,12));
  assert.equal(await unseal(one, env.RELAY_KEY), 'http://example.com/one.ts');
  await assert.rejects(unseal(await seal('http://example.com/one.ts', env.RELAY_KEY, 1, true), env.RELAY_KEY));
});
test('arbitrary hosts and caller-supplied URLs are rejected', async () => {
  assert.throws(() => checkUpstream('http://127.0.0.1/admin', env));
  assert.throws(() => checkUpstream('file:///etc/passwd', env));
  const response = await relay.fetch(new Request('https://relay.example/?url=http://example.com'), env);
  assert.equal(response.status, 404);
});
test('catalog exposes no provider information and foreign origins are blocked', async () => {
  const response = await relay.fetch(new Request('https://relay.example/catalog'), env);
  assert.deepEqual(await response.json(), [{name:'Canal RCN', url:'https://relay.example/live/rcn.m3u8'}]);
  assert.equal((await relay.fetch(new Request('https://relay.example/catalog', {headers:{Origin:'https://foreign.example'}}), env)).status, 403);
});

test('playback pins refreshes to one encrypted session with stable media URLs', async () => {
  const transport = async () => new Response('#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:2\n#EXTINF:6,\nsegment.ts',
    {headers:{'Content-Type':'application/vnd.apple.mpegurl'}});
  const start = await relay.fetch(new Request('https://relay.example/live/rcn.m3u8'), env, null, transport);
  assert.equal(start.status, 302);
  const location = start.headers.get('Location');
  assert.ok(location.startsWith('https://relay.example/part/'));
  assert.ok(!location.includes('example.com'));
  const one = await relay.fetch(new Request(location), env, null, transport);
  const two = await relay.fetch(new Request(location), env, null, transport);
  assert.equal(one.status, 200);
  assert.equal(await one.text(), await two.text());
});

test('purchased playback allows only audited IDs and keeps account details encrypted', async () => {
  const paidEnv={...env,IPTV_XTREAM:JSON.stringify({host:'http://example.com',username:'fake-user',password:'fake-password'})};
  const id=auditedStreams[0]?.id;
  assert.ok(id);
  let upstream;
  const transport=async value=>{upstream=String(value);return new Response('#EXTM3U\n#EXTINF:5,\nmedia.ts');};
  const response=await relay.fetch(new Request(`https://relay.example/live/iptv-${id}.m3u8`),paidEnv,null,transport);
  assert.equal(response.status,302);
  const location=response.headers.get('Location');
  assert.ok(!location.includes('fake-user')&&!location.includes('fake-password'));
  assert.equal(await unseal(new URL(location).pathname.slice(6),env.RELAY_KEY),upstream);
  assert.equal((await relay.fetch(new Request('https://relay.example/live/iptv-999999999.m3u8'),paidEnv,null,transport)).status,404);
  const catalog=await (await relay.fetch(new Request('https://relay.example/catalog'),paidEnv)).text();
  assert.ok(!catalog.includes('fake-user')&&!catalog.includes('fake-password'));
});
