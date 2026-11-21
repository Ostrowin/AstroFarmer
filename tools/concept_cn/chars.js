'use strict';
// Postaci w stylu Tartakovsky'ego: proste bryły (odwrócony trapez tułowia, cienkie nogi,
// ciężkie buty, kwadratowa szczęka), gruby kontur, płaskie światło z sierpami.

function rot([x, y], a) { const c = Math.cos(a), s = Math.sin(a); return [x * c - y * s, x * s + y * c]; }
function add(a, b) { return [a[0] + b[0], a[1] + b[1]]; }
function dirv(a, len) { return [Math.sin(a) * len, Math.cos(a) * len]; }

// ścieżka "kiełbaski" przez punkty P z szerokościami Wd
function chainPath(ctx, P, Wd) {
  const n = P.length, Lp = [], Rp = [];
  const dirs = [];
  for (let i = 0; i < n; i++) {
    let dx, dy;
    if (i === 0) { dx = P[1][0] - P[0][0]; dy = P[1][1] - P[0][1]; }
    else if (i === n - 1) { dx = P[n - 1][0] - P[n - 2][0]; dy = P[n - 1][1] - P[n - 2][1]; }
    else {
      const a = Math.hypot(P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]) || 1, b = Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]) || 1;
      dx = (P[i + 1][0] - P[i][0]) / a + (P[i][0] - P[i - 1][0]) / b; dy = (P[i + 1][1] - P[i][1]) / a + (P[i][1] - P[i - 1][1]) / b;
    }
    const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l; dirs.push([dx, dy]);
    Lp.push([P[i][0] - dy * Wd[i], P[i][1] + dx * Wd[i]]);
    Rp.push([P[i][0] + dy * Wd[i], P[i][1] - dx * Wd[i]]);
  }
  const e = dirs[n - 1], s0 = dirs[0];
  const endCap = [P[n - 1][0] + e[0] * Wd[n - 1] * 0.85, P[n - 1][1] + e[1] * Wd[n - 1] * 0.85];
  const startCap = [P[0][0] - s0[0] * Wd[0] * 0.85, P[0][1] - s0[1] * Wd[0] * 0.85];
  path(ctx, [...Lp, endCap, ...Rp.reverse(), startCap]);
}

