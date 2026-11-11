# Astro Farmer: pula pomysłów na rozszerzenie

Wygenerowano przez /office-hours, 2026-11-11. Kierunek: **Żywa planeta** (zobacz [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md)).

To jest **pula propozycji**, a nie lista decyzji. Każdy pomysł oceniono według kryteriów z bazy wiedzy (sekcja 20).

**Legenda:**
- Filary: 🧭 eksploracja · 🌱 farming · 🐛 ekosystem
- Koszt dla solo deva w Godocie: **S** (dni) · **M** (1-3 tygodnie) · **L** (miesiąc i więcej)
- Etap: **Teraz** (MVP / zaraz po nim) · **Dalej** (po sprawdzeniu pętli) · **Kiedyś** (gdy reszta działa)

---

## Top 5: od tego zacząć po MVP

| # | Pomysł | Dlaczego |
|---|---|---|
| 1 | **K1 Nastrój biomu** | Rdzeń kierunku. Rozstrzyga otwarte decyzje 1, 2, 12. |
| 2 | **K2 Skaner "Sieć życia"** | Bez niego nastrój biomu jest nieczytelny (zasada 18.7). |
| 3 | **N2 Rakietowe Pnącze** | Ewakuacja staje się sceną farmingu pod presją, a nie marszem do punktu. |
| 4 | **E2 Kuchnia ekspedycyjna** | Najprostsze połączenie farmy z wyprawą: uprawy dają buffy na start runu. |
| 5 | **T1 Zdziczałe ziemskie uprawy** | Tania, mocna tajemnica opowiedziana samymi roślinami. |

---

## W. Momenty "wow" (wybrane przez autora)

Sceny, które mają odróżniać Astro Farmer od innych gier o farmie na obcej planecie i nadawać się do trailera.

**Ton całej gry:** cartoon, ale trochę strasznie i trochę uroczo. Planeta jest śliczna, a jednocześnie wyraźnie żywa i obca. Ten kontrast obowiązuje przy projektowaniu każdego stworzenia, rośliny i efektu.

### W1. Sieć życia jako wizualny podpis gry · 🧭🐛 · M · Teraz
Rozwinięcie `K2`. Włączasz skaner, świat przygasa i desaturuje się, a między roślinami i stworzeniami zapalają się świecące nici: kto kogo zapyla, kto kogo zjada, kto przed kim ucieka. Każdy typ relacji ma własny kolor i animację (pulsująca nić zapylania, szarpana nić drapieżnictwa). Nieodkryte relacje są przerywane, ze znakiem zapytania.
- **Uwaga autora:** "Fantastyczny pomysł."
- **Dlaczego "wow":** jeden kadr tłumaczy całą grę: ten świat to sieć zależności, a Ty ją odkrywasz.
- **Kierunek techniczny (Godot):** osobny shader post-process na tryb skanera + nici jako `ImmediateMesh` / linie z shaderem świecenia między węzłami.

### W2. Dolina nocą przy wysokiej Równowadze · 🌱🐛 · M · Dalej (razem z M4)
Nagroda za dbanie o biom, którą widać i słychać. Gdy Równowaga jest wysoka, noc w dolinie zamienia się w spektakl: rośliny i grzyby świecą bioluminescencją, latają Lumen-mole, a cała roślinność cicho "gra", każdy gatunek w swojej tonacji (połączenie z `R6` Farma, która gra). W rozchwianej dolinie noc jest ciemna, cicha i niepokojąca.
- **Uwaga autora:** "Równie fenomenalny."
- **Dlaczego "wow":** Równowaga przestaje być liczbą w dzienniku. Gracz *czuje* różnicę między zadbaną i zniszczoną doliną.
- **Wymaga:** cyklu dnia i nocy (przenieść z "Dalej" bliżej M4), emisji w materiałach low-poly, krótkich pętli dźwiękowych per gatunek.

