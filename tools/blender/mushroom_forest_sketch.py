"""Szkic Grzybowego Lasu (etap 1, "Pod Kapeluszami Olbrzymów"): bryły + rendery do akceptacji.

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/mushroom_forest_sketch.py -- [views...]

Bez argumentów renderuje wszystkie widoki. Widoki: day, gills, cliff, canopy, night, cliffnight, pulse.
Env SKETCH_FAST=1 = mały podgląd (szybko).
Wynik: art/source/sketches/mushroom_*.png (+ mushroom_pulse.gif), źródło art/source/mushroom_forest.blend.

Co jest w szkicu:
  - Towercap: olbrzymie grzyby 30-45 m, kapelusze 22-36 m szerokości zamykają niebo (stały półmrok),
    blaszki pod kapeluszem świecą turkusem, z blaszek opadają świecące zarodniki.
  - Bellcap: średnie grzyby 6-12 m z dzwonowatym kapeluszem, blaszki magenta.
  - Shelfcap: nowe grzyby-półki na klifach (bursztynowy spód), można po nich wskakiwać na górę;
    z niektórych zwisają świecące nitki.
  - Glowcap: małe kępki świecących grzybków na ziemi.
  - Grzybnia: świecące żyłki na ziemi, z "serc" (węzłów) co jakiś czas rozchodzi się fala światła.
  - Płytka woda (kałuże), mgła, smugi światła przez szczeliny między kapeluszami.
"""
import bpy, bmesh, math, os, random, sys, subprocess, shutil
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SKETCH_DIR = os.path.join(ROOT, "art", "source", "sketches")
FAST = os.environ.get("SKETCH_FAST") == "1"
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rng = random.Random(7)

# ---------------------------------------------------------------- materials

