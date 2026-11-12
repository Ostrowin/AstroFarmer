# Design: Astro Farmer, kierunek "Żywa planeta"

Wygenerowano przez /office-hours, 2026-11-11
Repo: brak (folder lokalny `D:\Projekty\Private\AstroFarmer`, jeszcze bez git)
Status: DRAFT (wersja 2)
Tryb: Builder (hobby / frajda)
Wersja 2 (2026-11-11): wyprawa jako rdzeń gry, baza pod presją planety, nasiona roślin jako broń i obrona, trudność per biom + globalna Uwaga planety.
Kanoniczna kopia: `D:\Projekty\Private\AstroFarmer\Design_Zywa_Planeta.md` (linki poniżej są względne wobec tego folderu). O kolejności prac decyduje [ToDo.md](ToDo.md), a ten dokument opisuje, *dlaczego* tak.
Powiązane pliki: [ToDo.md](ToDo.md), [Pomysly_rozszerzen.md](Pomysly_rozszerzen.md), [baza wiedzy](astro_farmer_rozszerzona_baza_wiedzy.md)

## Problem

Baza wiedzy opisuje bogatą grę (8 biomów, mutacje, ekosystem, baza, pojazdy, automatyzacja), ale zostawia 13 otwartych decyzji i ostrzega przed trzema pułapkami: farming jako dekoracja (18.2), za szeroki zakres (18.1) i trudność jako samo skalowanie statystyk (18.6). Potrzebny jest jeden kierunek rozbudowy, który:

- daje wszystkie cztery momenty "whoa" wybrane w sesji: dziwne rośliny i mutacje, żywy ekosystem, napięcie ekspedycji i tajemnicę planety,
- rozstrzyga kilka otwartych decyzji jednym systemem, zamiast dokładać osobne mechaniki,
- da się zbudować w pojedynkę w Godocie, etapami.

## Co w tym jest fajnego

**Planeta pamięta, co robisz, i odpowiada.** Każdy biom ma "nastrój". Rabunkowe zbieranie i wydobycie go rozchwiewa: pojawiają się agresywne warianty stworzeń, szkodniki i mutacje stresowe. Sadzenie rodzimych gatunków i dokarmianie fauny go stabilizuje: przychodzą rzadkie symbionty, gatunek-zwornik i ukryte polany. **Oba kierunki dają nową zawartość**, więc to nie jest moralizatorski licznik karmy, tylko wybór, jaki biom chcesz mieć. Poziom zagrożenia przestaje być suwakiem statystyk i staje się skutkiem decyzji gracza.

Do tego tajemnica opowiadana przez ekologię: zdziczałe ziemskie uprawy poprzedniej, zaginionej kolonii, grzybnia łącząca biomy jak układ nerwowy i martwe "Serce" planety jako możliwy cel końcowy.

**Pętla w jednym zdaniu:** wyruszasz do niebezpiecznego biomu, przywozisz nowy organizm, wyhodowujesz z niego narzędzie albo obronę, a planeta reaguje tym mocniej, im więcej bierzesz, także atakując Twoją bazę.

**Przywozisz zagrożenia na własnych butach.** Nowe zagrożenia dla bazy pojawiają się przez to, co sam zrobiłeś: zarodniki z Grzybowego lasu, uciekła mutacja z Twojej farmy, rzadki kryształ, który ściąga burze. Każdy najazd ma przyczynę, którą gracz rozumie.

## Czym różnimy się od Lightyear Frontier

| Lightyear Frontier | Astro Farmer |
|---|---|
| Spokojne zasiedlanie, bez porażki | Wyprawy z ryzykiem utraty łupu, baza pod presją |
| Świat się "naprawia" i tyle | Planeta reaguje w obie strony (Równowaga, Uwaga planety) |
| Rośliny obce z wyglądu, zwykłe jako uprawy | Rośliny jako broń, obrona i żywe narzędzia, z mutacjami |
| Mech i budowanie gospodarstwa | Przyrodnik na piechotę: skanowanie, Sieć życia, nazywanie gatunków |
| Otwarty sandbox | Struktura roguelite: biomy z poziomami, nowa zawartość na wyższych poziomach |

