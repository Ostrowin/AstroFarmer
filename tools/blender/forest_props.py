"""Modele otoczenia Grzybowego Lasu + nowy Hammer Cap (grzyb-młot ze ściany kanionu).

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/forest_props.py -- [export] [sheet]

  export - zapisuje art/models/forest/<nazwa>.glb (jeden obiekt na model; Hammer Cap: Root + Arm)
  sheet  - render podglądu wszystkich modeli z farmerem dla skali: art/source/sketches/forest_props_*.png
Bez argumentów robi oba. Źródło: art/source/forest_props.blend.

Konwencje (Blender, Z w górę):
  - modele "naziemne" stoją na Z = 0,
  - modele "ścienne" rosną z płaszczyzny ściany Y = 0 w stronę -Y (w Godocie to lokalne +Z = normalna ściany),
  - UV na kapeluszach: U = odległość od nasady (0) do brzegu (1), V = kąt (wzdłuż brzegu); shader w Godocie
    rysuje z tego blaszki i świecenie,
  - kolor wierzchołków "Col" = wariacje koloru (mech, kora, plamy), alfa = maska świecenia,
  - materiały rozpoznawane w Godocie po nazwie (GhostTop, GillOrange, FernLeaf...).
Modele nie są low poly: kapelusze mają gęste siatki, faliste brzegi i grubość, kora i skały są pofałdowane.
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix
from mathutils.noise import noise as pnoise, fractal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "forest")
SKETCH_DIR = os.path.join(ROOT, "art", "source", "sketches")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_EXPORT = not ARGV or "export" in ARGV
DO_SHEET = not ARGV or "sheet" in ARGV
FAST = os.environ.get("SKETCH_FAST") == "1"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ------------------------------------------------------------------ materiały (podgląd + nazwy dla Godota)

MATS = {}


def _vc_mul(m, b, color):
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["A"].default_value = (*color, 1)
    nt.links.new(attr.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    return attr


def plain(name, color, rough=0.75):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = rough
    _vc_mul(m, b, color)
    MATS[name] = m
    return m


def glow(name, base, glow_color, strength_in, strength_out, stripes=0.0, stripe_amount=0.0):
    """Świecący kapelusz/blaszki: siła świecenia zależy od U (nasada -> brzeg), paski od V."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Emission Color"].default_value = (*glow_color, 1)
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    grad = nt.nodes.new("ShaderNodeMapRange")
    grad.inputs["To Min"].default_value = strength_in
    grad.inputs["To Max"].default_value = strength_out
    nt.links.new(sep.outputs["X"], grad.inputs["Value"])
    out = grad.outputs["Result"]
    if stripes > 0:
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = stripes * math.tau
        nt.links.new(sep.outputs["Y"], mul.inputs[0])
        sn = nt.nodes.new("ShaderNodeMath"); sn.operation = "SINE"
        nt.links.new(mul.outputs[0], sn.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = -1
        mr.inputs["To Min"].default_value = 1.0 - stripe_amount
        nt.links.new(sn.outputs[0], mr.inputs["Value"])
        m2 = nt.nodes.new("ShaderNodeMath"); m2.operation = "MULTIPLY"
        nt.links.new(out, m2.inputs[0]); nt.links.new(mr.outputs["Result"], m2.inputs[1])
        out = m2.outputs[0]
    nt.links.new(out, b.inputs["Emission Strength"])
    MATS[name] = m
    return m


M = {
    "GhostTop": glow("GhostTop", (0.55, 0.85, 0.45), (0.45, 1.0, 0.3), 2.5, 1.6, 26, 0.25),
    "GhostGill": glow("GhostGill", (0.45, 0.75, 0.35), (0.6, 1.0, 0.3), 3.0, 1.4, 60, 0.6),
    "RuffleGlow": glow("RuffleGlow", (0.35, 0.8, 0.3), (0.3, 1.0, 0.25), 1.8, 2.6, 18, 0.55),
    "OysterTop": plain("OysterTop", (0.78, 0.74, 0.86), 0.55),
    "GillOrange": glow("GillOrange", (0.5, 0.3, 0.15), (1.0, 0.55, 0.15), 4.0, 0.6, 70, 0.6),
    "InkCap": plain("InkCap", (0.13, 0.1, 0.16), 0.45),
    "InkRim": glow("InkRim", (0.2, 0.1, 0.3), (0.65, 0.3, 1.0), 3.5, 3.5),
    "StemPale": plain("StemPale", (0.72, 0.7, 0.68), 0.7),
    "Coral": plain("Coral", (0.22, 0.12, 0.3), 0.6),
    "CoralTip": glow("CoralTip", (0.3, 0.8, 0.9), (0.3, 0.95, 1.0), 3.0, 3.0),
    "FernLeaf": plain("FernLeaf", (0.12, 0.26, 0.24), 0.7),
    "ShrubLeaf": plain("ShrubLeaf", (0.2, 0.14, 0.28), 0.65),
    "BulbGlow": glow("BulbGlow", (0.8, 0.3, 0.6), (1.0, 0.35, 0.75), 3.0, 3.0),
    "Rock": plain("Rock", (1.0, 1.0, 1.0), 0.85),
    "Bark": plain("Bark", (1.0, 1.0, 1.0), 0.85),
    "Birch": plain("Birch", (1.0, 1.0, 1.0), 0.75),
    "ShelfTop": plain("ShelfTop", (0.55, 0.32, 0.16), 0.7),
    "ShelfGlow": glow("ShelfGlow", (0.5, 0.3, 0.1), (1.0, 0.58, 0.12), 2.6, 1.2, 40, 0.5),
    "HammerCap": plain("HammerCap", (0.5, 0.15, 0.1), 0.55),
    "HammerStem": plain("HammerStem", (0.8, 0.72, 0.62), 0.7),
    "HammerGlow": glow("HammerGlow", (0.4, 0.2, 0.08), (1.0, 0.55, 0.12), 2.5, 1.0, 50, 0.5),
}

# ------------------------------------------------------------------ budowniczy siatek


class Builder:
    """Zbiera geometrię do jednego bmesh: siatki (u, v) z UV, kolorem wierzchołków i materiałem."""

    def __init__(self, mats):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.color.new("Col")
        self.mats = mats  # lista nazw materiałów -> indeksy

    def mat_index(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def grid(self, pos, nu, nv, mat, matrix=Matrix(), color=None, flip=False):
        """pos(u, v) -> Vector; color(u, v, p) -> (r, g, b, a). Zwraca siatkę wierzchołków."""
        mi = self.mat_index(mat)
        verts = []
        for i in range(nu + 1):
            row = []
            for j in range(nv + 1):
                u, v = i / nu, j / nv
                row.append(self.bm.verts.new(matrix @ pos(u, v)))
            verts.append(row)
        for i in range(nu):
            for j in range(nv):
                q = [verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1]]
                uvs = [(i / nu, j / nv), ((i + 1) / nu, j / nv), ((i + 1) / nu, (j + 1) / nv), (i / nu, (j + 1) / nv)]
                if flip:
                    q.reverse(); uvs.reverse()
                try:
                    f = self.bm.faces.new(q)
                except ValueError:
                    continue
                f.material_index = mi
                f.smooth = True
                for loop, uv in zip(f.loops, uvs):
                    loop[self.uv].uv = uv
                    c = color(uv[0], uv[1], loop.vert.co) if color else (1, 1, 1, 1)
                    loop[self.col] = c
        return verts

    def finish(self, name):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for n in self.mats:
            me.materials.append(M[n])
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
        o = bpy.data.objects.new(name, me)
        scene.collection.objects.link(o)
        return o


def frame(d, up=Vector((0, 0, 1))):
    """Baza: X wzdłuż d, Z możliwie w górę."""
    x = d.normalized()
    z = (up - x * up.dot(x))
    if z.length < 1e-4:
        z = Vector((0, 1, 0)) - x * x.y
    z.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def tube(b, pts, radii, mat, seg=10, color=None, cap_end=True, wobble=0.0, seed=0):
    """Rurka wzdłuż punktów (transport ramki), UV: U wzdłuż, V dookoła."""
    n = len(pts)
    tangents = []
    for i in range(n):
        a = pts[max(i - 1, 0)]; c = pts[min(i + 1, n - 1)]
        tangents.append((c - a).normalized())
    normal = tangents[0].orthogonal().normalized()
    frames = []
    for i in range(n):
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()
        frames.append((normal, t.cross(normal)))

    def pos(u, v):
        fi = u * (n - 1)
        i = min(int(fi), n - 2)
        k = fi - i
        p = pts[i].lerp(pts[i + 1], k)
        r = radii[i] + (radii[i + 1] - radii[i]) * k
        nn = frames[i][0].lerp(frames[i + 1][0], k).normalized()
        bb = frames[i][1].lerp(frames[i + 1][1], k).normalized()
        a = v * math.tau
        if wobble > 0:
            r *= 1 + wobble * pnoise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, u * 6 + seed)))
        return p + (nn * math.cos(a) + bb * math.sin(a)) * r

    b.grid(pos, max(2, (n - 1) * 3), seg, mat, color=color)
    if cap_end:
        tip = pts[-1]
        b.grid(lambda u, v: tip.lerp(pos(1.0, v), 1 - u), 1, seg, mat, color=color, flip=True)


