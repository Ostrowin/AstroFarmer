# Generowanie muzyki do Astro Farmera: wnioski i instrukcja

Notatki z pierwszej sesji muzycznej (2026-11-14), dla osobnego czatu do muzyki. **Lista zamówień od czatu gry: `docs/Muzyka_zamowienia.md`** (zacznij od niej). Zebrane tu jest wszystko, czego nie widać od razu w kodzie: jak działa proces, pułapki narzędzi, czego nauczyły pomiary i co lubi autor.

## 1. Zasady pracy z autorem

- Rozmowa i dokumenty po polsku, napisy w grze po angielsku.
- **Autor sam robi commity i pushe.** Nie commitować i nie proponować commitów.
- Autor odsłuchuje w odsłuchowni (`tests/sound_board.tscn`) i mówi, co zmienić. Uruchomienie w PowerShellu wymaga `&` na początku:
  `& "D:/Programy/Godot/Godot_v4.7.2-stable_win64.exe" --path "D:/Projekty/Private/AstroFarmer" res://tests/sound_board.tscn`
  (albo w edytorze Godota: otworzyć scenę i wcisnąć F6).
- **Claude nie słyszy dźwięku.** Każdą decyzję o brzmieniu trzeba oprzeć na pomiarze (sekcja 7) i uczciwie mówić, że wynik nie był odsłuchany.
- Utwory-odniesienia, które autor wrzuca do `C:\Users\lucci\Downloads`, analizujemy tylko pod kątem proporcji brzmienia (tempo, tonacja, pasma, głośność, gęstość dołu). **Nie kopiujemy melodii, tekstów ani motywów.** Niczego nie pobieramy z YouTube ani Spotify.
- Pobieranie plików z sieci wymaga zgody autora (zgoda jest na paczki CC0 z Kenney i OpenGameArt oraz na VSCO 2 CE).

## 2. Gdzie co jest

| Co | Gdzie |
|---|---|
| SoundCraft (DAW sterowany komendami) | `D:/Programy/Craft/SoundCraft/soundcraft-cli.exe` (`soundcraft.exe` to okno) |
| Biblioteka próbek VSCO 2 CE (CC0, 3,1 GB, kompletna) | `D:/Audio/VSCO-2-CE/` |
| Sesje SoundCraft utworów (z nutami, do edycji w oknie) | `D:/Audio/Sessions/<Utwór>/<utwór>.scraft` |
| Próbki wygenerowane do utworów (banjo, 808, okrzyki) | `D:/Audio/Sessions/<Utwór>/fx/`, `.../banjo/` |
| Skrypty utworów | `tools/audio/<utwór>.py` |
| Wspólne składanie w SoundCraft | `tools/audio/sc_song.py` |
| Strefy samplera, wykrywanie wysokości próbek, `sc()` | `tools/audio/star_rodeo.py` (funkcje `zones_for`, `detect_pitch`, `fix_overlaps`, `sc`) |
| Synteza próbek (banjo, stopy, 808, okrzyki, riser) | `tools/audio/fx_synth.py` |
| Pomiary | `tools/audio/analysis/` (sekcja 7) |
| Gotowa muzyka do gry | `audio/music/*.ogg` |
| Efekty dźwiękowe gry (osobny temat) | `audio/sfx/`, składane przez `tools/audio/build_sounds.py`, licencje w `audio/LICENSES.md` |
| Odtwarzanie w grze | autoload `Sfx`: `Sfx.play_music(path, volume_db)` (pętla, szyna Music), `Sfx.play_music("")` cisza |
| Odsłuchownia | `tests/sound_board.gd`, lista `MUSIC` na górze pliku |
| Test | `tests/test_audio.gd` (sprawdza m.in., że każdy plik muzyki się wczytuje) |

## 3. Jak powstaje utwór

Każdy utwór to skrypt `tools/audio/<nazwa>.py` z:
1. konfiguracją instrumentów: `SAMPLED` (próbki VSCO albo własne), `FX_TRACKS` (pojedyncze próbki: stopa, 808, okrzyki, riser), `SYNTHS` (syntezatory SoundCraft z wtyczkami);
2. funkcją `compose()`, która wypełnia słownik `notes` w postaci instrument → lista `(wysokość MIDI, start w beatach, długość w beatach, velocity)`;
3. wywołaniem `sc_song.build(...)`, które:
   - dzieli instrumenty na strefy samplera (jedna próbka na zakres klawiszy, osobna ścieżka na strefę),
   - w fazie 1 tworzy sesję, ścieżki, wtyczki, wysyłki na pogłos i puste klipy MIDI,
   - odczytuje z zapisanej sesji numery klipów,
   - w fazie 2 dopisuje nuty, zapisuje sesję i zgrywa miks do WAV,
   - ustawia głośność (pomiar LUFS, wzmocnienie do celu, limiter -2 dBFS) i koduje OGG,
   - opcjonalnie robi pętlę bez szwu (`loop_beats`: ogon pogłosu nałożony na początek).

