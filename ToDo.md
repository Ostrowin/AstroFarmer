# Astro Farmer: ToDo

Ostatnia aktualizacja: 2026-11-11 · Kierunek: **Żywa planeta** ([Design_Zywa_Planeta.md](Design_Zywa_Planeta.md)) · Pula pomysłów: [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md)

**Zasada nadrzędna:** jeden etap naraz. Nie zaczynaj kolejnego etapu, dopóki poprzedni nie przeszedł swojego testu. Każdy etap kończy się grywalnym buildem i jednym playtestem.

Kody w nawiasach (np. `K1`, `N2`) odnoszą się do pomysłów w [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md).

---

## 🎯 Teraz: zadanie na ten tydzień

- [x] Scena **"jedna grządka"**: kapsuła jako postać, kamera za plecami, jedno nasiono, 3 etapy wzrostu, zbiór z efektem i dźwiękiem.
- [x] Atrapa "drzwi wyprawy": przejście przez nie = +1 cykl = +1 etap wzrostu (test docelowej pętli cykli, bez czekania).
- [x] Zbiór oddaje 1-2 nasiona, więc można od razu posadzić znowu.
- [x] Dać zagrać 1 osobie bez podpowiedzi (2026-11-20, kuzyn): gra się podoba, ale **za mało rzeczy do zobaczenia**. Odpowiedź: powiększamy obie mapy (baza i łąka) i zapełniamy je.

---

## M0. Przygotowanie projektu

- [x] Zainstalować najnowszą stabilną wersję Godot 4.x (jest 4.7.2 w `D:\Programy\Godot`).
- [x] `git init` w folderze projektu + `.gitignore` dla Godota (folder `.godot/`), `.gitattributes`, `.editorconfig`.
- [x] Dokumenty (baza wiedzy, podsumowanie, design, pomysły, ToDo) zostają w katalogu głównym, żeby linki między nimi działały. Raporty z playtestów trafiają do `docs/`.
- [x] Struktura folderów: `scenes/` (+ `levels/`, `ui/`), `scripts/` (+ `autoload/`), `data/plants/`, `data/creatures/`, `art/models/`, `art/textures/`, `audio/music/`, `audio/sfx/`, `tests/`, `docs/`.
- [x] Fizyka Jolt ustawiona w `project.godot`.
- [x] Pipeline grafiki (2026-11-12): własne modele w Blenderze (przez Blender MCP) → eksport `.glb` do `art/models/`. Źródła `.blend` w `art/source/` (z `.gdignore`, Godot ich nie importuje). Pierwszy model: gracz (farmer w ogrodniczkach i słomianym kapeluszu, szkielet 20 kości, animacje Idle/Run/Sprint/Dash/Shoot/Jump).
  - [x] Nowy bieg i sprint (2026-11-15, `tools/blender/player_locomotion.py`): stopy przyklejone do ziemi przy 5 i 8,5 m/s (przetaczanie z pięty na palce), podskok i skręt bioder, przeciwskręt barków, machanie rąk, głowa prosto. Eksport bez przesunięcia o 1 klatkę (pętle bez zacięcia). Porównanie: `art/source/sketches/anim_*.gif`.
  - [x] Nowe Idle, Jump i Dash (2026-11-15, ten sam skrypt): Idle 4 s (oddech, przenoszenie ciężaru, rozglądanie się), Jump (ręce w górę przy odbiciu, w szczycie na boki, nogi do lądowania; ostatnia klatka trzymana do ziemi), Dash (wypad z rękami w tył, poza gotowa w 2. klatce, bo dash trwa 0,18 s). Stare wersje w pliku jako `*_old`. Zostaje stary Shoot (tylko góra ciała).
  - Rośliny (2026-11-12): 5 gatunków × 3 etapy w `art/source/plants.blend`, eksport do `art/models/plants/<id>.glb`, dojrzałe 1.1-1.45 m. Animacje w kodzie (`plant.gd`): kołysanie z własnym rytmem, pulsujące świecenie, oddychająca paszcza Snappera, falujący kapelusz Boomshrooma, krążące krople Mgielnika. Mutacje przemalowują materiały modelu. Tekstury i materiały można robić w TextureCraft/MaterialCraft (ArtCraft, CLI w `D:\Programy\Craft`).
- [x] Autoload `GameState`: cykl, odkrycia, zasoby, Równowaga biomów, Uwaga planety, zapis/wczytanie JSON.
- [x] Mapa klawiszy: WASD ruch, Spacja skok, Shift sprint, E interakcja, LPM narzędzie, Q skan, F9 następny cykl (debug).
- [x] Scena startowa `scenes/main.tscn` (dolina, światło, niebo, atrapa postaci, HUD z cyklem).
- [x] Test `tests/test_game_state.gd` (16 sprawdzeń, przechodzi).

## M1. Rdzeń: czy sadzenie jest fajne?

**Test etapu:** tester sam z siebie sadzi kilka roślin i chce zobaczyć, co wyrośnie.

