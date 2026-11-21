'use strict';
// Wspólne narzędzia rysunku w stylu "stary Cartoon Network / Tartakovsky":
// płaskie plamy koloru bez gradientów, tła bez konturu, postaci z grubym konturem,
// poświata jako schodkowe kręgi (bez rozmycia), drgający kontur (line boil).
const W = 1920, H = 1080;
const TAU = Math.PI * 2;

const PAL = {
  ink: '#0d0a1f',
  sky: ['#0f0d2b', '#151238', '#1c1847', '#241e56', '#2d2665', '#382e73'],
  star: '#fff4d6', starBlue: '#c4ecff',
  moon: '#f4ecd0', moonShade: '#d9cda6', moonPink: '#f7a9cd', moonPinkShade: '#de86b0',
  mtnFar: '#2a235d', mtnFarLit: '#372e74',
  mtnMid: '#1f1a4a', mtnMidLit: '#29225f',
  hill: '#171338', hillLit: '#201a4b',
  ground: '#100d28', groundLit: '#181433',
  fg: '#07051a',
  cyan: '#43f3e0', cyanDeep: '#16a6b6', mint: '#8bffb7', teal: '#0e5d6c',
  magenta: '#ff55da', violet: '#ab77ff', amber: '#ffb446', amberDeep: '#e5732c', lemon: '#fff48c', rose: '#ff7ba9',
  white: '#fbf8ee',
  // kolory własne farmera (w dzień)
  overall: '#3f72db', shirt: '#f2ede0', skin: '#f3bf98', hat: '#f3dd8e', hatBand: '#e3485c',
  bandana: '#da3a42', boot: '#6d3d22', glove: '#ffd23f', pack: '#cfe08a', hair: '#5b5368',
};

