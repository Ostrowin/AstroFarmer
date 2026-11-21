'use strict';
// Sceny animowane: kamera TPP, bieg z boku, las grzybowy, split-screen, Boomshroom.

// ---------------- HUD w stylu kreskówki ----------------
function hudBox(ctx, x, y, w, h, fillC = '#1b1640', border = PAL.ink) {
  fill(ctx, PAL.ink, () => { ctx.roundRect(x + 6, y + 7, w, h, 14); });
  ctx.beginPath(); ctx.roundRect(x, y, w, h, 14); ctx.fillStyle = fillC; ctx.fill();
  ctx.lineWidth = 5; ctx.strokeStyle = border; ctx.stroke();
}
function hudText(ctx, x, y, text, size = 30, col = PAL.white, align = 'left') {
  ctx.save(); ctx.font = `900 ${size}px "Arial Black", "Segoe UI Black", sans-serif`; ctx.textAlign = align; ctx.textBaseline = 'middle';
  ctx.lineWidth = 7; ctx.strokeStyle = PAL.ink; ctx.lineJoin = 'round'; ctx.strokeText(text, x, y); ctx.fillStyle = col; ctx.fillText(text, x, y); ctx.restore();
}
function hudBar(ctx, x, y, w, h, v, col, icon) {
  hudBox(ctx, x, y, w, h, '#120f2c');
  ctx.save(); ctx.beginPath(); ctx.roundRect(x + 6, y + 6, w - 12, h - 12, 8); ctx.clip();
  ctx.fillStyle = col; ctx.fillRect(x + 6, y + 6, (w - 12) * v, h - 12);
  ctx.fillStyle = 'rgba(255,255,255,0.35)'; ctx.fillRect(x + 6, y + 8, (w - 12) * v, 5);
  ctx.restore();
  icon(x - 34, y + h / 2);
}
function drawHud(ctx, t, o = {}) {
  hudBox(ctx, 40, 36, 150, 62);
  hudText(ctx, 115, 68, o.clock ?? '21:40', 30, PAL.white, 'center');
  hudBar(ctx, 760, 40, 420, 34, o.hp ?? 0.82, '#ff4f6d', (x, y) => {
    fill(ctx, '#ff4f6d', () => { ctx.moveTo(x, y + 12); ctx.bezierCurveTo(x - 26, y - 4, x - 12, y - 22, x, y - 8); ctx.bezierCurveTo(x + 12, y - 22, x + 26, y - 4, x, y + 12); });
    ctx.lineWidth = 4; ctx.strokeStyle = PAL.ink; ctx.stroke();
  });
  hudBar(ctx, 760, 86, 420, 26, o.awake ?? 0.18, PAL.violet, (x, y) => {
    inked(ctx, () => path(ctx, [[x - 18, y, 0], [x, y - 10], [x + 18, y, 0], [x, y + 10]]), '#e6dcff', 4);
    fill(ctx, PAL.ink, () => ctx.arc(x, y, 5, 0, TAU));
  });
  hudBox(ctx, 1730, 36, 150, 62);
  inked(ctx, () => path(ctx, [[1752, 54, 0], [1782, 54, 0], [1786, 86, 0], [1748, 86, 0]]), '#d39b5a', 4);
  hudText(ctx, 1838, 68, o.bag ?? '3/10', 28, PAL.white, 'center');
  // pasek przedmiotów
  const slots = [['1', 'gun'], ['2', 'berry'], ['RMB', 'seed']];
  slots.forEach(([k, ic], i) => {
    const x = 790 + i * 120, y = 950, sel = i === 0;
    hudBox(ctx, x, y, 100, 100, '#1b1640', sel ? PAL.lemon : PAL.ink);
    if (sel) { ctx.beginPath(); ctx.roundRect(x, y, 100, 100, 14); ctx.lineWidth = 6; ctx.strokeStyle = PAL.lemon; ctx.stroke(); }
    hudText(ctx, x + 16, y + 18, k, 16, '#cfc8ff');
    const cx = x + 50, cy = y + 56;
    if (ic === 'gun') { inked(ctx, () => path(ctx, [[cx - 26, cy - 10, 0], [cx + 24, cy - 10, 0], [cx + 24, cy + 2, 0], [cx - 4, cy + 2, 0], [cx - 8, cy + 20, 0], [cx - 22, cy + 20, 0], [cx - 18, cy + 2, 0], [cx - 26, cy + 2, 0]]), PAL.lemon, 4); }
    if (ic === 'berry') for (const [dx, dy] of [[-10, 4], [8, 6], [0, -10]]) { halo(ctx, cx + dx, cy + dy, 16, PAL.violet, 1, 0.25); inked(ctx, () => circle(ctx, cx + dx, cy + dy, 10), PAL.violet, 3.5); }
    if (ic === 'seed') { halo(ctx, cx, cy, 30, PAL.amber, 2, 0.15); inked(ctx, () => path(ctx, [[cx, cy - 22], [cx + 16, cy], [cx, cy + 20], [cx - 16, cy]]), PAL.amberDeep, 4); fill(ctx, PAL.lemon, () => circle(ctx, cx - 4, cy - 4, 4)); }
  });
}

