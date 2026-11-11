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
- [ ] Decyzja o pipeline grafiki: Blender → glTF, albo darmowe paczki low-poly (np. Kenney, Quaternius, licencja CC0) na etap prototypu. Rekomendacja: paczki CC0 do końca MVP, własne modele dopiero przy M4.
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
- [ ] Dźwięki są syntezowane w kodzie (`Sfx`). Podmienić na prawdziwe pliki, gdy będą.
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

**Baza pod presją (nowe w wersji 2):**
- [ ] **Uwaga planety** (0-100, globalna, trwała): rośnie z wywożonych rzadkich rzeczy, spada powoli po skromnych wyprawach. 2 progi: 0-49 rzadkie, słabe najazdy · 50+ częstsze i silniejsze.
- [ ] Najazd fauny w trakcie cyklu (rój szkodników / roślinożercy), rozstrzygany automatycznie: siła zagrożenia vs obrona w zasięgu farmy.
- [ ] Obrona: Snapper posadzony na stałe, **Boomshroom** (odrzut + ogłuszenie, 4. gatunek), proste ogrodzenie z warsztatu.
- [ ] **Rytuał powrotu** (`W3`): krótka scena lądowania + raport najazdu: co obroniono, co stracono, co zostawił napastnik (np. nawóz).
- [ ] Zasada: najazd nigdy nie niszczy całej bazy. Najgorzej: część upraw albo uszkodzony budynek do naprawy surowcami.

**Postęp:**

- [ ] Skaner: rozszerzenie skanu z M2 na rośliny, stworzenia, minerały.
- [ ] Baza danych z wpisami uzupełnianymi stopniowo (procent kompletności).
- [ ] Podstawowy crafting: stół warsztatowy + 3-5 receptur (np. większy plecak, lepsza konewka).
- [ ] Kuchnia ekspedycyjna (`E2`): 2 dania z upraw = buff na run. Najprostsze połączenie farma → wyprawa.
- [ ] Kolejne stworzenia: zapylacz i roślinożerca (drapieżnik jest już z M2).
- [ ] +2 gatunki roślin (razem 5: Boomshroom + nasiono-zagadka).
- [ ] 2-3 proste, widoczne mutacje (np. kolor + bonus do plonu).
- [ ] Poziom biomu 2: odblokowany przez odkrycia progowe (np. 60% wpisów).
- [ ] 1 nasiono-zagadka (`R3`) dostępne dopiero na poziomie 2 = wymagany przez MVP "przykład odblokowania nowej zawartości". Kiełkuje tylko po podlaniu wodą z Mglistego źródła (poziom 2, przynoszona w plecaku).
- [ ] *Opcjonalnie, jeśli starczy sił:* zlecenia z niekompletnych wpisów (`N5`), robot-botanik komentujący wpisy (`T4`), nazywanie gatunków przy pierwszym spotkaniu (`W4`).

Pomysły z puli wciągnięte do MVP: `N1`, `E2`, `R3`, uproszczony `E1` (Snapper, Boomshroom), `W3` (+ opcjonalnie `N5`, `T4`, `W4`). Reszta MVP to zakres z bazy wiedzy, sekcja 17.

**➡ Po M3: MVP gotowe.** Odpowiedzieć na 6 pytań z bazy wiedzy (sekcja 17.2) i zapisać wnioski w `docs/playtest-mvp.md`.

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
- [ ] Cykl dnia i nocy + dolina nocą przy wysokiej Równowadze: bioluminescencja i "grające" rośliny (`W2`)
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
- [ ] **#8** Częściowo rozstrzygnięte: bez broni palnej, bronią są rośliny-narzędzia, ogłuszacz, później Seed Cannon. Otwarte: czy cokolwiek może zabijać (na razie przegonione stworzenia uciekają), a jeśli tak, czy zabijanie staje się wejściem "−" Równowagi.
- [ ] Jak liczyć zasięg obrony w najeździe automatycznym (promień wokół rośliny czy "strefa farmy")? Rozstrzygnąć w prototypie M3.
- [ ] **#9** Pojazdy bojowe: system czy opcja? (Propozycja: opcja, "Kiedyś".)
- [ ] **#10** Granice swobodnego budowania? (Propozycja: swobodne sadzenie, budynki na prostej siatce w bazie.)
- [ ] **#11** Woda i energia w różnych biomach? (Do zaprojektowania przy M5.)
- [ ] Czy oprócz liczb w dzienniku pokazywać stały pasek Równowagi na HUD? Rozstrzygnąć w playteście M4.
- [ ] Czy baza też może być zagrożona (najazdy szkodników)? Na razie: nie.
- [ ] Ostateczna nazwa planety (robocza: Elysium-7) i gry.

## ⚠️ Pilnować

- [ ] Każdy nowy pomysł: czy wzmacnia ≥2 z 3 filarów? Czy da się go przetestować w małym prototypie?
- [ ] Gracz zawsze widzi, **dlaczego** coś się dzieje (roślina nie rośnie, stworzenie przyszło, biom się zmienił).
- [ ] Wyższy poziom biomu = nowa zawartość, a nie tylko mocniejsi wrogowie.
- [ ] Żadnego czekania w czasie rzeczywistym.
- [ ] Każde zagrożenie bazy ma przyczynę, którą gracz rozumie, i jasną stronę (nawóz, minerały, mutacja). Najazd nigdy nie niszczy całej bazy.
- [ ] Obrona bazy nie może zamienić gry w tower defense: najazdy na żywo rzadko, większość rozstrzygana automatycznie.
- [ ] Zakres: jeśli etap trwa 2x dłużej niż planowano, wyciąć połowę jego listy.
