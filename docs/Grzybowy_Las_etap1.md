# Grzybowy Las, etap 1 „Pod Kapeluszami Olbrzymów”: rozgrywka

Notatka z 2026-11-20. Plan do akceptacji (szkice: `art/source/sketches/stage1_*.png`). Rozwija [Biomy_etapy.md](Biomy_etapy.md) (etap 1), [Biomy_brainstorm.md](Biomy_brainstorm.md) (P1 i odblokowania) i [Grzybowy_Las_szkic.md](Grzybowy_Las_szkic.md) (wygląd lasu, który już jest w grze w wersji testowej). Nazwy w grze po angielsku.

## Krótko: jak się gra

1. **Lądowanie.** Zawsze ta sama zasada co na łące: plecak, Przebudzenie, ewakuacja z latarni. Mapa losowana przy każdej wyprawie (teren, kanion, doły, jaskinie, położenie Polany, wioski i areny).
2. **Las sam przysyła przeciwników** (jak w Risk of Rain 2): „reżyser” co jakiś czas wypuszcza grupę stworzeń **poza polem widzenia gracza**. Im wyżej Przebudzenie, tym częściej i groźniej. Stać w miejscu się nie opłaca, ale też nie da się „wyczyścić” mapy.
3. **Co można robić** (gracz wybiera, ile zaryzykuje):
   - zbierać znajdźki lasu (w jaskiniach, dołach i kanionie lepsze),
   - odwiedzić **wioskę Sporekinów** (bezpieczna strefa, handel),
   - zejść do **Groty Zarodników** po najlepsze znajdźki, płacąc halucynacjami (z maską bez problemu),
   - znaleźć **Słoneczną Polanę** i pokonać **Rot Shepherda** (mini-boss, opcjonalny),
   - pójść grubiejącą grzybnią do areny i pokonać **The Puffkinga** (boss, odblokowuje etap 2).
4. **Koniec:** ewakuacja z latarni (jak dziś) albo po pokonaniu bossa: latarnia przylatuje do areny i zabiera od razu.

## Reżyser przeciwników (spawn poza polem widzenia)

- **Punkty:** reżyser zbiera punkty co sekundę: `0,6/s × (1 + Przebudzenie/50)`. Po progu 100 (burza) tempo x2.
- **Zakup grupy:** kiedy ma dość punktów, losuje grupę z listy (koszt w punktach) i od razu ją wypuszcza.
- **Gdzie:** 25–45 m od gracza, na terenie, po którym da się chodzić; **poza kamerą** (poza stożkiem widzenia albo zasłonięte, sprawdzane promieniem). Nigdy w bezpiecznych strefach (wioska, Polana po oczyszczeniu, lądowisko na pierwsze 20 s).
- **Jak:** z ziemi wyrasta **kokon z grzybni** i pęka po 1,5 s; stworzenie wychodzi. Słychać to (dźwięk z kierunku), więc gracz ma szansę się odwrócić.
- **Limit:** naraz najwyżej 12 stworzeń od reżysera; daleko pozostawione (ponad 90 m) wracają do grzybni (znikają, punkty wracają do puli).
- **Zabijanie:** stworzenia lasu można zabić z pistoletu; zostawiają **Mycelium Fiber** (nowy surowiec) albo zarodniki. Każde zabójstwo +2 Przebudzenia (las „czuje” śmierć).

| Stworzenie | Koszt | Co robi | Jak sobie radzić |
|---|---|---|---|
| **Sporebat** (stado 3–5) | 4 | Śpią głową w dół pod kapeluszami; od reżysera przylatują stadem, nurkują z góry, po trafieniu odlatują i krążą | słabe (1 strzał), dash w bok przy nurkowaniu |
| **Spore Tick** (1–3) | 5 | Chodzi po ścianach i trzonach, skacze na gracza; trafienie dodaje zarodników (halucynacje) | strzał w locie, Spore Mask |
| **Rotling** (zarażony Muncher, 2–4) | 6 | Zwierzę z naroślami grzybów, biegnie prosto na gracza, przy śmierci puff zarodników | dystans, Snapper |
| **Rot Thornback** (1) | 14 | Zarażony Thornback: szarżuje, narośle pękają chmurą zarodników | Boomshroom, Snapper, unik |
| **Hammer Cap** | – | Stały, w kanionie (już jest) | rytm, skok nad falą |

## Miejsca

