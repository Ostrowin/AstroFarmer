# Astro Farmer

Roguelite TPP o farmerze-odkrywcy na nieprzyjaznej, obcej planecie. Godot 4.7, GDScript.

## Dokumenty

- [ToDo.md](ToDo.md): plan prac, etapy M0-M5
- [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md): kierunek gry i decyzje projektowe
- [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md): pula pomysłów
- [astro_farmer_rozszerzona_baza_wiedzy.md](astro_farmer_rozszerzona_baza_wiedzy.md): baza wiedzy

## Uruchomienie

Otwórz `project.godot` w Godot 4.7 i naciśnij F5. Albo z terminala:

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
| `art/`, `audio/` | grafika i dźwięk |
| `tests/` | testy uruchamiane z terminala |
| `docs/` | raporty z playtestów |

## Sterowanie

Ruch jak w Risk of Rain 2:
- WASD ruch, Spacja skok, mysz kamera.
- Ctrl włącza bieg. Bieg trwa, dopóki się ruszasz i nie strzelasz.
- Shift: dash (odnowienie 2 s).
- Esc zwalnia mysz.

**Baza** (sadzenie i budowanie na siatce 1×1 m):
- 1-8 / kółko: wybór narzędzia (1-5 nasiona, 6 konewka, 7 nawóz, 8 płot).
- LPM: użyj (sadź, podlej, napełnij konewkę, nawóź, postaw słupek).
- E: zbierz / zabierz słupek / warsztat / komputer w chatce (baza danych) / drzwi wyprawy.
- F9 następny cykl, F10 nowa gra (debug).

**Wyprawa:**
- LPM: przedmiot z paska. 1 pistolet (przytrzymaj = seria), 2 zjedz Voidberry.
- PPM: rzuć to, co masz w drugiej ręce (nasiono Snappera albo Boomshrooma). R zmienia rzucany przedmiot.
- Tab: plecak. Przeciągnij nasiono na rękę PPM; PPM na przedmiocie wyrzuca 1 sztukę, przeciągnięcie do kosza wyrzuca stos.
- E: podnieś / zjedz dziki owoc / nabierz wody z Mglistego źródła / wezwij ewakuację.
- Q: skanuj.
