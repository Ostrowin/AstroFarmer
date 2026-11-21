'use strict';
// Kadry z kamery TPP w prawdziwej perspektywie: ziemia jako płaszczyzna, obiekty skalowane f/d,
// rysowane od najdalszego do najbliższego. Jednostki świata: metry.

function Cam(H0, f, hc, cx = 960) {
  return {
    H0, f, hc, cx,
    p(X, h, d) { return [cx + (X * f) / d, H0 + (f * (hc - h)) / d, f / d]; },
    gy(d) { return H0 + (f * hc) / d; },
    k(d) { return f / d; },
  };
}
function groundBands(ctx, cam, cols, ds = [90, 40, 22, 13, 8, 5]) {
  cols.forEach((c, i) => { const y = cam.gy(ds[i]); ctx.fillStyle = c; ctx.fillRect(0, y, W, H - y); });
}
function depthDraw(list) { list.sort((a, b) => b.d - a.d).forEach((o) => o.fn()); }
const GROUND_NIGHT = ['#1c1744', '#19153d', '#161236', '#13102f', '#100d29', '#0c0a22'];

// typowa łąka nocą: drzewa-grzyby, kępy trawy, mech; dodaje elementy do listy głębi
function meadowStuff(L, ctx, cam, t, o = {}) {
  const r = mulberry32(o.seed ?? 3);
  const fogC = o.fog ?? PAL.mtnMid;
  const fg = (d) => clamp((d - 8) / 50) * 0.8;
  const avoid = o.avoid || (() => false);
  for (let i = 0; i < (o.trees ?? 10); i++) {
    const X = (r() > 0.5 ? 1 : -1) * (6 + r() * 22), d = 12 + r() * 50, sc = 0.8 + r() * 0.6, gc = [PAL.cyan, PAL.violet, PAL.mint][i % 3], seed = i;
    if (avoid(X, d)) continue;
    L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); const f = fg(d); mushTree(ctx, x, y, (7 * sc * k) / 300, { trunk: mix('#0d0b26', fogC, f), cap: mix('#110e2e', fogC, f), capLit: mix('#221c55', PAL.mtnMidLit, f), glow: gc, glowAmt: 1 - f * 0.5, seed, lean: X > 0 ? -0.08 : 0.08 }); } });
  }
  for (let i = 0; i < (o.moss ?? 8); i++) {
    const X = (r() - 0.5) * 34, d = 9 + r() * 40, rr = 1.5 + r() * 3, c = [PAL.cyan, PAL.mint, PAL.violet][i % 3];
    if (avoid(X, d)) continue;
    L.push({ d: d + 100, fn: () => { const [x, y, k] = cam.p(X, 0, d); const rx = rr * k, ry = (rx * cam.hc) / d; screenFill(ctx, c, 0.1 * (1 - fg(d)), () => ctx.ellipse(x, y, rx, ry, 0, 0, TAU)); screenFill(ctx, c, 0.12 * (1 - fg(d)), () => ctx.ellipse(x, y, rx * 0.55, ry * 0.55, 0, 0, TAU)); } });
  }
  for (let i = 0; i < (o.grass ?? 120); i++) {
    const X = (r() - 0.5) * (o.grassW ?? 30), d = (o.grassD0 ?? 3.6) + Math.pow(r(), 1.6) * 40, sc = 0.7 + r() * 0.6, tip = r() > 0.8 ? (o.tip2 ?? PAL.mint) : (o.tip ?? PAL.cyan), seed = i;
    if (avoid(X, d)) continue;
    L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); if (x < -200 || x > W + 200) return; const f = fg(d); grassClump(ctx, x, y, (0.45 * sc * k) / 75, t, { seed, base: mix(o.grassBase ?? '#07061a', GROUND_NIGHT[0], f), tip, glow: (1 - f * 0.6) * (o.glow ?? 1), blades: d > 22 ? 4 : 7, wave: o.boost ? () => o.boost(X, d) : undefined }); } });
  }
}
function farHorizon(ctx, cam, t, o = {}) {
  const c1 = o.m1 ?? '#201a4c', c2 = o.m2 ?? '#2b2462', ledge = o.ledge ?? '#352d72';
  crystalMountain(ctx, o.mx1 ?? 380, cam.H0 + 14, 520, 190, c1, c2, 3, { glow: 0.9, ledge, crystalCount: 3, steps: 3, crystalCol: o.cc });
  crystalMountain(ctx, o.mx2 ?? 1380, cam.H0 + 14, 640, 240, c1, c2, 6, { glow: 0.9, ledge, steps: 3, crystalCol: o.cc });
  crystalMountain(ctx, o.mx3 ?? 880, cam.H0 + 16, 360, 140, c1, c2, 9, { glow: 0.9, ledge, steps: 3, crystalCount: 3, crystalCol: o.cc });
  hillBand(ctx, cam.H0 + 12, 7, o.hill ?? PAL.mtnMid, 4, 0.003);
}
function hudBase(ctx, o = {}) {
  hudBox(ctx, 40, 36, 150, 62);
  hudText(ctx, 115, 68, o.clock ?? '22:15', 30, PAL.white, 'center');
  if (o.note) hudText(ctx, 44, 128, o.note, 22, '#cfc8ff');
  const icons = o.icons ?? ['berry', 'crystal', 'snap', 'boom', 'mist', 'can', 'fert', 'fence'];
  const n = icons.length, sw = 92, x0 = 960 - (n * sw) / 2;
  icons.forEach((ic, i) => {
    const x = x0 + i * sw, y = 968, sel = i === (o.sel ?? 0);
    hudBox(ctx, x, y, 80, 80, '#1b1640', sel ? PAL.lemon : PAL.ink);
    if (sel) { ctx.beginPath(); ctx.roundRect(x, y, 80, 80, 14); ctx.lineWidth = 6; ctx.strokeStyle = PAL.lemon; ctx.stroke(); }
    hudText(ctx, x + 14, y + 16, String(i + 1), 15, '#cfc8ff');
    const cx = x + 40, cy = y + 46;
    const col = { berry: PAL.violet, crystal: PAL.cyan, snap: '#5fd06f', boom: '#ef5a2f', mist: '#bfe8ff', can: '#6f8de0', fert: '#a0703a', fence: '#c79a62' }[ic];
    if (ic === 'can') { inked(ctx, () => path(ctx, [[cx - 16, cy - 10, 0], [cx + 10, cy - 10, 0], [cx + 12, cy + 16, 0], [cx - 18, cy + 16, 0]]), col, 3.5); stroke(ctx, PAL.ink, 5, () => poly(ctx, [[cx + 10, cy - 4], [cx + 24, cy - 14]], false)); }
    else if (ic === 'fence') { for (const dx of [-10, 10]) inked(ctx, () => poly(ctx, [[cx + dx - 4, cy + 18], [cx + dx - 4, cy - 8], [cx + dx, cy - 18], [cx + dx + 4, cy - 8], [cx + dx + 4, cy + 18]]), col, 3); }
    else if (ic === 'crystal') { inked(ctx, () => poly(ctx, [[cx - 9, cy + 16], [cx, cy - 20], [cx + 9, cy + 16]]), col, 3.5); }
    else { halo(ctx, cx, cy, 22, col, 1, 0.2); inked(ctx, () => path(ctx, [[cx, cy - 18], [cx + 14, cy], [cx, cy + 16], [cx - 14, cy]]), col, 3.5); }
  });
}
function fencePost(ctx, cam, X, d) {
  const [x, y, k] = cam.p(X, 0, d), w = 0.14 * k, h = 1.15 * k;
  fill(ctx, '#2c1d32', () => poly(ctx, [[x - w / 2, y], [x - w / 2, y - h], [x, y - h - w * 1.6], [x + w / 2, y - h], [x + w / 2, y]]));
  fill(ctx, '#4a3346', () => poly(ctx, [[x, y], [x, y - h - w * 1.6], [x + w / 2, y - h], [x + w / 2, y]]));
}
// pole w perspektywie: kafle 1x1 m z uprawami
function field(L, ctx, cam, X0, X1, d0, d1, t, cropFn) {
  for (let dz = d1 - 1; dz >= d0; dz--) {
    L.push({ d: dz + 0.999, fn: () => {
      for (let X = X0; X < X1; X++) {
        const g = 0.07;
        const a = cam.p(X + g, 0, dz + 1 - g), b = cam.p(X + 1 - g, 0, dz + 1 - g), c = cam.p(X + 1 - g, 0, dz + g), e = cam.p(X + g, 0, dz + g);
        fill(ctx, '#2b1830', () => poly(ctx, [a, b, c, e]));
        for (let q = 1; q < 3; q++) { const zz = dz + q / 3; const l = cam.p(X + 0.12, 0, zz), rr = cam.p(X + 0.88, 0, zz); stroke(ctx, '#3d2340', Math.max(1, 0.04 * cam.k(zz)), () => poly(ctx, [l, rr], false)); }
      }
    } });
    for (let X = X0; X < X1; X++) { const dd = dz + 0.5; L.push({ d: dd, fn: () => cropFn(X + 0.5, dd, cam.p(X + 0.5, 0, dd)) }); }
  }
}