Uruchomienie: `python tools/audio/<nazwa>.py`. Flaga `--fx` wymusza ponowne wygenerowanie własnych próbek. Jedno złożenie trwa 2–4 minuty.

Przy nowym utworze najprościej skopiować najbliższy istniejący skrypt (sekcja 10) i podmienić `compose()` oraz instrumenty.

## 4. SoundCraft CLI: fakty i pułapki

- `soundcraft-cli script plik.txt`: jedna komenda na linię w formacie `ID {json}`. `describe <komenda>` pokazuje parametry, `commands` listę, `run --cmd engine.plugins` listę wtyczek z parametrami.
- **960 ticków na ćwierćnutę** (`midi.note_add`: `start_ticks`, `length_ticks`).
- Pozycje w formacie takt|beat|tick z **taktami liczonymi od 1**: `"38|1|000"` to początek taktu 38. Liczby to próbki (48 kHz).
- `mix.pan` przyjmuje wartości od -1 do 1. `mix.volume` max +12 dB.
- Ścieżki stereo: `track.new {"kind":"instrument", ...}`. Syntezator ustawia `mix.instrument {"track", "plugin", "params"}`, a próbkę `mix.sampler_load {"track", "path", "params"}`, gdzie `root_note`, `key_low` i `key_high` ustawiają strefę.
- **Jeden sampler gra jedną próbkę.** Instrument wielopróbkowy to kilka ścieżek-stref (robi to `zones_for`).
- `play_mode`: 0 = Gate (nuta trzyma), 1 = One Shot (gra całą próbkę niezależnie od długości nuty). Bas 808 musi grać w Gate, inaczej nie da się skracać nut.
- Pogłos: `mix.new_bus` + ścieżka `aux` z `track.input` na tę szynę + wtyczka na aux + `mix.send` z każdej ścieżki.
- Ścieżka master: `track.new {"kind":"master"}`. Wtyczki na niej wstawia się **po numerze ścieżki**, nie po nazwie.
- Zapis po zmianach w istniejącej sesji: `--in S --save S --in-place` (wszystkie trzy, inaczej albo błąd, albo brak zapisu).
- Pomiar grupy instrumentów: `run --in S --cmd mix.solo={...} --bounce x.wav --start ... --end ...`. Do tego `mix.insert_bypass` na wtyczkach mastera, bo inaczej limiter zniekształca proporcje (robi to `analysis/stems.py`).
- **Ta sama wysokość na tym samym instrumencie nie może nachodzić na siebie:** wyłączenie starszej nuty ucina nową (sampler gasi głos po wysokości). Pilnuje tego `fix_overlaps()` (wywołuje go `sc_song`).
- Wtyczki: `subtractive_synth`, `drum_synth`, `sampler`, `saturator`, `eq_7band`, `compressor`, `maximizer`, `plate_reverb`, `room_reverb`, `mod_delay`, `chorus`, `phaser`, `flanger`, `pitch_shifter`, `lofi`, `auto_pan`, `signal_generator`.
- **`drum_synth`** ma nuty w standardzie GM: 36 stopa, 38 werbel, 39 klaśnięcie (ciche), 42/44/46 hi-haty, 41–50 tomy, 49 crash, 51 ride (bardzo cichy).
- W skryptach `mod_delay` z `"time": "dotted8"` dostaje ósemkę z kropką w ms (podmienia `sc_song`).

## 5. VSCO 2 CE: fakty i pułapki