def _bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def mat(name, color, rough=0.7, emit=0.0, emit_color=None, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*(emit_color or color), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


GLOW_MATS = []  # (material, socket, day_value) -> night multiplies


def glow_input(m, sock, value):
    sock.default_value = value
    GLOW_MATS.append((sock, value))


def mat_emit(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    glow_input(m, em.inputs["Strength"], strength)
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def mat_spotted(name, base, spot, spot_glow=0.0, scale=1.2):
    """Kapelusz: kolor bazowy + jasne plamki (voronoi), plamki lekko świecą."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.12
    ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
    ramp.color_ramp.elements[1].position = 0.16
    ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*base, 1)
    mix.inputs["B"].default_value = (*spot, 1)
    nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.65
    if spot_glow > 0:
        b.inputs["Emission Color"].default_value = (*spot, 1)
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        glow_input(m, mul.inputs[1], spot_glow)
        nt.links.new(ramp.outputs["Color"], mul.inputs[0])
        nt.links.new(mul.outputs[0], b.inputs["Emission Strength"])
    return m


def mat_gills(name, base, glow, strength, stripes=56):
    """Blaszki: gęste, nieregularne promieniste paski; najjaśniej w pobliżu brzegu, przy trzonie ciemno.
    Siatka blaszek ma promień ~1 (obiekt skalowany), więc długość współrzędnych obiektu = promień względny."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Roughness"].default_value = 0.8
    b.inputs["Emission Color"].default_value = (*glow, 1)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    at = nt.nodes.new("ShaderNodeMath"); at.operation = "ARCTAN2"
    nt.links.new(sep.outputs["Y"], at.inputs[0]); nt.links.new(sep.outputs["X"], at.inputs[1])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    jit = nt.nodes.new("ShaderNodeMath"); jit.operation = "MULTIPLY_ADD"
    nt.links.new(nz.outputs["Fac"], jit.inputs[0]); jit.inputs[1].default_value = 0.25
    nt.links.new(at.outputs[0], jit.inputs[2])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = stripes
    nt.links.new(jit.outputs[0], mul.inputs[0])
    sn = nt.nodes.new("ShaderNodeMath"); sn.operation = "SINE"
    nt.links.new(mul.outputs[0], sn.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1; mr.inputs["From Max"].default_value = 1
    mr.inputs["To Min"].default_value = 0.45; mr.inputs["To Max"].default_value = 1.0
    nt.links.new(sn.outputs[0], mr.inputs["Value"])
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    rad = nt.nodes.new("ShaderNodeValToRGB")
    e = rad.color_ramp.elements
    e[0].position = 0.2; e[0].color = (0.05, 0.05, 0.05, 1)
    e[1].position = 0.97; e[1].color = (0.35, 0.35, 0.35, 1)
    e.new(0.78).color = (1, 1, 1, 1)
    nt.links.new(ln.outputs["Value"], rad.inputs["Fac"])
    m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY"
    nt.links.new(mr.outputs["Result"], m1.inputs[0]); nt.links.new(rad.outputs["Color"], m1.inputs[1])
    st = nt.nodes.new("ShaderNodeMath"); st.operation = "MULTIPLY"
    glow_input(m, st.inputs[1], strength)
    nt.links.new(m1.outputs[0], st.inputs[0])
    nt.links.new(st.outputs[0], b.inputs["Emission Strength"])
    return m


def mat_underglow(name, top, glow, strength):
    """Grzyb-półka: góra matowa, spód (normalna w dół) świeci, z porami."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*top, 1)
    b.inputs["Roughness"].default_value = 0.75
    b.inputs["Emission Color"].default_value = (*glow, 1)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.1; mr.inputs["From Max"].default_value = -0.6
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 6
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    pores = nt.nodes.new("ShaderNodeMapRange")
    pores.inputs["From Min"].default_value = 0.05; pores.inputs["From Max"].default_value = 0.35
    pores.inputs["To Min"].default_value = 0.3; pores.inputs["To Max"].default_value = 1.0
    nt.links.new(vor.outputs["Distance"], pores.inputs["Value"])
    m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY"
    nt.links.new(mr.outputs["Result"], m1.inputs[0]); nt.links.new(pores.outputs["Result"], m1.inputs[1])
    m2 = nt.nodes.new("ShaderNodeMath"); m2.operation = "MULTIPLY"
    glow_input(m, m2.inputs[1], strength)
    nt.links.new(m1.outputs[0], m2.inputs[0])
    nt.links.new(m2.outputs[0], b.inputs["Emission Strength"])
    return m


PULSE_PHASES = []  # value sockets (phase in metres) for the mycelium pulse


def mat_mycelium(name, color, base_glow, pulse_glow, phase):
    """Grzybnia: słabe stałe świecenie + pierścień fali od środka obiektu (serca)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (0.06, 0.08, 0.1, 1)
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Emission Color"].default_value = (*color, 1)
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    val = nt.nodes.new("ShaderNodeValue"); val.outputs[0].default_value = phase
    PULSE_PHASES.append(val)
    d = nt.nodes.new("ShaderNodeMath"); d.operation = "SUBTRACT"
    nt.links.new(ln.outputs["Value"], d.inputs[0]); nt.links.new(val.outputs[0], d.inputs[1])
    sq = nt.nodes.new("ShaderNodeMath"); sq.operation = "MULTIPLY"
    nt.links.new(d.outputs[0], sq.inputs[0]); nt.links.new(d.outputs[0], sq.inputs[1])
    k = nt.nodes.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = -1.4
    nt.links.new(sq.outputs[0], k.inputs[0])
    ex = nt.nodes.new("ShaderNodeMath"); ex.operation = "EXPONENT"
    nt.links.new(k.outputs[0], ex.inputs[0])
    amp = nt.nodes.new("ShaderNodeMath"); amp.operation = "MULTIPLY"
    glow_input(m, amp.inputs[1], pulse_glow)
    nt.links.new(ex.outputs[0], amp.inputs[0])
    add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
    glow_input(m, add.inputs[1], base_glow)
    nt.links.new(amp.outputs[0], add.inputs[0])
    nt.links.new(add.outputs[0], b.inputs["Emission Strength"])
    return m


def mat_ground():
    m = bpy.data.materials.new("ForestFloor")
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.06
    nz.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position = 0.4; e[0].color = (0.035, 0.05, 0.06, 1)   # mokra, ciemna ziemia
    e[1].position = 0.62; e[1].color = (0.09, 0.06, 0.14, 1)   # fioletowy mech
    el = e.new(0.52); el.color = (0.05, 0.09, 0.08, 1)           # zielonkawy mech
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.9
    return m


def mat_rock():
    m = bpy.data.materials.new("CliffRock")
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wv = nt.nodes.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"; wv.bands_direction = "Z"
    wv.inputs["Scale"].default_value = 0.08; wv.inputs["Distortion"].default_value = 6
    nt.links.new(tc.outputs["Generated"] if False else tc.outputs["Object"], wv.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].color = (0.12, 0.1, 0.17, 1); e[1].color = (0.26, 0.21, 0.32, 1)
    nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    # plamy świecącego porostu na skale
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.5
    nz.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    lr = nt.nodes.new("ShaderNodeMapRange")
    lr.inputs["From Min"].default_value = 0.68; lr.inputs["From Max"].default_value = 0.72
    nt.links.new(nz.outputs["Fac"], lr.inputs["Value"])
    b.inputs["Emission Color"].default_value = (0.25, 0.85, 0.55, 1)
    ls = nt.nodes.new("ShaderNodeMath"); ls.operation = "MULTIPLY"
    glow_input(m, ls.inputs[1], 0.12)
    nt.links.new(lr.outputs["Result"], ls.inputs[0])
    nt.links.new(ls.outputs[0], b.inputs["Emission Strength"])
    return m


M_GROUND = mat_ground()
M_ROCK = mat_rock()
M_WATER = mat("Puddle", (0.01, 0.015, 0.03), 0.04)
M_STEM = mat("TowercapStem", (0.5, 0.46, 0.56), 0.7)
M_CAP = mat_spotted("TowercapCap", (0.26, 0.13, 0.36), (0.72, 0.62, 0.86), spot_glow=0.25, scale=0.9)
M_GILL = mat_gills("TowercapGills", (0.04, 0.09, 0.12), (0.05, 0.75, 0.95), 1.2, stripes=140)
M_SPORE = mat_emit("SporeCyan", (0.3, 0.95, 1.0), 7.0)
M_BELL_STEM = mat("BellcapStem", (0.36, 0.42, 0.44), 0.7)
M_BELL_CAP = mat_spotted("BellcapCap", (0.06, 0.2, 0.24), (0.5, 0.85, 0.8), spot_glow=0.3, scale=2.5)
M_BELL_GILL = mat_gills("BellcapGills", (0.15, 0.03, 0.12), (1.0, 0.2, 0.75), 2.2, stripes=60)
M_SPORE_PINK = mat_emit("SporePink", (1.0, 0.35, 0.85), 7.0)
M_SHELF = mat_underglow("ShelfcapAmber", (0.6, 0.36, 0.17), (1.0, 0.55, 0.1), 2.6)
M_THREAD = mat_emit("CliffThread", (0.85, 1.0, 0.45), 3.0)
M_GLOWCAP = mat_emit("Glowcap", (0.4, 1.0, 0.6), 2.5)
M_GLOWSTEM = mat("GlowcapStem", (0.6, 0.65, 0.6), 0.7)
M_HEART = None  # set per network

# ---------------------------------------------------------------- helpers

def link(obj):
    scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if isinstance(material, list):
        for mm in material:
            me.materials.append(mm)
    else:
        me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return link(bpy.data.objects.new(name, me))


def curve_tube(name, pts, radius, radii=None, material=None, res=6):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = res // 2
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        bp = sp.bezier_points[i]
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = radii[i] if radii else 1.0
    if material:
        cu.materials.append(material)
    return link(bpy.data.objects.new(name, cu))


# ---------------------------------------------------------------- ground

def ground():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=160)
    mesh_obj("Ground", bm, M_GROUND)


def puddle(x, y, r):
    bm = bmesh.new()
    res = bmesh.ops.create_circle(bm, cap_ends=True, segments=28, radius=1)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        k = r * (1 + 0.25 * math.sin(a * 3 + x) + 0.15 * math.sin(a * 5 + y))
        v.co.x *= k * 1.4
        v.co.y *= k
    o = mesh_obj("Puddle", bm, M_WATER)
    o.location = (x, y, 0.015)
    o.rotation_euler.z = rng.uniform(0, math.pi)


# ---------------------------------------------------------------- mushrooms

# pozycje kamer szkicu: zarodniki bliżej niż 3 m od kamery są pomijane (inaczej wielkie plamy w kadrze)
CAMS = [Vector(c) for c in ((2.5, -10, 3.0), (-7.5, 13.5, 1.7), (9, 30, 3.5), (-23, -15.5, 3.4), (9, -6, 7))]


def _near_cam(p):
    return any((p - c).length < 3.0 for c in CAMS)


SPORE_BANDS = {}  # materiał bazowy -> [jasny, średni, ciemny] (zarodnik gaśnie w miarę opadania)


def _bands(material, color):
    if material.name not in SPORE_BANDS:
        SPORE_BANDS[material.name] = [mat_emit(material.name + f"_b{i}", color, k)
                                      for i, k in enumerate((3.0, 1.3, 0.45))]
    return SPORE_BANDS[material.name]


def spore_cloud(name, center, radius, top, bottom, count, material, size=(0.006, 0.012),
                fall_mean=6.0, color=(0.3, 0.95, 1.0)):
    """Zarodniki tylko pod kapeluszem: każdy ma własny "czas życia" (długość opadania, rozkład
    wykładniczy: większość gaśnie po kilku metrach, nieliczne lecą nisko). Im dalej od blaszek
    w swoim życiu, tym ciemniejszy (3 pasma jasności)."""
    bms = [bmesh.new() for _ in range(3)]
    for _ in range(count):
        life = min(rng.expovariate(1.0 / fall_mean), top - bottom)
        u = rng.random()                     # jak daleko jest w swoim życiu
        z = top - u * life
        rr = radius * math.sqrt(rng.random()) * (0.95 + 0.15 * u)
        a = rng.uniform(0, math.tau)
        p = Vector((center.x + math.cos(a) * rr, center.y + math.sin(a) * rr, z))
        if _near_cam(p):
            continue
        band = 0 if u < 0.45 else (1 if u < 0.8 else 2)
        bmesh.ops.create_icosphere(bms[band], subdivisions=0, radius=rng.uniform(*size),
                                   matrix=Matrix.Translation(p))
    for bm, m in zip(bms, _bands(material, color)):
        mesh_obj(name, bm, m)


def air_spores(count, box, material, size=(0.008, 0.016)):
    """Zarodniki wiszące w powietrzu wszędzie (jak pyłek w smudze światła), drobne jak piksele."""
    bm = bmesh.new()
    (x0, x1), (y0, y1), (z0, z1) = box
    for _ in range(count):
        z = z0 + (z1 - z0) * rng.random() ** 1.5
        p = Vector((rng.uniform(x0, x1), rng.uniform(y0, y1), z))
        if _near_cam(p):
            continue
        bmesh.ops.create_icosphere(bm, subdivisions=0, radius=rng.uniform(*size),
                                   matrix=Matrix.Translation(p))
    mesh_obj("AirSpores", bm, material)


def towercap(x, y, h, R, base_z=0.0, spores=True, lean=None):
    stem_r = R * 0.075 + 0.6
    lx, ly = lean if lean else (rng.uniform(-1, 1) * h * 0.12, rng.uniform(-1, 1) * h * 0.12)
    p0 = Vector((x, y, base_z))
    p1 = Vector((x + lx * 0.25, y + ly * 0.25, base_z + h * 0.45))
    p2 = Vector((x + lx, y + ly, base_z + h))
    curve_tube("TowercapStem", [p0, p1, p2], stem_r, [1.7, 1.0, 0.85], M_STEM, res=12)
    # pierścień (spódniczka) pod kapeluszem
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=stem_r * 2.6,
                          radius2=stem_r * 1.0, depth=h * 0.06)
    sk = mesh_obj("TowercapRing", bm, M_STEM)
    sk.location = p1.lerp(p2, 0.7)
    # kapelusz
    top = p2 + Vector((0, 0, 0.25 * R))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1)
    bmesh.ops.scale(bm, vec=(R, R, 0.42 * R), verts=bm.verts)
    for v in bm.verts:  # lekko falisty brzeg
        a = math.atan2(v.co.y, v.co.x)
        v.co.z += math.sin(a * 5 + x) * 0.04 * R * (1 - abs(v.co.z) / (0.42 * R))
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, 0, -0.12 * R), plane_no=(0, 0, 1), clear_inner=True)
    cap = mesh_obj("TowercapCap", bm, M_CAP)
    cap.location = top
    tilt = Vector((lx, ly, 0)) * (0.25 / max(h, 1))
    cap.rotation_euler = (-tilt.y, tilt.x, rng.uniform(0, math.tau))
    # blaszki
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=True, segments=64, radius=0.95)
    for v in bm.verts:
        if v.co.length < 0.01:
            v.co.z = 0.18
    gill = mesh_obj("TowercapGills", bm, M_GILL)
    gill.scale = (R, R, R)
    gill.location = (0, 0, -0.12 * R + 0.02)
    gill.parent = cap
    if spores:
        spore_cloud("SporesCyan", Vector((p2.x, p2.y, 0)), R * 0.8, top.z - 0.2 * R, base_z + 0.5,
                    int(500 + R * 40), M_SPORE, size=(0.012, 0.022), fall_mean=7.0)