// ---------- liczby ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash(x, y, s) { const h = Math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453; return h - Math.floor(h); }
function lerp(a, b, t) { return a + (b - a) * t; }
function clamp(v, a = 0, b = 1) { return Math.max(a, Math.min(b, v)); }
function smooth(a, b, v) { const t = clamp((v - a) / (b - a)); return t * t * (3 - 2 * t); }
function ease(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
function easeOut(t) { return 1 - Math.pow(1 - clamp(t), 3); }
function easeIn(t) { return Math.pow(clamp(t), 3); }
function backOut(t, s = 1.7) { t = clamp(t) - 1; return t * t * ((s + 1) * t + s) + 1; }
// częstotliwość dociągnięta do całkowitej liczby cykli w pętli animacji (LOOPT ustawia index.html)
function qf(f) { const L = (typeof window !== 'undefined' && window.LOOPT) || 0; return L ? Math.max(1, Math.round(f * L)) / L : f; }
// "na dwójkach": rysunek zmienia się co 2 klatki przy 24 fps (tu animacje są w 12 fps, więc to po prostu klatka)
function hold(frame, n) { return Math.floor(frame / n) * n; }

// ---------- kolor ----------
function rgb(hex) { const v = parseInt(hex.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; }
function hex([r, g, b]) { return '#' + [r, g, b].map((c) => Math.round(clamp(c, 0, 255)).toString(16).padStart(2, '0')).join(''); }
function mix(a, b, t) { const A = rgb(a), B = rgb(b); return hex([lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t)]); }
function rgba(h, a) { const [r, g, b] = rgb(h); return `rgba(${r},${g},${b},${a})`; }
// nocny odcień koloru własnego: zostaje ślad barwy, reszta idzie w indygo
const NIGHT_TINT = '#8a80d8';
function multiply(a, b) { const A = rgb(a), B = rgb(b); return hex([A[0] * B[0] / 255, A[1] * B[1] / 255, A[2] * B[2] / 255]); }
function night(c, amt = 0.6, into = '#130f33') { return mix(multiply(c, NIGHT_TINT), into, clamp((amt - 0.3) * 0.9)); }

// ---------- drgający kontur ----------
const BOIL = { amp: 0, seed: 0 };
function setBoil(amp, seed) { BOIL.amp = amp; BOIL.seed = seed; }
function bx(x, y) {
  if (!BOIL.amp) return [x, y];
  const k = 0.09;
  return [x + (hash(x * k, y * k, BOIL.seed) - 0.5) * 2 * BOIL.amp, y + (hash(y * k + 3.1, x * k + 1.7, BOIL.seed + 9) - 0.5) * 2 * BOIL.amp];
}

// ---------- ścieżki ----------
// pts: [x,y] (gładki) albo [x,y,0] (ostry narożnik). Dodaje podścieżkę do bieżącej ścieżki.
function path(ctx, pts, closed = true, tension = 1) {
  const n = pts.length;
  const q = pts.map((p) => { const [x, y] = bx(p[0], p[1]); return [x, y, p[2] === 0]; });
  const get = (i) => (closed ? q[((i % n) + n) % n] : q[Math.max(0, Math.min(n - 1, i))]);
  ctx.moveTo(q[0][0], q[0][1]);
  const segs = closed ? n : n - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = get(i - 1), p1 = get(i), p2 = get(i + 1), p3 = get(i + 2);
    let c1x, c1y, c2x, c2y;
    if (p1[2]) { c1x = p1[0] + (p2[0] - p1[0]) / 3; c1y = p1[1] + (p2[1] - p1[1]) / 3; }
    else { c1x = p1[0] + ((p2[0] - p0[0]) / 6) * tension; c1y = p1[1] + ((p2[1] - p0[1]) / 6) * tension; }
    if (p2[2]) { c2x = p2[0] - (p2[0] - p1[0]) / 3; c2y = p2[1] - (p2[1] - p1[1]) / 3; }
    else { c2x = p2[0] - ((p3[0] - p1[0]) / 6) * tension; c2y = p2[1] - ((p3[1] - p1[1]) / 6) * tension; }
    ctx.bezierCurveTo(c1x, c1y, c2x, c2y, p2[0], p2[1]);
  }
  if (closed) ctx.closePath();
}
function poly(ctx, pts, closed = true) {
  pts.forEach((p, i) => { const [x, y] = bx(p[0], p[1]); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
  if (closed) ctx.closePath();
}
function ellipse(ctx, x, y, rx, ry, rot = 0) {
  // elipsa jako ścieżka z punktów, żeby też drgała
  const pts = [];
  const n = 14;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * TAU;
    const px = Math.cos(a) * rx, py = Math.sin(a) * ry;
    pts.push([x + px * Math.cos(rot) - py * Math.sin(rot), y + px * Math.sin(rot) + py * Math.cos(rot)]);
  }
  path(ctx, pts, true);
}
function circle(ctx, x, y, r) { ellipse(ctx, x, y, r, r); }

// ---------- wypełnienia ----------
function fill(ctx, color, fn, alpha = 1) {
  ctx.beginPath(); fn(); ctx.globalAlpha = alpha; ctx.fillStyle = color; ctx.fill(); ctx.globalAlpha = 1;
}
function stroke(ctx, color, lw, fn, cap = 'round') {
  ctx.beginPath(); fn(); ctx.lineWidth = lw; ctx.lineJoin = 'round'; ctx.lineCap = cap; ctx.strokeStyle = color; ctx.stroke();
}
function inked(ctx, fn, color, lw = 5) {
  ctx.beginPath(); fn();
  if (color) { ctx.fillStyle = color; ctx.fill(); }
  if (lw) { ctx.lineWidth = lw; ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.strokeStyle = PAL.ink; ctx.stroke(); }
}
// Płaskie cieniowanie celu: kolor bazowy + sierpy (kształt minus kształt przesunięty).
// layers: [{c, dx, dy}] — sierp powstaje po stronie przeciwnej do przesunięcia.
function cel(ctx, fn, base, layers = [], lw = 5) {
  ctx.beginPath(); fn(); ctx.fillStyle = base; ctx.fill();
  if (layers.length) {
    ctx.save();
    ctx.beginPath(); fn(); ctx.clip();
    for (const L of layers) {
      if (!L || !L.c) continue;
      ctx.beginPath(); fn();
      ctx.save(); ctx.translate(L.dx, L.dy); fn(); ctx.restore();
      ctx.globalAlpha = L.a ?? 1;
      ctx.fillStyle = L.c; ctx.fill('evenodd');
      ctx.globalAlpha = 1;
    }
    ctx.restore();
  }
  if (lw) { ctx.beginPath(); fn(); ctx.lineWidth = lw; ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.strokeStyle = PAL.ink; ctx.stroke(); }
}
// sierp światła od kierunku (lx, ly) (wektor DO światła), szerokość w
function rim(c, lx, ly, w, a = 1) { const l = Math.hypot(lx, ly) || 1; return { c, dx: (-lx / l) * w, dy: (-ly / l) * w, a }; }

// ---------- światło ----------
function halo(ctx, x, y, r, color, steps = 3, alpha = 0.2, squash = 1) {
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.fillStyle = color;
  for (let i = 0; i < steps; i++) {
    const rr = r * (1 - (i / steps) * 0.7);
    ctx.globalAlpha = alpha;
    ctx.beginPath(); ctx.ellipse(x, y, rr, rr * squash, 0, 0, TAU); ctx.fill();
  }
  ctx.restore();
}
function screenFill(ctx, color, alpha, fn) {
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.globalAlpha = alpha; ctx.fillStyle = color;
  ctx.beginPath(); fn(); ctx.fill(); ctx.restore();
}
function sparkle(ctx, x, y, r, color, fat = 0.14) {
  const f = r * fat;
  ctx.beginPath();
  ctx.moveTo(x, y - r);
  ctx.quadraticCurveTo(x + f, y - f, x + r, y);
  ctx.quadraticCurveTo(x + f, y + f, x, y + r);
  ctx.quadraticCurveTo(x - f, y + f, x - r, y);
  ctx.quadraticCurveTo(x - f, y - f, x, y - r);
  ctx.fillStyle = color; ctx.fill();
}

// ---------- tło: niebo ----------
function skyBands(ctx, colors, top, bottom, seed = 1, wav = 9) {
  const r = mulberry32(seed);
  ctx.fillStyle = colors[0]; ctx.fillRect(0, 0, W, H);
  const n = colors.length;
  for (let i = 1; i < n; i++) {
    const y = top + (bottom - top) * Math.pow(i / n, 0.75);
    const ph = r() * TAU, f = 0.0015 + r() * 0.002;
    ctx.beginPath(); ctx.moveTo(0, H); ctx.lineTo(0, y);
    for (let x = 0; x <= W; x += 32) ctx.lineTo(x, y + Math.sin(x * f + ph) * wav + Math.sin(x * f * 3.1 + ph * 2) * wav * 0.3);
    ctx.lineTo(W, H); ctx.closePath();
    ctx.fillStyle = colors[i]; ctx.fill();
  }
}
// długie, płaskie smugi chmur jak u Scotta Willsa
function cloudStreak(ctx, x, y, len, th, color, alpha = 1) {
  fill(ctx, color, () => path(ctx, [[x, y, 0], [x + len * 0.25, y - th * 0.9], [x + len * 0.6, y - th], [x + len, y, 0], [x + len * 0.55, y + th * 0.35], [x + len * 0.2, y + th * 0.3]]), alpha);
}
function stars(ctx, seed, count, top, bottom, t = 0, avoid = null) {
  const r = mulberry32(seed);
  for (let i = 0; i < count; i++) {
    const x = r() * W, y = top + Math.pow(r(), 1.4) * (bottom - top);
    const s = r(), ph = r() * TAU, sp = qf(0.3 + r() * 0.9);
    if (avoid && Math.hypot(x - avoid[0], y - avoid[1]) < avoid[2]) continue;
    const tw = 0.55 + 0.45 * Math.sin(t * sp * TAU + ph);
    const col = s > 0.7 ? PAL.starBlue : PAL.star;
    if (s > 0.94) {
      const k = r() > 0.5 ? 1 : 0.7;
      sparkle(ctx, x, y, (9 + 9 * s) * k * (0.6 + 0.4 * tw), col);
    } else {
      ctx.globalAlpha = 0.35 + 0.65 * tw * (0.4 + s * 0.6);
      ctx.fillStyle = col;
      ctx.fillRect(Math.round(x), Math.round(y), s > 0.6 ? 3 : 2, s > 0.6 ? 3 : 2);
      ctx.globalAlpha = 1;
    }
  }
}
function moon(ctx, x, y, r, col, shade, opts = {}) {
  halo(ctx, x, y, r * 2.4, col, 3, 0.07);
  fill(ctx, col, () => { ctx.arc(x, y, r, 0, TAU); });
  // płaski terminator
  ctx.save(); ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.clip();
  fill(ctx, shade, () => { ctx.arc(x - r * (opts.phase ?? 0.55), y + r * 0.15, r * 1.05, 0, TAU); ctx.arc(x - r * 2.6, y, r * 2.2, 0, TAU, true); });
  const rr = mulberry32(opts.seed ?? 7);
  for (let i = 0; i < (opts.craters ?? 6); i++) {
    const a = rr() * TAU, d = rr() * r * 0.75, cr = r * (0.08 + rr() * 0.16);
    fill(ctx, shade, () => ctx.ellipse(x + Math.cos(a) * d, y + Math.sin(a) * d, cr, cr * 0.8, 0, 0, TAU), 0.85);
  }
  ctx.restore();
}

// ---------- tło: góry z kryształami (jak w grze: schodkowe stożki) ----------
function crystalMountain(ctx, cx, baseY, w, h, col, lit, seed, opts = {}) {
  const r = mulberry32(seed);
  const steps = opts.steps ?? 4;
  const top = baseY - h;
  const plate = w * 0.13;
  // sylwetka: tarasy po obu stronach
  const left = [], right = [];
  for (let i = 0; i <= steps; i++) {
    const u = i / steps;
    const y = lerp(baseY, top, u);
    const hw = lerp(w / 2, plate, Math.pow(u, 0.9));
    const jitter = (r() - 0.5) * w * 0.03;
    left.push([cx - hw + jitter, y, 0]);
    if (i < steps) left.push([cx - hw + w * 0.035 + jitter, y - h / steps * 0.18, 0]);
    right.push([cx + hw + jitter * 0.5, y, 0]);
    if (i < steps) right.push([cx + hw - w * 0.035 + jitter * 0.5, y - h / steps * 0.18, 0]);
  }
  const sil = [...left, ...right.reverse()];
  fill(ctx, col, () => poly(ctx, sil));
  // oświetlona ścianka (księżyc z prawej): prawa część za grzbietem
  const ridgeX = (u) => cx + lerp(w * 0.08, plate * 0.2, u);
  const litPts = [[ridgeX(0), baseY]];
  for (let i = 0; i <= steps; i++) { const u = i / steps; litPts.push([ridgeX(u) + (r() - 0.5) * 6, lerp(baseY, top, u)]); }
  const rightSide = right.slice().reverse(); // od dołu do góry
  ctx.save(); ctx.beginPath(); poly(ctx, sil); ctx.clip();
  fill(ctx, lit, () => poly(ctx, [...litPts, ...rightSide.slice().reverse(), [cx + w, baseY]]));
  // jasne krawędzie tarasów
  for (let i = 1; i < steps; i++) {
    const u = i / steps, y = lerp(baseY, top, u), hw = lerp(w / 2, plate, Math.pow(u, 0.9));
    fill(ctx, opts.ledge ?? lit, () => poly(ctx, [[cx - hw + 6, y - 2], [cx + hw - 4, y - 2], [cx + hw - 10, y + 5], [cx - hw + 12, y + 5]]), 0.55);
  }
  ctx.restore();
  // kryształy na szczycie
  if (opts.crystals !== false) {
    const n = opts.crystalCount ?? 4;
    halo(ctx, cx, top - h * 0.08, plate * 2.2, (opts.crystalCol || [0, PAL.cyan])[1], 3, 0.06 * (opts.glow ?? 1), 0.75);
    for (let i = 0; i < n; i++) {
      const x = cx + (i - (n - 1) / 2) * plate * 0.55 + (r() - 0.5) * 8;
      const ch = h * (0.12 + r() * 0.1) * (i === 1 ? 1.3 : 1);
      const lean = (x - cx) / plate * 0.45 + (r() - 0.5) * 0.25;
      crystal(ctx, x, top + 6, ch, ch * 0.28, lean, opts.glow ?? 1, opts.crystalCol);
    }
  }
}
function crystal(ctx, x, y, h, w, lean, glow = 1, cols) {
  const c = cols || [PAL.cyanDeep, PAL.cyan, '#b9fff6'];
  const tx = x + Math.sin(lean) * h, ty = y - Math.cos(lean) * h;
  const nx = Math.cos(lean) * w / 2, ny = Math.sin(lean) * w / 2;
  if (glow) halo(ctx, lerp(x, tx, 0.5), lerp(y, ty, 0.5), h * 0.62, c[1], 2, 0.07 * glow);
  fill(ctx, c[0], () => poly(ctx, [[x - nx, y - ny], [tx, ty], [x + nx * 0.1, y + ny * 0.1]]));
  fill(ctx, c[1], () => poly(ctx, [[x + nx * 0.1, y + ny * 0.1], [tx, ty], [x + nx, y + ny]]));
  fill(ctx, c[2], () => poly(ctx, [[lerp(x, tx, 0.15) + nx * 0.25, lerp(y, ty, 0.15) + ny * 0.25], [tx, ty], [lerp(x, tx, 0.45) + nx * 0.55, lerp(y, ty, 0.45) + ny * 0.55]]), 0.8);
}

// ---------- łagodne wzgórza ----------
function hillBand(ctx, y, amp, color, seed, freq = 0.004, bottom = H) {
  const r = mulberry32(seed); const ph = r() * TAU, ph2 = r() * TAU;
  fill(ctx, color, () => {
    ctx.moveTo(0, bottom);
    for (let x = 0; x <= W + 20; x += 20) ctx.lineTo(x, y - Math.sin(x * freq + ph) * amp - Math.sin(x * freq * 2.7 + ph2) * amp * 0.35);
    ctx.lineTo(W, bottom); ctx.closePath();
  });
}
function hillY(x, y, amp, seed, freq = 0.004) {
  const r = mulberry32(seed); const ph = r() * TAU, ph2 = r() * TAU;
  return y - Math.sin(x * freq + ph) * amp - Math.sin(x * freq * 2.7 + ph2) * amp * 0.35;
}

// ---------- drzewo-grzyb (świeci od spodu) ----------
// x,y: podstawa trzonu; s: skala (1 = ok. 300 px wysokości)
function mushTree(ctx, x, y, s, o = {}) {
  const trunkC = o.trunk ?? PAL.hill, capC = o.cap ?? PAL.mtnMid, capLit = o.capLit ?? PAL.mtnMidLit;
  const glowC = o.glow ?? PAL.cyan, glowAmt = o.glowAmt ?? 1, lean = o.lean ?? 0.08;
  const h = 300 * s, cw = (o.capW ?? 260) * s, ch = (o.capH ?? 70) * s;
  const topX = x + lean * h, topY = y - h;
  const tw = 16 * s;
  // trzon
  fill(ctx, trunkC, () => path(ctx, [[x - tw * 1.6, y, 0], [x - tw * 0.8, y - h * 0.2], [topX - tw * 0.6, topY + ch * 0.4], [topX + tw * 0.6, topY + ch * 0.4], [x + tw * 0.9, y - h * 0.25], [x + tw * 1.8, y, 0]]));
  // pierścień
  fill(ctx, capC, () => path(ctx, [[lerp(x, topX, 0.62) - tw * 1.5, lerp(y, topY, 0.62), 0], [lerp(x, topX, 0.62) + tw * 1.5, lerp(y, topY, 0.62), 0], [lerp(x, topX, 0.58) + tw * 0.9, lerp(y, topY, 0.58) + 10 * s], [lerp(x, topX, 0.58) - tw * 0.9, lerp(y, topY, 0.58) + 10 * s]]));
  // spód kapelusza (świecące blaszki)
  const under = () => path(ctx, [[topX - cw / 2, topY, 0], [topX, topY + ch * 0.42], [topX + cw / 2, topY, 0], [topX, topY + ch * 0.12]]);
  if (glowAmt > 0) {
    halo(ctx, topX, topY + ch * 0.3, cw * 0.62, glowC, 3, 0.07 * glowAmt, 0.5);
    fill(ctx, mix(capC, glowC, 0.55 * glowAmt), under);
    // blaszki: promieniste kreski
    ctx.save(); ctx.beginPath(); under(); ctx.clip();
    for (let i = -9; i <= 9; i++) {
      const u = i / 9;
      stroke(ctx, mix(capC, glowC, 0.95 * glowAmt), 2.2 * s + 0.6, () => { ctx.moveTo(topX + u * cw * 0.08, topY + ch * 0.3); ctx.lineTo(topX + u * cw * 0.52, topY - 2); });
    }
    ctx.restore();
    // światło na trzonie
    fill(ctx, mix(trunkC, glowC, 0.35 * glowAmt), () => path(ctx, [[topX - tw * 0.5, topY + ch * 0.4, 0], [topX + tw * 0.6, topY + ch * 0.4, 0], [lerp(x, topX, 0.7) + tw * 0.7, lerp(y, topY, 0.7)], [lerp(x, topX, 0.7) - tw * 0.2, lerp(y, topY, 0.7)]]));
  } else fill(ctx, capC, under);
  // wierzch kapelusza
  const top = () => path(ctx, [[topX - cw / 2, topY, 0], [topX - cw * 0.36, topY - ch * 0.55], [topX - cw * 0.05, topY - ch], [topX + cw * 0.3, topY - ch * 0.8], [topX + cw / 2, topY, 0], [topX, topY + ch * 0.12]]);
  fill(ctx, capC, top);
  // oświetlony brzeg kapelusza (księżyc z prawej-góry)
  ctx.save(); ctx.beginPath(); top(); ctx.clip();
  ctx.beginPath(); top(); ctx.save(); ctx.translate(-cw * 0.07, ch * 0.2); top(); ctx.restore();
  ctx.fillStyle = capLit; ctx.fill('evenodd');
  ctx.restore();
  // jasne kropki na kapeluszu
  if (o.spots !== false) {
    const r = mulberry32(o.seed ?? 3);
    for (let i = 0; i < 6; i++) {
      const u = r() * 0.8 - 0.4, v = 0.25 + r() * 0.5;
      fill(ctx, o.spotC ?? mix(capLit, glowC, 0.25), () => ctx.ellipse(topX + u * cw, topY - ch * v * (1 - Math.abs(u)), 6 * s + r() * 8 * s, 4 * s + r() * 4 * s, 0, 0, TAU), 0.9);
    }
  }
}

// ---------- trawa ze świecącymi czubkami ----------
// x,y: podstawa kępy; s: skala; t: czas; o.wave(x)->0..1 dodatkowe rozjaśnienie (fala wiatru)
function grassClump(ctx, x, y, s, t, o = {}) {
  const r = mulberry32(o.seed ?? Math.floor(x * 13 + y * 7));
  const n = o.blades ?? 7;
  const base = o.base ?? PAL.fg, tip = o.tip ?? PAL.cyan;
  const wv = o.wave ? o.wave(x) : 0;
  const glow = (o.glow ?? 1) * (0.75 + 0.6 * wv);
  for (let i = 0; i < n; i++) {
    const bxp = x + (i - (n - 1) / 2) * 7 * s + (r() - 0.5) * 6 * s;
    const hgt = (40 + r() * 55) * s * (1 - Math.abs(i - (n - 1) / 2) / n * 0.8);
    const lean = (i - (n - 1) / 2) * 0.12 + (r() - 0.5) * 0.25;
    const wind = Math.sin(t * TAU * qf(o.speed ?? 0.5) + x * 0.006 + r() * 0.8) * 0.18 + wv * 0.35;
    const bend = lean + wind;
    const bw = (4 + r() * 3) * s;
    const pt = (u) => [bxp + Math.sin(bend * u) * hgt * u, y - Math.cos(bend * u * 0.6) * hgt * u];
    const [x1, y1] = pt(0.4), [x2, y2] = pt(0.72), [xt, yt] = pt(1);
    fill(ctx, base, () => poly(ctx, [[bxp - bw, y], [x1 - bw * 0.7, y1], [x2 - bw * 0.45, y2], [xt, yt], [x2 + bw * 0.45, y2], [x1 + bw * 0.7, y1], [bxp + bw, y]]));
    if (glow > 0.02) {
      const tc = mix(base, tip, clamp(glow));
      fill(ctx, tc, () => poly(ctx, [[x2 - bw * 0.45, y2], [xt, yt], [x2 + bw * 0.45, y2]]));
      if (r() < (o.haloChance ?? 0.1)) halo(ctx, xt, yt, 8 * s * (0.7 + wv), tip, 2, 0.12 * glow);
    }
  }
}
// rząd kęp wzdłuż linii terenu
function grassRow(ctx, y0, s, t, o = {}) {
  const r = mulberry32(o.seed ?? 11);
  const gap = (o.gap ?? 34) * s;
  for (let x = -20; x < W + 40; x += gap * (0.6 + r() * 0.8)) {
    const y = (o.yFn ? o.yFn(x) : y0) + (r() - 0.5) * (o.jy ?? 6) * s;
    if (o.skip && o.skip(x, y)) continue;
    grassClump(ctx, x, y, s * (0.7 + r() * 0.6), t, { ...o, seed: Math.floor(r() * 1e6) });
  }
}

// ---------- świetliki / zarodniki ----------
function fireflies(ctx, seed, count, box, t, col = PAL.lemon, o = {}) {
  const r = mulberry32(seed);
  const [x0, y0, x1, y1] = box;
  for (let i = 0; i < count; i++) {
    const bxp = lerp(x0, x1, r()), byp = lerp(y0, y1, r());
    const ph = r() * TAU, sp = qf(0.3 + r() * 0.5), sp2 = qf(0.2 + r() * 0.4), amp = 10 + r() * 30;
    const x = bxp + Math.sin(t * sp * TAU + ph) * amp, y = byp + Math.cos(t * sp2 * TAU + ph * 1.3) * amp * 0.6;
    const bl = Math.sin((t * qf(1 / (o.period ?? 2)) + r()) * TAU);
    const on = bl > (o.threshold ?? -0.2) ? 1 : 0.15;
    const rad = (o.size ?? 3) * (0.7 + r() * 0.6);
    if (on > 0.5) halo(ctx, x, y, rad * (o.haloK ?? 3.2), col, 2, 0.16);
    ctx.globalAlpha = on; ctx.fillStyle = mix(col, '#ffffff', 0.4);
    ctx.beginPath(); ctx.arc(x, y, rad, 0, TAU); ctx.fill(); ctx.globalAlpha = 1;
  }
}

// ---------- ziarno papieru ----------
let _grain = null;
function grain(ctx, alpha = 0.05, seed = 5) {
  if (!_grain) {
    _grain = document.createElement('canvas'); _grain.width = 512; _grain.height = 512;
    const g = _grain.getContext('2d'); const img = g.createImageData(512, 512); const r = mulberry32(seed);
    for (let i = 0; i < img.data.length; i += 4) { const v = r() * 255; img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255; }
    g.putImageData(img, 0, 0);
  }
  ctx.save(); ctx.globalAlpha = alpha; ctx.globalCompositeOperation = 'overlay';
  ctx.fillStyle = ctx.createPattern(_grain, 'repeat'); ctx.fillRect(0, 0, W, H); ctx.restore();
}
function letterbox(ctx, ratio = 2.2, col = '#000') {
  const h = (H - W / ratio) / 2; ctx.fillStyle = col; ctx.fillRect(0, 0, W, h); ctx.fillRect(0, H - h, W, h); return h;
}

// czarna (albo dowolna) sylwetka z dowolnego rysunku: klatki uderzenia
function silhouette(ctx, color, fn) {
  const c = document.createElement('canvas'); c.width = ctx.canvas.width; c.height = ctx.canvas.height;
  const g = c.getContext('2d'); g.setTransform(ctx.getTransform()); fn(g);
  g.setTransform(1, 0, 0, 1, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = color; g.fillRect(0, 0, c.width, c.height);
  ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(c, 0, 0); ctx.restore();
}