### W3. Rytuał powrotu · 🌱🐛 · S-M · Teraz (od M3)
Po każdej wyprawie farma czymś zaskakuje. Krótka scena powrotu (kapsuła ląduje, kamera przelatuje nad farmą) i jedno-dwa wydarzenia losowane z puli zależnej od tego, co posadziłeś i jaki jest nastrój doliny:
- stworzenie wprowadziło się między grządki,
- roślina zmutowała pod wpływem sąsiada,
- coś zdziczało i rozsiało się poza grządkę,
- roślinożerca podjadł plon, ale zostawił nawóz,
- przy grządce leży "prezent": dziwne nasiono przyniesione przez zwierzę.
- **Uwaga autora:** "Coś przy powrocie się może dziać."
- **Dlaczego "wow":** każdy powrót jak rozpakowywanie prezentu. Wzmacnia pętlę "wracam do bazy, bo chcę zobaczyć, co się stało".
- **Uwaga projektowa:** wydarzenia nie mogą być karą bez wyjścia. Każde negatywne ma pozytywną stronę (zgodnie z zasadą "oba końce dają zawartość").

### W4. Nazywasz gatunki · 🧭🐛 · S · Teraz (od M3)
Pierwsze spotkanie z nowym gatunkiem to mała scena: kamera się zbliża, skaner analizuje, pojawia się sylwetka i robocza nazwa naukowa, a gracz może nadać gatunkowi własną nazwę. Nazwa zostaje w bazie danych, w dzienniku biomu i w komentarzach robota-botanika (`T4`).
- **Uwaga autora:** "Niezły pomysł z nazywaniem gatunków."
- **Dlaczego "wow":** to staje się *Twoja* planeta i *Twój* atlas. Gracze lubią pokazywać sobie, jak co nazwali.
- **Szczegóły:** domyślna nazwa robocza (np. Voidberry) zawsze dostępna jednym kliknięciem; możliwość zmiany nazwy później w bazie danych; zapis w save'ie.

### W5. Grzybnia patrzy · 🧭🐛 · M · Dalej (razem z M4 / M5)
Rozwinięcie `T2`. Gdy Równowaga spada nisko, grzybnia wypełza na powierzchnię jako jarzące się żyłki, a w ciemnych miejscach otwierają się na niej "oczka", które obracają się za graczem. Nic nie atakuje, tylko patrzy. Przy wysokiej Równowadze grzybnia chowa się pod ziemię i co najwyżej delikatnie pulsuje.
- **Uwaga autora:** "Ma być cartoon, ale ma być też trochę strasznie, trochę uroczo."
- **Kierunek wizualny:** duże, okrągłe, lekko wilgotne oczka z odblaskiem jak w kreskówce, mrugające nierówno. Bardziej "ciekawskie" niż wrogie, ale tak, żeby gracz poczuł, że przesadził.
- **Dlaczego "wow":** planeta wprost daje znać, że widzi, co robisz. Fabularne uzasadnienie całego systemu nastroju biomu.

---

## R. Dziwne rośliny i mutacje

### R1. Geny jako kafelki cech · 🌱🐛 · M · Dalej
Każda roślina ma 3 sloty genów pokazane jako kolorowe ikonki (np. ❄ mrozoodporność, ⚡ szybki wzrost, ✨ świecenie). Krzyżowanie w laboratorium to wybór, które kafelki przejdą dalej, z małą szansą na losową mutację. Genetyka jest głęboka, ale czytelna jednym spojrzeniem.
- **Test w prototypie:** 2 rośliny, 4 rodzaje kafelków, prosty ekran krzyżowania.
- **Prostsza alternatywa:** brak slotów, tylko "odmiana A/B/C" per gatunek.

### R2. Terroir nasion · 🧭🌱 · S · Dalej
Roślina, która dojrzała w danym biomie, daje nasiona z lokalną cechą (z pustyni: oszczędność wody, z gór: mrozoodporność). Każda placówka staje się "manufakturą odmian", a mapa planety jest mapą genów. To powód, by zakładać placówki i wracać do biomów.

