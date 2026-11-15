# Zamówienia muzyczne i dźwiękowe

Lista dla czatu od muzyki: czego gra potrzebuje, gdzie to zagra i w jakim nastroju. Czat od gry dopisuje tu pozycje, kiedy jakaś funkcja potrzebuje muzyki albo sampla; czat od muzyki je realizuje (instrukcja: `docs/Muzyka_generowanie.md`), oznacza `[x]` i wpisuje, gdzie leży plik.

Format pozycji: **nazwa** (dla jakiej funkcji gry), nastrój i styl, długość / pętla, gdzie gra, jak ma być podpięte. Gotowy plik: `audio/music/<nazwa>.ogg` (muzyka) albo `audio/sfx/<zdarzenie>/<a|b|c>/` (efekty, patrz `tools/audio/build_sounds.py`).

## Do zrobienia

- [ ] **Muzyka traktora** (maszyny farmy, w grze od 2026-11-15): lokalnie gra oryginalny „Cotton Eye Joe” (plik w `.gitignore`, nie do publikacji), a bez niego „Hoedown Circuit”. Przed wydaniem gry potrzebna **własna melodia** w tym klimacie (skrzypce, banjo, tupiący rytm, pętla 60–90 s) albo licencja. Podpięcie: `Tractor.MUSIC_FALLBACK` w `scripts/farm/tractor.gd`.
- [ ] **Silnik traktora** (maszyny farmy): pętla pracy silnika (3D, w świecie), głośniejsza i wyższa przy gazie, plus krótki dźwięk odpalenia przy wsiadaniu. Efekty. Dziś przy wsiadaniu gra zastępczo `craft`.
- [ ] **Muzyka wyprawy** (łąka): „niepokojąca na wyprawie” z bazy wiedzy (sekcja 16). Cicha, napięta, dużo powietrza, nie zagłusza dźwięków natury i stworzeń. Pętla 2–3 min. Najlepiej dwie warstwy, które gra przełącza: spokojna (Przebudzenie < 50) i napięta (≥ 50, drapieżnik patroluje). Dziś na wyprawie muzyka milknie.
- [ ] **Muzyka rajdu / najazdu na bazę** (M3 i M4: najazd przy powrocie, 60–90 s obrony): krótka, rytmiczna, z wyraźnym końcem. Kandydat do sprawdzenia: „Heavy Pulse” (60 BPM, sam rytm), może w skróconej wersji.
- [ ] **Ostrzeżenie Przebudzenia 25** (M4: „ostrzeżenie dźwiękowe + kolor nieba”): krótki, niepokojący sygnał (1–2 s), np. niski róg albo dziwny akord. Efekt, nie muzyka.
- [ ] **Warstwa wiatru do tła** (dzień i noc, baza i łąka): brakuje dobrego nagrania CC0. Pętla 20–40 s bez szwu, delikatny wiatr w trawie. Gra pod `amb_*` w `Sfx` (pętle dnia i nocy).
- [ ] **Śpiewające rośliny** (pomysł autora, „Dalej”): Humming Corn (kukurydza nuci przy wietrze albo gdy gracz podejdzie: krótkie, nucone frazy, kilka wysokości, żeby rośliny obok siebie składały się w melodię) i Chór drzew (pieśni w klimacie rdzennych Amerykanów, nocą przy wysokiej Równowadze). Na razie tylko pomysł: zrobić, gdy funkcja wejdzie do planu.
- [ ] **Dron nawadniający** (maszyny farmy, w grze od 2026-11-15; dziś podlewa dźwiękiem `water`, tankuje `fill`, lata bezgłośnie): cichy szum silniczka w pętli (3D, w świecie) i krótki dźwięk podlewania. Efekty.

## Drobne poprawki w istniejących

- [ ] „Star Rodeo”: sprawdzić werbel VSCO (ma ton A#, w „Hoedown Circuit” przestrojony o +1).
- [ ] „Boss Rodeo”, „Rodeo Rave”: przebudować po poprawce głośności w `sc_song.py` (dziś są trochę za ciche / inaczej głośne).
- [ ] Okrzyk „iiihaaa”: jeśli autor nagra własny, podmienić syntezowany `yeehaw.wav` we wszystkich utworach, które go używają.

## Zrobione

(na razie nic z tej listy)