// ======================================================================
// 9. Baza nocą zza pleców
// ======================================================================
SCENES.tppBase = {
  file: 'cn_9_tpp_base_night',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(410, 1100, 2.8);
    nightSky(ctx, 1.1, { moon: [1540, 150, 84], moon2: [300, 110, 26], horizon: cam.H0 });
    farHorizon(ctx, cam, t);
    groundBands(ctx, cam, GROUND_NIGHT);
    const L = [];
    const inField = (X, d) => X > -4.2 && X < 5.6 && d > 6.2 && d < 18.5;
    const nearHut = (X, d) => Math.abs(X + 8) < 5 && Math.abs(d - 15) < 4;
    meadowStuff(L, ctx, cam, 1.1, { seed: 4, trees: 12, avoid: (X, d) => inField(X, d) || nearHut(X, d) || (Math.abs(X - 7) < 3 && d > 20 && d < 28) });
    // chatka, brama, traktor
    L.push({ d: 15, fn: () => { const [x, y, k] = cam.p(-8.5, 0, 15); screenFill(ctx, PAL.amber, 0.1, () => ctx.ellipse(x - 60 * k / 30, y + 4, 4 * k, 4 * k * cam.hc / 15, 0, 0, TAU)); Props.hut(ctx, x, y, (9 * k) / 450, { t: 1.1 }); } });
    L.push({ d: 25, fn: () => { const [x, y, k] = cam.p(7.2, 0, 25); Props.gate(ctx, x, y, (6 * k) / 300, 1.1); } });
    L.push({ d: 12, fn: () => { const [x, y, k] = cam.p(9.5, 0, 12); Props.tractor(ctx, x, y, (4.5 * k) / 230, 1.1, { dir: -1, body: night('#f39a2c', 0.45), bodyLit: '#f7a948' }); } });
    for (let d = 6.5; d <= 18; d += 1.4) { L.push({ d, fn: () => fencePost(ctx, cam, -4.6, d) }); L.push({ d, fn: () => fencePost(ctx, cam, 6, d) }); }
    // pole z uprawami
    field(L, ctx, cam, -4, 5, 7, 18, t, (X, d, [x, y, k]) => {
      const kind = (Math.floor(X + 10) + Math.floor(d)) % 4;
      if (kind === 0) Critters.voidberry(ctx, x, y, (0.7 * k) / 75, 1.1, { seed: Math.floor(X * 7 + d) });
      else if (kind === 1) Critters.moonpetal(ctx, x, y, (0.6 * k) / 90, 1.1);
      else if (kind === 2) crystal(ctx, x, y, 0.6 * k, 0.2 * k, (X - 0.5) * 0.06, 1);
      else Critters.boomshroom(ctx, x, y, (0.5 * k) / 146, { look: NIGHT_LOOK, spotGlow: true, seed: Math.floor(d) });
    });
    // dron z wodą nad polem
    L.push({ d: 12.5, fn: () => { const [x, y, k] = cam.p(1.5, 4.4, 12.5); const s = (0.9 * k) / 100; Props.drone(ctx, x, y, s, 1.1, { beamLen: (cam.gy(12.5) - y) / s }); } });
    // farmer
    L.push({ d: 5.4, fn: () => {
      const [x, y, k] = cam.p(-0.5, 0, 5.4);
      screenFill(ctx, PAL.cyan, 0.1, () => ctx.ellipse(x, y, 0.8 * k, (0.8 * k * cam.hc) / 5.4, 0, 0, TAU));
      const a = Farmer.back(ctx, x, y, (1.8 * k) / 330, {}, { ...NIGHT_LOOK, lw: 6 });
      const [sx, sy, sk] = cam.p(0.6, 0, 11);
      screenFill(ctx, PAL.lemon, 0.09, () => poly(ctx, [[a.lamp[0] - 6, a.lamp[1]], [a.lamp[0] + 6, a.lamp[1]], [sx + 2.2 * sk, sy], [sx - 2.2 * sk, sy]]));
      screenFill(ctx, PAL.lemon, 0.1, () => ctx.ellipse(sx, sy, 2.3 * sk, (2.3 * sk * cam.hc) / 11, 0, 0, TAU));
    } });
    depthDraw(L);
    fireflies(ctx, 12, 34, [60, 360, 1860, 900], 1.1, PAL.lemon, { size: 3 });
    hudBase(ctx, { clock: '22:15', note: 'Raid in 2 cycles', sel: 3 });
    grain(ctx, 0.04);
  },
};