Nie konkurujemy ilością cozy treści (dom, mech, co-op). Wygrywamy ryzykiem, systemami i odkrywaniem.

## Ograniczenia

- Jedna osoba, Godot 4.x, projekt hobbystyczny. Nie ma terminu, ale motywacja zależy od tego, czy szybko widać grywalne efekty.
- Styl low-poly / stylizowane 3D (baza wiedzy, sekcja 12) trzyma koszt grafiki w ryzach.
- Zasady z bazy wiedzy (sekcja 20) zostają w mocy: najpierw farming i eksploracja, automatyzacja i walka później.

## Założenia (zaakceptowane w sesji)

1. Rośliny są głównymi czasownikami gracza także **na ekspedycji**, a nie tylko surowcem między runami.
2. Każdy nowy pomysł musi wzmacniać co najmniej 2 z 3 filarów: eksploracja, farming, ekosystem.
3. Solo + Godot: najpierw mały prototyp pętli. Pomysły mają etykiety Teraz / Dalej / Kiedyś. Pojazdy, duża automatyzacja i walka pojazdów są w "Kiedyś".
4. Planeta jest postacią: ma tajemnicę i reaguje na gracza. Fabułę odkrywa się przez ekologię, nie przez cutscenki.

5. **(wersja 2)** Wyprawa jest główną rozgrywką. Baza to miejsce, gdzie łup z wyprawy zamienia się w siłę, i ona też jest narażona na ataki fauny, flory, grzybów i samej planety.

**Jak założenie 1 jest realizowane w kolejnych etapach:**
- **MVP:** wprost. Nasiona roślin-narzędzi (Snapper, Boomshroom) rzucasz na wyprawie i sadzisz w bazie jako obronę. Do tego Kuchnia ekspedycyjna (`E2`), próbki nasion i dzikie owoce, które przywracają Kondycję.
- **Żywa planeta v1:** sadzenie rodzimych roślin w terenie podnosi Równowagę, a ewakuacja przez Rakietowe Pnącze (`N2`) jest testowana jako scena sadzenia pod presją.

## Rozważane podejścia

- **A: "Nasienny build"**: w wersji 1 usunięty z MVP, bo był niejasny. **W wersji 2 przywrócony w uproszczonej formie** jako "nasiona jako broń i obrona" (sekcja niżej), po tym jak autor sam opisał tę pętlę: przywozisz nasiona rośliny atakującej i używasz ich.
- **B: "Żywa planeta"**: WYBRANE.
- **C: "Szczepienie planety"**: trwałe przekształcanie świata to dla jednej osoby za drogi fundament. Zostaje tylko jako wstępny pomysł na finał (decyzja 13).

## Rekomendowane podejście: B, etapami

### Wyprawa w MVP: presja i porażka