// ======================================================================
// 3. Łąka wyprawy z kamery TPP (pętla: farmer idzie, świat płynie)
// ======================================================================
const TPP = { H0: 430, f: 1100, hc: 2.4, cx: 960, v: 1.6, L: 6, dF: 6.2 };
function tppProj(X, d) { return [TPP.cx + (X * TPP.f) / d, TPP.H0 + (TPP.f * TPP.hc) / d, TPP.f / d]; }
function drawMeadowTPP(ctx, t, o = {}) {
  const P = TPP.v * TPP.L; // okres wzoru w głąb (pętla bez szwu)
  const shift = TPP.v * t;
  skyBands(ctx, PAL.sky, 0, TPP.H0, 6, 7);
  cloudStreak(ctx, 200, 260, 700, 14, '#2a2463');
  cloudStreak(ctx, 1100, 330, 600, 12, '#332a6e');
  stars(ctx, 31, 200, 0, TPP.H0, t);
  moon(ctx, 1640, 150, 90, PAL.moon, PAL.moonShade, { phase: 0.45, seed: 4 });
  crystalMountain(ctx, 420, TPP.H0 + 14, 420, 160, '#201a4c', '#2b2462', 3, { glow: 0.9, ledge: '#352d72', crystalCount: 3, steps: 3 });
  crystalMountain(ctx, 1380, TPP.H0 + 14, 520, 200, '#201a4c', '#2b2462', 6, { glow: 0.9, ledge: '#352d72', steps: 3 });
  hillBand(ctx, TPP.H0 + 10, 8, PAL.mtnMid, 4, 0.003);
  // ziemia: pasy głębi (płaskie) zamiast gradientu
  const bands = ['#1b1642', '#18143b', '#151134', '#120f2d', '#0f0c27', '#0c0a21'];
  bands.forEach((c, i) => { const y = TPP.H0 + 18 + Math.pow(i / bands.length, 1.6) * 640; ctx.fillStyle = c; ctx.fillRect(0, y, W, H - y); });
  // obiekty świata w głębi (okresowy wzór)
  const r = mulberry32(5);
  const objs = [];
  for (let i = 0; i < 70; i++) objs.push({ kind: 'grass', X: (r() - 0.5) * 26, d0: r() * P, s: 0.7 + r() * 0.6, tip: r() > 0.8 ? PAL.mint : PAL.cyan, seed: i });
  for (let i = 0; i < 9; i++) objs.push({ kind: 'moss', X: (r() - 0.5) * 30, d0: r() * P, s: 1.2 + r() * 2, c: [PAL.cyan, PAL.mint, PAL.violet][i % 3] });
  for (let i = 0; i < 4; i++) objs.push({ kind: 'petal', X: (r() > 0.5 ? 1 : -1) * (1.4 + r() * 4), d0: r() * P, seed: i });
  for (let i = 0; i < 3; i++) objs.push({ kind: 'tree', X: (i % 2 ? 1 : -1) * (4.5 + r() * 5), d0: r() * P, s: 0.9 + r() * 0.5, c: i === 1 ? PAL.violet : PAL.cyan, seed: i });
  const inst = [];
  for (const ob of objs) for (let k = 0; k < (ob.kind === 'petal' ? 2 : 7); k++) {
    const d = ((ob.d0 - shift) % P + P) % P + k * P + 3.2;
    if (d > 3.2 + 6 * P * 0.9) continue;
    inst.push({ ...ob, d });
  }
  inst.sort((a, b) => b.d - a.d);
  // snop latarki: plama na ziemi przed farmerem
  const [spx, spy, sps] = tppProj(0.15, TPP.dF + 5.5);
  const inSpot = (x, y) => { const dx = (x - spx) / (sps * 2.6), dy = (y - spy) / (sps * 2.6 * TPP.hc / (TPP.dF + 5.5)); return Math.exp(-(dx * dx + dy * dy) * 1.2); };
  const fog = (d) => clamp((d - 6) / 40);
  let drewFarmer = false;
  const drawFarmer = () => {
    // ślady stóp za farmerem (płyną do kamery)
    for (let k = 0; k < 10; k++) {
      const age = ((t % 0.5) + k * 0.5);
      const side = (Math.floor(t / 0.5) - k) % 2 === 0 ? 1 : -1;
      const d = TPP.dF - TPP.v * age;
      if (d < 3.6) continue;
      const fade = 1 - age / 4;
      const [x, y, sc] = tppProj(side * 0.16, d);
      const rx = 0.09 * sc, ry = rx * 0.5 * TPP.hc / d * 3;
      screenFill(ctx, PAL.mint, 0.25 * fade, () => ctx.ellipse(x, y, rx * 2.6, ry * 2.6, 0, 0, TAU));
      fill(ctx, mix('#1b1642', PAL.mint, fade), () => ctx.ellipse(x, y, rx, ry, 0, 0, TAU));
      fill(ctx, mix('#1b1642', PAL.mint, fade), () => ctx.ellipse(x, y - ry * 1.9, rx * 0.8, ry * 0.7, 0, 0, TAU));
    }
    const [fx, fy, fs] = tppProj(0, TPP.dF);
    screenFill(ctx, PAL.cyan, 0.12, () => ctx.ellipse(fx, fy, 120, 26, 0, 0, TAU));
    const look = { ...NIGHT_LOOK, lw: 6, rims: [{ c: PAL.cyan, lx: -0.7, ly: 0.7, w: 7 }, { c: '#a99cff', lx: 0.8, ly: -0.5, w: 5 }] };
    const ph = t * TAU * 1.0;
    const a = Farmer.back(ctx, fx, fy, fs / 330 * 1.8, { phase: ph, run: 0.7, armSwing: 0.8 }, look);
    // snop latarki: płaski klin od hełmu do plamy
    screenFill(ctx, PAL.lemon, 0.09, () => poly(ctx, [[a.lamp[0] - 8, a.lamp[1]], [a.lamp[0] + 8, a.lamp[1]], [spx + sps * 2.6, spy], [spx - sps * 2.6, spy]]));
  };
  // plama światła latarki (pod obiektami w niej)
  screenFill(ctx, PAL.lemon, 0.1, () => ctx.ellipse(spx, spy, sps * 2.8, sps * 2.8 * TPP.hc / (TPP.dF + 5.5), 0, 0, TAU));
  screenFill(ctx, PAL.lemon, 0.1, () => ctx.ellipse(spx, spy, sps * 1.8, sps * 1.8 * TPP.hc / (TPP.dF + 5.5), 0, 0, TAU));
  for (const ob of inst) {
    if (!drewFarmer && ob.d < TPP.dF) { drawFarmer(); drewFarmer = true; }
    const [x, y, sc] = tppProj(ob.X, ob.d);
    if (x < -400 || x > W + 400) continue;
    const fg = fog(ob.d);
    if (ob.kind === 'grass') {
      const spot = inSpot(x, y);
      grassClump(ctx, x, y, sc * 0.0072 * ob.s * 100 / 100, t, { seed: ob.seed, base: mix('#07061a', '#1b1642', fg), tip: ob.tip, glow: (1 - fg * 0.6) + spot * 0.8, blades: ob.d > 20 ? 4 : 7, wave: () => spot * 0.6 });
    } else if (ob.kind === 'moss') {
      if (ob.d < 9) continue;
      const rx = ob.s * sc, ry = rx * TPP.hc / ob.d;
      screenFill(ctx, ob.c, 0.1 * (1 - fg), () => ctx.ellipse(x, y, rx, ry, 0, 0, TAU));
      screenFill(ctx, ob.c, 0.12 * (1 - fg), () => ctx.ellipse(x, y, rx * 0.55, ry * 0.55, 0, 0, TAU));
    } else if (ob.kind === 'petal') {
      Critters.moonpetal(ctx, x, y, sc * 0.006, t);
    } else if (ob.kind === 'tree') {
      mushTree(ctx, x, y, sc * 0.0115 * ob.s, { trunk: mix(PAL.fg, PAL.mtnMid, fg), cap: mix('#0d0b26', PAL.mtnMid, fg), capLit: mix('#1d1850', PAL.mtnMidLit, fg), glow: ob.c, glowAmt: 1 - fg * 0.5, seed: ob.seed, lean: ob.X > 0 ? -0.08 : 0.08 });
    }
  }
  if (!drewFarmer) drawFarmer();
  // świetliki i ćma
  fireflies(ctx, 8, 30, [80, 380, 1840, 900], t, PAL.lemon, { size: 3 });
  Critters.lumimoth(ctx, 1460 + Math.sin(t * TAU / TPP.L) * 120, 360 + Math.sin(t * TAU * 2 / TPP.L) * 40, 0.45, t * 1.33);
  if (o.hud !== false) drawHud(ctx, t);
}
SCENES.meadow = {
  file: 'cn_3_meadow_tpp', frames: TPP.L * 12, fps: 12, keyFrame: 20, previewFrame: 20,
  draw(ctx, f, t) { drawMeadowTPP(ctx, t); grain(ctx, 0.04); },
};