// ======================================================================
// 10. Las grzybowy zza pleców (kamera lekko w górę)
// ======================================================================
let _myc3 = null;
function myceliumWorld(cam) {
  if (_myc3) return _myc3;
  const r = mulberry32(8);
  const threads = [], hearts = [[0.8, 11], [-6, 21], [7, 26]];
  const make = (X, D, ang, len, w, d0, hi, depth) => {
    const pts = [cam.p(X, 0, D)], ds = [d0];
    let x = X, z = D, d = d0, a = ang;
    for (let i = 0; i < len / 0.3; i++) {
      a += (r() - 0.5) * 0.3; x += Math.cos(a) * 0.3; z += Math.sin(a) * 0.3; d += 0.3;
      if (z < 3.2) { a = -a; z = 3.2; }
      pts.push(cam.p(x, 0, z)); ds.push(d);
      if (depth < 2 && i > 5 && r() < 0.05) make(x, z, a + (r() > 0.5 ? 1 : -1) * 0.7, len * 0.45, w * 0.6, d, hi, depth + 1);
    }
    threads.push({ pts, ds, w, hi, z: D });
  };
  hearts.forEach(([X, D], hi) => { for (let k = 0; k < 8; k++) make(X, D, (k / 8) * TAU + r() * 0.3, 7 + r() * 7, 3, 0, hi, 0); });
  _myc3 = { threads, hearts };
  return _myc3;
}
SCENES.tppForest = {
  file: 'cn_10_tpp_mushroom_forest',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(700, 1000, 1.9);
    const fogC = '#33225f';
    skyBands(ctx, ['#0b0820', '#110c2a', '#181136', '#201743', '#2a1d52', fogC], 0, cam.H0 + 20, 13, 6);
    // gwiazdy w szczelinach między kapeluszami
    stars(ctx, 5, 90, 0, 300, 1);
    groundBands(ctx, cam, ['#2a1d52', '#211644', '#1a1138', '#140d2e', '#0f0a24', '#0a071a'], [70, 35, 20, 12, 7, 4.5]);
    const L = [];
    const fgK = (d) => clamp((d - 6) / 55);
    const caps = [[-9, 12, 1.15], [7.5, 10, 1], [-2.5, 27, 1], [12, 31, 1.3], [-17, 35, 1.1], [3, 50, 1], [-10, 62, 1.2], [21, 56, 1], [-28, 24, 1], [26, 17, 1.2], [-5, 80, 1], [14, 90, 1.1]];
    caps.forEach(([X, d, sz], i) => {
      L.push({ d, fn: () => {
        const fg = fgK(d);
        const hCap = 22 * sz, R = 9 * sz, w = 1.5 * sz;
        const [cx, cy, k] = cam.p(X, hCap, d);
        const rx = R * k, ry = rx * clamp((hCap - cam.hc) / d, 0.1, 0.55);
        if (cy + ry > -50) gillsUnder(ctx, cx, cy, rx, ry, 1, mix(PAL.cyan, fogC, fg * 0.5), 0.85 - fg * 0.45, i);
        const [bx, by] = cam.p(X, 0, d);
        const tw = w * k, trunk = mix('#130c2e', fogC, fg * 0.85), lit = mix('#2a1c56', fogC, fg * 0.7);
        fill(ctx, trunk, () => path(ctx, [[bx - tw * 1.5, by, 0], [bx - tw * 0.75, by - tw * 1.8], [cx - tw * 0.45, cy + ry * 0.3, 0], [cx + tw * 0.45, cy + ry * 0.3, 0], [bx + tw * 0.75, by - tw * 1.8], [bx + tw * 1.7, by, 0]]));
        fill(ctx, lit, () => path(ctx, [[bx + tw * 0.25, by - tw * 1.2], [cx + tw * 0.15, cy + ry * 0.3, 0], [cx + tw * 0.45, cy + ry * 0.3, 0], [bx + tw * 0.75, by - tw * 1.8], [bx + tw * 1.7, by, 0], [bx + tw * 0.9, by, 0]]));
        fill(ctx, mix(trunk, PAL.cyan, 0.3 * (1 - fg)), () => poly(ctx, [[cx - tw * 0.45, cy + ry * 0.3], [cx + tw * 0.45, cy + ry * 0.3], [cx + tw * 0.5, cy + ry * 0.3 + tw * 3], [cx - tw * 0.2, cy + ry * 0.3 + tw * 5]]));
        // pierścień na trzonie
        const [, ryy] = cam.p(X, 13 * sz, d);
        const rw = lerp(tw * 0.75, tw * 0.45, 0.6);
        fill(ctx, lit, () => path(ctx, [[cx - rw * 2.2 + (bx - cx) * 0.4, ryy, 0], [cx + rw * 2.2 + (bx - cx) * 0.4, ryy, 0], [cx + rw * 1.4 + (bx - cx) * 0.4, ryy + tw * 0.5], [cx - rw * 1.4 + (bx - cx) * 0.4, ryy + tw * 0.5]]));
      } });
    });
    // dzwonkowe grzyby (magenta)
    for (const [X, d, h] of [[2.5, 16, 6], [-6, 19, 5], [9.5, 23, 7], [-13, 14, 5.5]]) {
      L.push({ d, fn: () => {
        const [bx, by, k] = cam.p(X, 0, d), [cx, cy] = cam.p(X + 0.3, h, d), s = k / 80, fg = fgK(d);
        stroke(ctx, mix('#3a2468', fogC, fg), 0.25 * k, () => path(ctx, [[bx, by], [bx + 0.3 * k, lerp(by, cy, 0.5)], [cx, cy]], false));
        halo(ctx, cx, cy + 10 * s, 130 * s, PAL.magenta, 3, 0.07);
        fill(ctx, mix('#45286f', fogC, fg), () => path(ctx, [[cx - 90 * s, cy + 30 * s, 0], [cx - 70 * s, cy - 40 * s], [cx, cy - 70 * s], [cx + 70 * s, cy - 40 * s], [cx + 90 * s, cy + 30 * s, 0], [cx, cy + 14 * s]]));
        fill(ctx, PAL.magenta, () => path(ctx, [[cx - 90 * s, cy + 30 * s, 0], [cx, cy + 14 * s], [cx + 90 * s, cy + 30 * s, 0], [cx, cy + 44 * s]]));
        fill(ctx, mix('#6a3fa0', fogC, fg), () => path(ctx, [[cx - 70 * s, cy - 40 * s], [cx, cy - 70 * s], [cx + 70 * s, cy - 40 * s], [cx + 40 * s, cy - 50 * s], [cx, cy - 56 * s]]));
        const rr = mulberry32(Math.floor(d * 10));
        for (let q = 0; q < 10; q++) { const yy = cy + 40 * s + rr() * 300 * s; fill(ctx, PAL.rose, () => ctx.arc(cx + (rr() - 0.5) * 140 * s, yy, 2.2, 0, TAU), 1 - (yy - cy) / (340 * s)); }
      } });
    }
    // kałuże
    for (const [X, d, rr] of [[-2.5, 8, 1.6], [4.5, 13, 2.2], [-8, 17, 2]]) L.push({ d: d + 100, fn: () => { const [x, y, k] = cam.p(X, 0, d); const rx = rr * k, ry = (rx * cam.hc) / d; fill(ctx, '#160f38', () => ctx.ellipse(x, y, rx, ry, 0, 0, TAU)); fill(ctx, mix('#160f38', PAL.cyan, 0.45), () => ctx.ellipse(x - rx * 0.2, y, rx * 0.5, ry * 0.18, 0, 0, TAU)); fill(ctx, mix('#160f38', PAL.magenta, 0.4), () => ctx.ellipse(x + rx * 0.35, y + ry * 0.2, rx * 0.2, ry * 0.1, 0, 0, TAU)); } });
    // grzybnia na ziemi (komety światła)
    L.push({ d: 1000, fn: () => {
      const M = myceliumWorld(cam);
      const fronts = [6.5, 10, 3.5];
      for (const th of M.threads) { ctx.beginPath(); subPath(ctx, th, 0, 1e9); ctx.lineWidth = Math.max(1, (th.w * 0.6 * 6) / th.z); ctx.strokeStyle = '#1b3a58'; ctx.lineCap = 'round'; ctx.stroke(); }
      for (const th of M.threads) {
        const fr = fronts[th.hi], wz = (8 / th.z) * th.w;
        ctx.beginPath(); subPath(ctx, th, fr - 3, fr - 0.8); ctx.lineWidth = wz * 0.6 + 0.8; ctx.strokeStyle = mix('#1b3a58', PAL.cyan, 0.45); ctx.stroke();
        ctx.beginPath(); subPath(ctx, th, fr - 0.8, fr - 0.25); ctx.lineWidth = wz + 1.5; ctx.strokeStyle = mix('#1b3a58', PAL.cyan, 0.9); ctx.stroke();
        ctx.beginPath(); subPath(ctx, th, fr - 0.25, fr); ctx.lineWidth = wz + 3; ctx.strokeStyle = '#e4fffc'; ctx.stroke();
        const hp = threadPoint(th, fr); if (hp) halo(ctx, hp[0], hp[1], 10 + wz * 4, PAL.cyan, 2, 0.22, 0.5);
      }
      M.hearts.forEach(([X, D]) => { const [x, y, k] = cam.p(X, 0, D); halo(ctx, x, y, 1.6 * k, PAL.cyan, 3, 0.1, 0.35); fill(ctx, mix('#1b3a58', PAL.cyan, 0.7), () => ctx.ellipse(x, y, 0.7 * k, (0.7 * k * cam.hc) / D, 0, 0, TAU)); });
    } });
    // świecące grzybki przy ziemi
    const rg = mulberry32(19);
    for (let i = 0; i < 26; i++) {
      const X = (rg() - 0.5) * 26, d = 4.5 + Math.pow(rg(), 1.4) * 30;
      L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); const s = k / 60; for (let q = 0; q < 4; q++) { const gx = x + (q - 1.5) * 10 * s, gy = y - (q % 2) * 3 * s; stroke(ctx, '#2c4a3c', 3 * s, () => poly(ctx, [[gx, gy], [gx + 1, gy - 16 * s]], false)); halo(ctx, gx + 1, gy - 18 * s, 14 * s, PAL.mint, 2, 0.16); fill(ctx, PAL.mint, () => path(ctx, [[gx - 7 * s, gy - 15 * s, 0], [gx + 1, gy - 23 * s], [gx + 9 * s, gy - 15 * s, 0]])); } } });
    }
    // farmer z latarką skierowaną w górę
    L.push({ d: 4.6, fn: () => {
      const [x, y, k] = cam.p(0.3, 0, 4.6);
      screenFill(ctx, PAL.cyan, 0.12, () => ctx.ellipse(x, y, 0.7 * k, (0.7 * k * cam.hc) / 4.6, 0, 0, TAU));
      const a = Farmer.back(ctx, x, y, (1.8 * k) / 330, {}, { ...NIGHT_LOOK, lw: 6, rims: [{ c: PAL.cyan, lx: 0, ly: 1, w: 8 }, { c: PAL.magenta, lx: 1, ly: -0.3, w: 5 }] });
      const [tx, ty] = cam.p(7.5, 7, 10);
      screenFill(ctx, PAL.lemon, 0.09, () => poly(ctx, [[a.lamp[0] - 6, a.lamp[1]], [a.lamp[0] + 6, a.lamp[1]], [tx + 120, ty + 60], [tx - 40, ty - 60]]));
      screenFill(ctx, PAL.lemon, 0.12, () => ctx.ellipse(tx + 40, ty, 70, 90, 0.3, 0, TAU));
    } });
    depthDraw(L);
    // bliski kapelusz nad głową i zarodniki
    gillsUnder(ctx, 700, -180, 1250, 330, 1, PAL.cyan, 0.85, 7);
    const rr = mulberry32(3);
    for (let i = 0; i < 160; i++) { const x = rr() * W, y = 120 + Math.pow(rr(), 1.3) * 700; ctx.globalAlpha = 1 - (y - 120) / 760; ctx.fillStyle = rr() > 0.85 ? PAL.mint : '#bffcf5'; ctx.fillRect(x, y, 3, 3); ctx.globalAlpha = 1; }
    Critters.lumimoth(ctx, 1380, 430, 0.42, 0.2);
    drawHud(ctx, 0, { clock: '23:05', hp: 0.9, awake: 0.12, bag: '5/10' });
    grain(ctx, 0.04);
  },
};