def bellcap(x, y, h, R, base_z=0.0):
    lx, ly = rng.uniform(-1, 1) * h * 0.15, rng.uniform(-1, 1) * h * 0.15
    p0 = Vector((x, y, base_z)); p2 = Vector((x + lx, y + ly, base_z + h))
    p1 = p0.lerp(p2, 0.5) + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))
    curve_tube("BellcapStem", [p0, p1, p2], 0.18 + R * 0.06, [1.5, 1.0, 0.9], M_BELL_STEM)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1)
    bmesh.ops.scale(bm, vec=(R, R, 1.15 * R), verts=bm.verts)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, 0, 0.05 * R), plane_no=(0, 0, 1), clear_inner=True)
    for v in bm.verts:  # brzeg dzwonu rozchyla się na zewnątrz
        if v.co.z < 0.35 * R:
            f = 1 + (0.35 * R - v.co.z) / R * 0.6
            v.co.x *= f; v.co.y *= f
    cap = mesh_obj("BellcapCap", bm, M_BELL_CAP)
    cap.location = p2 + Vector((0, 0, -0.1 * R))
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=True, segments=36, radius=1.0)
    for v in bm.verts:
        if v.co.length < 0.01:
            v.co.z = 0.6
    g = mesh_obj("BellcapGills", bm, M_BELL_GILL)
    g.scale = (R, R, R)
    g.location = (0, 0, 0.06 * R)
    g.parent = cap
    spore_cloud("SporesPink", Vector((p2.x, p2.y, 0)), R * 0.8, p2.z - 0.2, base_z + 0.3,
                int(120 + R * 60), M_SPORE_PINK, size=(0.005, 0.01), fall_mean=2.5, color=(1.0, 0.35, 0.85))