- [x] Postać TPP: `CharacterBody3D` + ruch, skok, sprint (`scenes/player/player.tscn`).
- [x] Kamera za plecami w stylu Risk of Rain 2: `SpringArm3D` + `Camera3D`, bez przenikania przez ściany.
- [x] Mały teren Zielonej doliny: blockout z prostych brył (`scenes/levels/valley.tscn`): chatka, staw, drzwi wyprawy, skały, drzewa, góry w tle.
- [x] Dane roślin jako `Resource` (`scripts/data/plant_data.gd` + `data/plants/*.tres`).
- [x] Swobodne sadzenie: podgląd miejsca (zielony/czerwony) + informacja, **dlaczego** nie można tu posadzić: brak nasion, to nie gleba, za stromo, za daleko, za blisko innej rośliny.
- [x] Wzrost w etapach z wyraźną zmianą modelu i krótką animacją "podskoku".
- [x] Zbiór: efekt cząsteczkowy, dźwięk, przedmiot leci do plecaka. Zbiór oddaje 1-2 nasiona.
- [x] Podlewanie (konewka, 5 porcji, napełnianie w stawie). Spragniona roślina ma kropelkę nad sobą i suchą glebę.
- [x] 3 pierwsze gatunki: Voidberry (jedzenie), Crystal Bloom (surowiec, bez wody, rośnie wolno), Snapper (roślina-narzędzie, daje tylko nasiona).
- [x] Czas farmy w **cyklach** (1 wyprawa = 1 cykl) + F9 przewija cykl, F10 nowa gra (debug).
- [x] Zapis i wczytanie gry (JSON, autozapis po każdej zmianie farmy i przy zamknięciu okna).
- [x] Bonus: dojrzały Snapper śledzi gracza głową i kłapie, gdy ten podejdzie za blisko.
- [x] Testy: `tests/test_farm_loop.tscn` (22 sprawdzenia pętli farmy) + podgląd roślin `tests/showcase.tscn`.
- [x] Prawdziwe dźwięki zamiast syntezy (2026-11-14). Paczki CC0 (Kenney, OpenGameArt; spis w `audio/LICENSES.md`), składane skryptem `tools/audio/build_sounds.py` do `audio/sfx/<zdarzenie>/<a|b|c>/`.
    - Każde zdarzenie ma 2-3 kandydatów po kilka wersji; gra losuje wersję i lekko zmienia wysokość. Wybór w `audio/sfx/picks.json`.
    - Nowe: kroki (trawa, grządka, bieg), klik latarki, klik i najechanie na przyciski, tła dnia i nocy dla bazy i łąki (przenikają się z zegarem).
    - Szyny głośności SFX, Ambient, Music.
    - [x] Kandydaci dźwięków (2026-11-20, decyzja autora): gra losuje kandydata (a, b, c) przy każdym odtworzeniu, zamiast grać jednego wybranego. `picks.json` wybiera już tylko pętle tła.
    - [x] Suwaki głośności (SFX / tło / muzyka) w menu głównym (Settings) i w menu pauzy pod Esc, zapis w `user://settings.cfg` (2026-11-15). Tam też przełącznik pełnego ekranu (F11 / Alt+Enter).
    - [ ] Wiatr jako osobna warstwa tła: **autor dostarczy nagranie** (ambient z YouTube); wtedy pętla 20-40 s bez szwu pod `amb_*`.
    - [x] Muzyka menu: **„Star Rodeo”** (epicka orkiestra + country, ok. 80 s), skomponowana w SoundCraft na próbkach VSCO 2 CE (`tools/audio/star_rodeo.py`, sesja do edycji: `D:/Audio/Sessions/StarRodeo/star_rodeo.scraft`). W grze muzyka cichnie.
    - [x] Muzyka bossa na później: **„Boss Rodeo”** (electro + country, e-moll, 132 BPM, ok. 95 s): przesterowany galopujący bas, stopa na ćwierćnuty, fiddle i lead grają hoedown, w breaku „train beat” i harfa jako banjo, okrzyki robo-kowboja „yee-haw” (synteza formantowa, `tools/audio/fx_synth.py`). Skrypt: `tools/audio/boss_rodeo.py`, sesja: `D:/Audio/Sessions/BossRodeo/boss_rodeo.scraft`. Plik: `audio/music/boss_rodeo.ogg` (jeszcze nigdzie niepodpięty).
    - [x] Druga muzyka bossa: **„Rodeo Rave”** (agresywny hard rave + country, f-moll, 150 BPM, ok. 82 s; własny utwór w klimacie Little Big, nie kopia): przesterowana stopa hardstyle strojona pod akordy, przesterowany bas na offbeatach (w drugim dropie „rolling”), piszczący lead, fiddle i banjo w hoedownie, chór HEY!/HA!/HOO! strojony do f-moll, YEE-HAW przed dropami, nagły koniec. Skrypt: `tools/audio/rodeo_rave.py` (wspólne składanie: `tools/audio/sc_song.py`), sesja: `D:/Audio/Sessions/RodeoRave/rodeo_rave.scraft`. Plik: `audio/music/rodeo_rave.ogg`.
    - [x] Trzecia muzyka bossa: **„Stampede”** (twarda elektronika z akcentami country, c-moll, 152 BPM, ok. 86 s). Brzmienie dostrojone pomiarami do utworu-odniesienia „Hardcore American Cowboy” (Little Big; tylko proporcje: pasma, subbas, głośność, gęstość dołu; bez melodii): stopa z czystym subem na ok. 49 Hz przez cały beat i przesterem tylko w górnej warstwie, bas z czystym subem i brudną warstwą na każdej szesnastce, jasna góra, prawie stała energia, -10 LUFS. Skrypt: `tools/audio/stampede.py`, sesja: `D:/Audio/Sessions/Stampede/stampede.scraft`.
    - [x] **„Hoedown Circuit”** (wyraźny elektroniczny beat + czyste country z dużą ilością banjo, E-dur, 144 BPM, ok. 93 s; inspiracja: tempo i charakter „Country Boy” Alana Jacksona, bez melodii). Krótka stopa z przerwami, klaśnięcie z werblem na 2 i 4, country „boom-chick” (kontrabas pizzicato + sub), w refrenie bas na offbeatach, banjo z modelu fizycznego (Karplus-Strong, `fx_synth.banjo_note`) w rollach Scruggsa, ostatni refren o cały ton wyżej. Wyrazistość pulsu zmierzona: akcenty na beatach +5..7 dB ponad resztę (w „Stampede” ok. +1,6). Skrypt: `tools/audio/hoedown_circuit.py`, sesja: `D:/Audio/Sessions/HoedownCircuit/hoedown_circuit.scraft`.
    - [x] **Muzyka bazy „Homestead”** (spokojna, akustyczna, bez elektroniki i perkusji; G-dur, 66 BPM, pętla 32 takty ok. 116 s bez szwu): łagodne banjo z modelu fizycznego gra palcami, cicha wiolonczela, miękkie smyczki, skrzypce z wolną melodią, harfa. Gra w bazie cicho (-12 dB) pod tłem natury; na wyprawie cichnie. Skrypt: `tools/audio/homestead.py`.
    - [x] **„Heavy Pulse”** (prawie sam rytm, 60 BPM, f-moll, ok. 100 s): krótka stopa + głęboki bas 808 (F1 ok. 44 Hz, z saturacją; nuty skrócone, żeby bas pulsował z rytmem), klaśnięcie z werblem na 2 i 4, trapowe hi-haty z przebiegami 32-kami i triolami, perkusja VSCO (wielki bęben, kongi, tumba, klawesy, kłody, kowadło), melodii prawie brak (ciemny akord-tło). Skrypt: `tools/audio/heavy_pulse.py`. Jeszcze nigdzie niepodpięty (np. rajd, napięcie, boss).
    - [ ] Podmiana okrzyku (**przypominać autorowi co jakiś czas**): nagrać własne „iiihaaa” i wstawić jako `D:/Audio/Sessions/BossRodeo/fx/yeehaw.wav` (plus `_low`, `_short`), potem `python tools/audio/boss_rodeo.py`.
    - [ ] Autor: przesłuchać „Star Rodeo” i powiedzieć, co zmienić (tempo, instrumenty, długość, czy grać też w bazie).
    - [ ] Eksport gry: dodać `audio/sfx/*.json` do filtra plików nie-zasobów w ustawieniach eksportu (inaczej wybór dźwięków nie trafi do builda).
- [x] **Playtest M1** (2026-11-20, kuzyn): podoba się, za mało rzeczy do zobaczenia (patrz „Teraz”).

## M2. Mini-wyprawa: czy decyzja o ewakuacji daje napięcie?

**Test etapu:** tester waha się, czy zostać jeszcze chwilę, i potrafi powiedzieć dlaczego.

- [x] Ekran przygotowania przy drzwiach wyprawy: wybór Snapperów i Voidberry z magazynu, plecak 10 miejsc, przycisk "Przeczekaj cykl" (stara atrapa).
- [x] Obszar wyprawy poza bazą: `scenes/levels/expedition_meadow.tscn` "Dzika łąka" (ręcznie zrobiona; generowanie losowe później).
- [x] Znajdźki: losowo 11 z 16 miejsc: nasiona (3 gatunki), kryształy, rzadka próbka "Lśniący mech".
- [x] Dzikie krzewy Voidberry: owoce zjada się na miejscu (+25 Kondycji).
- [x] Akcja skanu (Q): zapisuje odkrycie w `GameState` od razu, więc zostaje nawet po porażce (pełna baza danych w M3).
- [x] Drapieżnik Thornback: śpi w legowisku i atakuje tylko, gdy podejdziesz bliżej niż 3.5 m (R3-7). Od Przebudzenia 50 patroluje, przy 100 poluje wszędzie. Ogłuszony albo złapany ucieka, nie ginie.
- [x] Licznik **Przebudzenia** (`N1`): ok. 0.35/s, +2 za zwykłe znalezisko, +12 za rzadkie. Progi: 25 (komunikat), 50 (pogoda + patrol), 75 (gęstsza burza), 100.
- [x] Pogoda na progach 50 i 75 jest tylko klimatem, bez obrażeń (R3-8).
- [x] Próg 100, "planeta się broni": 90 s odliczania, burza zabiera 1 Kondycji/s.
- [x] **Kondycja** (zdrowie): pasek w HUD, spada od ugryzień (15) i burzy. Leczenie: dzikie owoce, Voidberry z plecaka.
- [x] Ogłuszacz (LPM, slot 1): promień do 14 m, ogłusza na 3 s, ładowanie 1.2 s, nie zabija.
- [x] **Rzucane nasiono Snappera** (slot 2): wyrasta w 1.5 s, łapie drapieżnika na 4 s, potem więdnie. Znika po wyprawie.
- [x] Ewakuacja: E przy lądowisku i 5 s na nim (zejście przerywa). Rakietowe Pnącze (`N2`) przetestować w M4.
- [x] Porażka = Kondycja 0 albo koniec odliczania z progu 100. Kapsuła ratunkowa zabiera farmera do bazy. Cały plecak przepada (także wyposażenie), odkrycia zostają. Zamknięcie gry w trakcie wyprawy = porażka.
- [x] 1 tymczasowe ulepszenie na wyprawę (losowo Turbo-buty albo Moduł witalności), w ryzykownym miejscu.
- [x] Powrót do bazy rozlicza 1 cykl (także po porażce), rośliny rosną, raport wyprawy w powiadomieniach.
- [x] Testy: `tests/test_expedition.tscn` (18 sprawdzeń: świat, drapieżnik, ogłuszenie, pułapka, burza, porażka, ewakuacja, powrót do bazy).
- [ ] Strojenie liczb po playteście: tempo Przebudzenia, siła ugryzienia, rozmiar plecaka.
- [ ] **Playtest M2:** sprawdzić test etapu (wpis do `docs/playtest-m2.md`).