- **Słoneczna Polana** (mini-biom, jedno z kilku miejsc na mapie): przez dziurę w kapeluszach wpada słońce; zielona trawa, kwiaty, motyle, ciepło. Brzegi zjada brunatna zgnilizna. Rot Shepherd pasie tu zarażone stado. Po jego pokonaniu zgnilizna się cofa, Polana zostaje bezpieczna do końca wyprawy.
- **Wioska Sporekinów:** chatki z trzciny na palach (strzecha porośnięta mchem i grzybami), kładki i pomosty między trzonami olbrzymów, lampiony. **Sporekini** (poprawka autora) to nie grzyby: krępi, uśmiechnięci ludkowie z bagien, skóra jak mokry mech w plamki, duże oczy, włosy z trzciny, plecione poncha, na których rosną małe grzybki (stąd nazwa). „Mówią” krótkimi dźwiękami i dymkami z emocjami-ikonkami. Bezpieczna strefa (reżyser tu nie wypuszcza stworzeń).
- **Grota Zarodników** (Spore Hollow, jedna na mapę, wejście w zboczu): jaskinia wypełniona gęstą, świecącą mgłą zarodników, w głębi najlepsze znajdźki (artefakt, rzadkie próbki, nasiona). Bez maski halucynacje narastają szybko (patrz niżej). Na etapie 1 to utrudnienie, ale wykonalne bez maski. Wygląd (uwaga autora po szkicu): **ciemniej** niż na szkicu, zarodniki w powietrzu **drobne**, a na ścianach co jakiś czas **pulsująca grzybnia** (cienkie świecące nitki, fala światła), żeby w środku było ładnie, a nie tylko mgliście.
- **Jaskinie** (2–3 na mapę): wejścia w zboczach i w ścianie kanionu, krótkie korytarze z niebieskimi grzybami i lepszymi znajdźkami; ciemno (latarka), Spore Ticki.
- **Arena Puffkinga:** okrągła niecka, do której zbiegają się grube sznury grzybni (droga bez znacznika). W środku śpi olbrzymia purchawka.
- Do tego reszta świata ze szkicu: **grzybnia** z cienkich nitek pulsująca na ziemi, **zarodniki** pod kapeluszami, **Shelfcapy** na klifach (wspinaczka).

## Rot Shepherd (mini-boss)

Wysoki, przygarbiony grzybowy pasterz z kosturem, płaszcz z nitek grzybni, zgniły, opadający kapelusz.
1. Pasie stado Rotlingów; gdy gracz wejdzie na Polanę, kosturem posyła je na gracza (3–4 naraz) i stawia nowe kokony.
2. Wbija kostur w ziemię: wokół rozchodzi się pierścień zgnilizny (strefa obrażeń), którą trzeba przeskoczyć albo wyjść; kostur świeci = słaby punkt (trafienie w kostur ogłusza).
- **Nagroda:** nasiona kwiatów Polany (Glade Bloom, przyciągają zapylacze do bazy) i towarzysz **Lantern Moth** (świeci nad graczem nocą, zbiera pyłek).

## The Puffking (boss, 2 fazy)

Ogromna purchawka (ok. 7 m) z koroną małych purchawek, popękana skóra z otworami. Groźny (poprawka autora): szeroka, poszarpana paszcza z nierównymi zębami i świecącym gardłem, wściekłe świecące szparki oczu pod ciężkimi łukami brwiowymi. Małe purchawki z fazy 2 mają takie same, mniejsze paszcze.
1. **Toczy się** po arenie (zostawia ślad zarodników) i co jakiś czas **wydmuchuje chmurę** zarodników z otworów (obrażenia + halucynacje bez maski). Słabe punkty: otwory świecą przed wydmuchem.
2. Przy połowie zdrowia **pęka na trzy mniejsze purchawki**, które gonią gracza i wybuchają przy dotyku (zapowiedź Cluster Shroom). Trzeba je rozstrzelać z dystansu albo zwabić na siebie nawzajem.
- **Nagroda:** nasiono **Cluster Shroom** (Boomshroom, który po wybuchu rozrzuca 3 mniejsze bomby), dużo Mycelium Fiber, odblokowanie etapu 2, wpis w bazie danych.

## Halucynacje

- Zarodniki (chmury Bellcapów i Puffkinga, trafienia Spore Ticka, a przede wszystkim mgła Groty Zarodników) napełniają ukryty licznik. Licznik sam opada poza mgłą.
- **Spore Mask** całkowicie chroni.
- Siła zależy od etapu (poprawka autora: „potem bez maski tak trudno, że aż niewykonalnie”):

