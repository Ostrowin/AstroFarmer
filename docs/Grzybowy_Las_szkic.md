# Grzybowy Las: szkic poziomu (etap 1)

Notatka z 2026-11-20. **Szkic do akceptacji**, jeszcze nic nie jest w grze. Opiera się na [Biomy_etapy.md](Biomy_etapy.md) (etap 1 „Pod Kapeluszami Olbrzymów”) i [Biomy_brainstorm.md](Biomy_brainstorm.md) (Grzybowy Las, M5) oraz na prośbie autora: olbrzymie grzyby dające półmrok, nowe grzyby na klifach, świecące zarodniki i blaszki, pulsująca grzybnia.

Rendery: `art/source/sketches/mushroom_*.png` + `mushroom_7_mycelium_pulse.gif`. Źródło: `art/source/mushroom_forest.blend`, skrypt `tools/blender/mushroom_forest_sketch.py` (bryły, to nie są gotowe modele).

| Plik | Co pokazuje |
|---|---|
| `mushroom_1_under_caps_day.png` | dzień: widok zza pleców farmera, półmrok pod kapeluszami |
| `mushroom_2_gills_up.png` | widok w górę: świecące blaszki pod kapeluszami |
| `mushroom_3_cliff_shelves.png` | klif z grzybami-półkami, po których można się wspinać |
| `mushroom_4_canopy_overview.png` | z góry: kapelusze zamykają niebo, dlatego na dole jest ciemno |
| `mushroom_5_under_caps_night.png` | ten sam widok co 1, w nocy |
| `mushroom_6_cliff_night.png` | klif w nocy |
| `mushroom_7_mycelium_pulse.gif` | fala światła przechodząca przez grzybnię |
| `mushroom_8_toward_boss.png` | grzybnia grubieje w sznury przy arenie bossa (zakopana purchawka = zapowiedź The Puffkinga) |

**Wersja 2 (uwagi autora z 2026-11-20):** całość ciemniejsza; zarodniki drobne jak pył i tylko pod kapeluszami; grzybnia z cieniutkich nitek zamiast grubych żył, grubsza dopiero przy bossie. Widok 4 (z góry) jest techniczny: bez mgły, żeby było widać układ kapeluszy.

## Nastrój

- **Wieczny półmrok, także w dzień.** Kapelusze olbrzymów prawie stykają się brzegami, więc słońce przebija tylko wąskimi smugami. W dzień świat jest fioletowo-szary i zamglony (sylwetki trzonów giną w mgle), w nocy prawie czarny i oświetlony tylko przez grzyby.
- **Mgła świeci delikatnie fioletem**, więc dalekie trzony są ciemnymi sylwetkami na jaśniejszym tle. To daje głębię bez słońca.
- **Kolor = rodzaj grzyba**: turkus (olbrzymy), magenta (średnie), bursztyn (półki na klifach), zieleń (małe grzybki na ziemi). Gracz z daleka wie, na co patrzy.

## Grzyby (nazwy w grze po angielsku)

| Nazwa | Rozmiar | Wygląd | Rola w grze |
|---|---|---|---|
| **Towercap** | 22-45 m wysokości, kapelusz 18-36 m | lekko pochylony trzon z pierścieniem, fioletowy kapelusz w jasne plamki; pod spodem gęste blaszki świecące turkusem, najjaśniej przy brzegu | robi „sufit” lasu i półmrok; z blaszek cały czas opadają świecące zarodniki |
| **Bellcap** | 5-12 m | cienki trzon, dzwonowaty kapelusz (ciemny morski), blaszki magenta, sypie różowymi zarodnikami | średnie piętro lasu, punkty orientacyjne; później: Spore Mortar / halucynacje (P2) |
| **Shelfcap** (nowy, na klifach) | półki 2-4,5 m szerokości | grzyby-huby przyrośnięte do skały, brązowo-rdzawe na górze, **spód świeci bursztynem** przez pory; z części zwisają świecące nitki | **platformy**: schodkami prowadzą na górę klifu, gdzie leżą lepsze znajdźki (rzadkie próbki, artefakt). Bursztyn jest celowo ciepły, żeby droga w górę była czytelna w fioletowym lesie |
| **Glowcap** | 0,2-0,6 m | kępki małych grzybków z zielonkawo świecącymi kapelusikami | wypełnienie ziemi, później znajdźka (Glow Spores już są w grze) |

Na skale klifu są też plamy słabo świecącego porostu (zielonkawe), żeby ściana nie była czarną dziurą.

## Zarodniki

- Drobne jak pył (z daleka po jednym pikselu), **tylko pod kapeluszami**, nie w całym powietrzu.
- Każdy zarodnik ma własny czas życia: większość gaśnie po kilku metrach opadania, nieliczne lecą prawie do ziemi. Pod blaszkami jest gęsto, niżej coraz rzadziej, a zarodnik ciemnieje w miarę opadania.
- W Godot: cząsteczki pod każdym kapeluszem (losowy czas życia, zanikanie koloru), bardzo małe punkty bez dużej poświaty.

## Grzybnia