## M3. Baza, obrona i trwały postęp: czy gracz wie, po co wraca?

**Test etapu:** po powrocie tester sam wybiera, co ulepszyć, i rozumie, jak to pomoże na następnej wyprawie. Po najeździe potrafi powiedzieć, dlaczego obronił albo stracił uprawy, i przed kolejną wyprawą sam dosadza rośliny obronne.

**Baza pod presją (nowe w wersji 2), część 1 zrobiona:**
- [x] **Uwaga planety** (0-100, globalna, trwała): +10 za Lśniący mech i +1 za kryształ wywiezione z udanej wyprawy, −5 po skromnej wyprawie albo porażce. Od 50 najazdy są częstsze i większe. Widać ją w HUD, na ekranie wyprawy i w raporcie (zawsze z powodem).
- [x] Najazd fauny w trakcie cyklu (Rój Chrupików), rozstrzygany automatycznie (`scripts/farm/raid.gd`). **Niepokój fauny** rośnie co cykl (szybciej przy wysokiej Uwadze), przy 100 jest najazd. Pierwszy najazd po 3 cyklach. HUD pokazuje, za ile cykli następny.
- [x] Obrona to promień wokół obrońcy i pojemność na najazd: dojrzały Snapper (3 m, 2 szkodniki), **Boomshroom** (4. gatunek, 4.5 m, 3) i słupki płotu z warsztatu (2 m, 1; bliskie słupki łączą się w płot, E zabiera słupek).
- [x] Boomshroom w bazie odrzuca gracza, który podejdzie za blisko. Na wyprawie rzucony (slot 4) robi puff i ogłusza wszystko w 4 m.
- [x] Przegonione Chrupiki zostawiają **nawóz** (slot 6: natychmiast +1 cykl wzrostu). Ślady najazdu (kupki nawozu, ogryzki) widać w bazie do następnego cyklu.
- [x] **Rytuał powrotu** (`W3`): kamera na lądowisko, kapsuła opada z płomieniem i osiada. Potem panel raportu z sekcjami Wyprawa / Planeta / Farma / Najazd. Ten sam panel po "Przeczekaj cykl".
- [x] Zasada: najazd nigdy nie niszczy więcej niż połowy upraw. Najgorzej: utracone etapy wzrostu i część kiełków.
- [x] Testy: `tests/test_base_defense.tscn` (56 sprawdzeń: reguły najazdu, Uwaga, warsztat, nawóz, płot, najazd na farmie, rytuał powrotu i raport) + Boomshroom w `test_expedition`.
- [ ] Strojenie po playteście: tempo Niepokoju, liczba Chrupików, zasięgi obrońców, Uwaga za łupy.

**Postęp:**

- [x] Skaner: skan działa na rośliny (dzikie krzewy, nasiona), stworzenia (Thornback, Pyłkowiec, Chrupik), minerały i próbki (kryształy, mech, Mgliste źródło).
- [x] Baza danych (`scripts/data/codex.gd`): 11 wpisów po 3 fakty, każdy fakt odkrywa inna akcja: skan, hodowla, zbiór, jedzenie, ogłuszenie, pułapka, puff, podniesienie, warsztat, obrona w najeździe. Komputer w chatce (E) pokazuje znane fakty, podpowiedzi do brakujących i procent kompletności. Nowy fakt = powiadomienie w HUD.
- [x] Podstawowy crafting: stół warsztatowy obok chatki + 4 receptury (słupki płotu, Duża konewka 8 porcji, Większy plecak +3, Ogłuszacz Mk2). Ulepszenia są trwałe i zapisywane.
- [x] Kuchnia ekspedycyjna (`E2`), na ekranie przygotowania jedno danie przed wyjściem:
  - Sałatka z Voidberry: +25 maks. Kondycji.
  - Kryształowa herbatka: Przebudzenie o 25% wolniej.
  - Pyłkowe ciastka: +20% szybkości.
  - Mgielny napar: Przebudzenie o połowę wolniej.
  Składniki schodzą z magazynu przy wyjściu.
- [x] Kolejne stworzenia: **Pyłkowiec** (latający zapylacz, ucieka przed graczem, ogłuszony gubi pyłek do ciastek) i stadko **Chrupików** (roślinożercy, od Przebudzenia 25 objadają dzikie krzewy; to te same Chrupiki, które najeżdżają farmę).
- [x] +2 gatunki roślin (razem 5): Boomshroom i Mgielnik (nasiono-zagadka).
- [x] 3 widoczne mutacje upraw, losowane przy dojrzewaniu (12%, a po nawozie 30%):
  - Złota: złote liście, +1 plonu.
  - Olbrzymia: większa, +2 plonu.
  - Świecąca: świeci, +1 nasiono.
  Mutacja jest zapisywana.
- [x] Poziom 2 łąki: odblokowany po odkryciu 6 z 9 wpisów poziomu 1. Wybór poziomu przy drzwiach wyprawy. Poziom 2 ma gęstą mgłę, Przebudzenie od 10, +2 znajdźki, Mgliste źródło i nasiono Mgielnika.
- [x] Nasiono-zagadka **Mgielnik** (`R3`) jest tylko na poziomie 2. Kiełkuje wyłącznie po podlaniu wodą z Mglistego źródła (E przy źródle, 1 porcja = 1 miejsce w plecaku); nawóz i zwykła woda go nie budzą. Potem rośnie normalnie i daje Mgielny owoc do naparu.
- [x] Testy: `tests/test_progress.tscn` (49 sprawdzeń: baza danych i odblokowanie poziomu 2, kuchnia, mutacje, Mgielnik, Pyłkowiec i Chrupiki, poziom 2, panel bazy danych).
- [ ] Strojenie po playteście: próg poziomu 2, szanse mutacji, siła dań, tempo objadania krzewów przez Chrupiki.
- [ ] *Opcjonalnie, jeśli starczy sił:* zlecenia z niekompletnych wpisów (`N5`), robot-botanik komentujący wpisy (`T4`), nazywanie gatunków przy pierwszym spotkaniu (`W4`).

Pomysły z puli wciągnięte do MVP: `N1`, `E2`, `R3`, uproszczony `E1` (Snapper, Boomshroom), `W3` (+ opcjonalnie `N5`, `T4`, `W4`). Reszta MVP to zakres z bazy wiedzy, sekcja 17.

**➡ Po M3: MVP gotowe** (zakres zrobiony 2026-11-11; brakuje playtestu i strojenia). Odpowiedzieć na 6 pytań z bazy wiedzy (sekcja 17.2) i zapisać wnioski w `docs/playtest-mvp.md`.

