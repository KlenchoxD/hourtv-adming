// Proxy a TMDB (themoviedb.org) para el panel de administración.
//
// Por qué existe: la ficha (año, género, rating, sinopsis, reparto, carátula)
// y sobre todo LAS TENDENCIAS tienen que salir de una fuente real, no de
// marcarlas a mano. TMDB es gratis, tiene ficha en español y cubre películas,
// series, anime y telenovelas.
//
// La clave vive en la variable de entorno TMDB_KEY del proyecto de Vercel,
// así no viaja al navegador. Acepta tanto una API key v3 como un token v4.
//
// Acciones:
//   /api/tmdb?action=search&q=Matrix[&year=1999]
//   /api/tmdb?action=detail&type=movie|tv&id=603
//   /api/tmdb?action=trending[&window=day|week]

const BASE = 'https://api.themoviedb.org/3';
const IMG = 'https://image.tmdb.org/t/p';
const LANG = 'es-ES';

function auth() {
  const key = process.env.TMDB_KEY;
  if (!key) return null;
  // Los tokens v4 son JWT y van por cabecera; las api_key v3 van por query.
  return key.startsWith('eyJ')
    ? { header: { Authorization: 'Bearer ' + key } }
    : { query: 'api_key=' + encodeURIComponent(key) };
}

async function tmdb(path, params, a) {
  const qs = [a.query, 'language=' + LANG, params].filter(Boolean).join('&');
  const r = await fetch(BASE + path + '?' + qs, { headers: a.header || {} });
  if (!r.ok) throw new Error('TMDB ' + r.status + ' en ' + path);
  return r.json();
}

const img = (path, size) => (path ? IMG + '/' + size + path : null);

// Resultado de búsqueda, ya normalizado a lo que usa el panel.
function card(row) {
  const type = row.media_type || (row.title ? 'movie' : 'tv');
  if (type !== 'movie' && type !== 'tv') return null;
  const date = row.release_date || row.first_air_date || '';
  return {
    tmdbId: row.id,
    tmdbType: type,
    title: row.title || row.name || '',
    originalTitle: row.original_title || row.original_name || '',
    year: date ? Number(date.slice(0, 4)) : null,
    releaseDate: date || null,
    plot: row.overview || '',
    rating: row.vote_average ? Math.round(row.vote_average * 10) / 10 : null,
    votes: row.vote_count || 0,
    popularity: row.popularity || 0,
    poster: img(row.poster_path, 'w500'),
    backdrop: img(row.backdrop_path, 'w1280'),
    genreIds: row.genre_ids || [],
  };
}

module.exports = async (req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  const a = auth();
  if (!a) {
    return res.status(500).json({
      error:
        'Falta la clave de TMDB. Añade la variable de entorno TMDB_KEY en ' +
        'Vercel (Settings → Environment Variables) con tu API key de ' +
        'themoviedb.org y vuelve a desplegar.',
    });
  }

  const { action, q, year, type, id, window } = req.query;
  try {
    if (action === 'search') {
      if (!q) return res.status(400).json({ error: 'Falta el parámetro q.' });
      const params =
        'query=' +
        encodeURIComponent(q) +
        '&include_adult=false' +
        (year ? '&year=' + encodeURIComponent(year) : '');
      const data = await tmdb('/search/multi', params, a);
      const results = (data.results || []).map(card).filter(Boolean);
      return res.status(200).json({ results: results.slice(0, 12) });
    }

    if (action === 'detail') {
      if (!id || (type !== 'movie' && type !== 'tv')) {
        return res.status(400).json({ error: 'Faltan type (movie|tv) e id.' });
      }
      const data = await tmdb(
        '/' + type + '/' + id,
        'append_to_response=credits',
        a,
      );
      const base = card({ ...data, media_type: type });
      const crew = (data.credits && data.credits.crew) || [];
      const cast = (data.credits && data.credits.cast) || [];
      const runtime =
        data.runtime || (data.episode_run_time && data.episode_run_time[0]);
      return res.status(200).json({
        ...base,
        genres: (data.genres || []).map((g) => g.name),
        genreIds: (data.genres || []).map((g) => g.id),
        originCountry: data.origin_country || [],
        originalLanguage: data.original_language || '',
        duration: runtime ? runtime + ' min' : null,
        cast: cast
          .slice(0, 8)
          .map((c) => c.name)
          .join(', '),
        director: (
          crew.find((c) => c.job === 'Director') ||
          (data.created_by && data.created_by[0]) ||
          {}
        ).name,
        writer: (
          crew.find((c) => c.job === 'Screenplay' || c.job === 'Writer') || {}
        ).name,
        seasons: data.number_of_seasons || null,
        episodes: data.number_of_episodes || null,
      });
    }

    if (action === 'trending') {
      const w = window === 'day' ? 'day' : 'week';
      const data = await tmdb('/trending/all/' + w, '', a);
      const results = (data.results || []).map(card).filter(Boolean);
      return res.status(200).json({ window: w, results });
    }

    return res.status(400).json({ error: 'action debe ser search, detail o trending.' });
  } catch (e) {
    return res.status(502).json({ error: e.message });
  }
};