// ======================================================================
// 11. Walka zza pleców: Thornback szarżuje, pułapki działają
// ======================================================================
SCENES.tppFight = {
  file: 'cn_11_tpp_fight',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(430, 1100, 2.6);
    skyBands(ctx, ['#0f0d2b', '#171238', '#211848', '#2f1d58', '#432266', '#5a2a6e'], 0, cam.H0, 7, 8);
    cloudStreak(ctx, 120, 230, 820, 18, '#2c1d58'); cloudStreak(ctx, 900, 300, 900, 16, '#3b2268'); cloudStreak(ctx, 400, 380, 700, 12, '#4d2a72');
    stars(ctx, 41, 120, 0, cam.H0, 1);
    moon(ctx, 260, 140, 70, PAL.moon, PAL.moonShade, { phase: -0.5, seed: 3 });
    farHorizon(ctx, cam, t, { mx1: 300, mx2: 1500 });
    groundBands(ctx, cam, GROUND_NIGHT);
    const L = [];
    meadowStuff(L, ctx, cam, 1.4, { seed: 9, trees: 10, avoid: (X, d) => Math.abs(X) < 6 && d < 18 && d > 6 });
    const look = { ...NIGHT_LOOK, lw: 6 };
    // Thornback w szarży
    L.push({ d: 15, fn: () => {
      const [x, y, k] = cam.p(3, 0, 15), s = (2.4 * k) / 240;
      for (let i = 0; i < 6; i++) fill(ctx, '#2a2258', () => circle(ctx, x + (90 + i * 26) * s * 1.6, y - 10 * s - (i % 2) * 18 * s, (22 - i * 2) * s * 1.6), 0.8);
      Critters.thornback(ctx, x, y, s, -1, { look: { ...look, lw: 6 }, t: 0, jaw: 0.4 });
      sparkle(ctx, x - 40 * s, y - 150 * s, 48 * s, PAL.lemon); sparkle(ctx, x - 40 * s, y - 150 * s, 26 * s, '#ffffff');
    } });
    // Muncherzy, Snapper i Boomshroom
    const mun = [[-1.8, 10.5, 20], [1.1, 8.6, 0], [4.2, 9.8, 30]];
    mun.forEach(([X, d, hop]) => L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); Critters.muncher(ctx, x, y - hop * k / 60, (0.6 * k) / 72, X > 0 ? -1 : 1, { look }); } }));
    L.push({ d: 9.4, fn: () => {
      const [x, y, k] = cam.p(2.6, 0, 9.4), s = (1.3 * k) / 190;
      Critters.snapper(ctx, x, y, s, 0.2, { look, innerGlow: true, open: 0.12, dir: -1 });
      Critters.muncher(ctx, x - 40 * s, y - 120 * s, (0.6 * k) / 72, -1, { look, xEyes: true, spin: 0.6 });
      hudText(ctx, x - 40 * s, y - 220 * s, 'SNAP!', 30, PAL.rose, 'center');
    } });
    L.push({ d: 12, fn: () => { const [x, y, k] = cam.p(-2.8, 0, 12); halo(ctx, x, y - 0.5 * k, 1.4 * k, PAL.amber, 3, 0.08); Critters.boomshroom(ctx, x, y, (0.9 * k) / 146, { look, spotGlow: true, swell: 0.6, shake: 3 }); } });
    // farmer celuje
    L.push({ d: 5.2, fn: () => {
      const [x, y, k] = cam.p(-0.7, 0, 5.2);
      screenFill(ctx, PAL.cyan, 0.1, () => ctx.ellipse(x, y, 0.8 * k, (0.8 * k * cam.hc) / 5.2, 0, 0, TAU));
      const a = Farmer.back(ctx, x, y, (1.8 * k) / 330, { aim: 1 }, look);
      const [tx, ty] = cam.p(2.6, 1.3, 15);
      for (let i = 0; i < 3; i++) {
        const u0 = 0.15 + i * 0.27, u1 = u0 + 0.12;
        const x0 = lerp(a.gun[0], tx, u0), y0 = lerp(a.gun[1], ty, u0), x1 = lerp(a.gun[0], tx, u1), y1 = lerp(a.gun[1], ty, u1);
        halo(ctx, x1, y1, 16, PAL.lemon, 2, 0.2);
        stroke(ctx, PAL.lemon, 6 - i, () => poly(ctx, [[x0, y0], [x1, y1]], false));
        stroke(ctx, '#ffffff', 2, () => poly(ctx, [[lerp(x0, x1, 0.5), lerp(y0, y1, 0.5)], [x1, y1]], false));
      }
      sparkle(ctx, a.gun[0], a.gun[1] - 6, 40, PAL.lemon); sparkle(ctx, a.gun[0], a.gun[1] - 6, 20, '#ffffff');
    } });
    depthDraw(L);
    fireflies(ctx, 31, 20, [60, 380, 1860, 900], 1.4, PAL.lemon, { size: 3 });
    drawHud(ctx, 0, { clock: '01:20', hp: 0.56, awake: 0.64, bag: '7/10' });
    grain(ctx, 0.04);
  },
};

