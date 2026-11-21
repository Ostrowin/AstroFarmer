'use strict';
// Sceny: każda ma draw(ctx, frame, t, duration). frames > 1 = animacja (12 fps, rysunki "na dwójkach").
const SCENES = {};

// wspólne nocne światło postaci: chłodny sierp od księżyca + zimny turkus od roślin z dołu
const NIGHT_LOOK = {
  night: true, amt: 0.6, lw: 5,
  rims: [{ c: PAL.cyan, lx: -0.6, ly: 0.8, w: 7 }, { c: '#8f86e8', lx: 0.8, ly: -0.6, w: 5 }],
  glass: PAL.cyan, glassHi: '#d6fffa', lampOn: true,
};

function nightSky(ctx, t, o = {}) {
  skyBands(ctx, o.sky ?? PAL.sky, o.top ?? 0, o.horizon ?? 640, o.seed ?? 2, 8);
  cloudStreak(ctx, 120, 300, 640, 16, '#2c2566', 0.9);
  cloudStreak(ctx, 980, 250, 820, 13, '#2a2462', 0.9);
  cloudStreak(ctx, 540, 420, 900, 18, '#352c72', 0.9);
  cloudStreak(ctx, 1300, 470, 560, 10, '#3a2f77', 0.9);
  stars(ctx, o.starSeed ?? 21, o.starCount ?? 260, 0, o.horizon ?? 640, t, o.moon ? [o.moon[0], o.moon[1], o.moon[2] * 1.6] : null);
  if (o.moon) moon(ctx, o.moon[0], o.moon[1], o.moon[2], PAL.moon, PAL.moonShade, { phase: 0.5, seed: 4 });
  if (o.moon2) moon(ctx, o.moon2[0], o.moon2[1], o.moon2[2], PAL.moonPink, PAL.moonPinkShade, { phase: -0.6, seed: 9, craters: 3 });
}

