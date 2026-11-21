"""Szkic Bagien Mgieł (etap 1, "Kraina Pijawek"): bryły + rendery nastroju do akceptacji (to nie są modele do gry).

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/mist_marsh_sketch.py -- [widoki...]

Widoki: day, reading, overview, night, barrowfar, barrow, boss, mist (bez argumentów wszystkie).
Env SKETCH_FAST=1 = mały podgląd (szybko).
Wynik: art/source/sketches/marsh_*.png (+ marsh_8_mist_drift.gif), źródło art/source/mist_marsh.blend.
Korzysta z funkcji tools/blender/forest_props.py (Builder, tube, lathe, Fan).

Co jest w szkicu:
  - woda na poziomie Z = 0: płycizny (matowa tafla z rzęsą, widać błotne dno, trzciny) i głębia
    (gładkie, czarne lustro bez roślin) -> "czytanie bagna" z etapu 1,
  - kępy turzycy (wysepki), kanały głębokiej wody, głęboki staw,
  - Blackroot: czarne, martwe pnie z rozszerzoną nasadą, "kolanami" wystającymi z wody i brodami mchu,
  - Weeping Mire: obca wierzba, z korony zwisają pasma liści zakończone miodowo świecącymi kroplami,
  - lilie wodne, pałki, kłody, bańki gazu, pijawki w płyciźnie,
  - mgła leżąca na wodzie jak koc (objętość przy ziemi), ogniki i świetliki,
  - Kościany Kurhan (mini-biom): suche wzgórze z żebrami i czaszką olbrzyma, wrzosy, złota trawa, sęp,
  - arena Bogmaw Elder: błotne jezioro, ślady wleczenia, obgryzione pnie, oczy i grzbiet bossa nad błotem.
"""
import bpy, bmesh, math, os, random, sys, subprocess, shutil
from mathutils import Vector, Matrix
from mathutils.noise import noise as pnoise, fractal

sys.path.insert(0, os.path.dirname(__file__))
import forest_props as fp  # noqa: E402  (czyści scenę; bierzemy Builder, tube, lathe, Fan)

ROOT = fp.ROOT
SKETCH_DIR = fp.SKETCH_DIR
FAST = fp.FAST
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ALL_VIEWS = ["day", "reading", "overview", "night", "barrowfar", "barrow", "boss", "mist"]
VIEWS = [a for a in ARGV if a in ALL_VIEWS] or ALL_VIEWS
scene = bpy.context.scene
M = fp.M
rng = random.Random(11)

SIZE = 200.0          # bok mapy szkicu (m)
WATER = 0.0           # poziom wody

# ---------------------------------------------------------------- układ (ręcznie, pod kadry)

CHANNEL = [(-100, 4), (-70, 11), (-42, 5), (-18, 12), (6, 9.5), (30, 13), (52, 20), (75, 12), (100, 18)]
CHANNEL_B = [(6, 9.5), (13, 0), (19, -8)]                 # odnoga do stawu
CHANNEL_C = [(-42, 5), (-45, -10), (-46, -24)]            # odnoga do areny
POOL = (25.0, -13.0, 10.0, -3.0)                          # głęboki staw (x, y, r, dno)
BARROW = Vector((52.0, 55.0))                             # Kościany Kurhan
BARROW_R, BARROW_H = 24.0, 10.0
SPINE = (Vector((42.0, 63.0)), Vector((62.0, 50.0)))      # kręgosłup olbrzyma
ARENA = Vector((-48.0, -42.0))                            # błotne jezioro Bogmawa
ARENA_R = 16.0
GROOVES = [[(-27, -21), (-35, -30), (-41.5, -36)], [(-28.6, -23.4), (-36.4, -31.6), (-42.6, -37.2)],
           [(-25, -24), (-33, -33.5), (-40, -39)]]
P_DAY = Vector((0.0, -2.0))
P_READ = Vector((11.5, -22.0))
TUSSOCK_PATH = [(12.5, -19.0), (13.6, -16.3), (13.0, -13.4), (14.5, -10.7), (14.0, -7.8), (15.5, -5.0)]
_SD = (SPINE[1] - SPINE[0]).normalized()
# kamery kadrów: dzień/noc, czytanie bagna, kurhan z bliska (wzdłuż kręgosłupa), kurhan z daleka, arena
CAMS = [Vector(c) for c in ((2.2, -10.5, 2.6), (8.5, -30.0, 2.3), (*(SPINE[1] + _SD * 6.0), 2.4), (22.0, 26.0, 2.5),
                            (-28.5, -23.5, 3.4))]
PLAYERS = [P_DAY, P_READ, SPINE[1] + _SD * 2.5, Vector((24.5, 29.5)), Vector((-33.0, -29.0))]
TARGETS = [Vector((-3, 25)), Vector((19, -9)), SPINE[0], BARROW, ARENA]