// ======================================================================
// 12. Ewakuacja: planeta się broni, bieg do kolumny światła
// ======================================================================
SCENES.tppEvac = {
  file: 'cn_12_tpp_evac',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(420, 1100, 2.6);
    skyBands(ctx, ['#14071d', '#210a28', '#330e33', '#4a143c', '#651b43', '#86264a'], 0, cam.H0, 21, 9);
    cloudStreak(ctx, 100, 210, 900, 20, '#3a0f36'); cloudStreak(ctx, 1000, 280, 820, 18, '#521741'); cloudStreak(ctx, 500, 370, 900, 14, '#6e2046');
    stars(ctx, 61, 60, 0, 300, 1);
    moon(ctx, 1640, 130, 60, '#ffb3a8', '#e07f7a', { phase: 0.4, seed: 2 });
    // meteory
    for (const [x, y, len] of [[1500, 40, 380], [1120, 10, 260], [600, 60, 300], [1780, 200, 200]]) {
      fill(ctx, PAL.amber, () => poly(ctx, [[x, y], [x - len, y + len * 0.7], [x - len + 6, y + len * 0.7 + 4], [x + 10, y + 8]]), 0.8);
      halo(ctx, x, y, 22, PAL.amber, 2, 0.3); fill(ctx, '#fff2d6', () => circle(ctx, x, y, 7));
    }
    farHorizon(ctx, cam, t, { m1: '#2a0f30', m2: '#3d1640', ledge: '#4a1c48', hill: '#2a0f2c', cc: ['#a3284a', '#ff5d6c', '#ffd0d4'] });
    groundBands(ctx, cam, ['#2c1230', '#24102a', '#1d0d24', '#170a1e', '#110818', '#0c0612']);
    // uderzenie meteoru w oddali
    { const [x, y, k] = cam.p(-14, 0, 40); halo(ctx, x, y - 20, 140, PAL.amber, 3, 0.12); for (let i = 0; i < 9; i++) { const a = -Math.PI * (0.1 + 0.8 * i / 8); fill(ctx, i % 2 ? PAL.amber : '#ffe1a0', () => poly(ctx, [[x, y], [x + Math.cos(a - 0.08) * 120, y + Math.sin(a - 0.08) * 120], [x + Math.cos(a + 0.08) * 120, y + Math.sin(a + 0.08) * 120]])); } }
    const L = [];
    // kolumna ewakuacji
    L.push({ d: 38, fn: () => {
      const [x, y, k] = cam.p(0.8, 0, 38);
      const w = 1.6 * k;
      halo(ctx, x, y, 7 * k, PAL.cyan, 3, 0.1, 0.3);
      screenFill(ctx, PAL.cyan, 0.16, () => poly(ctx, [[x - w * 1.8, y], [x + w * 1.8, y], [x + w * 1.2, 0], [x - w * 1.2, 0]]));
      screenFill(ctx, PAL.cyan, 0.3, () => poly(ctx, [[x - w, y], [x + w, y], [x + w * 0.7, 0], [x - w * 0.7, 0]]));
      fill(ctx, '#e8fffc', () => poly(ctx, [[x - w * 0.35, y], [x + w * 0.35, y], [x + w * 0.25, 0], [x - w * 0.25, 0]]));
      for (const h of [3, 8, 15]) { const [, ry] = cam.p(0.8, h, 38); stroke(ctx, '#d9fffb', 3, () => ctx.ellipse(x, ry, w * 2.6, w * 0.5, 0, 0, TAU)); }
      fill(ctx, '#2f2850', () => ctx.ellipse(x, y, w * 3, w * 0.5, 0, 0, TAU));
      fill(ctx, PAL.cyan, () => ctx.ellipse(x, y, w * 2, w * 0.3, 0, 0, TAU));
    } });
    meadowStuff(L, ctx, cam, 1.6, { seed: 12, trees: 9, tip: PAL.rose, tip2: PAL.magenta, fog: '#2a0f2c', grassBase: '#0e0512', avoid: (X, d) => Math.abs(X) < 1.5 && d < 30 });
    // pościg: sylwetki ze świecącymi oczami
    const dark = { night: true, amt: 0.95, into: '#12050f', lw: 6, rims: [{ c: PAL.rose, lx: 0.4, ly: -1, w: 6 }] };
    L.push({ d: 13, fn: () => { const [x, y, k] = cam.p(-6.5, 0, 13); Critters.thornback(ctx, x, y, (2.4 * k) / 240, 1, { look: dark, t: 0, jaw: 0.3, glow: true }); } });
    for (const [X, d] of [[5.2, 9], [7, 11.5], [-4.2, 8.2], [3.8, 14]]) L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); Critters.muncher(ctx, x, y - 10 * k / 60, (0.6 * k) / 72, X > 0 ? -1 : 1, { look: dark, eyeGlow: true }); } });
    // farmer w biegu + świecące ślady
    L.push({ d: 5.4, fn: () => {
      for (let i = 1; i < 5; i++) { const [x, y, k] = cam.p(i % 2 ? 0.18 : -0.18, 0, 5.4 - i * 0.55); if (y > H) continue; fill(ctx, mix('#2c1230', PAL.mint, 1 - i * 0.2), () => ctx.ellipse(x, y, 0.1 * k, 0.05 * k, 0, 0, TAU)); }
      const [x, y, k] = cam.p(0, 0, 5.4);
      Farmer.back(ctx, x, y, (1.8 * k) / 330, { phase: 0.9, run: 1, armSwing: 1.2 }, { ...NIGHT_LOOK, lw: 6, rims: [{ c: PAL.cyan, lx: 0, ly: -1, w: 7 }, { c: PAL.rose, lx: -0.8, ly: 0.5, w: 6 }] });
    } });
    depthDraw(L);
    // HUD z odliczaniem
    drawHud(ctx, 0, { clock: '03:48', hp: 0.38, awake: 1, bag: '10/10' });
    hudBox(ctx, 860, 140, 200, 74, '#5a1230', PAL.ink);
    hudText(ctx, 960, 178, '0:42', 44, '#ffd6dc', 'center');
    grain(ctx, 0.04);
  },
};