# ------------------------------------------------------------------ kapelusze


class Fan:
    def __init__(self, R, rng, span=math.radians(210), cup=0.25, ruffle=0.06, droop=0.05, lobe=0.08,
                 n_ruffle=None, th=0.06):
        self.R = R; self.span = span; self.cup = cup; self.ruffle = ruffle; self.droop = droop
        self.lobe = lobe; self.th = th
        self.k1 = rng.choice((3, 4, 5)); self.k2 = rng.choice((7, 9, 11))
        self.n = n_ruffle or rng.choice((5, 7, 9, 11))
        self.ph = [rng.uniform(0, math.tau) for _ in range(4)]

    def top(self, u, v):
        a = (v - 0.5) * self.span
        Ra = self.R * (1 + self.lobe * math.sin(a * self.k1 + self.ph[0]) + self.lobe * 0.5 * math.sin(a * self.k2 + self.ph[1]))
        r = 0.02 * self.R + (Ra - 0.02 * self.R) * u
        z = (self.cup * u ** 1.6 + self.ruffle * u ** 3 * math.sin(a * self.n + self.ph[2])
             - self.droop * u ** 4) * self.R
        return Vector((r * math.cos(a), r * math.sin(a), z))

    def bottom(self, u, v):
        p = self.top(u, v)
        p.z -= self.th * self.R * (1 - 0.75 * u)
        return p


def fan_cap(b, fan, matrix, top_mat, gill_mat, top_color=None, gill_color=None, nu=12, nv=32):
    b.grid(fan.top, nu, nv, top_mat, matrix, top_color)
    b.grid(fan.bottom, nu, nv, gill_mat, matrix, gill_color, flip=True)
    # brzeg (pasek łączący górę i dół)
    b.grid(lambda u, v: fan.top(1.0, v).lerp(fan.bottom(1.0, v), u), 1, nv, top_mat, matrix, top_color, flip=True)