### R3. Nasiona-zagadki · 🧭🌱 · S · Teraz (jako 1 przykład w MVP)
Rzadkie nasiono z wyższego poziomu biomu kiełkuje tylko w szczególnych warunkach: po uderzeniu meteorytu, w nocy, w cieniu Skywhale, po burzy elektromagnetycznej. Wpis w bazie danych daje tylko wskazówkę ("Znaleziono w pobliżu wypalonej ziemi..."). Dobry kandydat na "przykład odblokowania nowej zawartości" wymagany przez MVP.

### R4. Wędrowiec · 🧭🌱🐛 · M · Dalej
Chodzący kaktus, który sam szuka wody. Na farmie trzeba go ogrodzić. Na wyprawie wypuszczasz go i idziesz za nim, bo prowadzi do ukrytych źródeł. Roślina jako żywe narzędzie eksploracji.

### R5. Korzenie-zwiadowcy (Glowroot) · 🧭🌱 · M · Dalej
Posadzony Glowroot rozrasta się pod ziemią i po kilku minutach rozświetla żyłami pobliskie minerały i wejścia do jaskiń. Zwiad roślinami zamiast dronami, bo drony to "Kiedyś".

### R6. Farma, która gra · 🌱🐛 · S-M · Dalej
Każdy gatunek wydaje cichy dźwięk w swojej tonacji, a cała farma tworzy ambient zależny od układu. Roślina chora lub spragniona **fałszuje**, więc słyszysz problem, zanim go zobaczysz. Klimat i czytelność w jednym. Tanie, jeśli dźwięki są krótkimi pętlami.

### R7. Chimery · 🌱🐛 · M · Kiedyś
Rzadka mutacja kosmiczna łączy roślinę z cechą stworzenia. Przykład: kwiat z okiem, który obraca się w stronę zagrożenia i piszczy, czyli żywy system alarmowy farmy.

### R8. Ucieczka mutanta · 🌱🐛 · M · Dalej
Niekontrolowana mutacja może "uciec" z farmy i zadomowić się w biomie jako chwast, co obniża Równowagę (K1). Na kolejnej wyprawie znajdujesz ją dziko jako nowy, zmieniony gatunek. Twoje eksperymenty zostawiają ślad w świecie.

---

## K. Żywy ekosystem

### K1. Nastrój biomu (RDZEŃ) · 🧭🌱🐛 · M · Teraz (zaraz po MVP)
Równowaga (trwała) + Przebudzenie (w trakcie wyprawy). Pełny opis w [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md). Kluczowa zasada: **oba końce skali dają zawartość**, rozchwiany biom ma mutacje stresowe, a zrównoważony rzadkie symbionty.
- **Test w prototypie:** jedna wartość Równowagi w Zielonej dolinie, 3 progi, 1 zmiana na próg (inne stworzenie, inna roślina, inna pogoda).

### K2. Skaner "Sieć życia" · 🧭🐛 · M · Teraz
Tryb skanera, który rysuje świecące nici między organizmami w okolicy: kto kogo zapyla, kto co zjada, kto przed kim ucieka. Odkryte relacje są pełne, a nieodkryte są przerywane ze znakiem zapytania. Czytelność ekosystemu i silny moment wizualny do pokazania znajomym. Rozwinięte w `W1`.

### K3. Pamięć gatunków · 🐛🧭 · M · Dalej
Każdy gatunek pamięta, jak go traktujesz. Dokarmiane Shellbacki przestają uciekać i idą za tobą, a drapieżniki, którym pokazałeś siłę, omijają twój obóz. Relacje zamiast "zabij albo zignoruj".

### K4. Sukcesja na placówkach · 🌱🐛 · M · Dalej
Placówki nie produkują między wyprawami, ale **zarastają**: twoje rośliny mieszają się z dzikimi, osiedlają się stworzenia. Wracasz i znajdujesz mały, nowy ekosystem, czasem z nową odmianą. Rozwiązuje otwartą decyzję 6 bez mikrozarządzania.

### K5. Gatunek-zwornik · 🧭🐛 · S (na biom) · Dalej
W każdym biomie jest jeden gatunek, którego obecność lub brak zmienia cały biom (np. Mudhopper w dolinie spulchnia glebę). Pojawia się dopiero przy wysokiej Równowadze. Odkrycie go to moment fabularny i nagroda za dbanie o biom.