// ======================================================================
// 1. Dolina nocą (ujęcie otwierające bazę)
// ======================================================================
function drawValley(ctx, t, o = {}) {
  const L = o.L ?? 4;
  const wave = (x) => { const k = ((t % L) / L) * 1.5 - 0.25; return Math.exp(-Math.pow((x / W - k) * 6, 2)); };
  nightSky(ctx, t, { moon: [1470, 220, 118], moon2: [330, 150, 34], horizon: 650 });
  // góry z kryształami
  crystalMountain(ctx, 330, 690, 640, 300, '#201a4c', '#2b2462', 5, { glow: 1, ledge: '#352d72' });
  crystalMountain(ctx, 1600, 690, 780, 350, '#201a4c', '#2b2462', 8, { glow: 1, crystalCount: 5, ledge: '#352d72' });
  crystalMountain(ctx, 960, 700, 560, 420, '#1b1644', '#272059', 12, { glow: 1.2, ledge: '#30286a' });
  // dalekie wzgórza z grzybami
  hillBand(ctx, 690, 22, PAL.mtnMid, 31, 0.004);
  const r = mulberry32(77);
  for (let i = 0; i < 16; i++) {
    const x = r() * W; if (x > 600 && x < 1350 && r() < 0.6) continue;
    mushTree(ctx, x, hillY(x, 690, 22, 31, 0.004) + 8, 0.22 + r() * 0.16, { trunk: PAL.mtnMid, cap: PAL.mtnMid, capLit: PAL.mtnMidLit, glowAmt: 0.75, glow: r() > 0.6 ? PAL.violet : PAL.cyan, seed: i, spots: false });
  }
  hillBand(ctx, 740, 18, PAL.hill, 41, 0.0035);
  // ziemia
  ctx.fillStyle = PAL.ground; ctx.fillRect(0, 760, W, H - 760);
  hillBand(ctx, 770, 10, PAL.ground, 45, 0.003);
  // świecący mech na ziemi
  for (const [mx, my, rx, c] of [[300, 830, 160, PAL.cyan], [1500, 860, 220, PAL.violet], [1750, 800, 120, PAL.mint], [520, 960, 200, PAL.mint], [1280, 1000, 240, PAL.cyan]]) {
    screenFill(ctx, c, 0.08, () => ctx.ellipse(mx, my, rx, rx * 0.16, 0, 0, TAU));
    screenFill(ctx, c, 0.1, () => ctx.ellipse(mx + 10, my, rx * 0.6, rx * 0.09, 0, 0, TAU));
  }
  // średnie drzewa-grzyby po bokach
  mushTree(ctx, 120, 790, 0.62, { trunk: PAL.hill, cap: PAL.hill, capLit: PAL.hillLit, glowAmt: 1, seed: 2, capW: 300 });
  mushTree(ctx, 1830, 800, 0.72, { trunk: PAL.hill, cap: PAL.hill, capLit: PAL.hillLit, glowAmt: 1, glow: PAL.violet, seed: 5, lean: -0.1 });
  mushTree(ctx, 1650, 780, 0.42, { trunk: PAL.hill, cap: PAL.hill, capLit: PAL.hillLit, glowAmt: 0.9, seed: 8 });
  // baza
  Props.hut(ctx, 620, 800, 0.78, { t });
  Props.gate(ctx, 1240, 790, 0.72, t);
  const items = Props.plots(ctx, [[760, 850], [1150, 850], [1270, 960], [660, 960]], 6, 3, t, { farScale: 0.36, nearScale: 0.5 });
  for (const it of items) {
    const k = (it.i + it.j * 2) % 4;
    if (k === 0) Critters.voidberry(ctx, it.p[0], it.p[1], it.sc * 0.8, t, { seed: it.i * 7 + it.j });
    else if (k === 1) Critters.moonpetal(ctx, it.p[0], it.p[1], it.sc * 0.9, t);
    else if (k === 2) crystal(ctx, it.p[0], it.p[1], 46 * it.sc, 16 * it.sc, (it.i - 3) * 0.08, 1);
    else Critters.voidberry(ctx, it.p[0], it.p[1], it.sc * 0.7, t, { seed: it.i * 3 + it.j, berry: PAL.cyan });
  }
  Props.tractor(ctx, 1420, 960, 0.62, t, { dir: -1, body: night('#f39a2c', 0.45), bodyLit: '#f7a948' });
  const dy = Math.sin(t * TAU * 0.5) * 6;
  Props.drone(ctx, 980, 700 + dy, 0.7, t, { beamLen: 220 - dy });
  // farmer przy grządkach z latarką
  const look = { ...NIGHT_LOOK, lw: 6 };
  const a = Farmer.side(ctx, 560, 990, 0.42, 1, { legN: [0.1, 0.05], legF: [-0.12, 0.1], armN: [0.5, 0.6], armF: [-0.2, 0.3], head: 0.12 }, look);
  // snop latarki (płaski klin)
  const [lx, ly] = a.lamp;
  screenFill(ctx, PAL.lemon, 0.12, () => poly(ctx, [[lx, ly], [lx + 330, ly + 40], [lx + 300, ly + 120]]));
  screenFill(ctx, PAL.lemon, 0.1, () => poly(ctx, [[lx, ly], [lx + 240, ly + 55], [lx + 220, ly + 100]]));
  // świetliki
  fireflies(ctx, 13, 46, [100, 620, 1800, 980], t, PAL.lemon, { size: 2.6 });
  // pierwszy plan: ciemna trawa ze świecącymi czubkami
  grassRow(ctx, 1040, 1.25, t, { base: PAL.fg, tip: PAL.cyan, seed: 3, wave, gap: 30, yFn: (x) => 1050 - Math.sin(x * 0.004) * 20 });
  fill(ctx, PAL.fg, () => { ctx.moveTo(0, H); for (let x = 0; x <= W; x += 20) ctx.lineTo(x, 1050 - Math.sin(x * 0.004) * 20); ctx.lineTo(W, H); });
  // wielki grzyb kadrujący z lewej
  mushTree(ctx, -40, 1120, 2.4, { trunk: PAL.fg, cap: PAL.fg, capLit: '#14112f', glowAmt: 1, seed: 1, lean: 0.12, capW: 230, capH: 60 });
  grassRow(ctx, 1080, 1.8, t, { base: PAL.fg, tip: PAL.mint, seed: 9, gap: 60, wave, skip: (x) => x > 500 && x < 1500 });
}
SCENES.valley = {
  file: 'cn_1_valley_night', loop: false,
  draw(ctx, f, t) { window.LOOPT = 4; drawValley(ctx, 1.3); grain(ctx, 0.05); },
};
SCENES.valleyLoop = {
  file: 'cn_1_valley_night_loop', frames: 48, fps: 12, keyFrame: 16, previewFrame: 16,
  draw(ctx, f, t) { drawValley(ctx, t); grain(ctx, 0.04); },
};