- **Przebudzenie** (0-100) rośnie z czasem pobytu i skokowo po zebraniu rzadkich rzeczy. W MVP są 2 progi: 50 (zmiana pogody + drapieżnik zaczyna patrolować) i 100. W v1 dochodzą: 25 (ostrzeżenie dźwiękowe + zmiana koloru nieba) i 75 (drapieżnik aktywnie poluje na gracza, burza gęstnieje).
- **Stworzenia w MVP:** pierwszy wrogi drapieżnik jest już na mini-wyprawie (M2), żeby było czego unikać i co ogłuszać. Zapylacz i roślinożerca dochodzą w M3.
- **Skanowanie w MVP:** prosta akcja skanu jest już w M2 (zapisuje odkrycie), a pełna baza danych z wpisami dochodzi w M3. Dzięki temu regułę porażki da się sprawdzić od pierwszej wyprawy.
- **Baza danych w prototypie (M3):** każdy wpis ma 3 fakty i każdy fakt odkrywa inna akcja (skan, hodowla, zbiór, ogłuszenie, obrona w najeździe...). Dzięki temu baza danych nagradza różne style gry, nie tylko skanowanie. Poziom 2 łąki otwiera się po odkryciu 6 z 9 wpisów poziomu 1. Chrupiki z wyprawy to te same szkodniki, które najeżdżają farmę: baza danych łączy oba światy.
- **Przebudzenie 100, "planeta się broni":** rusza 90-sekundowe odliczanie, a pogoda zaczyna stale obniżać Kondycję. Trzeba dotrzeć do punktu ewakuacji.
- **Kondycja** (zdrowie) spada od ataków stworzeń i pogody. Porażka następuje przy Kondycji = 0 albo gdy odliczanie z progu 100 dobiegnie końca przed ewakuacją. Wtedy kapsuła ratunkowa zabiera nieprzytomnego farmera do bazy, bez dramatycznej śmierci.
- **Reakcja na zagrożenie w MVP i v1:** unikanie, bieg i dash, **pistolet** (zadaje obrażenia) oraz **rośliny-narzędzia** (sekcja niżej). Rośliny przeganiają, unieruchamiają i ogłuszają. Stworzenia mają zdrowie: ranne uciekają, zabite zostawiają materiały (kolce, nawóz, pyłek). Zabicie drapieżnika budzi planetę (Przebudzenie +8). Decyzja #8 zmieniona 2026-11-12, wcześniej "bez broni palnej".
- **Reguła porażki w MVP:** zeskanowane dane zostają, niesiony łup przepada. Później dochodzą bezpieczne próbki wysłane kurierem (`N3`) i zarośnięty plecak (`N6`).

### Nasiona jako broń i obrona (uproszczony nasienny build)

Te same nasiona działają w dwóch miejscach:

| | Na wyprawie | W bazie |
|---|---|---|
| Jak | rzucasz nasiono, roślina wyrasta w 2-3 s | sadzisz jak uprawę, rośnie przez cykle |
| Trwałość | znika po wyprawie | zostaje na stałe, dopóki jej nie zniszczy najazd |
| Rola | narzędzie w terenie | stała obrona farmy podczas Twojej nieobecności |

**Rośliny-narzędzia w MVP:**
- **Snapper:** pułapka, łapie i przytrzymuje stworzenie na kilka sekund.
- **Boomshroom:** odrzut, wybucha chmurą zarodników, odrzuca i ogłusza wszystko w pobliżu.

**Skąd nasiona:** pierwsze znajdujesz na wyprawie. W bazie hodujesz je jak uprawy i zbierasz kolejne nasiona, więc farma produkuje Twój arsenał. Lepsze odmiany (np. mocniejszy Snapper z mutacji) to naturalna ścieżka rozwoju.

**Później:** Seed Cannon (wyrzutnia, która strzela nasionami z Twojej farmy jako amunicją) i kolejne rośliny-narzędzia z puli (Floatroot jako platforma itd.).

### Baza pod presją

Baza leży w niebezpiecznej krainie. Podczas każdego cyklu, kiedy jesteś na wyprawie, może ją spotkać zagrożenie.

**Cztery źródła zagrożeń:**

| Źródło | Przykłady | Obrona | Etap |
|---|---|---|---|
| **Fauna** | rój szkodników, roślinożercy podjadający plon, drapieżnik krążący wokół bazy | Snapper, Boomshroom, ogrodzenie, później drapieżnik-sojusznik przyciągnięty kwiatami (`K6`) | MVP (M3) |
| **Planeta** | burza, meteoryt, fala mrozu lub upału, wstrząsy | osłony nad grządkami, piorunochron z Crystal Bloom, prognoza przed wyprawą (`N4`) | v1 (M4) |
| **Grzyby** | plaga zarodników zarażająca uprawy, grzybnia wypełzająca pod bazą | rośliny antygrzybowe, osuszanie gleby, lampa UV | M5 (po pierwszej wizycie w Grzybowym lesie) |
| **Flora** | inwazyjne pnącza zarastające budynki, chwasty z uciekłej mutacji (`R8`), rośliny-pasożyty | pielenie, roślina-konkurent, herbicyd z grzybów | Dalej |