const Farmer = {
  cols(look) {
    const f = (k, extra = 0) => (look.night ? night(PAL[k], (look.amt ?? 0.6) + extra, look.into) : PAL[k]);
    return {
      overall: f('overall'), shirt: f('shirt', -0.06), skin: f('skin'), hat: f('hat', -0.06), band: f('hatBand'), bandana: f('bandana'),
      boot: f('boot'), sole: night(PAL.boot, 0.85), glove: f('glove', -0.08), pack: f('pack'), hair: f('hair'), metal: f('starBlue', 0.15),
      far: (c) => mix(c, PAL.ink, 0.28),
    };
  },
  layers(look, dir) { return (look.rims || []).map((r) => rim(r.c, r.lx * dir, r.ly, r.w, r.a ?? 1)); },

  // ---------------- widok z boku (patrzy w prawo dla dir = 1) ----------------
  side(ctx, x, y, s, dir, pose, look) {
    const p = { hip: [0, -128], lean: 0.05, legN: [0.05, 0.05], legF: [-0.06, 0.08], armN: [0.15, 0.3], armF: [-0.1, 0.25], head: 0, footN: 0, footF: 0, eye: 'open', brow: 'angry', mouth: 'flat', sx: 1, sy: 1, ...pose };
    const C = this.cols(look), Ls = this.layers(look, dir), lw = look.lw ?? 5;
    const farLs = Ls.map((l) => ({ ...l, a: (l.a ?? 1) * 0.55 }));
    ctx.save(); ctx.translate(x, y); ctx.scale(s * dir * p.sx, s * p.sy);
    const hip = p.hip;
    const T = (pt) => add(hip, rot(pt, p.lean));
    const shN = T([8, -90]), shF = T([0, -94]);
    // ramię dalsze
    this.arm(ctx, shF, p.armF, C, farLs, lw, true);
    // noga dalsza
    this.leg(ctx, hip, p.legF, p.footF, C, farLs, lw, true);
    // plecak
    ctx.save(); ctx.translate(hip[0], hip[1]); ctx.rotate(p.lean);
    const pack = () => path(ctx, [[-60, -96, 0], [-26, -100, 0], [-22, -28, 0], [-58, -24, 0]]);
    cel(ctx, pack, C.pack, Ls, lw);
    fill(ctx, mix(C.pack, PAL.ink, 0.3), () => poly(ctx, [[-59, -72], [-24, -74], [-24, -66], [-59, -64]]));
    fill(ctx, mix(C.pack, PAL.ink, 0.3), () => poly(ctx, [[-58, -46], [-23, -47], [-23, -40], [-58, -39]]));
    // rurka do hełmu
    stroke(ctx, PAL.ink, lw + 6, () => path(ctx, [[-44, -98], [-40, -122], [-18, -140]], false));
    stroke(ctx, C.metal, 6, () => path(ctx, [[-44, -98], [-40, -122], [-18, -140]], false));
    // tułów
    const torso = () => path(ctx, [[-17, 6], [-24, -40], [-30, -82], [-22, -100], [-4, -108], [18, -106], [36, -93], [46, -70], [41, -38], [24, -6], [16, 8]]);
    cel(ctx, torso, C.shirt, Ls, 0);
    ctx.save(); ctx.beginPath(); torso(); ctx.clip();
    cel(ctx, () => poly(ctx, [[-40, -24], [60, -26], [60, 20], [-40, 20]]), C.overall, Ls, 0);
    cel(ctx, () => path(ctx, [[0, -20, 0], [50, -22, 0], [50, -76, 0], [16, -80, 0]]), C.overall, Ls, 0);
    stroke(ctx, C.overall, 10, () => path(ctx, [[24, -78], [10, -104], [-20, -98], [-30, -50]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[0, -20], [16, -80]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[-40, -24], [3, -24]], false));
    stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[22, -58], [40, -58], [40, -44], [24, -44]], false));
    fill(ctx, C.glove, () => circle(ctx, 22, -74, 3.6));
    ctx.restore();
    inked(ctx, torso, null, lw);
    // apaszka
    cel(ctx, () => path(ctx, [[8, -110, 0], [34, -100, 0], [34, -82, 0], [24, -94], [10, -100]]), C.bandana, Ls, lw);
    ctx.restore();
    // noga bliższa
    this.leg(ctx, hip, p.legN, p.footN, C, Ls, lw, false);
    // głowa w hełmie
    const hc = T([14, -140]);
    const anchors = this.headSide(ctx, hc, p.lean + p.head, p, C, Ls, lw, look);
    // ramię bliższe
    const hand = this.arm(ctx, shN, p.armN, C, Ls, lw, false);
    const m = (window.BASE_INV || new DOMMatrix()).multiply(ctx.getTransform());
    const toWorld = (pt) => { const q = m.transformPoint(new DOMPoint(pt[0], pt[1])); return [q.x, q.y]; };
    const out = { lamp: toWorld(anchors.lamp), lampTip: toWorld(anchors.lampTip), head: toWorld(hc), hand: toWorld(hand) };
    ctx.restore();
    return out;
  },
  leg(ctx, hip, [th, kn], foot, C, Ls, lw, far) {
    const K = add(hip, dirv(th, 58)), A = add(K, dirv(th - kn, 56));
    const col = far ? C.far(C.overall) : C.overall;
    cel(ctx, () => chainPath(ctx, [hip, K, A], [11, 8.5, 7.5]), col, Ls, lw);
    ctx.save(); ctx.translate(A[0], A[1]); ctx.rotate(foot);
    const boot = () => path(ctx, [[-12, -12], [9, -12], [19, -5], [33, 1], [36, 9, 0], [34, 16, 0], [-15, 16, 0], [-16, 3]]);
    cel(ctx, boot, far ? C.far(C.boot) : C.boot, Ls, 0);
    fill(ctx, C.sole, () => poly(ctx, [[-15, 10], [36, 10], [34, 16], [-15, 16]]));
    inked(ctx, boot, null, lw);
    ctx.restore();
    return A;
  },
  arm(ctx, sh, [a, e], C, Ls, lw, far) {
    const E = add(sh, dirv(a, 48)), Wr = add(E, dirv(a + e, 42));
    const k = far ? C.far : (c) => c;
    cel(ctx, () => chainPath(ctx, [sh, E, Wr], [8, 6.5, 5.5]), k(C.skin), Ls, lw);
    const S2 = add(sh, dirv(a, 34));
    cel(ctx, () => chainPath(ctx, [add(sh, dirv(a, -4)), S2], [11, 10]), k(C.shirt), Ls, lw);
    // rękawica
    const fa = a + e;
    const G = add(Wr, dirv(fa, 9));
    ctx.save(); ctx.translate(G[0], G[1]); ctx.rotate(-fa);
    cel(ctx, () => path(ctx, [[-11, -6], [-2, -9], [11, -6], [13, 6], [6, 14], [-6, 14], [-12, 6]]), k(C.glove), Ls, lw);
    cel(ctx, () => ellipse(ctx, 11, -2, 5, 7, 0.4), k(C.glove), Ls, lw * 0.8);
    stroke(ctx, PAL.ink, lw * 0.8, () => poly(ctx, [[-12, -9], [12, -9]], false));
    ctx.restore();
    return G;
  },
  headSide(ctx, hc, tilt, p, C, Ls, lw, look) {
    ctx.save(); ctx.translate(hc[0], hc[1]); ctx.rotate(tilt);
    // kołnierz hełmu
    cel(ctx, () => ellipse(ctx, 4, 46, 34, 9), C.metal, Ls, lw);
    // szyja
    cel(ctx, () => poly(ctx, [[-8, 44], [-10, 20], [12, 20], [14, 44]]), C.skin, Ls, lw);
    const head = () => path(ctx, [[-23, -4], [-21, -24], [-6, -34], [13, -32], [24, -20], [27, -9, 0], [35, -1], [27, 5, 0], [30, 9], [42, 17], [38, 33, 0], [6, 35], [-15, 23, 0], [-21, 10]]);
    cel(ctx, head, C.skin, Ls, lw);
    // włosy (spod kapelusza)
    cel(ctx, () => path(ctx, [[-23, -4], [-22, -22], [-8, -31], [4, -28], [-8, -18], [-12, -2]]), C.hair, [], lw * 0.8);
    // ucho
    cel(ctx, () => ellipse(ctx, -6, 2, 5, 7), C.skin, Ls, lw * 0.8);
    // oko i brew
    if (p.eye === 'narrow') stroke(ctx, PAL.ink, 4.5, () => poly(ctx, [[12, -11], [21, -12]], false));
    else if (p.eye === 'closed') stroke(ctx, PAL.ink, 3.5, () => path(ctx, [[11, -11], [16, -8], [21, -11]], false));
    else fill(ctx, PAL.ink, () => ellipse(ctx, 17, -11, 3.6, 4.8));
    if (p.brow === 'angry') fill(ctx, PAL.ink, () => poly(ctx, [[6, -24], [27, -16], [26, -12], [6, -19]]));
    else fill(ctx, PAL.ink, () => poly(ctx, [[7, -21], [26, -22], [26, -18], [7, -17]]));
    // usta + dołek w brodzie
    if (p.mouth === 'grit') { fill(ctx, PAL.white, () => poly(ctx, [[20, 12], [34, 12], [34, 18], [21, 18]])); stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[20, 12], [34, 12], [34, 18], [21, 18]])); }
    else if (p.mouth === 'open') fill(ctx, PAL.ink, () => path(ctx, [[22, 10], [34, 11], [31, 20], [24, 19]]));
    else stroke(ctx, PAL.ink, 3, () => poly(ctx, [[22, 12], [33, 11]], false));
    stroke(ctx, PAL.ink, 2.5, () => path(ctx, [[36, 22], [33, 27]], false));
    // kapelusz w bańce (rondo opiera się o szybę)
    cel(ctx, () => path(ctx, [[-44, -27, 0], [-6, -33], [52, -29, 0], [50, -24, 0], [-4, -24], [-43, -22, 0]]), C.hat, Ls, lw);
    cel(ctx, () => path(ctx, [[-20, -29, 0], [-19, -50], [2, -54], [24, -50], [26, -29, 0]]), C.hat, Ls, lw);
    fill(ctx, C.band, () => path(ctx, [[-20, -30, 0], [-20, -38, 0], [26, -38, 0], [26, -30, 0]]));
    stroke(ctx, PAL.ink, lw * 0.6, () => path(ctx, [[-20, -38], [26, -38]], false));
    // bańka hełmu
    const R = 57, cx = 6, cy = -6;
    screenFill(ctx, look.glass ?? PAL.starBlue, 0.1, () => ctx.arc(cx, cy, R, 0, TAU));
    stroke(ctx, look.glassHi ?? PAL.white, 6, () => { ctx.arc(cx, cy, R - 10, Math.PI * 1.08, Math.PI * 1.42); });
    fill(ctx, look.glassHi ?? PAL.white, () => circle(ctx, cx - 30, cy - 38, 3.5));
    ctx.beginPath(); circle(ctx, cx, cy, R); ctx.lineWidth = lw * 0.9; ctx.strokeStyle = PAL.ink; ctx.stroke();
    // lampa na hełmie
    const la = -1.05;
    const lx = cx + Math.cos(la) * R, ly = cy + Math.sin(la) * R;
    ctx.save(); ctx.translate(lx, ly); ctx.rotate(la + Math.PI / 2 + 0.35);
    cel(ctx, () => path(ctx, [[-9, -4, 0], [9, -4, 0], [9, 8, 0], [-9, 8, 0]]), C.metal, Ls, lw * 0.8);
    fill(ctx, look.lampOn ? PAL.lemon : C.metal, () => poly(ctx, [[-7, -9], [7, -9], [8, -4], [-8, -4]]));
    inked(ctx, () => poly(ctx, [[-7, -9], [7, -9], [8, -4], [-8, -4]]), null, lw * 0.6);
    ctx.restore();
    const out = { lamp: [lx + Math.cos(la) * 8, ly + Math.sin(la) * 8], lampTip: [lx + Math.cos(la + 0.35) * 30, ly + Math.sin(la + 0.35) * 30] };
    ctx.restore();
    return { lamp: add(hc, rot(out.lamp, tilt)), lampTip: add(hc, rot(out.lampTip, tilt)) };
  },

  // ---------------- widok z przodu ----------------
  front(ctx, x, y, s, pose, look) {
    const p = { armL: [0.22, 0.25], armR: [0.22, 0.25], spread: 18, eye: 'open', brow: 'angry', mouth: 'flat', look: 0, sy: 1, sx: 1, headTilt: 0, ...pose };
    const C = this.cols(look), Ls = this.layers(look, 1), lw = look.lw ?? 5;
    ctx.save(); ctx.translate(x, y); ctx.scale(s * p.sx, s * p.sy);
    const hipY = -128;
    // plecak wystaje zza ramion
    cel(ctx, () => path(ctx, [[-44, -230, 0], [44, -230, 0], [44, -150, 0], [-44, -150, 0]]), C.far(C.pack), Ls, lw);
    // nogi
    for (const sg of [-1, 1]) {
      const hp = [sg * 14, hipY], an = [sg * p.spread, -14];
      cel(ctx, () => chainPath(ctx, [hp, [lerp(hp[0], an[0], 0.5), -70], an], [12, 9, 8]), C.overall, Ls, lw);
      const boot = () => path(ctx, [[sg * p.spread - 15, -14], [sg * p.spread + 15, -14], [sg * p.spread + 22 * 1, 4], [sg * p.spread + 20, 16, 0], [sg * p.spread - 20, 16, 0], [sg * p.spread - 22, 4]]);
      cel(ctx, boot, C.boot, Ls, 0);
      fill(ctx, C.sole, () => poly(ctx, [[sg * p.spread - 21, 9], [sg * p.spread + 21, 9], [sg * p.spread + 20, 16], [sg * p.spread - 20, 16]]));
      inked(ctx, boot, null, lw);
    }
    // ramiona (za tułowiem tylko barki)
    const torso = () => path(ctx, [[-24, hipY + 8], [-30, hipY - 40], [-52, hipY - 84], [-60, hipY - 98], [-48, hipY - 108], [0, hipY - 112], [48, hipY - 108], [60, hipY - 98], [52, hipY - 84], [30, hipY - 40], [24, hipY + 8]]);
    cel(ctx, torso, C.shirt, Ls, 0);
    ctx.save(); ctx.beginPath(); torso(); ctx.clip();
    cel(ctx, () => poly(ctx, [[-70, hipY - 26], [70, hipY - 26], [70, hipY + 20], [-70, hipY + 20]]), C.overall, Ls, 0);
    cel(ctx, () => poly(ctx, [[-27, hipY - 20], [27, hipY - 20], [25, hipY - 76], [-25, hipY - 76]]), C.overall, Ls, 0);
    for (const sg of [-1, 1]) stroke(ctx, C.overall, 11, () => path(ctx, [[sg * 20, hipY - 74], [sg * 30, hipY - 100], [sg * 36, hipY - 116]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[-70, hipY - 26], [-27, hipY - 26]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[27, hipY - 26], [70, hipY - 26]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[-27, hipY - 20], [-25, hipY - 76], [25, hipY - 76], [27, hipY - 20]], false));
    stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[-12, hipY - 60], [12, hipY - 60], [12, hipY - 44], [-12, hipY - 44]]));
    for (const sg of [-1, 1]) fill(ctx, C.glove, () => circle(ctx, sg * 19, hipY - 70, 4));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[0, hipY - 26], [0, hipY + 10]], false));
    ctx.restore();
    inked(ctx, torso, null, lw);
    // apaszka
    cel(ctx, () => path(ctx, [[-22, hipY - 112, 0], [22, hipY - 112, 0], [2, hipY - 84, 0]]), C.bandana, Ls, lw);
    // ręce
    for (const [sg, ar] of [[-1, p.armL], [1, p.armR]]) {
      const sh = [sg * 52, hipY - 96];
      const E = add(sh, [sg * Math.sin(ar[0]) * 48, Math.cos(ar[0]) * 48]);
      const fa = ar[0] - ar[1];
      const Wr = add(E, [sg * Math.sin(fa) * 42, Math.cos(fa) * 42]);
      cel(ctx, () => chainPath(ctx, [sh, E, Wr], [8.5, 7, 6]), C.skin, Ls, lw);
      cel(ctx, () => chainPath(ctx, [add(sh, [0, -4]), add(sh, [sg * Math.sin(ar[0]) * 33, Math.cos(ar[0]) * 33])], [13, 11]), C.shirt, Ls, lw);
      const G = add(Wr, [sg * Math.sin(fa) * 9, Math.cos(fa) * 9]);
      cel(ctx, () => path(ctx, [[G[0] - 11, G[1] - 8], [G[0] + 11, G[1] - 8], [G[0] + 13, G[1] + 6], [G[0] + 5, G[1] + 14], [G[0] - 5, G[1] + 14], [G[0] - 13, G[1] + 6]]), C.glove, Ls, lw);
      cel(ctx, () => ellipse(ctx, G[0] - sg * 12, G[1] - 1, 5, 7), C.glove, Ls, lw * 0.8);
    }
    // głowa
    ctx.save(); ctx.translate(0, hipY - 146); ctx.rotate(p.headTilt);
    cel(ctx, () => ellipse(ctx, 0, 46, 38, 10), C.metal, Ls, lw);
    cel(ctx, () => poly(ctx, [[-11, 46], [-12, 22], [12, 22], [11, 46]]), C.skin, Ls, lw);
    for (const sg of [-1, 1]) cel(ctx, () => ellipse(ctx, sg * 24, 2, 6, 8), C.skin, Ls, lw * 0.8);
    const head = () => path(ctx, [[-20, -24], [-14, -34], [14, -34], [20, -24], [22, 0], [27, 22, 0], [16, 38, 0], [-16, 38, 0], [-27, 22, 0], [-22, 0]]);
    cel(ctx, head, C.skin, Ls, lw);
    cel(ctx, () => path(ctx, [[-20, -24], [-14, -34], [14, -34], [20, -24], [20, -14], [8, -22], [-10, -20], [-20, -12]]), C.hair, [], lw * 0.8);
    const lk = p.look * 3;
    for (const sg of [-1, 1]) {
      if (p.eye === 'narrow') stroke(ctx, PAL.ink, 4.5, () => poly(ctx, [[sg * 6 + lk - 4, -8], [sg * 6 + lk + 4, -8]], false));
      else if (p.eye === 'closed') stroke(ctx, PAL.ink, 3.5, () => path(ctx, [[sg * 7 - 4, -9], [sg * 7, -6], [sg * 7 + 4, -9]], false));
      else fill(ctx, PAL.ink, () => ellipse(ctx, sg * 8 + lk, -8, 3.4, 4.6));
      if (p.brow === 'angry') fill(ctx, PAL.ink, () => poly(ctx, [[sg * 18, -21], [sg * 3, -15], [sg * 3, -11], [sg * 18, -17]]));
      else fill(ctx, PAL.ink, () => poly(ctx, [[sg * 18, -19], [sg * 3, -19], [sg * 3, -15], [sg * 18, -15]]));
    }
    stroke(ctx, PAL.ink, 3, () => path(ctx, [[-2, -2], [-4, 6], [2, 7]], false));
    if (p.mouth === 'grit') { fill(ctx, PAL.white, () => poly(ctx, [[-10, 14], [10, 14], [9, 21], [-9, 21]])); stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[-10, 14], [10, 14], [9, 21], [-9, 21]])); stroke(ctx, PAL.ink, 2, () => poly(ctx, [[0, 14], [0, 21]], false)); }
    else if (p.mouth === 'smirk') stroke(ctx, PAL.ink, 3, () => path(ctx, [[-9, 16], [2, 17], [10, 12]], false));
    else stroke(ctx, PAL.ink, 3, () => poly(ctx, [[-9, 16], [9, 15]], false));
    stroke(ctx, PAL.ink, 2.5, () => path(ctx, [[0, 30], [0, 37]], false));
    // kapelusz
    cel(ctx, () => ellipse(ctx, 0, -30, 54, 9), C.hat, Ls, lw);
    cel(ctx, () => path(ctx, [[-25, -30, 0], [-24, -52], [0, -56], [24, -52], [25, -30, 0]]), C.hat, Ls, lw);
    fill(ctx, C.band, () => poly(ctx, [[-25, -31], [-25, -39], [25, -39], [25, -31]]));
    stroke(ctx, PAL.ink, lw * 0.6, () => poly(ctx, [[-25, -39], [25, -39]], false));
    // bańka
    const R = 60;
    screenFill(ctx, look.glass ?? PAL.starBlue, 0.1, () => ctx.arc(0, -4, R, 0, TAU));
    stroke(ctx, look.glassHi ?? PAL.white, 6, () => ctx.arc(0, -4, R - 10, Math.PI * 1.1, Math.PI * 1.4));
    fill(ctx, look.glassHi ?? PAL.white, () => circle(ctx, -32, -42, 3.5));
    ctx.beginPath(); circle(ctx, 0, -4, R); ctx.lineWidth = lw * 0.9; ctx.strokeStyle = PAL.ink; ctx.stroke();
    // lampa
    cel(ctx, () => path(ctx, [[-10, -70, 0], [10, -70, 0], [8, -58, 0], [-8, -58, 0]]), C.metal, Ls, lw * 0.8);
    fill(ctx, look.lampOn ? PAL.lemon : C.metal, () => poly(ctx, [[-7, -68], [7, -68], [6, -61], [-6, -61]]));
    ctx.restore();
    ctx.restore();
  },

  // ---------------- widok z tyłu (kamera TPP) ----------------
  back(ctx, x, y, s, pose, look) {
    const p = { phase: 0, run: 0, armSwing: 0, sy: 1, ...pose };
    const C = this.cols(look), Ls = this.layers(look, 1), lw = look.lw ?? 5;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s * p.sy);
    const bob = -Math.abs(Math.sin(p.phase)) * 6 * p.run;
    const hipY = -128 + bob;
    // nogi: krok widziany z tyłu = noga unosi się i skraca
    for (const sg of [-1, 1]) {
      const ph = p.phase + (sg > 0 ? Math.PI : 0);
      const lift = Math.max(0, Math.sin(ph)) * 26 * p.run;
      const hp = [sg * 14, hipY], an = [sg * 17, -14 - lift];
      cel(ctx, () => chainPath(ctx, [hp, [sg * 16, lerp(hipY, an[1], 0.5)], an], [12, 9.5, 8]), C.overall, Ls, lw);
      const bt = () => path(ctx, [[an[0] - 15, an[1]], [an[0] + 15, an[1]], [an[0] + 18, an[1] + 10], [an[0] + 15, an[1] + 18 - lift * 0.3, 0], [an[0] - 15, an[1] + 18 - lift * 0.3, 0], [an[0] - 18, an[1] + 10]]);
      cel(ctx, bt, C.boot, Ls, 0);
      fill(ctx, C.sole, () => poly(ctx, [[an[0] - 16, an[1] + 12 - lift * 0.2], [an[0] + 16, an[1] + 12 - lift * 0.2], [an[0] + 15, an[1] + 18 - lift * 0.3], [an[0] - 15, an[1] + 18 - lift * 0.3]]));
      inked(ctx, bt, null, lw);
    }
    // ręce (p.aim: prawa ręka z pistoletem wyciągnięta przed siebie, widać ją zza barku)
    let gun = null;
    for (const sg of [-1, 1]) {
      if (p.aim && sg > 0) {
        const sh = [52, hipY - 96], E = [76, hipY - 112], Wr = [86, hipY - 140];
        cel(ctx, () => chainPath(ctx, [sh, E, Wr], [8.5, 7, 6]), C.skin, Ls, lw);
        cel(ctx, () => chainPath(ctx, [add(sh, [0, -4]), add(sh, [14, -10])], [13, 11]), C.shirt, Ls, lw);
        cel(ctx, () => poly(ctx, [[Wr[0] - 8, Wr[1] - 4], [Wr[0] + 8, Wr[1] - 4], [Wr[0] + 6, Wr[1] - 40], [Wr[0] - 6, Wr[1] - 40]]), '#3a3560', [rim(PAL.lemon, 0.3, -1, 4)], lw);
        fill(ctx, PAL.lemon, () => poly(ctx, [[Wr[0] - 6, Wr[1] - 40], [Wr[0] + 6, Wr[1] - 40], [Wr[0] + 5, Wr[1] - 46], [Wr[0] - 5, Wr[1] - 46]]));
        cel(ctx, () => ellipse(ctx, Wr[0], Wr[1] + 4, 12, 11), C.glove, Ls, lw);
        gun = [Wr[0], Wr[1] - 46];
        continue;
      }
      const sw = Math.sin(p.phase + (sg > 0 ? 0 : Math.PI)) * p.armSwing;
      const sh = [sg * 52, hipY - 96];
      const E = add(sh, [sg * 10, 46 - sw * 8]);
      const Wr = add(E, [sg * 4, 40 - sw * 14]);
      cel(ctx, () => chainPath(ctx, [sh, E, Wr], [8.5, 7, 6]), C.skin, Ls, lw);
      cel(ctx, () => chainPath(ctx, [add(sh, [0, -4]), add(sh, [sg * 7, 32])], [13, 11]), C.shirt, Ls, lw);
      cel(ctx, () => ellipse(ctx, Wr[0] + sg * 1, Wr[1] + 9, 12, 12), C.glove, Ls, lw);
    }
    const torso = () => path(ctx, [[-24, hipY + 8], [-30, hipY - 40], [-52, hipY - 84], [-60, hipY - 98], [-48, hipY - 108], [0, hipY - 112], [48, hipY - 108], [60, hipY - 98], [52, hipY - 84], [30, hipY - 40], [24, hipY + 8]]);
    cel(ctx, torso, C.shirt, Ls, 0);
    ctx.save(); ctx.beginPath(); torso(); ctx.clip();
    cel(ctx, () => poly(ctx, [[-70, hipY - 30], [70, hipY - 30], [70, hipY + 20], [-70, hipY + 20]]), C.overall, Ls, 0);
    for (const sg of [-1, 1]) stroke(ctx, C.overall, 11, () => poly(ctx, [[sg * 6, hipY - 30], [sg * 40, hipY - 108]], false));
    stroke(ctx, PAL.ink, 3, () => poly(ctx, [[-70, hipY - 30], [70, hipY - 30]], false));
    stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[-22, hipY - 18], [-6, hipY - 18], [-7, hipY - 2], [-21, hipY - 2]]));
    stroke(ctx, PAL.ink, 2.5, () => poly(ctx, [[22, hipY - 18], [6, hipY - 18], [7, hipY - 2], [21, hipY - 2]]));
    ctx.restore();
    inked(ctx, torso, null, lw);
    // plecak
    const pack = () => path(ctx, [[-36, hipY - 104, 0], [36, hipY - 104, 0], [38, hipY - 34, 0], [-38, hipY - 34, 0]]);
    cel(ctx, pack, C.pack, Ls, lw);
    for (const yy of [hipY - 84, hipY - 56]) fill(ctx, mix(C.pack, PAL.ink, 0.32), () => poly(ctx, [[-37, yy], [37, yy], [37, yy + 8], [-37, yy + 8]]));
    cel(ctx, () => circle(ctx, 18, hipY - 68, 7), C.metal, [], lw * 0.7);
    fill(ctx, look.packLight ?? PAL.mint, () => circle(ctx, -20, hipY - 96, 4));
    halo(ctx, -20, hipY - 96, 14, look.packLight ?? PAL.mint, 2, 0.2);
    stroke(ctx, PAL.ink, lw + 6, () => path(ctx, [[-20, hipY - 104], [-24, hipY - 124], [-8, hipY - 140]], false));
    stroke(ctx, C.metal, 6, () => path(ctx, [[-20, hipY - 104], [-24, hipY - 124], [-8, hipY - 140]], false));
    // głowa od tyłu
    ctx.save(); ctx.translate(0, hipY - 146);
    cel(ctx, () => ellipse(ctx, 0, 46, 38, 10), C.metal, Ls, lw);
    for (const sg of [-1, 1]) cel(ctx, () => ellipse(ctx, sg * 23, 2, 6, 8), C.skin, Ls, lw * 0.8);
    cel(ctx, () => poly(ctx, [[-13, 20], [13, 20], [11, 42], [-11, 42]]), C.skin, Ls, lw);
    cel(ctx, () => path(ctx, [[-21, -22], [-14, -34], [14, -34], [21, -22], [23, 4], [17, 28, 0], [-17, 28, 0], [-23, 4]]), C.skin, Ls, lw);
    cel(ctx, () => path(ctx, [[-23, -24], [-14, -36], [14, -36], [23, -24], [25, 6], [17, 21], [6, 16], [-6, 16], [-17, 21], [-25, 6]]), mix(C.hair, PAL.ink, 0.35), Ls, lw);
    // węzeł apaszki na karku
    for (const sg of [-1, 1]) cel(ctx, () => path(ctx, [[0, 38, 0], [sg * 16, 30, 0], [sg * 14, 48, 0]]), C.bandana, Ls, lw * 0.8);
    cel(ctx, () => ellipse(ctx, 0, 39, 5, 5), C.bandana, [], lw * 0.8);
    cel(ctx, () => ellipse(ctx, 0, -30, 54, 9), C.hat, Ls, lw);
    cel(ctx, () => path(ctx, [[-25, -30, 0], [-24, -52], [0, -56], [24, -52], [25, -30, 0]]), C.hat, Ls, lw);
    fill(ctx, C.band, () => poly(ctx, [[-25, -31], [-25, -39], [25, -39], [25, -31]]));
    const R = 60;
    screenFill(ctx, look.glass ?? PAL.starBlue, 0.1, () => ctx.arc(0, -4, R, 0, TAU));
    stroke(ctx, look.glassHi ?? PAL.white, 6, () => ctx.arc(0, -4, R - 10, Math.PI * 1.6, Math.PI * 1.85));
    ctx.beginPath(); circle(ctx, 0, -4, R); ctx.lineWidth = lw * 0.9; ctx.strokeStyle = PAL.ink; ctx.stroke();
    cel(ctx, () => path(ctx, [[-10, -70, 0], [10, -70, 0], [8, -58, 0], [-8, -58, 0]]), C.metal, Ls, lw * 0.8);
    ctx.restore();
    const m = (window.BASE_INV || new DOMMatrix()).multiply(ctx.getTransform());
    const q = m.transformPoint(new DOMPoint(0, hipY - 146 - 66));
    const g = gun ? m.transformPoint(new DOMPoint(gun[0], gun[1])) : null;
    ctx.restore();
    return { lamp: [q.x, q.y], gun: g ? [g.x, g.y] : null };
  },
};

