# Styl „stary Cartoon Network” (Tartakovsky): analiza i szkice

Notatka z 2026-11-20. **Szkic koncepcyjny do oceny**, nic z tego nie jest w grze. Pytanie autora: jak wyglądałaby gra w stylu starego Cartoon Network (Johnny Bravo, Atomówki, Ed, Edd i Eddy), głównie Genndy'ego Tartakovsky'ego (Laboratorium Dextera, Samuraj Jack), szczególnie nocą, gdy rządzi bioluminescencja.

Rendery: `art/source/sketches/cn_*.png|gif` (wideo MP4 lepszej jakości: `tools/concept_cn/out/`). Źródło: rysunki w kodzie (canvas 2D), `tools/concept_cn/` (podgląd: otwórz `index.html` w przeglądarce, render: `node tools/concept_cn/render.mjs`, potrzebny Edge i ffmpeg).

| Plik | Co pokazuje |
|---|---|
| `cn_1_valley_night.png`, `cn_1_valley_night_loop.gif` | baza w dolinie nocą: chatka, brama, grządki, traktor, dron; fala wiatru przechodzi przez świecącą trawę |
| `cn_2_cast_night.png` | model sheet: farmer (przód, bok, tył) i stworzenia w nocnym świetle |
| `cn_3_meadow_tpp.gif` | tak mogłaby wyglądać rozgrywka: kamera TPP, łąka wyprawy, świecące ślady, latarka, kreskówkowy HUD |
| `cn_4_run_footprints.gif` | bieg z boku: ślady stóp rozbłyskują, trawa przy krokach świeci mocniej (planeta „czuje” gracza) |
| `cn_5_mushroom_forest_pulse.gif` | las grzybowy: po żyłkach grzybni biegną komety światła, blaszki olbrzymów jaśnieją, gdy fala dochodzi do trzonu |
| `cn_6_standoff_split.gif` | pojedynek w trzech kadrach jak w Samuraju Jacku: oczy farmera, Thornback, dłoń z nasionem |
| `cn_7_boomshroom.gif` | rzut nasiona, Boomshroom wyrasta w trzech pozach, nadyma się, 2 klatki uderzenia, Muncherzy odlatują |
| `cn_8_dash_smear.gif` | dash: wyczekanie, smuga (smear), zatrzymanie w pozie, świecący ślad na trawie |

## Krótko: czy to dobry pomysł?

**Tak, i pasuje do tej gry lepiej, niż się wydaje.** Trzy powody:

