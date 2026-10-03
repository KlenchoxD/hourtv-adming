import {createDecipheriv} from 'node:crypto';
const origin = 'https://hourtv-live-relay.hourtv-release-20261002.workers.dev';
for (const id of ['rcn', 'rcn-mas', 'rcn-hd2']) {
  let text = await (await fetch(`${origin}/live/${id}.m3u8`)).text();
  if (text.includes('#EXT-X-STREAM-INF')) text = await (await fetch(text.split('\n').find(l => l.startsWith('https:')))).text();
  const uri = text.split('\n').find(l => l.startsWith('https:'));
  let bytes = Buffer.from(await (await fetch(uri)).arrayBuffer());
  const aes = text.match(/#EXT-X-KEY:METHOD=AES-128,URI="([^"]+)".*IV=0x([0-9a-f]+)/i);
  if (aes) {
    const key = Buffer.from(await (await fetch(aes[1])).arrayBuffer());
    const cipher = createDecipheriv('aes-128-cbc', key, Buffer.from(aes[2], 'hex'));
    bytes = Buffer.concat([cipher.update(bytes), cipher.final()]);
  }
  const types = new Set();
  for (let off = 0; off + 188 <= bytes.length; off += 188) {
    const p = bytes.subarray(off, off + 188);
    if (p[0] !== 0x47 || !(p[1] & 0x40)) continue;
    const control = (p[3] >> 4) & 3;
    if (!(control & 1)) continue;
    let start = 4;
    if (control & 2) start += p[4] + 1;
    start += p[start] + 1;
    if (p[start] !== 2) continue;
    const len = ((p[start + 1] & 15) << 8) | p[start + 2];
    const infoLen = ((p[start + 10] & 15) << 8) | p[start + 11];
    for (let pos = start + 12 + infoLen; pos < start + 3 + len - 4 && pos + 5 <= 188;) {
      types.add(p[pos]); pos += 5 + ((p[pos + 3] & 15) << 8) + p[pos + 4];
    }
  }
  console.log({id, bytes:bytes.length, transportSync:bytes[0] === 71,
    streams:[...types].map(t => ({type:t, codec:({27:'H264',36:'HEVC',15:'AAC',3:'MP3',4:'MP3',2:'MPEG2'})[t] || 'other'}))});
}