def glowcap_cluster(x, y, n=7, base_z=0.0, scale=1.0):
    stems = bmesh.new(); caps = bmesh.new()
    for _ in range(n):
        a = rng.uniform(0, math.tau); r = rng.uniform(0, 0.9) * scale
        h = rng.uniform(0.15, 0.6) * scale
        px, py = x + math.cos(a) * r, y + math.sin(a) * r
        bmesh.ops.create_cone(stems, cap_ends=True, segments=8, radius1=0.035 * scale,
                              radius2=0.03 * scale, depth=h,
                              matrix=Matrix.Translation((px, py, base_z + h / 2)))
        cr = rng.uniform(0.06, 0.16) * scale
        m = Matrix.Translation((px, py, base_z + h)) @ Matrix.Diagonal((cr, cr, cr * 0.55, 1))
        bmesh.ops.create_uvsphere(caps, u_segments=12, v_segments=6, radius=1, matrix=m)
    mesh_obj("GlowcapStems", stems, M_GLOWSTEM)
    mesh_obj("GlowcapCaps", caps, M_GLOWCAP)


# ---------------------------------------------------------------- cliff

CLIFF_Y = 56.0
CLIFF_H = 30.0


def cliff():
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.name = "Cliff"
    o.scale = (200, 60, CLIFF_H)
    o.location = (0, CLIFF_Y + 30, CLIFF_H / 2)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=48)
    bpy.ops.object.mode_set(mode="OBJECT")
    tex = bpy.data.textures.new("CliffNoise", "CLOUDS")
    tex.noise_scale = 7
    tex.noise_depth = 3
    d = o.modifiers.new("Rough", "DISPLACE")
    d.texture = tex; d.texture_coords = "GLOBAL"; d.direction = "Y"; d.strength = 4; d.mid_level = 0.5
    o.data.materials.append(M_ROCK)
    o.select_set(False)


