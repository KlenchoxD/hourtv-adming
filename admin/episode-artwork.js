(function(root, factory){
  const api = factory();
  if(typeof module === 'object' && module.exports) module.exports = api;
  else root.EpisodeArtwork = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function(){
  'use strict';
  const aliases = ['poster', 'backdrop', 'thumbnail', 'image', 'logo', 'still_url', 'stillUrl'];
  function imageUrl(value){
    const text = String(value || '').trim();
    if(!text) return '';
    let url;
    try{url = new URL(text);}catch(_){throw new Error('URL de miniatura no válida');}
    if(!['https:', 'http:'].includes(url.protocol) || url.username || url.password)
      throw new Error('La URL de miniatura debe ser HTTP o HTTPS');
    return text;
  }
  function existingImage(episode){
    for(const key of aliases){
      try{const url = imageUrl(episode[key]); if(url) return url;}catch(_){}
    }
    return '';
  }
  function metadata(episode){
    const copy = {...episode};
    delete copy.servers;
    return copy;
  }
  function saveEpisode(original, fields){
    const result = {...original, ...fields};
    for(const key of aliases) delete result[key];
    result.poster = imageUrl(fields.poster) || null;
    return result;
  }
  function preview(row){
    const input = row.querySelector('.ep-poster');
    const image = row.querySelector('.ep-preview');
    const empty = row.querySelector('.ep-empty');
    let url = '';
    try{url = imageUrl(input.value);}catch(_){}
    image.hidden = !url;
    empty.hidden = !!url;
    if(url) image.src = url;
    else image.removeAttribute('src');
  }
  function capture(root){
    // Capture identities and values before requesting: never overwrite edits made while loading.
    const sections = [...root.querySelectorAll('.season')].map(section => ({
      section, number: Number(section.querySelector('.snum').value),
      rows: [...section.querySelectorAll(':scope > .eps > .ep')].map(row => ({
        row, number: Number(row.querySelector('.nm').value), value: row.querySelector('.ep-poster').value
      }))
    }));
    return {root, sections};
  }
  async function refresh(root, fetchSeason, isCurrent = () => true, snapshot = capture(root)){
    const result = {updated: 0, cleared: 0, failures: [], skipped: 0};
    if(snapshot.root !== root) return result;
    const sections = snapshot.sections;
    for(const {section, number, rows} of sections){
      if(!isCurrent()) break;
      try{
        if(!Number.isSafeInteger(number) || number < 0) throw new Error('Número de temporada no válido');
        const data = await fetchSeason(number);
        if(data.seasonNumber !== number || !Array.isArray(data.episodes)) throw new Error('Respuesta de temporada no válida');
        const images = new Map();
        for(const episode of data.episodes){
          if(!Number.isSafeInteger(episode.number) || episode.number < 1 || images.has(episode.number))
            throw new Error('Numeración de episodios no válida');
          images.set(episode.number, imageUrl(episode.poster));
        }
        if(!isCurrent() || Number(section.querySelector('.snum').value) !== number) continue;
        for(const snapshot of rows){
          const {row} = snapshot;
          const input = row.querySelector('.ep-poster');
          if(!row.isConnected || input.value !== snapshot.value || Number(row.querySelector('.nm').value) !== snapshot.number){
            result.skipped++; continue;
          }
          // An unmatched episode is not evidence of a missing still: leave it for review.
          if(!images.has(snapshot.number)){result.skipped++; continue;}
          input.value = images.get(snapshot.number);
          preview(row);
          if(input.value) result.updated++; else result.cleared++;
        }
      }catch(error){result.failures.push({season: number, error: error.message});}
    }
    return result;
  }
  return {imageUrl, existingImage, metadata, saveEpisode, preview, capture, refresh};
});