## M3+. Sterowanie, siatka i plecak (zrobione 2026-11-12, przed grafiką)

- [x] Sadzenie i budowanie na siatce 1×1 m: podgląd pola (zielone/czerwone) z kratkami dookoła. Każda roślina i słupek zajmuje jedno pole. Słupki co 1-2 pola łączą się w płot. Stare zapisy trafiają na siatkę same.
- [x] Sterowanie jak w RoR2: Ctrl włącza bieg (gaśnie, gdy stoisz albo strzelasz), Shift robi dash (odnowienie 2 s). Stan dasha widać w HUD.
- [x] Na wyprawie LPM używa przedmiotu z paska (pistolet z serią, jedzenie), a PPM drugiej ręki (rzucane nasiona). R zmienia rzucany przedmiot.
- [x] **Pistolet** (zamiast ogłuszacza): 10 obrażeń co 0.28 s, zasięg 30 m; Mk2 z warsztatu (3 kryształy + 2 kolce) daje 15 co 0.2 s.
  - Thornback ma 80 zdrowia. Postrzelony budzi się i atakuje, poniżej 25% ucieka, przy 0 pada i zostawia kolce. Zabicie dodaje +8 Przebudzenia.
  - Pyłkowiec (10 zdrowia) trafiony spada i gubi pyłek.
  - Chrupik (20 zdrowia) trafiony ucieka w panice, zabity zostawia nawóz.
- [x] **Plecak** na wyprawie (Tab): siatka przedmiotów z opisami, druga ręka (przeciągnij nasiono albo kliknij je dwa razy), wyrzucanie (PPM = 1 sztuka, kosz = cały stos). Wyrzucone leży na ziemi i nie podnosi ponownie Przebudzenia. Gra toczy się dalej przy otwartym plecaku.
- [x] Magazyn w bazie zostaje, ekran przygotowania dalej pakuje plecak.
- [x] Testy: `tests/test_controls.tscn` (35 sprawdzeń).
- [ ] Ręczny test sterowania: czucie dasha i serii, czytelność plecaka.

## 🎨 Plan grafiki i klimatu (kolejność ustalona 2026-11-12)

Każdy krok kończy się renderem do akceptacji. Potem grafika robiona na bieżąco: każda nowa rzecz w grze najpierw dostaje szkic do akceptacji, a dopiero potem model.

- [x] **1. Dokończenie modeli** (zamknięte 2026-11-13):
  - [x] stworzenia (2026-11-12, `art/source/creatures.blend`, `art/models/creatures/`): Thornback ze szkieletem i animacjami Sleep/Idle/Walk/Run/Attack/Stunned; Pollenbug (skrzydła trzepoczą w kodzie) i Muncher (podskoki w kodzie),
  - [x] budynki (2026-11-12, `art/source/buildings.blend`, `art/models/buildings/`, szkice w `art/source/sketches/`): chatka (blaszany barak z drewnianym frontem, gankiem, latarnią i anteną), warsztat, drzwi wyprawy (pierścień z portalem i kryształami, konsola), kapsuła z lądowiskiem (właz otwiera się po lądowaniu), słupek płotu, lądowisko ewakuacji z masztem,
  - [x] natura (2026-11-13, `art/source/nature.blend`, `art/models/nature/`): spiralna sosna, drzewo-grzyb, nowe drzewo-latarnia (świecące bańki pod noc), głaz z mchem i kryształami, stos kamieni, Mgliste źródło, legowisko Thornbacka, staw w bazie, góry z kryształami,
  - [x] znajdźki (2026-11-13, `art/source/pickups.blend`, `art/models/pickups/`): nasiono w łupinie (kolor z rośliny), kępa kryształów, świecący mech, pyłek, kolec Thornbacka, worek nawozu, fiolka mglistej wody, kiść voidberry, owoc Mgielnika, artefakt (klejnot nad cokołem z runami),
  - [x] gracz: hełm astronauty (pomysł autora, wybrany wariant A, 2026-11-13): szklana bańka, słomkowy kapelusz na jej czubku, kołnierz i rurka do plecaka; hełm noszony zawsze. Kopia modelu sprzed hełmu: `art/source/player_before_helmet.blend`.
  - [x] generowane pokrzywione drzewa (2026-11-13): `scripts/fx/tree_generator.gd` (4 gatunki: sękacz, wierzba z pnączami, parasol, straszydło ze świecącymi końcówkami; każde drzewo z innego ziarna). `TreeScatter` rozsiewa je przy starcie poziomu (baza 34 na obrzeżach, łąka 46), omija obiekty i strefy, drzewa mają kolizję pnia. Siatki trafiają do pamięci podręcznej `user://tree_cache/` (zmiana kształtu = podbić `TreeGenerator.VERSION`). Szkice: `art/source/sketches/trees_gen*.png`.
- [x] **2. Dzień i noc** (zasady ustalone 2026-11-13, opis w `Design_Zywa_Planeta.md`, sekcja "Pora doby"):
  - [x] zegar w czasie rzeczywistym: doba trwa 10 minut, płynie w bazie i na wyprawie, zapisuje się w grze; zegar w HUD; F8 przesuwa czas o 2 godziny (debug),
  - [x] niebo, słońce po łuku, świt i zmierzch, ciemna noc z gwiazdami i dwoma księżycami (biały i mały fioletowy); burza i mgła poziomu 2 nakładają się na porę doby (`scripts/fx/day_night.gd`),
  - [x] latarka na hełmie: snop światła tam, gdzie patrzy gracz, włącza się o zmierzchu,
  - [x] nocne znajdźki (2026-11-13, `art/source/night.blend`): Księżycowy kwiat (nasiono Moonpetal; w bazie rośnie i świeci tylko nocą, plon Moon Petal do Moon Tea), Świecące grzybki (Glow Spores), Odłamek spadającej gwiazdy (rzadki, Starfall Shard). 5 na wyprawę, widoczne i do podniesienia tylko nocą,
  - [x] nocne stworzenia: Świetlik-ćma (leci do latarki i krąży wokół gracza, trafiona gubi Lumen Dust) i Meduzowiec (dryfuje, macki parzą z bliska, zestrzelony daje Lumen Dust). Pyłkowce nocą śpią. Thornback bez zmian (będzie przerobiony),
  - [x] warsztat: Bright Lamp (2 Lumen Dust, 2 Glow Spores, 1 Starfall Shard) = latarka dalej i szerzej; 5 nowych wpisów w bazie danych.