**Jak rozstrzyga się najazd:**
- **MVP (automatycznie):** w trakcie cyklu siła zagrożenia jest porównywana z obroną w zasięgu farmy. Wynik widać przy powrocie, w rytuale powrotu (`W3`): co obroniono, co stracono, co zostawił napastnik.
  **Jak to działa w prototypie (M3):**
  - **Niepokój fauny** (0-100) rośnie co cykl o 15 + połowę Uwagi planety. Przy 100 przychodzi najazd i Niepokój spada do zera. Nowa gra zaczyna od 55, więc pierwszy najazd jest po 3 cyklach. HUD i ekran wyprawy pokazują, za ile cykli będzie następny, co zastępuje prognozę do czasu `N4`.
  - **Rój Chrupików:** 3 szkodniki + 1 na każde 20 Uwagi; od Uwagi 50 nazywa się "Wielki rój". Każdy celuje w losową uprawę. Rośliny-narzędzia nie są celem.
  - **Zasięg obrony to promień wokół obrońcy** (rozstrzyga pytanie otwarte z M3). Każdy obrońca ma pojemność na jeden najazd: dojrzały Snapper 3 m / 2 szkodniki, dojrzały Boomshroom 4.5 m / 3, słupek płotu 2 m / 1. Szkodnika przejmuje najbliższy obrońca z wolną pojemnością.
  - Nieprzegoniony szkodnik zabiera uprawie 1 etap wzrostu. Kiełek znika, ale najwyżej połowa upraw na najazd. Przegoniony zostawia **nawóz** (natychmiast +1 cykl wzrostu rośliny).
  - Ślady najazdu (kupki nawozu przy obrońcach, ogryzki przy uprawach) są widoczne w bazie do następnego cyklu.
- **v1 (na żywo, czasem):** kapsuła ląduje w środku ataku i bronisz bazy przez krótką scenę (ok. 60-90 s). Rzadziej niż najazdy automatyczne, żeby nie zamienić gry w tower defense.

**Zasady, które trzymają to w ryzach:**
- Najazd nigdy nie niszczy całej bazy. Najgorszy wynik to część zniszczonych upraw albo uszkodzony budynek do naprawy surowcami.
- Każde zagrożenie ma jasną stronę: roślinożercy zostawiają nawóz, meteoryt minerały i szansę na mutację, burza ładuje akumulatory.
- Przed wyprawą gracz widzi prognozę ("w tym cyklu: rój szkodników"), więc decyzja "co posadzić jako obronę, zanim wyruszę" jest częścią przygotowań.
- Obrona to głównie rośliny i proste konstrukcje (ogrodzenie, osłony). Wieżyczki z bazy wiedzy (13.3) zostają w "Kiedyś".

### Uwaga planety (globalna presja)

Trzy wskaźniki, każdy z inną rolą:

| Wskaźnik | Zasięg | Trwałość | Co robi |
|---|---|---|---|
| **Przebudzenie** | jedna wyprawa | resetuje się | presja w trakcie wyprawy |
| **Równowaga** | jeden biom | trwała, dryfuje do 0 | charakter biomu, rzadkie gatunki |
| **Uwaga planety** | cała planeta | trwała | siła i częstotliwość zagrożeń bazy |