def shelfcap(x, z, R, droop=0.0, threads=0, yaw=0.0):
    """Grzyb-półka przyrośnięty do ściany klifu (płaska strona do ściany)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=12, radius=1)
    bmesh.ops.scale(bm, vec=(R, R, 0.28 * R), verts=bm.verts)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, 0.0, 0), plane_no=(0, -1, 0), clear_inner=True)
    for v in bm.verts:  # spód płaski, góra kopułka, brzeg opada
        if v.co.z < 0:
            v.co.z *= 0.35
        v.co.z -= (abs(v.co.y) / R) ** 2 * droop * R
    o = mesh_obj("Shelfcap", bm, M_SHELF)
    # ściana stoi przy y = CLIFF_Y, półka wystaje w -Y
    o.location = (x, CLIFF_Y + 0.8, z)
    o.rotation_euler.z = yaw
    for i in range(threads):
        a = rng.uniform(-0.8, 0.8)
        px = x + math.sin(a) * R * 0.75
        py = CLIFF_Y + 0.8 - math.cos(a) * R * 0.75
        ln = rng.uniform(1.0, 4.5)
        curve_tube("Thread", [Vector((px, py, z - 0.05)),
                              Vector((px + 0.1, py, z - ln * 0.5)),
                              Vector((px, py - 0.1, z - ln))], 0.025, [1, 0.8, 0.4], M_THREAD, res=4)


# ---------------------------------------------------------------- mycelium

BOSS = Vector((-42.0, -34.0, 0.0))   # arena bossa (The Puffking): tu grzybnia jest najgrubsza


def boss_thickness(p):
    """Mnożnik grubości nitek: 1 daleko od bossa, do ~14 przy samej arenie (sznury jak korzenie)."""
    d = (Vector((p.x, p.y, 0)) - BOSS).length
    k = max(0.0, 1.0 - d / 70.0)
    return 1.0 + 9.0 * k ** 2.0


def _hyphae(cu, r, origin, start, ang, steps, width, depth, reach, branch=0.09, maxdepth=4,
            step=(0.3, 0.55), wiggle=0.55):
    """Jedna strzępka: kręta nitka, która co jakiś czas się rozgałęzia (cieńsze odgałęzienia)."""
    pts = [start.copy()]
    p = start.copy()
    for i in range(steps):
        ang += r.uniform(-wiggle, wiggle)
        p = p + Vector((math.cos(ang), math.sin(ang), 0)) * r.uniform(*step)
        pts.append(p.copy())
        if depth < maxdepth and r.random() < branch:
            _hyphae(cu, r, origin, p.copy(), ang + r.choice((-1, 1)) * r.uniform(0.35, 1.1),
                    max(3, int(steps * 0.55)), width * 0.6, depth + 1, reach, branch, maxdepth, step, wiggle)
        if p.length > reach:
            break
    if len(pts) < 2:
        return
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    n = len(pts)
    for i, q in enumerate(pts):
        sp.points[i].co = (q.x, q.y, 0.02, 1)
        sp.points[i].radius = max(0.35, width * (1 - i / n * 0.7)) * boss_thickness(origin + q)


def _thread_curve(name):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.0025        # ~5 mm średnicy przy grubości 1: cieniutkie nitki jak w prawdziwej grzybni
    cu.bevel_resolution = 0
    return cu


def mycelium(cx, cy, reach=14.0, phase=6.0, seed=0, primaries=9, fuzz=35, branch=0.07, maxdepth=3, width=(0.8, 1.3)):
    r = random.Random(seed)
    origin = Vector((cx, cy, 0))
    cu = _thread_curve("Mycelium")
    for k in range(primaries):
        _hyphae(cu, r, origin, Vector((0, 0, 0)), k / primaries * math.tau + r.uniform(-0.2, 0.2),
                int(reach * 2.6), r.uniform(*width), 0, reach, branch=branch, maxdepth=maxdepth)
    for _ in range(fuzz):  # drobny "puch" krótkich strzępek wokół serca
        a = r.uniform(0, math.tau); d = reach * math.sqrt(r.random())
        st = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        if boss_thickness(origin + st) > 2.5:   # przy bossie tylko grube sznury, bez puchu
            continue
        _hyphae(cu, r, origin, st, r.uniform(0, math.tau), r.randint(4, 12), 0.7, 3, reach * 1.2,
                branch=0.15, step=(0.15, 0.35), wiggle=0.8)
    m = mat_mycelium("Mycelium", (0.35, 0.9, 1.0), 0.12, 6.0, phase)
    cu.materials.append(m)
    o = link(bpy.data.objects.new("Mycelium", cu))
    o.location = origin
    # serce grzybni: spłaszczony guz (większy bliżej bossa)
    hs = 0.35 * min(boss_thickness(origin) ** 0.6, 5.0)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1)
    bmesh.ops.scale(bm, vec=(hs, hs, hs * 0.45), verts=bm.verts)
    h = mesh_obj("MyceliumHeart", bm, m)
    h.parent = o


def mycelium_web(count, box, seed=99):
    """Tło: rzadka sieć cienkich nitek po całym dnie lasu, poza sercami (bez fali)."""
    r = random.Random(seed)
    cu = _thread_curve("MyceliumWeb")
    (x0, x1), (y0, y1) = box
    for _ in range(count):
        st = Vector((r.uniform(x0, x1), r.uniform(y0, y1), 0))
        if boss_thickness(st) > 2.5:
            continue
        _hyphae(cu, r, Vector((0, 0, 0)), st, r.uniform(0, math.tau), r.randint(8, 26), 0.8, 2, 1e9,
                branch=0.12, step=(0.25, 0.5), wiggle=0.6)
    m = mat_mycelium("MyceliumWeb", (0.35, 0.9, 1.0), 0.04, 0.0, 1000.0)
    cu.materials.append(m)
    link(bpy.data.objects.new("MyceliumWeb", cu))


def boss_lair():
    """Zapowiedź areny: na wpół zakopana olbrzymia purchawka, do której zbiegają się grube sznury."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co *= 1 + 0.06 * math.sin(a * 7) * (1 - abs(v.co.z))
    bmesh.ops.scale(bm, vec=(5.5, 5.5, 4.2), verts=bm.verts)
    o = mesh_obj("Puffking", bm, mat_spotted("PuffkingSkin", (0.42, 0.38, 0.32), (0.75, 0.7, 0.55),
                                             spot_glow=0.0, scale=3.0))
    o.location = BOSS + Vector((0, 0, 1.2))
    mycelium(BOSS.x, BOSS.y, 60, 9.0, seed=77, primaries=11, fuzz=60, branch=0.035, maxdepth=2, width=(1.8, 2.4))