### K6. Ekosystem jako obrona · 🌱🐛 · M · Dalej
Zamiast wieżyczek: kwiaty przyciągają drapieżnika, który przegania szkodniki z farmy. Gracz projektuje łańcuch zależności, który sam się pilnuje. Zgodne z filozofią walki z bazy wiedzy (13.1).

### K7. Towarzysz z plecaka · 🐛🧭 · M · Dalej
Mała kolonia organizmów (np. Pollenbugi) mieszka w module plecaka i rośnie razem z tobą między wyprawami. To, czym ją karmisz, zmienia jej zdolność: zapylanie, świecenie, wykrywanie zagrożeń. Emocjonalna kotwica w roguelite, gdzie wszystko inne jest tymczasowe.

### K8. Migracja Skywhale · 🧭🌱🐛 · L · Kiedyś
Stado ogromnych Skywhale przelatuje nad planetą po stałej trasie. W ich cieniu rośliny mutują, a z nieba spadają rzadkie nasiona. Gracz planuje placówki pod trasę przelotu.

---

## N. Napięcie ekspedycji

### N1. Przebudzenie · 🧭🐛 · S · Teraz
Licznik zagrożenia rośnie z czasem, ale **szybciej, gdy zabierasz rzadkie rzeczy**. Chciwość jest widoczna i ma cenę. Progi 25/50/75/100 zmieniają pogodę, fauna robi się aktywniejsza, a na końcu "planeta się broni". Rozwiązuje otwartą decyzję 1.

### N2. Rakietowe Pnącze · 🌱🧭 · M · Teraz / Dalej
Ewakuacja = zasadzenie specjalnego nasiona, które przez ok. 60 sekund rośnie w niebo jak łodyga fasoli, a ty go bronisz. Na szczycie czeka kapsuła. Możesz je przyspieszyć podlewaniem lub nawozem zabranym z bazy. Ewakuacja staje się sceną farmingu pod presją, zgodnie z 5.2 ("powrót nie powinien wymagać długiego marszu").
- **Prostsza alternatywa:** zwykły punkt ewakuacji z odliczaniem.

### N3. Kurierzy próbek · 🧭🐛 · S · Dalej
Oswojony owad-kurier zabiera jedną próbkę do bazy w trakcie wyprawy. Ta próbka jest bezpieczna nawet przy porażce. Decyzja: co zabezpieczyć teraz, a co zaryzykować. Czytelne rozdzielenie łupu od danych (6.3).

### N4. Prognoza przed wyprawą · 🧭 · S · Dalej
Ekran przygotowania pokazuje prognozę ("burza elektromagnetyczna w ok. 8. minucie", "noc: kwitną Moonbelle"). Planowanie wyposażenia staje się ciekawszą decyzją.

### N5. Zlecenia z bazy danych · 🧭🐛 · S · Teraz
Niekompletne wpisy same stają się celami: "Zaobserwuj Glowmole w nocy", "Znajdź, co zjada Voidberry". Eksploracja ma kierunek, ale nie jest ograniczona.

### N6. Zarośnięty plecak · 🌱🧭 · S-M · Dalej
Po porażce twój plecak zostaje w biomie. Na następnej wyprawie znajdujesz go **zarośniętego** roślinami z nasion, które w nim niosłeś, czasem zmutowanymi. Porażka zostawia w świecie coś ciekawego, zamiast samego "straciłeś wszystko".

### N7. Kolumny anomalii · 🧭 · S · Dalej
Anomalie są widoczne z daleka jako kolumny kolorowego światła. Możesz iść po pewny łup w pobliżu albo zaryzykować dłuższy marsz do anomalii (+Przebudzenie, + rzadka nagroda). Prosty, czytelny wybór ryzyka w duchu Risk of Rain 2.

---

## T. Tajemnica planety