**Uwaga planety (0-100):**
- **Rośnie** z rzadkich rzeczy wywożonych z dowolnego biomu (kryształy, rzadkie nasiona, próbki z wyższych poziomów). Nie rośnie z samego upływu czasu, więc spokojna eksploracja nie jest karana.
- **Spada** powoli po skromnych wyprawach i gdy Równowaga odwiedzanych biomów jest dodatnia.
- **Progi w MVP:** 0-49 rzadkie, słabe najazdy fauny · 50+ częstsze i silniejsze najazdy. W v1 dochodzą progi z zagrożeniami planety.
- **Liczby w prototypie (M3):** udana wyprawa dodaje +10 za każdą próbkę Lśniącego mchu i +1 za każdy kryształ. Wyprawa bez takich rzeczy albo porażka (nic nie wywiezione) odejmuje 5. Raport po powrocie zawsze podaje zmianę i jej powód.
- Gracz sam decyduje, jak szybko podkręca grę: chciwość daje szybszy rozwój, ale baza dostaje mocniej.

Trudność biomów pozostaje osobna i per biom (sekcja "Poziomy biomu").

### Rdzeń Żywej planety: Równowaga

Każdy biom ma jedną wartość **Równowagi** (-100 do +100), wspólną dla wszystkich poziomów tego biomu i trwałą między wyprawami.

**Zakres v1 (tylko Zielona dolina):**

| Wejście | Kierunek |
|---|---|
| Nadmierne zbieranie jednego gatunku w czasie wyprawy | − |
| Wydobycie minerałów | − |
| Sadzenie rodzimych roślin w terenie wyprawy | + |
| Dokarmianie stworzeń | + |

| Próg | Efekt w v1 |
|---|---|
| ≤ -50 (rozchwiany) | agresywny wariant drapieżnika, startowe Przebudzenie = 25 + **nagroda: mutacja stresowa** |
| -49..+49 (neutralny) | stan bazowy |
| ≥ +50 (zrównoważony) | mniej agresywnych spawnów + **nagroda: rzadki symbiont** |

**Nagrody v1:**
- **Mutacja stresowa (robocza nazwa: Cierniowa Voidberry):** dzika odmiana, która pojawia się tylko w rozchwianej dolinie. Pobierasz z niej próbkę i sadzisz w bazie. Daje owoc, który przywraca więcej Kondycji, a kolce chronią ją i sąsiednie grządki podczas najazdów roślinożerców.
- **Rzadki symbiont (robocza nazwa: Lumen-mól):** pojawia się tylko w zrównoważonej dolinie. Dokarmiony, idzie za tobą do bazy i zwiększa plon farmy.
- **Skąd gracz wie, że istnieją:** od początku w bazie danych są dwa zablokowane wpisy z podpowiedzią ("??? · widziany, gdy dolina jest rozchwiana" / "...gdy dolina kwitnie").

**Reakcja poniżej progów (jedna w v1):** przetrzebienie rośliny-żywiciela w trakcie wyprawy sprawia, że jej zapylacz odlatuje do końca cyklu. Dzięki temu dziennik ma co raportować także między progami.

Reszta (szkodniki, choroby roślin, gatunek-zwornik, ukryte polany, zabijanie i obce gatunki jako wejścia) wchodzi dopiero po v1.

**Reguły:**
- **Rodzimy gatunek** to taki, którego biom bazowy (pole w `PlantData`) to ten biom. Wyhodowane przez gracza odmiany rodzimego gatunku dalej są rodzime. Gatunki z innych biomów i ziemskie posadzone w terenie są obce (wejście "−" dopiero po v1).
- **Farma w bazie nie wpływa na Równowagę.** Liczy się tylko to, co gracz robi w terenie wyprawy. Dzięki temu główna pętla farmingu nigdy po cichu nie szkodzi biomowi.
- **Nasadzenia w terenie w v1 nie są zapisywane w scenie wyprawy.** Liczy się tylko ich efekt na Równowagę. Trwałe nasadzenia przychodzą dopiero z placówkami (M5), co omija koszt trwałych zmian świata.
- **Limit na wyprawę:** zmiana Równowagi w jednej wyprawie jest ograniczona do ±30, a każde wejście ma malejące zwroty (dziesiąte posadzone nasiono daje mniej niż pierwsze). Masowe sadzenie nie daje więc +50 od razu.
- **Hamulec (część v1):** Równowaga dryfuje w stronę 0 z obu stron o kilka punktów na cykl. Oba skrajne stany da się osiągnąć celowo w 2-3 wyprawach, ale każdy wymaga podtrzymywania. Dokładne liczby ustali playtest.
- **Dziennik biomu (część v1):** po każdej wyprawie krótki raport przyczyn i skutków, zawsze z liczbową zmianą ("Zebrałeś 40 Voidberry → Pollenbugi odleciały, Równowaga −15").
- **Związek z zagrożeniem:** Równowaga zmienia tabele spawnów i wydarzeń. Tylko przy ≤ -50 wyprawa zaczyna się od Przebudzenia 25. Dodatnia Równowaga nie spowalnia Przebudzenia, tylko zmienia skład fauny.