def clamp01(x):
    return 0.0 if x < 0 else (1.0 if x > 1 else x)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(e0, e1, x):
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = clamp01(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
    return math.hypot(px - ax - dx * t, py - ay - dy * t)


def poly_dist(px, py, pts):
    return min(seg_dist(px, py, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def carve(h, d, half, depth):
    """Kanał: dno `depth` w środku, łagodny brzeg do 1,5 szerokości."""
    k = smooth(half * 0.35, half * 1.5, d)
    return min(h, depth + (h - depth) * k)


def groove(x, y):
    g = 0.0
    for line in GROOVES:
        d = poly_dist(x, y, line)
        g = max(g, max(0.0, 1.0 - d / 0.6))
    return g


def H(x, y):
    """Wysokość dna/terenu (woda na Z = 0)."""
    n = fractal(Vector((x * 0.028 + 7.3, y * 0.028 + 1.9, 0.5)), 0.6, 2.0, 4)
    h = -0.3 + 0.42 * n
    t = pnoise(Vector((x * 0.19 + 3.1, y * 0.19 - 2.2, 9.1)))
    h += 0.4 * max(0.0, t) ** 1.6                                   # kępy
    # płycizna przed graczem (kadr dnia i nocy)
    m = smooth(-10, -7, x) * (1 - smooth(7, 10, x)) * smooth(-0.5, 1.5, y) * (1 - smooth(6, 8.5, y))
    h = lerp(h, -0.28 + 0.06 * t, m)
    # płycizna "czytania bagna" (kadr 2)
    m = smooth(5.0, 7.5, x) * (1 - smooth(15.0, 17.0, x)) * smooth(-31, -28, y) * (1 - smooth(-4, -1, y))
    h = lerp(h, -0.24 + 0.05 * t, m)
    h = carve(h, poly_dist(x, y, CHANNEL), 4.2, -2.8)
    h = carve(h, poly_dist(x, y, CHANNEL_B), 2.6, -2.0)
    h = carve(h, poly_dist(x, y, CHANNEL_C), 2.4, -1.8)
    dp = math.hypot(x - POOL[0], y - POOL[1])
    h = min(h, POOL[3] + (h - POOL[3]) * smooth(POOL[2] * 0.45, POOL[2] * 1.12, dp))
    # ścieżka kęp przez płyciznę
    for (cx, cy) in TUSSOCK_PATH:
        d = math.hypot(x - cx, y - cy)
        if d < 1.4:
            h = max(h, 0.26 * (1 - (d / 1.4) ** 2) + 0.03 * t - 0.02)
    # kępa pod graczem (dzień/noc) i za nim
    d = math.hypot(x - P_DAY.x, y - P_DAY.y)
    if d < 4.0:
        h = max(h, 0.4 * (1 - (d / 4.0) ** 2) + 0.04 * t)
    d = math.hypot(x - 3.0, y + 9.0)
    if d < 7.0:
        h = max(h, 0.5 * (1 - (d / 7.0) ** 2))
    # Kościany Kurhan
    dk = math.hypot(x - BARROW.x, y - BARROW.y)
    if dk < BARROW_R * 1.05:
        dome = BARROW_H * max(0.0, 1 - (dk / BARROW_R) ** 2) ** 1.35
        dome += 0.45 * fractal(Vector((x * 0.12, y * 0.12, 4.4)), 0.5, 2.0, 3) * min(1.0, dome)
        h = max(h, dome - 0.15)
    # arena: brzeg z błota i misa jeziora
    da = math.hypot(x - ARENA.x, y - ARENA.y)
    h = lerp(h, 0.2 + 0.05 * t, 1 - smooth(ARENA_R + 2.5, ARENA_R + 10, da))
    if da < ARENA_R:
        h = min(h, -1.4 * (1 - (da / ARENA_R) ** 2) ** 0.6 - 0.02)
    g = groove(x, y)
    if g > 0 and h > -0.3:
        h -= 0.24 * g
    return h


# ---------------------------------------------------------------- materiały

GLOW = []  # (socket, wartość w dzień, w nocy)


def reg(sock, day, night):
    sock.default_value = day
    GLOW.append((sock, day, night))


def _bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def sk(node, name, out=False):
    """Gniazdo po nazwie, ale tylko aktywne (Mix ma po kilka "A"/"B"/"Result" dla różnych typów)."""
    coll = node.outputs if out else node.inputs
    for s in coll:
        if s.name == name and getattr(s, "enabled", True) and not getattr(s, "is_unavailable", False):
            return s
    return coll[name]


def mix_rgb(nt, a, b, fac):
    """a, b: kolor (krotka) albo gniazdo; fac: liczba albo gniazdo."""
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    for key, val in (("A", a), ("B", b)):
        if isinstance(val, tuple):
            sk(mx, key).default_value = (*val, 1) if len(val) == 3 else val
        else:
            nt.links.new(val, sk(mx, key))
    if isinstance(fac, (int, float)):
        sk(mx, "Factor").default_value = fac
    else:
        nt.links.new(fac, sk(mx, "Factor"))
    return sk(mx, "Result", True)


def math_node(nt, op, a, b=None):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def map_range(nt, val, fmin, fmax, tmin, tmax):
    n = nt.nodes.new("ShaderNodeMapRange")
    n.inputs["From Min"].default_value = fmin
    n.inputs["From Max"].default_value = fmax
    n.inputs["To Min"].default_value = tmin
    n.inputs["To Max"].default_value = tmax
    nt.links.new(val, n.inputs["Value"])
    return n.outputs["Result"]


def vc_mat(name, color=(1, 1, 1), rough=0.7, glow=None, glow_day=0.0, glow_night=0.0):
    """Kolor bazowy x kolor wierzchołków "Col"; alfa koloru = maska świecenia."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    sk(mx, "Factor").default_value = 1.0
    sk(mx, "A").default_value = (*color, 1)
    nt.links.new(attr.outputs["Color"], sk(mx, "B"))
    nt.links.new(sk(mx, "Result", True), b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if glow:
        b.inputs["Emission Color"].default_value = (*glow, 1)
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        nt.links.new(attr.outputs["Alpha"], mul.inputs[0])
        reg(mul.inputs[1], glow_day, glow_night)
        nt.links.new(mul.outputs[0], b.inputs["Emission Strength"])
    M[name] = m
    return m


def emit_mat(name, color, day, night):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    reg(em.inputs["Strength"], day, night)
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    M[name] = m
    return m


ANIM = {}  # wartości animowane w GIF-ie mgły (przesunięcie szumu)


def water_mat():
    """Woda: R koloru wierzchołków = głębokość (0 płytko .. 1 głęboko), G = rzęsa/kożuch.
    Płytko: matowa, półprzezroczysta (widać błoto), drobne zmarszczki. Głęboko: czarne lustro."""
    m = bpy.data.materials.new("Water")
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(attr.outputs["Color"], sep.inputs[0])
    deep, scum = sep.outputs["Red"], sep.outputs["Green"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # drobny szum rzęsy (kropki), żeby kożuch nie był gładką plamą
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 9.0
    nz.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    speck = map_range(nt, nz.outputs["Fac"], 0.42, 0.62, 0.0, 1.0)
    scum_m = math_node(nt, "MULTIPLY", scum, speck)
    scum_m = math_node(nt, "MINIMUM", math_node(nt, "MULTIPLY", scum_m, 1.6), 1.0)
    col = mix_rgb(nt, (0.075, 0.07, 0.04), (0.006, 0.012, 0.01), deep)
    col = mix_rgb(nt, col, (0.2, 0.3, 0.05), scum_m)
    nt.links.new(col, b.inputs["Base Color"])
    rough = map_range(nt, deep, 0.0, 1.0, 0.2, 0.012)
    rough = math_node(nt, "MAXIMUM", rough, math_node(nt, "MULTIPLY", scum_m, 0.8))
    nt.links.new(rough, b.inputs["Roughness"])
    alpha = map_range(nt, deep, 0.0, 0.7, 0.5, 1.0)
    alpha = math_node(nt, "MAXIMUM", alpha, scum_m)
    nt.links.new(alpha, b.inputs["Alpha"])
    b.inputs["Emission Color"].default_value = (0.3, 1.0, 0.65, 1)    # nocą świecące glony na kożuchu
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    nt.links.new(math_node(nt, "MULTIPLY", scum, map_range(nt, nz.outputs["Fac"], 0.5, 0.7, 0.0, 1.0)), em.inputs[0])
    reg(em.inputs[1], 0.0, 0.9)
    nt.links.new(em.outputs[0], b.inputs["Emission Strength"])
    # zmarszczki tylko na płyciźnie
    rip = nt.nodes.new("ShaderNodeTexNoise")
    rip.noise_dimensions = "4D"
    rip.inputs["Scale"].default_value = 2.2
    rip.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], rip.inputs["Vector"])
    ANIM["water_w"] = rip.inputs["W"]
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.02
    nt.links.new(map_range(nt, deep, 0.0, 0.6, 0.35, 0.0), bump.inputs["Strength"])
    nt.links.new(rip.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    M["Water"] = m
    return m


def mud_mat():
    m = bpy.data.materials.new("MudLake")
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.35
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    col = mix_rgb(nt, (0.05, 0.04, 0.025), (0.12, 0.1, 0.055), nz.outputs["Fac"])
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(map_range(nt, nz.outputs["Fac"], 0.4, 0.6, 0.18, 0.55), b.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    bump.inputs["Distance"].default_value = 0.15
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    M["MudLake"] = m
    return m


def ground_mat():
    m = vc_mat("Ground", (1, 1, 1), 0.85)
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nt.links.new(map_range(nt, sep.outputs["Z"], 0.02, 0.35, 0.22, 0.88), b.inputs["Roughness"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.0
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


def fog_mats():
    """Mgła przy wodzie (obiekt-objętość): gęsta przy Z = 0, znika ok. 3 m wyżej, plamy z szumu."""
    m = bpy.data.materials.new("GroundFog")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mp = nt.nodes.new("ShaderNodeMapping")
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    ANIM["fog_loc"] = mp.inputs["Location"]
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.noise_dimensions = "4D"
    nz.inputs["Scale"].default_value = 0.045
    nz.inputs["Detail"].default_value = 3.0
    nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    ANIM["fog_w"] = nz.inputs["W"]
    # koc: gęsty do ok. 1 m nad wodą, wierzch faluje (0,9-2,5 m) razem z plamami szumu
    zmod = math_node(nt, "SUBTRACT", sep.outputs["Z"], map_range(nt, nz.outputs["Fac"], 0.3, 0.7, -0.7, 0.7))
    layer = map_range(nt, zmod, 1.8, 0.3, 0.0, 1.0)
    layer = math_node(nt, "POWER", layer, 1.3)
    patch = map_range(nt, nz.outputs["Fac"], 0.32, 0.68, 0.15, 1.2)
    dens = math_node(nt, "MULTIPLY", layer, patch)
    dm = nt.nodes.new("ShaderNodeMath")
    dm.operation = "MULTIPLY"
    nt.links.new(dens, dm.inputs[0])
    nt.links.new(dm.outputs[0], vol.inputs["Density"])
    # mleczna poświata mgły: świecenie proporcjonalne do gęstości (nad warstwą nic nie świeci)
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    nt.links.new(dm.outputs[0], em.inputs[0])
    reg(em.inputs[1], 0.15, 0.1)
    nt.links.new(em.outputs[0], vol.inputs["Emission Strength"])
    return m, vol, dm.inputs[1]


def haze_mat():
    """Ogólna mgiełka (obiekt zamiast objętości świata: objętość świata w EEVEE zasłania niebo i światło otoczenia)."""
    m = bpy.data.materials.new("Haze")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    return m, vol


M_WATER = water_mat()
M_MUD = mud_mat()
M_GROUND = ground_mat()
M_FOG, FOG_VOL, FOG_DENS = fog_mats()
M_HAZE, HAZE_VOL = haze_mat()
vc_mat("Sedge", rough=0.65)
vc_mat("Reed", rough=0.55)
vc_mat("Cattail", (0.32, 0.19, 0.1), 0.85)
vc_mat("Blackbark", rough=0.42)
vc_mat("MossBeard", (0.46, 0.5, 0.36), 0.85, (0.45, 1.0, 0.7), 0.0, 0.7)
vc_mat("WeeperBark", rough=0.6)
vc_mat("WeeperFrond", rough=0.5)
vc_mat("HoneyBead", (0.95, 0.62, 0.22), 0.3, (1.0, 0.6, 0.16), 0.15, 7.0)
vc_mat("LilyPad", rough=0.28)
vc_mat("LilyFlower", rough=0.5, glow=(1.0, 0.72, 0.3), glow_day=0.05, glow_night=4.0)
vc_mat("Bracket", (0.55, 0.6, 0.55), 0.55, (0.3, 1.0, 0.8), 0.08, 4.0)
vc_mat("BracketGill", (0.4, 0.55, 0.5), 0.6, (0.3, 1.0, 0.8), 0.3, 6.0)
vc_mat("Leech", rough=0.22, glow=(1.0, 0.3, 0.1), glow_day=0.1, glow_night=2.0)
vc_mat("Bone", rough=0.7)
vc_mat("Heather", rough=0.85)
vc_mat("Bubble", (0.35, 0.36, 0.28), 0.04)
vc_mat("Bogmaw", rough=0.3)
vc_mat("BogmawEye", (1.0, 0.7, 0.2), 0.2, (1.0, 0.55, 0.08), 5.0, 9.0)
vc_mat("Vulture", rough=0.85)
vc_mat("Stump", rough=0.6)
vc_mat("Honeybell", rough=0.5, glow=(1.0, 0.65, 0.2), glow_day=0.1, glow_night=5.0)
emit_mat("Firefly", (0.75, 1.0, 0.45), 0.0, 9.0)
emit_mat("Wisp", (1.0, 0.68, 0.28), 0.6, 30.0)


# ---------------------------------------------------------------- pomocnicze

def link(obj):
    scene.collection.objects.link(obj)
    return obj


def mesh_from_bm(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    if "Col" in me.color_attributes:
        me.color_attributes.active_color = me.color_attributes["Col"]
    return link(bpy.data.objects.new(name, me))


def near_view(x, y, r=2.6):
    """Nie zasłaniaj kadrów: nic tuż przy kamerze, przy graczu i na linii kamera -> gracz."""
    p = Vector((x, y))
    if any((p - c.xy).length < r for c in CAMS) or any((p - q).length < 1.3 for q in PLAYERS):
        return True
    return any(seg_dist(x, y, tuple(c.xy), tuple(q)) < 1.4 for c, q in zip(CAMS, PLAYERS))


def in_sightline(x, y, r=3.5):
    """Duże obiekty (drzewa): poza linią kamera -> cel ujęcia."""
    return any(seg_dist(x, y, tuple(c.xy), tuple(t)) < r for c, t in zip(CAMS, TARGETS))


def bez(p0, p1, p2, u):
    return p0 * (1 - u) ** 2 + p1 * (2 * u * (1 - u)) + p2 * (u * u)


def ribbon(b, path, width, side, nu, mat, color):
    """Pasek (liść, źdźbło): path(u) -> punkt, width(u) -> szerokość, side -> wektor w poprzek."""
    def pos(u, v):
        return path(u) + side * ((v - 0.5) * width(u))
    b.grid(pos, nu, 1, mat, color=color)


def blob(b, c, r, mat, color, seg=8, squash=1.0):
    """Mała kula (kropla, oko, guz) z lathe."""
    prof = [(0.0, -r * squash), (r * 0.7, -r * 0.7 * squash), (r, 0.0), (r * 0.7, r * 0.7 * squash), (0.0, r * squash)]
    fp.lathe(b, prof, mat, Matrix.Translation(c), seg, color)


def const(c, a=0.0):
    return lambda u, v, p: (c[0], c[1], c[2], a)


# ---------------------------------------------------------------- teren i woda

def grid_mesh(name, n, zfun, colfun, material):
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    step = SIZE / n
    verts = []
    cache = []
    for i in range(n + 1):
        row = []
        for j in range(n + 1):
            x, y = -SIZE / 2 + i * step, -SIZE / 2 + j * step
            z = zfun(x, y)
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    bm.verts.index_update()
    colors = [colfun(v.co) for v in bm.verts]
    for i in range(n):
        for j in range(n):
            f = bm.faces.new((verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1]))
            f.smooth = True
            for loop in f.loops:
                loop[col] = colors[loop.vert.index]
    return mesh_from_bm(name, bm, material)


def ground_color(p):
    x, y, z = p.x, p.y, p.z
    n = pnoise(Vector((x * 0.15, y * 0.15, 2.2)))
    n2 = pnoise(Vector((x * 0.6, y * 0.6, 5.5)))
    dk = math.hypot(x - BARROW.x, y - BARROW.y)
    da = math.hypot(x - ARENA.x, y - ARENA.y)
    if z < -0.05:                                  # dno pod wodą: błoto, ciemniejsze w głębi
        c = Vector((0.11, 0.09, 0.05)).lerp(Vector((0.03, 0.03, 0.02)), clamp01(-z / 1.5))
        c = c.lerp(Vector((0.09, 0.12, 0.05)), 0.3 * max(0.0, n))
    elif z < 0.12 or da < ARENA_R + 4:            # mokry brzeg
        c = Vector((0.06, 0.05, 0.035)) * (0.85 + 0.3 * n2)
        if groove(x, y) > 0.2:
            c *= 0.6
    elif dk < BARROW_R * 0.9 and z > 1.0:          # kurhan: sucha złota trawa, wrzos, goła ziemia
        heather = smooth(0.05, 0.3, pnoise(Vector((x * 0.22, y * 0.22, 7.7))))
        c = Vector((0.42, 0.36, 0.17)).lerp(Vector((0.3, 0.13, 0.27)), heather)
        c = c.lerp(Vector((0.25, 0.2, 0.13)), 0.4 * max(0.0, n2))
    else:                                         # kępy: mech i turzyca, plamy czerwonego torfowca
        c = Vector((0.11, 0.15, 0.06)).lerp(Vector((0.3, 0.29, 0.13)), clamp01(0.5 + n))
        if n2 > 0.35:
            c = c.lerp(Vector((0.32, 0.09, 0.06)), clamp01((n2 - 0.35) * 3) * 0.75)
    return (c.x, c.y, c.z, 0.0)


def water_color(p):
    x, y = p.x, p.y
    h = H(x, y)
    deep = clamp01(-h / 1.1)
    s = smooth(0.0, 0.4, pnoise(Vector((x * 0.09, y * 0.09, 3.3))))
    scum = s * (1 - deep) ** 1.6
    scum = max(scum, smooth(-0.35, -0.05, h) * 0.75 * (1 - deep))   # kożuch przy brzegach
    if poly_dist(x, y, CHANNEL) < 3.0 or math.hypot(x - POOL[0], y - POOL[1]) < POOL[2] * 0.8:
        scum = 0.0                                                    # głębia zawsze gładka
    return (deep, scum, 0.0, 1.0)


def terrain():
    grid_mesh("Ground", 125 if FAST else 250, H, ground_color, M_GROUND)
    grid_mesh("Water", 100 if FAST else 200, lambda x, y: WATER, water_color, M_WATER)
    # błotne jezioro areny (nad wodą, żeby ją zakryć)
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=ARENA_R + 0.6)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    for v in bm.verts:
        v.co.z = 0.035 + 0.05 * pnoise(Vector((v.co.x * 0.3, v.co.y * 0.3, 1.0)))
    o = mesh_from_bm("MudLake", bm, M_MUD)
    o.location = (ARENA.x, ARENA.y, 0)


def fog():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, 1.25)) @ Matrix.Diagonal((SIZE * 1.1, SIZE * 1.1, 3.5, 1)))
    o = mesh_from_bm("GroundFog", bm, M_FOG)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, 34.0)) @ Matrix.Diagonal((SIZE * 1.3, SIZE * 1.3, 70.0, 1)))
    h = mesh_from_bm("Haze", bm, M_HAZE)
    return o, h


# ---------------------------------------------------------------- rośliny

def sedge_tuft(b, x, y, z, r, size, dry=False):
    n = r.randint(12, 20)
    tip_red = r.random() < 0.25
    for _ in range(n):
        a = r.uniform(0, math.tau)
        h = size * r.uniform(0.5, 1.0)
        bend = r.uniform(0.3, 0.9)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        base = Vector((x + d.x * 0.05 * size, y + d.y * 0.05 * size, z - 0.04))

        def path(u, base=base, d=d, h=h, bend=bend):
            return base + d * (bend * h * u * u + 0.07 * size * u) + Vector((0, 0, h * u * (1 - 0.4 * bend * u)))

        if dry:
            c0, c1 = Vector((0.3, 0.24, 0.1)), Vector((0.78, 0.66, 0.36))
        else:
            c0, c1 = Vector((0.06, 0.1, 0.035)), (Vector((0.5, 0.2, 0.08)) if tip_red else Vector((0.42, 0.4, 0.16)))

        def col(u, v, p, c0=c0, c1=c1):
            c = c0.lerp(c1, u ** 0.8)
            return (c.x, c.y, c.z, 0.0)

        ribbon(b, path, lambda u: 0.032 * size * (1 - u) ** 0.7 + 0.003, side, 4, "Sedge", col)


def reed_clump(b, x, y, r, size, wind):
    zb = H(x, y) - 0.05
    n = r.randint(18, 34)
    for _ in range(n):
        a = r.uniform(0, math.tau)
        rr = 0.75 * size * math.sqrt(r.random())
        px, py = x + math.cos(a) * rr, y + math.sin(a) * rr
        h = r.uniform(1.4, 2.6) * size - zb
        lean = wind + r.uniform(-0.5, 0.5)
        d = Vector((math.cos(lean), math.sin(lean), 0))
        bend = r.uniform(0.04, 0.22)
        base = Vector((px, py, zb))
        side = Vector((-d.y, d.x, 0)).lerp(Vector((0, 0, 0)), 0.0)
        twist = r.uniform(-0.6, 0.6)
        side = (side * math.cos(twist) + d * math.sin(twist)).normalized()

        def path(u, base=base, d=d, h=h, bend=bend):
            return base + d * (bend * h * u * u) + Vector((0, 0, h * u))

        def col(u, v, p):
            if p.z < 0.0:
                c = Vector((0.05, 0.06, 0.03))
            else:
                c = Vector((0.12, 0.2, 0.07)).lerp(Vector((0.58, 0.5, 0.27)), clamp01(u * 1.3 - 0.25))
            return (c.x, c.y, c.z, 0.0)

        ribbon(b, path, lambda u: 0.03 * (1 - u) ** 0.5 + 0.002, side, 5, "Reed", col)
    for _ in range(r.randint(0, 5)):                      # pałki
        a = r.uniform(0, math.tau)
        rr = 0.6 * size * math.sqrt(r.random())
        px, py = x + math.cos(a) * rr, y + math.sin(a) * rr
        h = r.uniform(1.6, 2.4) * size - zb
        lean = Vector((math.cos(wind), math.sin(wind), 0)) * r.uniform(0.05, 0.2)
        p0 = Vector((px, py, zb))
        p1 = p0 + lean * h * 0.5 + Vector((0, 0, h * 0.75))
        p2 = p0 + lean * h + Vector((0, 0, h))
        fp.tube(b, [p0, p1], [0.012, 0.01], "Reed", seg=5, color=const((0.2, 0.25, 0.1)), cap_end=False)
        head0 = p1
        head1 = p1 + (p2 - p1) * 0.35
        fp.tube(b, [head0, head0.lerp(head1, 0.5), head1], [0.04, 0.048, 0.035], "Cattail", seg=8,
                color=const((1, 1, 1)))
        fp.tube(b, [head1, p2], [0.008, 0.003], "Reed", seg=4, color=const((0.4, 0.35, 0.2)))


def lily(b, x, y, R, r):
    notch = 0.32
    a0 = r.uniform(0, math.tau)
    wob = r.uniform(0, 10)

    def pos(u, v):
        a = a0 + notch / 2 + v * (math.tau - notch)
        rr = R * (0.02 + 0.98 * u) * (1 + 0.04 * math.sin(a * 5 + wob))
        z = 0.012 + 0.05 * R * max(0.0, (u - 0.88) / 0.12)
        return Vector((x + math.cos(a) * rr, y + math.sin(a) * rr, z))

    decay = r.random()

    def col(u, v, p):
        c = Vector((0.1, 0.2, 0.05)).lerp(Vector((0.36, 0.3, 0.08)), u ** 3)
        if math.sin(v * 70) > 0.93:
            c = c * 1.4
        if pnoise(p * 1.8) > 0.4 - 0.3 * decay:
            c = c.lerp(Vector((0.25, 0.12, 0.05)), 0.7)
        return (c.x, c.y, c.z, 0.0)

    b.grid(pos, 3, 20, "LilyPad", color=col)
    if r.random() < 0.22:
        s = r.uniform(0.6, 1.0)
        prof = [(0.0, 0.02), (0.05 * s, 0.03), (0.12 * s, 0.07), (0.17 * s, 0.15), (0.15 * s, 0.22)]

        def deform(p, u, v):
            if u > 0.3:
                k = 0.5 + 0.5 * abs(math.cos(v * math.tau * 4))
                p = Vector((p.x * k, p.y * k, p.z))
            return p

        def fcol(u, v, p):
            c = Vector((1.0, 0.75, 0.35)).lerp(Vector((0.95, 0.82, 0.86)), smooth(0.2, 0.6, u))
            return (c.x, c.y, c.z, 1.0 - smooth(0.15, 0.5, u))

        fp.lathe(b, prof, "LilyFlower", Matrix.Translation((x + r.uniform(-0.2, 0.2) * R, y + r.uniform(-0.2, 0.2) * R, 0.0)),
                 16, fcol, deform)


def honeybell(b, x, y, z, r):
    """Kwiat-dzwonek na kępie: cienka łodyga, zwisający bursztynowy dzwonek (nocą świeci: "miód" bagna)."""
    h = r.uniform(0.35, 0.8)
    p0 = Vector((x, y, z - 0.02))
    lean = Vector((r.uniform(-1, 1), r.uniform(-1, 1), 0)).normalized() * 0.18
    top = p0 + Vector((0, 0, h)) + lean
    fp.tube(b, [p0, p0 + Vector((0, 0, h * 0.7)), top], [0.008, 0.007, 0.005], "Sedge", seg=4,
            color=const((0.15, 0.22, 0.07)), cap_end=False)
    bell = top + lean * 0.4 - Vector((0, 0, 0.06))
    prof = [(0.0, 0.0), (0.02, -0.005), (0.045, -0.05), (0.06, -0.1), (0.05, -0.11)]
    fp.lathe(b, prof, "Honeybell", Matrix.Translation(bell), 10,
             lambda u, v, p: (0.95, 0.6, 0.2, 0.4 + 0.6 * u))


def scatter_plants():
    tufts = fp.Builder([])
    reeds = fp.Builder([])
    lilies = fp.Builder([])
    flowers = fp.Builder([])
    wind = math.radians(35)
    n_try = 5000 if FAST else 16000
    for _ in range(n_try):
        x, y = rng.uniform(-98, 98), rng.uniform(-98, 98)
        if near_view(x, y):
            continue
        h = H(x, y)
        dk = math.hypot(x - BARROW.x, y - BARROW.y)
        da = math.hypot(x - ARENA.x, y - ARENA.y)
        if da < ARENA_R + 3:
            continue
        clump = pnoise(Vector((x * 0.07, y * 0.07, 1.3)))
        if 0.06 < h < 2.5 and dk > BARROW_R * 0.75:
            if rng.random() < 0.55:
                sedge_tuft(tufts, x, y, h, rng, rng.uniform(0.5, 1.1))
                if rng.random() < 0.12:
                    honeybell(flowers, x + rng.uniform(-0.4, 0.4), y + rng.uniform(-0.4, 0.4), h, rng)
        elif h > 0.8 and dk <= BARROW_R * 0.75:
            if rng.random() < 0.35:
                sedge_tuft(tufts, x, y, h, rng, rng.uniform(0.4, 0.9), dry=True)
        elif -0.7 < h <= 0.06 and clump > 0.05:
            if rng.random() < 0.5:
                reed_clump(reeds, x, y, rng, rng.uniform(0.7, 1.15), wind)
        elif -1.6 < h < -0.25 and clump < -0.1:
            if rng.random() < 0.4:
                for _k in range(rng.randint(2, 6)):
                    lily(lilies, x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), rng.uniform(0.25, 0.9), rng)
    # kadry: kępy z bliska (pod nogami gracza dzień/noc i na ścieżce kęp)
    for (cx, cy, rad, cnt) in [(0, -2, 3.0, 26), (3, -8, 5.0, 30), (13.5, -12, 7.0, 40)]:
        for _ in range(cnt):
            a, d = rng.uniform(0, math.tau), rad * math.sqrt(rng.random())
            x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
            h = H(x, y)
            if h > 0.04 and not near_view(x, y, 1.6):
                sedge_tuft(tufts, x, y, h, rng, rng.uniform(0.45, 0.9))
                if rng.random() < 0.2:
                    honeybell(flowers, x, y, h, rng)
    for (x, y, s) in [(-6.5, 3.5, 1.0), (6.0, 2.5, 1.1), (-4.0, 5.8, 0.9), (8.0, 5.5, 1.0), (7.0, -16.0, 1.0),
                      (6.5, -10.0, 1.1), (8.0, -5.0, 0.9), (6.0, -24.5, 1.0)]:
        reed_clump(reeds, x, y, rng, s, wind)
    for (x, y, R) in [(-2.5, 6.2, 0.8), (-1.2, 7.0, 0.55), (3.0, 6.5, 0.7), (16.5, -17.0, 0.6), (17.0, -9.0, 0.8),
                      (17.6, -13.5, 0.5), (1.0, 5.2, 0.45)]:
        lily(lilies, x, y, R, rng)
    tufts.finish("SedgeTufts")
    reeds.finish("Reeds")
    lilies.finish("Lilies")
    flowers.finish("Honeybells")


# ---------------------------------------------------------------- drzewa

def bark_col(u, v, p):
    n = pnoise(Vector((v * 6.0, u * 9.0, 0.7)))
    c = Vector((0.05, 0.045, 0.042)) * (0.75 + 0.5 * max(0.0, n))
    lich = pnoise(p * 0.9 + Vector((3.0, 1.0, 2.0)))
    if lich > 0.32:
        c = c.lerp(Vector((0.3, 0.31, 0.26)), min(1.0, (lich - 0.32) * 3) * 0.6)
    if p.z < 1.0:
        c = c.lerp(Vector((0.07, 0.1, 0.045)), clamp01((1.0 - p.z) / 1.0) * 0.75)
    return (c.x, c.y, c.z, 0.0)


def beard_col(u, v, p):
    c = Vector((0.55, 0.58, 0.42)).lerp(Vector((0.35, 0.4, 0.28)), u)
    return (c.x, c.y, c.z, 0.15 + 0.5 * u)


def beards_from(b, p, r, count, max_len):
    for _ in range(count):
        q = p + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(-0.1, 0.05)))
        L = min(max_len, r.uniform(0.5, 1.0) * max_len)
        if q.z - L < 0.25:
            L = max(0.2, q.z - 0.25)
        sway = Vector((r.uniform(-1, 1), r.uniform(-1, 1), 0)) * 0.12 * L
        pts = [q, q + sway * 0.4 - Vector((0, 0, L * 0.33)), q + sway - Vector((0, 0, L * 0.7)),
               q + sway * 0.8 - Vector((0, 0, L))]
        fp.tube(b, pts, [0.035, 0.03, 0.018, 0.004], "MossBeard", seg=4, color=beard_col, cap_end=False)


def bracket_cluster(b, center, out, r):
    for j in range(r.randint(2, 4)):
        R = r.uniform(0.12, 0.28)
        fan = fp.Fan(R, r, cup=r.uniform(0.1, 0.25), droop=0.1)
        base = center + Vector((r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), j * 0.22))
        mat = Matrix.Translation(base) @ fp.frame(out + Vector((0, 0, 0.4))).to_4x4()
        fp.fan_cap(b, fan, mat, "Bracket", "BracketGill", top_color=const((1, 1, 1), 0.3),
                   gill_color=const((1, 1, 1), 1.0), nu=6, nv=14)


def blackroot(b, x, y, height, r0, seed, beards=True):
    r = random.Random(seed)
    g = H(x, y)
    z0 = g - 0.5
    lean = Vector((r.uniform(-1, 1), r.uniform(-1, 1), 0)) * 0.05 * height
    pts, radii = [], []
    for k in range(10):
        t = k / 9
        wob = Vector((math.sin(t * 5 + seed) * 0.3, math.cos(t * 4 + seed * 1.3) * 0.3, 0)) * r0
        pts.append(Vector((x, y, z0)) + lean * t ** 1.4 + wob + Vector((0, 0, height * t)))
        radii.append(r0 * (1 + 1.9 * math.exp(-k * 1.25)) * (1 - 0.5 * t))
    fp.tube(b, pts, radii, "Blackbark", seg=16, color=bark_col, cap_end=False, wobble=0.2, seed=seed)
    top = pts[-1]
    fp.lathe(b, [(radii[-1], 0.0), (radii[-1] * 0.5, 0.0), (0.0, 0.0)], "Blackbark", Matrix.Translation(top), 14,
             lambda u, v, p: (0.28, 0.26, 0.23, 0.0),
             lambda p, u, v: p + Vector((0, 0, (0.7 * max(0.0, math.sin(v * math.tau * 3 + seed)) + 0.2 * pnoise(p * 4))
                                       * radii[-1] * 2 * (1 - u * 0.5))))
    # przypory korzeni
    for k in range(r.randint(4, 6)):
        a = k / 5 * math.tau + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        hb = r.uniform(0.9, 1.6)
        p0 = pts[0] + Vector((0, 0, 0.5 + hb))
        reach = r0 * r.uniform(2.6, 4.0)
        fp.tube(b, [p0 + d * r0 * 1.2, Vector((x, y, g + 0.3)) + d * reach * 0.6, Vector((x, y, g - 0.4)) + d * reach],
                [r0 * 0.55, r0 * 0.4, r0 * 0.15], "Blackbark", seg=8, color=bark_col)
    # "kolana" wystające z wody
    if g < 0.25:
        for k in range(r.randint(3, 8)):
            a = r.uniform(0, math.tau)
            d = r.uniform(1.6, 4.5) * (0.6 + r0)
            kx, ky = x + math.cos(a) * d, y + math.sin(a) * d
            kb = H(kx, ky) - 0.2
            s = r.uniform(0.7, 1.4)
            top_z = max(0.25, r.uniform(0.2, 0.7)) - kb
            fp.lathe(b, [(0.24 * s, 0.0), (0.17 * s, top_z * 0.35), (0.1 * s, top_z * 0.75), (0.04 * s, top_z * 0.97), (0.0, top_z)],
                     "Blackbark", Matrix.Translation((kx, ky, kb)), 10, bark_col,
                     lambda p, u, v: p + Vector((0.03 * pnoise(p * 5), 0.03 * pnoise(p * 5 + Vector((4, 0, 0))), 0)))
    # konary z brodami mchu
    nb = r.randint(2, 5) if height > 8 else r.randint(0, 2)
    for k in range(nb):
        t = r.uniform(0.45, 0.88)
        fi = t * 9
        i = min(int(fi), 8)
        start = pts[i].lerp(pts[i + 1], fi - i)
        rs = radii[i] * 0.4
        a = r.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0))
        L = r.uniform(1.5, 0.28 * height)
        up = r.uniform(0.2, 0.7)
        bp = [start, start + d * L * 0.35 + Vector((0, 0, L * up * 0.5)), start + d * L * 0.7 + Vector((0, 0, L * up * 0.7)),
              start + d * L + Vector((0, 0, L * up * 0.45))]
        bp = [q + Vector((r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), r.uniform(-0.15, 0.15))) for q in bp]
        fp.tube(b, bp, [rs, rs * 0.7, rs * 0.4, rs * 0.12], "Blackbark", seg=8, color=bark_col)
        if beards:
            for q in range(r.randint(6, 12)):
                u = r.uniform(0.2, 1.0)
                fi2 = u * 3
                j = min(int(fi2), 2)
                bq = bp[j].lerp(bp[j + 1], fi2 - j)
                beards_from(b, bq, r, r.randint(2, 5), r.uniform(0.6, min(3.5, height * 0.25)))
    if beards and height > 6:
        beards_from(b, top + Vector((0, 0, -0.2)), r, r.randint(3, 8), 1.6)
    if r.random() < 0.6:
        for k in range(r.randint(1, 3)):
            a = r.uniform(0, math.tau)
            hz = r.uniform(0.8, 3.0) + max(0.0, g)
            fi = (hz - z0) / height * 9
            i = max(0, min(int(fi), 8))
            c = pts[i].lerp(pts[i + 1], clamp01(fi - i))
            out = Vector((math.cos(a), math.sin(a), 0))
            bracket_cluster(b, c + out * radii[i] * 0.95, out, r)


def weeper(b, x, y, height, seed):
    """Weeping Mire: obca wierzba. Pochylony pień, z kopuły korony zwisają pasma liści do wody,
    na końcach miodowo świecące krople."""
    r = random.Random(seed)
    g = H(x, y)
    z0 = g - 0.4
    a = r.uniform(0, math.tau)
    lean = Vector((math.cos(a), math.sin(a), 0)) * 0.22 * height
    pts = [Vector((x, y, z0)) + lean * (k / 7) ** 1.6 + Vector((0, 0, height * k / 7))
           + Vector((math.sin(k * 1.3 + seed) * 0.3, math.cos(k * 1.1 + seed) * 0.3, 0)) for k in range(8)]
    radii = [0.95 * (1 + 0.9 * math.exp(-k * 1.4)) * (1 - 0.45 * k / 7) for k in range(8)]

    def wcol(u, v, p):
        n = pnoise(Vector((v * 7, u * 12, 2.0)))
        c = Vector((0.14, 0.11, 0.07)) * (0.75 + 0.4 * n)
        if p.z < 1.0:
            c = c.lerp(Vector((0.07, 0.1, 0.045)), 0.6)
        return (c.x, c.y, c.z, 0.0)

    fp.tube(b, pts, radii, "WeeperBark", seg=16, color=wcol, cap_end=True, wobble=0.15, seed=seed)
    top = pts[-1]
    C = top + Vector((0, 0, 0.8))
    Rc = 0.48 * height
    for k in range(7):                         # konary do kopuły
        aa = k / 7 * math.tau + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(aa), math.sin(aa), 0))
        fp.tube(b, [top - Vector((0, 0, 1.0)), top + d * Rc * 0.35 + Vector((0, 0, Rc * 0.28)), C + d * Rc * 0.75 + Vector((0, 0, Rc * 0.12))],
                [0.42, 0.25, 0.08], "WeeperBark", seg=8, color=wcol)
    n_fr = 220 if FAST else 420
    for _ in range(n_fr):                      # pasma liści
        aa = r.uniform(0, math.tau)
        rr = Rc * math.sqrt(r.random())
        dz = Rc * 0.32 * (1 - (rr / Rc) ** 2)
        q = C + Vector((math.cos(aa) * rr, math.sin(aa) * rr, dz))
        out = Vector((math.cos(aa), math.sin(aa), 0))
        floor = max(H(q.x, q.y), WATER)
        L = (q.z - floor) * r.uniform(0.35, 0.9) * (0.55 + 0.45 * rr / Rc)
        q1 = q + out * r.uniform(0.4, 1.0) + Vector((0, 0, 0.2))
        q2 = q + out * r.uniform(0.6, 1.3) + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), -L))
        side = Vector((-out.y, out.x, 0))
        c_top = Vector((0.14, 0.17, 0.05))
        c_tip = Vector((0.6, 0.48, 0.15)) if r.random() < 0.7 else Vector((0.36, 0.4, 0.12))

        def col(u, v, p, c_top=c_top, c_tip=c_tip):
            c = c_top.lerp(c_tip, u ** 0.9)
            return (c.x, c.y, c.z, 0.0)

        ribbon(b, lambda u, q=q, q1=q1, q2=q2: bez(q, q1, q2, u), lambda u: 0.16 * (1 - 0.55 * u) + 0.02, side, 6,
               "WeeperFrond", col)
        if r.random() < 0.55:
            blob(b, q2 - Vector((0, 0, 0.04)), r.uniform(0.04, 0.085), "HoneyBead", const((1, 1, 1), 1.0), seg=6)
    for _ in range(140 if not FAST else 60):  # gęste liście na wierzchu kopuły
        aa = r.uniform(0, math.tau)
        rr = Rc * 0.9 * math.sqrt(r.random())
        dz = Rc * 0.32 * (1 - (rr / Rc) ** 2)
        q = C + Vector((math.cos(aa) * rr, math.sin(aa) * rr, dz + 0.1))
        out = Vector((math.cos(aa), math.sin(aa), 0))
        side = Vector((-out.y, out.x, 0))
        q2 = q + out * r.uniform(1.0, 2.2) - Vector((0, 0, r.uniform(0.4, 1.2)))
        ribbon(b, lambda u, q=q, q2=q2: q.lerp(q2, u) + Vector((0, 0, 0.35 * math.sin(u * math.pi))), lambda u: 0.22 * (1 - 0.6 * u),
               side, 4, "WeeperFrond", const((0.2, 0.22, 0.07)))


def log(b, x, y, ang, length, rad, seed):
    r = random.Random(seed)
    d = Vector((math.cos(ang), math.sin(ang), 0))
    zc = max(H(x, y), -0.3) + rad * 0.15
    pts = [Vector((x, y, zc)) + d * (length * (k / 8 - 0.5)) + Vector((0, r.uniform(-0.1, 0.1), r.uniform(-0.06, 0.06)))
           for k in range(9)]
    fp.tube(b, pts, [rad * (1 - 0.15 * k / 8) for k in range(9)], "Blackbark", seg=14, color=bark_col, cap_end=True,
            wobble=0.12, seed=seed)
    if r.random() < 0.7:
        bracket_cluster(b, pts[r.randint(2, 6)] + Vector((0, 0, rad * 0.8)), Vector((0, 0, 1)), r)


def trees():
    b = fp.Builder([])
    w = fp.Builder([])
    # kadr dnia/nocy (patrzymy na +Y przez kanał)
    hero = [(5, 15.5, 14, 0.42), (-17, 14, 10, 0.35), (11, 25, 18, 0.5), (-4, 39, 21, 0.55), (24, 19, 9, 0.3),
            (-28, 30, 16, 0.45), (2, 55, 22, 0.55), (30, 48, 18, 0.5), (-36, 58, 20, 0.5), (-12, 24, 8, 0.3),
            (17, 40, 12, 0.4), (-22, 46, 13, 0.4), (-8, 3.5, 7, 0.28),
            # kadr czytania bagna i staw
            (31, -4, 16, 0.45), (21, -26, 11, 0.38), (35, -18, 13, 0.4), (4, -16, 6, 0.25),
            # przy arenie (obgryzione osobno) i w tle
            (-22, -14, 15, 0.45), (-14, -34, 12, 0.4), (-58, -18, 18, 0.5)]
    for i, (x, y, h, r0) in enumerate(hero):
        blackroot(b, x, y, h, r0, 100 + i)
    for i in range(60 if not FAST else 30):
        x, y = rng.uniform(-96, 96), rng.uniform(-96, 96)
        if near_view(x, y, 6) or in_sightline(x, y) or math.hypot(x - BARROW.x, y - BARROW.y) < BARROW_R or \
                math.hypot(x - ARENA.x, y - ARENA.y) < ARENA_R + 4 or poly_dist(x, y, CHANNEL) < 3:
            continue
        blackroot(b, x, y, rng.uniform(6, 24), rng.uniform(0.3, 0.6), 300 + i, beards=rng.random() < 0.8)
    for i, (x, y, h) in enumerate([(-9, 21, 12), (17, 33, 14), (-16, -7, 10), (-30, 10, 13), (40, 2, 15),
                                   (-20, 66, 16), (60, 25, 12)]):
        weeper(w, x, y, h, 500 + i)
    for i, (x, y, a, L, rad) in enumerate([(-3, 1.6, 0.3, 6.5, 0.45), (9, 13.5, -0.4, 8, 0.6), (18, -20.5, 1.2, 5.5, 0.4),
                                           (-14, 6, 2.2, 7, 0.5), (-31, -26, 0.8, 6, 0.5), (26, 6, 0.1, 9, 0.65)]):
        log(b, x, y, a, L, rad, 700 + i)
    b.finish("Blackroots")
    w.finish("Weepers")


# ---------------------------------------------------------------- drobne: bańki, pijawki, świetliki

def bubbles():
    b = fp.Builder([])
    spots = [(POOL[0] + 2, POOL[1] - 1, 3.0, 9), (POOL[0] - 3, POOL[1] + 4, 2.0, 6), (-30, 8, 3.0, 8), (14, 10, 3.0, 6),
             (ARENA.x + 2, ARENA.y + 1.5, 4.0, 14), (ARENA.x - 4, ARENA.y - 3, 3.0, 8), (2, 9.8, 2.5, 5)]
    for (cx, cy, rad, n) in spots:
        for _ in range(n):
            a, d = rng.uniform(0, math.tau), rad * math.sqrt(rng.random())
            rr = rng.uniform(0.03, 0.14)
            c = Vector((cx + math.cos(a) * d, cy + math.sin(a) * d, 0.03))
            fp.lathe(b, [(0.0, 0.0), (rr, 0.0), (rr * 0.75, rr * 0.65), (0.0, rr * 0.9)], "Bubble", Matrix.Translation(c), 10,
                     const((1, 1, 1)))
    b.finish("Bubbles")


def leech(b, x, y, z, ang, L, r):
    d = Vector((math.cos(ang), math.sin(ang), 0))
    s = Vector((-d.y, d.x, 0))
    ph = r.uniform(0, math.tau)
    pts = [Vector((x, y, z)) + d * ((k / 11 - 0.5) * L) + s * (math.sin(k / 11 * math.pi * 1.7 + ph) * L * 0.1)
           + Vector((0, 0, 0.02 * math.sin(k * 0.9 + ph))) for k in range(12)]
    radii = []
    for k in range(12):
        t = k / 11
        rr = L * 0.065 * (0.3 + 0.7 * math.sin(math.pi * min(1.0, t * 1.08 + 0.02)))
        radii.append(rr * (1.25 if k == 11 else 1.0))

    def col(u, v, p):
        ring = 0.85 + 0.15 * math.sin(u * 70)
        c = Vector((0.045, 0.05, 0.025)) * ring
        stripe = 1.0 - smooth(0.04, 0.09, abs(v - 0.25))
        c = c.lerp(Vector((0.55, 0.2, 0.06)), stripe * 0.8)
        return (c.x, c.y, c.z, stripe)

    fp.tube(b, pts, radii, "Leech", seg=10, color=col, cap_end=True)


def leeches():
    b = fp.Builder([])
    spots = [(1.4, 3.2, 0.3, 0.7), (-1.8, 4.6, 2.0, 0.6), (3.6, 4.4, -0.8, 0.55), (10.4, -18.8, 0.9, 0.7),
             (11.2, -16.0, 2.6, 0.6), (9.0, -20.6, -0.3, 0.65), (12.0, -24.6, 1.6, 0.5), (16.0, -13.0, 0.2, 0.75)]
    for (x, y, a, L) in spots:
        leech(b, x, y, H(x, y) + 0.06, a, L, rng)
    leech(b, -3.4, 1.5, 0.55, 0.3, 0.6, rng)       # na kłodzie
    b.finish("Leeches")


def lights_bugs():
    """Świetliki (drobne) i ogniki (większe kule ze światłem nocą)."""
    bm = bmesh.new()
    for _ in range(900 if not FAST else 400):
        x, y = rng.uniform(-60, 60), rng.uniform(-50, 70)
        if near_view(x, y, 2.0):
            continue
        z = max(H(x, y), WATER) + 0.3 + 2.8 * rng.random() ** 1.6
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(0.012, 0.022), matrix=Matrix.Translation((x, y, z)))
    mesh_from_bm("Fireflies", bm, M["Firefly"])
    wisps = [(-5, 12, 1.4), (8, 20, 2.2), (-14, 26, 1.1), (19, -9, 1.6), (22, -20, 1.2), (-38, -33, 1.8), (-20, 4, 1.5),
             (3, 32, 1.8), (-25, 18, 2.0)]
    bm = bmesh.new()
    lamps = []
    for (x, y, z) in wisps:
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.07, matrix=Matrix.Translation((x, y, z)))
        ld = bpy.data.lights.new("WispLight", "POINT")
        ld.energy = 0.0
        ld.color = (1.0, 0.62, 0.25)
        ld.shadow_soft_size = 0.1
        lo = link(bpy.data.objects.new("WispLight", ld))
        lo.location = (x, y, z)
        lamps.append(lo)
    mesh_from_bm("Wisps", bm, M["Wisp"])
    return lamps


# ---------------------------------------------------------------- Kościany Kurhan

def bone_col(u, v, p):
    n = pnoise(p * 1.6)
    c = Vector((0.82, 0.78, 0.67)) * (0.85 + 0.18 * n)
    crack = pnoise(p * 7.0 + Vector((2, 2, 2)))
    if crack > 0.45:
        c *= 0.55
    gz = H(p.x, p.y)
    if p.z - gz < 0.8:
        c = c.lerp(Vector((0.25, 0.27, 0.12)), clamp01(1 - (p.z - gz) / 0.8) * 0.7)
    return (c.x, c.y, c.z, 0.0)


def barrow():
    b = fp.Builder([])
    s0, s1 = SPINE
    d = (s1 - s0).normalized()
    perp = Vector((-d.y, d.x))
    n_ribs = 9
    r = random.Random(42)
    for k in range(n_ribs):
        t = (k + 0.5) / n_ribs
        c = s0.lerp(s1, t)
        apex = lerp(9.5, 4.5, t) + r.uniform(-0.6, 0.6)
        W = lerp(7.5, 4.5, t)
        gz = H(c.x, c.y)
        broken = r.random() < 0.3
        pts = []
        steps = 12
        for i in range(steps + 1):
            u = i / steps
            if broken and u > 0.62:
                break
            q = c + perp * (W * (u * 2 - 1))
            z = H(q.x, q.y) - 0.6 + (apex + 0.6) * math.sin(math.pi * u) ** 0.75
            fwd = d * (0.9 * math.sin(math.pi * u))       # żebra lekko odchylone do tyłu
            pts.append(Vector((q.x + fwd.x, q.y + fwd.y, z)))
        rr = lerp(0.6, 0.38, t)
        radii = [rr * (1.15 - 0.35 * math.sin(math.pi * i / steps)) for i in range(len(pts))]
        fp.tube(b, pts, radii, "Bone", seg=12, color=bone_col, cap_end=True, wobble=0.12, seed=k)
        # kręg pod łukiem
        vz = gz - 0.3
        fp.lathe(b, [(0.0, -0.3), (0.85, -0.25), (0.95, 0.15), (0.7, 0.45), (0.0, 0.5)], "Bone",
                 Matrix.Translation((c.x, c.y, vz)) @ Matrix.Rotation(math.pi / 2, 4, Vector((perp.x, perp.y, 0))), 14, bone_col)
        fp.tube(b, [Vector((c.x, c.y, vz + 0.4)), Vector((c.x - d.x * 0.4, c.y - d.y * 0.4, vz + 1.6))], [0.3, 0.08], "Bone",
                seg=8, color=bone_col)
    # czaszka na przedzie, wpół zakopana, pyskiem w dół zbocza
    sk_c = s0 - Vector((d.x, d.y)) * 5.5
    gz = H(sk_c.x, sk_c.y)
    face = -d
    # bryła obrotowa: lokalna oś Z = pysk (poziomo), lokalne X = w górę, Y = w bok
    f3 = Vector((face.x, face.y, 0)).normalized()
    up = Vector((0, 0, 1))
    side3 = f3.cross(up)
    rot3 = Matrix((up, side3, f3)).transposed()
    skull_m = Matrix.Translation((sk_c.x, sk_c.y, gz - 0.4)) @ rot3.to_4x4()
    skull_inv = skull_m.inverted()
    eyes = [Vector((0.95, 1.4 * sy, 1.0)) for sy in (-1, 1)]

    def sdef(p, u, v):
        p = p.copy()
        if p.z > 0:                                   # pysk się zwęża
            k = 1 - 0.5 * (p.z / 2.7)
            p.x *= k
            p.y *= k
        p.x *= 0.8                                    # spłaszczona w pionie
        for e in eyes:                                # oczodoły: wgłębienie w stronę osi
            dd = (p - e).length
            if dd < 0.95:
                p = p - Vector((p.x, p.y, 0)).normalized() * (0.95 - dd) * 0.8
        if p.x > 0.4:                                 # wał nad oczodołami
            p.x += 0.3 * math.exp(-((p.z - 0.5) ** 2) * 2)
        return p + p.normalized() * 0.1 * pnoise(p * 1.3)

    def skull_col(u, v, p):
        c = Vector(bone_col(u, v, p)[:3])
        q = skull_inv @ p
        for e in eyes:
            if (Vector((q.x, q.y, q.z)) - e).length < 0.8:
                c *= 0.12
        return (c.x, c.y, c.z, 0.0)

    prof = [(0.0, -2.4), (2.0, -2.2), (2.8, -0.8), (2.9, 0.6), (2.3, 1.9), (1.2, 2.6), (0.0, 2.75)]
    fp.lathe(b, prof, "Bone", skull_m, 28, skull_col, sdef)
    # kły
    for sy in (-1, 1):
        base = Vector((sk_c.x, sk_c.y, gz)) + Vector((face.x, face.y, 0)) * 3.2 + Vector((perp.x, perp.y, 0)) * 1.0 * sy
        side = Vector((perp.x, perp.y, 0)) * sy
        fw = Vector((face.x, face.y, 0))
        pts = [base, base + fw * 1.8 + side * 0.8 + Vector((0, 0, -0.4)), base + fw * 3.4 + side * 1.4 + Vector((0, 0, 0.8)),
               base + fw * 3.8 + side * 0.9 + Vector((0, 0, 2.6))]
        fp.tube(b, pts, [0.42, 0.36, 0.24, 0.04], "Bone", seg=12, color=bone_col, cap_end=True)
    # rozrzucone kości
    for k in range(9):
        a = r.uniform(0, math.tau)
        dist = r.uniform(6, BARROW_R * 0.85)
        cx, cy = BARROW.x + math.cos(a) * dist, BARROW.y + math.sin(a) * dist
        ang = r.uniform(0, math.tau)
        dd = Vector((math.cos(ang), math.sin(ang), 0))
        L = r.uniform(1.5, 4.0)
        p0 = Vector((cx, cy, H(cx, cy) + 0.1)) - dd * L / 2
        p1 = p0 + dd * L
        p1.z = H(p1.x, p1.y) + 0.1
        fp.tube(b, [p0, p0.lerp(p1, 0.5) + Vector((0, 0, 0.05)), p1], [0.18, 0.12, 0.18], "Bone", seg=10, color=bone_col)
        blob(b, p0, 0.3, "Bone", bone_col, seg=10, squash=0.8)
        blob(b, p1, 0.27, "Bone", bone_col, seg=10, squash=0.8)
    b.finish("Barrow")
    # wrzosy
    hb = fp.Builder([])
    for _ in range(420 if not FAST else 180):
        a = rng.uniform(0, math.tau)
        dist = BARROW_R * 0.85 * math.sqrt(rng.random())
        x, y = BARROW.x + math.cos(a) * dist, BARROW.y + math.sin(a) * dist
        if near_view(x, y, 1.5):
            continue
        z = H(x, y)
        if pnoise(Vector((x * 0.22, y * 0.22, 7.7))) < -0.05:
            continue
        s = rng.uniform(0.25, 0.6)
        ph = rng.uniform(0, 10)

        def hcol(u, v, p, ph=ph):
            n = pnoise(p * 9 + Vector((ph, 0, 0)))
            c = Vector((0.1, 0.12, 0.06)) if u < 0.3 else (Vector((0.6, 0.22, 0.52)) if n > 0.05 else Vector((0.34, 0.12, 0.32)))
            return (c.x, c.y, c.z, 0.0)

        fp.lathe(hb, [(0.0, -0.05), (s, -0.02), (s * 0.95, s * 0.35), (s * 0.6, s * 0.65), (0.0, s * 0.72)], "Heather",
                 Matrix.Translation((x, y, z - 0.04)), 12, hcol,
                 lambda p, u, v, ph=ph: p + p.normalized() * 0.08 * pnoise(p * 7 + Vector((ph, 0, 0))))
    hb.finish("Heather")
    # sęp (zapowiedź Bonepickera) na najwyższym żebrze
    v = fp.Builder([])
    tip = s0.lerp(s1, 0.5 / n_ribs)
    perch = Vector((tip.x, tip.y, H(tip.x, tip.y) - 0.6 + 9.9))
    fw = Vector((-d.x, -d.y, 0))
    body_m = Matrix.Translation(perch + Vector((0, 0, 0.7))) @ fp.frame(fw + Vector((0, 0, 0.6))).to_4x4() \
        @ Matrix.Rotation(math.pi / 2, 4, "Y")
    fp.lathe(v, [(0.0, -0.75), (0.38, -0.55), (0.5, 0.0), (0.42, 0.45), (0.0, 0.7)], "Vulture", body_m, 14,
             const((0.12, 0.08, 0.06)))
    neck0 = perch + Vector((0, 0, 1.15)) + fw * 0.25
    head = neck0 + fw * 0.45 + Vector((0, 0, 0.1))
    fp.tube(v, [neck0, neck0 + fw * 0.2 + Vector((0, 0, 0.25)), head], [0.13, 0.09, 0.08], "Vulture", seg=8,
            color=const((0.55, 0.38, 0.35)))
    blob(v, head, 0.14, "Vulture", const((0.6, 0.42, 0.38)), seg=10)
    fp.tube(v, [head + fw * 0.1, head + fw * 0.33 + Vector((0, 0, -0.02)), head + fw * 0.38 + Vector((0, 0, -0.14))],
            [0.05, 0.035, 0.01], "Vulture", seg=6, color=const((0.85, 0.75, 0.45)))
    for sy in (-1, 1):                 # złożone skrzydła
        side = Vector((perp.x, perp.y, 0)) * sy
        w0 = perch + Vector((0, 0, 1.0)) + side * 0.4
        fp.tube(v, [w0, w0 - fw * 0.6 + side * 0.15 + Vector((0, 0, -0.2)), w0 - fw * 1.2 + Vector((0, 0, -0.7))],
                [0.22, 0.2, 0.05], "Vulture", seg=8, color=const((0.1, 0.07, 0.05)))
        fp.tube(v, [perch + Vector((0, 0, 0.3)) + side * 0.15, perch + side * 0.17], [0.04, 0.03], "Vulture", seg=5,
                color=const((0.6, 0.5, 0.4)))
    # ptaki krążące nad kurhanem
    for k in range(5):
        a = k / 5 * math.tau + 0.4
        c = Vector((BARROW.x + math.cos(a) * 9, BARROW.y + math.sin(a) * 9, 26 + k * 2.5))
        tang = Vector((-math.sin(a), math.cos(a), 0))
        side = Vector((math.cos(a), math.sin(a), 0))
        for sy in (-1, 1):
            p0 = c
            p1 = c + side * sy * 1.2 + Vector((0, 0, 0.35)) - tang * 0.2
            p2 = c + side * sy * 2.2 - tang * 0.4 + Vector((0, 0, 0.1))
            ribbon(v, lambda u, p0=p0, p1=p1, p2=p2: bez(p0, p1, p2, u), lambda u: 0.45 * (1 - u) + 0.05, tang, 4, "Vulture",
                   const((0.08, 0.06, 0.05)))
    v.finish("Vulture")
    for k in range(8):
        a = rng.uniform(0, math.tau)
        dist = rng.uniform(4, BARROW_R * 0.8)
        x, y = BARROW.x + math.cos(a) * dist, BARROW.y + math.sin(a) * dist
        o = fp.rock(f"BarrowRock{k}", 900 + k, rng.uniform(0.6, 1.6))
        o.location = (x, y, H(x, y) - 0.15)


# ---------------------------------------------------------------- arena Bogmawa

def arena():
    b = fp.Builder([])
    r = random.Random(77)
    # obgryzione pnie przy brzegu
    for i, (x, y, hh, r0) in enumerate([(-38, -28, 2.6, 0.6), (-35.5, -36, 1.4, 0.5), (-42.5, -27, 3.4, 0.7),
                                        (-30.5, -33.5, 1.0, 0.45), (-55, -26, 2.2, 0.6), (-31, -45, 1.8, 0.5)]):
        g = H(x, y)
        pts = [Vector((x, y, g - 0.4 + hh * k / 4)) + Vector((r.uniform(-0.08, 0.08), r.uniform(-0.08, 0.08), 0)) for k in range(5)]
        radii = [r0 * (1.6 if k == 0 else 1.0) for k in range(5)]
        fp.tube(b, pts, radii, "Blackbark", seg=14, color=bark_col, cap_end=False, wobble=0.15, seed=i)

        def scol(u, v, p):
            gouge = math.sin(v * math.tau * 9) > 0.6
            c = Vector((0.6, 0.45, 0.3)) * (0.55 if gouge else 1.0)
            return (c.x, c.y, c.z, 0.0)

        fp.lathe(b, [(radii[-1], 0.0), (radii[-1] * 0.7, 0.0), (0.0, 0.0)], "Stump", Matrix.Translation(pts[-1]), 16, scol,
                 lambda p, u, v, rr=radii[-1], s=i: p + Vector((0, 0, (0.9 * max(0.0, math.sin(v * math.tau * 4 + s)) ** 2
                                                                    + 0.15 * pnoise(p * 6)) * rr * 1.2 * (1 - u * 0.6))))
        for k in range(r.randint(3, 6)):        # drzazgi wokół
            a = r.uniform(0, math.tau)
            dd = r.uniform(0.8, 2.5)
            p0 = Vector((x + math.cos(a) * dd, y + math.sin(a) * dd, 0))
            p0.z = H(p0.x, p0.y) + 0.05
            p1 = p0 + Vector((math.cos(a + 1), math.sin(a + 1), 0.05)) * r.uniform(0.4, 1.0)
            fp.tube(b, [p0, p1], [0.06, 0.02], "Stump", seg=5, color=const((0.55, 0.42, 0.28)))
    # kości ofiar przy brzegu
    for k in range(7):
        a = r.uniform(-2.6, -1.2)
        dd = r.uniform(ARENA_R + 1, ARENA_R + 6)
        cx, cy = ARENA.x + math.cos(a + 1.6) * dd, ARENA.y + math.sin(a + 1.6) * dd
        ang = r.uniform(0, math.tau)
        dv = Vector((math.cos(ang), math.sin(ang), 0))
        L = r.uniform(0.6, 1.6)
        p0 = Vector((cx, cy, H(cx, cy) + 0.05)) - dv * L / 2
        p1 = p0 + dv * L
        fp.tube(b, [p0, p1], [0.07, 0.07], "Bone", seg=8, color=bone_col)
        blob(b, p0, 0.11, "Bone", bone_col, seg=8)
        blob(b, p1, 0.1, "Bone", bone_col, seg=8)
    b.finish("ArenaProps")
    # Bogmaw Elder: wierzch głowy, oczy i grzbiet nad błotem
    g = fp.Builder([])
    c = Vector((ARENA.x + 1.5, ARENA.y + 1.0, 0.0))
    face = (Vector((-33.0, -29.0, 0)) - c).normalized()
    face.z = 0
    yaw = math.atan2(face.y, face.x)
    rot = Matrix.Rotation(yaw, 4, "Z")

    def W(p):
        return Matrix.Translation(c) @ rot @ p

    def skin(u, v, p):
        n = pnoise(p * 2.2)
        c0 = Vector((0.08, 0.09, 0.045)) * (0.8 + 0.4 * n)
        if pnoise(p * 6 + Vector((1, 2, 3))) > 0.45:
            c0 = c0.lerp(Vector((0.24, 0.2, 0.09)), 0.7)
        if p.z < 0.08:
            c0 = c0.lerp(Vector((0.06, 0.05, 0.03)), 0.7)
        return (c0.x, c0.y, c0.z, 0.0)

    head_m = Matrix.Translation(c) @ rot @ Matrix.Translation((0, 0, -0.55))
    fp.lathe(g, [(0.0, -0.3), (1.35, -0.2), (1.45, 0.35), (1.1, 0.75), (0.0, 0.85)], "Bogmaw", head_m, 28, skin,
             lambda p, u, v: Vector((p.x * (1.9 if p.x > 0 else 1.3), p.y, p.z)) + p.normalized() * 0.06 * pnoise(p * 3))
    for sy in (-1, 1):
        e = W(Vector((-0.5, 0.75 * sy, 0.32)))
        blob(g, Vector(e), 0.42, "Bogmaw", skin, seg=14, squash=0.85)
        iris = W(Vector((-0.2, 0.83 * sy, 0.42)))
        blob(g, Vector(iris), 0.17, "BogmawEye", const((1, 1, 1), 1.0), seg=10, squash=0.55)
        brow0 = W(Vector((-0.9, 0.75 * sy, 0.55)))
        brow1 = W(Vector((-0.2, 0.95 * sy, 0.7)))
        brow2 = W(Vector((0.25, 0.7 * sy, 0.55)))
        fp.tube(g, [Vector(brow0), Vector(brow1), Vector(brow2)], [0.12, 0.15, 0.08], "Bogmaw", seg=8, color=skin)
        nos = W(Vector((2.45, 0.28 * sy, 0.12)))
        blob(g, Vector(nos), 0.14, "Bogmaw", skin, seg=10, squash=0.7)
    for k in range(10):
        t = k / 9
        p = W(Vector((-2.0 - k * 1.05, 0.5 * math.sin(k * 0.45), -0.15)))
        hgt = lerp(0.7, 0.18, t)
        rad = lerp(0.42, 0.18, t)
        fp.lathe(g, [(rad, 0.0), (rad * 0.8, hgt * 0.4), (rad * 0.35, hgt * 0.85), (0.0, hgt)], "Bogmaw",
                 Matrix.Translation(Vector(p)), 10, skin, lambda q, u, v: q + q.normalized() * 0.05 * pnoise(q * 6))
    # zmarszczki na błocie wokół głowy
    for k, rr in enumerate((3.2, 4.4, 5.9)):
        def pos(u, v, rr=rr):
            a = v * math.tau
            R2 = rr + 0.25 * u
            return Vector((c.x + math.cos(a) * R2 * 1.25, c.y + math.sin(a) * R2, 0.07 + 0.03 * math.sin(u * math.pi)))
        g.grid(pos, 2, 64, "Bubble", color=const((0.5, 0.45, 0.35)))
    g.finish("BogmawElder")


# ---------------------------------------------------------------- światło, render, kamery

def world_and_sun():
    w = bpy.data.worlds.new("MarshWorld")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.angle = math.radians(1.5)
    so = link(bpy.data.objects.new("Sun", sun))
    return bg, HAZE_VOL, sun, so


def light_view(env, sun_dir, fog_density):
    """Kadr szkicu: kierunek słońca (dokąd świeci) i gęstość koca mgły dobrane pod ujęcie."""
    env[3].rotation_euler = Vector(sun_dir).to_track_quat("-Z", "Y").to_euler()
    FOG_DENS.default_value = fog_density


def set_time(night, env, lamps, helmet):
    bg, vol, sun, so = env
    for sock, day, nite in GLOW:
        sock.default_value = nite if night else day
    if night:
        bg.inputs["Color"].default_value = (0.006, 0.01, 0.016, 1)
        bg.inputs["Strength"].default_value = 1.0
        sun.energy = 0.12
        sun.color = (0.55, 0.65, 1.0)
        so.rotation_euler = Vector((-0.4, 0.3, -0.6)).to_track_quat("-Z", "Y").to_euler()
        vol.inputs["Color"].default_value = (0.4, 0.5, 0.6, 1)
        vol.inputs["Density"].default_value = 0.008
        vol.inputs["Anisotropy"].default_value = 0.2
        FOG_VOL.inputs["Color"].default_value = (0.5, 0.62, 0.72, 1)
        FOG_VOL.inputs["Emission Color"].default_value = (0.25, 0.5, 0.55, 1)
        FOG_VOL.inputs["Anisotropy"].default_value = 0.2
        FOG_DENS.default_value = 0.12
        for lo in lamps:
            lo.data.energy = 25.0
        helmet.data.energy = 25.0
    else:
        bg.inputs["Color"].default_value = (0.62, 0.66, 0.54, 1)
        bg.inputs["Strength"].default_value = 0.9
        sun.energy = 4.5
        sun.color = (1.0, 0.82, 0.55)
        so.rotation_euler = Vector((0.1, -0.85, -0.5)).to_track_quat("-Z", "Y").to_euler()
        vol.inputs["Color"].default_value = (0.85, 0.87, 0.76, 1)
        vol.inputs["Density"].default_value = 0.006
        vol.inputs["Anisotropy"].default_value = 0.35
        FOG_VOL.inputs["Color"].default_value = (0.92, 0.92, 0.8, 1)
        FOG_VOL.inputs["Emission Color"].default_value = (0.95, 0.88, 0.65, 1)
        FOG_VOL.inputs["Anisotropy"].default_value = 0.45
        FOG_DENS.default_value = 0.07
        for lo in lamps:
            lo.data.energy = 0.0
        helmet.data.energy = 4.0


def setup_render():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    ee = scene.eevee
    for k, v in (("taa_render_samples", 16 if FAST else 64), ("use_raytracing", True),
                 ("volumetric_end", 220.0), ("volumetric_tile_size", "4" if FAST else "2"),
                 ("use_volumetric_shadows", True), ("volumetric_samples", 64 if FAST else 128),
                 ("volumetric_sample_distribution", 0.9), ("use_shadows", True)):
        try:
            setattr(ee, k, v)
        except Exception as e:
            print("eevee", k, e)
    scene.render.resolution_x = 960 if FAST else 1600
    scene.render.resolution_y = 540 if FAST else 900
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception as e:
        print("cm", e)
    try:
        tree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
        scene.compositing_node_group = tree
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = tree.nodes.new("CompositorNodeRLayers")
        gl = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        for sname, val in (("Type", "Bloom"), ("Threshold", 1.1), ("Strength", 0.35), ("Size", 0.5), ("Quality", "High")):
            s = gl.inputs.get(sname)
            if s is not None:
                try:
                    s.default_value = val
                except Exception as e:
                    print("glare", sname, e)
        tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
        tree.links.new(gl.outputs["Image"], out.inputs[0])
        scene.render.use_compositing = True
    except Exception as e:
        print("glare setup failed:", e)


def add_player():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "player.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    return next(o for o in new if o.parent is None)


def place(player, helmet, xy, yaw_deg, sink=0.0):
    z = H(xy.x, xy.y) - sink
    player.location = (xy.x, xy.y, z)
    player.rotation_euler.z = math.radians(yaw_deg)
    helmet.location = (xy.x + 0.4, xy.y - 0.9, z + 2.4)


def aim(cam, pos, target, lens):
    cam.location = pos
    cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam


def render(name):
    path = os.path.join(SKETCH_DIR, name)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


def main():
    terrain()
    fog_obj, haze_obj = fog()
    scatter_plants()
    trees()
    bubbles()
    leeches()
    lamps = lights_bugs()
    barrow()
    arena()
    env = world_and_sun()
    setup_render()
    player = add_player()
    hl = bpy.data.lights.new("HelmetLamp", "POINT")
    hl.color = (1.0, 0.92, 0.75)
    hl.shadow_soft_size = 0.3
    helmet = link(bpy.data.objects.new("HelmetLamp", hl))
    cam = link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    cam.data.clip_end = 500
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "source", "mist_marsh.blend"))

    def cam_at(i):
        c = CAMS[i]
        return (c.x, c.y, max(H(c.x, c.y), WATER) + c.z)

    if "day" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (0.35, -0.8, -0.45), 0.22)
        place(player, helmet, P_DAY, -8)
        aim(cam, CAMS[0], (-3, 25, 3.5), 20)
        render("marsh_1_day.png")
    if "reading" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (0.6, 0.55, -0.55), 0.07)
        place(player, helmet, P_READ, -25)
        aim(cam, CAMS[1], (19, -9, 0.2), 22)
        render("marsh_2_reading_water.png")
    if "overview" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (0.4, 0.5, -0.75), 0.0)
        fog_obj.hide_render = True
        haze_obj.hide_render = True
        place(player, helmet, P_DAY, -8)
        aim(cam, (125, -125, 120), (0, 5, 0), 26)
        render("marsh_3_overview.png")
        fog_obj.hide_render = False
        haze_obj.hide_render = False
    if "night" in VIEWS:
        set_time(True, env, lamps, helmet)
        FOG_DENS.default_value = 0.3
        place(player, helmet, P_DAY, -8)
        aim(cam, CAMS[0], (-3, 25, 3.5), 20)
        render("marsh_4_night.png")
    if "barrowfar" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (0.75, -0.25, -0.5), 0.25)
        place(player, helmet, PLAYERS[3], -46)
        aim(cam, cam_at(3), (BARROW.x, BARROW.y, 6.5), 24)
        render("marsh_5_bonebarrow_far.png")
    if "barrow" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (-0.98, -0.2, -0.6), 0.2)
        yaw = math.degrees(math.atan2(-_SD.y, -_SD.x)) - 90
        place(player, helmet, PLAYERS[2], yaw)
        aim(cam, cam_at(2), (SPINE[0].x, SPINE[0].y, H(SPINE[0].x, SPINE[0].y) + 3.5), 20)
        render("marsh_6_bonebarrow.png")
    if "boss" in VIEWS:
        set_time(False, env, lamps, helmet)
        light_view(env, (0.3, 0.6, -0.4), 0.15)
        place(player, helmet, PLAYERS[4], 133)
        aim(cam, CAMS[4], (-48, -42, 0.4), 22)
        render("marsh_7_toward_boss.png")
    if "mist" in VIEWS:
        render_mist(cam, player, helmet, env, lamps)


def render_mist(cam, player, helmet, env, lamps):
    """Mgła dryfuje nad wodą, tafla płycizny marszczy się: klatki -> GIF."""
    set_time(False, env, lamps, helmet)
    light_view(env, (0.35, -0.8, -0.45), 0.22)
    place(player, helmet, P_DAY, -8)
    aim(cam, CAMS[0], (-3, 25, 3.5), 20)
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x, scene.render.resolution_y = 640, 360
    samples = scene.eevee.taa_render_samples
    scene.eevee.taa_render_samples = 16
    frames_dir = os.path.join(SKETCH_DIR, "_mist_frames")
    os.makedirs(frames_dir, exist_ok=True)
    n = 12 if FAST else 30
    for i in range(n):
        t = i / n
        ANIM["fog_w"].default_value = math.sin(t * math.tau) * 0.6
        ANIM["fog_loc"].default_value = (math.cos(t * math.tau) * 6.0, t * 0.0, 0.0)
        ANIM["water_w"].default_value = math.sin(t * math.tau) * 0.8
        scene.render.filepath = os.path.join(frames_dir, f"f{i:03d}.png")
        bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    scene.eevee.taa_render_samples = samples
    ff = shutil.which("ffmpeg")
    gif = os.path.join(SKETCH_DIR, "marsh_8_mist_drift.gif")
    if ff:
        subprocess.run([ff, "-y", "-framerate", "10", "-i", os.path.join(frames_dir, "f%03d.png"),
                        "-vf", "split[a][b];[a]palettegen[p];[b][p]paletteuse", gif], check=False)
        shutil.copy(os.path.join(frames_dir, f"f{n // 2:03d}.png"), os.path.join(SKETCH_DIR, "marsh_8_mist_drift_frame.png"))
        shutil.rmtree(frames_dir, ignore_errors=True)
        print("gif", gif)
    else:
        print("ffmpeg not found; frames in", frames_dir)


main()