### T1. Zdziczałe ziemskie uprawy · 🧭🌱 · S · Teraz / Dalej
Gracz nie jest pierwszy. W dolinie rosną zdziczałe, zmutowane **ziemskie** rośliny: marchew wielkości drzewa, ziemniaki z krystaliczną skórką. To ślady zaginionej kolonii rolniczej. Historia opowiedziana przez rośliny, bez cutscenek. Każdy taki gatunek to wpis w bazie danych z fragmentem historii.

### T2. Grzybnia jako układ nerwowy · 🧭🐛 · M · Dalej
Pod wszystkimi biomami biegnie sieć grzybni. W Grzybowym lesie widać ją na powierzchni. Pulsuje mocniej, gdy Równowaga spada, i podpowiada, że planeta "czuje" gracza. Fabularne uzasadnienie systemu nastroju biomu. Wizualnie rozwinięte w `W5` (grzybnia patrzy).

### T3. Serce planety i drzewa-kotwice (FINAŁ) · 🧭🌱🐛 · L · Kiedyś
W centrum planety leży martwy biom: Serce (osobna, zamknięta scena). Z biomu o wysokiej Równowadze można zdobyć nasiono drzewa-kotwicy. Drzewa z 3 biomów zasadzone w Sercu stopniowo je ożywiają. To wstępna propozycja zakończenia fabularnego (otwarta decyzja 13), do potwierdzenia po trzecim biomie. Po finale gra trwa dalej.

### T4. Robot-botanik · 🧭 · S · Teraz
Mały robot w bazie komentuje nowe wpisy bazy danych jednym, dwoma zdaniami z charakterem. Najtańszy możliwy narrator: sam tekst, bez nagrań głosu.

### T5. Dreamfruit · 🌱🧭 · S · Dalej
Rzadki owoc. Zjedzony w bazie pokazuje krótką wizję (prosta scena lub ilustracja) ze wspomnień planety albo zaginionej kolonii. Uprawa jako klucz do fabuły.

### T6. Skywhale jako archiwa · 🧭🐛 · L · Kiedyś
Skywhale pamiętają historię planety. Oswojenie jednego (late game) odblokowuje ostatnie fragmenty tajemnicy i lot nad mapą.

---

## E. Eksperymenty i połączenia farma ↔ wyprawa

### E1. Nasienny build (wyjaśnienie odrzuconego podejścia A) · 🌱🧭 · M · Dalej (opcjonalnie)
**Prościej:** w grach roguelite typu Risk of Rain 2 w trakcie runu zbierasz przedmioty, które zmieniają sposób grania. Tutaj zamiast przedmiotów zbierasz **nasiona-gadżety**. Rzucasz takie nasiono na ziemię i w 2-3 sekundy wyrasta roślina, która działa jak narzędzie:
- **Boomshroom** → mina: wybucha, gdy coś na nią wejdzie,
- **Snapper** → pułapka: łapie i przytrzymuje stworzenie,
- **Floatroot** → platforma: wyrzuca cię w górę,
- **Voidberry** → zjadasz od razu: krótki sprint.

Twój "build" w danym runie to zestaw nasion, które niesiesz. W bazie możesz wyhodować lepsze odmiany tych nasion na następne wyprawy.
- **Status (wersja 2):** przywrócone w uproszczonej formie jako "nasiona jako broń i obrona". W MVP: Snapper (M2) i Boomshroom (M3), działające i na wyprawie (rzucane), i w bazie (sadzone na stałe jako obrona). Później Floatroot i Seed Cannon. Szczegóły w [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md).

### E2. Kuchnia ekspedycyjna · 🌱🧭 · S · Teraz / Dalej
Przed wyprawą gotujesz 1-2 dania z własnych upraw. Każde daje buff na cały run (Voidberry tart: +szybkość, zupa grzybowa: odporność na zarodniki). Najprostsze i najbardziej zrozumiałe połączenie farmy z wyprawą. Dobra alternatywa dla E1.

### E3. Fotograf-przyrodnik · 🧭🐛 · S · Dalej
Tryb zdjęć w skanerze. Zdjęcie rzadkiej sceny (zapylanie nocą, polowanie drapieżnika) uzupełnia wpis bazy danych do 100%. Tanie, daje nagrodę za obserwację zamiast walki, a zrzuty ekranu sprzedają grę.

