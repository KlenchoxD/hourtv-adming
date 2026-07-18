// Genera una lista IPTV (M3U) a partir del catalog.json publicado en GitHub.
// Pega la URL de esta función en cualquier app de IPTV (TiviMate, IPTV
// Smarters, etc.) en los TV que no dejan instalar HourTV.
//
// - Streams directos (.m3u8/.mp4) y canales en vivo: van tal cual.
// - Embeds (streamwish, vidhide…): pasan por /api/resolve (best-effort).

const CATALOG_URL =
  'https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/catalog.json';

const DIRECT = /\.(m3u8|mp4|mkv|ts|mpd|webm|m4v)(\?|$)/i;

function esc(value) {
  return String(value == null ? '' : value).replace(/[\r\n,]+/g, ' ').trim();
}

// Grupo (categoría) para la app IPTV.
function movieGroup(movie) {
  const cats = (movie.categories || []).map((c) => String(c).toLowerCase());
  if (cats.includes('anime')) return 'Anime';
  if (cats.includes('infantil')) return 'Infantil';
  if (cats.includes('novela') || cats.includes('novelas')) return 'Novelas';
  return 'Películas';
}

function streamFor(base, url) {
  if (!url) return null;
  if (DIRECT.test(url)) return url; // directo: la app IPTV lo reproduce
  return base + '/api/resolve?u=' + encodeURIComponent(url); // embed: resolvedor
}

function entry(name, logo, group, stream) {
  return (
    '#EXTINF:-1 tvg-logo="' +
    esc(logo) +
    '" group-title="' +
    esc(group) +
    '",' +
    esc(name) +
    '\n' +
    stream +
    '\n'
  );
}

module.exports = async (req, res) => {
  try {
    const r = await fetch(CATALOG_URL + '?_=' + Date.now());
    const cat = r.ok ? await r.json() : { movies: [], series: [] };
    const base = 'https://' + req.headers.host;
    let out = '#EXTM3U\n';

    for (const m of cat.movies || []) {
      const url = m.servers && m.servers[0] && m.servers[0].url;
      const stream = streamFor(base, url);
      if (stream) out += entry(m.title, m.poster || m.logo, movieGroup(m), stream);
    }

    for (const s of cat.series || []) {
      const group = 'Series';
      for (const season of s.seasons || []) {
        for (const ep of season.episodes || []) {
          const url = ep.servers && ep.servers[0] && ep.servers[0].url;
          const stream = streamFor(base, url);
          if (!stream) continue;
          const label =
            s.title +
            ' · T' +
            (season.number || 1) +
            'E' +
            (ep.number || 1) +
            (ep.title ? ' ' + ep.title : '');
          out += entry(label, s.cover || s.poster, group, stream);
        }
      }
    }

    for (const ch of cat.liveChannels || []) {
      if (ch.url) out += entry(ch.name || ch.title, ch.logo, ch.group || 'Canales', ch.url);
    }

    res.setHeader('Content-Type', 'audio/x-mpegurl; charset=utf-8');
    res.setHeader('Content-Disposition', 'inline; filename="hourtv.m3u"');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.status(200).send(out);
  } catch (e) {
    res
      .status(500)
      .setHeader('Content-Type', 'audio/x-mpegurl; charset=utf-8');
    res.send('#EXTM3U\n# Error generando la lista: ' + e.message + '\n');
  }
};