def lathe(b, profile, mat, matrix=Matrix(), seg=24, color=None, deform=None, flip=False):
    """Bryła obrotowa: profile = [(r, z)], U wzdłuż profilu, V dookoła."""
    n = len(profile)

    def pos(u, v):
        fi = u * (n - 1)
        i = min(int(fi), n - 2)
        k = fi - i
        r = profile[i][0] + (profile[i + 1][0] - profile[i][0]) * k
        z = profile[i][1] + (profile[i + 1][1] - profile[i][1]) * k
        a = v * math.tau
        p = Vector((r * math.cos(a), r * math.sin(a), z))
        return deform(p, u, v) if deform else p

    b.grid(pos, (n - 1) * 2, seg, mat, matrix, color, flip)


# ------------------------------------------------------------------ modele


def ghost_cluster(name, seed, count=9, size=0.5, mount="wall"):
    """Świecące zielone grzyby wachlarzowe (jak boczniaki): kępa wachlarzy z płatowymi brzegami."""
    rng = random.Random(seed)
    b = Builder([])
    for i in range(count):
        R = size * rng.uniform(0.45, 1.0) * (1.0 if i > 1 else 1.25)
        fan = Fan(R, rng, span=math.radians(rng.uniform(200, 260)), cup=rng.uniform(0.3, 0.55),
                  ruffle=rng.uniform(0.04, 0.1), droop=rng.uniform(0.05, 0.15), lobe=rng.uniform(0.06, 0.12))
        if mount == "wall":
            base = Vector((rng.uniform(-1, 1) * size * 1.4, 0.0, rng.uniform(-0.8, 1.2) * size * 1.3))
            out = Vector((rng.uniform(-0.6, 0.6), -1.0, rng.uniform(0.7, 1.6)))
        else:
            a = rng.uniform(0, math.tau)
            base = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0, 0.5) * size + Vector((0, 0, rng.uniform(0.05, 0.3) * size))
            out = Vector((math.cos(a), math.sin(a), rng.uniform(0.4, 1.2)))
        stem_len = R * rng.uniform(0.15, 0.35)
        tip = base + out.normalized() * stem_len
        tube(b, [base - out.normalized() * 0.05 * size, base.lerp(tip, 0.5), tip],
             [R * 0.12, R * 0.1, R * 0.09], "GhostGill", seg=8, cap_end=False)
        # Wachlarz uniesiony: płaszczyzna kapelusza stromo, otwarta na zewnątrz (jak na zdjęciach).
        fd = Vector((out.x, out.y, out.z))
        mat = Matrix.Translation(tip) @ frame(fd, Vector((0, -1, 0.35)) if mount == "wall" else Vector((0, 0, 1))).to_4x4()
        shade = rng.uniform(0.75, 1.0)
        fan_cap(b, fan, mat, "GhostTop", "GhostGill", lambda u, v, p, s=shade: (s, s, s, s),
                lambda u, v, p, s=shade: (s, s, s, s))
    return b.finish(name)


def ruffle_rosette(name, seed, size=0.6):
    """Gęsta, kędzierzawa rozeta drobnych wachlarzy na kopczyku (świecąca zieleń)."""
    rng = random.Random(seed)
    b = Builder([])
    for i in range(70):
        # punkty na półkuli skierowanej od ściany (-Y)
        a = rng.uniform(-1.3, 1.3); e = rng.uniform(-0.9, 1.1)
        dirv = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        base = dirv * size * rng.uniform(0.15, 0.55) + Vector((0, 0.05, 0))
        R = size * rng.uniform(0.18, 0.4)
        fan = Fan(R, rng, span=math.radians(rng.uniform(150, 230)), cup=rng.uniform(0.35, 0.7),
                  ruffle=rng.uniform(0.12, 0.22), droop=rng.uniform(0.0, 0.1), lobe=0.12, n_ruffle=rng.choice((9, 11, 13)))
        mat = Matrix.Translation(base) @ frame(dirv + Vector((0, 0, 0.4))).to_4x4()
        s = rng.uniform(0.7, 1.0)
        fan_cap(b, fan, mat, "RuffleGlow", "RuffleGlow", lambda u, v, p, s=s: (s, s, s, s),
                lambda u, v, p, s=s: (s * 0.8, s * 0.8, s * 0.8, s), nu=8, nv=22)
    return b.finish(name)


def oyster_cluster(name, seed, tiers=3, size=0.55, b=None, origin=Matrix(), finish=True):
    """Boczniaki: blade, liliowe kapelusze, pod spodem pomarańczowo świecące blaszki; piętra na pniu/ścianie."""
    rng = random.Random(seed)
    own = b is None
    if own:
        b = Builder([])
    for t in range(tiers):
        z0 = t * size * 1.1
        for i in range(rng.randint(3, 5)):
            R = size * rng.uniform(0.5, 1.0)
            fan = Fan(R, rng, span=math.radians(rng.uniform(160, 220)), cup=rng.uniform(0.08, 0.2),
                      ruffle=rng.uniform(0.05, 0.1), droop=rng.uniform(0.15, 0.3), lobe=0.1, th=0.09)
            base = Vector((rng.uniform(-1, 1) * size * 0.9, 0.02, z0 + rng.uniform(-0.25, 0.25) * size))
            out = Vector((rng.uniform(-0.7, 0.7), -1.0, rng.uniform(0.15, 0.45)))
            tip = base + out.normalized() * R * 0.18
            tube(b, [base, tip], [R * 0.16, R * 0.13], "StemPale", seg=8, cap_end=False)
            mat = origin @ Matrix.Translation(tip) @ frame(out).to_4x4()
            top = lambda u, v, p: (0.85 + 0.15 * u, 0.85 + 0.15 * u, 0.9 + 0.1 * u, 1)
            fan_cap(b, fan, mat, "OysterTop", "GillOrange", top, lambda u, v, p: (1, 1, 1, 1))
    if own and finish:
        return b.finish(name)