// ======================================================================
// 2. Plansza postaci (nocne światło)
// ======================================================================
function label(ctx, x, y, text, col = '#cfc8ff', size = 26) {
  ctx.save(); ctx.font = `900 ${size}px "Arial Black", "Segoe UI Black", sans-serif`; ctx.textAlign = 'center';
  ctx.lineWidth = 8; ctx.strokeStyle = PAL.ink; ctx.lineJoin = 'round'; ctx.strokeText(text, x, y);
  ctx.fillStyle = col; ctx.fillText(text, x, y); ctx.restore();
}
SCENES.cast = {
  file: 'cn_2_cast_night',
  draw(ctx, f, t) {
    skyBands(ctx, ['#120e2e', '#161238', '#1b1642', '#211a4d'], 0, 800, 4, 6);
    // daleka sylwetka łąki
    hillBand(ctx, 770, 16, '#1a1540', 3, 0.003);
    for (const [x, sc] of [[240, 0.35], [520, 0.25], [1180, 0.3], [1500, 0.22], [1780, 0.4]]) mushTree(ctx, x, hillY(x, 770, 16, 3, 0.003) + 6, sc, { trunk: '#1a1540', cap: '#1a1540', capLit: '#241d55', glowAmt: 0.7, spots: false, seed: x });
    ctx.fillStyle = '#0c0a23'; ctx.fillRect(0, 812, W, H - 812);
    for (let i = 0; i < 10; i++) screenFill(ctx, i % 2 ? PAL.cyan : PAL.mint, 0.07, () => ctx.ellipse(90 + i * 200, 816, 130, 12, 0, 0, TAU));
    grassRow(ctx, 1000, 1.0, 0.4, { base: '#07061a', tip: PAL.cyan, seed: 21, gap: 40 });
    ctx.fillStyle = '#07061a'; ctx.fillRect(0, 1000, W, 80);
    const look = { ...NIGHT_LOOK, lw: 6 };
    const G = 812;
    // obrót farmera: przód, bok, tył
    Farmer.front(ctx, 170, G, 1.08, { armL: [0.2, 0.15], armR: [0.2, 0.15], mouth: 'smirk', look: 0.5 }, look);
    Farmer.side(ctx, 390, G, 1.08, 1, { armN: [0.1, 0.2], armF: [-0.05, 0.15] }, look);
    Farmer.back(ctx, 610, G, 1.08, {}, look);
    // stworzenia i rośliny
    Critters.voidberry(ctx, 790, G, 0.9, 0.5);
    Critters.moonpetal(ctx, 905, G, 1.0, 0.2);
    Critters.boomshroom(ctx, 1030, G, 0.9, { look, spotGlow: true });
    Critters.snapper(ctx, 1180, G, 0.95, 0.2, { look, innerGlow: true, open: 0.75 });
    Critters.muncher(ctx, 1345, G, 1.15, -1, { look });
    Critters.thornback(ctx, 1680, G, 1.0, -1, { look, t: 0 });
    Critters.lumimoth(ctx, 1040, 290, 0.8, 0.3);
    Critters.drifter(ctx, 1500, 200, 0.7, 1.2);
    const L = [[390, 'THE FARMER', 0], [790, 'VOIDBERRY', 0], [905, 'MOONPETAL', 1], [1030, 'BOOMSHROOM', 0], [1180, 'SNAPPER', 1], [1345, 'MUNCHER', 0], [1680, 'THORNBACK', 1]];
    for (const [x, tx, row] of L) label(ctx, x, 866 + row * 32, tx, '#d9d2ff', 21);
    label(ctx, 1040, 405, 'LUMIMOTH', '#b8fff4', 21);
    label(ctx, 1690, 210, 'DRIFTER', '#e4d2ff', 21);
    grain(ctx, 0.05);
  },
};
