// Isolated localhost-only verification. No production CORS changes, account
// sessions, credentials or third-party executable scripts are involved.
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {Readable} from 'node:stream';
const origin = 'https://hourtv-live-relay.hourtv-release-20261002.workers.dev';
createServer(async (req, res) => {
  try {
    const path = new URL(req.url, 'http://127.0.0.1').pathname;
    if (path === '/') {
      res.setHeader('Content-Type', 'text/html');
      res.end(await readFile(new URL('./browser-test.html', import.meta.url))); return;
    }
    if (path === '/vendor/hls.min.js') {
      res.setHeader('Content-Type', 'application/javascript');
      res.end(await readFile(new URL('../web/vendor/hls.min.js', import.meta.url))); return;
    }
    if (!/^\/relay\/(live\/(rcn|rcn-mas|rcn-hd2)\.m3u8|part\/[A-Za-z0-9_-]+)$/.test(path)) {
      res.writeHead(404); res.end(); return;
    }
    const response = await fetch(origin + path.slice('/relay'.length), {redirect:'manual'});
    res.statusCode = response.status;
    if (response.status === 302) {
      res.setHeader('Location', response.headers.get('Location').replace(origin, '/relay'));
      res.end(); return;
    }
    const type = response.headers.get('Content-Type') || 'application/octet-stream';
    res.setHeader('Content-Type', type);
    if (/mpegurl/i.test(type)) res.end((await response.text()).replaceAll(origin, '/relay'));
    else Readable.fromWeb(response.body).pipe(res);
  } catch { res.writeHead(502); res.end('Test transport failed'); }
}).listen(8788, '127.0.0.1', () => console.log('Isolated HLS test: http://127.0.0.1:8788'));
