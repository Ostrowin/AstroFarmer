"""Animacje farmera (Run, Sprint, Idle, Jump, Dash) liczone proceduralnie i zapisywane jako klatki kluczowe.
Shoot zostaje ręczny (gra nakłada go tylko na górę ciała).

Uruchom (Blender 5.2, bez okna):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b art/source/player.blend -P tools/blender/player_locomotion.py
  (dodaj `-- --no-export`, żeby tylko zapisać .blend bez eksportu player.glb)

Co robi:
  * stare akcje zostają w pliku jako <nazwa>_old (fake user, do porównania),
  * nowe akcje trafiają na ścieżki NLA o tych samych nazwach (eksport NLA_TRACKS),
  * Idle, Jump, Dash: pozy kluczowe (base / keyed) albo funkcja czasu (idle_pose) przez apply_pose,
  * zapisuje art/source/player.blend i eksportuje art/models/player.glb.

Jak liczone (w miejscu, gra przesuwa postać sama):
  * stopa w fazie podporu stoi w miejscu na ziemi: względem bioder cofa się dokładnie z prędkością
    biegu (Run 5 m/s, Sprint 8,5 m/s = prędkości z player.gd), więc przy playback 1.0 nic się nie ślizga;
    toczy się z pięty na palce (obrót wokół pięty / palców, podeszwa z siatki butów),
  * w fazie przenoszenia kostka leci po krzywej Hermite'a (pięta pod pośladek, kolano do przodu),
  * kolano i udo z analitycznego IK dwóch kości (kolano celuje do przodu),
  * biodra: podskok (najniżej w połowie podporu), skręt i opadanie miednicy po stronie nogi w powietrzu,
  * tułów pochylony do biegu, barki skręcają się przeciwnie do bioder, głowa patrzy prosto,
  * ręce machają przeciwnie do nóg, łokcie zgięte, dłonie lekko do środka.
Układ szkieletu: Z w górę, przód = -Y, lewa strona = +X (kości .L).
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB = os.path.join(ROOT, "art", "models", "player.glb")
FPS = 24

# Podeszwa buta względem kostki (z siatki: pięta 4,5 cm za, palce 12,6 cm przed, kostka 13 cm nad ziemią).
ANKLE_H = 0.13
HEEL = 0.045
TOE = 0.126

RUN = {
    "name": "Run", "frames": 16, "speed": 5.0, "stance": 3.0,
    "strike_pitch": -14.0, "off_pitch": 28.0,
    # (czas w klatkach, przód m, wysokość kostki m, pochylenie stopy °; + = palce w dół)
    "swing": [(4.5, -0.42, 0.30, 50.0), (6.5, -0.30, 0.50, 40.0), (8.5, 0.00, 0.52, 20.0),
              (10.5, 0.28, 0.42, 5.0), (12.5, 0.41, 0.27, -8.0), (14.5, 0.39, 0.17, -13.0)],
    "hip_drop": -0.065, "bob": 0.035, "hip_yaw": 9.0, "hip_roll": 4.0,
    "lean": (4.0, 6.0, 5.0), "chest_yaw": 7.0, "head_nod": 2.0,
    "arm_mid": 4.0, "arm_swing": 34.0, "elbow": 70.0, "elbow_swing": 4.0, "arm_out": 14.0, "hand_in": 0.12,
}
SPRINT = {
    "name": "Sprint", "frames": 12, "speed": 8.5, "stance": 2.0,
    "strike_pitch": -12.0, "off_pitch": 32.0,
    "swing": [(3.2, -0.52, 0.36, 55.0), (4.6, -0.38, 0.62, 45.0), (6.2, -0.02, 0.62, 22.0),
              (7.8, 0.32, 0.48, 2.0), (9.4, 0.47, 0.30, -9.0), (10.9, 0.43, 0.17, -13.0)],
    "hip_drop": -0.085, "bob": 0.045, "hip_yaw": 11.0, "hip_roll": 4.0,
    "lean": (7.0, 8.0, 6.0), "chest_yaw": 9.0, "head_nod": 2.5,
    "arm_mid": 8.0, "arm_swing": 46.0, "elbow": 80.0, "elbow_swing": 4.0, "arm_out": 12.0, "hand_in": 0.12,
}

rig = bpy.data.objects["PlayerRig"]
pose = rig.pose
REST = {pb.name: pb.bone.matrix_local.to_3x3() for pb in pose.bones}
REST_HEAD = {pb.name: pb.bone.head_local.copy() for pb in pose.bones}
LEN = {pb.name: pb.bone.length for pb in pose.bones}


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def update():
    bpy.context.view_layer.update()


def set_rot(name, rot, loc=None):
    """Ustawia orientację kości w przestrzeni szkieletu (pozycja z rodzica albo podana)."""
    update()
    pb = pose.bones[name]
    t = loc if loc is not None else pb.matrix.translation.copy()
    pb.matrix = Matrix.Translation(t) @ rot.to_4x4()


def aim(name, direction, delta):
    """Kość celuje w `direction`; skręt jak w spoczynku obróconym o `delta` (minimalny obrót osi Y)."""
    r0 = delta @ REST[name]
    q = r0.col[1].normalized().rotation_difference(direction.normalized())
    set_rot(name, q.to_matrix() @ r0)


def head_of(name):
    update()
    return pose.bones[name].matrix.translation.copy()


def rot_uz(u, z, deg):
    """Obrót wektora (przód, góra) o kąt stopy (+ = palce w dół)."""
    a = math.radians(deg)
    return (u * math.cos(a) + z * math.sin(a), -u * math.sin(a) + z * math.cos(a))


def hermite(keys, t):
    """Krzywa przez punkty (czas, wartości...) z pochodnymi Catmulla-Roma."""
    for i in range(len(keys) - 1):
        t0, t1 = keys[i][0], keys[i + 1][0]
        if t0 <= t <= t1:
            break
    def tangent(j):
        a, b = keys[max(j - 1, 0)], keys[min(j + 1, len(keys) - 1)]
        return [(vb - va) / (b[0] - a[0]) for va, vb in zip(a[1:], b[1:])]
    p0, p1 = keys[i][1:], keys[i + 1][1:]
    m0, m1 = tangent(i), tangent(i + 1)
    h = t1 - t0
    s = (t - t0) / h
    h00, h10, h01, h11 = 2*s**3 - 3*s**2 + 1, s**3 - 2*s**2 + s, -2*s**3 + 3*s**2, s**3 - s**2
    return [h00*a + h10*h*ma + h01*b + h11*h*mb for a, b, ma, mb in zip(p0, p1, m0, m1)]


def stance_state(p, t):
    """Faza podporu: stopa przyklejona do ziemi. Zwraca (przód kostki, wysokość kostki, pochylenie)."""
    S = p["stance"]
    step = p["speed"] / FPS
    ground = step * (S / 2.0 - t)  # gdzie byłaby kostka przy płaskiej stopie
    if t < 0.35 * S:
        pitch = p["strike_pitch"] * (1.0 - t / (0.35 * S)) ** 2
    elif t > 0.6 * S:
        pitch = p["off_pitch"] * ((t - 0.6 * S) / (0.4 * S)) ** 2
    else:
        pitch = 0.0
    if pitch < 0.0:  # palce w górę: obrót wokół pięty
        du, dz = rot_uz(HEEL, ANKLE_H, pitch)
        return ground - HEEL + du, dz, pitch
    du, dz = rot_uz(-TOE, ANKLE_H, pitch)  # palce w dół: obrót wokół palców
    return ground + TOE + du, dz, pitch


def foot_state(p, t):
    N, S = p["frames"], p["stance"]
    t = t % N
    if t <= S:
        return stance_state(p, t)
    end = stance_state(p, S)
    start = stance_state(p, 0.0)
    keys = [(S, *end)] + [tuple(k) for k in p["swing"]] + [(float(N), *start)]
    return tuple(hermite(keys, t))


def two_bone_ik(hip, ankle, l1, l2, pole):
    d_vec = ankle - hip
    d = min(d_vec.length, (l1 + l2) * 0.999)
    direction = d_vec.normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    side = (pole - direction * pole.dot(direction)).normalized()
    knee = hip + direction * a + side * h
    return knee, hip + direction * d


def apply_pose(P):
    """Układa całą pozę z płaskich parametrów (kąty w stopniach, odległości w metrach):
    hx, hz: przesunięcie bioder; hyaw, hroll, hlean: skręt, przechył, pochylenie bioder;
    syaw, slean: kręgosłup; cyaw, clean: klatka (pochylenia sumują się w dół łańcucha);
    neck: szyja (bezwzględnie, + = do przodu); hdyaw, hdpitch: głowa (bezwzględnie, 0 = prosto);
    na stronę X = L/R: Xsw wymach ramienia (+ = do przodu), Xel zgięcie łokcia, Xout odwiedzenie,
    Xin dłoń do środka; Xu, Xz kostka (przód, wysokość), Xx kostka w bok (|x|), Xp stopa
    (+ = palce w dół), Xtoe stopa na zewnątrz."""
    for pb in pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    d_hips = R("Z", P["hyaw"]) @ R("Y", P["hroll"]) @ R("X", P["hlean"])
    set_rot("hips", d_hips @ REST["hips"], REST_HEAD["hips"] + Vector((P["hx"], 0, P["hz"])))
    d_spine = R("Z", P["syaw"]) @ R("X", P["hlean"] + P["slean"])
    set_rot("spine", d_spine @ REST["spine"])
    d_chest = R("Z", P["cyaw"]) @ R("X", P["hlean"] + P["slean"] + P["clean"])
    set_rot("chest", d_chest @ REST["chest"])
    set_rot("neck", R("Z", P["hdyaw"] * 0.4) @ R("X", P["neck"]) @ REST["neck"])
    set_rot("head", R("Z", P["hdyaw"]) @ R("X", P["hdpitch"]) @ REST["head"])
    for side, s in (("L", 1.0), ("R", -1.0)):
        swing, elbow, out = P[side + "sw"], P[side + "el"], math.radians(P[side + "out"])
        base = Vector((s * math.sin(out), 0.0, -math.cos(out)))
        aim("upper_arm." + side, d_chest @ (R("X", -swing) @ base), d_chest)
        fore = R("X", -(swing + elbow)) @ base
        fore.x -= s * P[side + "in"] * math.sin(math.radians(elbow))
        aim("forearm." + side, d_chest @ fore, d_chest)
    for side, s in (("L", 1.0), ("R", -1.0)):
        hip = head_of("thigh." + side)
        ankle = Vector((s * P[side + "x"], -P[side + "u"], P[side + "z"]))
        pole = d_hips @ Vector((s * 0.12, -1.0, 0.0))
        knee, ankle = two_bone_ik(hip, ankle, LEN["thigh." + side], LEN["shin." + side], pole)
        aim("thigh." + side, knee - hip, d_hips)
        aim("shin." + side, ankle - knee, d_hips)
        set_rot("foot." + side, R("Z", s * P[side + "toe"]) @ R("X", P[side + "p"]) @ REST["foot." + side])
    update()


ANKLE_X = abs(REST_HEAD["foot.L"].x)


def locomotion(p, t):
    """Parametry pozy biegu / sprintu w chwili t (klatki)."""
    N, S = p["frames"], p["stance"]
    phi = 2 * math.pi * t / N
    flight_mid = (S + N / 2.0) / 2.0
    lean_h, lean_s, lean_c = p["lean"]
    hip_yaw = -p["hip_yaw"] * math.cos(phi)              # lewe biodro do przodu, gdy lewa noga z przodu
    chest_yaw = p["chest_yaw"] * math.cos(phi - 0.25)    # barki przeciwnie do bioder
    P = {
        "hx": 0.0, "hz": p["hip_drop"] + p["bob"] * math.cos(2 * math.pi * (t - flight_mid) / (N / 2.0)),
        "hyaw": hip_yaw, "hroll": -p["hip_roll"] * math.cos(2 * math.pi * (t - S / 2.0) / N), "hlean": lean_h,
        "syaw": (hip_yaw + chest_yaw) * 0.2, "slean": lean_s, "cyaw": chest_yaw, "clean": lean_c,
        "neck": (lean_h + lean_s + lean_c) * 0.4, "hdyaw": 0.0,
        "hdpitch": p["head_nod"] * math.cos(2 * math.pi * (t - S / 2.0) / (N / 2.0)),  # głowa prosto
    }
    arm_phase = 2 * math.pi * (t - 1.0) / N              # ręce przeciwnie do nóg, lekko spóźnione
    for side, offset in (("L", 0.0), ("R", N / 2.0)):
        forward = -math.cos(arm_phase) if side == "L" else math.cos(arm_phase)
        u, z, pitch = foot_state(p, t + offset)
        P.update({side + "sw": p["arm_mid"] + p["arm_swing"] * forward,
                  side + "el": p["elbow"] + p["elbow_swing"] * max(forward, 0.0),
                  side + "out": p["arm_out"], side + "in": p["hand_in"],
                  side + "u": u, side + "z": z, side + "x": ANKLE_X * 0.92, side + "p": pitch, side + "toe": 5.0})
    return P


def keyed(keys, t):
    """Parametry pozy z póz kluczowych [(czas, {parametry})] po krzywej Catmulla-Roma."""
    names = sorted(keys[0][1])
    table = [(k[0], *[k[1][n] for n in names]) for k in keys]
    t = min(max(t, keys[0][0]), keys[-1][0])
    return dict(zip(names, hermite(table, t)))


def pose_frame(p, t):
    apply_pose(p["pose"](p, t) if "pose" in p else locomotion(p, t))


def build(p):
    name = p["name"]
    old = bpy.data.actions.get(name)
    if old and not bpy.data.actions.get(name + "_old"):
        old.name = name + "_old"
        old.use_fake_user = True
    elif old:
        bpy.data.actions.remove(old)
    N = p["frames"]
    # 1) Pozy liczone bez żadnej animacji na szkielecie (żeby ewaluacja akcji ich nie nadpisała).
    rig.animation_data.action = None
    rig.animation_data.use_nla = False
    frames = []
    prev = {}
    last = N + 1 if p.get("loop", True) else N
    for f in range(1, last + 1):
        pose_frame(p, float(f - 1))
        values = {}
        for pb in pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in prev:
                q.make_compatible(prev[pb.name])
            prev[pb.name] = q
            values[pb.name] = (q, pb.location.copy())
        frames.append((f, values))
    rig.animation_data.use_nla = True
    for pb in pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    # 2) Krzywe zapisane wprost do nowej akcji.
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for pb in pose.bones:
        for path, size, pick in (("rotation_quaternion", 4, 0), ("location", 3, 1)):
            data_path = 'pose.bones["%s"].%s' % (pb.name, path)
            for i in range(size):
                fc = act.fcurve_ensure_for_datablock(rig, data_path, index=i, group_name=pb.name)
                for f, values in frames:
                    k = fc.keyframe_points.insert(f, values[pb.name][pick][i], options={"FAST"})
                    k.interpolation = "LINEAR"
                fc.update()
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        if track.name == name:
            strip = track.strips[0]
            strip.action = act
            try:
                strip.action_slot = act.slots[0]
            except Exception:
                pass
            strip.action_frame_start = 1
            strip.action_frame_end = last
            strip.frame_end_ui = last
            print("STRIP", name, strip.frame_start, strip.frame_end, strip.action.name)
    return act


def export():
    for o in bpy.context.scene.objects:
        o.select_set(o.name in ("PlayerRig", "Player_Mesh"))
    bpy.context.view_layer.objects.active = rig
    rig.animation_data.action = bpy.data.actions.get("Idle")
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_yup=True)
    print("EXPORTED", GLB)


def base(**over):
    """Neutralna poza stojąca; nadpisania jako parametry apply_pose (Lu, Rsw, ...)."""
    P = {"hx": 0.0, "hz": 0.0, "hyaw": 0.0, "hroll": 0.0, "hlean": 0.0, "syaw": 0.0, "slean": 0.0,
         "cyaw": 0.0, "clean": 0.0, "neck": 0.0, "hdyaw": 0.0, "hdpitch": 0.0}
    for side in ("L", "R"):
        P.update({side + "sw": 4.0, side + "el": 14.0, side + "out": 9.0, side + "in": 0.05,
                  side + "u": 0.0, side + "z": ANKLE_H, side + "x": ANKLE_X * 1.2, side + "p": 0.0, side + "toe": 8.0})
    P.update(over)
    return P


def both(prefix_values):
    """{"sw": 30} -> {"Lsw": 30, "Rsw": 30}"""
    out = {}
    for k, v in prefix_values.items():
        out["L" + k] = v
        out["R" + k] = v
    return out


def idle_pose(p, t):
    """Oddech (klatka w górę i w tył), przenoszenie ciężaru z nogi na nogę, rozglądanie się."""
    w = 2 * math.pi * t / p["frames"]
    breath = math.sin(w)
    sway = math.sin(w + 0.5)
    P = base(hx=0.018 * sway, hz=-0.018 + 0.003 * breath, hroll=-2.0 * sway, hyaw=1.5 * math.sin(w + 1.2),
             slean=1.0, clean=1.0 - 1.6 * breath, cyaw=-1.2 * math.sin(w + 1.2), neck=2.0 - 0.6 * breath,
             hdyaw=6.0 * math.sin(w - 0.8), hdpitch=-1.0 + 1.5 * math.sin(2 * w))
    P.update({"Lu": 0.03, "Ru": -0.03})
    for side, s in (("L", 1.0), ("R", -1.0)):
        P[side + "sw"] = 4.0 + 1.5 * breath + 1.0 * s * sway
        P[side + "out"] = 9.0 + 1.2 * breath
        P[side + "el"] = 14.0 + 3.0 * breath
    return P


IDLE = {"name": "Idle", "frames": 96, "pose": idle_pose}

# Skok: gra włącza go już w powietrzu, nie zapętla (zostaje ostatnia klatka do lądowania).
JUMP = {"name": "Jump", "frames": 14, "loop": False, "pose": lambda p, t: keyed([
    (0.0, base(hz=0.02, hlean=-2.0, clean=-3.0, neck=2.0, hdpitch=-4.0,
               Lsw=100.0, Lel=25.0, Lout=24.0, Rsw=80.0, Rel=30.0, Rout=28.0,
               Lu=0.18, Lz=0.48, Lp=25.0, Ru=-0.28, Rz=0.40, Rp=45.0)),
    (6.0, base(hz=0.04, hlean=4.0, slean=2.0, hdpitch=2.0,
               **both({"sw": 40.0, "el": 35.0, "out": 62.0}),
               Lu=0.15, Lz=0.52, Lp=20.0, Ru=-0.02, Rz=0.50, Rp=25.0)),
    (13.0, base(hlean=5.0, slean=3.0, clean=2.0, neck=2.0, hdpitch=-3.0,
                **both({"sw": 28.0, "el": 25.0, "out": 40.0}),
                Lu=0.14, Lz=0.20, Lp=12.0, Ru=-0.10, Rz=0.17, Rp=18.0)),
], t)}

# Dash trwa w grze 0,18 s: poza docelowa już w 2. klatce, potem tylko lekko osiada.
DASH = {"name": "Dash", "frames": 8, "loop": False, "pose": lambda p, t: keyed([
    (0.0, base(hz=-0.04, hlean=6.0, slean=5.0, clean=4.0, neck=4.0,
               **both({"sw": 10.0, "el": 50.0, "out": 14.0}),
               Lu=0.10, Lz=0.20, Lp=10.0, Ru=-0.20, Rz=0.25, Rp=30.0)),
    (2.0, base(hz=-0.10, hlean=14.0, slean=10.0, clean=6.0, neck=8.0, hdpitch=-3.0, hyaw=-4.0, cyaw=5.0,
               **both({"sw": -55.0, "el": 15.0, "out": 22.0, "in": 0.0}),
               Lu=0.32, Lz=0.22, Lp=5.0, Ru=-0.55, Rz=0.32, Rp=50.0)),
    (7.0, base(hz=-0.09, hlean=13.0, slean=9.0, clean=6.0, neck=8.0, hdpitch=-3.0, hyaw=-3.0, cyaw=4.0,
               **both({"sw": -45.0, "el": 25.0, "out": 20.0, "in": 0.0}),
               Lu=0.28, Lz=0.20, Lp=8.0, Ru=-0.50, Rz=0.30, Rp=45.0)),
], t)}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    saved_action = rig.animation_data.action
    for params in (RUN, SPRINT, IDLE, JUMP, DASH):
        build(params)
    rig.animation_data.action = saved_action
    bpy.ops.wm.save_mainfile()
    print("SAVED", bpy.data.filepath)
    if "--no-export" not in args:
        export()