// ======================================================================
// 13. Traktor nocą zza pleców: siewnik i reflektory
// ======================================================================
function tractorBack(ctx, cam, X, d) {
  const [x, y, k] = cam.p(X, 0, d);
  const P = (dx, h) => [x + dx * k, cam.p(X, h, d)[1]];
  const orange = night('#f39a2c', 0.35), orangeLit = '#f7a948', dark = '#16132e', mid = '#28254f';
  // maska z przodu (dalej, wystaje nad siedzeniem)
  const [hx, hy, hk] = cam.p(X, 1.2, d + 1.6);
  fill(ctx, orange, () => poly(ctx, [[hx - 0.42 * hk, hy], [hx + 0.42 * hk, hy], [hx + 0.38 * hk, hy + 0.5 * hk], [hx - 0.38 * hk, hy + 0.5 * hk]]));
  fill(ctx, orangeLit, () => poly(ctx, [[hx - 0.42 * hk, hy], [hx + 0.42 * hk, hy], [hx + 0.4 * hk, hy + 0.08 * hk], [hx - 0.4 * hk, hy + 0.08 * hk]]));
  stroke(ctx, mid, 0.09 * hk, () => poly(ctx, [[hx + 0.25 * hk, hy], [hx + 0.25 * hk, hy - 0.7 * hk]], false));
  for (let i = 0; i < 3; i++) fill(ctx, '#3b3466', () => circle(ctx, hx + 0.25 * hk + i * 8, hy - 0.8 * hk - i * 16, 7 + i * 4), 0.6 - i * 0.15);
  // farmer na siedzeniu
  const s = (1.8 * k) / 330;
  Farmer.back(ctx, x, P(0, 1.15)[1] + 128 * s, s, { armSwing: 0 }, { ...NIGHT_LOOK, lw: 6 });
  // oparcie i korpus (zakrywa nogi)
  fill(ctx, '#2b2650', () => path(ctx, [P(-0.4, 1.45), P(0.4, 1.45), [P(0.42, 0.7)[0], P(0.42, 0.7)[1], 0], [P(-0.42, 0.7)[0], P(-0.42, 0.7)[1], 0]]));
  fill(ctx, orange, () => poly(ctx, [P(-0.5, 0.9), P(0.5, 0.9), P(0.5, 0.25), P(-0.5, 0.25)]));
  fill(ctx, orangeLit, () => poly(ctx, [P(-0.5, 0.9), P(0.5, 0.9), P(0.5, 0.82), P(-0.5, 0.82)]));
  for (const sg of [-1, 1]) { const [lx, ly] = P(sg * 0.38, 0.6); halo(ctx, lx, ly, 0.25 * k, '#ff4f6d', 2, 0.25); fill(ctx, '#ff4f6d', () => poly(ctx, [[lx - 0.08 * k, ly - 0.05 * k], [lx + 0.08 * k, ly - 0.05 * k], [lx + 0.08 * k, ly + 0.05 * k], [lx - 0.08 * k, ly + 0.05 * k]])); }
  // tylne koła i błotniki
  for (const sg of [-1, 1]) {
    const cx = sg * 0.92;
    const wheel = () => path(ctx, [[x + (cx - 0.24) * k, P(0, 0)[1], 0], [x + (cx - 0.26) * k, P(0, 0.75)[1]], [x + (cx - 0.24) * k, P(0, 1.5)[1], 0], [x + (cx + 0.24) * k, P(0, 1.5)[1], 0], [x + (cx + 0.26) * k, P(0, 0.75)[1]], [x + (cx + 0.24) * k, P(0, 0)[1], 0]]);
    fill(ctx, dark, wheel);
    ctx.save(); ctx.beginPath(); wheel(); ctx.clip();
    for (let i = 0; i < 9; i++) { const yy = P(0, i * 0.18)[1]; fill(ctx, mid, () => poly(ctx, [[x + (cx - 0.3) * k, yy], [x + (cx + 0.3) * k, yy - 0.05 * k], [x + (cx + 0.3) * k, yy - 0.1 * k], [x + (cx - 0.3) * k, yy - 0.05 * k]])); }
    ctx.restore();
    fill(ctx, orange, () => path(ctx, [[x + (cx - 0.32) * k, P(0, 1.35)[1], 0], [x + (cx - 0.3) * k, P(0, 1.62)[1]], [x + (cx + 0.3) * k, P(0, 1.62)[1]], [x + (cx + 0.32) * k, P(0, 1.35)[1], 0]]));
    fill(ctx, orangeLit, () => poly(ctx, [[x + (cx - 0.3) * k, P(0, 1.62)[1]], [x + (cx + 0.3) * k, P(0, 1.62)[1]], [x + (cx + 0.3) * k, P(0, 1.55)[1]], [x + (cx - 0.3) * k, P(0, 1.55)[1]]]));
    stroke(ctx, mid, 0.06 * k, () => poly(ctx, [[x + cx * 0.75 * k, P(0, 1.6)[1]], [x + cx * 0.75 * k, P(0, 2.7)[1]]], false));
  }
  // dach z panelem
  fill(ctx, '#3a59b5', () => poly(ctx, [P(-0.85, 2.7), P(0.85, 2.7), [x + 0.78 * k, P(0, 2.95)[1]], [x - 0.78 * k, P(0, 2.95)[1]]]));
  fill(ctx, '#6f8de0', () => poly(ctx, [P(-0.85, 2.7), P(0.85, 2.7), P(0.85, 2.66), P(-0.85, 2.66)]));
}
SCENES.tppTractor = {
  file: 'cn_13_tpp_tractor',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(360, 1100, 3.4);
    nightSky(ctx, 0.7, { moon: [330, 140, 72], horizon: cam.H0, starSeed: 77 });
    farHorizon(ctx, cam, t, { mx1: 1500, mx2: 520, mx3: 1000 });
    groundBands(ctx, cam, ['#2a1a36', '#24152f', '#1f122a', '#1a0f24', '#150c1f', '#100919']);
    const inBeam = (X, d) => d > 7.5 && d < 24 && Math.abs(X) < 0.5 + (d - 7.5) * 0.17;
    // rzędy grządek do horyzontu
    for (let i = -7; i <= 7; i++) {
      const a = cam.p(i - 0.3, 0, 60), b = cam.p(i + 0.3, 0, 60), c = cam.p(i + 0.3, 0, 3.6), e = cam.p(i - 0.3, 0, 3.6);
      fill(ctx, '#3a2440', () => poly(ctx, [a, b, c, e]));
      fill(ctx, '#4a2e4c', () => poly(ctx, [cam.p(i - 0.05, 0, 60), cam.p(i + 0.05, 0, 60), cam.p(i + 0.05, 0, 3.6), cam.p(i - 0.05, 0, 3.6)]));
    }
    const L = [];
    // dojrzałe uprawy przed traktorem, świeże nasiona za nim
    for (let i = -7; i <= 7; i++) for (let d = 4; d < 48; d += 1.2) {
      const X = i, dd = d + (Math.abs(i) % 2) * 0.6;
      L.push({ d: dd, fn: () => {
        const [x, y, k] = cam.p(X, 0, dd);
        if (x < -100 || x > W + 100) return;
        if (Math.abs(X) <= 1 && dd < 6.6) { halo(ctx, x, y, 0.25 * k, PAL.amber, 2, 0.25); fill(ctx, PAL.lemon, () => ctx.ellipse(x, y, 0.06 * k, 0.03 * k, 0, 0, TAU)); return; }
        const boost = inBeam(X, dd) ? 1.6 : 1;
        const kind = (i + 7 + Math.floor(dd)) % 3;
        if (kind === 0) Critters.voidberry(ctx, x, y, (0.6 * k) / 75, 0.7, { seed: i * 13 + Math.floor(dd), berry: boost > 1 ? '#d7b8ff' : PAL.violet });
        else if (kind === 1) Critters.moonpetal(ctx, x, y, ((0.55 * k) / 90), 0.7, { c: boost > 1 ? '#ffffff' : '#e9dcff' });
        else crystal(ctx, x, y, 0.5 * k, 0.17 * k, 0.05 * i, boost);
      } });
    }
    // reflektory: płaskie kliny światła na ziemi przed traktorem
    L.push({ d: 7.9, fn: () => {
      screenFill(ctx, PAL.lemon, 0.13, () => poly(ctx, [cam.p(-0.9, 0, 7.6), cam.p(0.9, 0, 7.6), cam.p(3.4, 0, 24), cam.p(-3.4, 0, 24)]));
      screenFill(ctx, PAL.lemon, 0.12, () => poly(ctx, [cam.p(-0.6, 0, 7.6), cam.p(0.6, 0, 7.6), cam.p(1.8, 0, 18), cam.p(-1.8, 0, 18)]));
    } });
    L.push({ d: 6.6, fn: () => tractorBack(ctx, cam, 0, 6.6) });
    // siewnik za traktorem (bliżej kamery)
    L.push({ d: 5.5, fn: () => {
      const [x, y, k] = cam.p(0, 0.35, 5.5);
      fill(ctx, '#28254f', () => poly(ctx, [[x - 1.5 * k, y - 0.06 * k], [x + 1.5 * k, y - 0.06 * k], [x + 1.5 * k, y + 0.06 * k], [x - 1.5 * k, y + 0.06 * k]]));
      for (const dx of [-1, 0, 1]) {
        const hx = x + dx * k;
        fill(ctx, night('#f39a2c', 0.3), () => poly(ctx, [[hx - 0.28 * k, y - 0.42 * k], [hx + 0.28 * k, y - 0.42 * k], [hx + 0.12 * k, y], [hx - 0.12 * k, y]]));
        fill(ctx, '#f7a948', () => poly(ctx, [[hx - 0.28 * k, y - 0.42 * k], [hx + 0.28 * k, y - 0.42 * k], [hx + 0.26 * k, y - 0.36 * k], [hx - 0.26 * k, y - 0.36 * k]]));
        for (let q = 0; q < 4; q++) { const sy = y + 0.1 * k + q * 0.1 * k; halo(ctx, hx, sy, 10, PAL.amber, 1, 0.25); fill(ctx, PAL.lemon, () => circle(ctx, hx + (q % 2 ? 3 : -3), sy, 4)); }
      }
    } });
    // dron z wodą przed traktorem
    L.push({ d: 17, fn: () => { const [x, y, k] = cam.p(3.2, 4.2, 17); const s = (0.9 * k) / 100; Props.drone(ctx, x, y, s, 0.7, { beamLen: (cam.gy(17) - y) / s }); } });
    depthDraw(L);
    fireflies(ctx, 22, 26, [60, 300, 1860, 800], 0.7, PAL.lemon, { size: 3 });
    hudBase(ctx, { clock: '21:30', icons: ['berry', 'crystal', 'snap', 'boom', 'mist'], sel: 0 });
    grain(ctx, 0.04);
  },
};