// ---------------- stworzenia ----------------
const Critters = {
  // Muncher: okrągły szkodnik z zębami (Chrupik)
  muncher(ctx, x, y, s, dir, o = {}) {
    const look = o.look || {}; const Ls = (look.rims || []).map((r) => rim(r.c, r.lx * dir, r.ly, r.w)); const lw = look.lw ?? 5;
    const body = look.night ? night('#efe7bd', look.amt ?? 0.58) : '#efe7bd';
    const sq = o.squash ?? 1;
    ctx.save(); ctx.translate(x, y); ctx.scale(s * dir, s); if (o.spin) ctx.rotate(o.spin);
    for (const fx of [-14, 14]) cel(ctx, () => ellipse(ctx, fx, -4, 11, 6), mix(body, PAL.ink, 0.2), Ls, lw);
    for (const [ex, ang] of [[-14, -0.35], [12, 0.3]]) cel(ctx, () => path(ctx, [[ex - 6, -60 * sq], [ex + Math.sin(ang) * 18 - 2, -60 * sq - 22, 0], [ex + 7, -58 * sq]]), mix(body, PAL.ink, 0.15), Ls, lw);
    const b = () => path(ctx, [[-38, -30 * sq], [-28, -62 * sq], [0, -72 * sq], [30, -62 * sq], [40, -30 * sq], [26, -6], [-26, -6]]);
    cel(ctx, b, body, Ls, lw);
    fill(ctx, PAL.white, () => poly(ctx, [[2, -30 * sq], [12, -30 * sq], [12, -16 * sq], [2, -16 * sq]]));
    fill(ctx, PAL.white, () => poly(ctx, [[14, -30 * sq], [24, -30 * sq], [23, -17 * sq], [14, -17 * sq]]));
    stroke(ctx, PAL.ink, 3, () => { poly(ctx, [[2, -30 * sq], [12, -30 * sq], [12, -16 * sq], [2, -16 * sq]]); poly(ctx, [[14, -30 * sq], [24, -30 * sq], [23, -17 * sq], [14, -17 * sq]]); });
    stroke(ctx, PAL.ink, 3.5, () => path(ctx, [[-4, -32 * sq], [13, -29 * sq], [30, -33 * sq]], false));
    const eyeC = o.eyeGlow ? PAL.lemon : PAL.white;
    for (const [ex, ey] of [[0, -48], [26, -50]]) {
      if (o.xEyes) { stroke(ctx, PAL.ink, 4, () => { poly(ctx, [[ex - 6, ey * sq - 6], [ex + 6, ey * sq + 6]], false); poly(ctx, [[ex - 6, ey * sq + 6], [ex + 6, ey * sq - 6]], false); }); continue; }
      if (o.eyeGlow) halo(ctx, ex, ey * sq, 22, PAL.lemon, 2, 0.16);
      inked(ctx, () => circle(ctx, ex, ey * sq, 9.5), eyeC, 3.5);
      fill(ctx, PAL.ink, () => circle(ctx, ex + 3, ey * sq + 1, 4));
    }
    ctx.restore();
  },
  // Thornback: ciężki drapieżnik z kolcami i świecącymi grzybkami na grzbiecie (patrzy w prawo dla dir = 1)
  thornback(ctx, x, y, s, dir, o = {}) {
    const look = o.look || {}; const Ls = (look.rims || []).map((r) => rim(r.c, r.lx * dir, r.ly, r.w)); const lw = look.lw ?? 6;
    const body = look.night ? night('#8f63d1', look.amt ?? 0.55) : '#8f63d1';
    const dark = mix(body, PAL.ink, 0.3);
    const spikeC = look.night ? night('#ffb54a', 0.35) : '#ffb54a';
    const t = o.t ?? 0; const breathe = 1 + Math.sin(t * TAU * qf(0.5)) * 0.015;
    const jaw = o.jaw ?? 0;
    ctx.save(); ctx.translate(x, y); ctx.scale(s * dir, s * breathe);
    // nogi dalsze
    for (const lx of [-70, 60]) cel(ctx, () => path(ctx, [[lx - 16, -60], [lx + 14, -60], [lx + 16, -2, 0], [lx - 18, -2, 0]]), mix(dark, PAL.ink, 0.25), [], lw);
    // kolce na grzbiecie
    const spine = (u) => [lerp(-120, 70, u), -150 - Math.sin(u * Math.PI) * 30];
    for (let i = 0; i < 8; i++) {
      const u = 0.06 + i / 8; const [sx, sy] = spine(u); const hgt = 34 + Math.sin(u * Math.PI) * 30;
      cel(ctx, () => path(ctx, [[sx - 14, sy + 14, 0], [sx + 4, sy - hgt, 0], [sx + 16, sy + 12, 0]]), spikeC, Ls, lw * 0.8);
    }
    const torso = () => path(ctx, [[-150, -90], [-128, -150], [-60, -184], [30, -182], [92, -150], [118, -110], [104, -60], [40, -46], [-60, -48], [-130, -58]]);
    cel(ctx, torso, body, Ls, lw);
    // brzuch
    ctx.save(); ctx.beginPath(); torso(); ctx.clip();
    fill(ctx, dark, () => path(ctx, [[-150, -60], [-60, -78], [60, -76], [130, -70], [130, 0], [-150, 0]]));
    ctx.restore();
    inked(ctx, torso, null, lw);
    // głowa
    ctx.save(); ctx.translate(108, -122);
    const jawFn = () => path(ctx, [[-18, 14], [60, 18 + jaw * 30], [86, 26 + jaw * 40, 0], [70, 40 + jaw * 40], [-10, 44]]);
    cel(ctx, jawFn, dark, Ls, lw);
    for (let i = 0; i < 4; i++) fill(ctx, PAL.white, () => poly(ctx, [[18 + i * 16, 18 + jaw * (8 + i * 8)], [26 + i * 16, 18 + jaw * (8 + i * 8)], [22 + i * 16, 4 + jaw * (8 + i * 8)]]));
    const head = () => path(ctx, [[-30, -40], [20, -52], [78, -34], [96, -6, 0], [88, 14, 0], [10, 16], [-30, 20]]);
    cel(ctx, head, body, Ls, lw);
    for (let i = 0; i < 4; i++) fill(ctx, PAL.white, () => poly(ctx, [[30 + i * 15, 14], [38 + i * 15, 14], [34 + i * 15, 27]]));
    // oko: żarząca się szparka
    const eyeC = o.eyeC ?? PAL.amber;
    halo(ctx, 44, -22, 34, eyeC, 3, 0.14);
    fill(ctx, PAL.ink, () => path(ctx, [[24, -28, 0], [64, -22, 0], [58, -12, 0], [28, -16, 0]]));
    fill(ctx, eyeC, () => path(ctx, [[30, -24, 0], [58, -20, 0], [54, -15, 0], [33, -18, 0]]));
    fill(ctx, PAL.ink, () => poly(ctx, [[18, -40], [66, -26], [64, -21], [20, -34]]));
    ctx.restore();
    // nogi bliższe
    for (const lx of [-96, 40]) cel(ctx, () => path(ctx, [[lx - 22, -80], [lx + 22, -84], [lx + 22, -2, 0], [lx - 24, -2, 0]]), body, Ls, lw);
    for (const lx of [-96, 40]) for (let k = 0; k < 3; k++) fill(ctx, PAL.white, () => poly(ctx, [[lx - 22 + k * 15, -2], [lx - 14 + k * 15, -2], [lx - 18 + k * 15, 8]]));
    // świecące grzybki na grzbiecie
    if (o.glow !== false) {
      for (const [u, h2, c] of [[0.2, 22, PAL.mint], [0.36, 30, PAL.cyan], [0.5, 18, PAL.mint], [0.7, 26, PAL.cyan]]) {
        const [gx, gy] = spine(u); const yy = gy + 30;
        stroke(ctx, mix(PAL.white, c, 0.4), 4, () => poly(ctx, [[gx, yy], [gx + 2, yy - h2]], false));
        halo(ctx, gx + 2, yy - h2, 26, c, 3, 0.15);
        fill(ctx, c, () => path(ctx, [[gx - 13, yy - h2 + 3, 0], [gx - 8, yy - h2 - 7], [gx + 2, yy - h2 - 11], [gx + 12, yy - h2 - 7], [gx + 17, yy - h2 + 3, 0]]));
      }
    }
    ctx.restore();
  },
  // Lumimoth: nocna ćma, skrzydła ze świecącymi oczkami
  lumimoth(ctx, x, y, s, t, o = {}) {
    const flap = o.flap ?? Math.sin(t * TAU * qf(1.5));
    const wy = 0.55 + 0.45 * Math.abs(flap);
    const wingC = o.wing ?? '#2b2156', spotC = o.spot ?? PAL.cyan, lw = o.lw ?? 4;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    for (const sg of [-1, 1]) {
      ctx.save(); ctx.scale(sg, wy);
      const up = () => path(ctx, [[4, -6], [40, -62], [104, -78], [120, -52, 0], [96, -14], [10, 6]]);
      const lo = () => path(ctx, [[6, 4], [70, 4], [86, 40], [60, 70, 0], [20, 40]]);
      halo(ctx, 70, -38, 70, spotC, 2, 0.06);
      cel(ctx, lo, mix(wingC, PAL.ink, 0.2), [], lw);
      cel(ctx, up, wingC, [rim(PAL.violet, 0, -1, 6)], lw);
      for (const [cx, cy, rr] of [[78, -44, 15], [52, 30, 10]]) {
        halo(ctx, cx, cy, rr * 2.6, spotC, 2, 0.18);
        fill(ctx, spotC, () => ellipse(ctx, cx, cy, rr, rr * 0.7, 0.3));
        fill(ctx, PAL.white, () => ellipse(ctx, cx + 2, cy - 1, rr * 0.4, rr * 0.28, 0.3));
      }
      fill(ctx, spotC, () => path(ctx, [[30, -30], [92, -66], [100, -62], [36, -26]]), 0.8);
      ctx.restore();
    }
    cel(ctx, () => path(ctx, [[-10, -24], [10, -24], [12, 30], [0, 58, 0], [-12, 30]]), '#3b2f66', [rim(PAL.violet, 0, -1, 4)], lw);
    for (const sg of [-1, 1]) {
      stroke(ctx, PAL.ink, 3, () => path(ctx, [[sg * 4, -24], [sg * 18, -52], [sg * 34, -62]], false));
      for (let k = 0; k < 5; k++) stroke(ctx, PAL.ink, 2, () => poly(ctx, [[sg * (10 + k * 5), -40 - k * 4.5], [sg * (16 + k * 5), -48 - k * 4.5]], false));
      halo(ctx, sg * 7, -20, 12, PAL.amber, 2, 0.25);
      fill(ctx, PAL.amber, () => circle(ctx, sg * 7, -20, 5));
    }
    ctx.restore();
  },
  // Drifter: latająca meduza
  drifter(ctx, x, y, s, t, o = {}) {
    const bellC = o.bell ?? PAL.violet, coreC = o.core ?? '#e8d6ff', lw = o.lw ?? 4;
    const pulse = 1 + Math.sin(t * TAU * qf(0.75)) * 0.06;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    // macki
    for (let i = 0; i < 9; i++) {
      const u = (i / 8) * 2 - 1, bx0 = u * 70;
      const pts = [];
      for (let k = 0; k <= 6; k++) { const v = k / 6; pts.push([bx0 * (1 - v * 0.3) + Math.sin(t * TAU * qf(0.5) + i + v * 3) * 18 * v, 20 + v * (230 + (i % 3) * 30)]); }
      stroke(ctx, PAL.ink, 7, () => path(ctx, pts, false));
      stroke(ctx, mix(bellC, PAL.white, 0.35), 3.5, () => path(ctx, pts, false));
      const e = pts[pts.length - 1];
      halo(ctx, e[0], e[1], 16, coreC, 2, 0.25);
      fill(ctx, coreC, () => circle(ctx, e[0], e[1], 5));
    }
    halo(ctx, 0, -40, 170, bellC, 3, 0.08);
    const bell = () => path(ctx, [[-100 * pulse, 20, 0], [-92 * pulse, -50], [-50, -100 / pulse], [0, -112 / pulse], [50, -100 / pulse], [92 * pulse, -50], [100 * pulse, 20, 0], [60, 8], [20, 22], [-20, 8], [-60, 22]]);
    ctx.save(); ctx.globalAlpha = 0.82; cel(ctx, bell, mix(bellC, '#1a1542', 0.35), [rim(mix(bellC, PAL.white, 0.4), 0.3, -1, 12)], 0); ctx.restore();
    inked(ctx, bell, null, lw);
    halo(ctx, 0, -46, 70, coreC, 3, 0.2);
    fill(ctx, coreC, () => ellipse(ctx, 0, -46, 34 * pulse, 30 * pulse));
    fill(ctx, PAL.white, () => ellipse(ctx, -10, -56, 10, 7));
    stroke(ctx, mix(bellC, PAL.white, 0.6), 5, () => path(ctx, [[-70, -66], [-40, -92], [-6, -100]], false));
    ctx.restore();
  },
  // Boomshroom: gruby grzyb-bomba; swell 0..1 nadyma, face: 'grump' | 'boom'
  boomshroom(ctx, x, y, s, o = {}) {
    const look = o.look || {}; const Ls = (look.rims || []).map((r) => rim(r.c, r.lx, r.ly, r.w)); const lw = look.lw ?? 5;
    const sw = o.swell ?? 0, shake = o.shake ?? 0;
    const capC = look.night ? night('#ef5a2f', 0.4) : '#ef5a2f', stemC = look.night ? night('#f4e3bf', 0.55) : '#f4e3bf';
    const spotC = o.spotGlow ? PAL.lemon : (look.night ? night('#fff1c6', 0.35) : '#fff1c6');
    ctx.save(); ctx.translate(x + shake, y); ctx.scale(s * (1 + sw * 0.25), s * (1 + sw * 0.12));
    const stem = () => path(ctx, [[-30, 0, 0], [-36, -36], [-26, -70], [26, -70], [36, -36], [30, 0, 0]]);
    cel(ctx, stem, stemC, Ls, lw);
    // twarz
    if (o.face === 'boom') { fill(ctx, PAL.ink, () => ellipse(ctx, 0, -28, 12, 14)); }
    else {
      for (const sg of [-1, 1]) { fill(ctx, PAL.ink, () => ellipse(ctx, sg * 12, -44, 4, 5.5)); fill(ctx, PAL.ink, () => poly(ctx, [[sg * 22, -58], [sg * 4, -52], [sg * 4, -49], [sg * 22, -54]])); }
      stroke(ctx, PAL.ink, 3.5, () => path(ctx, [[-10, -22], [0, -27], [10, -22]], false));
    }
    const cap = () => path(ctx, [[-82, -64, 0], [-74, -104], [-40, -136], [0, -146], [40, -136], [74, -104], [82, -64, 0], [40, -58], [-40, -58]]);
    cel(ctx, cap, capC, Ls, lw);
    const rr = mulberry32(o.seed ?? 4);
    for (let i = 0; i < 7; i++) {
      const px = (rr() - 0.5) * 120, py = -80 - rr() * 50 * (1 - Math.abs(px) / 90);
      const r0 = 7 + rr() * 9;
      if (o.spotGlow) halo(ctx, px, py, r0 * 1.9, PAL.lemon, 2, 0.14 + sw * 0.15);
      fill(ctx, spotC, () => ellipse(ctx, px, py, r0, r0 * 0.75));
    }
    ctx.restore();
  },
  // Snapper: roślina-pułapka, paszcza na zawiasie otwiera się w prawo; open 0..1
  snapper(ctx, x, y, s, t, o = {}) {
    const look = o.look || {}; const dir = o.dir ?? 1;
    const Ls = (look.rims || []).map((r) => rim(r.c, r.lx * dir, r.ly, r.w)); const lw = look.lw ?? 5;
    const green = look.night ? night('#5fd06f', 0.42) : '#5fd06f', dark = mix(green, PAL.ink, 0.35);
    const inner = o.innerGlow ? PAL.rose : '#ff6f91';
    const op = o.open ?? 0.6, sway = Math.sin(t * TAU * 0.4) * 0.06;
    ctx.save(); ctx.translate(x, y); ctx.scale(s * dir, s);
    for (const sg of [-1, 1]) cel(ctx, () => path(ctx, [[0, 0, 0], [sg * 34, -34], [sg * 78, -26, 0], [sg * 40, -6]]), dark, Ls, lw);
    const hx = 26 + Math.sin(sway) * 40, hy = -132;
    stroke(ctx, PAL.ink, 19, () => path(ctx, [[0, 0], [-22, -52], [18, -96], [hx, hy]], false));
    stroke(ctx, green, 9, () => path(ctx, [[0, 0], [-22, -52], [18, -96], [hx, hy]], false));
    ctx.save(); ctx.translate(hx, hy); ctx.rotate(sway - 0.15);
    const a1 = 0.12 + op * 0.62, a2 = 0.08 + op * 0.42;
    // wnętrze paszczy
    if (o.innerGlow) halo(ctx, 50, 0, 70 * (0.6 + op * 0.6), inner, 3, 0.1);
    fill(ctx, mix(inner, PAL.ink, 0.45), () => poly(ctx, [[0, 0], [Math.cos(-a1) * 96, Math.sin(-a1) * 96], [Math.cos(a2) * 96, Math.sin(a2) * 96]]));
    for (const sg of [1, -1]) { // najpierw dolna, potem górna szczęka
      ctx.save(); ctx.rotate(sg > 0 ? a2 : -a1);
      const jaw = () => path(ctx, [[-6, 0, 0], [6, sg * 30], [46, sg * 46], [88, sg * 30], [104, 0, 0]]);
      cel(ctx, jaw, green, [{ c: inner, dx: 0, dy: sg * 10 }, ...Ls], 0);
      for (let k = 0; k < 5; k++) { const px = 20 + k * 17; fill(ctx, PAL.white, () => poly(ctx, [[px - 5, 0], [px + 5, 0], [px, -sg * 13]])); inked(ctx, () => poly(ctx, [[px - 5, 0], [px + 5, 0], [px, -sg * 13]]), null, 2); }
      inked(ctx, jaw, null, lw);
      for (const [px, py, rr] of [[34, 30, 6], [60, 34, 5], [80, 22, 4]]) fill(ctx, mix(green, PAL.white, 0.25), () => ellipse(ctx, px, sg * py, rr, rr * 0.7));
      ctx.restore();
    }
    ctx.restore();
    ctx.restore();
  },
  // Voidberry: krzak ze świecącymi jagodami
  voidberry(ctx, x, y, s, t, o = {}) {
    const leaf = o.leaf ?? '#1b2e45', berry = o.berry ?? PAL.violet;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    const r = mulberry32(o.seed ?? 9);
    for (let i = 0; i < 6; i++) {
      const ax = (r() - 0.5) * 80, ay = -20 - r() * 40;
      fill(ctx, i % 2 ? leaf : mix(leaf, PAL.ink, 0.25), () => path(ctx, [[ax - 34, ay + 18, 0], [ax - 20, ay - 18], [ax + 8, ay - 28], [ax + 34, ay + 10, 0], [ax, ay + 24]]));
    }
    for (let i = 0; i < 9; i++) {
      const bx0 = (r() - 0.5) * 90, by0 = -14 - r() * 56;
      const tw = 0.7 + 0.3 * Math.sin(t * TAU * qf(0.75) + i);
      halo(ctx, bx0, by0, 18 * tw, berry, 2, 0.18);
      fill(ctx, mix(berry, PAL.white, 0.2), () => circle(ctx, bx0, by0, 6.5));
      fill(ctx, PAL.white, () => circle(ctx, bx0 - 2, by0 - 2, 2));
    }
    ctx.restore();
  },
  moonpetal(ctx, x, y, s, t, o = {}) {
    const c = o.c ?? '#e9dcff';
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    stroke(ctx, '#12223a', 5, () => path(ctx, [[0, 0], [4, -30], [0, -60]], false));
    const op = 0.85 + 0.15 * Math.sin(t * TAU * qf(0.5) + x);
    halo(ctx, 0, -66, 46 * op, c, 3, 0.12);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * TAU + 0.3;
      fill(ctx, c, () => path(ctx, [[0, -66, 0], [Math.cos(a - 0.35) * 16, -66 + Math.sin(a - 0.35) * 10], [Math.cos(a) * 24 * op, -66 + Math.sin(a) * 15 * op, 0], [Math.cos(a + 0.35) * 16, -66 + Math.sin(a + 0.35) * 10]]));
    }
    fill(ctx, PAL.lemon, () => circle(ctx, 0, -66, 5));
    ctx.restore();
  },
};