// ======================================================================
// 4. Bieg z boku: świecące ślady i trawa, która "czuje" kroki
// ======================================================================
const RUN = { L: 3, cyc: 0.5, s: 1.15, fx: 720, gy: 900 };
function runPose(ph) {
  const leg = (p) => {
    const th = 0.68 * Math.sin(p);
    const kn = 0.25 + 1.75 * Math.pow(Math.max(0, Math.cos(p + Math.PI / 4)), 1.4);
    return [th, kn];
  };
  const N = leg(ph), F = leg(ph + Math.PI);
  const footY = ([th, kn]) => 58 * Math.cos(th) + 56 * Math.cos(th - kn);
  const hipY = -(Math.max(footY(N), footY(F)) + 14) - Math.max(0, Math.sin(2 * ph - 0.6)) * 12;
  const footAng = ([th, kn], p) => (Math.cos(p) > 0.2 ? -0.2 : 0) + (Math.sin(p) < -0.3 ? 0.5 * Math.sin(p) * -1 * 0.5 : 0);
  return {
    hip: [0, hipY], lean: 0.24, legN: N, legF: F, footN: footAng(N, ph), footF: footAng(F, ph + Math.PI),
    armN: [-0.95 * Math.sin(ph), 1.5], armF: [0.95 * Math.sin(ph), 1.5], head: -0.1, mouth: 'grit', brow: 'angry',
  };
}
function footX([th, kn]) { return 58 * Math.sin(th) + 56 * Math.sin(th - kn); }
function drawRun(ctx, t, o = {}) {
  const ph = (t / RUN.cyc) * TAU;
  // prędkość ziemi = przesunięcie stopy podporowej
  const v = ((footX([0.68, 0.25]) - footX([-0.68, 0.25])) * RUN.s) / (RUN.cyc / 2) * 0.92;
  const scroll = v * t;
  skyBands(ctx, PAL.sky, 0, 620, 9, 8);
  cloudStreak(ctx, 100, 220, 760, 14, '#2a2463');
  cloudStreak(ctx, 900, 330, 900, 16, '#332a6e');
  stars(ctx, 55, 220, 0, 600, t);
  moon(ctx, 1500, 200, 105, PAL.moon, PAL.moonShade, { phase: 0.4, seed: 4 });
  moon(ctx, 420, 120, 30, PAL.moonPink, PAL.moonPinkShade, { phase: -0.6, seed: 9, craters: 3 });
  crystalMountain(ctx, 500, 640, 700, 300, '#201a4c', '#2b2462', 5, { glow: 1, ledge: '#352d72' });
  crystalMountain(ctx, 1400, 640, 800, 360, '#201a4c', '#2b2462', 8, { glow: 1, ledge: '#352d72', crystalCount: 5 });
  // warstwa średnia (paralaksa 0.33, kafel 1050 px)
  const tile = (speed, tw, fn) => { const off = -((scroll * speed) % tw); for (let k = -1; k <= Math.ceil(W / tw) + 1; k++) fn(off + k * tw); };
  hillBand(ctx, 680, 14, PAL.mtnMid, 4, TAU / 1050 * 2);
  tile(0.333, v * RUN.L * 0.333, (ox) => {
    const tw = v * RUN.L * 0.333; const rr = mulberry32(3);
    for (let i = 0; i < 4; i++) { const x = ox + rr() * tw; mushTree(ctx, x, 700, 0.3 + rr() * 0.2, { trunk: PAL.mtnMid, cap: PAL.mtnMid, capLit: PAL.mtnMidLit, glowAmt: 0.8, glow: rr() > 0.5 ? PAL.violet : PAL.cyan, spots: false, seed: i }); }
  });
  ctx.fillStyle = PAL.hill; ctx.fillRect(0, 700, W, H - 700);
  fill(ctx, PAL.hillLit, () => poly(ctx, [[0, 700], [W, 700], [W, 712], [0, 712]]));
  // ziemia z grzybami (prędkość 1)
  const TW = v * RUN.L;
  tile(1, TW, (ox) => {
    const rr = mulberry32(11);
    for (let i = 0; i < 3; i++) { const x = ox + (i + 0.3 + rr() * 0.4) * TW / 3; mushTree(ctx, x, RUN.gy - 30, 0.55 + rr() * 0.25, { trunk: PAL.hill, cap: '#1d1848', capLit: '#2b2463', glowAmt: 1, glow: [PAL.cyan, PAL.violet, PAL.mint][i], seed: 10 + i }); }
  });
  ctx.fillStyle = PAL.ground; ctx.fillRect(0, RUN.gy - 30, W, H);
  fill(ctx, PAL.groundLit, () => poly(ctx, [[0, RUN.gy - 30], [W, RUN.gy - 30], [W, RUN.gy - 20], [0, RUN.gy - 20]]));
  // ślady stóp: zdarzenia kontaktu w ostatnich 4 s (w czasie świata)
  const prints = [];
  const half = RUN.cyc / 2;
  const n0 = Math.floor((t - 4) / half), n1 = Math.floor(t / half);
  for (let n = n0; n <= n1; n++) {
    const te = n * half + half * 0.5; // chwila postawienia stopy
    const age = t - te; if (age < 0 || age > 4) continue;
    const leg = n % 2 === 0 ? 'N' : 'F';
    const xs = RUN.fx + footX([0.68, 0.25]) * RUN.s * 0.85 - v * age;
    prints.push({ x: xs, age, leg });
  }
  const boost = (x) => { let b = 0; for (const p of prints) b += Math.exp(-Math.pow((x - p.x) / 70, 2)) * Math.max(0, 1 - p.age / 3); return clamp(b); };
  // trawa (świeci mocniej przy śladach)
  tile(1, TW, (ox) => {
    const rr = mulberry32(21);
    for (let i = 0; i < 26; i++) { const x = ox + rr() * TW; const y = RUN.gy - 26 + rr() * 16; grassClump(ctx, x, y, 0.75 + rr() * 0.4, t, { seed: i, base: '#0b0922', tip: rr() > 0.75 ? PAL.mint : PAL.cyan, glow: 0.55, wave: (gx) => boost(gx) * 1.4, haloChance: 0.2 }); }
  });
  for (const p of prints) {
    const fade = Math.max(0, 1 - p.age / 4);
    const y = RUN.gy + (p.leg === 'N' ? 12 : -2);
    if (p.age < 0.35) { const k = p.age / 0.35; stroke(ctx, mix(PAL.ground, PAL.mint, 1 - k), 4, () => ctx.ellipse(p.x, y, 20 + k * 70, 5 + k * 14, 0, 0, TAU)); }
    screenFill(ctx, PAL.mint, 0.3 * fade, () => ctx.ellipse(p.x, y, 40, 9, 0, 0, TAU));
    fill(ctx, mix(PAL.ground, PAL.mint, fade), () => ctx.ellipse(p.x + 6, y, 18, 4.5, 0, 0, TAU));
    fill(ctx, mix(PAL.ground, PAL.mint, fade), () => ctx.ellipse(p.x - 16, y, 7, 4, 0, 0, TAU));
  }
  // farmer
  const look = { ...NIGHT_LOOK, lw: 6, rims: [{ c: PAL.cyan, lx: -0.3, ly: 1, w: 7 }, { c: '#a99cff', lx: 0.9, ly: -0.4, w: 5 }] };
  screenFill(ctx, PAL.cyan, 0.12, () => ctx.ellipse(RUN.fx, RUN.gy + 8, 110, 16, 0, 0, TAU));
  const a = Farmer.side(ctx, RUN.fx, RUN.gy, RUN.s, 1, runPose(ph), look);
  screenFill(ctx, PAL.lemon, 0.11, () => poly(ctx, [[a.lamp[0], a.lamp[1] - 6], [a.lamp[0] + 520, a.lamp[1] - 40], [a.lamp[0] + 500, a.lamp[1] + 170]]));
  // linie pędu za plecami (płaskie, jak u Tartakovsky'ego)
  const rr = mulberry32(Math.floor(t * 6));
  for (let i = 0; i < 5; i++) { const y = 560 + rr() * 320, x = RUN.fx - 240 - rr() * 400, len = 120 + rr() * 220; fill(ctx, '#3b3283', () => poly(ctx, [[x, y], [x + len, y - 2], [x + len, y + 3], [x, y + 2]]), 0.7); }
  fireflies(ctx, 4, 20, [0, 400, W, 860], t, PAL.lemon, { size: 2.6 });
  // pierwszy plan (prędkość 1.6)
  tile(1.6, TW * 1.6, (ox) => {
    const rr2 = mulberry32(31);
    for (let i = 0; i < 18; i++) { const x = ox + rr2() * TW * 1.6; grassClump(ctx, x, 1090, 1.7 + rr2() * 0.6, t, { seed: 50 + i, base: PAL.fg, tip: PAL.cyan, glow: 0.8, blades: 6 }); }
  });
}
SCENES.run = {
  file: 'cn_4_run_footprints', frames: RUN.L * 12, fps: 12, keyFrame: 14, previewFrame: 14,
  draw(ctx, f, t) { drawRun(ctx, t); grain(ctx, 0.04); },
};

