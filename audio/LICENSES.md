# Dźwięki: źródła i licencje

Wszystkie dźwięki w `audio/sfx/` pochodzą z paczek na licencji **CC0 1.0** (domena publiczna: wolno używać, zmieniać i publikować, także komercyjnie, bez podawania autora). Mimo to zapisujemy, skąd są.

Dokładne pliki źródłowe każdego kandydata są w `audio/sfx/candidates.json`. Pliki zostały przycięte, znormalizowane, a część zwolniona lub przyspieszona (`tools/audio/build_sounds.py`).

## Kenney (kenney.nl), CC0

- Impact Sounds: https://kenney.nl/assets/impact-sounds
- Sci-fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- Interface Sounds: https://kenney.nl/assets/interface-sounds
- RPG Audio: https://kenney.nl/assets/rpg-audio
- UI Audio: https://kenney.nl/assets/ui-audio
- Digital Audio: https://kenney.nl/assets/digital-audio

## OpenGameArt, CC0 (licencja sprawdzona na stronie każdej paczki)

- rubberduck, 80 CC0 creature SFX: https://opengameart.org/content/80-cc0-creature-sfx
- rubberduck, 80 CC0 creature SFX #2: https://opengameart.org/content/80-cc0-creture-sfx-2
- rubberduck, 100 CC0 SFX: https://opengameart.org/content/100-cc0-sfx
- rubberduck, 100 CC0 SFX #2: https://opengameart.org/content/100-cc0-sfx-2
- rubberduck, 30 CC0 SFX loops: https://opengameart.org/content/30-cc0-sfx-loops
- rubberduck, 40 CC0 water/splash/slime SFX: https://opengameart.org/content/40-cc0-water-splash-slime-sfx
- rubberduck, 80 CC0 RPG SFX: https://opengameart.org/content/80-cc0-rpg-sfx
- rubberduck, 25 CC0 mud SFX: https://opengameart.org/content/25-cc0-mud-sfx
- Monster snarls: https://opengameart.org/content/monster-snarls
- CC0 Deep Monster Roar: https://opengameart.org/content/cc0-deep-monster-roar
- Crickets ambient noise (loopable): https://opengameart.org/content/crickets-ambient-noise-loopable
- Forest Ambience: https://opengameart.org/content/forest-ambience
- Birds and Wind, ambient: https://opengameart.org/content/birds-and-wind-ambient-birds-wind-and-synth

## Muzyka

- Efekty w „Boss Rodeo” i „Rodeo Rave” (okrzyki „yee-haw” i „HEY!/HA!/HOO!”, stopy hardstyle i „sub kick”, riser, uderzenie) są syntezowane od zera (`tools/audio/fx_synth.py`); odwrócony talerz pochodzi z VSCO 2 CE.
- `audio/music/` to utwory skomponowane do gry w SoundCraft na próbkach **VSCO 2 Community Edition** (Versilian Studios, CC0): https://github.com/sgossner/VSCO-2-CE. Biblioteka leży poza projektem, w `D:/Audio/VSCO-2-CE`.

## Jak odtworzyć `audio/sfx/`

1. Pobierz paczki z listy powyżej do `audio/_incoming/` (Kenney: `audio/_incoming/<nazwa-paczki>/`, OpenGameArt: `audio/_incoming/oga/<skrót>/`). Folder nie trafia do gita.
2. `python tools/audio/build_sounds.py` (potrzebne: ffmpeg, numpy).