### Poziomy biomu

- Wyższy poziom odblokowują odkrycia progowe (np. 60% wpisów bazy danych biomu), a nie sama liczba wypraw.
- Gracz wybiera dowolny odblokowany poziom.
- Wyższy poziom dodaje **warstwy zawartości** (nowe gatunki, miejsca, wydarzenia, elitarne warianty jako nowe stworzenia) i lekko przyspiesza Przebudzenie (np. +10% na poziom). Nie skaluje zdrowia ani obrażeń zwykłych stworzeń.

### Jak to rozstrzyga otwarte decyzje z bazy wiedzy

| # | Otwarta decyzja | Propozycja |
|---|---|---|
| 1 | Limit czasu czy narastające zagrożenie? | Przebudzenie, napędzane czasem **i chciwością**. Bez sztywnego timera (poza odliczaniem na progu 100). |
| 2 | Co podnosi poziom biomu? | Odkrycia progowe. |
| 3 | Ręczny wybór trudności? | Tak, spośród odblokowanych poziomów. |
| 4 | Co zostaje po porażce? | MVP: zeskanowane dane. Później: także próbki wysłane kurierem (`N3`) + zarośnięty plecak (`N6`). |
| 6 | Czy placówki działają między wyprawami? | Nie produkują, ale zarastają i tworzą mini-ekosystem (`K4`). Etap: drugi biom (M5). |
| 7 | Wzrost roślin pod nieobecność gracza? | Czas farmy w **cyklach**: 1 wyprawa = 1 cykl. Bez czekania w czasie rzeczywistym. W trakcie cyklu bazę może spotkać najazd. |
| 8 | Nacisk na walkę i broń? | **Rozstrzygnięte (2026-11-12):** pistolet zadaje obrażenia, stworzenia mają zdrowie i mogą zginąć. Rośliny-narzędzia dalej łapią i ogłuszają, później Seed Cannon. Otwarte: czy zabijanie obniża Równowagę (M4). |
| 12 | Konsekwencje ingerencji w ekosystem? | Równowaga. |
| 13 | Zakończenie fabularne? | **Wstępnie:** ożywienie Serca planety drzewami-kotwicami z 3 biomów. Serce to osobna, zamknięta scena, więc nie trzeba trwale zmieniać terenu innych biomów. Do potwierdzenia, gdy powstanie trzeci biom. |

Decyzje 5, 9, 10 i 11 pozostają otwarte, a 8 częściowo (lista w [ToDo.md](ToDo.md)).

### Etapy (zgodne z kamieniami milowymi w ToDo)

1. **MVP = M1-M3.** Zestaw z bazy wiedzy (sekcja 17), w tym 5 gatunków roślin (dolna granica z 17.1), + minimalne Przebudzenie (2 progi). Pomysły z puli świadomie wciągnięte do MVP: `N1` Przebudzenie, `E2` Kuchnia ekspedycyjna, `R3` nasiono-zagadka (jako wymagany "przykład odblokowania"). Warunek kiełkowania R3 w MVP: podlanie wodą z Mglistego źródła, które występuje tylko na poziomie 2 doliny i trzeba ją przynieść w plecaku. Opcjonalnie, jeśli starczy sił: `N5` zlecenia, `T4` robot-botanik.
   **Nowe w wersji 2:** Snapper jako pierwsza roślina-narzędzie na wyprawie (M2). Najazdy fauny rozstrzygane automatycznie, Boomshroom i ogrodzenie jako obrona, Uwaga planety z 2 progami, raport najazdu w rytuale powrotu (M3).