# ---------------------------------------------------------------- build scene

def build():
    ground()
    cliff()
    for (x, y, r) in [(4, 8, 2.2), (-7, 15, 3.5), (10, 26, 4), (-20, 30, 3), (16, 4, 1.6), (-3, 34, 2.5),
                      (24, 18, 3), (-15, 4, 1.8), (2, 46, 3)]:
        puddle(x, y, r)
    # olbrzymy: (x, y, wysokość, promień kapelusza)
    giants = [(-15, 24, 40, 17), (19, 34, 34, 13), (-36, 44, 44, 18), (6, -14, 38, 15), (-28, -2, 30, 12),
              (33, 8, 36, 14), (42, 42, 30, 11), (-52, 18, 42, 17), (14, 52, 26, 10), (-12, 52, 22, 9)]
    for g in giants:
        towercap(*g)
    for _ in range(18):  # dalszy las, ginący we mgle
        a = rng.uniform(0, math.tau); d = rng.uniform(62, 120)
        x, y = math.cos(a) * d, math.sin(a) * d
        if y > CLIFF_Y - 8:
            continue
        towercap(x, y, rng.uniform(30, 46), rng.uniform(12, 19), spores=False)
    for x in range(-90, 91, 22):  # las na górze klifu
        towercap(x + rng.uniform(-6, 6), CLIFF_Y + rng.uniform(10, 30), rng.uniform(22, 36),
                 rng.uniform(10, 15), base_z=CLIFF_H, spores=False)
    for b in [(7, 44, 10, 2.6), (-7, 47, 8, 2.0), (25, 47, 12, 3.0), (-21, 13, 7, 1.8), (12, 15, 6, 1.6),
              (-4, 22, 5, 1.3), (28, 26, 9, 2.4), (-30, 30, 11, 2.8)]:
        bellcap(*b)
    for _ in range(40):
        glowcap_cluster(rng.uniform(-40, 40), rng.uniform(-20, 54), rng.randint(4, 9))
    # półki na klifie (x, z, promień, opad brzegu, nitki)
    shelves = [(-6, 3.0, 2.4, 0.1, 3), (-2, 6.5, 3.2, 0.15, 4), (-8, 9.5, 2.6, 0.1, 2), (-3, 13, 3.8, 0.2, 5),
               (3, 16.5, 2.8, 0.1, 2), (-1, 20, 4.2, 0.2, 4), (5, 24, 3.0, 0.1, 3), (1, 27.5, 3.5, 0.15, 0),
               (12, 4.5, 2.0, 0.1, 2), (16, 9, 3.0, 0.15, 3), (14, 14, 2.2, 0.1, 0), (19, 18.5, 3.4, 0.2, 4),
               (-16, 6, 2.6, 0.1, 2), (-20, 12, 3.2, 0.15, 3), (-17, 18, 2.4, 0.1, 2), (-22, 23, 3.6, 0.2, 4),
               (28, 7, 2.8, 0.1, 2), (32, 15, 3.6, 0.2, 3), (-32, 9, 3.0, 0.15, 3), (-36, 20, 4.0, 0.2, 4)]
    for s in shelves:
        shelfcap(*s, yaw=rng.uniform(-0.15, 0.15))
    # grzybnia (x, y, zasięg, faza fali w m)
    for i, (x, y, reach, ph) in enumerate([(0, 7, 14, 6.0), (-14, 30, 12, 3.0), (15, 22, 13, 9.0),
                                           (-30, 10, 12, 1.5), (6, 42, 10, 7.0), (24, -4, 12, 4.0),
                                           (-6, -12, 12, 10.0), (-22, -18, 12, 5.0)]):
        mycelium(x, y, reach, ph, seed=i + 3)
    mycelium_web(180, ((-55, 50), (-50, 54)))
    boss_lair()


