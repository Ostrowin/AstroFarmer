"""Modele maszyn farmy: dron nawadniający, dok drona, traktor z siewnikiem.

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/machines_models.py

Zapisuje art/models/machines/{drone,drone_dock,tractor}.glb oraz art/source/machines_models.blend.
Przód każdego modelu = -Z w Godocie (w Blenderze +Y). Ruchome części to osobne węzły:
  dron:    Rotor0..3 (obrót wokół osi pionowej), TankWater (skalowany w pionie = poziom wody)
  traktor: WheelRL/WheelRR/WheelFL/WheelFR (obrót wokół osi X), FrontAxleL/R (skręt kół),
           Seeder (podnoszenie siewnika), Beacon (migacz), ExhaustTip (punkt dymu), Seat (miejsce gracza)
Szkic z farmerem dla skali: art/source/machines.blend.
"""
import bpy, math, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "machines")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, rough=0.6, metal=0.0, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    return m


ORANGE = mat("Orange", (1.0, 0.42, 0.06), 0.45)
WHITE = mat("White", (0.9, 0.9, 0.88), 0.5)
DARK = mat("MetalDark", (0.12, 0.13, 0.15), 0.5, 0.3)
METAL = mat("Metal", (0.55, 0.57, 0.6), 0.35, 0.8)
TIRE = mat("Tire", (0.06, 0.06, 0.07), 0.9)
YELLOW = mat("Yellow", (1.0, 0.78, 0.1), 0.5)
GLASS = mat("TankGlass", (0.6, 0.85, 1.0), 0.1, 0.0, 0.0, 0.35)
WATER = mat("Water", (0.15, 0.5, 1.0), 0.1, 0.0, 0.3, 0.85)
BLADE = mat("Blade", (0.2, 0.21, 0.23), 0.4, 0.3)
EYE = mat("Eye", (0.2, 0.9, 1.0), 0.3, 0.0, 2.0)
LAMP = mat("Lamp", (1.0, 0.9, 0.6), 0.3, 0.0, 3.0)
BEACON = mat("Beacon", (1.0, 0.5, 0.05), 0.3, 0.0, 3.0)
SOLAR = mat("Solar", (0.08, 0.15, 0.4), 0.2, 0.5)
SEAT = mat("SeatTan", (0.55, 0.35, 0.2), 0.8)


def _finish(o, name, m, parent, bevel):
    o.name = name
    if m:
        o.data.materials.append(m)
    if bevel:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
    if parent:
        o.parent = parent
    return o


def box(name, size, loc, m, parent=None, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, name, m, parent, bevel)


