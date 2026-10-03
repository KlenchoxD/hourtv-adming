const encoder = new TextEncoder();
const decoder = new TextDecoder();
const names = { rcn: 'Canal RCN', 'rcn-mas': 'RCN Mas', 'rcn-hd2': 'RCN HD2' };

export function checkUpstream(value, env) {
  const u = new URL(value);
  const allowed = env.ALLOWED_UPSTREAM_HOSTS.split(',').map(v => v.trim());
  if (!['http:', 'https:'].includes(u.protocol) || u.username || u.password ||
      !allowed.includes(u.hostname)) throw new Error('Upstream not allowed');
  return u;
}

async function key(secret) {
  const hash = await crypto.subtle.digest('SHA-256', encoder.encode(secret));
  return crypto.subtle.importKey('raw', hash, 'AES-GCM', false, ['encrypt', 'decrypt']);
}
function b64(bytes) {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}
function unb64(text) {
  return Uint8Array.from(atob(text.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0));
}
export async function seal(url, secret, expires = Date.now() + 20 * 60 * 1000, stable = false) {
  const plaintext = encoder.encode(JSON.stringify({url, expires}));
  // HLS compares segment URLs across playlist reloads. A keyed nonce derived
  // from the complete plaintext is stable only for the exact same payload;
  // different URLs/expiry values do not reuse a GCM nonce.
  let iv = crypto.getRandomValues(new Uint8Array(12));
  if (stable) {
    const nonceKey = await crypto.subtle.importKey('raw', encoder.encode('hls-nonce:' + secret),
      {name:'HMAC', hash:'SHA-256'}, false, ['sign']);
    iv = new Uint8Array(await crypto.subtle.sign('HMAC', nonceKey, plaintext)).slice(0, 12);
  }
  const encrypted = new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv},
    await key(secret), plaintext));
  const bytes = new Uint8Array(iv.length + encrypted.length);
  bytes.set(iv); bytes.set(encrypted, iv.length);
  return b64(bytes);
}
export async function unseal(token, secret) {
  return (await unsealPayload(token, secret)).url;
}
async function unsealPayload(token, secret) {
  if (token.length > 8192) throw new Error('Invalid token');
  const bytes = unb64(token);
  const payload = JSON.parse(decoder.decode(await crypto.subtle.decrypt(
    {name: 'AES-GCM', iv: bytes.slice(0, 12)}, await key(secret), bytes.slice(12))));
  if (!Number.isFinite(payload.expires) || payload.expires < Date.now()) throw new Error('Expired token');
  return payload;
}

export async function rewriteManifest(text, upstream, origin, env, expires = Date.now() + 20 * 60 * 1000) {
  if (!text.trimStart().startsWith('#EXTM3U')) throw new Error('Invalid manifest');
  async function rewrite(uri) {
    if (uri.startsWith('data:')) return uri;
    const target = checkUpstream(new URL(uri, upstream), env);
    return `${origin}/part/${await seal(target.href, env.RELAY_KEY, expires, true)}`;
  }
  const output = [];
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) { output.push(line); continue; }
    if (!line.startsWith('#')) { output.push(await rewrite(line.trim())); continue; }
    // HLS keys, maps, audio tracks and subtitles use URI attributes.
    const matches = [...line.matchAll(/URI="([^"]+)"/g)];
    let rewritten = line;
    for (const match of matches) rewritten = rewritten.replace(match[0], `URI="${await rewrite(match[1])}"`);
    output.push(rewritten);
  }
  return output.join('\n');
}

async function upstreamFetch(url, env, request, transport) {
  let target = checkUpstream(url, env);
  for (let i = 0; i < 5; i++) {
    const headers = {'User-Agent': 'Mozilla/5.0'};
    if (request.headers.has('Range')) headers.Range = request.headers.get('Range');
    const response = await transport(target, {headers, redirect: 'manual',
      signal: AbortSignal.timeout(15000), cf: {cacheTtl: 0, cacheEverything: false}});
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('Location');
      await response.body?.cancel();
      if (!location) throw new Error('Invalid redirect');
      target = checkUpstream(new URL(location, target), env);
      continue;
    }
    return {response, target};
  }
  throw new Error('Too many redirects');
}