- [x] **3. Bioluminescencja** (2026-11-13, `scripts/fx/bioluminescence.gd`, szkice `art/source/sketches/biolum_*.png`): kępy trawy kołyszące się na wietrze ze świecącymi czubkami (w dzień zwykła trawa), plamy świecącego mchu (turkus, zieleń, fiolet), świetliki i zarodniki w powietrzu, drzewa-grzyby świecące od spodu na niebiesko, świecące ślady stóp gracza (gasną po 4 s). Wszystko świeci tylko nocą; baza ma wolny środek z farmą.
- [ ] **4. Tekstury:** stylizowane, ręcznie malowane (TextureCraft, MaterialCraft), najpierw teren, potem rośliny, gracz i budynki.
  - [x] teren (2026-11-13, `art/materials/`, szkice `art/source/sketches/terrain_*.png`): baza = malowana łąka (miękkie plamy trzech zieleni, pociągnięcia pędzla, kwiatki), łąka wyprawy = obca ziemia (turkus z fioletowymi łachami i kryształkami), pole uprawne z bruzdami. Liczone w shaderze z bezszwowego szumu, bez plików tekstur,
  - [x] styl wszystkich modeli (2026-11-13, autoload `Stylize`, szkice `art/source/sketches/models_*.png`): cel-shading (ostre tony światła, jasna krawędź) + miękkie plamy farby. Działa na każdy model automatycznie; świecenie, mutacje i obwódki bez zmian,
  - [ ] ręcznie malowane tekstury z TextureCraft (serwer MCP w `.mcp.json`; projekty `.tcraft` i tekstury w `art/source/texturecraft/`):
    - [x] skała i stos kamieni (2026-11-13, w grze: `rock_painted.glb`, `rock_stack_painted.glb`),
    - [x] chatka, drzewo-grzyb, legowisko (2026-11-13, w grze: `hut_painted.glb`, `tree_mushroom_painted.glb`, `den_painted.glb`),
    - [x] warsztat, drzwi wyprawy, kapsuła, słupek płotu, latarnia ewakuacji, sosna, drzewo-latarnia (2026-11-14, w grze jako `*_painted.glb`),
    - [ ] reszta (rośliny, stworzenia, gracz, znajdźki).
    - Przepis v2 (zachowuje węzły modelu, np. Capsule/Hatch): `tc_prep2` robi UV na modelu z gry, TextureCraft maluje całość jednym skryptem z linii poleceń (`texturecraft-cli batch`), `tc_rebuild2` podmienia materiały.
    - Przepis: Blender (w tle) łączy części i robi czyste UV na materiał, TextureCraft wypala mapy i maluje warstwami (kolor bazowy z szumem, ciemne wnęki, jasne krawędzie; na kamieniach bez krawędzi, bo low-poly robi z nich siatkę), Blender składa model z teksturami. Materiały świecące zostają bez zmian. Podgląd 3D w TextureCraft wywraca serwer, więc wyniki ogląda się w Godocie.
- [ ] **5. Styl UI** (plansze w FigCraft, 2026-11-14; wybrany styl A "Field Notebook": kremowe karty z brązową ramką, twardy cień jak naklejka, pomarańczowe akcenty, font Lato w `art/fonts/`; plansze `art/source/sketches/ui_style_*.png`, pliki `art/source/ui/*.figcraft`):
  - [x] HUD bazy i wyprawy (`scripts/ui/notebook_theme.gd`): karta z zegarem i cyklem, podpowiedź z klawiszem w znaczku, powiadomienia na kartach, kwadratowe sloty z kolorową ikoną i ilością (nazwa wybranego nad paskiem), paski zdrowia i Przebudzenia, druga ręka, licznik plecaka,
  - [x] ikony przedmiotów (`art/ui/icons/`, renderowane w Godocie z modeli znajdziek skryptem `tests/_make_icons.tscn`; nowy przedmiot = dopisać go tam i uruchomić w oknie): w pasku narzędzi i w plecaku,
  - [x] menu główne (`scenes/menu.tscn`, ekran startowy): nocna dolina z bioluminescencją w tle, logo, Continue / New Game (przy zapisie trzeba kliknąć dwa razy) / Quit,
  - [x] okna w stylu notesu (wspólny motyw `NotebookTheme.theme()`): baza danych, warsztat, przygotowanie wyprawy, raport, plecak; wysokość okien według treści,
  - [x] baza danych jako ekran komputera (zakładki Plants / Creatures / Minerals, lista z ikonami i kropkami postępu, karta wpisu z faktami i podpowiedziami) i warsztat jako drzewko ulepszeń (karty z ikoną i stanem Craft / Owned / Missing, linie pokazują kolejność rozwoju, bez blokowania) (2026-11-14).
  - Montserrat (nagłówki z planszy) nie jest dostępny jako plik; w grze nagłówki są pogrubionym Lato. Montserrat można dołożyć później (darmowa licencja OFL).

## UI: angielski, mniej tekstu, obwódki (zrobione 2026-11-12)

- [x] Wszystkie napisy w grze po angielsku (nazwy, podpowiedzi, okna, baza danych). Dokumenty zostają po polsku.
- [x] Mniej tekstu:
  - HUD bazy to tylko „Cycle N / Raid in N cycles”; magazyn pod przytrzymanym Tab.
  - Na wyprawie paski Health i Awakening oraz licznik plecaka.
  - Podpowiedzi typu „[E] Harvest”, najwyżej 4 krótkie powiadomienia naraz.
  - Dash pokazuje się tylko podczas ładowania.
- [x] Żółta obwódka (`scripts/fx/outline.gd`) na obiekcie, z którym można teraz coś zrobić: dojrzała albo spragniona roślina, słupek, warsztat, komputer, drzwi, staw, znajdźki, krzewy, źródło, lądowisko.
- [x] Celownik na ziemi pod rośliną liczy się jako celowanie w roślinę.

## M4. Żywa planeta v1

**Test etapu:** tester po 2-3 wyprawach potrafi powiedzieć, **dlaczego** dolina się zmieniła, i raz celowo próbuje ją rozchwiać albo ustabilizować dla konkretnej nagrody. Przynajmniej raz rezygnuje z rzadkiego łupu, bo boi się o bazę.

**Baza pod presją v1:**
- [ ] Zagrożenia planety dla bazy: burza i meteoryt (meteoryt zostawia minerały i szansę na mutację).
- [ ] Obrona przed planetą: osłony nad grządkami, piorunochron z Crystal Bloom.
- [ ] Prognoza przed wyprawą (`N4`): "w tym cyklu: rój szkodników / burza". Decyzja, co dosadzić przed wyjściem.
- [ ] Najazd na żywo przy powrocie (najwyżej co 3-4 cykle): kapsuła ląduje w środku ataku, 60-90 s obrony.
- [ ] Nowe progi Uwagi planety z zagrożeniami planety.

**Żywa planeta:**

- [ ] **Równowaga** biomu (`K1`): jedna wartość -100..+100 dla Zielonej doliny, wspólna dla wszystkich poziomów.
- [ ] 4 wejścia: nadmierne zbieranie jednego gatunku (−), wydobycie (−), sadzenie rodzimych roślin w terenie (+), dokarmianie (+). Farma w bazie się nie liczy.
- [ ] Pole "biom bazowy" w `PlantData` (rodzimy = biom bazowy to ten biom; odmiany gracza dalej rodzime).
- [ ] 3 progi: ≤-50 agresywny wariant drapieżnika + start od Przebudzenia 25 · neutralny · ≥+50 mniej agresywnych spawnów.
- [ ] Nagroda ≤-50: Cierniowa Voidberry (próbka z dzikiej odmiany → owoc lepiej leczy, kolce chronią ją i sąsiednie grządki podczas najazdów roślinożerców).
- [ ] Nagroda ≥+50: Lumen-mól (dokarmiony idzie do bazy, zwiększa plon farmy).
- [ ] Dwa zablokowane wpisy w bazie danych z podpowiedzią, gdzie szukać obu nagród.
- [ ] Reakcja poniżej progów: przetrzebienie rośliny-żywiciela → jej zapylacz odlatuje do końca cyklu.
- [ ] Nasadzenia w terenie nie są zapisywane w scenie, liczy się tylko efekt na Równowagę.
- [ ] Limit ±30 Równowagi na wyprawę + malejące zwroty każdego wejścia.
- [ ] Hamulec: dryf w stronę 0 z obu stron o kilka punktów na cykl.
- [ ] Dziennik biomu po wyprawie, zawsze z liczbami: "Zebrałeś 40 Voidberry → Pollenbugi odleciały, Równowaga −15".
- [ ] Pozostałe progi Przebudzenia: 25 (ostrzeżenie dźwiękowe + kolor nieba), 75 (drapieżnik aktywnie poluje, burza gęstnieje).
- [ ] Skaner "Sieć życia" (`K2` / `W1`): świat przygasa, świecące nici zależności, każdy typ relacji w innym kolorze.
- [ ] Stworzenia reagują na Równowagę (inne zachowanie albo inne warianty).
- [ ] Test: Rakietowe Pnącze (`N2`) zamiast punktu ewakuacji. Zostawić to, co lepsze w playteście.
- [ ] Zdziczałe ziemskie uprawy (`T1`): 2 gatunki w dolinie z fragmentem historii w bazie danych.