// ======================================================================
// 5. Las grzybowy: puls grzybni
// ======================================================================
let _myc = null;
function mycelium() {
  if (_myc) return _myc;
  const r = mulberry32(42);
  const threads = [];
  const hearts = [[620, 950], [1330, 985]];
  const make = (x, y, ang, len, w, d0, hi, depth) => {
    const pts = [[x, y]], ds = [d0];
    let px = x, py = y, d = d0, a = ang;
    const steps = Math.floor(len / 14);
    for (let i = 0; i < steps; i++) {
      a += (r() - 0.5) * 0.28;
      const nx = px + Math.cos(a) * 14, ny = py + Math.sin(a) * 14 * 0.42;
      if (ny < 905) a = Math.abs(a) * 0.6 + 0.1;
      if (ny > H + 40) break;
      d += 14; pts.push([nx, ny]); ds.push(d); px = nx; py = ny;
      if (depth < 2 && i > 4 && r() < 0.07) make(px, py, a + (r() > 0.5 ? 1 : -1) * (0.5 + r() * 0.5), len * (0.35 + r() * 0.25), w * 0.6, d, hi, depth + 1);
    }
    threads.push({ pts, ds, w, hi });
  };
  hearts.forEach(([hx, hy], hi) => { const n = 8; for (let k = 0; k < n; k++) make(hx, hy, (k / n) * TAU + r() * 0.35, 520 + r() * 420, 3, 0, hi, 0); });
  _myc = { threads, hearts };
  return _myc;
}
// kawałek polilinii między odległościami a..b (odległość od serca)
function subPath(ctx, th, a, b) {
  let started = false;
  for (let i = 1; i < th.pts.length; i++) {
    const d0 = th.ds[i - 1], d1 = th.ds[i];
    if (d1 < a || d0 > b) continue;
    const t0 = clamp((a - d0) / (d1 - d0)), t1 = clamp((b - d0) / (d1 - d0));
    const p0 = th.pts[i - 1], p1 = th.pts[i];
    const x0 = lerp(p0[0], p1[0], t0), y0 = lerp(p0[1], p1[1], t0), x1 = lerp(p0[0], p1[0], t1), y1 = lerp(p0[1], p1[1], t1);
    if (!started) { ctx.moveTo(x0, y0); started = true; }
    ctx.lineTo(x1, y1);
  }
}
function threadPoint(th, d) {
  for (let i = 1; i < th.pts.length; i++) if (th.ds[i] >= d) { const k = (d - th.ds[i - 1]) / (th.ds[i] - th.ds[i - 1]); return [lerp(th.pts[i - 1][0], th.pts[i][0], k), lerp(th.pts[i - 1][1], th.pts[i][1], k)]; }
  return null;
}
function towercap(ctx, x, y, s, t, o = {}) {
  // olbrzym widziany od dołu: trzon w górę kadru, spód kapelusza z blaszkami
  const trunkC = o.trunk ?? '#140f30', trunkLit = o.trunkLit ?? '#1f1847', glowC = o.glow ?? PAL.cyan, gl = o.gl ?? 1;
  const w0 = 70 * s, w1 = 46 * s, top = o.capY ?? 140;
  const lean = o.lean ?? 0;
  fill(ctx, trunkC, () => path(ctx, [[x - w0 * 1.5, y, 0], [x - w0, y - 60 * s], [x - w1 + lean * 0.6, top + 120], [x - w1 * 0.8 + lean, top, 0], [x + w1 * 0.8 + lean, top, 0], [x + w1 + lean * 0.6, top + 120], [x + w0, y - 60 * s], [x + w0 * 1.6, y, 0]]));
  // światło blaszek na trzonie (płaski pas)
  fill(ctx, mix(trunkC, glowC, 0.3 * gl), () => path(ctx, [[x - w1 * 0.8 + lean, top, 0], [x + w1 * 0.8 + lean, top, 0], [x + w1 * 0.9 + lean * 0.8, top + 90], [x + w1 * 0.2 + lean * 0.8, top + 220], [x - w1 * 0.6 + lean * 0.8, top + 110]]));
  fill(ctx, trunkLit, () => path(ctx, [[x + w1 * 0.4 + lean * 0.6, top + 140], [x + w1 + lean * 0.6, top + 120], [x + w0, y - 60 * s], [x + w0 * 1.6, y, 0], [x + w0 * 0.9, y, 0], [x + w0 * 0.5, y - 80 * s]]));
  // pierścień
  const ry = top + 180 + (o.ringY ?? 0);
  fill(ctx, trunkLit, () => path(ctx, [[x - w1 * 1.7 + lean * 0.7, ry, 0], [x + w1 * 1.7 + lean * 0.7, ry, 0], [x + w1 * 1.2 + lean * 0.7, ry + 26], [x - w1 * 1.2 + lean * 0.7, ry + 26]]));
}
function gillsUnder(ctx, cx, cy, rx, ry, t, glowC, gl, seed) {
  // ogromny spód kapelusza nad kadrem: elipsa z promienistymi blaszkami
  fill(ctx, mix('#120d2c', glowC, 0.35 * gl), () => ctx.ellipse(cx, cy, rx, ry, 0, 0, TAU));
  ctx.save(); ctx.beginPath(); ctx.ellipse(cx, cy, rx, ry, 0, 0, TAU); ctx.clip();
  const n = 64;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU;
    const k = 0.5 + 0.5 * Math.sin(i * 1.7 + seed);
    stroke(ctx, mix('#120d2c', glowC, (0.55 + 0.45 * k) * gl), 3 + k * 2, () => { ctx.moveTo(cx + Math.cos(a) * rx * 0.12, cy + Math.sin(a) * ry * 0.12); ctx.lineTo(cx + Math.cos(a) * rx, cy + Math.sin(a) * ry); });
  }
  // jaśniejszy brzeg
  stroke(ctx, mix(glowC, '#ffffff', 0.3 * gl), 10, () => ctx.ellipse(cx, cy, rx - 8, ry - 4, 0, 0, TAU));
  fill(ctx, '#0d0a22', () => ctx.ellipse(cx, cy, rx * 0.14, ry * 0.14, 0, 0, TAU));
  ctx.restore();
}
function drawForest(ctx, t, o = {}) {
  const L = o.L ?? 4;
  // tło: fioletowa mgła w płaskich pasach
  skyBands(ctx, ['#0b0820', '#120d2c', '#191238', '#211846', '#2a1d55'], 0, 900, 13, 6);
  // dalekie trzony (jaśniejsze, w mgle)
  const far = [[160, 0.45, '#2a1d55'], [560, 0.35, '#2a1d55'], [880, 0.5, '#251a4d'], [1180, 0.4, '#2a1d55'], [1760, 0.45, '#251a4d']];
  for (const [x, s, c] of far) {
    const cy = 260 + s * 100;
    towercap(ctx, x, 900, s, t, { trunk: c, trunkLit: mix(c, '#4a3a8c', 0.4), glow: PAL.cyan, gl: 0.4, capY: cy });
    const cw = 420 * s;
    fill(ctx, mix(c, PAL.cyan, 0.35), () => path(ctx, [[x - cw, cy + 6, 0], [x, cy + 26], [x + cw, cy + 6, 0], [x, cy - 4]]));
    fill(ctx, c, () => path(ctx, [[x - cw, cy + 6, 0], [x - cw * 0.6, cy - 50 * s], [x, cy - 90 * s], [x + cw * 0.6, cy - 50 * s], [x + cw, cy + 6, 0], [x, cy - 4]]));
    fill(ctx, mix(c, '#4a3a8c', 0.45), () => path(ctx, [[x, cy - 90 * s], [x + cw * 0.6, cy - 50 * s], [x + cw, cy + 6, 0], [x + cw * 0.7, cy - 20 * s], [x + cw * 0.3, cy - 60 * s]]));
  }
  // dzwonkowe grzyby (magenta) średni plan
  for (const [x, y, s] of [[420, 640, 0.9], [1100, 600, 1.1], [1640, 660, 0.8]]) {
    stroke(ctx, '#3a2468', 14 * s, () => path(ctx, [[x, 900], [x + 10 * s, 760], [x, y]], false));
    stroke(ctx, mix('#3a2468', PAL.magenta, 0.3), 5 * s, () => path(ctx, [[x + 4 * s, 900], [x + 14 * s, 760], [x + 4 * s, y + 20]], false));
    halo(ctx, x, y + 20 * s, 120 * s, PAL.magenta, 3, 0.07);
    fill(ctx, '#45286f', () => path(ctx, [[x - 90 * s, y + 30 * s, 0], [x - 70 * s, y - 40 * s], [x, y - 70 * s], [x + 70 * s, y - 40 * s], [x + 90 * s, y + 30 * s, 0], [x, y + 14 * s]]));
    fill(ctx, PAL.magenta, () => path(ctx, [[x - 90 * s, y + 30 * s, 0], [x, y + 14 * s], [x + 90 * s, y + 30 * s, 0], [x, y + 40 * s]]));
    fill(ctx, '#6a3fa0', () => path(ctx, [[x - 70 * s, y - 40 * s], [x, y - 70 * s], [x + 70 * s, y - 40 * s], [x + 40 * s, y - 50 * s], [x, y - 56 * s]]));
    for (let k = 0; k < 6; k++) { const yy = y + 40 * s + ((t * 40 + k * 37) % 160); const xx = x + Math.sin(k * 2.1 + t) * 50 * s; fill(ctx, PAL.rose, () => ctx.arc(xx, yy, 2.2, 0, TAU), 1 - (yy - y) / 220); }
  }
  // klif z półkami (prawa strona)
  fill(ctx, '#160f33', () => poly(ctx, [[1560, 900], [1600, 300], [1700, 260], [1920, 240], [1920, 900]]));
  fill(ctx, '#1e1642', () => poly(ctx, [[1600, 300], [1700, 260], [1720, 280], [1640, 360], [1610, 600]]));
  for (const [y, w] of [[380, 150], [520, 190], [660, 160], [790, 210]]) {
    const x = 1600 - (y - 300) * 0.06;
    halo(ctx, x + w * 0.45, y + 14, w * 0.55, PAL.amber, 2, 0.07, 0.45);
    fill(ctx, '#4a2a26', () => path(ctx, [[x - 20, y - 8, 0], [x + w * 0.5, y - 26], [x + w, y - 4, 0], [x + w * 0.5, y + 6]]));
    fill(ctx, PAL.amber, () => path(ctx, [[x - 20, y - 8, 0], [x + w * 0.5, y + 6], [x + w, y - 4, 0], [x + w * 0.5, y + 18]]));
    for (let k = 0; k < 3; k++) stroke(ctx, mix(PAL.amber, '#ffffff', 0.2), 2, () => poly(ctx, [[x + w * (0.25 + k * 0.25), y + 10], [x + w * (0.25 + k * 0.25) + 2, y + 50 + k * 14]], false));
  }
  // dno lasu
  ctx.fillStyle = '#0a0720'; ctx.fillRect(0, 880, W, H - 880);
  fill(ctx, '#120c2c', () => { ctx.moveTo(0, 900); for (let x = 0; x <= W; x += 40) ctx.lineTo(x, 886 + Math.sin(x * 0.01) * 6); ctx.lineTo(W, 900); });
  // kałuże odbijające światło
  for (const [x, y, rx] of [[300, 1010, 160], [1180, 1040, 200], [880, 960, 90]]) {
    fill(ctx, '#151036', () => ctx.ellipse(x, y, rx, rx * 0.12, 0, 0, TAU));
    fill(ctx, mix('#151036', PAL.cyan, 0.4), () => ctx.ellipse(x - rx * 0.2, y, rx * 0.5, rx * 0.03, 0, 0, TAU));
  }
  // grzybnia: cienkie żyłki, po których biegną świecące komety (każde serce ma swój rytm)
  const M = mycelium();
  const fronts = [((t % L) / L) * 1150 - 60, (((t + L * 0.45) % L) / L) * 1150 - 60];
  for (const th of M.threads) { ctx.beginPath(); subPath(ctx, th, 0, 1e9); ctx.lineWidth = Math.max(1.2, th.w * 0.55); ctx.strokeStyle = '#183652'; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(); }
  for (const th of M.threads) {
    const fr = fronts[th.hi];
    if (fr < th.ds[0]) continue;
    // poświata za kometą (gaśnie)
    ctx.beginPath(); subPath(ctx, th, fr - 320, fr - 90); ctx.lineWidth = th.w * 0.7 + 0.6; ctx.strokeStyle = mix('#183652', PAL.cyan, 0.45); ctx.stroke();
    ctx.beginPath(); subPath(ctx, th, fr - 90, fr - 30); ctx.lineWidth = th.w + 1.2; ctx.strokeStyle = mix('#183652', PAL.cyan, 0.85); ctx.stroke();
    ctx.beginPath(); subPath(ctx, th, fr - 30, fr); ctx.lineWidth = th.w + 2.4; ctx.strokeStyle = '#e4fffc'; ctx.stroke();
    const hp = threadPoint(th, fr);
    if (hp) { halo(ctx, hp[0], hp[1], 16 + th.w * 4, PAL.cyan, 2, 0.22, 0.6); }
  }
  M.hearts.forEach(([hx, hy], i) => {
    const ph = (fronts[i] + 60) / 1150; const beat = ph < 0.08 ? 1 - ph / 0.08 : 0;
    halo(ctx, hx, hy, 70 + beat * 50, PAL.cyan, 3, 0.07 + beat * 0.14, 0.4);
    fill(ctx, mix('#183652', PAL.cyan, 0.45 + beat * 0.55), () => ctx.ellipse(hx, hy, 38 + beat * 10, 12 + beat * 4, 0, 0, TAU));
    fill(ctx, '#e4fffc', () => ctx.ellipse(hx - 8, hy - 3, 10, 3, 0, 0, TAU), 0.5 + beat * 0.5);
  });
  const glowNear = (x) => { let g = 0; for (const th of M.threads) { const fr = fronts[th.hi]; const hp = threadPoint(th, fr); if (hp && Math.abs(hp[0] - x) < 160 && hp[1] > 1000) g = Math.max(g, 1 - Math.abs(hp[0] - x) / 160); } return g; };
  // farmer, mały, z latarką
  const look = { ...NIGHT_LOOK, lw: 6, rims: [{ c: PAL.cyan, lx: 0, ly: 1, w: 8 }, { c: PAL.amber, lx: 1, ly: -0.2, w: 5 }] };
  const a = Farmer.side(ctx, 860, 990, 0.5, 1, { head: -0.35, lean: -0.05, armN: [0.3, 0.4] }, look);
  screenFill(ctx, PAL.lemon, 0.1, () => poly(ctx, [[a.lamp[0], a.lamp[1]], [a.lamp[0] + 260, a.lamp[1] - 360], [a.lamp[0] + 420, a.lamp[1] - 250]]));
  // pierwszy plan: dwa olbrzymy przy krawędziach i ich spody nad kadrem
  towercap(ctx, 170, 1080, 1.9, t, { capY: -20, gl: 0.6 + glowNear(170) * 0.8 });
  towercap(ctx, 1460, 1080, 1.6, t, { capY: -20, gl: 0.6 + glowNear(1460) * 0.8, lean: -30 });
  gillsUnder(ctx, 260, -60, 760, 210, t, PAL.cyan, 0.7 + glowNear(170) * 0.5, 1);
  gillsUnder(ctx, 1500, -80, 680, 190, t, PAL.cyan, 0.7 + glowNear(1460) * 0.5, 2);
  // zarodniki spod blaszek (gasną w drodze w dół)
  const rr = mulberry32(7);
  for (let i = 0; i < 140; i++) {
    const x0 = rr() * W, life = 0.3 + rr() * 0.7, n = Math.max(1, Math.round((60 + rr() * 60) * L / (900 * life))), sp = (n * 900 * life) / L;
    const yy = 150 + ((t * sp + rr() * 900) % (900 * life));
    const k = (yy - 150) / (900 * life);
    const xx = x0 + Math.sin(t * TAU / L + i) * 12;
    ctx.globalAlpha = 1 - k; ctx.fillStyle = rr() > 0.85 ? PAL.mint : '#bffcf5'; ctx.fillRect(xx, yy, 3, 3); ctx.globalAlpha = 1;
  }
  // nisko: świecące grzybki Glowcap
  for (const [x, y, s] of [[90, 1060, 1], [520, 1050, 0.8], [1050, 1070, 1.1], [1700, 1050, 0.9], [1290, 1000, 0.6]]) {
    for (let k = 0; k < 4; k++) {
      const gx = x + (k - 1.5) * 18 * s, gy = y - (k % 2) * 6;
      const tw = 0.7 + 0.3 * Math.sin(t * TAU * 0.5 + x + k);
      stroke(ctx, '#2c4a3c', 4 * s, () => poly(ctx, [[gx, gy], [gx + 2, gy - 26 * s]], false));
      halo(ctx, gx + 2, gy - 28 * s, 20 * s * tw, PAL.mint, 2, 0.16);
      fill(ctx, PAL.mint, () => path(ctx, [[gx - 10 * s, gy - 24 * s, 0], [gx + 2, gy - 36 * s], [gx + 14 * s, gy - 24 * s, 0]]));
    }
  }
}
SCENES.forest = {
  file: 'cn_5_mushroom_forest_pulse', frames: 48, fps: 12, keyFrame: 22, previewFrame: 22,
  draw(ctx, f, t) { drawForest(ctx, t); grain(ctx, 0.04); },
};