async function smallText(response) {
  const reader = response.body.getReader();
  const chunks = []; let total = 0;
  try {
    while (true) {
      const {value, done} = await reader.read();
      if (done) break;
      total += value.length;
      if (total > 512 * 1024) throw new Error('Manifest too large');
      chunks.push(value);
    }
  } catch (e) { await reader.cancel(); throw e; }
  const bytes = new Uint8Array(total); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return decoder.decode(bytes);
}

export default {
  async fetch(request, env, _ctx, transport = fetch) {
    const url = new URL(request.url);
    const headers = new Headers({'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN,
      'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Range',
      'Access-Control-Expose-Headers': 'Content-Range, Accept-Ranges',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Vary': 'Origin'});
    const reply = (body, status = 200) => new Response(body, {status, headers});
    const origin = request.headers.get('Origin');
    if (origin && origin !== env.ALLOWED_ORIGIN) return reply('Forbidden origin', 403);
    if (request.method === 'OPTIONS') return reply(null, 204);
    if (request.method !== 'GET') return reply('Method not allowed', 405);
    if (!env.RELAY_KEY || !env.UPSTREAM_CHANNELS) return reply('Relay not configured', 503);
    let stage = 'routing';
    try {
      const channels = JSON.parse(env.UPSTREAM_CHANNELS);
      if (url.pathname === '/catalog') {
        headers.set('Content-Type', 'application/json');
        return reply(JSON.stringify(Object.keys(names).filter(id => channels[id]).map(id =>
          ({name: names[id], url: `${url.origin}/live/${id}.m3u8`}))));
      }
      const live = url.pathname.match(/^\/live\/([a-z0-9-]+)\.m3u8$/);
      const part = url.pathname.match(/^\/part\/([A-Za-z0-9_-]+)$/);
      // The owner explicitly authorized up to 24 hours for playback sessions.
      let target; let expires = Date.now() + 24 * 60 * 60 * 1000;
      if (live && names[live[1]] && channels[live[1]]) target = channels[live[1]];
      else if (part) {
        try { const payload = await unsealPayload(part[1], env.RELAY_KEY); target = payload.url; expires = payload.expires; }
        catch { return reply('Invalid or expired media token', 403); }
      } else return reply('Not found', 404);
      stage = 'upstream';
      const result = await upstreamFetch(target, env, request, transport);
      const upstream = result.response;
      if (!upstream.ok) { headers.set('X-Relay-Upstream-Status', String(upstream.status)); await upstream.body?.cancel(); return reply('Channel unavailable', 502); }
      // Xtream redirects create a playback session. Pin playlist refreshes to
      // that resolved session instead of opening a new one every few seconds.
      // Child media URLs inherit this session expiry and remain stable.
      if (live) {
        await upstream.body?.cancel();
        headers.set('Location', `${url.origin}/part/${await seal(result.target.href, env.RELAY_KEY, expires)}`);
        return reply(null, 302);
      }
      const type = upstream.headers.get('Content-Type') || 'application/octet-stream';
      if (/mpegurl/i.test(type) || result.target.pathname.endsWith('.m3u8')) {
        stage = 'manifest';
        const text = await smallText(upstream);
        const manifest = await rewriteManifest(text, result.target.href, url.origin, env, expires);
        headers.set('Content-Type', 'application/vnd.apple.mpegurl');
        return reply(manifest);
      }
      headers.set('Content-Type', type);
      for (const h of ['Content-Length', 'Content-Range', 'Accept-Ranges'])
        if (upstream.headers.has(h)) headers.set(h, upstream.headers.get(h));
      // Stream segments without buffering video or caching paid content.
      return new Response(upstream.body, {status: upstream.status, headers});
    } catch {
      headers.set('X-Relay-Stage', stage);
      // Never return provider URLs, credentials, redirects or exception text.
      return reply('Channel temporarily unavailable', 502);
    }
  }
};
