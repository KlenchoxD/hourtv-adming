import test from 'node:test';
import assert from 'node:assert/strict';
import relay, {seal, unseal, rewriteManifest, checkUpstream} from './worker.mjs';
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
