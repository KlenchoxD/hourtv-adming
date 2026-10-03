import test from 'node:test';
import assert from 'node:assert/strict';
import {socketHttp} from './socket-http.mjs';
const encoder = new TextEncoder();

function fakeSocket(parts) {
  let request = ''; let closed = false;
  return {
    get request() { return request; }, get wasClosed() { return closed; },
    connect(address) {
      assert.deepEqual(address, {hostname:'example.com', port:4000});
      return {
        closed: Promise.resolve(),
        close: async () => { closed = true; },
        writable: new WritableStream({write(value) { request += new TextDecoder().decode(value); }}),
        readable: new ReadableStream({start(controller) {
          for (const part of parts) controller.enqueue(encoder.encode(part));
          controller.close();
        }})
      };
    }
  };
}
const url = new URL('http://example.com:4000/video.ts?token=private');
test('socket HTTP streams a fixed-length body and preserves range', async () => {
  const fake = fakeSocket(['HTTP/1.1 206 Partial Content\r\nContent-Length: 5\r\n',
    'Content-Type: video/mp2t\r\nContent-Range: bytes 0-4/10\r\n\r\nhe', 'llo']);
  const response = await socketHttp(url, {headers:{Range:'bytes=0-4'}}, fake.connect);
  assert.equal(response.status, 206);
  assert.equal(await response.text(), 'hello');
  assert.match(fake.request, /GET \/video.ts\?token=private HTTP\/1.0/);
  assert.match(fake.request, /Host: example.com:4000/);
  assert.match(fake.request, /Range: bytes=0-4/);
  assert.equal(fake.wasClosed, true);
});
test('chunk framing split across packets is decoded, not forwarded', async () => {
  const fake = fakeSocket(['HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r',
    '\nhe\r\n3;test=yes\r\n', 'llo\r', '\n0\r\n\r\n']);
  const response = await socketHttp(url, {headers:{}}, fake.connect);
  assert.equal(await response.text(), 'hello');
  assert.equal(response.headers.has('Transfer-Encoding'), false);
  assert.equal(fake.wasClosed, true);
});
test('EOF framing and redirects are supported', async () => {
  const fake = fakeSocket(['HTTP/1.0 302 Found\r\nLocation: /child.m3u8\r\n\r\nredirect']);
  const response = await socketHttp(url, {headers:{}}, fake.connect);
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('Location'), '/child.m3u8');
  assert.equal(await response.text(), 'redirect');
});
test('truncated bodies, invalid chunks and oversized headers fail closed', async () => {
  for (const content of [
    'HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nshort',
    'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nnothex\r\n',
  ]) {
    const fake = fakeSocket([content]);
    const response = await socketHttp(url, {headers:{}}, fake.connect);
    await assert.rejects(response.text());
    assert.equal(fake.wasClosed, true);
  }
  const fake = fakeSocket(['HTTP/1.1 200 OK\r\nHuge: ' + 'a'.repeat(20000)]);
  await assert.rejects(socketHttp(url, {headers:{}}, fake.connect));
  assert.equal(fake.wasClosed, true);
});
test('canceling playback closes the upstream socket', async () => {
  const fake = fakeSocket(['HTTP/1.0 200 OK\r\n\r\nsegment']);
  const response = await socketHttp(url, {headers:{}}, fake.connect);
  await response.body.cancel();
  assert.equal(fake.wasClosed, true);
});