def lights():
    w = bpy.data.worlds.new("ForestWorld")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.10, 0.08, 0.18, 1)
    bg.inputs["Strength"].default_value = 0.6
    out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.55, 0.5, 0.8, 1)
    vol.inputs["Density"].default_value = 0.012
    vol.inputs["Emission Color"].default_value = (0.4, 0.33, 0.7, 1)
    vol.inputs["Emission Strength"].default_value = 0.0012
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 1.6
    sun.color = (0.75, 0.75, 1.0)
    sun.angle = math.radians(2)
    so = link(bpy.data.objects.new("Sun", sun))
    so.rotation_euler = (math.radians(30), math.radians(-12), math.radians(20))
    # smugi światła przez szczeliny między kapeluszami
    for (x, y, tx, ty) in [(4, 16, 3, 13), (-24, 36, -22, 33), (26, 22, 24, 20), (-2, 40, -3, 43)]:
        sp = bpy.data.lights.new("Shaft", "SPOT")
        sp.energy = 90000
        sp.spot_size = math.radians(7)
        sp.spot_blend = 0.6
        sp.color = (0.85, 0.95, 1.0)
        o = link(bpy.data.objects.new("Shaft", sp))
        o.location = (x, y, 26)
        d = Vector((tx, ty, 0)) - Vector(o.location)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    # rozproszone światło odbite na ścianę klifu (w grze: ambient), żeby półki nie wisiały w próżni
    fl = bpy.data.lights.new("CliffFill", "AREA")
    fl.energy = 1800; fl.size = 60; fl.color = (0.6, 0.55, 1.0)
    fo = link(bpy.data.objects.new("CliffFill", fl))
    fo.location = (0, 20, 22)
    fo.rotation_euler = (Vector((0, CLIFF_Y, 12)) - Vector(fo.location)).to_track_quat("-Z", "Y").to_euler()
    return bg, vol, sun


def setup_render():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    ee = scene.eevee
    for k, v in (("taa_render_samples", 16 if FAST else 48), ("use_raytracing", True),
                 ("volumetric_end", 160.0), ("volumetric_tile_size", "4"),
                 ("use_volumetric_shadows", True), ("volumetric_samples", 64),
                 ("use_shadows", True)):
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
    setup_glare()


def setup_glare():
    try:
        tree = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
        scene.compositing_node_group = tree
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = tree.nodes.new("CompositorNodeRLayers")
        gl = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        for prop, val in (("glare_type", "BLOOM"), ("quality", "HIGH")):
            try:
                setattr(gl, prop, val)
            except Exception:
                pass
        for sname, val in (("Type", "Bloom"), ("Threshold", 1.2), ("Strength", 0.3), ("Size", 0.45),
                           ("Quality", "High")):
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
    path = os.path.join(ROOT, "art", "models", "player.glb")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = next(o for o in new if o.parent is None)
    return root


LAMP = None


def place(player, loc, yaw_deg):
    """Gracz + lampka hełmu (światło lekko za plecami, od strony kamery)."""
    player.location = loc
    player.rotation_euler.z = math.radians(yaw_deg)
    if LAMP:
        LAMP.location = (loc[0] + 0.4, loc[1] - 0.9, loc[2] + 2.4)


def camera():
    cd = bpy.data.cameras.new("Cam")
    cd.clip_end = 400
    return link(bpy.data.objects.new("Cam", cd))


def aim(cam, pos, target, lens):
    cam.location = pos
    cam.data.lens = lens
    d = Vector(target) - Vector(pos)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam


def set_night(night, bg, vol, sun):
    k = 1.6 if night else 1.0
    for sock, v in GLOW_MATS:
        sock.default_value = v * k
    bg.inputs["Color"].default_value = (0.015, 0.015, 0.035, 1) if night else (0.10, 0.08, 0.18, 1)
    bg.inputs["Strength"].default_value = 0.35 if night else 0.6
    sun.energy = 0.15 if night else 1.6
    sun.color = (0.6, 0.6, 1.0) if night else (0.75, 0.75, 1.0)
    vol.inputs["Color"].default_value = (0.35, 0.35, 0.6, 1) if night else (0.55, 0.5, 0.8, 1)
    vol.inputs["Emission Strength"].default_value = 0.00015 if night else 0.0012
    for o in scene.objects:
        if o.name.startswith("CliffFill"):
            o.data.energy = 400 if night else 1800
    for o in scene.objects:
        if o.type == "LIGHT" and o.data.type == "SPOT":
            o.data.energy = 8000 if night else 90000
            o.data.color = (0.6, 0.7, 1.0) if night else (0.85, 0.95, 1.0)


