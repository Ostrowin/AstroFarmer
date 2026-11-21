"""Szkice etapu 1 Grzybowego Lasu (do akceptacji, nie modele do gry).

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/stage1_sketch.py -- [arkusze...]
Arkusze: creatures, glade, puffking, village, cave, items (bez argumentów wszystkie). SKETCH_FAST=1 = szybki podgląd.
Wynik: art/source/sketches/stage1_*.png, źródło art/source/stage1_sketch.blend.
Korzysta z funkcji tools/blender/forest_props.py (Builder, tube, lathe, Fan...).
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix
from mathutils.noise import noise as pnoise, fractal

sys.path.insert(0, os.path.dirname(__file__))
import forest_props as fp  # noqa: E402  (czyści scenę i tworzy materiały lasu)

ROOT = fp.ROOT
SKETCH_DIR = fp.SKETCH_DIR
FAST = fp.FAST
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ALL_SHEETS = ["creatures", "glade", "puffking", "village", "cave", "items", "sporecave"]
SHEETS = [a for a in ARGV if a in ALL_SHEETS] or ALL_SHEETS
scene = bpy.context.scene
M = fp.M


def add_mat(name, m):
    M[name] = m
    return m


add_mat("BatSkin", fp.plain("BatSkin", (0.16, 0.1, 0.2), 0.6))
add_mat("BatMembrane", fp.plain("BatMembrane", (0.32, 0.16, 0.4), 0.5))
add_mat("BatGlow", fp.glow("BatGlow", (0.2, 0.6, 0.7), (0.25, 0.9, 1.0), 3.0, 3.0))
add_mat("TickShell", fp.plain("TickShell", (0.2, 0.12, 0.14), 0.35))
add_mat("SporeSac", fp.glow("SporeSac", (0.5, 0.25, 0.6), (0.75, 0.35, 1.0), 3.0, 3.0))
add_mat("RotCap", fp.plain("RotCap", (0.36, 0.3, 0.16), 0.7))
add_mat("RotGlow", fp.glow("RotGlow", (0.4, 0.6, 0.2), (0.6, 1.0, 0.25), 3.0, 3.0))
add_mat("Thread", fp.plain("Thread", (0.75, 0.75, 0.72), 0.8))
add_mat("ThreadGlow", fp.glow("ThreadGlow", (0.5, 0.8, 0.85), (0.4, 0.95, 1.0), 2.0, 2.0))
add_mat("Puff", fp.plain("Puff", (0.82, 0.76, 0.62), 0.85))
add_mat("PuffVent", fp.glow("PuffVent", (0.6, 0.7, 0.3), (0.85, 1.0, 0.4), 4.0, 4.0))
add_mat("Eye", fp.plain("Eye", (0.02, 0.02, 0.03), 0.1))
add_mat("EyeGlow", fp.glow("EyeGlow", (1, 0.9, 0.6), (1.0, 0.85, 0.5), 4.0, 4.0))
add_mat("BossEye", fp.glow("BossEye", (0.8, 1.0, 0.3), (0.85, 1.0, 0.25), 9.0, 9.0))
add_mat("Throat", fp.glow("Throat", (0.5, 0.7, 0.2), (0.7, 1.0, 0.2), 3.5, 3.5))
add_mat("KinCapTeal", fp.plain("KinCapTeal", (0.12, 0.45, 0.45), 0.6))
add_mat("KinCapOrange", fp.plain("KinCapOrange", (0.75, 0.35, 0.12), 0.6))
add_mat("KinCapViolet", fp.plain("KinCapViolet", (0.42, 0.2, 0.55), 0.6))
add_mat("KinBody", fp.plain("KinBody", (0.8, 0.76, 0.68), 0.7))
add_mat("Lantern", fp.glow("Lantern", (1.0, 0.75, 0.4), (1.0, 0.7, 0.3), 5.0, 5.0))
add_mat("Wood", fp.plain("Wood", (0.35, 0.24, 0.18), 0.85))
add_mat("KinSkin", fp.plain("KinSkin", (1.0, 1.0, 1.0), 0.55))
add_mat("KinEyeWhite", fp.plain("KinEyeWhite", (0.95, 0.95, 0.9), 0.3))
add_mat("KinCheek", fp.plain("KinCheek", (0.85, 0.45, 0.45), 0.6))
add_mat("Reed", fp.plain("Reed", (0.5, 0.5, 0.28), 0.85))
add_mat("Tooth", fp.plain("Tooth", (1.0, 1.0, 1.0), 0.5))


def _phantom():
    """Fantom (halucynacja): półprzezroczysta, świecąca fioletem kopia."""
    m = bpy.data.materials.new("Phantom")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.7, 0.4, 1.0, 1)
    em.inputs["Strength"].default_value = 2.5
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.35
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(m, attr, val)
        except Exception:
            pass
    return m


add_mat("Phantom", _phantom())
add_mat("Grass", fp.plain("Grass", (0.22, 0.5, 0.14), 0.8))
add_mat("Flower", fp.plain("Flower", (1.0, 0.85, 0.3), 0.6))
add_mat("FlowerPink", fp.plain("FlowerPink", (0.95, 0.45, 0.7), 0.6))
add_mat("RotGround", fp.plain("RotGround", (0.2, 0.15, 0.08), 0.9))
add_mat("Metal", fp.plain("Metal", (0.55, 0.57, 0.6), 0.35))
add_mat("Glass", fp.plain("Glass", (0.6, 0.8, 0.9), 0.1))
add_mat("Liquid", fp.glow("Liquid", (0.2, 0.5, 0.9), (0.2, 0.55, 1.0), 1.2, 1.2))
add_mat("PodGlow", fp.glow("PodGlow", (0.4, 0.22, 0.55), (0.7, 0.4, 1.0), 0.8, 1.2))
add_mat("Ground", fp.plain("Ground", (0.08, 0.07, 0.1), 0.95))
add_mat("RockDark", fp.plain("RockDark", (0.18, 0.15, 0.22), 0.9))
add_mat("CaveGlow", fp.glow("CaveGlow", (0.2, 0.4, 0.9), (0.25, 0.55, 1.0), 3.0, 3.0))

Builder, tube, lathe, Fan, fan_cap, frame = fp.Builder, fp.tube, fp.lathe, fp.Fan, fp.fan_cap, fp.frame
SPHERE = [(0.0, -1.0), (0.5, -0.87), (0.87, -0.5), (1.0, 0.0), (0.87, 0.5), (0.5, 0.87), (0.0, 1.0)]


def sphere(b, center, r, mat, sx=1.0, sy=1.0, sz=1.0, seg=16, color=None, deform=None):
    m = Matrix.Translation(center) @ Matrix.Diagonal((r * sx, r * sy, r * sz, 1))
    lathe(b, SPHERE, mat, m, seg, color, deform)


def place(obj, loc, rot_z=0.0, scale=1.0):
    obj.location = loc
    obj.rotation_euler.z = rot_z
    obj.scale = (scale, scale, scale)
    return obj


def import_glb(path, loc, rot_z=0.0, scale=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    roots = [o for o in bpy.data.objects if o not in before and o.parent is None]
    for o in roots:
        o.location = loc
        o.rotation_euler.z = rot_z
        o.scale = (scale, scale, scale)
    return roots


def farmer(loc, rot_z=0.0):
    return import_glb(os.path.join(ROOT, "art", "models", "player.glb"), loc, rot_z)


def ground_disc(loc, r, mat="Ground"):
    b = Builder([])
    b.grid(lambda u, v: Vector((math.cos(v * math.tau) * r * u, math.sin(v * math.tau) * r * u, 0)), 2, 48, mat)
    return place(b.finish("GroundDisc"), loc)


# ------------------------------------------------------------------ stworzenia


def sporebat(name, spread=True):
    """Nietoperz-grzyb: ciało = mały kapelusz z blaszkami, błoniaste skrzydła z palcami, świecące oczy."""
    b = Builder([])
    # ciało (kapelusz na grzbiecie) + brzuch
    lathe(b, [(0.0, 0.2), (0.12, 0.19), (0.2, 0.12), (0.22, 0.02), (0.2, -0.02)], "BatSkin", Matrix(), 20,
          lambda u, v, p: (1.0, 1.0, 1.0, 1) if pnoise(p * 30) < 0.35 else (1.8, 1.5, 2.0, 1))
    lathe(b, [(0.2, -0.02), (0.1, 0.0), (0.0, 0.01)], "BatGlow", Matrix(), 20, flip=True)
    sphere(b, Vector((0, 0, -0.08)), 0.1, "BatSkin", 1.0, 1.3, 0.8)
    # głowa z uszami i oczami (z przodu: -Y)
    sphere(b, Vector((0, -0.17, -0.02)), 0.07, "BatSkin")
    for s in (-1, 1):
        sphere(b, Vector((0.03 * s, -0.23, 0.0)), 0.014, "BatGlow")
        tube(b, [Vector((0.035 * s, -0.17, 0.03)), Vector((0.07 * s, -0.16, 0.11))], [0.025, 0.004], "BatSkin", seg=6)
    # skrzydła
    for s in (-1, 1):
        if spread:
            shoulder = Vector((0.16 * s, -0.02, 0.02))
            fingers = [Vector((0.62 * s, -0.12, 0.12)), Vector((0.66 * s, 0.1, 0.02)), Vector((0.5 * s, 0.26, -0.05))]
        else:  # złożone wokół ciała (wisi głową w dół)
            shoulder = Vector((0.13 * s, -0.02, 0.0))
            fingers = [Vector((0.2 * s, -0.12, -0.3)), Vector((0.22 * s, 0.04, -0.34)), Vector((0.16 * s, 0.14, -0.28))]
        elbow = shoulder.lerp(fingers[0], 0.45) + Vector((0, -0.04, 0.05 if spread else 0.0))
        tube(b, [shoulder, elbow], [0.022, 0.016], "BatSkin", seg=6)
        for f in fingers:
            tube(b, [elbow, f], [0.012, 0.004], "BatSkin", seg=5)
        pts = [shoulder] + [elbow] + fingers + [Vector((0.08 * s, 0.12, -0.04))]
        # błona: wachlarz od łokcia między palcami (z zatoką na brzegu)
        rim = [shoulder, fingers[0], fingers[1], fingers[2], Vector((0.1 * s, 0.14, -0.03))]

        def membrane(u, v, rim=rim, elbow=elbow):
            fi = v * (len(rim) - 1)
            i = min(int(fi), len(rim) - 2)
            k = fi - i
            edge = rim[i].lerp(rim[i + 1], k)
            sag = math.sin(k * math.pi) * 0.25  # zatoka między palcami
            edge = edge.lerp(elbow, sag * 0.6)
            return elbow.lerp(edge, u)

        b.grid(membrane, 4, 24, "BatMembrane",
               color=lambda u, v, p: (1.0, 1.0, 1.0, 1) if (v * 4) % 1 > 0.06 else (0.5, 0.5, 0.6, 1))
    # nóżki (pazurki, którymi wisi)
    for s in (-1, 1):
        tube(b, [Vector((0.04 * s, 0.08, -0.12)), Vector((0.05 * s, 0.14, -0.2))], [0.012, 0.006], "BatSkin", seg=5)
    o = b.finish(name)
    if not spread:
        o.rotation_euler.x = math.pi  # głową w dół
    return o


def spore_tick(name):
    """Kleszcz zarodnikowy: bulwiasty odwłok ze świecącymi woreczkami, 8 nóg, żuwaczki."""
    b = Builder([])
    rng = random.Random(3)
    sphere(b, Vector((0, 0.12, 0.28)), 0.3, "TickShell", 1.0, 1.25, 0.85, seg=24,
           deform=lambda p, u, v: p * (1 + 0.04 * pnoise(p * 9)))
    for i in range(9):
        a = rng.uniform(0, math.tau); e = rng.uniform(0.1, 1.2)
        d = Vector((math.cos(a) * math.cos(e), 0.12 + 1.25 * math.sin(a) * math.cos(e) * 0.8, 0)).normalized()
        c = Vector((0.27 * math.cos(a) * math.cos(e), 0.12 + 0.34 * math.sin(a) * math.cos(e), 0.28 + 0.24 * math.sin(e)))
        sphere(b, c, rng.uniform(0.05, 0.09), "SporeSac")
    sphere(b, Vector((0, -0.18, 0.24)), 0.12, "TickShell", 1.0, 0.9, 0.8)
    for s in (-1, 1):
        tube(b, [Vector((0.04 * s, -0.27, 0.22)), Vector((0.06 * s, -0.36, 0.17)), Vector((0.03 * s, -0.38, 0.12))],
             [0.025, 0.018, 0.005], "TickShell", seg=6)
        sphere(b, Vector((0.05 * s, -0.27, 0.29)), 0.022, "EyeGlow")
        for k in range(4):
            ang = (-0.6 + k * 0.45)
            hip = Vector((0.12 * s, -0.12 + k * 0.08, 0.24))
            knee = hip + Vector((0.3 * s * math.cos(ang * 0.3), 0.25 * math.sin(ang), 0.22))
            foot = knee + Vector((0.22 * s, 0.12 * math.sin(ang), -0.46))
            tube(b, [hip, knee, foot], [0.03, 0.022, 0.006], "TickShell", seg=6)
    return b.finish(name)


def growths(name, anchors, seed=1, size=0.15):
    """Narośla grzybów (zgnilizna) w podanych punktach: kapelusiki + świecące plamki."""
    b = Builder([])
    rng = random.Random(seed)
    for p, n in anchors:
        for i in range(rng.randint(2, 4)):
            off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * size * 0.6
            base = p + off
            h = size * rng.uniform(0.6, 1.4)
            top = base + (n + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))).normalized() * h
            tube(b, [base, top], [size * 0.12, size * 0.09], "StemPale", seg=6, cap_end=False)
            r = size * rng.uniform(0.35, 0.6)
            m = Matrix.Translation(top) @ (top - base).to_track_quat("Z", "Y").to_matrix().to_4x4()
            lathe(b, [(0.0, r * 0.5), (r * 0.7, r * 0.42), (r, r * 0.1), (r * 0.95, 0.0)], "RotCap", m, 12)
            lathe(b, [(r * 0.95, 0.0), (0.0, r * 0.15)], "RotGlow", m, 12, flip=True)
    return b.finish(name)


def cocoon(name, burst=False):
    """Kokon z grzybni, z którego wychodzi stworzenie od reżysera (zamknięty / pękający)."""
    b = Builder([])
    rng = random.Random(9)
    prof = [(0.0, 0.0), (0.35, 0.08), (0.5, 0.45), (0.48, 0.9), (0.32, 1.25), (0.0, 1.38)]
    if burst:
        prof = prof[:4] + [(0.42, 1.0)]

    def deform(p, u, v):
        if burst and u > 0.7:  # postrzępione płaty rozchylone na boki
            a = v * math.tau
            lobe = max(0.0, math.sin(a * 5))
            p = p + Vector((math.cos(a), math.sin(a), 0)) * lobe * (u - 0.7) * 1.6
        return p * (1 + 0.06 * pnoise(p * 7))

    lathe(b, prof, "Thread", Matrix(), 28, lambda u, v, p: (0.8 + 0.2 * pnoise(p * 20), 0.8, 0.78, 1), deform)
    if burst:
        sphere(b, Vector((0, 0, 0.75)), 0.33, "ThreadGlow")
    # nitki oplatające
    for k in range(10):
        a0 = rng.uniform(0, math.tau)
        pts = []
        for i in range(10):
            t = i / 9
            r = 0.5 * math.sin(math.pi * min(t * 1.05, 1.0)) + 0.03
            a = a0 + t * rng.uniform(1.5, 3.0)
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, t * (1.0 if burst else 1.35))))
        tube(b, pts, [0.012] * 10, "ThreadGlow" if k % 3 == 0 else "Thread", seg=4)
    # korzenie-nitki na ziemi
    for k in range(14):
        a = rng.uniform(0, math.tau)
        pts = [Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.02))]
        for i in range(6):
            a += rng.uniform(-0.4, 0.4)
            pts.append(pts[-1] + Vector((math.cos(a), math.sin(a), 0)) * 0.25)
        tube(b, pts, [0.015] * len(pts), "ThreadGlow", seg=4)
    return b.finish(name)


def rot_shepherd(name):
    """Rot Shepherd: wysoki, przygarbiony grzybowy pasterz z kosturem, płaszcz z nitek, zgniły kapelusz."""
    b = Builder([])
    rng = random.Random(4)
    hips = Vector((0, 0, 1.05))
    neck = Vector((0, -0.35, 2.1))
    # nogi
    for s in (-1, 1):
        tube(b, [hips + Vector((0.15 * s, 0, 0)), Vector((0.2 * s, -0.1, 0.55)), Vector((0.22 * s, 0.05, 0.05))],
             [0.13, 0.1, 0.12], "KinBody", seg=10, color=lambda u, v, p: (0.75, 0.7, 0.6, 1))
    # tułów: przygarbiony trzon
    tube(b, [hips, Vector((0, -0.05, 1.5)), Vector((0, -0.2, 1.9)), neck], [0.24, 0.27, 0.25, 0.14], "KinBody", seg=14,
         color=lambda u, v, p: (0.7, 0.66, 0.55, 1), wobble=0.08)
    # zgniły, opadający kapelusz
    m = Matrix.Translation(neck + Vector((0, -0.1, 0.05))) @ Vector((0, -0.45, 1)).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()

    def droop(p, u, v):
        a = v * math.tau
        p = p.copy()
        p.z -= (u ** 2) * 0.35 * (1 + 0.6 * math.sin(a * 3 + 1))
        return p * (1 + 0.08 * pnoise(p * 4))

    rot = lambda u, v, p: (0.6, 0.6, 0.5, 1) if pnoise(p * 6) > 0.25 else (1.0, 1.0, 1.0, 1)
    lathe(b, [(0.0, 0.55), (0.35, 0.5), (0.62, 0.32), (0.72, 0.1), (0.7, -0.02)], "RotCap", m, 28, rot, droop)
    lathe(b, [(0.7, -0.02), (0.3, 0.1), (0.0, 0.16)], "RotGlow", m, 28, None, droop, flip=True)
    for i in range(12):  # świecące zarodniki na kapeluszu
        a = rng.uniform(0, math.tau); r = rng.uniform(0.1, 0.55)
        sphere(b, m @ Vector((math.cos(a) * r, math.sin(a) * r, 0.5 - r * 0.5)), 0.035, "RotGlow")
    # oczy pod kapeluszem
    for s in (-1, 1):
        sphere(b, neck + Vector((0.08 * s, -0.17, -0.05)), 0.035, "RotGlow")
    # ręce: długie, palce-blaszki
    for s in (-1, 1):
        sh = Vector((0.22 * s, -0.25, 1.85))
        el = Vector((0.4 * s, -0.5, 1.4))
        wr = Vector((0.35 * s if s < 0 else 0.5, -0.75, 1.25 if s < 0 else 1.55))
        tube(b, [sh, el, wr], [0.08, 0.06, 0.05], "KinBody", seg=8, color=lambda u, v, p: (0.7, 0.66, 0.55, 1))
        for k in range(4):
            tube(b, [wr, wr + Vector((rng.uniform(-0.08, 0.08), -0.15, rng.uniform(-0.12, 0.05)))], [0.02, 0.005], "KinBody", seg=5)
    # kostur (w prawej ręce) z świecącą zarodnią
    staff = [Vector((0.55, -0.75, 0.0)), Vector((0.52, -0.78, 1.2)), Vector((0.55, -0.76, 2.3)), Vector((0.75, -0.8, 2.6)),
             Vector((0.9, -0.8, 2.45))]
    tube(b, staff, [0.045, 0.04, 0.035, 0.03, 0.025], "Wood", seg=8, color=lambda u, v, p: (0.8, 0.7, 0.6, 1))
    sphere(b, Vector((0.9, -0.8, 2.32)), 0.13, "RotGlow", 1.0, 1.0, 1.25)
    # płaszcz z nitek grzybni od ramion w dół
    for k in range(70):
        a = rng.uniform(-0.3, math.pi + 0.3)
        top = Vector((math.cos(a) * 0.3, -0.25 + math.sin(a) * 0.2, 1.9))
        L = rng.uniform(1.0, 1.75)
        pts = [top]
        for i in range(1, 6):
            t = i / 5
            pts.append(top + Vector((math.cos(a) * 0.18 * t, 0.25 * t * t + math.sin(a) * 0.1 * t, -L * t)) +
                       Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0)))
        tube(b, pts, [0.018] * 6, "ThreadGlow" if k % 7 == 0 else "Thread", seg=4)
    return b.finish(name)


def _maw(b, center, normal, width, height, teeth, seed, depth=0.5):
    """Poszarpana paszcza: ciemna jama z nierównymi zębami u góry i dołu, w głębi chorobliwa poświata."""
    rng = random.Random(seed)
    rot = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    base = Matrix.Translation(center) @ rot
    # jama (spłaszczona elipsa wciśnięta w skórę)
    lathe(b, SPHERE, "Eye", base @ Matrix.Diagonal((width, height, depth, 1)), 24)
    lathe(b, SPHERE, "Throat", base @ Matrix.Translation((0, -height * 0.15, depth * 0.35)) @ Matrix.Diagonal((width * 0.45, height * 0.4, depth * 0.2, 1)), 16)
    # zęby: stożki od krawędzi do środka, każdy inny
    for row, sign in ((teeth, 1), (teeth - 1, -1)):
        for i in range(row):
            t = (i + 0.5) / row
            x = (t - 0.5) * 2 * width * 0.85
            edge_y = sign * height * math.sqrt(max(0.0, 1 - (x / width) ** 2)) * 0.92
            L = height * rng.uniform(0.45, 1.05) * (1 - abs(t - 0.5) * 0.7)
            w = width / row * rng.uniform(0.6, 0.95)
            root = base @ Vector((x, edge_y, depth * 0.55))
            tip = base @ Vector((x + rng.uniform(-0.1, 0.1) * w, edge_y - sign * L, depth * 0.45))
            d = (tip - root)
            m = Matrix.Translation(root) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            lathe(b, [(w * 0.5, 0.0), (w * 0.35, d.length * 0.5), (0.0, d.length)], "Tooth", m, 8,
                  lambda u, v, p: (0.9 - 0.3 * u, 0.85 - 0.3 * u, 0.6, 1))


def _angry_eyes(b, centers, normal, size, brow=True, eye_mat="BossEye"):
    """Głęboko osadzone, skośne, świecące szparki oczu pod ciężkimi łukami brwiowymi."""
    for c, s in centers:
        rot = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
        base = Matrix.Translation(c) @ rot
        lathe(b, SPHERE, "Eye", base @ Matrix.Diagonal((size * 1.3, size * 0.8, size * 0.5, 1)), 16)
        # szparka: wydłużona, przechylona w dół ku nosowi (wściekłość)
        tilt = Matrix.Rotation(math.radians(-22 * s), 4, "Z")
        lathe(b, SPHERE, eye_mat, base @ Matrix.Translation((0, -size * 0.05, size * 0.45)) @ tilt @ Matrix.Diagonal((size * 0.95, size * 0.22, size * 0.12, 1)), 12)
        if brow:
            # wściekłe brwi: wewnętrzny koniec nisko (nad nosem), zewnętrzny wysoko
            p0 = base @ Vector((-size * 1.3 * s, size * 0.05, size * 0.55))
            p1 = base @ Vector((size * 0.1 * s, size * 0.75, size * 0.55))
            p2 = base @ Vector((size * 1.5 * s, size * 1.25, size * 0.35))
            tube(b, [p0, p1, p2], [size * 0.45, size * 0.55, size * 0.35], "Puff", seg=10,
                 color=lambda u, v, p: (0.75, 0.68, 0.6, 1))


def puffking(name, r=3.5):
    """The Puffking: olbrzymia, popękana purchawka z koroną małych purchawek; szeroka, poszarpana paszcza
    z nierównymi zębami i świecącym gardłem, wściekłe świecące szparki oczu pod ciężkimi brwiami."""
    b = Builder([])
    rng = random.Random(6)

    def skin(p, u, v):
        return p * (1 + 0.05 * fractal(p * 1.1, 0.6, 2.0, 4))

    def crack(u, v, p):
        n = abs(pnoise(p * 0.8))
        if n < 0.05:
            return (0.12, 0.1, 0.08, 1)
        k = 0.75 - 0.2 * pnoise(p * 2.5)
        return (k, k * 0.92, k * 0.8, 1)

    prof = [(0.0, -0.75), (0.7, -0.68), (0.95, -0.35), (1.0, 0.05), (0.9, 0.5), (0.6, 0.85), (0.0, 0.95)]
    lathe(b, [(x * r, z * r) for x, z in prof], "Puff", Matrix(), 56, crack, skin)
    for i in range(9):  # otwory na zarodniki (z tyłu i po bokach)
        a = rng.uniform(math.radians(-40), math.radians(220)); e = rng.uniform(0.1, 0.9)
        n = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        c = Vector((n.x * r * 0.98, n.y * r * 0.98, n.z * r * 0.9))
        m = Matrix.Translation(c) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
        rr = rng.uniform(0.25, 0.45)
        lathe(b, [(rr * 1.3, -0.05), (rr * 1.1, 0.12), (rr, 0.1), (rr * 0.6, -0.15)], "Puff", m, 16)
        lathe(b, [(rr * 0.6, -0.15), (0.0, -0.2)], "PuffVent", m, 16)
    for i in range(7):  # korona małych purchawek, pochylonych jak kolce
        a = i / 7 * math.tau
        c = Vector((math.cos(a) * r * 0.45, math.sin(a) * r * 0.45, r * 0.84))
        sphere(b, c, r * rng.uniform(0.12, 0.17), "Puff", 1, 1, 1.25, color=crack)
    front = Vector((0, -1, 0.05)).normalized()
    _maw(b, Vector((0, -r * 0.93, -r * 0.12)), front, r * 0.62, r * 0.3, 12, 11, depth=r * 0.25)
    _angry_eyes(b, [(Vector((-r * 0.33, -r * 0.9, r * 0.33)), -1), (Vector((r * 0.33, -r * 0.9, r * 0.33)), 1)], front, r * 0.13)
    return b.finish(name)


def mini_puff(name, r=0.9):
    b = Builder([])
    lathe(b, [(0.0, -0.7 * r), (0.75 * r, -0.6 * r), (r, 0.0), (0.75 * r, 0.65 * r), (0.0, 0.8 * r)], "Puff", Matrix(), 24,
          lambda u, v, p: (0.8, 0.72, 0.62, 1), lambda p, u, v: p * (1 + 0.06 * pnoise(p * 4)))
    front = Vector((0, -1, 0.1)).normalized()
    _maw(b, Vector((0, -0.92 * r, -0.12 * r)), front, 0.5 * r, 0.24 * r, 6, 3, depth=0.2 * r)
    _angry_eyes(b, [(Vector((-0.28 * r, -0.86 * r, 0.25 * r)), -1), (Vector((0.28 * r, -0.86 * r, 0.25 * r)), 1)], front, 0.12 * r)
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        sphere(b, Vector((math.cos(a) * 0.7 * r, math.sin(a) * 0.7 * r, 0.45 * r)), 0.09 * r, "PuffVent")
    return b.finish(name)


KIN_SKIN = [(0.32, 0.5, 0.42), (0.45, 0.48, 0.3), (0.3, 0.42, 0.5), (0.5, 0.42, 0.32)]


def sporekin(name, palette=0, seed=1, lantern=False):
    """Sporekin (nowa wersja): krępy, uśmiechnięty ludek z bagien. Skóra jak wilgotny mech/żaba w plamki,
    duże oczy, szeroki uśmiech, włosy z trzcin; poncho plecione z sitowia, na którym rosną małe grzybki."""
    b = Builder([])
    rng = random.Random(seed)
    sk = KIN_SKIN[palette % len(KIN_SKIN)]
    def skin(u, v, p, sk=sk):
        f = 1.35 if pnoise(p * 14) > 0.35 else 1.0  # plamki jak u żaby
        return (sk[0] * f, sk[1] * f, sk[2] * f, 1)
    for s in (-1, 1):  # krótkie, krępe nogi z szerokimi stopami
        tube(b, [Vector((0.1 * s, 0, 0.45)), Vector((0.12 * s, 0.02, 0.22)), Vector((0.12 * s, -0.02, 0.05))],
             [0.08, 0.07, 0.07], "KinSkin", seg=8, color=skin)
        sphere(b, Vector((0.13 * s, -0.08, 0.03)), 0.09, "KinSkin", 1.0, 1.5, 0.45, color=skin)
    # tułów (gruszka)
    lathe(b, [(0.0, 0.35), (0.2, 0.38), (0.27, 0.6), (0.24, 0.85), (0.14, 0.98), (0.0, 1.0)], "KinSkin", Matrix(), 18, skin)
    # głowa: szeroka, okrągła
    head = Vector((0, -0.02, 1.2))
    sphere(b, head, 0.27, "KinSkin", 1.15, 1.0, 0.92, seg=20, color=skin)
    for s in (-1, 1):  # duże oczy (białko, źrenica, błysk)
        e = head + Vector((0.11 * s, -0.21, 0.07))
        sphere(b, e, 0.085, "KinEyeWhite")
        sphere(b, e + Vector((0.0, -0.07, 0.0)), 0.045, "Eye")
        sphere(b, e + Vector((0.018 * s, -0.105, 0.025)), 0.014, "EyeGlow")
        sphere(b, head + Vector((0.2 * s, -0.17, -0.04)), 0.05, "KinCheek", 1, 0.5, 0.7)
    # szeroki uśmiech
    smile = [head + Vector((x, -0.255 + 0.02 * abs(x) * 3, -0.07 - 0.07 * (1 - (x / 0.14) ** 2))) for x in (-0.14, -0.07, 0.0, 0.07, 0.14)]
    tube(b, smile, [0.012, 0.016, 0.018, 0.016, 0.012], "Eye", seg=6)
    # włosy z trzcin
    for k in range(14):
        a = rng.uniform(0, math.tau); e = rng.uniform(0.3, 1.2)
        root = head + Vector((math.cos(a) * 0.2 * math.cos(e), math.sin(a) * 0.2 * math.cos(e) + 0.03, 0.2 * math.sin(e) + 0.05))
        tip = root + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12 + 0.05, rng.uniform(0.18, 0.32)))
        tube(b, [root, root.lerp(tip, 0.5) + Vector((0, 0.03, 0)), tip], [0.012, 0.008, 0.002], "Reed", seg=4,
             color=lambda u, v, p: (0.8 + 0.3 * u, 0.85 + 0.2 * u, 0.6, 1))
    # poncho plecione z sitowia (paski) + grzybki rosnące na nim
    weave = lambda u, v, p: ((0.85 if int(v * 40) % 2 == 0 else 1.1), (0.85 if int(u * 8) % 2 == 0 else 1.05), 0.9, 1)
    lathe(b, [(0.12, 1.0), (0.3, 0.92), (0.42, 0.7), (0.44, 0.55)], "Reed", Matrix(), 28, weave,
          lambda p, u, v: p + Vector((0, 0, -0.04 * math.sin(v * math.tau * 9) * u)))
    for k in range(rng.randint(4, 6)):
        a = rng.uniform(0, math.tau)
        rr = 0.36
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.75 + rng.uniform(-0.12, 0.1)))
        n = Vector((math.cos(a), math.sin(a), 0.6)).normalized()
        h = rng.uniform(0.05, 0.1)
        tube(b, [base, base + n * h], [0.01, 0.008], "StemPale", seg=5, cap_end=False)
        cr = rng.uniform(0.03, 0.06)
        m = Matrix.Translation(base + n * h) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(b, [(0.0, cr * 0.6), (cr, 0.1 * cr), (cr * 0.9, 0.0)], rng.choice(["GhostTop", "KinCapOrange", "CaveGlow"]), m, 10)
    # ręce
    for s in (-1, 1):
        hand = Vector((0.36 * s, -0.12, 0.5 if not (lantern and s > 0) else 0.85))
        tube(b, [Vector((0.24 * s, 0, 0.88)), Vector((0.36 * s, -0.04, 0.7)), hand], [0.05, 0.045, 0.04], "KinSkin", seg=7, color=skin)
        sphere(b, hand, 0.055, "KinSkin", color=skin)
        if lantern and s > 0:
            tube(b, [hand, hand + Vector((0.08, -0.15, 0.3))], [0.012, 0.01], "Wood", seg=5)
            sphere(b, hand + Vector((0.1, -0.18, 0.16)), 0.07, "Lantern", 1, 1, 1.3)
    return b.finish(name)


def stilt_hut(name, h=2.4, r=1.5):
    """Chatka Sporekinów: na palach, ściany z trzciny, stożkowy dach strzechą z mchem i grzybami, świecące okienka."""
    b = Builder([])
    rng = random.Random(len(name))
    floor = 1.1
    for k in range(5):  # pale
        a = k / 5 * math.tau
        tube(b, [Vector((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, -0.2)), Vector((math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, floor))],
             [0.08, 0.07], "Wood", seg=6)
    lathe(b, [(0.0, floor), (r * 1.15, floor), (r * 1.15, floor - 0.15), (0.0, floor - 0.15)], "Wood", Matrix(), 24,
          lambda u, v, p: (0.8 + 0.3 * pnoise(p * 4), 0.8, 0.8, 1))
    walls = lambda u, v, p: ((0.85 if int(v * 60) % 2 == 0 else 1.1), 1.0, 0.85, 1)
    lathe(b, [(r * 0.95, floor), (r, floor + h * 0.5), (r * 0.92, floor + h)], "Reed", Matrix(), 32, walls)
    # dach: strzecha z mchem
    roof = [(r * 1.35, floor + h - 0.1), (r * 0.9, floor + h + 0.6), (r * 0.35, floor + h + 1.5), (0.0, floor + h + 1.9)]
    lathe(b, roof, "Reed", Matrix(), 32, lambda u, v, p: (0.75 - 0.3 * max(0.0, pnoise(p * 2)), 0.8, 0.6, 1),
          lambda p, u, v: p + Vector((0, 0, -0.06 * math.sin(v * math.tau * 14))))
    for k in range(10):  # grzyby i mech na dachu
        a = rng.uniform(0, math.tau); t = rng.uniform(0.1, 0.8)
        rr = r * 1.3 * (1 - t) + 0.2
        p = Vector((math.cos(a) * rr, math.sin(a) * rr, floor + h + t * 1.6))
        n = Vector((math.cos(a), math.sin(a), 1.2)).normalized()
        cr = rng.uniform(0.08, 0.18)
        tube(b, [p, p + n * cr], [0.02, 0.015], "StemPale", seg=5, cap_end=False)
        m = Matrix.Translation(p + n * cr) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(b, [(0.0, cr * 0.6), (cr, 0.1 * cr), (cr * 0.9, 0.0)], rng.choice(["GhostTop", "KinCapOrange"]), m, 10)
    b.grid(lambda u, v: Vector((-0.3 + 0.6 * u, -r * 1.0, floor + 0.05 + 1.2 * v)), 1, 1, "Lantern")
    b.grid(lambda u, v: Vector((r * 0.98, -0.2 + 0.4 * u, floor + 1.0 + 0.35 * v)), 1, 1, "Lantern")
    # schodki/drabina
    tube(b, [Vector((-0.35, -r * 1.2, floor)), Vector((-0.35, -r * 1.2 - 0.8, -0.1))], [0.04, 0.04], "Wood", seg=5)
    tube(b, [Vector((0.35, -r * 1.2, floor)), Vector((0.35, -r * 1.2 - 0.8, -0.1))], [0.04, 0.04], "Wood", seg=5)
    for k in range(4):
        t = (k + 0.5) / 4
        y = -r * 1.2 - 0.8 * t
        z = floor - (floor + 0.1) * t
        tube(b, [Vector((-0.35, y, z)), Vector((0.35, y, z))], [0.03, 0.03], "Wood", seg=5)
    tube(b, [Vector((r * 0.7, -r * 0.8, floor + h)), Vector((r * 0.9, -r * 1.3, floor + h - 0.1)), Vector((r * 0.9, -r * 1.3, floor + h - 0.5))],
         [0.02] * 3, "Wood", seg=4)
    sphere(b, Vector((r * 0.9, -r * 1.3, floor + h - 0.65)), 0.12, "Lantern", 1, 1, 1.3)
    return b.finish(name)


def walkway(name, a, c, sag=0.5, width=1.1):
    """Kładka z desek między dwoma punktami (lekko zwisa), poręcze z lin, lampiony."""
    b = Builder([])
    d = c - a
    L = d.length
    side = d.cross(Vector((0, 0, 1))).normalized()
    n = int(L / 0.32)
    for i in range(n):
        t0, t1 = i / n, (i + 0.8) / n
        p0 = a + d * t0 + Vector((0, 0, -sag * 4 * t0 * (1 - t0)))
        p1 = a + d * t1 + Vector((0, 0, -sag * 4 * t1 * (1 - t1)))
        b.grid(lambda u, v, p0=p0, p1=p1: p0.lerp(p1, u) + side * (v - 0.5) * width, 1, 1, "Wood",
               color=lambda u, v, p: (0.8 + 0.3 * pnoise(p * 5), 0.8, 0.8, 1))
    for s in (-1, 1):
        rope = [a + d * (k / 10) + side * s * width * 0.5 + Vector((0, 0, 0.8 - sag * 4 * (k / 10) * (1 - k / 10) * 1.2)) for k in range(11)]
        tube(b, rope, [0.025] * 11, "Thread", seg=5)
    for k in (0.3, 0.7):
        p = a + d * k + Vector((0, 0, -sag * 4 * k * (1 - k) + 0.75)) + side * width * 0.5
        sphere(b, p - Vector((0, 0, 0.25)), 0.09, "Lantern", 1, 1, 1.3)
    return b.finish(name)


def grass_field(name, center, r, count=4000, seed=1):
    b = Builder([])
    rng = random.Random(seed)
    for i in range(count):
        a = rng.uniform(0, math.tau); d = r * math.sqrt(rng.random())
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        h = rng.uniform(0.15, 0.45)
        lean = Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0))
        w = 0.025
        dirv = Vector((math.cos(a * 7), math.sin(a * 7), 0)) * w
        shade = rng.uniform(0.7, 1.2)
        b.grid(lambda u, v, p=p, h=h, lean=lean, dirv=dirv: p + dirv * (v - 0.5) * 2 * (1 - u) + Vector((0, 0, h * u)) + lean * u * u,
               2, 1, "Grass", color=lambda u, v, pp, s=shade: (s * (0.6 + 0.6 * u), s * (0.6 + 0.6 * u), s * 0.6, 1))
    for i in range(260):  # kwiaty
        a = rng.uniform(0, math.tau); d = r * 0.9 * math.sqrt(rng.random())
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        h = rng.uniform(0.25, 0.5)
        tube(b, [p, p + Vector((0, 0, h))], [0.008, 0.006], "Grass", seg=4, cap_end=False)
        mat = "Flower" if rng.random() < 0.6 else "FlowerPink"
        m = Matrix.Translation(p + Vector((0, 0, h)))
        lathe(b, [(0.0, 0.02), (0.06, 0.01), (0.07, -0.005)], mat, m, 8)
    o = b.finish(name)
    o.location = center
    return o


def cave_entrance(name):
    """Wejście do jaskini w zboczu: skalny łuk, zwisające świecące korzenie, niebieskie grzyby w środku."""
    b = Builder([])
    rng = random.Random(8)
    hill = fp.rock(name + "_hill", 21, 7.0)
    hill.scale = (1.6, 1.0, 0.9)
    # łuk z grubej skały
    arch = [Vector((-2.4, -5.6, 0)), Vector((-2.6, -5.8, 2.2)), Vector((-1.4, -6.0, 3.5)), Vector((0.2, -6.1, 3.8)),
            Vector((1.6, -6.0, 3.3)), Vector((2.5, -5.8, 2.0)), Vector((2.4, -5.6, 0))]
    tube(b, arch, [1.0, 0.9, 0.85, 0.8, 0.85, 0.9, 1.0], "RockDark", seg=14, wobble=0.25, seed=3,
         color=lambda u, v, p: (0.8 + 0.3 * pnoise(p * 2), 0.8, 0.85, 1))
    # ciemne wnętrze (tył)
    lathe(b, [(0.0, 0.0), (2.2, 0.0), (2.0, 3.0), (0.0, 3.6)], "Eye", Matrix.Translation((0, -4.6, 0)) @ Matrix.Diagonal((1, 0.35, 1, 1)), 24)
    # zwisające korzenie ze świecącymi końcówkami
    for k in range(16):
        x = rng.uniform(-1.8, 1.8)
        top = Vector((x, -6.0 + rng.uniform(-0.3, 0.4), 3.5 - abs(x) * 0.4))
        L = rng.uniform(0.6, 2.0)
        pts = [top, top + Vector((rng.uniform(-0.1, 0.1), -0.05, -L * 0.5)), top + Vector((rng.uniform(-0.15, 0.15), -0.1, -L))]
        tube(b, pts, [0.04, 0.025, 0.01], "Bark", seg=5, color=lambda u, v, p: (0.3, 0.22, 0.2, 1))
        sphere(b, pts[-1], 0.05, "CaveGlow")
    # niebieskie grzybki w środku i u wejścia
    for k in range(40):
        p = Vector((rng.uniform(-1.8, 1.8), rng.uniform(-5.4, -4.2), 0))
        h = rng.uniform(0.1, 0.5)
        tube(b, [p, p + Vector((0, 0, h))], [0.02, 0.015], "StemPale", seg=5, cap_end=False)
        rr = rng.uniform(0.05, 0.14)
        lathe(b, [(0.0, rr * 0.6), (rr, 0.1 * rr), (rr * 0.9, 0.0)], "CaveGlow", Matrix.Translation(p + Vector((0, 0, h))), 10)
    return b.finish(name), hill


# ------------------------------------------------------------------ przedmioty


def spore_mask(name):
    """Spore Mask: respirator na przodzie hełmu, dwa filtry z kapeluszami-osłonkami."""
    b = Builder([])
    m = Matrix.Translation((0, -0.16, 0)) @ Vector((0, -1, 0)).to_track_quat("Z", "Y").to_matrix().to_4x4()
    lathe(b, [(0.0, 0.07), (0.07, 0.065), (0.11, 0.03), (0.12, -0.02), (0.1, -0.03)], "Metal", m, 20)
    for s in (-1, 1):
        c = Vector((0.13 * s, -0.2, -0.03))
        d = Vector((0.6 * s, -1, -0.35)).normalized()
        cm = Matrix.Translation(c) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(b, [(0.0, 0.0), (0.045, 0.0), (0.045, 0.08), (0.0, 0.08)], "Metal", cm, 14)
        lathe(b, [(0.0, 0.13), (0.05, 0.12), (0.07, 0.085), (0.065, 0.08)], "KinCapTeal", cm, 16)
        lathe(b, [(0.065, 0.08), (0.0, 0.09)], "GhostGill", cm, 16, flip=True)
    tube(b, [Vector((-0.12, -0.12, 0.02)), Vector((-0.17, 0.0, 0.05)), Vector((-0.12, 0.14, 0.04))], [0.012] * 3, "Thread", seg=5)
    tube(b, [Vector((0.12, -0.12, 0.02)), Vector((0.17, 0.0, 0.05)), Vector((0.12, 0.14, 0.04))], [0.012] * 3, "Thread", seg=5)
    return b.finish(name)


def mushroom_log(name):
    """Mushroom Log (budowla w bazie): kłoda na koziołkach, rosną na niej jadalne boczniaki."""
    b = Builder([])
    pts = [Vector((-1.2 + 0.3 * k, 0, 0.75)) for k in range(9)]
    tube(b, pts, [0.32] * 9, "Bark", seg=16, color=fp._bark_color("log"), wobble=0.08)
    for x in (-0.9, 0.9):
        for s in (-1, 1):
            tube(b, [Vector((x, 0.0, 0.62)), Vector((x + 0.15 * s, 0.35 * s, 0.0))], [0.05, 0.05], "Wood", seg=6)
            tube(b, [Vector((x, 0.0, 0.62)), Vector((x - 0.15 * s, 0.35 * s, 0.0))], [0.05, 0.05], "Wood", seg=6)
    for k in range(4):
        x = -0.8 + k * 0.55
        rot = Matrix.Rotation(math.radians(180 if k % 2 else 0), 4, "Z")
        fp.oyster_cluster(name, 40 + k, tiers=1, size=0.28, b=b,
                          origin=Matrix.Translation((x, -0.28 if k % 2 == 0 else 0.28, 0.85)) @ rot, finish=False)
    return b.finish(name)


def fiber_spool(name):
    b = Builder([])
    lathe(b, [(0.0, 0.0), (0.22, 0.0), (0.22, 0.04), (0.1, 0.05), (0.1, 0.35), (0.22, 0.36), (0.22, 0.4), (0.0, 0.4)], "Wood", Matrix(), 20)
    lathe(b, [(0.11, 0.05), (0.19, 0.08), (0.2, 0.2), (0.19, 0.32), (0.11, 0.35)], "Thread", Matrix(), 24,
          lambda u, v, p: (0.9 + 0.1 * math.sin(p.z * 220), 0.9, 0.88, 1))
    rng = random.Random(2)
    for k in range(4):
        pts = [Vector((0.2, 0, 0.2))]
        for i in range(8):
            pts.append(pts[-1] + Vector((0.1, rng.uniform(-0.08, 0.08), -0.025 if pts[-1].z > 0.01 else 0)))
        tube(b, pts, [0.006] * len(pts), "ThreadGlow" if k == 0 else "Thread", seg=4)
    return b.finish(name)


def fungicide(name):
    b = Builder([])
    lathe(b, [(0.0, 0.0), (0.09, 0.0), (0.1, 0.02), (0.1, 0.26), (0.05, 0.31), (0.03, 0.34)], "Glass", Matrix(), 20)
    lathe(b, [(0.0, 0.01), (0.085, 0.01), (0.085, 0.2), (0.0, 0.2)], "Liquid", Matrix(), 20)
    lathe(b, [(0.035, 0.33), (0.045, 0.4), (0.03, 0.44), (0.0, 0.45)], "Metal", Matrix(), 12)
    tube(b, [Vector((0, -0.02, 0.42)), Vector((0, -0.09, 0.43))], [0.012, 0.01], "Metal", seg=6)
    tube(b, [Vector((0, 0.03, 0.4)), Vector((0, 0.08, 0.36)), Vector((0, 0.09, 0.3))], [0.012] * 3, "Metal", seg=6)
    return b.finish(name)


def spore_pod(name):
    b = Builder([])
    lathe(b, [(0.0, 0.0), (0.12, 0.05), (0.2, 0.25), (0.17, 0.45), (0.08, 0.58), (0.0, 0.6)], "PodGlow", Matrix(), 20,
          deform=lambda p, u, v: p * (1 + 0.08 * math.sin(v * math.tau * 8) * math.sin(u * math.pi)))
    for k in range(5):
        a = k / 5 * math.tau
        tube(b, [Vector((0, 0, 0.55)), Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.75))], [0.015, 0.004], "Thread", seg=4)
    return b.finish(name)


def cluster_shroom(name):
    """Cluster Shroom: Boomshroom z trzema małymi bombkami dookoła (szkic z modelu Boomshrooma)."""
    roots = import_glb(os.path.join(ROOT, "art", "models", "plants", "boomshroom.glb"), (0, 0, 0))
    for i in range(3):
        a = i / 3 * math.tau + 0.5
        import_glb(os.path.join(ROOT, "art", "models", "plants", "boomshroom.glb"),
                   (math.cos(a) * 0.55, math.sin(a) * 0.55, 0), a, 0.42)
    return roots


# ------------------------------------------------------------------ render


def setup_render():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    try:
        scene.eevee.taa_render_samples = 16 if FAST else 48
    except Exception:
        pass
    scene.render.resolution_x = 960 if FAST else 1800
    scene.render.resolution_y = 540 if FAST else 1000
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    w = bpy.data.worlds.new("W")
    scene.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.07, 0.055, 0.12, 1)
    sun = bpy.data.lights.new("Key", "SUN"); sun.energy = 2.6; sun.color = (0.75, 0.72, 1.0)
    so = bpy.data.objects.new("Key", sun); scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), 0, math.radians(30))
    try:
        tree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
        scene.compositing_node_group = tree
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = tree.nodes.new("CompositorNodeRLayers")
        gl = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        for sname, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.45), ("Size", 0.5)):
            s = gl.inputs.get(sname)
            if s is not None:
                try:
                    s.default_value = val
                except Exception:
                    pass
        tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
        tree.links.new(gl.outputs["Image"], out.inputs[0])
    except Exception as e:
        print("glare", e)


CAM = None


def shot(pos, target, lens, fname):
    global CAM
    if CAM is None:
        CAM = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        CAM.data.clip_end = 500
        scene.collection.objects.link(CAM)
        scene.camera = CAM
    CAM.location = pos
    CAM.data.lens = lens
    CAM.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(SKETCH_DIR, fname)
    bpy.ops.render.render(write_still=True)
    print("rendered", fname)


def fill_light(loc, target, energy=1500, size=12, color=(0.65, 0.6, 1.0)):
    l = bpy.data.lights.new("Fill", "AREA"); l.energy = energy; l.size = size; l.color = color
    o = bpy.data.objects.new("Fill", l); scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# Każdy arkusz stoi w innym miejscu świata (X), żeby się nie mieszały.
def sheet_creatures(ox):
    ground_disc((ox, 0, 0), 14)
    # nawis z kapelusza, pod którym wiszą nietoperze
    over = Builder([])
    lathe(over, [(0.0, 0.5), (1.5, 0.4), (2.4, 0.1), (2.5, 0.0)], "InkCap", Matrix(), 28)
    lathe(over, [(2.5, 0.0), (0.3, 0.2)], "GhostGill", Matrix(), 28, flip=True)
    place(over.finish("Overhang"), (ox - 5, 1.5, 3.2))
    for i, dx in enumerate((-0.6, 0.1, 0.7)):
        place(sporebat("BatHang%d" % i, spread=False), (ox - 5 + dx, 1.5 + 0.2 * i, 3.15), i * 0.6)
    place(sporebat("BatFly", spread=True), (ox - 2.2, 0.2, 2.2), 0.3, 1.6)
    place(sporebat("BatFly2", spread=True), (ox - 3.4, 1.2, 2.8), -0.4, 1.4)
    tick_rock = fp.rock("TickRock", 31, 1.0)
    place(tick_rock, (ox + 0.2, 1.2, 0))
    place(spore_tick("Tick"), (ox + 0.2, 0.9, 0.55), 0.4, 1.2)
    place(spore_tick("Tick2"), (ox - 0.6, -0.6, 0), -0.6, 1.0)
    # zarażone zwierzęta: Muncher i Thornback z naroślami
    import_glb(os.path.join(ROOT, "art", "models", "creatures", "muncher.glb"), (ox + 2.4, -0.2, 0), 0.6)
    place(growths("RotlingGrowths", [(Vector((0, 0, 0.5)), Vector((0, 0.2, 1))), (Vector((0.2, 0.1, 0.4)), Vector((1, 0, 0.5))),
                                    (Vector((-0.2, 0.0, 0.4)), Vector((-1, 0, 0.5)))], 2, 0.22),
          (ox + 2.4, -0.2, 0), 0.6)
    import_glb(os.path.join(ROOT, "art", "models", "creatures", "thornback.glb"), (ox + 5.2, 1.0, 0), 0.9)
    place(growths("RotThornGrowths", [(Vector((0, 0, 1.0)), Vector((0, 0, 1))), (Vector((0, 0.5, 0.9)), Vector((0, 0.3, 1))),
                                     (Vector((0.35, -0.3, 0.7)), Vector((1, 0, 0.6)))], 5, 0.25), (ox + 5.2, 1.0, 0), 0.9)
    place(cocoon("Cocoon"), (ox + 3.0, 3.0, 0))
    place(cocoon("CocoonBurst", burst=True), (ox + 4.6, 3.6, 0))
    farmer((ox - 1.6, -1.6, 0), math.radians(200))
    fill_light((ox, -12, 8), (ox, 0, 1))
    shot((ox, -10.5, 3.4), (ox, 1.0, 1.5), 26, "stage1_1_creatures.png")
    shot((ox - 3.8, -2.6, 1.8), (ox - 4.2, 1.5, 2.6), 30, "stage1_1b_sporebats.png")


def sheet_glade(ox):
    ground_disc((ox, 0, 0), 30, "RotGround")
    g = ground_disc((ox, 0, 0.01), 12, "Grass")
    grass_field("Glade", (ox, 0, 0), 12, 12000 if not FAST else 3000)
    rng = random.Random(4)
    # olbrzymy dookoła polany (ze zgnilizną u stóp)
    for i in range(9):
        a = i / 9 * math.tau
        x, y = ox + math.cos(a) * 16, math.sin(a) * 16
        g = Builder([])
        tube(g, [Vector((0, 0, 0)), Vector((0, 0, 14)), Vector((0.5, 0, 26))], [1.6, 1.2, 1.0], "StemPale", seg=14)
        lathe(g, [(0.0, 4.5), (5, 4.0), (9, 1.5), (10, 0.0)], "InkCap", Matrix.Translation((0.5, 0, 26)), 32)
        lathe(g, [(10, 0.0), (1.2, 0.8)], "GhostGill", Matrix.Translation((0.5, 0, 26)), 32, flip=True)
        place(g.finish("Giant%d" % i), (x, y, 0))
    place(rot_shepherd("RotShepherd"), (ox + 1.5, 2.5, 0), math.radians(200))
    for i in range(4):
        x, y = ox + rng.uniform(-3, 4), rng.uniform(-1, 4)
        import_glb(os.path.join(ROOT, "art", "models", "creatures", "muncher.glb"), (x, y, 0), rng.uniform(0, math.tau))
        place(growths("RotlingG%d" % i, [(Vector((0, 0, 0.5)), Vector((0, 0.2, 1))), (Vector((0.2, 0, 0.4)), Vector((1, 0, 0.5)))], 10 + i, 0.22), (x, y, 0))
    farmer((ox - 3.5, -5.5, 0), math.radians(160))
    # słońce przez dziurę w kapeluszach
    sp = bpy.data.lights.new("SunShaft", "SPOT"); sp.energy = 30000; sp.spot_size = math.radians(40); sp.spot_blend = 0.5
    sp.color = (1.0, 0.92, 0.7)
    so = bpy.data.objects.new("SunShaft", sp); scene.collection.objects.link(so)
    so.location = (ox, 0, 24)
    fill_light((ox, -14, 6), (ox, 0, 1), 1200)
    shot((ox - 2, -13, 3.2), (ox + 1, 1.5, 2.2), 24, "stage1_2_glade_shepherd.png")
    shot((ox + 3.5, -2.0, 1.9), (ox + 1.5, 2.5, 1.9), 32, "stage1_2b_shepherd_close.png")


def sheet_puffking(ox):
    ground_disc((ox, 0, 0), 30)
    place(puffking("Puffking"), (ox, 2, 2.6))
    for i, (dx, dy) in enumerate(((-6, -2), (5.5, -3), (7, 2.5))):
        place(mini_puff("Mini%d" % i), (ox + dx, dy, 0.65), 0.3 * i)
    # grube sznury grzybni zbiegające się do areny
    rng = random.Random(3)
    cords = Builder([])
    for k in range(12):
        a = k / 12 * math.tau + rng.uniform(-0.2, 0.2)
        pts = []
        for i in range(10):
            d = 4 + i * 2.2
            a2 = a + math.sin(i * 0.8 + k) * 0.08
            pts.append(Vector((math.cos(a2) * d, 2 + math.sin(a2) * d, 0.05)))
        fp.tube(cords, pts, [0.35 * (1 - i / 12) for i in range(10)], "ThreadGlow", seg=8)
    place(cords.finish("Cords"), (ox, 0, 0))
    farmer((ox - 1.8, -6.5, 0), math.radians(170))
    fill_light((ox, -16, 9), (ox, 2, 2), 2500)
    shot((ox + 1, -16, 4.0), (ox, 2, 2.6), 26, "stage1_3_puffking.png")
    shot((ox - 2.5, -7.5, 1.6), (ox, 2, 3.2), 26, "stage1_3b_puffking_face.png")


def sheet_village(ox):
    ground_disc((ox, 0, 0), 25)
    stems = [Vector((ox - 6, 4, 0)), Vector((ox + 5, 6, 0)), Vector((ox + 0.5, -2, 0))]
    for i, s in enumerate(stems):
        g = Builder([])
        tube(g, [Vector((0, 0, 0)), Vector((0, 0, 12)), Vector((0, 0, 24))], [1.8, 1.4, 1.2], "StemPale", seg=16)
        place(g.finish("VStem%d" % i), s)
        # platforma dookoła trzonu
        p = Builder([])
        lathe(p, [(1.3, 0.0), (3.2, 0.0), (3.2, -0.25), (1.3, -0.25)], "Wood", Matrix(), 24,
              lambda u, v, pp: (0.8 + 0.3 * pnoise(pp * 3), 0.8, 0.8, 1))
        place(p.finish("Platform%d" % i), s + Vector((0, 0, 4.0 + i * 0.6)))
    walkway("Walk1", stems[0] + Vector((2.8, 0.6, 4.0)), stems[2] + Vector((-2.6, 1.0, 5.2)))
    walkway("Walk2", stems[2] + Vector((2.4, 1.6, 5.2)), stems[1] + Vector((-2.6, -1.2, 4.6)))
    place(stilt_hut("Hut1"), (ox - 8.5, 0.5, 0), 0.3)
    place(stilt_hut("Hut2", 2.0, 1.3), (ox + 7.5, 1.5, 0), -0.4)
    place(stilt_hut("Hut3", 1.6, 1.0), stems[0] + Vector((0.6, -2.4, 4.0 - 1.0)), 0.2, 0.8)
    for i, lant in enumerate((True, False, False, False)):
        place(sporekin("Kin%d" % i, i, i + 1, lant), (ox - 2.5 + i * 1.3, -4.5 + (i % 2) * 0.6, 0), math.radians((i - 1.5) * 15))
    place(sporekin("KinUp", 1, 9, True), stems[2] + Vector((-1.5, -2.2, 5.2)), math.radians(20))
    farmer((ox + 3.2, -6.2, 0), math.radians(40))
    fill_light((ox, -16, 8), (ox, 0, 2), 2000)
    shot((ox, -15, 4.5), (ox, 1, 3.0), 24, "stage1_4_sporekin_village.png")
    shot((ox - 0.5, -8.6, 1.3), (ox - 0.5, -4.5, 0.9), 34, "stage1_4b_sporekin_close.png")


def sheet_cave(ox):
    ground_disc((ox, 0, 0), 20)
    arch, hill = cave_entrance("Cave")
    place(arch, (ox, 0, 0))
    hill.location = (ox, 0, -1.5)
    farmer((ox + 0.8, -9, 0), math.radians(10))
    fill_light((ox, -15, 5), (ox, -5, 2), 1500)
    shot((ox + 3, -16, 2.6), (ox, -5, 2.0), 30, "stage1_5_cave.png")


def _phantomize(roots):
    for root in roots:
        for o in [root] + list(root.children_recursive):
            if o.type == "MESH":
                o.data = o.data.copy()
                o.data.materials.clear()
                o.data.materials.append(M["Phantom"])


def sheet_sporecave(ox):
    """Grota Zarodników: gęsta, świecąca mgła zarodników, w środku najlepsze znajdźki; bez maski halucynacje:
    fantomowi przeciwnicy (fioletowe, półprzezroczyste) i fałszywe znajdźki (migoczą), obraz faluje."""
    rng = random.Random(12)
    ground_disc((ox, 0, 0), 14, "RockDark")
    shell = Builder([])
    lathe(shell, [(13.0, 0.0), (12.0, 4.0), (8.0, 7.5), (0.0, 8.5)], "RockDark", Matrix(), 40,
          lambda u, v, p: (0.7 + 0.4 * pnoise(p * 0.5), 0.7, 0.8, 1), lambda p, u, v: p * (1 + 0.12 * pnoise(p * 0.4)), flip=True)
    place(shell.finish("CaveShell"), (ox, 0, 0))
    # stalaktyty i grzyby
    deco = Builder([])
    for k in range(40):
        a = rng.uniform(0, math.tau); d = rng.uniform(1, 9)
        top = Vector((math.cos(a) * d, math.sin(a) * d, 8.2 - d * 0.45))
        L = rng.uniform(0.5, 2.5)
        lathe(deco, [(0.25 * L * 0.3, 0.0), (0.0, -L)], "RockDark", Matrix.Translation(top), 8)
    for k in range(160):
        a = rng.uniform(0, math.tau); d = rng.uniform(1.5, 12)
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        h = rng.uniform(0.1, 0.7)
        tube(deco, [p, p + Vector((0, 0, h))], [0.025, 0.02], "StemPale", seg=5, cap_end=False)
        rr = rng.uniform(0.06, 0.2)
        lathe(deco, [(0.0, rr * 0.6), (rr, 0.1 * rr), (rr * 0.9, 0.0)], rng.choice(["SporeSac", "CaveGlow", "SporeSac"]),
              Matrix.Translation(p + Vector((0, 0, h))), 10)
    place(deco.finish("CaveDeco"), (ox, 0, 0))
    # gęsta mgła zarodników (objętość)
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    me = bpy.data.meshes.new("SporeFog"); bm.to_mesh(me); bm.free()
    fog = bpy.data.materials.new("SporeFogMat"); fog.use_nodes = True
    nt = fog.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.7, 0.5, 0.9, 1)
    vol.inputs["Density"].default_value = 0.022
    vol.inputs["Emission Color"].default_value = (0.6, 0.3, 1.0, 1)
    vol.inputs["Emission Strength"].default_value = 0.012
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    me.materials.append(fog)
    fo = bpy.data.objects.new("SporeFog", me); scene.collection.objects.link(fo)
    fo.location = (ox, 0, 3); fo.scale = (24, 24, 6)
    # zarodniki w powietrzu
    dust = Builder([])
    for k in range(900):
        p = Vector((rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(0.2, 6)))
        sphere(dust, p, rng.uniform(0.01, 0.03), "SporeSac", seg=6)
    place(dust.finish("SporeDust"), (ox, 0, 0))
    # prawdziwe znajdźki (w głębi) i fałszywe (fantomy, migoczą)
    pick = os.path.join(ROOT, "art", "models", "pickups")
    import_glb(os.path.join(pick, "relic.glb"), (ox + 0.5, 6.5, 0), 0, 1.4)
    import_glb(os.path.join(pick, "glowmoss.glb"), (ox - 2.5, 5.5, 0), 0, 1.3)
    for i, (dx, dy) in enumerate(((-4.5, 2.5), (3.5, 3.5), (-1.5, 0.5), (5.0, 0.0))):
        _phantomize(import_glb(os.path.join(pick, ("relic.glb", "crystal.glb", "glowmoss.glb", "seed.glb")[i]), (ox + dx, dy, 0), 0.4 * i, 1.4))
    # fantomowi przeciwnicy
    _phantomize(import_glb(os.path.join(ROOT, "art", "models", "creatures", "thornback.glb"), (ox + 2.5, 1.2, 0), math.radians(200), 1.1))
    _phantomize(import_glb(os.path.join(ROOT, "art", "models", "creatures", "muncher.glb"), (ox - 3.0, 1.0, 0), math.radians(160), 1.2))
    ph = sporebat("PhantomBat", spread=True)
    place(ph, (ox - 0.8, 2.5, 2.6), 0.2, 1.8)
    ph.data.materials.clear(); ph.data.materials.append(M["Phantom"])
    farmer((ox + 0.2, -5.5, 0), math.radians(20))
    fill_light((ox, -8, 4), (ox, 2, 1), 600, 6, (0.7, 0.5, 1.0))
    shot((ox + 0.5, -10.5, 2.2), (ox, 2.5, 1.4), 26, "stage1_7_spore_cave.png")


def sheet_items(ox):
    ground_disc((ox, 0, 0), 10)
    roots = farmer((ox - 2.4, 0, 0), math.radians(200))
    place(spore_mask("SporeMaskOnFarmer"), (ox - 2.4 + 0.02, -0.12, 1.42), math.radians(200 - 180))
    place(spore_mask("SporeMask"), (ox - 1.0, -0.4, 0.3), 0.3, 2.0)
    place(mushroom_log("MushroomLog"), (ox + 1.3, 0.8, 0), 0.2)
    place(fiber_spool("Fiber"), (ox + 0.1, -1.0, 0), 0.4)
    place(fungicide("Fungicide"), (ox + 0.9, -1.2, 0), 0.2, 1.3)
    place(spore_pod("SporePod"), (ox + 1.7, -1.3, 0), 0.0, 1.2)
    cs = cluster_shroom("Cluster")
    for o in cs:
        o.location = (ox + 3.6, -0.3, 0)
    fill_light((ox, -8, 4), (ox, 0, 0.8), 900, 8)
    shot((ox + 0.6, -6.5, 2.0), (ox + 0.6, 0, 0.7), 34, "stage1_6_items.png")


def main():
    setup_render()
    table = {"creatures": sheet_creatures, "glade": sheet_glade, "puffking": sheet_puffking,
             "village": sheet_village, "cave": sheet_cave, "items": sheet_items, "sporecave": sheet_sporecave}
    order = ALL_SHEETS
    for i, key in enumerate(order):
        if key in SHEETS:
            table[key](i * 300.0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "source", "stage1_sketch.blend"))


if __name__ == "__main__":  # import z forest_creatures.py bierze tylko funkcje
    main()