// ======================================================================
// 6. Pojedynek w trzech kadrach (split-screen jak w Samuraju Jacku)
// ======================================================================
function seedPod(ctx, x, y, s, glow) {
  halo(ctx, x, y, 70 * s * (0.8 + glow * 0.5), PAL.amber, 3, 0.1 + glow * 0.08);
  inked(ctx, () => path(ctx, [[x, y - 40 * s], [x + 30 * s, y - 6 * s], [x + 22 * s, y + 30 * s], [x - 22 * s, y + 30 * s], [x - 30 * s, y - 6 * s]]), mix(PAL.amberDeep, PAL.amber, glow), 6);
  for (const [dx, dy, r] of [[-8, -10, 7], [10, 6, 6], [-6, 16, 5]]) fill(ctx, mix(PAL.lemon, '#ffffff', glow * 0.5), () => circle(ctx, x + dx * s, y + dy * s, r * s));
}
function drawStandoff(ctx, f, t) {
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  const lb = (H - W / 2.35) / 2, top = lb, bot = H - lb, ph = bot - top;
  const g = 14;
  // wejścia kadrów
  const in1 = easeOut(t / 0.35), in2 = easeOut((t - 0.25) / 0.35), in3 = easeOut((t - 0.5) / 0.35);
  const narrow = smooth(1.2, 1.5, t), ignite = smooth(1.9, 2.05, t), squeeze = smooth(2.5, 2.7, t);
  const shake = t > 3.2 ? Math.sin(t * 80) * 4 * (1 - smooth(3.2, 3.9, t)) : 0;
  const wind = (ctx2, x0, x1) => { const rr = mulberry32(Math.floor(t * 12)); for (let i = 0; i < 6; i++) { const y = top + rr() * ph, x = x0 + rr() * (x1 - x0), len = 80 + rr() * 200; fill(ctx2, '#ffffff', () => poly(ctx2, [[x, y], [x + len, y - 1], [x + len, y + 2], [x, y + 1]]), 0.12); } };
  const panel = (x0, x1, dy, dx, fn) => {
    ctx.save(); ctx.beginPath(); ctx.rect(x0, top, x1 - x0, ph); ctx.clip();
    ctx.translate(dx + shake, dy); fn(x0, x1); wind(ctx, x0, x1);
    ctx.restore();
  };
  const P1 = [0, 520], P2 = [520 + g, 1400], P3 = [1400 + g, W];
  // kadr 1: oczy farmera w bańce
  if (in1 > 0) panel(P1[0], P1[1], -(1 - in1) * ph, 0, (x0, x1) => {
    ctx.fillStyle = '#16123a'; ctx.fillRect(x0, top, x1 - x0, ph);
    const look = { ...NIGHT_LOOK, lw: 1.1, rims: [{ c: PAL.cyan, lx: -0.5, ly: 0.9, w: 3 }, { c: '#a99cff', lx: 0.9, ly: -0.4, w: 2 }] };
    Farmer.front(ctx, 262, 540 + 282 * 8.2, 8.2, { eye: narrow > 0.5 ? 'narrow' : 'open', brow: 'angry', mouth: 'flat' }, look);
    // odbicie świecącej trawy na szybie
    ctx.save(); ctx.globalCompositeOperation = 'screen';
    for (let i = 0; i < 9; i++) { const x = 30 + i * 52; fill(ctx, PAL.cyan, () => poly(ctx, [[x, bot], [x + 12, bot - 90 - (i % 3) * 40], [x + 24, bot]]), 0.3); }
    ctx.restore();
    stroke(ctx, '#d6fffa', 16, () => ctx.arc(262, 560, 470, Math.PI * 1.08, Math.PI * 1.3));
  });
  // kadr 2: Thornback w ciemności
  if (in2 > 0) panel(P2[0], P2[1], (1 - in2) * ph, 0, (x0, x1) => {
    ctx.fillStyle = '#0c0a22'; ctx.fillRect(x0, top, x1 - x0, ph);
    fill(ctx, '#151137', () => ctx.ellipse(960, top + 120, 520, 160, 0, 0, TAU));
    moon(ctx, 1220, top + 120, 60, PAL.moon, PAL.moonShade, { phase: 0.5, seed: 3 });
    const look = { night: true, amt: 0.95, lw: 6, rims: [{ c: '#a99cff', lx: 0.6, ly: -0.8, w: 7 }, { c: PAL.cyan, lx: -0.2, ly: 1, w: 5 }] };
    Critters.thornback(ctx, 1240, bot + 40, 2.3, -1, { look, t, eyeC: mix('#3a2a20', PAL.amber, ignite), jaw: ignite * 0.15 });
    if (ignite > 0.5 && t < 2.15) { ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.fillStyle = rgba(PAL.amber, 0.25); ctx.fillRect(x0, top, x1 - x0, ph); ctx.restore(); }
    grassRow(ctx, bot + 10, 2.2, t, { base: '#07061a', tip: PAL.cyan, seed: 12, gap: 34, glow: 0.8 });
  });
  // kadr 3: dłoń z nasionem Boomshrooma
  if (in3 > 0) panel(P3[0], P3[1], 0, (1 - in3) * (W - P3[0]), (x0, x1) => {
    ctx.fillStyle = '#1a1340'; ctx.fillRect(x0, top, x1 - x0, ph);
    const cx = (x0 + x1) / 2, cy = top + ph * 0.55;
    const gl = 0.3 + squeeze * 0.7 + Math.sin(t * TAU * 2) * 0.08;
    seedPod(ctx, cx + 10, cy - 30, 2.1, gl);
    const glove = mix(PAL.glove, '#c9a23a', 0.25);
    // palce zaciskają się na nasionie
    for (let k = 0; k < 4; k++) {
      const yy = cy - 70 + k * 44, curl = squeeze * 24;
      cel(ctx, () => path(ctx, [[cx - 150, yy - 18], [cx - 10 - curl, yy - 22], [cx + 30 - curl, yy - 8], [cx + 34 - curl, yy + 14], [cx - 10 - curl, yy + 22], [cx - 150, yy + 20]]), glove, [rim(PAL.amber, 1, -0.3, 10), rim(PAL.cyan, -0.3, 1, 6)], 7);
    }
    cel(ctx, () => path(ctx, [[cx - 260, cy - 120], [cx - 120, cy - 110], [cx - 100, cy + 120], [cx - 260, cy + 140]]), glove, [rim(PAL.amber, 1, 0, 10)], 7);
    cel(ctx, () => path(ctx, [[cx - 140, cy + 90], [cx - 40, cy + 70 - squeeze * 20], [cx + 10, cy + 100 - squeeze * 30], [cx - 30, cy + 140], [cx - 150, cy + 150]]), glove, [rim(PAL.amber, 1, -0.5, 9)], 7);
  });
  // czarne pasy kina
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, top); ctx.fillRect(0, bot, W, lb);
}
SCENES.standoff = {
  file: 'cn_6_standoff_split', frames: 48, fps: 12, keyFrame: 30, previewFrame: 30,
  draw(ctx, f, t) { drawStandoff(ctx, f, t); grain(ctx, 0.04); },
};