def inkcap_cluster(name, seed, count=5, size=1.0):
    """Ciemne czernidłaki: wysokie, nieregularne dzwony z postrzępionym brzegiem, słaba fioletowa poświata brzegu."""
    rng = random.Random(seed)
    b = Builder([])
    for i in range(count):
        h = size * rng.uniform(0.6, 1.6)
        r = h * rng.uniform(0.18, 0.28)
        a = rng.uniform(0, math.tau); d = rng.uniform(0, 0.35) * size
        base = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        lean = Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 1)).normalized()
        top = base + lean * h
        tube(b, [base, base.lerp(top, 0.5) + Vector((rng.uniform(-0.03, 0.03), 0, 0)), top],
             [r * 0.35, r * 0.25, r * 0.2], "StemPale", seg=10, cap_end=False)
        cap_h = r * rng.uniform(2.2, 3.0)
        seed_i = rng.uniform(0, 100)

        def deform(p, u, v, r=r, s=seed_i):
            n = fractal(Vector((p.x * 3 / r, p.y * 3 / r, p.z * 2 / r + s)), 0.6, 2.0, 3)
            k = 1 + 0.07 * n
            q = Vector((p.x * k, p.y * k, p.z))
            if u > 0.75:  # postrzępiony, "rozpływający się" brzeg
                a = v * math.tau
                q.z -= (u - 0.75) * 4 * r * 0.35 * max(0.0, math.sin(a * 13 + s) * 0.6 + math.sin(a * 5 + s) * 0.5)
            return q

        prof = [(0.0, cap_h), (r * 0.45, cap_h * 0.95), (r * 0.8, cap_h * 0.72), (r * 0.98, cap_h * 0.4),
                (r * 1.02, cap_h * 0.1), (r * 1.0, 0.0)]
        m = Matrix.Translation(top - lean * cap_h * 0.8) @ frame(Vector((1, 0, 0)), lean).to_4x4()
        # obrót, żeby oś kapelusza była wzdłuż `lean`
        m = Matrix.Translation(top - lean * cap_h * 0.8) @ lean.to_track_quat("Z", "Y").to_matrix().to_4x4()
        def shade(u, v, p, s=seed_i):
            # łuski: jaśniejsze, postrzępione pasma w dół kapelusza
            scale = max(0.0, math.sin(v * math.tau * 22 + 3 * pnoise(Vector((v * 9, u * 5, s))))) ** 3
            k = 0.7 + 0.5 * (1 - u) + 1.4 * scale * (0.3 + 0.7 * u)
            return (k, k * 0.92, k * 1.1, 1)
        lathe(b, prof, "InkCap", m, 28, shade, deform)
        rim = [(r * 1.02, 0.03 * cap_h), (r * 1.0, -0.01 * cap_h), (r * 0.84, 0.02 * cap_h)]
        lathe(b, rim, "InkRim", m, 28, None, deform)
        lathe(b, [(r * 0.86, 0.02 * cap_h), (r * 0.3, cap_h * 0.75)], "InkCap", m, 28,
              lambda u, v, p: (0.5, 0.45, 0.55, 1), deform, flip=True)
    return b.finish(name)


def coral(name, seed, size=1.0):
    """Grzyb koralowy: rozgałęzione ciemnofioletowe ramiona ze świecącymi końcówkami."""
    rng = random.Random(seed)
    b = Builder([])

    def branch(p, d, length, r, depth):
        pts = [p]
        q = p.copy(); dd = d.copy()
        for k in range(4):
            dd = (dd + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.15))).normalized()
            q = q + dd * length / 4
            pts.append(q.copy())
        radii = [r * (1 - k / 5 * 0.45) for k in range(5)]
        col = lambda u, v, pp, depth=depth: (0.7 + depth * 0.15, 0.7 + depth * 0.1, 0.8 + depth * 0.1, 1)
        tube(b, pts, radii, "Coral", seg=7, color=col, cap_end=False)
        if depth < 3:
            for _ in range(rng.randint(2, 3)):
                nd = (dd + Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(0.1, 0.6)))).normalized()
                branch(q, nd, length * rng.uniform(0.55, 0.75), radii[-1] * 0.85, depth + 1)
        else:
            bm_tip = Matrix.Translation(q) @ Matrix.Scale(radii[-1] * 1.9, 4)
            lathe(b, [(0.0, -1.0), (0.8, -0.6), (1.0, 0.0), (0.8, 0.6), (0.0, 1.0)], "CoralTip", bm_tip, 10)

    for i in range(rng.randint(3, 5)):
        a = rng.uniform(0, math.tau)
        branch(Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.05)) * size,
               Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 1)).normalized(), 0.45 * size, 0.07 * size, 0)
    return b.finish(name)


