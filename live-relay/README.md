# HourTV live HTTPS relay

Web-only, targeted RCN playback overrides. Existing channel URLs remain the
catalog identity, so favourites and the guide are not migrated or duplicated.
Working RCN Novelas and Noticias RCN sources are untouched. HD2 retains its
original signal: it must not be replaced by the distinct main RCN channel.

Deploy with `wrangler deploy --config live-relay/wrangler.jsonc`.
Configure `RELAY_KEY` (32 random bytes) and `UPSTREAM_CHANNELS` as Worker secrets.
The latter is a JSON object keyed by `rcn`, `rcn-mas`, `rcn-hd2` with upstream
HLS URLs. Never commit these values or put them in the Flutter build.

Only explicitly configured hosts are allowed, including validated redirect
hosts. HLS variant, segment, key and map URLs use authenticated AES-GCM tokens
with 20-minute expiry; the browser cannot decode the provider credentials.
Redirect targets, upstream exception details and credentials are not logged
or returned. Video bodies are streamed, not buffered or cached.

HTTP IP origins and nonstandard ports use the Cloudflare TCP socket transport
because the Workers fetch API cannot directly address those origins. Every
redirect is still allowlisted. The transport bounds headers and chunk framing,
closes canceled playback connections, enforces read timeouts and preserves
byte ranges. HTTPS origins use normal fetch with certificate validation.

Run `node --test live-relay/worker.test.mjs live-relay/socket-http.test.mjs`.

Origin restrictions prevent use from other browser sites but are not user
authentication. The public player is intentionally accessible to HourTV users.
Provider connection limits still apply. This relay does not multiply the paid
account's four simultaneous connections or enable VOD. No paid plan is enabled
by this deployment. Monitor Workers quotas before broadening the channel list.
