// Renderuje sceny z index.html (canvas) do PNG / GIF / MP4 przez Edge headless (CDP).
// Użycie:
//   node tools/concept_cn/render.mjs                 -> wszystkie sceny
//   node tools/concept_cn/render.mjs valley run      -> wybrane sceny
//   node tools/concept_cn/render.mjs --preview valley -> tylko klatka 0, mała skala (szybki podgląd)
// Klatki: %TEMP%/cn_frames/<scena>/, wyniki: art/source/sketches/cn_*.png|gif, mp4 w tools/concept_cn/out/.
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const sketches = path.join(root, 'art', 'source', 'sketches');
const outVid = path.join(here, 'out');
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const PORT = 9300 + Math.floor(Math.random() * 600);
const tmp = process.env.TEMP || process.env.TMP || '.';
const framesRoot = path.join(tmp, 'cn_frames');
const profile = path.join(tmp, 'cn_render_profile_' + PORT);

const args = process.argv.slice(2);
const preview = args.includes('--preview');
const only = args.filter((a) => !a.startsWith('--'));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const edge = spawn(EDGE, ['--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--hide-scrollbars', 'about:blank'], { stdio: 'ignore' });

async function getJSON(u) {
  for (let i = 0; i < 80; i++) {
    try { const r = await fetch(u); return await r.json(); } catch { await sleep(150); }
  }
  throw new Error('Edge CDP not reachable');
}

let ws;
let nextId = 0;
const pending = new Map();
function send(method, params = {}) {
  return new Promise((res) => { const id = ++nextId; pending.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
}
async function evaluate(expression) {
  const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (r.error) throw new Error(JSON.stringify(r.error));
  if (r.result.exceptionDetails) throw new Error(r.result.exceptionDetails.exception?.description || JSON.stringify(r.result.exceptionDetails));
  return r.result.result.value;
}

function ffmpeg(a) {
  const r = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...a], { stdio: 'inherit' });
  if (r.status !== 0) throw new Error('ffmpeg failed: ' + a.join(' '));
}

try {
  const list = await getJSON(`http://127.0.0.1:${PORT}/json/list`);
  const page = list.find((t) => t.type === 'page');
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
  await send('Runtime.enable');
  await send('Page.enable');
  await send('Page.navigate', { url: pathToFileURL(path.join(here, 'index.html')).href + '?render=1' });
  for (let i = 0; i < 100; i++) { try { if (await evaluate('!!window.CN_READY')) break; } catch { /* page loading */ } await sleep(100); }

  const all = await evaluate('Object.keys(SCENES)');
  const names = only.length ? only : all;
  fs.mkdirSync(outVid, { recursive: true });
  for (const name of names) {
    if (!all.includes(name)) { console.log('unknown scene', name); continue; }
    const info = await evaluate(`sceneInfo(${JSON.stringify(name)})`);
    const dir = path.join(framesRoot, name);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    const n = preview ? 1 : info.frames;
    const scale = preview ? 0.5 : info.scale;
    const t0 = Date.now();
    for (let i = 0; i < n; i++) {
      const frame = preview && info.previewFrame != null ? info.previewFrame : i;
      // duże klatki idą w kawałkach (jedna wiadomość CDP z kilkoma MB potrafi utknąć)
      const len = await evaluate(`(window.__f = renderFrame(${JSON.stringify(name)}, ${frame}, ${scale})).length`);
      let data = '';
      for (let a = 0; a < len; a += 400000) data += await evaluate(`window.__f.slice(${a}, ${a + 400000})`);
      fs.writeFileSync(path.join(dir, String(i).padStart(4, '0') + '.png'), Buffer.from(data.split(',')[1], 'base64'));
      if (process.env.CN_VERBOSE) console.log(name, i, len);
    }
    const file = info.file;
    if (preview) {
      fs.copyFileSync(path.join(dir, '0000.png'), path.join(framesRoot, `preview_${name}.png`));
      console.log(`${name}: preview -> ${path.join(framesRoot, `preview_${name}.png`)}`);
      continue;
    }
    if (info.frames === 1) {
      fs.copyFileSync(path.join(dir, '0000.png'), path.join(sketches, `${file}.png`));
    } else {
      const inp = ['-framerate', String(info.fps), '-i', path.join(dir, '%04d.png')];
      const gw = info.gifWidth || 960;
      ffmpeg([...inp, '-vf', `scale=${gw}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=${info.gifColors || 160}:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle`, '-loop', '0', path.join(sketches, `${file}.gif`)]);
      ffmpeg([...inp, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', '-movflags', '+faststart', path.join(outVid, `${file}.mp4`)]);
      // klatka-wizytówka do dokumentu
      const key = info.keyFrame ?? Math.floor(info.frames / 2);
      fs.copyFileSync(path.join(dir, String(key).padStart(4, '0') + '.png'), path.join(sketches, `${file}_frame.png`));
    }
    console.log(`${name}: ${n} frames in ${((Date.now() - t0) / 1000).toFixed(1)} s -> ${file}`);
  }
} finally {
  try { ws?.close(); } catch { /* ignore */ }
  // Edge headless zostawia procesy potomne: zabij całe drzewo
  spawnSync('taskkill', ['/PID', String(edge.pid), '/T', '/F'], { stdio: 'ignore' });
  await sleep(300);
  try { fs.rmSync(profile, { recursive: true, force: true }); } catch { /* zablokowane pliki: zostaw */ }
}
