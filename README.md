# Astro Farmer

Roguelite TPP o farmerze-odkrywcy na nieprzyjaznej, obcej planecie. Godot 4.7, GDScript.

## Dokumenty

- [ToDo.md](ToDo.md): plan prac, etapy M0-M5
- [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md): kierunek gry i decyzje projektowe
- [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md): pula pomysłów
- [astro_farmer_rozszerzona_baza_wiedzy.md](astro_farmer_rozszerzona_baza_wiedzy.md): baza wiedzy
- [docs/Muzyka_generowanie.md](docs/Muzyka_generowanie.md): jak powstaje muzyka (SoundCraft + VSCO 2 CE), pułapki, pomiary, katalog utworów
- [docs/Muzyka_zamowienia.md](docs/Muzyka_zamowienia.md): czego gra potrzebuje od czatu muzycznego (muzyka i sample)

## Uruchomienie

Otwórz `project.godot` w Godot 4.7 i naciśnij F5 (gra startuje od menu: Continue / New Game). Albo z terminala:

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64.exe" --path .
```

## Testy

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_game_state.gd
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_farm_loop.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_expedition.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_base_defense.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_progress.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_controls.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_machines.tscn
```

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_settings.tscn
```

Modele maszyn farmy (dron, dok, traktor) i ikonę drona buduje skrypt Blendera:

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/machines_models.py
```

Odsłuchownia dźwięków (klik = odsłuch, Use = wybór, Save zapisuje `audio/sfx/picks.json`):

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64.exe" --path . res://tests/sound_board.tscn
```

Muzykę menu („Star Rodeo”) składa skrypt z SoundCraft i biblioteki VSCO 2 CE (`D:/Audio/VSCO-2-CE`); po zmianie nut w skrypcie:

```bash
python tools/audio/star_rodeo.py
```

Test dźwięku:

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_audio.tscn
```

Podgląd wszystkich roślin we wszystkich etapach (osobny zapis, nie rusza gry; Tab przełącza kamerę):

```bash
"D:/Programy/Godot/Godot_v4.7.2-stable_win64.exe" --path . res://tests/showcase.tscn
```

## Struktura

| Folder | Zawartość |
|---|---|
| `scenes/` | sceny (`levels/` poziomy i biomy, `ui/` interfejs) |
| `scripts/` | skrypty (`autoload/` globalne singletony, np. `GameState`) |
| `data/` | dane gry jako zasoby Godota (`plants/`, `creatures/`) |
| `art/fonts/` | fonty gry (Lato, licencja OFL w `OFL-lato.txt`) |
| `art/materials/` | materiały i shadery (teren: `ground_valley.tres`, `ground_meadow.tres`, pole `tilled.tres`; wzgórza wokół poziomów buduje `scripts/fx/terrain_ring.gd`) |
| `art/models/` | modele do gry (`.glb`): `player.glb` z animacjami, `plants/<id>.glb` (3 etapy wzrostu w jednym pliku), `creatures/`, `buildings/`, `nature/` |
| `art/source/` | pliki źródłowe Blendera (`.blend`) i szkice (`sketches/`); Godot je pomija (`.gdignore`) |
| `audio/` | dźwięk: `sfx/<zdarzenie>/<a\|b\|c>/` (kandydaci, wybór w `sfx/picks.json`), `music/`, źródła i licencje w `LICENSES.md` |
| `tools/` | skrypty pomocnicze poza grą (`audio/build_sounds.py` składa dźwięki z paczek CC0) |
| `tests/` | testy uruchamiane z terminala |
| `docs/` | raporty z playtestów |

## Sterowanie

Ruch jak w Risk of Rain 2:
- WASD ruch, Spacja skok, mysz kamera.
- Ctrl włącza bieg. Bieg trwa, dopóki się ruszasz i nie strzelasz.
- Shift: dash (odnowienie 2 s).
- F gasi i zapala latarkę na hełmie (świeci tylko po zmroku).
- Esc: menu pauzy (Resume, głośność muzyki, efektów i tła, pełny ekran, Main Menu, Quit). Wyjście z wyprawy trzeba potwierdzić, bo przerywa ją jak porażka.
- F11 albo Alt+Enter: pełny ekran / okno (gra startuje na pełnym ekranie).

Doba trwa 10 minut (zegar w lewym górnym rogu). W nocy jest ciemno, a latarka na hełmie świeci tam, gdzie patrzysz.

Gra jest po angielsku i pokazuje jak najmniej tekstu. Obiekt, z którym można teraz coś zrobić, ma żółtą obwódkę.

**Baza** (sadzenie i budowanie na siatce 1×1 m):
- Tab (przytrzymaj): lista magazynu.
- 1-9 / kółko: wybór narzędzia (1-5 nasiona, 6 konewka, 7 nawóz, 8 płot, 9 dron nawadniający).
- LPM: użyj (sadź, podlej, napełnij konewkę, nawóź, postaw słupek albo dok drona).
- E: zbierz / zabierz słupek lub dok drona / wsiądź do traktora / warsztat / komputer w chatce (baza danych) / drzwi wyprawy.
- W traktorze: WASD jazda, LPM opuszcza i podnosi siewnik (sadzi nasiona z wybranego slotu i zbiera dojrzałe uprawy pasem 3 pól), E wysiada, +/- głośniej i ciszej (muzyka startuje bardzo głośno).
- F8 przesuwa zegar o 2 godziny, F9 następny cykl, F10 nowa gra (debug).

**Wyprawa:**
- LPM: przedmiot z paska. 1 pistolet (przytrzymaj = seria), 2 zjedz Voidberry.
- PPM: rzuć to, co masz w drugiej ręce (nasiono Snappera albo Boomshrooma). R zmienia rzucany przedmiot.
- Tab: plecak. Przeciągnij nasiono na rękę PPM; PPM na przedmiocie wyrzuca 1 sztukę, przeciągnięcie do kosza wyrzuca stos.
- E: podnieś / zjedz dziki owoc / nabierz wody z Mglistego źródła / wezwij ewakuację.
- Q: skanuj.

## Narzędzia graficzne

- Blender przez MCP (modele, szkice brył).
- TextureCraft przez MCP: skonfigurowany w `.mcp.json` (czyta cały projekt, zapisuje tylko w `art/`). Claude Code pyta o zgodę przy pierwszym uruchomieniu.

## Sposób pracy

- Napisy w grze są po angielsku i krótkie. Dokumenty są po polsku.
- **Najpierw szkic, potem wdrożenie:** każda nowa rzecz widoczna w grze zaczyna się od szkicu do akceptacji (rysunek 2D albo bryła w Blenderze z renderem).
- Modele: Blender, potem `.glb` w `art/models/`. Źródła `.blend` leżą w `art/source/`.
