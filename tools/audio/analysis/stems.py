"""Głośność (LUFS) grup instrumentów w sekcjach utworu: solo grupy + bounce fragmentu
z SoundCraft, z WYŁĄCZONĄ obróbką sumy (kompresor/limiter zniekształcają proporcje).

Użycie:
  python stems.py sesja.scraft tymczasowy.wav BPM '{"bas":["sub","grit"],"fiddle":["fiddle","fid_spic"]}' '{"A":[8,24],"B":[24,32]}'
Grupy: nazwa -> prefiksy nazw ścieżek; sekcje: nazwa -> [pierwszy takt, takt za ostatnim] (od 0).
Uwaga: LUFS waży bas słabo (filtr K), więc stopa/sub wychodzą „ciszej” niż brzmią.
"""
import json, subprocess, sys
SC = "D:/Programy/Craft/SoundCraft/soundcraft-cli.exe"
session = sys.argv[1]
out = sys.argv[2]
BAR = 4 * 60 / float(sys.argv[3]) if len(sys.argv) > 3 else 4 * 60 / 108
data = json.load(open(session, encoding="utf-8"))
names = [t["name"] for t in data["tracks"] if t["kind"] == "Instrument"]
master = [t["id"] for t in data["tracks"] if t["kind"] == "Master"][0]
BYPASS = []
for slot in (0, 1):
    BYPASS += ["--cmd", "mix.insert_bypass=" + json.dumps({"track": master, "slot": slot, "value": True})]
GROUPS = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {"fiddle": ["fiddle"], "vln": ["vln_"], "vla": ["vla"], "horn": ["horn"], "trumpet": ["trumpet"],
          "low brass": ["trombone", "tuba"], "cello": ["cello_"], "pizz": ["cello_pz", "vln_pz", "bass_pz"],
          "harp": ["harp"], "drums": ["kick", "snare", "tamb"], "crash": ["crash"], "timp": ["timp"]}
SECTIONS = json.loads(sys.argv[5]) if len(sys.argv) > 5 else {"intro": (0, 8), "A": (8, 16), "B": (16, 24), "A2": (24, 32)}
print(f"{'grupa':10s}" + "".join(f"{s:>8s}" for s in SECTIONS))
for g, prefixes in GROUPS.items():
    tracks = [n for n in names if any(n.startswith(p) and (p != "vln_" or not n.startswith("vln_pz")) and (p != "cello_" or not n.startswith("cello_pz")) for p in prefixes)]
    if not tracks:
        continue
    row = f"{g:10s}"
    for s, (a, b) in SECTIONS.items():
        res = subprocess.run([SC, "run", "--in", session, *BYPASS, "--cmd", "mix.solo=" + json.dumps({"tracks": tracks, "value": True}),
                              "--bounce", out, "--start", str(a * BAR), "--end", str(b * BAR)], capture_output=True, text=True)
        lufs = None
        for line in res.stdout.splitlines():
            if '"lufs"' in line:
                lufs = json.loads(line[line.index("{"):]).get("lufs")
        row += f"{lufs:8.1f}" if lufs is not None and lufs > -70 else f"{'-':>8s}"
    print(row, flush=True)
