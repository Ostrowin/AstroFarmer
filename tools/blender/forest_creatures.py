"""Modele stworzeń Grzybowego Lasu do gry (wg zaakceptowanych szkiców stage1_*).

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/forest_creatures.py

Zapisuje art/models/forest/:
  sporebat.glb      - węzły Body, WingL, WingR (oś skrzydła = barki; machanie w kodzie: obrót wokół osi Z w Godocie)
  cocoon.glb        - kokon z grzybni (z niego reżyser wypuszcza stworzenia)
  rot_growths.glb   - narośla grzybów do przyczepienia na grzbiecie zarażonego zwierzęcia (Rotling)
  mycelium_fiber.glb- znajdźka: kłębek świecących nitek
  spore_tick.glb    - kleszcz zarodnikowy (świecące woreczki z zarodnikami na odwłoku)
Przód modeli = -Y w Blenderze (= +Z w Godocie... po eksporcie glTF: Blender -Y -> Godot +Z).
"""
import bpy, math, os, random, sys
from mathutils import Vector, Matrix
from mathutils.noise import noise as pnoise

sys.path.insert(0, os.path.dirname(__file__))
import stage1_sketch as s1  # noqa: E402  (materiały i funkcje szkiców)
import forest_props as fp  # noqa: E402

OUT = fp.OUT
Builder, tube, lathe, sphere = fp.Builder, fp.tube, fp.lathe, s1.sphere


def sporebat_parts():
    """Ciało (z głową, uszami, oczami, nóżkami) i dwa skrzydła z początkiem układu w barku."""
    b = Builder([])
    lathe(b, [(0.0, 0.2), (0.12, 0.19), (0.2, 0.12), (0.22, 0.02), (0.2, -0.02)], "BatSkin", Matrix(), 20,
          lambda u, v, p: (1.0, 1.0, 1.0, 1) if pnoise(p * 30) < 0.35 else (1.8, 1.5, 2.0, 1))
    lathe(b, [(0.2, -0.02), (0.1, 0.0), (0.0, 0.01)], "BatGlow", Matrix(), 20, flip=True)
    sphere(b, Vector((0, 0, -0.08)), 0.1, "BatSkin", 1.0, 1.3, 0.8)
    sphere(b, Vector((0, -0.17, -0.02)), 0.07, "BatSkin")
    for s in (-1, 1):
        sphere(b, Vector((0.03 * s, -0.23, 0.0)), 0.014, "BatGlow")
        tube(b, [Vector((0.035 * s, -0.17, 0.03)), Vector((0.07 * s, -0.16, 0.11))], [0.025, 0.004], "BatSkin", seg=6)
        tube(b, [Vector((0.04 * s, 0.08, -0.12)), Vector((0.05 * s, 0.14, -0.2))], [0.012, 0.006], "BatSkin", seg=5)
    body = b.finish("Body")
    wings = []
    for s, nm in ((-1, "WingL"), (1, "WingR")):
        w = Builder([])
        shoulder = Vector((0.16 * s, -0.02, 0.02))
        fingers = [Vector((0.62 * s, -0.12, 0.12)), Vector((0.66 * s, 0.1, 0.02)), Vector((0.5 * s, 0.26, -0.05))]
        elbow = shoulder.lerp(fingers[0], 0.45) + Vector((0, -0.04, 0.05))
        o = shoulder
        tube(w, [shoulder - o, elbow - o], [0.022, 0.016], "BatSkin", seg=6)
        for f in fingers:
            tube(w, [elbow - o, f - o], [0.012, 0.004], "BatSkin", seg=5)
        rim = [shoulder - o, fingers[0] - o, fingers[1] - o, fingers[2] - o, Vector((0.1 * s, 0.14, -0.03)) - o]
        el = elbow - o

        def membrane(u, v, rim=rim, el=el):
            fi = v * (len(rim) - 1)
            i = min(int(fi), len(rim) - 2)
            k = fi - i
            edge = rim[i].lerp(rim[i + 1], k)
            edge = edge.lerp(el, math.sin(k * math.pi) * 0.15)
            return el.lerp(edge, u)

        w.grid(membrane, 4, 24, "BatMembrane",
               color=lambda u, v, p: (1.0, 1.0, 1.0, 1) if (v * 4) % 1 > 0.06 else (0.5, 0.5, 0.6, 1))
        obj = w.finish(nm)
        obj.location = shoulder
        wings.append(obj)
    return [body] + wings


def fiber_tangle():
    b = Builder([])
    rng = random.Random(7)
    for k in range(16):
        pts = []
        a0 = rng.uniform(0, math.tau); e0 = rng.uniform(-1, 1)
        for i in range(12):
            t = i / 11
            a = a0 + t * rng.uniform(3, 6)
            e = e0 + math.sin(t * 5 + k) * 0.8
            r = 0.12 + 0.03 * math.sin(t * 9 + k)
            pts.append(Vector((math.cos(a) * math.cos(e) * r, math.sin(a) * math.cos(e) * r, 0.14 + math.sin(e) * r)))
        tube(b, pts, [0.008] * 12, "ThreadGlow" if k % 3 == 0 else "Thread", seg=4)
    return b.finish("MyceliumFiber")


def export(objs, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_vertex_color="NAME", export_vertex_color_name="Col")
    print("exported", filename)


def main():
    os.makedirs(OUT, exist_ok=True)
    export(sporebat_parts(), "sporebat.glb")
    c = s1.cocoon("Cocoon")
    export([c], "cocoon.glb")
    g = s1.growths("RotGrowths", [(Vector((0, 0, 0.0)), Vector((0, 0.15, 1))), (Vector((0.18, 0.08, -0.08)), Vector((1, 0, 0.5))),
                                  (Vector((-0.18, 0.05, -0.08)), Vector((-1, 0, 0.5))), (Vector((0, 0.25, -0.05)), Vector((0, 1, 0.6)))], 2, 0.22)
    export([g], "rot_growths.glb")
    export([fiber_tangle()], "mycelium_fiber.glb")
    export([s1.spore_tick("SporeTick")], "spore_tick.glb")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(fp.ROOT, "art", "source", "forest_creatures.blend"))


main()
