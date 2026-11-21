'use strict';
// Budynki i maszyny bazy, w nocnej palecie, rysowane bez konturu (tło) albo z konturem (gdy blisko).
const Props = {
  // Chatka: półbeczka (Quonset) z drewnianym frontem. x,y: środek podstawy frontu
  hut(ctx, x, y, s, o = {}) {
    const lw = o.lw ?? 0, t = o.t ?? 0;
    const dome = o.dome ?? '#2c2a5c', domeLit = o.domeLit ?? '#4a4790', wood = o.wood ?? '#3a2335', woodLit = o.woodLit ?? '#55304a';
    const warm = PAL.amber;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    // plama światła z drzwi
    screenFill(ctx, warm, 0.16, () => poly(ctx, [[-60, 0], [10, 0], [90, 120], [-140, 120]]));
    screenFill(ctx, warm, 0.12, () => poly(ctx, [[-40, 0], [-6, 0], [40, 70], [-90, 70]]));
    // beczka korpusu (w głąb w prawo)
    const body = () => path(ctx, [[-150, 0, 0], [-150, -40], [-120, -125], [-40, -160], [150, -150], [250, -110], [290, -40], [295, 0, 0]]);
    fill(ctx, dome, body);
    ctx.save(); ctx.beginPath(); body(); ctx.clip();
    fill(ctx, domeLit, () => path(ctx, [[-120, -125], [-40, -160], [150, -150], [250, -110], [270, -80], [150, -128], [-40, -138], [-110, -110]]));
    for (let i = 0; i < 6; i++) {
      const u = i / 5, xx = lerp(-60, 260, u);
      stroke(ctx, mix(dome, domeLit, 0.6), 5, () => path(ctx, [[xx - 40, 0], [xx - 30, -90 + u * 20], [xx + 10, -150 + u * 40]], false));
    }
    ctx.restore();
    // bulaj
    halo(ctx, 120, -88, 46, PAL.cyan, 2, 0.14);
    fill(ctx, '#1a1840', () => ellipse(ctx, 120, -88, 26, 20));
    fill(ctx, PAL.cyan, () => ellipse(ctx, 120, -88, 18, 13));
    fill(ctx, PAL.white, () => ellipse(ctx, 114, -93, 6, 4));
    // front drewniany
    const front = () => poly(ctx, [[-160, 0], [-160, -96], [-150, -110], [30, -110], [40, -96], [40, 0]]);
    fill(ctx, wood, front);
    for (let i = 0; i < 6; i++) stroke(ctx, woodLit, 3, () => poly(ctx, [[-160 + i * 34, -100], [-160 + i * 34, 0]], false));
    fill(ctx, woodLit, () => poly(ctx, [[-170, -110], [50, -110], [56, -122], [-176, -122]]));
    // okno i drzwi ze światłem
    halo(ctx, -110, -66, 60, warm, 3, 0.1);
    fill(ctx, '#2a1424', () => poly(ctx, [[-138, -86], [-84, -86], [-84, -46], [-138, -46]]));
    fill(ctx, warm, () => poly(ctx, [[-132, -80], [-90, -80], [-90, -52], [-132, -52]]));
    fill(ctx, '#2a1424', () => poly(ctx, [[-113, -80], [-109, -80], [-109, -52], [-113, -52]]));
    fill(ctx, PAL.lemon, () => poly(ctx, [[-130, -78], [-116, -78], [-124, -66], [-130, -66]]));
    halo(ctx, -24, -50, 80, warm, 3, 0.1);
    fill(ctx, '#2a1424', () => poly(ctx, [[-56, -2], [-56, -94], [8, -94], [8, -2]]));
    fill(ctx, warm, () => poly(ctx, [[-48, -2], [-48, -86], [0, -86], [0, -2]]));
    fill(ctx, PAL.lemon, () => poly(ctx, [[-44, -2], [-44, -82], [-28, -82], [-36, -2]]));
    // antena-talerz
    ctx.save(); ctx.translate(60, -172); ctx.rotate(-0.5 + Math.sin(t * TAU * qf(0.25)) * 0.05);
    fill(ctx, domeLit, () => path(ctx, [[-44, 0, 0], [-30, 20], [0, 26], [30, 20], [44, 0, 0], [0, 8]]));
    fill(ctx, mix(domeLit, PAL.white, 0.25), () => path(ctx, [[-38, 2, 0], [0, 9], [38, 2, 0], [0, 20]]));
    stroke(ctx, domeLit, 4, () => poly(ctx, [[0, 12], [0, -26]], false));
    fill(ctx, PAL.rose, () => circle(ctx, 0, -28, 5));
    halo(ctx, 0, -28, 18, PAL.rose, 2, 0.2 * (0.5 + 0.5 * Math.sign(Math.sin(t * TAU * 0.5))));
    ctx.restore();
    fill(ctx, dome, () => poly(ctx, [[40, -150], [80, -150], [70, -170], [50, -170]]));
    // komin
    fill(ctx, '#232046', () => poly(ctx, [[-60, -150], [-46, -150], [-46, -196], [-60, -196]]));
    fill(ctx, domeLit, () => poly(ctx, [[-64, -196], [-42, -196], [-42, -204], [-64, -204]]));
    // beczka i panel
    fill(ctx, '#7a3b2c', () => path(ctx, [[-210, 0, 0], [-214, -50], [-206, -60, 0], [-176, -60, 0], [-168, -50], [-172, 0, 0]]));
    fill(ctx, '#9b4d35', () => poly(ctx, [[-206, -50], [-176, -50], [-176, -42], [-206, -42]]));
    stroke(ctx, '#232046', 6, () => poly(ctx, [[320, 0], [320, -90]], false));
    fill(ctx, '#232046', () => poly(ctx, [[280, -90], [372, -120], [380, -100], [288, -70]]));
    fill(ctx, '#3c5bb0', () => poly(ctx, [[288, -92], [366, -116], [372, -104], [294, -78]]));
    ctx.restore();
  },
  // Brama wyprawy: pierścień ze świecącą taflą. x,y: środek podstawy
  gate(ctx, x, y, s, t = 0, o = {}) {
    const ringC = o.ring ?? '#2f2d63', ringLit = o.ringLit ?? '#5552a0', stone = o.stone ?? '#25224f', stoneLit = o.stoneLit ?? '#38347a';
    const g = o.glow ?? PAL.cyan;
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    const R = 130, cy = -170;
    screenFill(ctx, g, 0.1, () => ctx.ellipse(0, 10, 300, 60, 0, 0, TAU));
    screenFill(ctx, g, 0.1, () => ctx.ellipse(0, 10, 200, 38, 0, 0, TAU));
    halo(ctx, 0, cy, R * 2.3, g, 3, 0.07);
    // podstawa
    fill(ctx, stone, () => poly(ctx, [[-200, 0], [-160, -50], [160, -50], [200, 0]]));
    fill(ctx, stoneLit, () => poly(ctx, [[-160, -50], [160, -50], [168, -40], [-168, -40]]));
    fill(ctx, stoneLit, () => poly(ctx, [[60, -50], [160, -50], [200, 0], [110, 0]]));
    // tafla
    const pulse = 0.5 + 0.5 * Math.sin(t * TAU * 0.5);
    fill(ctx, mix(g, '#ffffff', 0.05), () => ctx.arc(0, cy, R * 0.86, 0, TAU));
    for (let i = 0; i < 4; i++) {
      const k = ((i / 4) + t * 0.25) % 1;
      stroke(ctx, mix(g, '#ffffff', 0.55), 6 * (1 - k) + 1, () => ctx.arc(0, cy, R * 0.86 * (1 - k * 0.92), 0, TAU));
    }
    fill(ctx, mix(g, '#ffffff', 0.7), () => ctx.arc(0, cy, R * (0.22 + pulse * 0.05), 0, TAU));
    // pierścień
    fill(ctx, ringC, () => { ctx.arc(0, cy, R * 1.08, 0, TAU); ctx.arc(0, cy, R * 0.86, 0, TAU, true); });
    fill(ctx, ringLit, () => { ctx.arc(0, cy, R * 1.08, -1.4, 0.4); ctx.arc(0, cy, R * 0.98, 0.4, -1.4, true); });
    for (const a of [-Math.PI / 2, 0.15, Math.PI - 0.15]) {
      ctx.save(); ctx.translate(Math.cos(a) * R * 1.08, cy + Math.sin(a) * R * 1.08); ctx.rotate(a + Math.PI / 2);
      fill(ctx, '#d9f6ff', () => poly(ctx, [[-10, 0], [0, -34], [10, 0]]));
      fill(ctx, '#9bc9dc', () => poly(ctx, [[0, 0], [0, -34], [10, 0]]));
      ctx.restore();
    }
    // konsola
    fill(ctx, stone, () => poly(ctx, [[180, -40], [230, -40], [230, -110], [180, -110]]));
    fill(ctx, PAL.mint, () => poly(ctx, [[188, -100], [222, -100], [222, -76], [188, -76]]));
    halo(ctx, 205, -88, 30, PAL.mint, 2, 0.15);
    ctx.restore();
  },
  // grządki w perspektywie: rogi czworoboku [lewy-dalszy, prawy-dalszy, prawy-bliższy, lewy-bliższy]
  plots(ctx, quad, cols, rows, t, o = {}) {
    const [a, b, c, d] = quad;
    const P = (u, v) => [lerp(lerp(a[0], b[0], u), lerp(d[0], c[0], u), v), lerp(lerp(a[1], b[1], u), lerp(d[1], c[1], u), v)];
    const soil = o.soil ?? '#2b1830', soilLit = o.soilLit ?? '#3d2340', gap = 0.08;
    const items = [];
    for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
      const u0 = (i + gap) / cols, u1 = (i + 1 - gap) / cols, v0 = (j + gap) / rows, v1 = (j + 1 - gap) / rows;
      fill(ctx, soil, () => poly(ctx, [P(u0, v0), P(u1, v0), P(u1, v1), P(u0, v1)]));
      for (let k = 1; k < 3; k++) { const v = lerp(v0, v1, k / 3); stroke(ctx, soilLit, 2.5, () => poly(ctx, [P(u0 + 0.02, v), P(u1 - 0.02, v)], false)); }
      items.push({ i, j, p: P((i + 0.5) / cols, (j + 0.55) / rows), sc: lerp(o.farScale ?? 0.5, o.nearScale ?? 1, (j + 0.5) / rows) });
    }
    return items;
  },
  tractor(ctx, x, y, s, t = 0, o = {}) {
    const body = o.body ?? night('#f39a2c', 0.45), bodyLit = o.bodyLit ?? '#f7b24c', dark = '#16132e', mid = '#28254f';
    ctx.save(); ctx.translate(x, y); ctx.scale(s * (o.dir ?? 1), s);
    // snop świateł
    if (o.lights !== false) {
      screenFill(ctx, PAL.lemon, 0.13, () => poly(ctx, [[150, -78], [520, -150], [560, 10], [150, -60]]));
      screenFill(ctx, PAL.lemon, 0.12, () => poly(ctx, [[150, -76], [420, -110], [440, -20], [150, -62]]));
    }
    fill(ctx, mid, () => poly(ctx, [[-60, -230], [-52, -230], [-40, -110], [-48, -110]]));
    fill(ctx, mid, () => poly(ctx, [[60, -230], [66, -230], [72, -110], [64, -110]]));
    fill(ctx, '#3a59b5', () => poly(ctx, [[-80, -240], [90, -240], [100, -226], [-74, -226]]));
    fill(ctx, '#6f8de0', () => poly(ctx, [[-60, -238], [40, -238], [36, -232], [-60, -232]]));
    fill(ctx, body, () => path(ctx, [[-70, -40, 0], [-70, -110, 0], [10, -118, 0], [20, -150, 0], [60, -150, 0], [64, -110, 0], [150, -96, 0], [160, -50, 0], [150, -30, 0]]));
    fill(ctx, bodyLit, () => poly(ctx, [[10, -118], [20, -150], [60, -150], [64, -110], [150, -96], [152, -86], [60, -100], [56, -138], [26, -138]]));
    fill(ctx, PAL.lemon, () => poly(ctx, [[140, -88], [156, -86], [156, -70], [142, -72]]));
    halo(ctx, 152, -78, 36, PAL.lemon, 2, 0.2);
    stroke(ctx, mid, 8, () => poly(ctx, [[110, -100], [110, -170]], false));
    // koła
    const rw = o.wheelRot ?? t * 3;
    for (const [wx, wr] of [[-40, 66], [120, 38]]) {
      fill(ctx, dark, () => ctx.arc(wx, -wr, wr, 0, TAU));
      for (let k = 0; k < 10; k++) { const a = rw + k * TAU / 10; fill(ctx, mid, () => poly(ctx, [[wx + Math.cos(a) * wr, -wr + Math.sin(a) * wr], [wx + Math.cos(a + 0.18) * (wr + 6), -wr + Math.sin(a + 0.18) * (wr + 6)], [wx + Math.cos(a + 0.3) * wr, -wr + Math.sin(a + 0.3) * wr]])); }
      fill(ctx, body, () => ctx.arc(wx, -wr, wr * 0.48, 0, TAU));
      fill(ctx, bodyLit, () => ctx.arc(wx + wr * 0.1, -wr - wr * 0.1, wr * 0.3, 0, TAU));
    }
    ctx.restore();
  },
  drone(ctx, x, y, s, t = 0, o = {}) {
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    if (o.beam !== false) {
      screenFill(ctx, PAL.cyan, 0.13, () => poly(ctx, [[-12, 10], [12, 10], [70, o.beamLen ?? 260], [-70, o.beamLen ?? 260]]));
      screenFill(ctx, PAL.cyan, 0.15, () => ctx.ellipse(0, o.beamLen ?? 260, 70, 16, 0, 0, TAU));
    }
    const sp = t * 40;
    for (const sg of [-1, 1]) {
      stroke(ctx, '#3b3970', 6, () => poly(ctx, [[0, 0], [sg * 48, -10]], false));
      fill(ctx, rgba('#c7d2ff', 0.45), () => ctx.ellipse(sg * 48, -14, 30 * Math.abs(Math.cos(sp + sg)), 5, 0, 0, TAU));
      fill(ctx, '#3b3970', () => ctx.ellipse(sg * 48, -12, 6, 4, 0, 0, TAU));
    }
    fill(ctx, '#55558e', () => path(ctx, [[-26, 0], [-18, -14], [18, -14], [26, 0], [16, 12], [-16, 12]]));
    fill(ctx, night('#f39a2c', 0.3), () => poly(ctx, [[-26, -2], [26, -2], [24, 4], [-24, 4]]));
    fill(ctx, PAL.cyan, () => circle(ctx, 0, 6, 6));
    halo(ctx, 0, 6, 20, PAL.cyan, 2, 0.25);
    ctx.restore();
  },
};