| Poziom licznika | Etap 1 (do zrobienia bez maski) | Etap 2 | Etap 3 i dalej (bez maski praktycznie niewykonalne) |
|---|---|---|---|
| 30% | obraz lekko faluje, kolory płyną | + szepty z różnych stron | + ciemnieją brzegi ekranu |
| 60% | **fałszywe znajdźki** (znikają przy podniesieniu, migoczą fioletem) | + fałszywe ścieżki i ściany (iluzje terenu) | + odwrócone sterowanie co jakiś czas |
| 100% | **fantomowi przeciwnicy**: fioletowi, półprzezroczyści, nie zadają obrażeń, rozwiewają się po strzale | fantomy zadają małe obrażenia, HUD kłamie (pasek zdrowia, licznik) | fantomy jak prawdziwe, kompas i znacznik latarni wariują, w grocie stale 100% |

Wskazówka dla gracza na etapie 1: prawdziwe znajdźki nie migoczą, a fantomy nie rzucają cienia.

## Nagrody i odblokowania (P1)

| Co | Skąd | Co daje |
|---|---|---|
| **Mycelium Fiber** (surowiec) | stworzenia lasu, kokony | liny, siatki, maska |
| **Spore Mask** | warsztat: 3 Mycelium Fiber + 2 Glow Spores (przepis od Sporekinów) | chroni przed halucynacjami i chmurami |
| **Mushroom Log** | handel ze Sporekinami | budowla w bazie: rośnie na niej grzyb jadalny co cykl, w cieniu i bez wody |
| **Cluster Shroom** | Puffking | nowe nasiono (rzut: wybuch + 3 małe bomby) |
| **Fungicide** | warsztat (przepis od Sporekinów) | ochrona upraw przed plagą grzybową (plaga przyjdzie z lasu na butach, M5) |
| Glade Bloom, Lantern Moth | Rot Shepherd | kwiaty do bazy, towarzysz |

Handel ze Sporekinami: płacisz Glow Spores, Mycelium Fiber, kryształami; dostajesz rzadkie nasiona grzybów (do Mushroom Log), przepisy i Mushroom Log.

## Wejście do lasu

Zamiast przycisku „(test)”: na łące (poziom 2, w pobliżu Mglistego źródła) leży rzadki **Spore Pod** (zarodnia przyniesiona wiatrem). Zeskanowanie jej odblokowuje cel „Mushroom Forest” na ekranie wyprawy. Do czasu skończenia etapu zostawiam też przycisk testowy (do usunięcia przed playtestem).

## Kolejność robienia (po akceptacji szkiców)

1. ~~Reżyser + kokon + Sporebat i Rotling (podstawa rozgrywki).~~ Zrobione 2026-11-20 (zrzuty: `art/source/sketches/forest_ingame_6..8_*.png`).
2. ~~Świat: grzybnia shaderem, zarodniki, Shelfcapy, jaskinie, Grota Zarodników.~~ Zrobione 2026-11-21 (zrzuty `forest_ingame_9..14_*.png`).
3. ~~Spore Tick, Rot Thornback, halucynacje.~~ Zrobione 2026-11-21 (etap 1: obraz faluje, fałszywe znajdźki, fantomy; mocniejsze skutki z tabeli dla etapów 2–3 przyjdą z tymi etapami).
4. ~~Wioska Sporekinów + handel + Spore Mask, Mushroom Log, Fungicide, Mycelium Fiber.~~ Zrobione 2026-11-21 (+ Mushroom Stew: halucynacje o połowę wolniej).
5. ~~Słoneczna Polana + Rot Shepherd + Lantern Moth.~~ Zrobione 2026-11-21 (Glade Bloom: plon Pollen; model 3D kwiatu jeszcze do szkicu).
6. ~~Arena + The Puffking + Cluster Shroom + odblokowanie etapu 2.~~ Zrobione 2026-11-21 (etap 2 sam w sobie jeszcze nie istnieje: tylko flaga i napis na ekranie wyprawy).
7. ~~Spore Pod na łące (wejście do lasu), wpisy w bazie danych, test całego etapu.~~ Zrobione 2026-11-21 (Spore Pod leży cały czas, nie tylko nocą; w buildzie debug las zawsze dostępny).

**Etap 1 gotowy do playtestu** (2026-11-21).

Muzyka i dźwięki lasu: zamówione w [Muzyka_zamowienia.md](Muzyka_zamowienia.md) (osobny czat).
