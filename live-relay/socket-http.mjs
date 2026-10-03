const encoder = new TextEncoder();
const decoder = new TextDecoder();

// Minimal GET-only HTTP transport for allowlisted IPTV origins. Media remains
// streamed with backpressure; only bounded HTTP headers/chunk lines are buffered.
export async function socketHttp(url, options, connect) {
  if (url.protocol !== 'http:') throw new Error('HTTP transport only');
  const socket = connect({hostname: url.hostname, port: Number(url.port || 80)});
  socket.closed.catch(() => {});
  const reader = socket.readable.getReader();
  let buffered = new Uint8Array();
  let ended = false;
  const close = async () => { await socket.close().catch(() => {}); };
  async function read() {
    let timer;
    try {
      const result = await Promise.race([reader.read(), new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('Upstream read timeout')), 15000);
      })]);
      if (result.done) ended = true;
      return result;
    } finally { clearTimeout(timer); }
  }
  function append(bytes) {
    const next = new Uint8Array(buffered.length + bytes.length);
    next.set(buffered); next.set(bytes, buffered.length); buffered = next;
  }
  async function line(limit = 16384) {
    while (true) {
      for (let i = 0; i < buffered.length - 1; i++) {
        if (buffered[i] === 13 && buffered[i + 1] === 10) {
          if (i > limit) throw new Error('HTTP line too large');
          const text = decoder.decode(buffered.slice(0, i));
          buffered = buffered.slice(i + 2); return text;
        }
      }
      if (buffered.length > limit || ended) throw new Error('Invalid HTTP line');
      const result = await read();
      if (!result.done) append(result.value);
    }
  }
  const onAbort = () => { void close(); };
  options.signal?.addEventListener('abort', onAbort, {once: true});
  function finish() {
    options.signal?.removeEventListener('abort', onAbort);
    void close();
  }
  try {
    const writer = socket.writable.getWriter();
    const headers = new Headers(options.headers);
    const range = headers.get('Range');
    if (range && !/^bytes=\d*-\d*(,\d*-\d*)*$/.test(range)) throw new Error('Invalid range');
    const request = `GET ${url.pathname}${url.search} HTTP/1.0\r\nHost: ${url.host}\r\n` +
      `User-Agent: Mozilla/5.0\r\nAccept: */*\r\nAccept-Encoding: identity\r\nConnection: close\r\n` +
      (range ? `Range: ${range}\r\n` : '') + '\r\n';
    await writer.write(encoder.encode(request));
    writer.releaseLock();
    const statusLine = await line();
    const match = statusLine.match(/^HTTP\/1\.[01] (\d{3})(?: |$)/);
    if (!match) throw new Error('Invalid HTTP status');
    const status = Number(match[1]);
    const responseHeaders = new Headers();
    let size = statusLine.length;
    while (true) {
      const header = await line(); size += header.length + 2;
      if (size > 65536) throw new Error('HTTP headers too large');
      if (!header) break;
      const colon = header.indexOf(':');
      if (colon < 1 || /^[ \t]/.test(header)) throw new Error('Invalid HTTP header');
      responseHeaders.append(header.slice(0, colon), header.slice(colon + 1).trim());
    }
    const encoding = responseHeaders.get('Content-Encoding');
    if (encoding && encoding !== 'identity') throw new Error('Unsupported encoding');
    const transfer = responseHeaders.get('Transfer-Encoding');
    if (transfer && transfer.toLowerCase() !== 'chunked') throw new Error('Unsupported transfer');
    const chunked = Boolean(transfer);
    const length = responseHeaders.get('Content-Length');
    if (length && !/^\d+$/.test(length)) throw new Error('Invalid content length');
    let remaining = length && !chunked ? Number(length) : null;
    let chunkRemaining = 0;
    let chunkEnd = false;
    // Body framing is decoded here, so do not expose hop-by-hop metadata.
    responseHeaders.delete('Transfer-Encoding'); responseHeaders.delete('Connection');
    if (chunked) responseHeaders.delete('Content-Length');
    if ([204, 304].includes(status)) { finish(); return new Response(null, {status, headers: responseHeaders}); }
    const body = new ReadableStream({
      async pull(controller) {
        try {
          if (chunked && chunkRemaining === 0) {
            if (chunkEnd && await line(2) !== '') throw new Error('Invalid chunk end');
            const chunkLine = await line(1024);
            const hex = chunkLine.split(';')[0];
            if (!/^[0-9a-f]+$/i.test(hex)) throw new Error('Invalid chunk length');
            chunkRemaining = parseInt(hex, 16);
            if (!Number.isSafeInteger(chunkRemaining)) throw new Error('Invalid chunk length');
            if (!chunkRemaining) { controller.close(); finish(); return; }
            chunkEnd = true;
          }
          if (remaining === 0) { controller.close(); finish(); return; }
          if (!buffered.length && !ended) {
            const result = await read();
            if (!result.done) buffered = result.value;
          }
          if (ended && !buffered.length) {
            if (chunked || remaining > 0) throw new Error('Truncated HTTP body');
            controller.close(); finish(); return;
          }
          const count = Math.min(buffered.length, chunked ? chunkRemaining : remaining ?? Infinity);
          controller.enqueue(buffered.slice(0, count));
          buffered = buffered.slice(count);
          if (chunked) chunkRemaining -= count;
          if (remaining !== null) remaining -= count;
        } catch (error) { controller.error(error); finish(); }
      },
      cancel() { finish(); }
    });
    return new Response(body, {status, headers: responseHeaders});
  } catch (error) { finish(); throw error; }
}