- **Nazwy plików mają różne przesunięcia oktaw** (sekcja skrzypiec nazwana oktawę niżej, róg nawet o dwie). `zones_for` mierzy wysokość próbek (HPS) i sam ustala przesunięcie. Wynik drukuje: „przesunięcie nazw +12”.
- Warstwy dynamiki w nazwach (`_p`/`_f`, `v1`..`v3`). **Ciche warstwy (`_p`, `v1`) są bardzo ciche**, nawet o 20 dB. Trzeba podnieść suwak, a gdy +12 dB nie wystarcza, dodać `sampler={"level": X}` w konfiguracji instrumentu.
- **Perkusja VSCO (kongi, klawesy, kłody, kowadło) jest bardzo cicha**: suwak +12, `level` w samplerze i `vel_sens` ok. 35 (patrz `perc()` w `heavy_pulse.py`).
- **Werbel `Snare2-HitSN` ma własny ton ok. 235 Hz (A#).** W E-dur to tryton. W `hoedown_circuit.py` przestrojony o +1 (`sampler={"transpose": 1}`). „Star Rodeo” (G-dur) używa go bez zmian, warto sprawdzić.
- Kontrabas pizzicato ma pełen zakres tylko w cichej warstwie `v1`. Głośna `v3` to tylko 6 nut. W `hoedown_circuit.py` podbity kompresorem z makeup i EQ 700 Hz.
- Kotły (`Timpani1/2/3`) nie mają nut w nazwach. Wykryte wysokości są niskie i niepewne, ale przy perkusji to nie przeszkadza.
- Cisza na początku próbek jest pomijalna (1–7 ms). Sustainy smyczków i blachy trwają 4–12 s.
- Przydatne: `Strings/Solo Violin/Arco Vib` (fiddle), `.../spic` (krótkie, do szesnastek), sekcje smyczków `susVib`, `Pizz`, `Strings/Harp`, `Brass/F Horn/sus|stac`, `Brass/Trumpet|Tenor Trombone|Tuba/sus`, `Percussion/BDrumNewhit` (wielki bęben orkiestrowy), `cymbal-crash`, `Tamb1-Hit`, `Conga/Tumba/Quinto-HitN`, `Claves1_Hit`, `LogDrumLo_MedM`, `Anvil_Hit1`. Jest też drewno (flet, obój, klarnet, fagot), fortepian i organy, jeszcze nieużywane.

## 6. Własne próbki (`fx_synth.py`)

| Funkcja | Co robi | Uwagi |
|---|---|---|
| `banjo_note(freq, length, seed, pick_pos, brightness, damping, drive)` | banjo modelem fizycznym (Karplus-Strong + rezonanse membrany 300/1400/3000 Hz) | strój skompensowany (0,2 centa). Zwykłe: domyślne, łagodne: `length=3, pick_pos=0.3, brightness=0.9975, damping=0.55, drive=0.9`. Generować co 3 półtony, nazwy `banjo_G#4.wav` (strefy same się ułożą) |
| `sub_kick(tail_hz, length, grit, hold)` | stopa: czysty sub + przester tylko powyżej 150 Hz | twarda: `49 Hz, 0.395, hold 0.93`; sprężysta: `41–55 Hz, 0.27, hold 0.6` |
| `hardstyle_kick(tail_hz)` | stopa hardstyle z przesterowanym ogonem | strojona do F2 (87 Hz); w sampler `pitched=True`, nuty = pryma akordu |
| `bass_808(freq, length, drive, punch)` | bas 808 (F1 ok. 44 Hz) z saturacją | w samplerze **Gate**, nuty skracać (patrz 8) |
| `shout(vowel, pitch, length, voices, seed, factors)` | chór okrzyków „HEY!/HA!/HOO!” (formanty) | `factors` = interwały głosów; **stroić do akordu** (np. `[1, 0.794, 1.335, ...]`), inaczej fałszuje |
| `yeehaw(pitch, length, seed)` | okrzyk robo-kowboja „yee-haw” (formanty, lekko zrobotyzowany) | do podmiany na nagranie autora, gdy nagra |
| `riser(seconds)`, `impact()`, `reverse_cymbal(path, s)` | narastający szum, uderzenie, odwrócony talerz | |

## 7. Pomiar zamiast słuchu

Narzędzia w `tools/audio/analysis/` (opisy użycia na górze plików):
- `stems.py`: LUFS grup instrumentów w sekcjach (solo + bounce, master wyłączony). **Podstawowe narzędzie balansu.**
- `chords.py`: zgodność harmonii z planem akordów takt po takcie + spektrogram PNG (obraz da się obejrzeć).
- `rhythm_grid.py`: energia w szesnastkach w pasmach, czyli wyrazistość rytmu (tylko przy dokładnie znanym tempie).
- `reference.py`: pełna analiza utworu-odniesienia albo porównanie z naszym (tempo, tonacja, LUFS, pasma, energia w czasie).
- `features.py`: cechy pojedynczych próbek (do wyboru próbek na ślepo).

Pułapki pomiarów:
- **LUFS waży bas słabo** (filtr K): stopa i sub w `stems.py` wychodzą „ciszej”, niż brzmią. Porównywać grupy względem siebie, a dół oceniać pasmami w `reference.py`.
- **Mierzyć z wyłączonym masterem**: limiter wyrównuje solo grupy (róg ściszony o 6 dB zmienił się o 1,5).
- **Siatka rytmu na nagraniach studyjnych nie działa**: tempo pływa i wzory wychodzą płaskie. Na własnych utworach podawać dokładne BPM (`BPM_FIXED` albo `rhythm_grid.py`). Nawet 143,6 zamiast 144 rozjeżdża siatkę o pół beatu.
- Wykrywanie tempa łapie połowę albo dwukrotność (Little Big: 75 zamiast 152). Zawężać `BPM_RANGE`.
- Szczyt pokazuje „true peak” (między próbkami), więc +2 dBTP przy rzeczywistym szczycie -0,7 dBFS to nie przester (sprawdzać `astats`).
- Zgodność akordów: akustyka ok. 0,8–0,95, electro ok. 0,6 (szum perkusji). Okrzyki z glissando i risery zaniżają wynik, nie oznaczają złych nut.
- Pomiar w oknach ±6 ms wokół uderzenia jest kruchy (stopa ma na początku wysoki ton). Lepsza jest średnia energia w całej szesnastce.

## 8. Wnioski miksowe (konkretne, sprawdzone)

- **Wyraźny rytm = przerwy w dole.** Długi ogon stopy plus bas na każdej szesnastce dają ścianę (różnica beat/reszta +1,6 dB, „Stampede”). Krótka stopa i bas z oddechem dają +7–20 dB („Hoedown Circuit”, „Heavy Pulse”). Bas 808 trzymany do następnej stopy buczy ciągle, więc skracać nuty (max ok. 3 szesnastki).
- **Twardość jak u Little Big to subbas, nie przester środka:** stopa strojona nisko (ok. 49 Hz) z ogonem przez cały beat, przester tylko w górnej warstwie, dół wypełniony na każdej szesnastce, jasna góra, ok. -10 LUFS.
- **Kompresor na sumie pompuje przy każdej stopie** i dusi klaśnięcia, które padają razem z nią. Na sumie łagodnie, głośność robi końcowy limiter (`sc_song`).
- **Echo na ósemkę z kropką ląduje na offbeatach** i zapycha miejsce werbla. W utworach rytmicznych ustawić echo na ćwierćnutę.
- **Smyczek (arco) narasta 1–2 szesnastki po nucie** i wypełnia offbeaty w paśmie 2–8 kHz. W gęstym refrenie przyciemnić fiddle (EQ) i ściszyć.
- **Banjo jest bardzo jasne i łatwo zostaje najgłośniejsze.** W rollach melodia na beacie mocno, wypełnienia ciszej (`vel + (14, -16, -6, -12)`), EQ -3 dB przy 3 kHz.
- **Tamburyn z akcentami na nieparzystych szesnastkach** dominuje pasmo klaśnięcia. Trzymać go cicho i równo.
- **Instrumenty z własnym tonem** (werbel A#, zjazd wysokości stopy) psują harmonię. Stroić je do tonacji (stopa: ogon na tonice).
- **Pady i ta sama nuta takt po takcie:** przez „uczłowieczenie” czasu nowa nuta potrafi zacząć się przed końcem starej i zostaje ucięta (`fix_overlaps`).
- Filtr górnoprzepustowy na brudnej warstwie basu nie może odcinać jej własnego tonu podstawowego (90 Hz, nie 170).
- `loudnorm` w ffmpeg potrafi ściszać zamiast podgłaśniać, gdy szczyty dołu blokują limit. Dlatego `sc_song` robi pomiar, wzmocnienie i `alimiter`.
- Kodek Vorbis zaczyna plik od zera, więc na szwie pętli OGG zostaje drobny ślad (mniejszy niż zwykłe różnice próbek).
- Typowe proporcje, które się sprawdziły (LUFS solo, master wyłączony):
  - orkiestra: melodia ok. -16, róg -19, trąbki -21, niska blacha -22, wiolonczele -18, pizzicato -22, perkusja -24, kotły -27;
  - electro-country: stopa -12, bas -15, lead i fiddle -17/-18, perkusja -17, chór -16;
  - spokojne: banjo -13, smyczki i skrzypce -17/-19, harfa -23.

## 9. Utwory-odniesienia (z Downloads)

| Utwór | Co pokazała analiza |
|---|---|
| Little Big – Hardcore American Cowboy | 152 BPM, c-moll, -9,6 LUFS, ogromny sub (20–60 Hz -5,5 dB), jasna góra (5–11 kHz -13 dB), czysty dół, energia prawie stała. Na tej podstawie powstało „Stampede” (pasma w ok. 2 dB) |
| Alan Jackson – Country Boy | ok. 144 BPM, E (country z D), dużo środka (gitary, banjo, wokal), naturalna dynamika (-16,9 LUFS). Inspiracja dla „Hoedown Circuit” (tylko tempo i charakter) |

## 10. Katalog utworów

| Utwór | Styl | Tonacja / tempo / długość | Skrypt | W grze |
|---|---|---|---|---|
| Star Rodeo | epicka orkiestra + country (fiddle, pizzicato boom-chick, blacha, kotły; koda „shave and a haircut… two bits”) | G-dur, 108 BPM, 82 s | `star_rodeo.py` | **menu główne** |
| Boss Rodeo | electro + country (galopujący przesterowany bas, hoedown, train beat, banjo z harfy, robo-yee-haw) | e-moll, 132 BPM, 98 s | `boss_rodeo.py` | jeszcze nie (boss) |
| Rodeo Rave | hard rave + country (stopa hardstyle strojona pod akordy, bas offbeat/rolling, screech, chór HEY/HA) | f-moll, 150 BPM, 82 s | `rodeo_rave.py` | jeszcze nie (boss) |
| Stampede | twarda elektronika wg Little Big (czysty sub 49 Hz, brudny bas w szesnastkach, jasna góra) | c-moll, 152 BPM, 86 s | `stampede.py` | jeszcze nie (boss) |
| Hoedown Circuit | wyraźny electro beat + czyste country, dużo banjo (model fizyczny), truck-driver modulation | E-dur, 144 BPM, 93 s | `hoedown_circuit.py` | jeszcze nie |
| Homestead | spokojne, akustyczne: łagodne banjo, wiolonczela, smyczki, skrzypce, harfa; pętla bez szwu | G-dur, 66 BPM, 116 s | `homestead.py` | **baza** (-12 dB, cichnie na wyprawie) |
| Heavy Pulse | prawie sam rytm: 808, stopa, trapowe hi-haty, perkusja VSCO | f-moll, 60 BPM, 100 s | `heavy_pulse.py` | jeszcze nie (rajd? napięcie?) |

„Boss Rodeo” i „Rodeo Rave” powstały przed poprawką głośności w `sc_song`. Po przebudowaniu wyjdą trochę inaczej głośne.

## 11. Co autor lubi (historia reakcji)

- „Star Rodeo”: „Masz talent chłopie do muzyki”.
- Pierwsze electro-country było za mało agresywne. „Rodeo Rave”: „nawet lepiej”. Potem chciał „hardej elektroniki”, czyli „Stampede”.
- Chciał **wyraźniejszego rytmu** (elektronicznego) i **więcej banjo**, czyli „Hoedown Circuit”.
- Chciał **spokojnego banjo bez elektroniki** do tła, czyli „Homestead”.
- Chciał utworu z **prawie samym rytmem, 60 BPM, mocnym niskim basem**, czyli „Heavy Pulse”.
- Okrzyki „iiihaaa” w stylu kowbojskim mu się podobają. Syntetyczne efekty dźwiękowe w grze go irytowały (dlatego SFX są z nagrań CC0).

## 12. Otwarte sprawy

- Autor może nagrać własne „iiihaaa”: wstawić jako `fx/yeehaw.wav` (plus `_low`, `_short`) w sesji danego utworu i przebudować.
- Sprawdzić werbel (ton A#) w „Star Rodeo”.
- Podpiąć muzykę bossów, rajdu i wypraw, gdy będą te elementy gry (np. „Heavy Pulse” na rajd).
- Suwaki głośności (SFX / tło / muzyka) w menu.
- Eksport gry: dodać `audio/sfx/*.json` do filtra plików nie-zasobów.
- Nieużyte jeszcze instrumenty VSCO: drewno, fortepian, organy, marimba, ksylofon, dzwonki.