## M5. Drugi biom: Grzybowy las

**Test etapu:** tester sam zauważa ślady tajemnicy i bez podpowiedzi szuka kolejnych.

- [ ] Nowa scena biomu z własnym nastrojem, florą i fauną.
  - [x] Szkic etapu 1 (2026-11-20, zaakceptowany wstępnie): [docs/Grzybowy_Las_szkic.md](docs/Grzybowy_Las_szkic.md), rendery `art/source/sketches/mushroom_*.png` + GIF pulsu grzybni. Olbrzymie Towercapy (półmrok), Bellcapy, nowe Shelfcapy na klifach (świecący spód, wspinaczka), Glowcapy, pulsująca grzybnia. Autor: nitki grzybni mają być **jeszcze cieńsze**.
  - [x] **Las testowy w grze** (2026-11-20): na ekranie wyprawy wybór „Mushroom Forest (test)” (`scenes/levels/expedition_mushroom.tscn`, `scripts/expedition/mushroom_expedition.gd`).
    - Teren losowany przy każdej wyprawie (`scripts/fx/forest_terrain.gd`, shader `art/materials/forest_floor.gdshader`): pagórki i grzbiety, miejscami tarasy z uskokami, 7 dołów ze stromymi ścianami i jedną rampą, kręty kanion przez całą mapę (strome ściany ok. 13 m, wejścia rampami na końcach), płaskie lądowisko. Kolizja `HeightMapShape3D`, ładowanie poniżej 1 s.
    - Grzyby z brył wg szkicu (`scripts/fx/forest_mushrooms.gd`, MultiMesh): 110 Towercapów, 110 Bellcapów, kępki Glowcapów; trzony z kolizją. Półmrok: `DayNight.canopy` (słabsze słońce i światło otoczenia, fioletowa mgła).
    - **Hammer Cap** w kanionie (`scripts/expedition/hammer_cap.gd`, bryły zamiast modelu): w rytmie podnosi kapelusz (spód świeci na bursztynowo) i uderza; fala trafia tylko gracza na ziemi (skok ją przeskakuje), pod kapeluszem boli mocniej. Pistolet przerywa zamach, Boomshroom ogłusza. Nie da się go zabić. Ulepszenie leży w środku kanionu.
    - Test: `tests/test_forest.tscn` (24 sprawdzenia).
    - [x] **Modele otoczenia i nowy Hammer Cap** (2026-11-20, uwagi autora: "mapa pusta", zdjęcia świecących grzybów, "zapomnij o low poly", "niech się wszystko porusza"):
      - Blender: `tools/blender/forest_props.py` → `art/models/forest/*.glb`, źródło `art/source/forest_props.blend`, arkusz `art/source/sketches/forest_props_*.png`. 15 modeli: świecące zielone wachlarze (ścienne x2, naziemne), kędzierzawa rozeta, boczniaki z pomarańczowo świecącymi blaszkami, czernidłaki x2 (ciemne, świecący fioletowy brzeg), grzyb koralowy (świecące końcówki), paprocie x2 (z pastorałami), krzew z bulwami, głazy z mchem x2, kłoda z grzybami, martwy pień z piętrami boczniaków.
      - Godot: wspólny shader `art/materials/forest_prop.gdshader` (kolor z wierzchołków, blaszki i świecenie z UV, **ruch**: kołysanie, falowanie brzegów, pulsowanie, każdy egzemplarz w swoim rytmie), loader `scripts/fx/forest_props.gd`, rozsiew `scripts/fx/forest_details.gd` (ok. 2300 sztuk: ziemia, ściany kanionu i dołów, trzony olbrzymów; MultiMesh w kawałkach 48 m, znikają za 110 m; kłody, pnie i duże głazy z kolizją). Olbrzymy: brzegi kapeluszy falują, blaszki pulsują, Glowcapy migoczą.
      - **Hammer Cap** od nowa: korzeń wrośnięty w ścianę kanionu, trzon wychodzi ze ściany i zagina się w górę; atak: odchyla się (bursztynowe ostrzeżenie) i uderza kapeluszem w dno kanionu, fala od miejsca uderzenia.
      - Wydajność: ok. 60 kl./s (z synchronizacją), las ładuje się ok. 1 s.
    - [ ] Wpis Hammer Capa w bazie danych.
  - [ ] **Etap 1 do końca** (plan: [docs/Grzybowy_Las_etap1.md](docs/Grzybowy_Las_etap1.md), szkice `art/source/sketches/stage1_*.png` z `tools/blender/stage1_sketch.py`, czekają na akceptację): reżyser przeciwników poza polem widzenia (jak Risk of Rain 2) z kokonami z grzybni, Sporebat, Spore Tick, Rotling, Rot Thornback, grzybnia, zarodniki, Shelfcapy, jaskinie, wioska Sporekinów z handlem, halucynacje, Słoneczna Polana z Rot Shepherdem (Lantern Moth, Glade Bloom), arena i The Puffking (Cluster Shroom), Spore Mask, Mushroom Log, Mycelium Fiber, Fungicide, Spore Pod na łące jako wejście do lasu.
    - [x] **Krok 1: reżyser + kokony + Sporebat + Rotling** (2026-11-20, szkice zaakceptowane):
      - `scripts/expedition/spawn_director.gd`: punkty 0,6/s × (1 + Przebudzenie/50), x2 w burzy; grupy kupowane za punkty (Sporebat 4/szt., 3–5; Rotling 6/szt., 2–4); spawn 25–45 m od gracza, **poza kamerą** (stożek widzenia + promień na zasłonięcie); max 12 naraz; dalej niż 90 m wracają do grzybni (połowa punktów wraca); pierwsze 20 s bez spawnu; bezpieczne strefy (`add_safe_zone`, na wioskę i Polanę); zabicie +2 Przebudzenia.
      - `spore_cocoon.gd`: kokon z grzybni wyrasta, drży, po 1,5 s pęka (dźwięk z kierunku).
      - `forest_creature.gd` (baza: trafienia, ogłuszenie Boomshroomem, Snapper, śmierć → **Mycelium Fiber**), `sporebat.gd` (krąży, zapowiada nurkowanie piskiem i rozbłyskiem blaszek, nurkuje 8 obrażeń, ginie od 1 strzału, ogłuszony spada), `rotling.gd` (zarażony Muncher z naroślami, biegnie 4,2 m/s, gryzie 10, 3 strzały, przy śmierci chmura zarodników).
      - Modele: `tools/blender/forest_creatures.py` → `art/models/forest/sporebat.glb` (skrzydła machają w kodzie), `cocoon.glb`, `rot_growths.glb`, `mycelium_fiber.glb`.
      - Test: `tests/test_forest.tscn` +12 sprawdzeń (spawn poza kamerą, kokon, ugryzienie, nurkowanie, drop, Przebudzenie, powrót do grzybni, zakup grupy).
      - Do zrobienia przy kroku 7: wpisy w bazie danych (Sporebat, Rotling, Mycelium Fiber), zastosowanie Mycelium Fiber w warsztacie (Spore Mask w kroku 4).
    - [x] **Krok 2: świat** (2026-11-21):
      - Teren (`forest_terrain.gd`): losuje też arenę bossa (płaska niecka ≥ 100 m od lądowiska), 3 jaskinie (pierwsza = Grota Zarodników) z równą podłogą i 14 serc grzybni; nic nie rośnie w jaskiniach, na arenie ani przy wejściach.
      - **Grzybnia** w shaderze ziemi (`art/materials/mycelium.gdshaderinc`, szum liczony w shaderze): cieniutkie nitki o stałej grubości w pikselach, w plamach i gęsto przy sercach; z serc co jakiś czas rozchodzi się fala światła; przy arenie nitki grubieją w sznury (droga do bossa). Nitki mogą być jeszcze cieńsze (`width_m` w `mycelium_threads`).
      - **Zarodniki pod kapeluszami** (`forest_spores.gd`): drobne cząsteczki pod 14 najbliższymi olbrzymami, każda z innym czasem życia, gasną w miarę opadania.
      - **Shelfcapy** (`forest_shelves.gd`, model `shelfcap.glb`): schody z półek (co 1,15 m) na ścianach kanionu i 3 dołów, z kolizją.
      - **Jaskinie** (`forest_caves.gd`, shader `cave_wall.gdshader`): kopiec z grubą ścianą i łukowym wejściem; w środku ciemno, na ścianach plamy cieniutkiej, pulsującej grzybni, świecące grzybki, kępy grzybów, drobne zarodniki; znajdźki w głębi. **Grota Zarodników**: fioletowa, gęsta grzybnia i zarodniki, strefa `spore_fog` (halucynacje w kroku 3), najlepsze znajdźki (2x Glowmoss, Starfall Shard).
      - Test: +12 sprawdzeń w `tests/test_forest.tscn`. Zrzuty: `art/source/sketches/forest_ingame_9..14_*.png`.
    - [x] **Krok 3: Spore Tick, Rot Thornback, halucynacje** (2026-11-21):
      - `spore_tick.gd` (model `spore_tick.glb`): chodzi też po stromych ścianach, z 6 m skacze na gracza (6 obrażeń + dawka zarodników), 2 strzały, przy śmierci fioletowy puff.
      - `rot_thornback.gd`: zarażony Thornback z naroślami; z 4–14 m grzebie łapą (0,8 s) i szarżuje prosto (18 obrażeń + odrzut), potem dyszy; 7 strzałów, przy śmierci chmura zarodników, 2x Mycelium Fiber.
      - Reżyser: nowe grupy Spore Tick (5/szt., 1–3) i Rot Thornback (14).
      - `hallucination.gd`: ukryty licznik (mgła Groty Zarodników ok. 0,11/s, trafienie Ticka +0,25, opada 0,06/s poza mgłą; Spore Mask = ulepszenie `spore_mask` chroni). Od 0,3 obraz faluje i kolory płyną (nakładka na ekran), od 0,6 do 4 fałszywych znajdziek (fioletowe, migoczą, bez cienia, przy podniesieniu „Not real”), przy pełnym do 3 fantomów (Rotling, Tick, Rot Thornback; nie ranią, rozwiewają się po strzale). `stage` przygotowany na kolejne etapy.
      - Grzybnia jeszcze cieńsza (poniżej piksela nitka słabnie zamiast grubieć). Przed wejściem do jaskiń płaski podjazd.
      - Test: +18 sprawdzeń w `tests/test_forest.tscn`. Zrzuty: `forest_ingame_15..18_*.png`.
    - [ ] Jaskinie (osobne bryły, mapa wysokości ich nie zrobi), półki Shelfcap na ścianach kanionu, grzybnia shaderem na ziemi, zarodniki pod kapeluszami.