- **Cieniutkie nitki** jak w prawdziwej grzybni (kilka mm), kręte i rozgałęzione; świecą słabo, mocno rozjaśnia je dopiero fala pulsu. Nitki rozchodzą się z **serc grzybni** (spłaszczonych guzów), a między sercami leży rzadka sieć pojedynczych nitek.
- **Grubieje w stronę bossa:** im bliżej areny, tym nitki grubsze, przy samej arenie zostaje kilkanaście grubych sznurów jak korzenie. Gracz może po grzybni trafić do bossa bez znacznika.
- W Godot: grzybnia jako wzór rysowany shaderem na ziemi (linie z szumu/tekstury, grubość zależna od odległości do bossa, puls z odległości od serca i czasu), nie jako osobne bryły. Dzięki temu nitki zostaną cienkie z bliska i z daleka, a puls nic nie kosztuje.
- **Puls:** co kilka-kilkanaście sekund z serca wychodzi fala światła i biegnie żyłkami na zewnątrz (GIF). Każde serce ma swój rytm, więc las „oddycha” nierówno.
- Łączy się z planem M5 (`T2`, `W5`): przy niskiej Równowadze pulsuje częściej i jaśniej, przy bardzo niskiej otwiera „oczka”. Pomysł: puls przyspiesza, kiedy gracz stoi na grzybni („czuje” go), co podbija Przebudzenie.

## Teren

- Płaskie, mokre dno lasu: ciemna ziemia, plamy fioletowego i zielonkawego mchu, **płytkie kałuże** (woda po kostki z opisu etapu; odbijają świecenie).
- **Klify** (nowe względem łąki): pionowe ściany ok. 30 m z warstwami skały, na górze druga półka terenu z własnymi olbrzymami. Dno i góra klifu to dwa poziomy rozgrywki.
- Wąskie smugi światła przez szczeliny w kapeluszach (w dzień), w nocy prawie znikają.

## Ukształtowanie terenu (uwaga autora, 2026-11-20)

Teren ma być nieregularny: raz trzeba wejść wyżej, raz zejść niżej, można wpaść w dziurę albo do jaskini. **Wersja testowa jest już w grze** (wybór „Mushroom Forest (test)” na ekranie wyprawy), losowana przy każdej wyprawie:

- pagórki i grzbiety, miejscami tarasy z uskokami ok. 2 m (część da się wskoczyć, część nie),
- doły ze stromymi ścianami: wpadasz i wychodzisz jedyną rampą,
- kanion przez całą mapę ze stromymi ścianami i wejściami na końcach; w nim **Hammer Capy** (inny typ przeciwnika: wyrastają ze ścian, trzon zagięty w górę, uderzają kapeluszem w dno kanionu; falę trzeba przeskoczyć albo przeczekać) i ulepszenie w środku,
- detale bez znaczenia dla rozgrywki, ale z klimatem (modele w `art/models/forest/`, wg zdjęć autora): świecące zielone wachlarze i rozety na ścianach i trzonach, boczniaki z pomarańczowym światłem pod kapeluszem, ciemne czernidłaki, grzyby koralowe, paprocie, krzewy z bulwami, głazy z mchem, kłody i martwe pnie. Wszystko się rusza: kołysze, faluje i pulsuje światłem, każdy w swoim rytmie,
- jaskiń jeszcze nie ma: mapa wysokości nie robi nawisów, potrzebne są osobne bryły (następny krok).

## Jak to zrobić w Godot (po akceptacji)

- Nowa scena `scenes/levels/expedition_mushroom.tscn` na wzór łąki (`expedition.gd`, znajdźki, ewakuacja, latarnia z `evac_beam.gd`).
- Olbrzymy: modele z Blendera (2-3 warianty Towercap, 2 Bellcap, 4-5 półek), rozsiewane jak drzewa (`TreeScatter` / `PropScatter` + `ScatterGrid`); trzon z kolizją, kapelusz bez (za wysoko).
- Blaszki i grzybnia: shadery zamiast tekstur (paski blaszek z kąta; grzybnia opisana wyżej).
- Półmrok: `WorldEnvironment` z mgłą wolumetryczną (fioletowa, lekko świecąca), słabe słońce, smugi jako `SpotLight3D`; zegar dnia i nocy z `day_night.gd` z własnymi kolorami lasu.
- Zarodniki: cząsteczki pod kapeluszami (opisane wyżej); tylko te najbliżej gracza, żeby nie liczyć całego lasu.
- Klif: osobna siatka ze skały z kolizją, półki z kolizją jako schody.

## Pytania do autora

1. Ogólny nastrój (fioletowy półmrok, kolory grzybów) — tak, czy zmienić paletę?
2. Grzyby-półki jako **wspinaczka na klif** — pasuje? Czy mają być tylko ozdobą?
3. Grzybnia: puls tak jak w GIF-ie (fala z serca), czy raczej całe żyłki rozjaśniają się naraz?
4. Gęstość: ma być tak ciasno jak w szkicu (sufit prawie zamknięty), czy z większymi polanami?
5. Klif po przyciemnieniu prawie znika w mroku (widać głównie świecące półki). Zostawić tak, czy dodać mu trochę światła (więcej porostu, poświata od półek)?
