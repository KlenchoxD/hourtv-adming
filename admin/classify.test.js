// Comprobación de la clasificación automática del panel: `node admin/classify.test.js`
//
// Los datos son respuestas reales de /api/tmdb?action=detail, recortadas a los
// campos que mira classify(). Van fijas a propósito: así la prueba corre sin
// clave de TMDB y sin red, y falla si alguien afloja una regla.
//
// Los casos negativos son los que importan. Anatomía de Grey tiene 465
// episodios y es drama: sin la comprobación de idioma acabaría en "novelas".
// Fatmagül lleva el género "Family" de TMDB: sin excluirlo, un drama sobre una
// agresión sexual acabaría en la fila "infantil".

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const from = html.indexOf('const TMDB_GENRE_CAT');
const to = html.indexOf('return [...cats];', from);
if (from < 0 || to < 0) throw new Error('No encuentro classify() en index.html');
eval(html.slice(from, html.indexOf('}', to) + 1));

const CASES = [
  ['Viuda Negra', {genreIds:[28,12,878],originCountry:['US'],originalLanguage:'en',year:2021,votes:11373,rating:7.2},
    ['accion','aventura','populares'], ['novelas','infantil','anime']],
  ['El Padrino', {genreIds:[18,80],originCountry:['US'],originalLanguage:'en',year:1972,votes:23218,rating:8.7},
    ['drama','antiguas','populares','recomendado'], ['infantil']],
  ['Coco', {genreIds:[10751,16,10402,12],originCountry:['US'],originalLanguage:'en',year:2017,votes:21163,rating:8.2},
    ['infantil','aventura'], ['anime','novelas']],
  ['Naruto', {genreIds:[16,10759,10765],originCountry:['JP'],originalLanguage:'ja',year:2002,votes:6060,rating:8.3},
    ['anime','accion','aventura'], ['infantil']],
  ['Peppa Pig', {genreIds:[16,10762],originCountry:['GB'],originalLanguage:'en',year:2004,votes:400,rating:6.9,episodes:492},
    ['infantil'], ['anime','novelas']],
  ['La Reina del Flow', {genreIds:[18,80],originCountry:['CO'],originalLanguage:'es',year:2018,votes:600,rating:7.9,episodes:237},
    ['novelas','drama','recomendado'], ['infantil']],
  // Telemundo: TMDB la registra como estadounidense, la salva el idioma.
  ['Pasión de gavilanes', {genreIds:[18],originCountry:['US'],originalLanguage:'es',year:2003,votes:2400,rating:7.4,episodes:270},
    ['novelas','drama','populares'], ['infantil']],
  ['Fatmagül', {genreIds:[10751,18],originCountry:['TR'],originalLanguage:'tr',year:2010,votes:300,rating:7.8,episodes:80},
    ['novelas','drama'], ['infantil']],
  // Negativos: series largas que NO son telenovelas.
  ['Anatomía de Grey', {genreIds:[18],originCountry:['US'],originalLanguage:'en',year:2005,votes:12000,rating:8.2,episodes:465},
    ['drama','populares','recomendado'], ['novelas','infantil']],
  ['Narcos', {genreIds:[80,18],originCountry:['US'],originalLanguage:'en',year:2015,votes:5000,rating:8.1,episodes:30},
    ['drama','populares','recomendado'], ['novelas']],
  ['El marginal', {genreIds:[80,18],originCountry:['AR'],originalLanguage:'es',year:2016,votes:300,rating:7.4,episodes:43},
    ['drama'], ['novelas','populares']],
];

let failed = 0;
for (const [name, info, expected, forbidden] of CASES) {
  const got = classify(info);
  const missing = expected.filter((c) => !got.includes(c));
  const extra = forbidden.filter((c) => got.includes(c));
  if (missing.length || extra.length) {
    failed++;
    console.error(
      `FALLO  ${name}\n  obtenido: ${got.join(', ') || '(ninguna)'}` +
        (missing.length ? `\n  falta:    ${missing.join(', ')}` : '') +
        (extra.length ? `\n  sobra:    ${extra.join(', ')}` : ''),
    );
  }
}

if (failed) {
  console.error(`\n${failed} de ${CASES.length} casos fallan.`);
  process.exit(1);
}
console.log(`Clasificación automática: ${CASES.length} casos correctos.`);