- [ ] Zarodniki jako warunek środowiskowy (widoczność, wzrost).
- [ ] Grzybnia widoczna na powierzchni, pulsuje przy niskiej Równowadze (`T2`), a przy bardzo niskiej otwiera "oczka", które śledzą gracza (`W5`).
- [ ] **Plaga grzybowa w bazie:** pojawia się dopiero po pierwszej wizycie w lesie ("przywozisz zarodniki na butach"), zaraża uprawy.
- [ ] Obrona przed grzybami: roślina antygrzybowa z lasu, osuszanie gleby albo lampa UV.
- [ ] Gatunek-zwornik lasu (`K5`).
- [ ] Terroir nasion (`R2`): nasiona z lasu dostają lokalną cechę.
- [ ] Pierwsza placówka terenowa + sukcesja (`K4`).
- [ ] Przejście z doliny do lasu odblokowywane technologią lub odkryciem.

---

## 🔜 Dalej (po M5, wybierać z puli wg playtestów)

- [ ] Geny jako kafelki cech + laboratorium krzyżowania (`R1`)
- [ ] Kolejne rośliny-narzędzia (Floatroot jako platforma itd.) + **Seed Cannon**: wyrzutnia strzelająca nasionami z farmy (`E1`)
- [ ] Zagrożenia flory dla bazy: inwazyjne pnącza, chwasty z uciekłej mutacji (`R8`), rośliny-pasożyty + obrona (pielenie, roślina-konkurent, herbicyd)
- [ ] Pamięć gatunków (`K3`)
- [ ] Towarzysz z plecaka (`K7`)
- [ ] Ekosystem jako obrona farmy: drapieżnik-sojusznik przyciągnięty kwiatami (`K6`)
- [ ] Kurierzy próbek (`N3`) · Kolumny anomalii (`N7`)
- [ ] Zarośnięty plecak po porażce (`N6`)
- [ ] Farma, która gra (`R6`) · Wędrowiec (`R4`) · Glowroot (`R5`)
- [ ] Ucieczka mutanta (`R8`)
- [ ] Dreamfruit (`T5`) · Fotograf-przyrodnik (`E3`)
- [ ] Muzyka: spokojna w bazie, niepokojąca na wyprawie (baza wiedzy, sekcja 16)
- [ ] Dolina nocą przy wysokiej Równowadze: "grające" rośliny (`W2`). Sam cykl dnia i nocy oraz bioluminescencja przeszły do planu grafiki (wyżej).
- [ ] **Śpiewające rośliny** (pomysł użytkownika, 2026-11-12):
  - **Humming Corn:** kukurydza, która nuci, gdy wieje wiatr albo gdy podejdziesz.
  - **Chór drzew:** drzewa śpiewające razem pieśni w klimacie pieśni rdzennych Amerykanów.
  - Rośliny mogą zgrywać się w melodię, kiedy rosną obok siebie (łączy się z `W2` i `R6` "Farma, która gra").
- [x] **Horyzont i większa mapa** (uwaga autora, 2026-11-13; zrobione 2026-11-14): krawędzi świata już nie widać.
    - `TerrainRing` (`scripts/fx/terrain_ring.gd`): płaski środek (y = 0, cała rozgrywka), wokół wzgórza do grzbietu i dalsze pagórki do 260 m, które giną we mgle. Kolizję mają tylko zbocza przy granicy; płaski środek ma dalej własną podłogę `Ground` (grządki).
    - Łąka: obszar gry z ±45 m do ±64 m, grzbiet 92 m. Więcej znajdziek (15 dziennych, 7 nocnych, 26 miejsc), 6 krzewów, 5 miejsc na artefakt, więcej skał, drzew i trawy.
    - Baza: ściany z ±40 m na ±46 m, grzbiet 70 m.
    - Na zboczach rosną generowane drzewa (`TreeScatter` z `terrain` i `ring_inner`), kryształowe góry odsunięte na wzgórza i powiększone.