// ======================================================================
// 14. Widok z grani przez ramię: dolina, strumień światła, meduzy na niebie
// ======================================================================
SCENES.tppRidge = {
  file: 'cn_14_tpp_ridge_view',
  draw(ctx, f, t) {
    window.LOOPT = 4;
    const cam = Cam(470, 1300, 9);
    nightSky(ctx, 0.4, { moon: [1240, 230, 140], moon2: [520, 120, 34], horizon: cam.H0, starSeed: 13, starCount: 320 });
    farHorizon(ctx, cam, t, { mx1: 300, mx2: 1650, mx3: 960 });
    groundBands(ctx, cam, ['#1f1a4a', '#1b1642', '#17133a', '#141032', '#110d2b', '#0e0b24'], [200, 90, 50, 30, 18, 11]);
    const L = [];
    // świecący strumień wijący się do horyzontu
    L.push({ d: 1e4, fn: () => {
      const lft = [], rgt = [];
      for (let d = 14; d < 260; d *= 1.04) { const X = Math.sin(d * 0.05) * 16 + Math.sin(d * 0.013) * 30 - 6, w = 1.6 + d * 0.012; lft.push(cam.p(X - w, 0, d)); rgt.push(cam.p(X + w, 0, d)); }
      const poly2 = (k2) => { ctx.moveTo(...lft[0]); for (let i = 0; i < lft.length; i++) ctx.lineTo(lerp(lft[i][0], rgt[i][0], 0.5 - k2), lerp(lft[i][1], rgt[i][1], 0.5 - k2)); for (let i = rgt.length - 1; i >= 0; i--) ctx.lineTo(lerp(lft[i][0], rgt[i][0], 0.5 + k2), lerp(lft[i][1], rgt[i][1], 0.5 + k2)); ctx.closePath(); };
      screenFill(ctx, PAL.cyan, 0.12, () => poly2(1.6));
      fill(ctx, '#1e6a7a', () => poly2(0.5));
      fill(ctx, PAL.cyan, () => poly2(0.22));
      fill(ctx, '#d9fffb', () => poly2(0.06));
    } });
    // łąki w dole: plamy świecącej trawy jako punkty, drzewa-grzyby
    const r = mulberry32(31);
    for (let i = 0; i < 420; i++) {
      const X = (r() - 0.5) * 220, d = 12 + Math.pow(r(), 1.5) * 200, c = [PAL.cyan, PAL.mint, PAL.violet, PAL.cyan][i % 4];
      L.push({ d: d + 500, fn: () => { const [x, y, k] = cam.p(X, 0, d); if (x < -20 || x > W + 20) return; const s = Math.max(1.2, 0.12 * k); ctx.globalAlpha = 0.85; ctx.fillStyle = c; ctx.fillRect(x, y, s * 1.6, s); ctx.globalAlpha = 1; } });
    }
    for (let i = 0; i < 40; i++) {
      const X = (r() - 0.5) * 180, d = 14 + Math.pow(r(), 1.3) * 150, sc = 0.8 + r() * 0.6, gc = [PAL.cyan, PAL.violet, PAL.mint][i % 3];
      L.push({ d, fn: () => { const [x, y, k] = cam.p(X, 0, d); if (x < -200 || x > W + 200) return; const fg = clamp((d - 14) / 140); mushTree(ctx, x, y, (8 * sc * k) / 300, { trunk: mix('#100d2c', '#1f1a4a', fg), cap: mix('#16123a', '#1f1a4a', fg), capLit: mix('#2b2463', '#2a2360', fg), glow: gc, glowAmt: 1 - fg * 0.5, spots: false, seed: i }); } });
    }
    // baza w oddali: ciepłe okno i turkusowa brama
    L.push({ d: 70, fn: () => { const [x, y, k] = cam.p(-26, 0, 70); Props.hut(ctx, x, y, (9 * k) / 450, { t: 0.4 }); const [gx, gy, gk] = cam.p(-16, 0, 74); Props.gate(ctx, gx, gy, (6 * gk) / 300, 0.4); } });
    depthDraw(L);
    // meduzy na niebie i ćma
    Critters.drifter(ctx, 1500, 330, 0.42, 0.3);
    Critters.drifter(ctx, 1020, 250, 0.26, 1.1);
    Critters.drifter(ctx, 1760, 520, 0.6, 2.2);
    Critters.drifter(ctx, 760, 330, 0.16, 0.7);
    Critters.lumimoth(ctx, 820, 560, 0.5, 0.15);
    // grań na pierwszym planie
    fill(ctx, '#0c0a22', () => path(ctx, [[0, 850, 0], [260, 820], [620, 870], [980, 930], [1350, 990], [1920, 1010, 0], [1920, 1080, 0], [0, 1080, 0]]));
    fill(ctx, '#1d1850', () => path(ctx, [[0, 850, 0], [260, 820], [620, 870], [980, 930], [1350, 990], [1920, 1010, 0], [1920, 1018, 0], [1350, 999], [980, 940], [620, 880], [260, 830], [0, 860, 0]]));
    grassRow(ctx, 1000, 1.6, 0.4, { base: '#07061a', tip: PAL.cyan, seed: 61, gap: 50, yFn: (x) => 850 + x * 0.09 + 30, skip: (x) => x < 700 });
    // farmer przez ramię (kadr z bliska)
    const look = { ...NIGHT_LOOK, lw: 7, lampOn: false, rims: [{ c: PAL.cyan, lx: 0.6, ly: 0.3, w: 8 }, { c: '#cfc6ff', lx: 0.5, ly: -1, w: 6 }] };
    Farmer.back(ctx, 400, 1500, 2.5, {}, look);
    grain(ctx, 0.05);
  },
};