def cyl(name, r, depth, loc, m, parent=None, rot=(0, 0, 0), verts=24, bevel=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    return _finish(o, name, m, parent, bevel)


def sphere(name, r, loc, m, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=24, ring_count=12)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    return _finish(o, name, m, parent, 0)


def torus(name, R, r, loc, m, parent=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot,
                                     major_segments=32, minor_segments=10)
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    return _finish(o, name, m, parent, 0)


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.rotation_euler = rot
    return e


# W skrypcie przód = +X (jak w szkicu); przed eksportem korzeń obracamy o 90°, by przód był +Y.

def make_drone():
    d = empty("Drone")
    sphere("Body", 0.3, (0, 0, 0), WHITE, d, (1, 1, 0.5))
    cyl("Band", 0.305, 0.05, (0, 0, -0.01), ORANGE, d)
    box("Visor", (0.06, 0.26, 0.1), (0.27, 0, 0.04), DARK, d, 0.03)
    sphere("EyeL", 0.025, (0.305, 0.06, 0.05), EYE, d)
    sphere("EyeR", 0.025, (0.305, -0.06, 0.05), EYE, d)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        dx, dy = math.cos(a), math.sin(a)
        box("Arm%d" % i, (0.32, 0.05, 0.035), (dx * 0.33, dy * 0.33, 0.02), DARK, d, 0.012, (0, 0, a))
        torus("Duct%d" % i, 0.17, 0.028, (dx * 0.5, dy * 0.5, 0.03), ORANGE if i < 2 else DARK, d)
        rotor = empty("Rotor%d" % i, (dx * 0.5, dy * 0.5, 0.04), d)
        cyl("Hub%d" % i, 0.03, 0.05, (0, 0, 0), METAL, rotor)
        box("BladeA%d" % i, (0.3, 0.035, 0.008), (0, 0, 0), BLADE, rotor, 0.004, (0.15, 0, 0))
        box("BladeB%d" % i, (0.035, 0.3, 0.008), (0, 0, 0), BLADE, rotor, 0.004, (0, 0.15, 0))
    cyl("TankCapTop", 0.17, 0.04, (0, 0, -0.14), METAL, d)
    cyl("Tank", 0.16, 0.22, (0, 0, -0.27), GLASS, d)
    # Woda: węzeł z punktem zaczepienia na dnie zbiornika (skala Y w Godocie = poziom).
    water = empty("TankWater", (0, 0, -0.38), d)
    cyl("WaterMesh", 0.15, 0.2, (0, 0, 0.1), WATER, water)
    cyl("TankCapBot", 0.17, 0.04, (0, 0, -0.4), METAL, d)
    cyl("Nozzle", 0.05, 0.1, (0, 0, -0.47), DARK, d, r2=0.02)
    for s in (-1, 1):
        box("Skid%d" % s, (0.5, 0.025, 0.025), (0, s * 0.2, -0.45), DARK, d, 0.01)
        box("Leg%d" % s, (0.025, 0.025, 0.3), (0, s * 0.2, -0.3), DARK, d, 0.005, (s * 0.25, 0, 0))
    sphere("Status", 0.03, (-0.2, 0, 0.13), EYE, d)
    return d


def make_dock():
    k = empty("DroneDock")
    cyl("DockPad", 0.45, 0.1, (0, 0, 0.05), DARK, k, verts=8)
    torus("DockRing", 0.36, 0.022, (0, 0, 0.105), YELLOW, k)
    box("PumpBox", (0.22, 0.2, 0.36), (-0.32, 0.3, 0.28), WHITE, k, 0.04)
    box("PumpStripe", (0.23, 0.21, 0.05), (-0.32, 0.3, 0.38), ORANGE, k, 0.01)
    cyl("PumpLight", 0.035, 0.04, (-0.32, 0.3, 0.48), EYE, k)
    return k


def make_tractor():
    t = empty("Tractor")
    box("Chassis", (2.4, 0.7, 0.3), (0.1, 0, 0.55), DARK, t, 0.04)
    box("Hood", (1.25, 0.82, 0.62), (0.75, 0, 0.98), ORANGE, t, 0.12)
    box("HoodStripe", (1.27, 0.2, 0.05), (0.75, 0, 1.3), WHITE, t, 0.02)
    box("Grille", (0.06, 0.6, 0.42), (1.39, 0, 0.92), DARK, t, 0.02)
    for s in (-1, 1):
        cyl("Headlight%d" % s, 0.08, 0.06, (1.42, s * 0.3, 1.13), LAMP, t, (0, math.pi / 2, 0))
        box("SideVent%d" % s, (0.5, 0.02, 0.2), (0.8, s * 0.42, 0.95), DARK, t, 0.01)
    cyl("Exhaust", 0.06, 0.75, (1.05, 0.28, 1.65), DARK, t)
    cyl("ExhaustCap", 0.085, 0.08, (1.05, 0.28, 2.05), METAL, t)
    empty("ExhaustTip", (1.05, 0.28, 2.12), t)
    box("Floor", (0.9, 1.0, 0.08), (-0.45, 0, 0.78), DARK, t, 0.02)
    box("Seat", (0.45, 0.5, 0.14), (-0.55, 0, 1.05), SEAT, t, 0.05)
    box("SeatBack", (0.12, 0.5, 0.5), (-0.78, 0, 1.3), SEAT, t, 0.05)
    box("SeatPost", (0.15, 0.15, 0.25), (-0.55, 0, 0.9), DARK, t, 0.01)
    empty("SeatPoint", (-0.58, 0, 0.3), t)
    cyl("SteerCol", 0.03, 0.55, (-0.02, 0, 1.25), DARK, t, (0, math.radians(-35), 0))
    torus("SteerWheel", 0.17, 0.025, (-0.17, 0, 1.47), DARK, t, (0, math.radians(-55), 0))
    for sx in (-1.0, 0.05):
        for sy in (-1, 1):
            box("Post%d%d" % (int(sx * 10), sy), (0.06, 0.06, 1.45), (sx, sy * 0.62, 1.55), WHITE, t, 0.02)
    box("Roof", (1.35, 1.45, 0.07), (-0.48, 0, 2.3), WHITE, t, 0.03)
    box("Solar", (1.15, 1.25, 0.03), (-0.48, 0, 2.35), SOLAR, t, 0.01)
    cyl("BeaconBase", 0.07, 0.05, (-0.95, 0.55, 2.37), DARK, t)
    sphere("Beacon", 0.07, (-0.95, 0.55, 2.43), BEACON, t, (1, 1, 1.3))
    for s in (-1, 1):
        side = "L" if s > 0 else "R"
        rear = empty("WheelR" + side, (-0.55, s * 0.78, 0.62), t)
        cyl("RearTire" + side, 0.62, 0.38, (0, 0, 0), TIRE, rear, (math.pi / 2, 0, 0), 32, 0.06)
        cyl("RearHub" + side, 0.34, 0.4, (0, s * 0.01, 0), ORANGE, rear, (math.pi / 2, 0, 0), 20)
        cyl("RearCap" + side, 0.12, 0.42, (0, s * 0.02, 0), METAL, rear, (math.pi / 2, 0, 0), 12)
        for k in range(10):
            a = 2 * math.pi * k / 10
            box("Lug%s%d" % (side, k), (0.1, 0.4, 0.07), (math.cos(a) * 0.62, 0, math.sin(a) * 0.62),
                TIRE, rear, 0.01, (0, -a + math.pi / 2, 0))
        box("Fender" + side, (1.05, 0.46, 0.06), (-0.55, s * 0.78, 1.32), ORANGE, t, 0.03)
        axle = empty("FrontAxle" + side, (1.0, s * 0.62, 0.36), t)
        front = empty("WheelF" + side, (0, 0, 0), axle)
        cyl("FrontTire" + side, 0.36, 0.26, (0, 0, 0), TIRE, front, (math.pi / 2, 0, 0), 24, 0.05)
        cyl("FrontHub" + side, 0.18, 0.28, (0, s * 0.01, 0), WHITE, front, (math.pi / 2, 0, 0), 16)
        for k in range(6):  # szprychy: widać, że koło się kręci
            a = 2 * math.pi * k / 6
            box("Spoke%s%d" % (side, k), (0.05, 0.29, 0.05), (math.cos(a) * 0.1, 0, math.sin(a) * 0.1), DARK, front, 0.01)
        for k in range(8):  # bieżnik przednich kół
            a = 2 * math.pi * k / 8
            box("FLug%s%d" % (side, k), (0.07, 0.27, 0.05), (math.cos(a) * 0.36, 0, math.sin(a) * 0.36),
                TIRE, front, 0.01, (0, -a + math.pi / 2, 0))
    # Siewnik: obraca się wokół zaczepu (Seeder), szerokość 3 pól.
    seeder = empty("Seeder", (-1.2, 0, 0.6), t)
    for s in (-1, 1):
        box("Hitch%d" % s, (0.75, 0.06, 0.06), (-0.3, s * 0.25, 0.0), DARK, seeder, 0.01, (0, math.radians(-12), 0))
    box("ToolBar", (0.18, 3.0, 0.16), (-0.75, 0, -0.05), DARK, seeder, 0.03)
    box("Hopper", (0.55, 2.7, 0.42), (-0.85, 0, 0.35), ORANGE, seeder, 0.08)
    box("HopperLid", (0.6, 2.75, 0.05), (-0.85, 0, 0.58), WHITE, seeder, 0.02)
    for i, y in enumerate((-1.0, 0.0, 1.0)):
        cyl("Disc%d" % i, 0.24, 0.04, (-0.75, y, -0.34), METAL, seeder, (math.radians(70), 0, math.radians(20)))
        box("DiscArm%d" % i, (0.06, 0.06, 0.3), (-0.75, y, -0.18), DARK, seeder, 0.01)
        cyl("SeedTube%d" % i, 0.04, 0.45, (-1.05, y, -0.05), DARK, seeder, (0, math.radians(20), 0))
        cyl("Press%d" % i, 0.13, 0.18, (-1.25, y, -0.47), DARK, seeder, (math.pi / 2, 0, 0))
    return t


def export(root, filename):
    root.rotation_euler = (0, 0, math.radians(90))
    bpy.ops.object.select_all(action="DESELECT")
    for o in [root] + list(root.children_recursive):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    print("EXPORTED", path)


drone = make_drone()
dock = make_dock()
tractor = make_tractor()
dock.location.x = 3
tractor.location.x = 7
export(drone, "drone.glb")
dock.location.x = 0
export(dock, "drone_dock.glb")
tractor.location.x = 0
export(tractor, "tractor.glb")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "source", "machines_models.blend"))


# --- Ikona 128×128 (przezroczyste tło) do warsztatu i paska narzędzi --------------
def render_icon(root, filename, target, direction, dist):
    from mathutils import Vector
    for o in scene.objects:
        o.hide_render = o not in [root] + list(root.children_recursive) and o.type != "LIGHT"
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = 128
    scene.view_settings.view_transform = "Standard"
    if not scene.world:
        scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.8, 0.82, 0.86, 1)
    if "IconSun" not in bpy.data.objects:
        sun = bpy.data.lights.new("IconSun", "SUN")
        sun.energy = 3.0
        so = bpy.data.objects.new("IconSun", sun)
        scene.collection.objects.link(so)
        so.rotation_euler = (math.radians(45), 0, math.radians(30))
    cam = bpy.data.objects.get("IconCam")
    if cam is None:
        cam = bpy.data.objects.new("IconCam", bpy.data.cameras.new("IconCam"))
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 50
    d = Vector(direction).normalized()
    cam.location = Vector(target) + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(ROOT, "art", "ui", "icons", filename)
    bpy.ops.render.render(write_still=True)
    print("ICON", filename)


render_icon(drone, "drone_dock.png", (0, 0, -0.12), (0.55, 1.0, 0.5), 2.0)
print("DONE")