// ======================================================================
// 7. Boomshroom: rzut, wyrośnięcie, wybuch (klatki uderzenia)
// ======================================================================
function drawBoom(ctx, f, t) {
  const G = 860, BX = 1080;
  const impact = f === 27 ? 1 : f === 28 ? 2 : 0;
  const shake = f > 28 && f < 38 ? Math.sin(f * 2.7) * (38 - f) * 2.2 : 0;
  ctx.save(); if (shake) { ctx.translate(W / 2, H / 2); ctx.scale(1.04, 1.04); ctx.translate(-W / 2 + shake, -H / 2 + shake * 0.4); }
  if (!impact) {
    skyBands(ctx, PAL.sky, 0, 640, 3, 8);
    stars(ctx, 77, 200, 0, 600, t);
    moon(ctx, 1600, 170, 90, PAL.moon, PAL.moonShade, { phase: 0.5, seed: 2 });
    crystalMountain(ctx, 400, 660, 600, 260, '#201a4c', '#2b2462', 2, { glow: 1, ledge: '#352d72' });
    crystalMountain(ctx, 1250, 660, 700, 320, '#201a4c', '#2b2462', 7, { glow: 1, ledge: '#352d72' });
    hillBand(ctx, 690, 16, PAL.mtnMid, 4);
    for (const [x, s, c] of [[150, 0.5, PAL.cyan], [1780, 0.6, PAL.violet], [640, 0.32, PAL.cyan]]) mushTree(ctx, x, 720, s, { trunk: PAL.mtnMid, cap: PAL.mtnMid, capLit: PAL.mtnMidLit, glow: c, seed: x, spots: false });
    ctx.fillStyle = PAL.ground; ctx.fillRect(0, 720, W, H);
    fill(ctx, PAL.groundLit, () => poly(ctx, [[0, 720], [W, 720], [W, 730], [0, 730]]));
  } else {
    ctx.fillStyle = impact === 1 ? '#fffdf4' : PAL.magenta; ctx.fillRect(-40, -40, W + 80, H + 80);
    // promienie
    for (let i = 0; i < 24; i++) { const a = (i / 24) * TAU + 0.1; fill(ctx, impact === 1 ? '#ffe9a8' : '#ff9be9', () => poly(ctx, [[BX, G - 80], [BX + Math.cos(a) * 2400, G - 80 + Math.sin(a) * 2400], [BX + Math.cos(a + 0.12) * 2400, G - 80 + Math.sin(a + 0.12) * 2400]])); }
  }
  const sil = impact ? { night: true, amt: 1, lw: 0, rims: [] } : null;
  const silFill = (fn) => { if (!impact) return fn(); ctx.save(); fn(); ctx.restore(); };
  // farmer: zamach i rzut
  const look = impact ? { night: true, amt: 1, into: '#000', lw: 6, rims: [] } : { ...NIGHT_LOOK, lw: 6 };
  const throwK = f < 3 ? f / 3 : f < 5 ? 1 + (f - 3) / 2 : 2;
  const armN = throwK <= 1 ? [lerp(0.2, -2.4, throwK), lerp(0.3, 0.9, throwK)] : [lerp(-2.4, 1.6, clamp(throwK - 1)), lerp(0.9, 0.1, clamp(throwK - 1))];
  const pose = { lean: f < 3 ? -0.12 : 0.18, armN, armF: [0.4, 0.5], legN: [0.35, 0.1], legF: [-0.3, 0.2], mouth: f > 40 ? 'flat' : 'grit', head: f > 28 ? -0.1 : 0, eye: f > 40 ? 'narrow' : 'open' };
  let fa;
  const SIL = impact ? (fn) => silhouette(ctx, '#000', (g) => fn(g)) : (fn) => fn(ctx);
  SIL((g) => { fa = Farmer.side(g, 330, G, 1.05, 1, pose, look); });
  // nasiono w locie
  if (f >= 5 && f < 12) {
    const k = (f - 5) / 7; const x = lerp(fa.hand[0], BX, k), y = lerp(fa.hand[1], G, k) - Math.sin(k * Math.PI) * 260;
    seedPod(ctx, x, y, 0.5, 0.6);
    for (let i = 1; i < 4; i++) { const kk = Math.max(0, k - i * 0.05); fill(ctx, PAL.amber, () => circle(ctx, lerp(fa.hand[0], BX, kk), lerp(fa.hand[1], G, kk) - Math.sin(kk * Math.PI) * 260, 6 - i), 0.5); }
  }
  // Muncherzy
  const mun = [[1500, 0.9, 0], [1680, 1.05, 0.4], [1360, 0.8, 0.8]];
  mun.forEach(([x0, s, ph], i) => {
    const mlook = impact ? { night: true, amt: 1, into: '#000', lw: 5, rims: [] } : { ...NIGHT_LOOK };
    if (f < 29) {
      const walk = Math.min(f, 22);
      const x = x0 - walk * (10 + i * 2);
      const hop = Math.abs(Math.sin((f / 3 + ph) * Math.PI)) * 26 * (f < 22 ? 1 : 0);
      SIL((g) => Critters.muncher(g, x, G - hop, s, -1, { look: mlook, squash: f >= 22 ? 1.12 : 1 }));
      if (f >= 22 && f < 27 && !impact) hudText(ctx, x, G - 120 * s - 10, '!', 54, PAL.lemon, 'center');
    } else {
      const k = (f - 29) / 18;
      const x = x0 - 22 * (10 + i * 2) + k * (700 + i * 160), y = G - Math.sin(Math.min(k * 1.4, 1) * Math.PI * 0.9) * (420 + i * 80) - k * 200;
      Critters.muncher(ctx, x, y, s, -1, { look: mlook, xEyes: true, spin: k * (8 + i * 2) });
    }
  });
  // Boomshroom
  if (f >= 12) {
    const blook = impact ? { night: true, amt: 1, into: '#000', lw: 6, rims: [] } : { ...NIGHT_LOOK };
    if (f < 18) {
      const st = [0.25, 0.25, 0.6, 0.6, 1.15, 1.15][f - 12];
      halo(ctx, BX, G - 20, 80 * st, PAL.amber, 2, 0.15);
      Critters.boomshroom(ctx, BX, G, 0.9 * st, { look: blook, spotGlow: true });
    } else if (f < 27) {
      const sw = (f - 18) / 9;
      Critters.boomshroom(ctx, BX, G, 1.0, { look: blook, spotGlow: true, swell: sw, shake: (f % 2 ? 1 : -1) * sw * 8 });
    } else if (impact) {
      SIL((g) => Critters.boomshroom(g, BX, G, 1.0, { look: blook, swell: 1.3, face: 'boom' }));
    }
  }
  // chmura zarodników
  if (f >= 29) {
    const k = (f - 29) / 18;
    const R = 120 + easeOut(k) * 520;
    const cols = [PAL.amber, PAL.rose, PAL.lemon, PAL.magenta];
    const rr = mulberry32(17);
    for (let i = 0; i < 16; i++) {
      const a = rr() * TAU, d = rr() * R * 0.75, rad = (60 + rr() * 90) * (1 - k * 0.55);
      const x = BX + Math.cos(a) * d, y = G - 90 + Math.sin(a) * d * 0.55 - k * 120;
      ctx.globalAlpha = 1 - smooth(0.55, 1, k);
      fill(ctx, cols[i % 4], () => circle(ctx, x, y, rad));
      ctx.globalAlpha = 1;
    }
    stroke(ctx, rgba('#ffffff', 1 - k), 10 * (1 - k) + 2, () => ctx.ellipse(BX, G - 40, R * 1.1, R * 0.32, 0, 0, TAU));
    for (let i = 0; i < 60; i++) {
      const a = rr() * TAU, d = R * (0.4 + rr() * 0.9);
      const x = BX + Math.cos(a) * d, y = G - 120 + Math.sin(a) * d * 0.5 - k * 160 + Math.sin(t * 3 + i) * 10;
      ctx.globalAlpha = 1 - k * 0.7; ctx.fillStyle = cols[i % 4]; ctx.beginPath(); ctx.arc(x, y, 3 + rr() * 4, 0, TAU); ctx.fill(); ctx.globalAlpha = 1;
      if (i % 5 === 0) halo(ctx, x, y, 18, cols[i % 4], 2, 0.15 * (1 - k));
    }
    // mały Boomshroom po wybuchu (opróżniony)
    Critters.boomshroom(ctx, BX, G, 0.6, { look: { ...NIGHT_LOOK }, face: 'grump' });
  }
  if (!impact) grassRow(ctx, 1060, 1.4, t, { base: PAL.fg, tip: PAL.cyan, seed: 5, gap: 36, glow: 0.8 });
  if (!impact) { ctx.fillStyle = PAL.fg; ctx.fillRect(-40, 1060, W + 80, 60); }
  ctx.restore();
}
SCENES.boom = {
  file: 'cn_7_boomshroom', frames: 48, fps: 12, keyFrame: 31, previewFrame: 27,
  draw(ctx, f, t) { drawBoom(ctx, f, t); if (f !== 27 && f !== 28) grain(ctx, 0.04); },
};