2. **Żywa planeta v1 = M4.** Równowaga w zakresie v1 (tabela wyżej), hamulec, dziennik biomu, skaner "Sieć życia" (`K2`), pozostałe progi Przebudzenia, test Rakietowego Pnącza (`N2`), zdziczałe ziemskie uprawy (`T1`).
   **Nowe w wersji 2:** zagrożenia planety dla bazy (burza, meteoryt) i osłony, prognoza przed wyprawą (`N4`), najazd na żywo przy powrocie (czasem).
3. **Drugi biom = M5.** Grzybowy las, grzybnia (`T2`), gatunek-zwornik (`K5`), terroir nasion (`R2`), pierwsza placówka z sukcesją (`K4`).
   **Nowe w wersji 2:** plaga grzybowa w bazie po pierwszej wizycie w lesie i rośliny antygrzybowe.
4. **Dalej / Kiedyś:** według [ToDo.md](ToDo.md), wybierane na podstawie playtestów.

## Otwarte pytania

- Dziennik zawsze pokazuje liczby. Otwarte zostaje tylko to, czy w trakcie gry widać też stały pasek Równowagi na HUD, czy nastrój czyta się wyłącznie ze świata. Do rozstrzygnięcia w playteście M4.
- Dokładne liczby: tempo hamulca, przesunięcie Równowagi na wyprawę, tempo Przebudzenia, przyrost i spadek Uwagi planety.
- ~~Czy baza też może być zagrożona?~~ Rozstrzygnięte w wersji 2: tak (sekcja "Baza pod presją").
- Jak często najazd na żywo, żeby był wydarzeniem, a nie obowiązkiem? Propozycja startowa: najwyżej co 3-4 cykle.
- ~~Jak zasięg obrony liczy się w trybie automatycznym (promień wokół rośliny czy "strefa farmy")?~~ Rozstrzygnięte w M3: promień wokół każdego obrońcy + pojemność na najazd (sekcja "Baza pod presją").

## Kryteria sukcesu

- **MVP (M3):** tester sam z siebie sadzi drugą roślinę i wraca na drugą wyprawę bez podpowiedzi. Po najeździe potrafi powiedzieć, dlaczego obronił albo stracił uprawy, i przed kolejną wyprawą sam dosadza rośliny obronne.
- **v1 (M4):** tester po 2-3 wyprawach potrafi powiedzieć, **dlaczego** dolina się zmieniła, i przynajmniej raz celowo próbuje ją rozchwiać albo ustabilizować, żeby zdobyć konkretną rzecz. Przynajmniej raz rezygnuje z rzadkiego łupu, bo boi się o bazę (Uwaga planety działa jako decyzja).
- **Drugi biom (M5):** tester sam zauważa ślady tajemnicy (zdziczałe uprawy, grzybnia) i bez podpowiedzi szuka kolejnych albo pyta, co się stało z poprzednią kolonią.

## Dystrybucja

Na razie brak: projekt hobbystyczny. Gdy będzie grywalny build, najprostsza droga to eksport z Godota do pliku .exe i strona na itch.io (darmowa, bez procesu certyfikacji). Steam dopiero, jeśli pojawi się chęć wydania komercyjnego.

## Następne kroki

1. Założyć repo git i projekt Godot 4.x ([ToDo.md](ToDo.md), etap M0).
2. Zbudować "jedną grządkę" (zadanie poniżej).
3. Dokończyć M1, potem mini-wyprawę z Przebudzeniem i ewakuacją (M2).
4. Dopiero po MVP: Równowaga (M4).

