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

**Baza:** WASD ruch · Spacja skok · Shift sprint · mysz kamera · 1-4 / kółko wybór narzędzia · LPM użyj (sadź, podlej, napełnij konewkę) · E zbierz / drzwi wyprawy · Esc zwalnia mysz · F9 następny cykl (debug) · F10 nowa gra (debug)

**Wyprawa:** 1 ogłuszacz · 2 rzut nasionem Snappera · 3 zjedz Voidberry · LPM użyj · E podnieś / zjedz dziki owoc / wezwij ewakuację · Q skanuj