---

## O. Zagrożenia i obrona bazy (wersja 2)

Baza leży w niebezpiecznej krainie i jest narażona na ataki fauny, flory, grzybów i samej planety. Zasada przewodnia: **przywozisz zagrożenia na własnych butach**, czyli każde nowe zagrożenie wynika z czegoś, co gracz zrobił. Model (Uwaga planety, najazdy automatyczne i na żywo) jest opisany w [Design_Zywa_Planeta.md](Design_Zywa_Planeta.md).

### O1. Rój szkodników · 🌱🐛 · S · Teraz (M3)
Chmara drobnych owadów obsiada grządki i zjada młode rośliny. Obrona: Boomshroom rozpędza rój, rośliny odstraszające, później drapieżnik-sojusznik (`K6`). Jasna strona: martwe owady to kompost.

### O2. Roślinożercy na grządkach · 🌱🐛 · S · Teraz (M3)
Stado przychodzi, gdy farma rozrasta się i ma dużo dojrzałych owoców. Obrona: Snapper, ogrodzenie, Cierniowa Voidberry. Jasna strona: zostawiają nawóz.

### O3. Burza i meteoryt · 🧭🌱 · M · Teraz (M4)
Burza łamie wysokie rośliny i uszkadza budynki. Meteoryt wybija krater w polu. Obrona: osłony nad grządkami, piorunochron z Crystal Bloom, prognoza (`N4`). Jasna strona: burza ładuje akumulatory, meteoryt zostawia minerały i szansę na mutację kosmiczną.

### O4. Plaga grzybowa · 🌱🐛 · M · M5
Pojawia się dopiero po pierwszej wizycie w Grzybowym lesie, bo przywiozłeś zarodniki. Zainfekowane uprawy pokrywają się świecącym nalotem. Obrona: roślina antygrzybowa z lasu, osuszanie gleby, lampa UV. Jasna strona: zainfekowana roślina może dać rzadką mutację grzybową.

### O5. Grzybnia pod bazą · 🐛🧭 · M · Dalej
Przy wysokiej Uwadze planety grzybnia z `T2` / `W5` wypełza spod fundamentów i "patrzy". Sama nie atakuje, ale osłabia rośliny wokół. Fabularny sygnał, że planeta zwróciła na Ciebie uwagę.

### O6. Inwazyjne pnącza · 🌱🐛 · M · Dalej
Uciekła mutacja z Twojej farmy (`R8`) albo nasiono przywiezione z innego biomu zarasta budynki i duszą uprawy. Obrona: pielenie, roślina-konkurent, herbicyd z grzybów. Jasna strona: pnącza to darmowe włókno i drewno.

### O7. Drapieżnik krążący wokół bazy · 🐛 · S · Dalej
Przy wysokiej Uwadze planety drapieżnik z wypraw zaczyna nocami odwiedzać bazę. Obrona: Snapper, światło, przynęta odciągająca. Może zostać oswojony po kilku nocach dokarmiania (`K3`).

### O8. Seed Cannon · 🌱🧭 · M · Dalej
Ręczna wyrzutnia, która strzela nasionami z Twojej farmy: Snapperem łapie, Boomshroomem odrzuca. "Broń" w pełni zasilana farmingiem. Przydatna w najazdach na żywo i na wyprawie.

### O9. Mapa zagrożeń w prognozie · 🧭 · S · Teraz (M4)
Ekran przygotowania pokazuje, skąd w tym cyklu może przyjść zagrożenie (strzałka nad bazą, ikona burzy). Gracz sadzi obronę po właściwej stronie farmy. Mała decyzja przestrzenna zamiast pełnego tower defense.

---

## Pomysły świadomie odłożone

- **Co-op online:** dla solo deva w Godocie to osobny projekt (sieć, synchronizacja świata). Kiedyś, jeśli w ogóle.
- **Pełna symulacja populacji:** baza wiedzy ostrzega przed nią (7.4). Zostają proste reguły i progi.
- **Walka pojazdami / Tank:** zgodnie z bazą wiedzy (13.4) tylko późna technologia.