## Zadanie na teraz

W najbliższym tygodniu zbuduj w Godocie scenę **"jedna grządka"**: kapsuła jako postać, kamera za plecami, jedno nasiono i roślina z 3 widocznymi etapami wzrostu. Dodaj atrapę "drzwi wyprawy": przejście przez nie przesuwa farmę o 1 cykl (= 1 etap wzrostu). Dzięki temu testujesz docelową pętlę cykli, a nie odliczanie w czasie rzeczywistym. Zbiór z małym efektem cząsteczkowym i dźwiękiem, który oddaje 1-2 nasiona, więc można od razu posadzić znowu. Daj zagrać jednej osobie i nie podpowiadaj. Zapisz jedno zdanie: czy sama posadziła drugą roślinę. To pierwszy test założenia "farming jest rdzeniem".

## Co zauważyłem w Twoim sposobie myślenia

- Na pytanie o moment "whoa" zaznaczyłeś wszystkie cztery odpowiedzi: rośliny, ekosystem, ekspedycje i tajemnicę. To spójne z bazą wiedzy, ale też dokładnie to ryzyko, które baza nazywa w 18.1. Dlatego ToDo idzie etapami: jeden biom i jeden etap naraz, a pomysły wciągnięte do MVP są wypisane wprost.
- Napisałeś: "Nie rozumiem tego podejścia" i kazałeś usunąć je z MVP, zamiast przyjąć coś niejasnego. Dobra reguła na cały projekt: jeśli mechanikę trzeba długo tłumaczyć projektantowi, gracz też jej nie zrozumie.
- Twoja baza wiedzy sama każe AI "krytycznie oceniać pomysły, a nie bezwarunkowo je aprobować". Dlatego każdy pomysł w puli ma ocenę kosztu i etykietę etapu.

## Uwagi recenzenta (otwarte po 3 rundach)

Niezależna recenzja: 3 rundy, ocena 6 → 8/10, 31 uwag potwierdzonych jako rozwiązane. Poniższe 10 drobnych luk zostało zapisanych do rozstrzygnięcia przy budowie M2-M4 (pełna treść: kopia w `~/.gstack/projects/AstroFarmer/`). Uwaga R3-11 (niespójność w ToDo "Teraz") została poprawiona w ToDo.

- ~~**R3-1** Kolce Cierniowej Voidberry chronią "na farmie przed roślinożercą", ale baza jest bezpieczna.~~ Rozwiązane w wersji 2: baza ma najazdy roślinożerców od M3.
- **R3-2** Kiedy zmiany Równowagi wchodzą w życie (na żywo czy po powrocie)? Czy nieudana wyprawa też się liczy i trafia do dziennika?
- **R3-3** Kiedy sprawdzane są progi (start wyprawy czy na żywo) i w jakiej kolejności względem dryfu?
- **R3-4** Co się dzieje z Lumen-molem przy porażce wyprawy?
- **R3-5** Czy Lumen-mola można zdobyć wiele razy i czy bonus do plonu się kumuluje?
- **R3-6** Skąd gracz ma się dowiedzieć o wodzie z Mglistego źródła dla nasiona-zagadki?
- ~~**R3-7** Co drapieżnik robi poniżej Przebudzenia 50?~~ Rozstrzygnięte w M2: śpi w legowisku i atakuje tylko, gdy gracz podejdzie bliżej niż 3.5 m.
- ~~**R3-8** Czy pogoda na progach 50 i 75 zabiera Kondycję?~~ Rozstrzygnięte w M2: nie, to tylko klimat. Kondycję zabiera dopiero burza na progu 100.
- **R3-9** Czy limit ±30 to sztywna zasada, czy wartość startowa do strojenia?
- **R3-10** Kryterium sukcesu MVP powinno obejmować testy etapów M2 i M3 z ToDo oraz 6 pytań z sekcji 17.2.
