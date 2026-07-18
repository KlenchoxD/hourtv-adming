// Resuelve un enlace embed (streamwish, vidhide, filemoon y clones con
// jwplayer empaquetado) a su .m3u8/.mp4 directo y redirige (302).
// Best-effort: algunos hosts caducan el enlace o exigen Referer que la app
// IPTV no envía, por lo que no todos funcionarán en reproductores externos.

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

function baseN(n, radix) {
  if (n === 0) return '0';
  const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
  const r = Math.max(2, Math.min(36, radix));
  let v = n;
  let s = '';
  while (v > 0) {
    s = digits[v % r] + s;
    v = Math.floor(v / r);
  }
  return s;
}

// Desempaqueta el clásico eval(function(p,a,c,k,e,d){...}('P',A,C,'W'.split('|')))
// mediante sustitución de texto (sin ejecutar código).
function unpack(js) {
  const m = js.match(
    /\}\s*\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\s*\.split\('\|'\)/s,
  );
  if (!m) return null;
  let payload = m[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
  const radix = parseInt(m[2], 10) || 36;
  const count = parseInt(m[3], 10) || 0;
  const words = m[4].split('|');
  for (let i = count - 1; i >= 0; i--) {
    if (i < words.length && words[i]) {
      payload = payload.replace(
        new RegExp('\\b' + baseN(i, radix) + '\\b', 'g'),
        words[i],
      );
    }
  }
  return payload;
}

function extractSource(html) {
  for (const text of [unpack(html), html]) {
    if (!text) continue;
    let m = text.match(/https?:\/\/[^"'\\ )]+\.(?:m3u8|mp4)[^"'\\ )]*/);
    if (m) return m[0];
    m = text.match(/["']?file["']?\s*:\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)["']/);
    if (m) return m[1];
  }
  return null;
}

async function resolve(embedUrl) {
  const origin = new URL(embedUrl).origin;
  const res = await fetch(embedUrl, {
    headers: { 'User-Agent': UA, Referer: origin + '/' },
    redirect: 'follow',
  });
  if (!res.ok) return null;
  const html = await res.text();
  let src = extractSource(html);
  if (!src) return null;
  if (src.startsWith('/')) src = origin + src;
  return src;
}

module.exports = async (req, res) => {
  const u = req.query && req.query.u;
  if (!u) {
    res.status(400).send('Falta el parámetro u');
    return;
  }
  try {
    const direct = await resolve(u);
    if (direct) {
      res.setHeader('Cache-Control', 'no-store');
      res.redirect(302, direct);
      return;
    }
    res.status(404).send('No se pudo resolver este enlace');
  } catch (e) {
    res.status(502).send('Error al resolver: ' + e.message);
  }
};
