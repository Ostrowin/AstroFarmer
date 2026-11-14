"""Wspólne składanie utworu w SoundCraft (używają go boss_rodeo.py, rodeo_rave.py i stampede.py).

Wejście: nuty (instrument -> [(wysokość, start_beat, długość_beat, velocity)]) i opis
instrumentów: próbki VSCO (strefy samplera), jednorazowe próbki efektów i syntezatory
SoundCraft z wtyczkami. Faza 1 tworzy ścieżki i klipy, faza 2 dopisuje nuty,
zapisuje sesję i zgrywa miks; na koniec ffmpeg robi OGG z normalizacją głośności.
"""
import json, os, subprocess

import star_rodeo as sr

PPQ = 960


def build(name, work, bpm, end_beat, notes, out_ogg, sampled=None, fx_tracks=None, fx_dir="", synths=None,
          reverb=None, master=None, loudness=-14.0, fade=3.0):
    sampled, fx_tracks, synths = sampled or {}, fx_tracks or {}, synths or {}
    os.makedirs(work, exist_ok=True)
    sr.notes = notes
    sr.fix_overlaps()
    delay_ms = round(60000 / bpm * 0.75)

    print("Strefy samplera:")
    plan = []  # (track, kind, cfg, zone|None, notes)
    for inst, cfg in sampled.items():
        if inst not in notes:
            continue
        for z in sr.zones_for(inst, cfg):
            zn = [n for n in notes[inst] if z["low"] <= n[0] <= z["high"]]
            if zn:
                plan.append((f"{inst}_{len(plan):02d}", "sampled", cfg, z, zn))
    for inst, fx in fx_tracks.items():
        if inst in notes:
            cfg = dict(mode="one", attack=1, release=fx.get("release", 400), db=fx["db"], pan=fx.get("pan", 0.0),
                       send=fx["send"], pitched=fx.get("pitched", False), echo=fx.get("echo", False), inserts=fx.get("inserts", []))
            root = fx.get("root", 60)
            zone = {"path": os.path.join(fx_dir, fx["file"]), "root": root,
                    "low": 0 if cfg["pitched"] else root, "high": 127 if cfg["pitched"] else root}
            plan.append((f"fx_{inst}", "sampled", cfg, zone, notes[inst]))
    for inst, cfg in synths.items():
        plan.append((inst, "synth", cfg, None, notes.get(inst, [])))
    print(f"Ścieżek: {len(plan)}, nut: {sum(len(p[4]) for p in plan)}")

    rv = {"mix": 100, "decay": 1.8, "pre_delay": 12, "size": 60, "damping": 8000, "low_cut": 250, **(reverb or {})}
    end_bar = end_beat // 4 + 1
    lines = [
        "session.new " + json.dumps({"name": name, "sample_rate": 48000}),
        f'event.tempo {{"bpm":{bpm}}}',
        'mix.new_bus {"name":"Verb"}',
        'track.new {"kind":"aux","name":"Room","format":"stereo"}',
        'track.input {"tracks":["Room"],"input":"Verb"}',
        "mix.insert " + json.dumps({"track": "Room", "slot": 0, "plugin": "plate_reverb", "params": rv}),
    ]
    for track, kind, cfg, z, zn in plan:
        lines.append(f'track.new {{"kind":"instrument","name":"{track}","format":"stereo"}}')
        inserts = list(cfg.get("inserts", []))
        if kind == "sampled":
            params = {"root_note": z["root"], "key_low": z["low"], "key_high": z["high"], "attack": cfg["attack"],
                      "release": cfg["release"], "play_mode": 1 if cfg["mode"] == "one" else 0, "velocity": cfg.get("vel_sens", 70),
                      "key_track": 1 if cfg.get("pitched", True) else 0}
            lines.append("mix.sampler_load " + json.dumps({"track": track, "path": z["path"], "params": params}))
            if cfg.get("echo"):
                inserts.insert(0, ("mod_delay", {"time": delay_ms, "feedback": 38, "mix": 26, "lpf": 5000}))
        else:
            lines.append("mix.instrument " + json.dumps({"track": track, "plugin": cfg["plugin"], "params": cfg["params"]}))
        for slot, (plugin, params) in enumerate(inserts):
            if plugin == "mod_delay" and params.get("time") == "dotted8":
                params = {**params, "time": delay_ms}
            lines.append("mix.insert " + json.dumps({"track": track, "slot": slot, "plugin": plugin, "params": params}))
        lines += [
            "mix.volume " + json.dumps({"tracks": [track], "db": cfg["db"]}),
            "mix.pan " + json.dumps({"tracks": [track], "pan": cfg["pan"]}),
            "mix.send " + json.dumps({"track": track, "slot": 0, "bus": "Verb", "level_db": cfg["send"]}),
            "midi.new_clip " + json.dumps({"track": track, "start": 0, "end": f"{end_bar}|1|000"}),
        ]
    lines.append('track.new {"kind":"master","name":"Master","format":"stereo"}')
    s1 = os.path.join(work, "phase1.txt")
    open(s1, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    session = os.path.join(work, name.lower().replace(" ", "_") + ".scraft")
    print("SoundCraft: ścieżki i klipy...")
    sr.sc(s1, "--save", session)

    data = json.load(open(session, encoding="utf-8"))
    clip_of, master_id = {}, None
    for t in data["tracks"]:
        if t["kind"] == "Master":
            master_id = t["id"]
        for pl in t.get("playlists", []):
            for c in pl.get("clips", []):
                clip_of[t["name"]] = c["id"]
    chain = master or [("compressor", {"threshold": -16, "ratio": 2.5, "attack": 20, "release": 150, "makeup": 3}),
                       ("maximizer", {"threshold": -4, "ceiling": -1})]
    lines = ["mix.insert " + json.dumps({"track": master_id, "slot": i, "plugin": p, "params": prm}) for i, (p, prm) in enumerate(chain)]
    for track, kind, cfg, z, zn in plan:
        for pitch, start, dur, vel in zn:
            lines.append("midi.note_add " + json.dumps({"clip": clip_of[track], "pitch": pitch, "start_ticks": int(round(start * PPQ)),
                                                        "length_ticks": max(30, int(dur * PPQ)), "velocity": vel}))
    s2 = os.path.join(work, "phase2.txt")
    open(s2, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    wav = session.replace(".scraft", ".wav")
    print("SoundCraft: nuty i zgranie miksu...")
    out = sr.sc(s2, "--in", session, "--save", session, "--in-place", "--bounce", wav, "--end", str(end_beat * 60 / bpm))
    print([l for l in out.splitlines() if '"lufs"' in l][-1][:300])
    os.makedirs(os.path.dirname(out_ogg), exist_ok=True)
    length = end_beat * 60 / bpm
    # Głośność: pomiar LUFS, wzmocnienie do celu i limiter szczytów (loudnorm nie podnosi
    # głośności, gdy szczyty potężnego dołu blokują go przed przekroczeniem limitu).
    meter = subprocess.run(["ffmpeg", "-nostats", "-i", wav, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True).stderr
    measured = float([l for l in meter.splitlines() if "I:" in l][-1].split(":")[1].split()[0])
    gain = loudness - measured
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af",
                    f"afade=t=out:st={length - fade}:d={fade},volume={gain:.2f}dB,alimiter=limit=0.79:attack=3:release=60:level=disabled",
                    "-ar", "48000", "-c:a", "libvorbis", "-q:a", "6", out_ogg], check=True)
    print(f"Głośność: {measured:.1f} LUFS -> cel {loudness} (wzmocnienie {gain:+.1f} dB, limiter -2 dBFS)")
    print("Gotowe:", out_ogg)
    return session