// ======================================================================
// 8. Dash: wyczekanie, smuga (smear), zatrzymanie w pozie
// ======================================================================
function sideBackdrop(ctx, t, G) {
  skyBands(ctx, PAL.sky, 0, 640, 14, 8);
  cloudStreak(ctx, 200, 260, 700, 14, '#2a2463');
  cloudStreak(ctx, 1000, 360, 760, 14, '#332a6e');
  stars(ctx, 91, 220, 0, 620, t);
  moon(ctx, 380, 190, 80, PAL.moon, PAL.moonShade, { phase: -0.5, seed: 6 });
  crystalMountain(ctx, 1450, 660, 760, 340, '#201a4c', '#2b2462', 4, { glow: 1, ledge: '#352d72', crystalCount: 5 });
  crystalMountain(ctx, 700, 670, 520, 240, '#201a4c', '#2b2462', 9, { glow: 1, ledge: '#352d72', crystalCount: 3 });
  hillBand(ctx, 700, 14, PAL.mtnMid, 6);
  for (const [x, s, c] of [[120, 0.55, PAL.cyan], [1000, 0.4, PAL.violet], [1800, 0.6, PAL.mint]]) mushTree(ctx, x, 730, s, { trunk: PAL.mtnMid, cap: PAL.mtnMid, capLit: PAL.mtnMidLit, glow: c, seed: x, spots: false });
  ctx.fillStyle = PAL.ground; ctx.fillRect(0, 730, W, H);
  fill(ctx, PAL.groundLit, () => poly(ctx, [[0, 730], [W, 730], [W, 740], [0, 740]]));
}
function drawDash(ctx, f, t) {
  const G = 900, X0 = 420, X1 = 1380;
  const smear = f === 10 || f === 11;
  sideBackdrop(ctx, t, G);
  // linie pędu na całym kadrze w klatkach smugi
  if (smear) { const rr = mulberry32(f); for (let i = 0; i < 26; i++) { const y = rr() * H, x = rr() * W, len = 300 + rr() * 700; fill(ctx, '#4b3f9e', () => poly(ctx, [[x, y], [x + len, y - 3], [x + len, y + 4], [x, y + 2]]), 0.8); } }
  const look = { ...NIGHT_LOOK, lw: 6 };
  // ścieżka: trawa przygnieciona i rozświetlona po przejściu
  const since = f - 10;
  const trail = since >= 0 ? clamp(1 - since / 14) : 0;
  const rr = mulberry32(5);
  for (let i = 0; i < 40; i++) {
    const x = rr() * W, y = G - 20 + rr() * 30;
    const onPath = x > X0 - 40 && x < X1 + 40;
    const flat = onPath && since >= 0 ? clamp(1 - (since - 1) / 6) : 0;
    grassClump(ctx, x, y, 0.8 + rr() * 0.4, t, { seed: i, base: '#0b0922', tip: PAL.cyan, glow: 0.55 + (onPath ? trail * 1.2 : 0), wave: () => (onPath ? flat * 1.6 : 0) });
  }
  // wstęga po dashu, rozpada się na kropki
  if (since >= 0 && trail > 0) {
    const k = since / 14;
    ctx.save(); ctx.globalCompositeOperation = 'screen';
    fill(ctx, PAL.cyan, () => path(ctx, [[X0 - 40, G - 150, 0], [lerp(X0, X1, 0.5), G - 190 + k * 40], [X1 - 60, G - 160, 0], [lerp(X0, X1, 0.5), G - 110 - k * 20]]), 0.5 * (1 - k));
    fill(ctx, '#d9fffb', () => path(ctx, [[X0 + 100, G - 152, 0], [lerp(X0, X1, 0.55), G - 168 + k * 20], [X1 - 120, G - 158, 0], [lerp(X0, X1, 0.55), G - 140]]), 0.6 * (1 - k * 1.5));
    ctx.restore();
    const r2 = mulberry32(9);
    for (let i = 0; i < 40; i++) { const u = r2(); const x = lerp(X0, X1, u), y = G - 150 + (r2() - 0.5) * 80 - k * 120 * r2(); const a = clamp(1 - k * (0.8 + r2())); if (a <= 0) continue; halo(ctx, x, y, 12, PAL.cyan, 2, 0.2 * a); fill(ctx, '#d9fffb', () => circle(ctx, x, y, 3.5), a); }
  }
  const idle = (k) => ({ lean: 0.04, legN: [0.1, 0.05], legF: [-0.12, 0.1], armN: [0.12 + Math.sin(k) * 0.03, 0.3], armF: [-0.1, 0.25], hip: [0, -128 + Math.sin(k) * 1.5] });
  if (f < 6) Farmer.side(ctx, X0, G, 1.15, 1, idle(t * 3), look);
  else if (f < 10) {
    // wyczekanie: przysiad w tył, ręce do tyłu (trzymane 4 klatki)
    Farmer.side(ctx, X0 - 30, G, 1.15, 1, { hip: [-10, -100], lean: -0.32, legN: [0.65, 1.3], legF: [-0.1, 0.9], footN: 0, footF: 0.2, armN: [-1.3, 0.3], armF: [-1.1, 0.4], mouth: 'grit', eye: 'narrow', head: 0.15, sy: 0.94 }, look);
    if (f >= 8) for (let i = 0; i < 3; i++) stroke(ctx, PAL.white, 4, () => poly(ctx, [[X0 - 160 - i * 10, G - 260 + i * 40], [X0 - 200 - i * 10, G - 270 + i * 40]], false));
  } else if (smear) {
    // smuga: wydłużona postać + duchy
    const mid = f === 10 ? 0.45 : 0.85;
    for (let i = 0; i < 4; i++) { const x = lerp(X0, X1, mid - i * 0.12); ctx.globalAlpha = 0.25 + i * 0; Farmer.side(ctx, x, G, 1.15, 1, { lean: 0.6, sx: 1.7, legN: [1.0, 0.6], legF: [-0.9, 0.4], armN: [1.4, 0.1], armF: [-1.2, 0.2] }, { ...look, rims: [] }); ctx.globalAlpha = 1; }
    Farmer.side(ctx, lerp(X0, X1, mid), G, 1.15, 1, { lean: 0.6, sx: 1.9, sy: 0.92, legN: [1.0, 0.6], legF: [-0.9, 0.4], armN: [1.4, 0.1], armF: [-1.2, 0.2], mouth: 'grit', eye: 'narrow' }, look);
  } else {
    // dojazd: wykrok, trzymany długo, potem powrót do stania
    const settle = clamp((f - 12) / 3), back = clamp((f - 22) / 4);
    const lunge = { hip: [0, -96], lean: 0.42, legN: [1.05, 0.5], legF: [-0.95, 0.35], footN: 0, footF: 0.3, armN: [-1.6, 0.4], armF: [0.6, 0.9], mouth: 'smirk', eye: 'open', head: -0.15 };
    const p = f < 12 ? { ...lunge, lean: 0.55, sx: 1.08, sy: 0.92 } : lunge;
    const pose = back > 0 ? { ...idle(t * 3), lean: lerp(0.42, 0.04, back), hip: [0, lerp(-96, -128, back)], legN: [lerp(1.05, 0.1, back), lerp(0.5, 0.05, back)], legF: [lerp(-0.95, -0.12, back), lerp(0.35, 0.1, back)] } : { ...p, lean: lerp(p.lean, 0.36, settle * 0.5) };
    Farmer.side(ctx, X1, G, 1.15, 1, { ...pose, mouth: 'flat' }, look);
    if (f < 16) { const k = (f - 12) / 4; for (let i = 0; i < 7; i++) { const a = -0.3 - i * 0.3; const d = 60 + k * 120; fill(ctx, PAL.mint, () => circle(ctx, X1 - 40 + Math.cos(Math.PI + a) * d, G - 10 + Math.sin(a) * d * 0.5, 9 * (1 - k) + 2)); } }
  }
  grassRow(ctx, 1080, 1.6, t, { base: PAL.fg, tip: PAL.cyan, seed: 8, gap: 44, glow: 0.8 });
  ctx.fillStyle = PAL.fg; ctx.fillRect(0, 1072, W, 10);
}
SCENES.dash = {
  file: 'cn_8_dash_smear', frames: 30, fps: 12, keyFrame: 10, previewFrame: 10,
  draw(ctx, f, t) { drawDash(ctx, f, t); grain(ctx, 0.04); },
};