def fern(name, seed, size=1.6, fronds=12):
    """Obca paproć: łukowate liście z listkami po obu stronach, w środku zwinięte pastorały."""
    rng = random.Random(seed)
    b = Builder([])
    for f in range(fronds):
        a = f / fronds * math.tau + rng.uniform(-0.2, 0.2)
        L = size * rng.uniform(0.7, 1.0)
        rise = rng.uniform(0.9, 1.4)
        dirh = Vector((math.cos(a), math.sin(a), 0))
        pts = []
        for k in range(9):
            t = k / 8
            pts.append(dirh * L * t * 0.95 + Vector((0, 0, L * rise * (t * 0.9 - t * t * 0.75))))
        tube(b, pts, [0.018 * size * (1 - k / 10) for k in range(9)], "FernLeaf", seg=5,
             color=lambda u, v, p: (0.6, 0.6, 0.65, 1), cap_end=False)
        # listki
        for k in range(1, 22):
            t = k / 22
            fi = t * 8
            i = min(int(fi), 7)
            p = pts[i].lerp(pts[i + 1], fi - i)
            tdir = (pts[i + 1] - pts[i]).normalized()
            side = tdir.cross(Vector((0, 0, 1))).normalized()
            leaf_len = L * 0.22 * math.sin(math.pi * (0.15 + 0.85 * t)) * (1.0 - 0.3 * t)
            for s in (-1, 1):
                d = (side * s + tdir * 0.35 + Vector((0, 0, -0.15))).normalized()
                w = leaf_len * 0.28
                nrm = d.cross(tdir).normalized() * s

                def leaf(u, v, p=p, d=d, w=w, ll=leaf_len, nrm=nrm, tdir=tdir):
                    x = u * ll
                    width = w * math.sin(math.pi * min(u * 1.1, 1.0)) * (v - 0.5) * 2
                    curl = -0.25 * ll * u * u
                    return p + d * x + tdir * width + nrm * curl * 0.3 + Vector((0, 0, curl * 0.4))

                tip_c = lambda u, v, pp, t=t: (0.75 + 0.5 * u * (1 - t * 0.3), 0.8 + 0.5 * u, 0.85 + 0.45 * u, 1)
                b.grid(leaf, 4, 2, "FernLeaf", color=tip_c)
    # pastorały (zwinięte młode liście)
    for c in range(rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        h = size * rng.uniform(0.35, 0.6)
        base = Vector((math.cos(a), math.sin(a), 0)) * 0.05 * size
        pts = [base, base + Vector((0, 0, h * 0.6))]
        cx = base + Vector((math.cos(a) * 0.08 * size, math.sin(a) * 0.08 * size, h * 0.85))
        for k in range(12):
            ang = k / 12 * math.tau * 1.3
            rr = 0.09 * size * (1 - k / 14)
            pts.append(cx + Vector((math.cos(a) * math.cos(ang) * rr, math.sin(a) * math.cos(ang) * rr, math.sin(ang) * rr)))
        tube(b, pts, [0.02 * size * (1 - k / (len(pts) + 2)) for k in range(len(pts))], "FernLeaf", seg=6,
             color=lambda u, v, p: (0.9, 1.1, 1.0, 1))
    return b.finish(name)


def shrub(name, seed, size=1.2):
    """Krzew o ciemnych, okrągłych liściach i świecących bulwach na końcach gałązek."""
    rng = random.Random(seed)
    b = Builder([])
    for k in range(9):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a) * rng.uniform(0.3, 0.7), math.sin(a) * rng.uniform(0.3, 0.7), 1)).normalized()
        L = size * rng.uniform(0.6, 1.0)
        pts = [Vector((0, 0, 0))]
        q = Vector((0, 0, 0))
        for s in range(5):
            d = (d + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), -0.06))).normalized()
            q = q + d * L / 5
            pts.append(q.copy())
        tube(b, pts, [0.03 * size * (1 - s / 7) for s in range(6)], "Bark", seg=6,
             color=lambda u, v, p: (0.25, 0.18, 0.2, 1), cap_end=False)
        for s in range(2, 6):
            for _ in range(5):
                c = pts[s] + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 1))) * 0.12 * size
                n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.2, 1))).normalized()
                rr = size * rng.uniform(0.05, 0.09)
                m = Matrix.Translation(c) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
                shade = rng.uniform(0.6, 1.1)
                lathe(b, [(0.0, 0.01 * size), (rr * 0.7, 0.004 * size), (rr, -0.01 * size)], "ShrubLeaf", m, 10,
                      lambda u, v, p, s=shade: (s, s, s * 1.1, 1))
        tipm = Matrix.Translation(pts[-1]) @ Matrix.Scale(0.045 * size * rng.uniform(0.8, 1.4), 4)
        lathe(b, [(0.0, -1.0), (0.8, -0.6), (1.0, 0.0), (0.8, 0.6), (0.0, 1.0)], "BulbGlow", tipm, 10)
    return b.finish(name)


