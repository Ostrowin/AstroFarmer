# Astro Farmer: ToDo

Ostatnia aktualizacja: 2026-11-11 · Kierunek: **Żywa planeta** ([Design_Zywa_Planeta.md](Design_Zywa_Planeta.md)) · Pula pomysłów: [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md)

**Zasada nadrzędna:** jeden etap naraz. Nie zaczynaj kolejnego etapu, dopóki poprzedni nie przeszedł swojego testu. Każdy etap kończy się grywalnym buildem i jednym playtestem.

Kody w nawiasach (np. `K1`, `N2`) odnoszą się do pomysłów w [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md).

---

## 🎯 Teraz: zadanie na ten tydzień

- [x] Scena **"jedna grządka"**: kapsuła jako postać, kamera za plecami, jedno nasiono, 3 etapy wzrostu, zbiór z efektem i dźwiękiem.
- [x] Atrapa "drzwi wyprawy": przejście przez nie = +1 cykl = +1 etap wzrostu (test docelowej pętli cykli, bez czekania).
- [x] Zbiór oddaje 1-2 nasiona, więc można od razu posadzić znowu.
- [ ] Dać zagrać 1 osobie bez podpowiedzi. Zapisać jedno zdanie: czy sama posadziła drugą roślinę?

---

## M0. Przygotowanie projektu

- [x] Zainstalować najnowszą stabilną wersję Godot 4.x (jest 4.7.2 w `D:\Programy\Godot`).
- [x] `git init` w folderze projektu + `.gitignore` dla Godota (folder `.godot/`), `.gitattributes`, `.editorconfig`.
- [x] Dokumenty (baza wiedzy, podsumowanie, design, pomysły, ToDo) zostają w katalogu głównym, żeby linki między nimi działały. Raporty z playtestów trafiają do `docs/`.
- [x] Struktura folderów: `scenes/` (+ `levels/`, `ui/`), `scripts/` (+ `autoload/`), `data/plants/`, `data/creatures/`, `art/models/`, `art/textures/`, `audio/music/`, `audio/sfx/`, `tests/`, `docs/`.
- [x] Fizyka Jolt ustawiona w `project.godot`.
- [x] Pipeline grafiki (2026-11-12): własne modele w Blenderze (przez Blender MCP) → eksport `.glb` do `art/models/`. Źródła `.blend` w `art/source/` (z `.gdignore`, Godot ich nie importuje). Pierwszy model: gracz (farmer w ogrodniczkach i słomianym kapeluszu, szkielet 20 kości, animacje Idle/Run/Sprint/Dash/Shoot/Jump).
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
- [ ] Dźwięki są syntezowane w kodzie (`Sfx`). Podmienić na prawdziwe pliki, gdy będą. **Syntetyczne dźwięki irytują autora (2026-11-13): zająć się nimi zaraz po planie grafiki.**
- [ ] **Playtest M1:** dać zagrać 1 osobie i sprawdzić test etapu (wpis do `docs/playtest-m1.md`).

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

- [ ] **1. Dokończenie modeli:**
  - [x] stworzenia (2026-11-12, `art/source/creatures.blend`, `art/models/creatures/`): Thornback ze szkieletem i animacjami Sleep/Idle/Walk/Run/Attack/Stunned; Pollenbug (skrzydła trzepoczą w kodzie) i Muncher (podskoki w kodzie),
  - [x] budynki (2026-11-12, `art/source/buildings.blend`, `art/models/buildings/`, szkice w `art/source/sketches/`): chatka (blaszany barak z drewnianym frontem, gankiem, latarnią i anteną), warsztat, drzwi wyprawy (pierścień z portalem i kryształami, konsola), kapsuła z lądowiskiem (właz otwiera się po lądowaniu), słupek płotu, lądowisko ewakuacji z masztem,
  - [x] natura (2026-11-13, `art/source/nature.blend`, `art/models/nature/`): spiralna sosna, drzewo-grzyb, nowe drzewo-latarnia (świecące bańki pod noc), głaz z mchem i kryształami, stos kamieni, Mgliste źródło, legowisko Thornbacka, staw w bazie, góry z kryształami,
  - znajdźki,
  - gracz: hełm astronauty (pomysł autora, 2026-11-13). Słomkowy kapelusz zostaje, np. na hełmie albo hełm otwierany. Najpierw szkic; do ustalenia, czy hełm jest tylko na wyprawie.
- [ ] **2. Dzień i noc:** pora doby (słońce, księżyc, niebo, mgła). Nocne wyprawy z innymi znajdźkami, stworzeniami i efektami.
- [ ] **3. Bioluminescencja:** świecące rośliny, grzyby i teren nocą, świetliki, zarodniki w powietrzu, poświata (glow) w środowisku.
- [ ] **4. Tekstury:** stylizowane, ręcznie malowane (TextureCraft, MaterialCraft), najpierw teren, potem rośliny, gracz i budynki.
- [ ] **5. Plansza stylu UI** (DesignCraft, FigCraft): menu, paski, skille, ekran komputera, plecak, raport na jednej planszy. Wdrożenie dopiero po akceptacji.

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
- [ ] **Maszyny farmy** (pomysł autora, 2026-11-13; każda najpierw szkic):
  - **Dron nawadniający:** lata nad grządkami i podlewa spragnione rośliny w zasięgu, wraca do stawu po wodę.
  - **Traktor:** gracz wsiada i jedzie. Orze i sadzi duże połacie naraz (np. pas 3 pól), może też zbierać.
  - Po odpaleniu traktora zawsze gra skoczna muzyka w stylu "Cotton Eye Joe". Uwaga: sam utwór jest chroniony prawem autorskim, więc w grze trzeba albo kupić licencję, albo zrobić własną melodię w tym klimacie (skrzypce, banjo, hoedown).
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