def render(name):
    path = os.path.join(SKETCH_DIR, name)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


def main():
    build()
    bg, vol, sun = lights()
    setup_render()
    player = add_player()
    lamp = bpy.data.lights.new("HelmetLamp", "POINT")
    lamp.energy = 25; lamp.color = (1.0, 0.92, 0.75); lamp.shadow_soft_size = 0.3
    lo = link(bpy.data.objects.new("HelmetLamp", lamp))
    global LAMP
    LAMP = lo
    cam = camera()
    views = ARGV or ["day", "gills", "cliff", "canopy", "night", "cliffnight", "boss", "pulse"]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "source", "mushroom_forest.blend"))

    if "day" in views:
        set_night(False, bg, vol, sun)
        place(player, (0, 0, 0), -10)
        aim(cam, (2.5, -10, 3.0), (-3, 20, 8), 18)
        render("mushroom_1_under_caps_day.png")
    if "gills" in views:
        set_night(False, bg, vol, sun)
        place(player, (-10.5, 17.5, 0), -150)
        aim(cam, (-7.5, 13.5, 1.7), (-15, 25, 30), 16)
        render("mushroom_2_gills_up.png")
    if "cliff" in views:
        set_night(False, bg, vol, sun)
        place(player, (-2.5, 48.5, 0), 0)
        aim(cam, (9, 30, 3.5), (-2, 56, 13), 22)
        render("mushroom_3_cliff_shelves.png")
    if "canopy" in views:
        set_night(False, bg, vol, sun)
        player.location = (0, 0, 0)
        vol.inputs["Density"].default_value = 0.0
        vol.inputs["Emission Strength"].default_value = 0.0
        sun.energy = 3.0
        aim(cam, (120, -115, 105), (-5, 22, 20), 32)
        render("mushroom_4_canopy_overview.png")
        vol.inputs["Density"].default_value = 0.012
        vol.inputs["Emission Strength"].default_value = 0.0012
        sun.energy = 1.6
    if "night" in views:
        set_night(True, bg, vol, sun)
        place(player, (0, 0, 0), -10)
        aim(cam, (2.5, -10, 3.0), (-3, 20, 8), 18)
        render("mushroom_5_under_caps_night.png")
    if "cliffnight" in views:
        set_night(True, bg, vol, sun)
        place(player, (-2.5, 48.5, 0), 0)
        aim(cam, (9, 30, 3.5), (-2, 56, 13), 22)
        render("mushroom_6_cliff_night.png")
    if "boss" in views:
        set_night(False, bg, vol, sun)
        place(player, (-27.5, -20.5, 0), -135)
        aim(cam, (-23, -15.5, 3.4), (-42, -34, 1.0), 20)
        render("mushroom_8_toward_boss.png")
    if "pulse" in views:
        render_pulse(cam, player, bg, vol, sun)


def render_pulse(cam, player, bg, vol, sun):
    """Fala światła przez grzybnię: klatki -> GIF (ffmpeg)."""
    set_night(False, bg, vol, sun)
    place(player, (2.5, 4.0, 0), 160)
    aim(cam, (9, -6, 7), (0, 8, 0), 24)
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x, scene.render.resolution_y = 640, 360
    samples = scene.eevee.taa_render_samples
    scene.eevee.taa_render_samples = 12
    frames_dir = os.path.join(SKETCH_DIR, "_pulse_frames")
    os.makedirs(frames_dir, exist_ok=True)
    n = 12 if FAST else 24
    for i in range(n):
        ph = -1.0 + i / (n - 1) * 17.0
        for j, v in enumerate(PULSE_PHASES):
            v.outputs[0].default_value = ph if j == 0 else (ph + j * 4.3) % 16
        scene.render.filepath = os.path.join(frames_dir, f"f{i:03d}.png")
        bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    scene.eevee.taa_render_samples = samples
    ff = shutil.which("ffmpeg")
    gif = os.path.join(SKETCH_DIR, "mushroom_7_mycelium_pulse.gif")
    if ff:
        subprocess.run([ff, "-y", "-framerate", "10", "-i", os.path.join(frames_dir, "f%03d.png"),
                        "-vf", "split[a][b];[a]palettegen[p];[b][p]paletteuse", gif], check=False)
        shutil.copy(os.path.join(frames_dir, f"f{n // 2:03d}.png"),
                    os.path.join(SKETCH_DIR, "mushroom_7_mycelium_pulse_frame.png"))
        shutil.rmtree(frames_dir, ignore_errors=True)
        print("gif", gif)
    else:
        print("ffmpeg not found; frames in", frames_dir)


main()