def rock(name, seed, size=1.2):
    """Głaz: pofałdowana bryła, mech na wierzchu (w kolorze wierzchołków)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    sx, sy, sz = rng.uniform(0.9, 1.4), rng.uniform(0.8, 1.2), rng.uniform(0.5, 0.8)
    s = rng.uniform(0, 100)
    for v in bm.verts:
        n = fractal(v.co * 1.4 + Vector((s, 0, 0)), 0.55, 2.0, 5)
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz)) * size * (1 + 0.22 * n)
        if v.co.z < -0.15 * size:
            v.co.z = -0.15 * size + (v.co.z + 0.15 * size) * 0.2
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            nz = loop.vert.normal.z
            moss = max(0.0, min(1.0, (nz - 0.35) / 0.3)) * (0.7 + 0.3 * pnoise(loop.vert.co * 2.0))
            rockc = Vector((0.22, 0.19, 0.27)) * (0.8 + 0.3 * pnoise(loop.vert.co * 4 + Vector((7, 0, 0))))
            mossc = Vector((0.1, 0.2, 0.14))
            c = rockc.lerp(mossc, moss)
            loop[col] = (c.x, c.y, c.z, 1)
            loop[uv].uv = (loop.vert.co.x, loop.vert.co.y)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.materials.append(M["Rock"])
    me.color_attributes.active_color = me.color_attributes["Col"]
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return o


def _bark_color(kind):
    def c(u, v, p):
        if kind == "birch":
            n = pnoise(Vector((v * 6, u * 30, 0.3)))
            dark = 1.0 if n > 0.35 else 0.0
            base = Vector((0.78, 0.76, 0.8)).lerp(Vector((0.12, 0.1, 0.13)), dark)
        else:
            n = pnoise(Vector((v * 8, u * 4, 1.7)))
            base = Vector((0.2, 0.15, 0.18)) * (0.8 + 0.3 * n)
            moss = max(0.0, min(1.0, (p.z - 0.2) * 2.0)) if p.z > 0 else 0.0
            base = base.lerp(Vector((0.1, 0.22, 0.13)), moss * 0.8)
        return (base.x, base.y, base.z, 1)
    return c


def log(name, seed, length=7.0, radius=0.7):
    """Zwalona kłoda z mchem na wierzchu i kępami świecących wachlarzy na boku."""
    rng = random.Random(seed)
    b = Builder([])
    pts = [Vector((-length / 2 + length * k / 8, rng.uniform(-0.15, 0.15), radius * 0.85 + rng.uniform(-0.05, 0.05)))
           for k in range(9)]
    radii = [radius * (1.0 - 0.15 * k / 8) for k in range(9)]

    def ccol(u, v, p):
        return _bark_color("log")(u, v, p)

    tube(b, pts, radii, "Bark", seg=18, color=ccol, cap_end=False, wobble=0.12, seed=seed)
    # postrzępione końce (pierścienie drewna)
    for end, r in ((pts[0], radii[0]), (pts[-1], radii[-1])):
        d = (pts[1] - pts[0]).normalized() * (-1 if end == pts[0] else 1)
        m = Matrix.Translation(end) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        lathe(b, [(r * 0.98, 0.0), (r * 0.6, 0.05 * r), (r * 0.2, -0.04 * r), (0.0, 0.02 * r)], "Bark", m, 18,
              lambda u, v, p: (0.45, 0.35, 0.3, 1),
              lambda p, u, v: p + Vector((0, 0, 0.15 * r * pnoise(p * 6.0))))
    # kępy świecących wachlarzy
    for k in range(3):
        t = rng.uniform(0.2, 0.8)
        fi = t * 8
        i = int(fi)
        p = pts[i].lerp(pts[i + 1], fi - i)
        side = rng.choice((-1, 1))
        rr = random.Random(seed * 10 + k)
        for j in range(5):
            R = rr.uniform(0.18, 0.35)
            fan = Fan(R, rr, cup=rr.uniform(0.15, 0.3), droop=0.1)
            ang = rr.uniform(-0.5, 0.9)
            base = p + Vector((rr.uniform(-0.4, 0.4), side * math.cos(ang) * radius * 0.95, math.sin(ang) * radius * 0.95))
            out = Vector((rr.uniform(-0.3, 0.3), side, 0.3 + math.sin(ang)))
            mat = Matrix.Translation(base) @ frame(out).to_4x4()
            fan_cap(b, fan, mat, "GhostTop", "GhostGill", nu=8, nv=20)
    return b.finish(name)


def snag(name, seed, height=8.0, radius=0.55):
    """Martwy, złamany pień (jasna kora z ciemnymi plamami) z piętrami pomarańczowych boczniaków."""
    rng = random.Random(seed)
    b = Builder([])
    lean = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0))
    bend = rng.uniform(0, math.tau)
    pts = [Vector((lean.x * height * (k / 10) ** 1.5 + 0.15 * math.sin(k * 0.7 + bend),
                   lean.y * height * (k / 10) ** 1.5 + 0.15 * math.cos(k * 0.6 + bend), height * k / 10)) for k in range(11)]
    radii = [radius * (1.35 - 0.45 * k / 10) for k in range(11)]
    radii[0] = radius * 1.8
    tube(b, pts, radii, "Birch", seg=18, color=_bark_color("birch"), cap_end=False, wobble=0.08, seed=seed)
    # złamany, poszarpany wierzchołek
    top = pts[-1]
    m = Matrix.Translation(top)
    lathe(b, [(radii[-1], 0.0), (radii[-1] * 0.5, 0.0), (0.0, 0.0)], "Bark", m, 18,
          lambda u, v, p: (0.4, 0.3, 0.28, 1),
          lambda p, u, v: p + Vector((0, 0, (0.6 * max(0.0, math.sin(v * math.tau * 3 + seed)) + 0.2 * pnoise(p * 4)) * radius * (1 - u * 0.5))))
    # korzenie
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(b, [d * radius * 0.6 + Vector((0, 0, 0.6)), d * radius * 1.4 + Vector((0, 0, 0.15)), d * radius * 2.4 + Vector((0, 0, -0.1))],
             [radius * 0.35, radius * 0.22, radius * 0.08], "Birch", seg=8, color=_bark_color("birch"))
    # boczniaki na pniu (piętra)
    for k in range(rng.randint(3, 4)):
        h = rng.uniform(1.2, height * 0.8)
        a = rng.uniform(0, math.tau)
        fi = h / height * 10
        i = min(int(fi), 9)
        r = radii[i] + (radii[i + 1] - radii[i]) * (fi - i)
        c = pts[i].lerp(pts[i + 1], fi - i)
        out = Vector((math.cos(a), math.sin(a), 0))
        # oyster_cluster rośnie w -Y: obróć tak, żeby -Y lokalne = out
        rot = Matrix.Rotation(math.atan2(out.y, out.x) + math.pi / 2, 4, "Z")
        oyster_cluster(name, seed * 7 + k, tiers=rng.randint(1, 2), size=rng.uniform(0.6, 0.9), b=b,
                       origin=Matrix.Translation(c + out * r * 0.85) @ rot, finish=False)
    return b.finish(name)


def shelfcap(name, seed=3):
    """Shelfcap: gruba półka-huba przyrośnięta do skały (rośnie w -Y), wierzch rdzawy z jaśniejszymi
    pierścieniami przyrostu, spód świeci bursztynem (pory). Promień 1 m, płaski wierzch: da się na nim stanąć."""
    rng = random.Random(seed)
    b = Builder([])
    fan = Fan(1.0, rng, span=math.radians(185), cup=0.04, ruffle=0.03, droop=0.18, lobe=0.06, th=0.26)
    mat = frame(Vector((0, -1, 0))).to_4x4()
    rings = lambda u, v, p: (0.8 + 0.35 * (0.5 + 0.5 * math.sin(u * 28)), 0.8 + 0.3 * (0.5 + 0.5 * math.sin(u * 28)), 0.85, 1)
    fan_cap(b, fan, mat, "ShelfTop", "ShelfGlow", rings, None, nu=14, nv=36)
    return b.finish(name)


def hammer_cap(name):
    """Nowy Hammer Cap: korzeń wrośnięty w ścianę (Root) i ramię (Arm): trzon wychodzi ze ściany (-Y)
    i zakrzywia się w górę, na końcu ciężki kapelusz-młot. Oś obrotu ramienia = oś X w punkcie (0, 0, 0)."""
    rng = random.Random(5)
    # Korzeń: guzowaty narośl na ścianie.
    br = Builder([])
    for k in range(6):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a) * 0.9, -0.25, math.sin(a) * 0.9))
        tube(br, [Vector((0, 0.35, 0)), d * 0.5 + Vector((0, 0.1, 0)), d * 1.1 + Vector((0, 0.25, 0))],
             [0.42, 0.25, 0.08], "HammerStem", seg=10, color=lambda u, v, p: (0.75, 0.7, 0.68, 1))
    m = Matrix.Translation((0, 0.15, 0)) @ Vector((0, -1, 0)).to_track_quat("Z", "Y").to_matrix().to_4x4()
    lathe(br, [(0.0, 0.45), (0.35, 0.38), (0.6, 0.15), (0.7, -0.2), (0.75, -0.4)], "HammerStem", m, 20,
          lambda u, v, p: (0.8, 0.74, 0.7, 1), lambda p, u, v: p * (1 + 0.1 * pnoise(p * 3)))
    root = br.finish(name + "_Root")
    # Ramię: trzon wychodzi ze ściany i zagina się w górę.
    ba = Builder([])
    pts = [Vector((0, 0.1, 0)), Vector((0, -0.9, 0.1)), Vector((0, -1.7, 0.5)), Vector((0, -2.2, 1.3)),
           Vector((0, -2.35, 2.2)), Vector((0, -2.3, 2.9))]
    radii = [0.5, 0.42, 0.38, 0.36, 0.35, 0.33]
    ribs = lambda u, v, p: (0.85 + 0.15 * math.sin(v * math.tau * 9), 0.8 + 0.15 * math.sin(v * math.tau * 9), 0.75, 1)
    tube(ba, pts, radii, "HammerStem", seg=16, color=ribs, cap_end=False, wobble=0.05)
    top = pts[-1]
    axis = (pts[-1] - pts[-2]).normalized()
    cm = Matrix.Translation(top) @ axis.to_track_quat("Z", "Y").to_matrix().to_4x4()

    def warts(p, u, v):
        n = pnoise(Vector((p.x * 3, p.y * 3, p.z * 3)))
        return p + Vector((0, 0, 0.06 * max(0.0, n)))

    cap_prof = [(0.0, 1.05), (0.6, 1.0), (1.15, 0.85), (1.5, 0.55), (1.65, 0.25), (1.62, 0.02)]
    wart_col = lambda u, v, p: (1.0, 1.0, 1.0, 1) if pnoise(p * 4.5) < 0.42 else (2.0, 1.8, 1.4, 1)
    lathe(ba, cap_prof, "HammerCap", cm, 36, wart_col, warts)
    lathe(ba, [(1.62, 0.02), (1.1, 0.12), (0.45, 0.22), (0.33, 0.25)], "HammerGlow", cm, 36, None, None, flip=True)
    arm = ba.finish(name + "_Arm")
    return root, arm


# ------------------------------------------------------------------ eksport


def export(objs, filename, names=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT, filename)
    kwargs = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    # Kolor wierzchołków po nazwie ("Col"): tryb ACTIVE brał domyślny, biały atrybut.
    for extra in ({"export_vertex_color": "NAME", "export_vertex_color_name": "Col"}, {"export_vertex_color": "ACTIVE"}, {}):
        try:
            bpy.ops.export_scene.gltf(**kwargs, **extra)
            break
        except TypeError:
            continue
    print("exported", path)


def build_all():
    props = {}
    props["ghost_wall_a"] = ghost_cluster("ghost_wall_a", 1, 10, 0.6, "wall")
    props["ghost_wall_b"] = ghost_cluster("ghost_wall_b", 2, 16, 1.1, "wall")
    props["ghost_ground"] = ghost_cluster("ghost_ground", 3, 9, 0.5, "ground")
    props["ruffle"] = ruffle_rosette("ruffle", 4, 1.1)
    props["oyster"] = oyster_cluster("oyster", 5, 3, 0.9)
    props["inkcap_a"] = inkcap_cluster("inkcap_a", 6, 5, 1.0)
    props["inkcap_b"] = inkcap_cluster("inkcap_b", 7, 3, 1.6)
    props["coral"] = coral("coral", 8, 1.8)
    props["fern_a"] = fern("fern_a", 9, 1.6, 12)
    props["fern_b"] = fern("fern_b", 10, 2.4, 9)
    props["shrub"] = shrub("shrub", 11, 1.6)
    props["rock_a"] = rock("rock_a", 12, 1.2)
    props["rock_b"] = rock("rock_b", 13, 2.0)
    props["log"] = log("log", 14, 7.0, 0.7)
    props["snag"] = snag("snag", 15, 8.0, 0.55)
    props["hammer_cap"] = hammer_cap("hammer_cap")
    props["shelfcap"] = shelfcap("shelfcap")
    return props


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
    bg.inputs["Color"].default_value = (0.06, 0.05, 0.1, 1)
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.lights.new("Key", "SUN"); sun.energy = 3.5; sun.color = (0.7, 0.7, 1.0)
    so = bpy.data.objects.new("Key", sun); scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), 0, math.radians(30))
    fill = bpy.data.lights.new("Fill", "AREA"); fill.energy = 3000; fill.size = 20; fill.color = (0.6, 0.55, 1.0)
    fo = bpy.data.objects.new("Fill", fill); scene.collection.objects.link(fo)
    fo.location = (0, -18, 10); fo.rotation_euler = (math.radians(60), 0, 0)
    try:
        tree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
        scene.compositing_node_group = tree
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = tree.nodes.new("CompositorNodeRLayers")
        gl = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        for sname, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.5), ("Size", 0.5)):
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


def sheet(props):
    """Podgląd: modele w dwóch rzędach na ciemnej ziemi, farmer dla skali, ściana dla modeli ściennych."""
    setup_render()
    gm = plain("SheetGround", (0.07, 0.065, 0.09), 0.95)
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    me = bpy.data.meshes.new("G"); bm.to_mesh(me); bm.free(); me.materials.append(gm)
    scene.collection.objects.link(bpy.data.objects.new("G", me))
    wm = plain("SheetWall", (0.18, 0.15, 0.22), 0.9)
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    me = bpy.data.meshes.new("Wall"); bm.to_mesh(me); bm.free(); me.materials.append(wm)
    wall = bpy.data.objects.new("Wall", me); scene.collection.objects.link(wall)
    wall.scale = (24, 1, 9); wall.location = (0, 6.5, 4.5)
    # ścienne na ścianie (płaszczyzna y = 6)
    wall_items = [("ghost_wall_a", (-8.5, 6.0, 2.4)), ("ghost_wall_b", (-4.5, 6.0, 4.0)), ("ruffle", (-0.8, 6.0, 2.2)),
                  ("oyster", (2.2, 6.0, 1.6)), ("hammer_cap", (7.0, 6.0, 3.2))]
    for key, loc in wall_items:
        objs = props[key] if isinstance(props[key], tuple) else (props[key],)
        for o in objs:
            o.location = loc
    ground_items = [("snag", (-10.5, 2.5, 0)), ("fern_b", (-7.5, 1.0, 0)), ("fern_a", (-5.0, -0.5, 0)),
                    ("inkcap_b", (-2.8, 1.2, 0)), ("inkcap_a", (-1.0, -0.8, 0)), ("coral", (0.6, 0.2, 0)),
                    ("shrub", (2.2, -0.6, 0)), ("ghost_ground", (3.4, -1.2, 0)), ("rock_a", (4.6, 0.8, 0)),
                    ("rock_b", (8.5, 1.5, 0)), ("log", (4.0, -3.5, 0))]
    for key, loc in ground_items:
        props[key].location = loc
    # farmer dla skali
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "player.glb"))
    for o in bpy.data.objects:
        if o not in before and o.parent is None:
            o.location = (-3.6, -2.2, 0)
            o.rotation_euler.z = math.radians(200)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shot(pos, target, lens, fname):
        cam.location = pos
        cam.data.lens = lens
        cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(SKETCH_DIR, fname)
        bpy.ops.render.render(write_still=True)
        print("rendered", fname)

    shot((0, -17, 5.5), (0, 1.5, 2.6), 26, "forest_props_1_all.png")
    shot((-6.5, -6.5, 2.4), (-5.5, 3, 2.2), 26, "forest_props_2_left.png")
    shot((4.5, -5.5, 2.6), (4.5, 3, 2.4), 26, "forest_props_3_right.png")


def main():
    props = build_all()
    os.makedirs(OUT, exist_ok=True)
    if DO_EXPORT:
        for key, obj in props.items():
            if isinstance(obj, tuple):
                root, arm = obj
                root.name = "Root"; arm.name = "Arm"
                export([root, arm], key + ".glb")
            else:
                export([obj], key + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "source", "forest_props.blend"))
    if DO_SHEET:
        sheet(props)


if __name__ == "__main__":  # import z innych skryptów (np. stage1_sketch.py) tylko bierze funkcje
    main()