1. **Bioluminescencja to płaskie światło.** Świecące rośliny w nocy i tak są „plamami koloru na ciemnym tle”, czyli dokładnie tym, z czego Tartakovsky buduje kadry. W stylu CN noc przestaje być czarna i nieczytelna (jak teraz), a staje się indygo, na którym rośliny rysują kształty.
2. **Gra już idzie w tę stronę.** Jest cel-shading (`Stylize`), twardy cień w UI (Field Notebook), farmer ma ogromny podbródek (ukłon w stronę Johnny'ego Bravo sam się prosi), a rośliny mają proste, mocne sylwetki.
3. **Styl porządkuje czytelność rozgrywki.** Zasada Samuraja Jacka „tło bez konturu, postać z konturem” daje darmową regułę gry: *ma kontur = żyje albo da się użyć*. Gracz w nocy od razu widzi stworzenie i znajdźkę na tle płaskiego świata.

Ale to **duża zmiana kierunku** i ma koszt (sekcja „Ryzyka”).

## Co jest w grze teraz (grafika)

- Stylizowane 3D: miękkie, zaokrąglone modele w pastelach, cel-shading z jasną krawędzią i plamami farby (autoload `Stylize`), tekstury liczone w shaderach.
- Noc: prawie czarna (`day_night.gd`: niebo nocą ok. `0.001–0.005`), światło dają latarka i bioluminescencja (`bioluminescence.gd`: trawa ze świecącymi czubkami, mech, świetliki, drzewa-grzyby świecące od spodu, ślady stóp). Efekt jest klimatyczny, ale sylwetki giną, a ekran jest w większości czarny.
- Bloom i miękkie poświaty, gradienty nieba, mgła: realistyczne światło na kreskówkowych bryłach.
- Język kształtów jest mieszany: miękkie, „zabawkowe” postaci i stworzenia obok ostrych, kanciastych gór i kryształów.

## Zasady stylu (co bierzemy od Tartakovsky'ego i reszty CN)

**Kształt przed detalem.** Każda postać to 2–3 proste bryły: farmer = odwrócony trapez tułowia, cienkie nogi, ciężkie buty, kwadratowa szczęka, bańka hełmu jako idealne koło (z kapeluszem w środku, rondem opartym o szybę). Thornback = ciężki „bochenek” z rzędem kolców. Muncher = kula z zębami.

**Tło bez konturu, postać z konturem** (Samuraj Jack). Tła to płaskie plany koloru: im dalej, tym jaśniej i bliżej koloru nieba. Kontur (gruby, ciemnogranatowy, nie czarny) mają tylko postaci, stworzenia, rośliny-narzędzia i znajdźki.

**Płaskie światło.** Bez gradientów: kolor bazowy + twardy sierp światła (rim) w kolorze najbliższego źródła. Nocą postać ma dwa sierpy: chłodny turkus od roślin z dołu i fiolet od księżyca z góry. Poświata to 2–3 schodkowe kręgi, nie rozmycie.

**Noc nie jest czarna.** Niebo w pasach indygo (schodkowy gradient) z płaskimi smugami chmur i 4-ramiennymi iskierkami gwiazd. Kolory własne nocą mnożone przez chłodny filtr (biała koszula robi się lawendowa, skóra wrzosowa), a nie zaciemniane do czerni.

**Paleta: ciepło = człowiek, zimno = planeta.** Turkus, mięta, magenta, fiolet to planeta (rośliny, grzyby, kryształy). Bursztyn i cytryna to człowiek (okno chatki, latarka, reflektory traktora, nasiono Boomshrooma). Każdy kadr nocny ma oba.

**Kompozycja.** Mała postać w ogromnym świecie, duże puste plamy, kadry pionowe (las grzybowy), split-screen (pojedynek), kinowe pasy w ważnych momentach.

**Animacja.**
- Na dwójkach: 12 rysunków na sekundę dla postaci (świat i kamera mogą zostać w 60 fps).
- Pozy trzymane długo, ruch szybki między nimi: wyczekanie → akcja → zatrzymanie (dash, rzut).
- Smuga (smear): 1–2 klatki wydłużonej postaci z „duchami” przy dashu.
- Klatki uderzenia: 2 klatki czarnych sylwetek na płaskim kolorze z promieniami (wybuch Boomshrooma, trafienie bossa).
- Drgający kontur (line boil, z Ed, Edd i Eddy): kontur lekko „żyje” co 2 klatki; w szkicach jest wszędzie.
- „Wszystko się rusza” zostaje: trawa faluje, świetliki mrugają, grzybnia pulsuje, ale skokowo, nie płynnie.

## Jak to przenieść do Godota (3D, kamera TPP)

- **Shader postaci:** rozbudowa `Stylize`: 2 tony bez przejścia + sierp rim w kolorze z najbliższego źródła bioluminescencji (np. uniform ustawiany z pozycji najbliższych świateł) + drugi sierp od księżyca.
- **Kontur:** inverted hull (druga powłoka modelu, `cull_front`, przesunięta po normalnych) tylko dla postaci, stworzeń, roślin-narzędzi i znajdziek. Line boil: szum w vertex shaderze konturu z czasem kwantyzowanym do 12 kroków na sekundę.
- **Tła i teren:** płaskie materiały + mgła **pasmowa** (odległość kwantyzowana do 4–5 stopni), żeby plany głębi były płaskimi pasami, nie gradientem.
- **Poświata:** zamiast bloom: billboardy „halo” ze schodkowymi kręgami (blend add) przy każdym świecącym obiekcie; ewentualnie posterize na buforze glow.
- **Niebo:** shader nieba z pasami (schodkowy gradient) + smugi chmur + gwiazdy-iskierki.
- **Animacje postaci:** w AnimationPlayer interpolacja `Nearest` i klucze co 1/12 s; smear jako osobna poza (shape key) na 1–2 klatki dasha.
- **Klatka uderzenia:** postprocess na 2 klatki (pełny ekran: tło jednym kolorem, wszystkie obiekty z konturem na czarno).
- **HUD:** grube obwódki i twardy cień pasują do obecnego Field Notebook; wystarczy pogrubić kontury i dodać ikony zamiast tekstu.

## Ryzyka i koszty

- **Kłóci się z kierunkiem „jakość, nie low poly, gęsty detal”.** Tartakovsky to redukcja: detal przechodzi w kształt, kompozycję i ruch, nie w gęstość geometrii. Kompromis: gęstość zostaje w roślinności i ruchu (wszystko faluje), ale w płaskich kolorach i z mocnymi sylwetkami.
- **Przeróbka wszystkich materiałów.** Ułatwia ją to, że cel-shading już siedzi w jednym autoloadzie (`Stylize`).
- **Kontury w 3D przy obrotowej kamerze** potrafią mieć artefakty na cienkich elementach (trawa, macki); tam lepiej bez konturu.
- **Noc przestanie być straszna przez ciemność.** Napięcie trzeba budować kolorem i dźwiękiem (np. Przebudzenie barwi niebo na czerwono), a nie czernią.
- **Inspiracja, nie kopia.** Bierzemy zasady (płaskie plany, kontur, timing), ale kształty, postaci i paleta są nasze.

## Propozycja taniego testu

Jedna scena w Godocie (łąka nocą) w nowym stylu, obok obecnej: shader 2 tonów + rim, kontur tylko na farmerze i stworzeniach, mgła pasmowa, halo zamiast bloom, niebo w pasach, animacja farmera na dwójkach. Jeśli zadziała w ruchu z kamerą TPP, dopiero wtedy decyzja o całej grze.

## Pytania do autora

1. Kierunek ogólnie: idziemy w to (cała gra), tylko część (np. noc, przerywniki, bossowie), czy zostaje jako ciekawostka?
2. Kontur: tylko postaci i rzeczy interaktywne (reguła czytelności), czy wszystko?
3. Animacja na dwójkach (12 kl./s) dla postaci: tak, czy płynnie?
4. Twarz farmera: kwadratowa szczęka w stylu Johnny'ego Bravo pasuje?