- [x] **Mapy 20x większe** (2026-11-20, po playteście: "za mało rzeczy do zobaczenia"): powierzchnia ok. 20x, bok ok. 4,5x.
    - Baza: ściany ±205 m (było ±46), płaski środek 192 m, grzbiet 250 m. Rdzeń farmy (grządki, chatka, brama, staw, warsztat, kapsuła) bez zmian, więc zapisy działają. 6 nowych stawów (woda do konewki), góry odsunięte na ok. 300 m i powiększone, 8 nowych.
    - Łąka: ściany ±285 m (było ±64), płaski środek 272 m. Dawny układ rozciągnięty 2x (lądowisko na z=68, legowisko Thornbacka na z=-62, źródło z poziomu 2 na (-54, 0)); 120 miejsc na znajdźki (60 dziennych + 28 nocnych na wyprawę), 26 dzikich krzewów, 16 miejsc na artefakt, 41 dodatkowych stadek stworzeń po całej łące (`WILD_HERDS` w `expedition.gd`). Przebudzenie rośnie wolniej (0,25/s zamiast 0,35), do strojenia w playteście.
    - Treść: gaje i polany z szumu (`clustering` w `TreeScatter`), nowy `PropScatter` (skały, grzyby-drzewa, latarniowce, stożki w grupach), więcej trawy, mchu i świetlików.
    - Wydajność (60 kl./s jak przed powiększeniem): drzewa w 3 poziomach szczegółów z tego samego ziarna (`TreeGenerator` lod 0/1/2, pełne do 25 m, średnie do 55 m, najlżejsze do 120 m; dalej mgła), bez płynnego przenikania (dithering kosztował ok. 5 ms), ograniczona liczba wariantów drzew (`variants`), trawa w kawałkach 32 m rysowanych do 75 m, świetliki i zarodniki wokół gracza (`particles_around_player`), cienie słońca do 70 m, teren z indeksami i jednym kwadratem w płaskim środku, `ScatterGrid` do sprawdzania odstępów. Ładowanie 5-8 s (przy pierwszym uruchomieniu ok. 14 s, bo generuje drzewa do pamięci podręcznej).
    - [x] **Droga do lądowiska na dużej łące** (2026-11-20, wariant B ze szkicu `art/source/sketches/beacon_B_*.png`): słup światła nad latarnią (`scripts/fx/evac_beam.gd`, widać ponad drzewami i przez mgłę, w dzień ciemniejszy turkus) + znacznik na HUD (`scripts/ui/beacon_marker.gd`): romb nad latarnią z odległością, poza ekranem strzałka przy krawędzi (za plecami z boku, omija paski i pasek narzędzi), bliżej niż 12 m znika.
- [x] **Maszyny farmy** (pomysł autora, 2026-11-13; szkic zaakceptowany i prototyp zrobiony 2026-11-15):
  - Szkic: `art/source/sketches/machines_1..6_*.png` (źródło `art/source/machines.blend`). Modele do gry buduje `tools/blender/machines_models.py` → `art/models/machines/*.glb` + ikona `art/ui/icons/drone_dock.png`.
  - **Dron nawadniający** (`scripts/farm/watering_drone.gd`, dok `drone_dock.gd`): warsztat „Watering Drone” (3 kryształy) daje dok; slot 9 na pasku stawia go na polu siatki, E zabiera. Dron podlewa spragnione rośliny w promieniu 14 m od doku (zbiornik 6 podlań, nie rusza konewki), z pustym leci do stawu, bez pracy wraca na dok. Nasiona-zagadki (Misty Water) zostawia graczowi. Dok w zapisie jako budowla `drone_dock`.
  - **Traktor** (`scripts/farm/tractor.gd`): stoi w bazie od startu, przy grządkach. E wsiada (farmer siedzi w fotelu, poza w `PlayerAnimator.set_seated`), WASD jedzie, E wysiada. LMB opuszcza siewnik: pasem 3 pól za traktorem zbiera dojrzałe uprawy i sadzi nasiona z wybranego slotu (inny slot = tylko zbiera). Pozycja w zapisie (`GameState.machines`).
  - Muzyka: po wejściu zawsze od początku `audio/music/cotton_eye_joe.mp3` (tylko lokalnie, w `.gitignore`, utwór chroniony); bez pliku gra własny „Hoedown Circuit”. Po wyjściu wraca „Homestead”.
  - Do zrobienia później: traktor z warsztatu zamiast od startu? orka (bruzdy na ziemi), dźwięk silnika, kolizja siewnika z płotem, więcej dronów / ulepszenia zasięgu i zbiornika.
- [ ] Trzeci biom (Pustynia lub Zimowe góry)

## 🌌 Kiedyś

- [ ] Finał (wstępny): Serce planety jako osobna scena + drzewa-kotwice z 3 biomów (`T3`). Potwierdzić po trzecim biomie.
- [ ] Pojazdy: Mini Rover, potem traktor i harvester
- [ ] Automatyzacja: rury, taśmy, autopilot pojazdów
- [ ] Drony zwiadowcze
- [ ] Wieżyczki z bazy wiedzy (13.3), jeśli obrona roślinami okaże się za mała
- [ ] Hydroponika, aeroponika, aquaponika
- [ ] Chimery (`R7`) · Migracja Skywhale (`K8`) · Skywhale jako archiwa (`T6`)
- [ ] Pozostałe biomy (jaskinie lawowe, las gigantów, wysoka trawa, bagna)
- [ ] Wydanie na itch.io

---

## ❓ Decyzje do podjęcia

Propozycje rozstrzygnięć są w [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md). Poniżej to, co zostało otwarte:

- [ ] **#5** Ile planety jest dostępne bezpośrednio, a ile przez osobne sceny wypraw? (Propozycja na start: dolina z bazą = jedna scena, każdy biom = osobna scena wyprawy.)
- [x] **#8** Rozstrzygnięte 2026-11-12: pistolet zadaje obrażenia, stworzenia mają zdrowie i mogą zginąć (zastąpił ogłuszacz). Rośliny-narzędzia dalej łapią i ogłuszają.
- [ ] Czy zabijanie ma być wejściem "−" Równowagi biomu? Rozstrzygnąć w M4 (na razie zabicie drapieżnika daje +8 Przebudzenia).
- [x] Jak liczyć zasięg obrony w najeździe automatycznym? Rozstrzygnięte w M3: promień wokół każdego obrońcy + pojemność na najazd.
- [ ] **#9** Pojazdy bojowe: system czy opcja? (Propozycja: opcja, "Kiedyś".)
- [ ] **#10** Granice swobodnego budowania? (Propozycja: swobodne sadzenie, budynki na prostej siatce w bazie.)
- [ ] **#11** Woda i energia w różnych biomach? (Do zaprojektowania przy M5.)
- [ ] Czy oprócz liczb w dzienniku pokazywać stały pasek Równowagi na HUD? Rozstrzygnąć w playteście M4.
- [x] Czy baza też może być zagrożona (najazdy szkodników)? Tak, od wersji 2 (najazdy fauny w M3).
- [ ] Ostateczna nazwa planety (robocza: Elysium-7) i gry.

## ⚠️ Pilnować

- [ ] Każdy nowy pomysł: czy wzmacnia ≥2 z 3 filarów? Czy da się go przetestować w małym prototypie?
- [ ] **Najpierw szkic, potem wdrożenie.** Przed dodaniem czegoś nowego, co widać w grze (roślina, stworzenie, budynek, biom, efekt, UI), robimy szkic do akceptacji: rysunek 2D albo szybką bryłę w Blenderze z renderem. Dopiero po akceptacji model, animacje i kod. Przykłady w [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md), sekcja "Do naszkicowania".
- [ ] Gracz zawsze widzi, **dlaczego** coś się dzieje (roślina nie rośnie, stworzenie przyszło, biom się zmienił).
- [ ] Wyższy poziom biomu = nowa zawartość, a nie tylko mocniejsi wrogowie.
- [ ] Żadnego czekania w czasie rzeczywistym.
- [ ] Każde zagrożenie bazy ma przyczynę, którą gracz rozumie, i jasną stronę (nawóz, minerały, mutacja). Najazd nigdy nie niszczy całej bazy.
- [ ] Obrona bazy nie może zamienić gry w tower defense: najazdy na żywo rzadko, większość rozstrzygana automatycznie.
- [ ] Zakres: jeśli etap trwa 2x dłużej niż planowano, wyciąć połowę jego listy.
