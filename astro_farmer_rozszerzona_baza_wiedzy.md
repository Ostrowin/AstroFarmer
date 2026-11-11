# ASTRO FARMER ROGUELIKE

## Rozszerzony dokument koncepcyjny i baza wiedzy dla AI planującego projekt

> Dokument roboczy. Zawiera ustalone kierunki, rozwinięte pomysły oraz
> kwestie do późniejszego zaprojektowania. Nie traktuj każdego pomysłu
> jako ostatecznej decyzji. Priorytetem jest zachowanie głównej wizji
> gry i pomaganie w jej rozwijaniu bez niepotrzebnego komplikowania
> projektu.

------------------------------------------------------------------------

# 1. Esencja projektu

## 1.1. Jednozdaniowy opis

Kolorowy, trzecioosobowy roguelite o farmerze eksplorującym nieprzyjazną
obcą planetę, odkrywającym niezwykłe organizmy i rozwijającym farmę oraz
ekosystem, które umożliwiają coraz dalsze wyprawy.

## 1.2. Główna fantazja gracza

Gracz nie jest żołnierzem, który przy okazji sadzi rośliny. Jest
odkrywcą-farmerem. Jego najważniejszym narzędziem jest wiedza o lokalnej
florze, faunie i środowisku. Z czasem potrafi wykorzystać obcy ekosystem
do zdobywania zasobów, ochrony, transportu i przetrwania.

## 1.3. Filary projektu

1.  **Eksploracja** --- odkrywanie biomów, gatunków, anomalii, ruin i
    sekretów.
2.  **Farming** --- zbieranie nasion, uprawa, eksperymentowanie, mutacje
    i rozwój odmian.
3.  **Ekosystem** --- organizmy oddziałują na siebie i na uprawy; gracz
    może te zależności wykorzystać.
4.  **Ekspedycje roguelite** --- wyprawy mają ryzyko, losowe zdarzenia,
    tymczasowe ulepszenia i decyzję o ewakuacji.
5.  **Trwały rozwój** --- baza, odkrycia i technologie zostają z graczem
    i otwierają nowe możliwości.
6.  **Automatyzacja** --- wraz z postępem gracz ogranicza monotonne
    czynności i buduje działające systemy.

## 1.4. Zasada przewodnia

**Eksplorujesz, żeby zdobywać nowe życie. Uprawiasz, żeby rozwijać swoje
możliwości. Rozwijasz ekosystem, żeby przetrwać i odkrywać jeszcze
więcej.**

------------------------------------------------------------------------

# 2. Gatunek, kamera i prezentacja

-   Gatunek: roguelite / roguelike z elementami farmingu, survivalu,
    eksploracji, craftingu i budowania bazy.
-   Kamera: TPP, za plecami postaci, z czytelnym widokiem na otoczenie;
    inspiracja kamerą *Risk of Rain 2*.
-   Świat: stylizowane 3D, kolorowe, bajkowe, z mocnymi sylwetkami i
    dużą czytelnością.
-   Inspiracje kierunkowe, nie wzorce do kopiowania:
    -   *Risk of Rain 2* --- czytelność akcji, kolor, kamera i rytm
        ekspedycji.
    -   *Astroneer* --- przyjazna, obca planeta i eksploracja.
    -   *Stardew Valley* --- satysfakcja z rozwoju farmy i odkrywania
        upraw.
    -   *Minecraft* --- swoboda craftingu, budowania i
        eksperymentowania.
-   Gra powinna być przyjemna wizualnie, ale świat nie może być
    całkowicie bezpieczny. Urocza stylistyka może kontrastować z
    nieprzyjazną naturą.

------------------------------------------------------------------------

# 3. Świat gry

## 3.1. Jedna planeta, wiele regionów

Robocza nazwa planety: **Elysium-7**. To nazwa tymczasowa.

Planeta składa się z połączonych regionów. Z bazy można dostrzec odległe
góry, lasy, pustkowia lub inne charakterystyczne obszary. Kolejne
przejścia mogą być początkowo zablokowane przez teren, zagrożenia lub
brak technologii.

Nie musi to być w pełni otwarty świat od początku. Można zastosować
połączenie: - centralnej, bezpieczniejszej doliny z bazą, - dużych
obszarów biomów eksplorowanych podczas wypraw, - skrótów i przejść
odblokowywanych w miarę rozwoju.

## 3.2. Środowisko powinno wpływać na rozgrywkę

Biom to nie tylko inna tekstura ziemi. Powinien zmieniać: - warunki
wzrostu roślin, - dostępność wody, światła i składników, - zachowanie
stworzeń, - typy zagrożeń, - dostępne materiały i technologie, - sposób
przygotowania ekspedycji.

## 3.3. Przykładowe biomy

### Zielona dolina --- biom startowy

-   Łagodniejszy niż pozostałe, ale nadal nieprzyjazny.
-   Podstawowe rośliny, woda, drewno, kamień i proste minerały.
-   Mniejsze zagrożenia pozwalające poznać systemy gry.
-   Miejsce głównej bazy.

### Grzybowy las

-   Wilgotny, gęsty las, ogromne grzyby i zarodniki w powietrzu.
-   Nowe grzyby, nawozy, składniki biologiczne i możliwości genetyczne.
-   Zarodniki mogą wpływać na widoczność, wzrost lub zachowanie
    organizmów.
-   Specjalizacja: biotechnologia, grzyby, nawozy i mutacje.

### Pustynne równiny

-   Mało wody, duże wahania temperatury, burze piaskowe.
-   Rośliny magazynujące wodę, minerały i kryształy.
-   Specjalizacja: magazynowanie wody, energia, odporność na suszę.

### Zimowe góry

-   Niskie temperatury, śnieg, lód i zamarzające zbiorniki.
-   Rośliny odporne na zimno, kryształy i rzadkie stworzenia.
-   Potrzeba izolacji, ogrzewania i odpowiedniego wyposażenia.

### Jaskinie i podziemia lawowe

-   Ciemność, wysoka temperatura, lawa i niestabilne podłoże.
-   Zaawansowane metale, minerały i organizmy przystosowane do
    ekstremalnych warunków.
-   Specjalizacja: zaawansowane materiały i technologie energetyczne.

### Las gigantycznych drzew

-   Ogromne pnie, korzenie, wielopoziomowe ścieżki i korony drzew.
-   Materiały organiczne, rzadkie owoce i stworzenia żyjące wysoko nad
    ziemią.
-   Specjalizacja: automatyzacja organiczna, konstrukcje i materiały
    roślinne.

### Biom wysokiej trawy

-   Roślinność wyższa od postaci, ograniczona widoczność i ukryte
    stworzenia.
-   Zapylacze, roślinożercy i gatunki nadające się do hodowli.
-   Specjalizacja: zoologia, hodowla, zapylanie i nawozy.

### Bagienne niziny

-   Woda, błoto, toksyny, rośliny mięsożerne i fauna wodna.
-   Rzadkie związki biologiczne i rośliny oczyszczające wodę.
-   Możliwe zagrożenia związane z chorobami roślin, pasożytami i trudnym
    terenem.

Biomy są propozycjami. Ich liczba i zakres powinny wynikać z możliwości
produkcyjnych projektu.

------------------------------------------------------------------------

# 4. Progresja biomów --- kluczowy system

## 4.1. Niezależny poziom zagrożenia

Każdy biom ma własny poziom trudności. Gracz sam wybiera, który region
rozwija i w jakiej kolejności. Nie ma obowiązkowej liniowej kolejności
odwiedzania wszystkich biomów.

Przykład: - Grzybowy las: poziom zagrożenia 1. - Pustynia: poziom
zagrożenia 3. - Zimowe góry: poziom zagrożenia 1.

Gracz może rozwijać jeden biom, a inny zostawić na później.

## 4.2. Wyższa trudność = nowe warstwy zawartości

To ważny element projektu: powrót do znanego biomu na wyższym poziomie
powinien odkrywać nowe rzeczy, a nie tylko zwiększać zdrowie i obrażenia
przeciwników.

Przykładowy rozwój Lasu X: - **Poziom 1:** podstawowe rośliny, pospolite
stworzenia, łatwo dostępne zasoby. - **Poziom 2:** rzadkie nasiona, nowe
warianty stworzeń, trudniej dostępne miejsca. - **Poziom 3:** ukryte
polany, nowe gatunki, anomalie i specjalne materiały. - **Poziom 4+:**
wyjątkowe wydarzenia, elitarne stworzenia, rzadkie mutacje, sekretne
lokacje i wyzwania.

Przykładowe nowe odkrycia: - gatunki roślin dostępne tylko na wyższych
poziomach, - nowe warianty znanych stworzeń, - rzadkie zasoby i
składniki, - zamknięte wcześniej przejścia, - ukryte jaskinie i
gniazda, - anomalie środowiskowe, - nowe receptury i technologie, -
wyjątkowe wydarzenia i bossopodobne stworzenia.

## 4.3. Urozmaicenie zamiast prostego skalowania

Wyższy poziom biomu może zmieniać skład ekspedycji: - inne kombinacje
stworzeń, - większa aktywność drapieżników, - nowe warunki pogodowe, -
większa liczba przeszkód, - nowe interakcje między organizmami, -
rzadsze, ale bardziej wartościowe znaleziska.

Warto unikać sytuacji, w której każdy kolejny poziom oznacza wyłącznie
większe statystyki przeciwników.

## 4.4. Co podnosi poziom biomu?

Kierunek do zaprojektowania: - poziom rośnie po udanych ekspedycjach lub
zdobyciu określonego postępu, - niektóre odkrycia mogą wymagać
konkretnego poziomu, - poziom powinien być czytelny przed wyprawą, -
gracz powinien rozumieć, jakie nowe możliwości i ryzyko wiążą się z
kolejnym poziomem.

Nie ustalono jeszcze, czy poziom wzrasta automatycznie po każdej
wyprawie, czy zależy od działań gracza. To otwarta decyzja projektowa.

------------------------------------------------------------------------

# 5. Ekspedycje i pętla rozgrywki

## 5.1. Podstawowa pętla

1.  Gracz przygotowuje się w bazie.
2.  Wybiera biom, poziom trudności, wyposażenie i cel wyprawy.
3.  Wyrusza na ekspedycję.
4.  Eksploruje, zbiera, skanuje i odkrywa nowe organizmy.
5.  Buduje tymczasowe urządzenia lub placówki.
6.  Zdobywa losowe ulepszenia ekspedycyjne.
7.  Zagrożenie narasta; gracz decyduje, czy kontynuować.
8.  Ewakuuje się lub ryzykuje dalszą eksplorację.
9.  W bazie wykorzystuje zdobycze do rozwoju farmy, technologii i
    kolejnych wypraw.

## 5.2. Decyzja o ewakuacji

Ekspedycja powinna mieć wyraźną stawkę. Im dłużej gracz zostaje, tym
większa szansa na rzadkie znaleziska, ale też ryzyko utraty części
zdobyczy.

Możliwe mechaniki: - urządzenie ewakuacyjne wymagające energii, - punkt
ewakuacji, który trzeba aktywować, - ograniczona liczba bezpiecznych
powrotów, - sygnał ostrzegający o narastającym zagrożeniu, - możliwość
przygotowania alternatywnych punktów powrotu.

Szczegóły do późniejszego zaprojektowania. Powrót nie powinien być
frustrującym obowiązkiem ani wymagać długiego marszu przez pusty teren.

## 5.3. Cele ekspedycji

Przed wyprawą można wybrać specjalizację: - **Botanika:** szukanie
nasion i nowych odmian. - **Zoologia:** odkrywanie i przyciąganie
stworzeń. - **Górnictwo:** minerały i metale. - **Technologia:** ruiny,
urządzenia i receptury. - **Ekspansja:** zakładanie placówek i punktów
logistycznych.

Cele mogą wpływać na dobór nagród, ale nie powinny całkowicie ograniczać
swobodnego odkrywania.

------------------------------------------------------------------------

# 6. Progresja stała i runowa

## 6.1. Stały postęp

Po powrocie gracz może zachować: - odkryte gatunki i wpisy w bazie
danych, - nasiona i próbki biologiczne, - receptury, - odblokowane
technologie, - rozwój głównej bazy, - dostęp do nowych obszarów, -
wiedzę o zagrożeniach i słabościach stworzeń.

## 6.2. Postęp ekspedycyjny

W trakcie runu gracz może zdobywać: - losowe ulepszenia, - tymczasowe
bonusy, - prowizoryczne urządzenia, - efekty mutacji, - tymczasowe
wsparcie stworzeń, - modyfikatory narzędzi i pojazdów.

Większość tych efektów kończy się wraz z ekspedycją.

## 6.3. Porażka i utrata zasobów

-   Porażka powinna mieć konsekwencje, ale nie kasować całego
    długoterminowego rozwoju.
-   Część surowców ekspedycyjnych może zostać utracona.
-   Ważne odkrycia mogą być zachowywane po ich zeskanowaniu lub
    zabezpieczeniu.
-   Warto rozdzielić zwykłe łupy od unikalnych danych i próbek, aby
    ryzyko było zrozumiałe.

------------------------------------------------------------------------

# 7. Farming --- główna mechanika

## 7.1. Sposób uprawy

-   Główna farma znajduje się przy bazie.
-   Gracz może zakładać mniejsze plantacje w biomach.
-   Sadzenie odbywa się w miarę swobodnie, bez wymogu trzymania się
    sztywnej siatki.
-   Rośliny rosną w czasie rzeczywistym również wtedy, gdy gracz
    eksploruje.
-   Uprawa powinna być prosta do rozpoczęcia, ale dawać przestrzeń do
    eksperymentów.

## 7.2. Kategorie roślin

-   **Owoce:** jedzenie, regeneracja i zasoby.
-   **Grzyby:** składniki mikstur, nawozów i biotechnologii.
-   **Kwiaty:** przyciąganie zapylaczy i efekty wspierające.
-   **Rośliny obronne:** odstraszanie lub zatrzymywanie zagrożeń.
-   **Rośliny użytkowe:** włókna, drewno, paliwo i materiały.
-   **Rośliny mięsożerne:** kontrola szkodników lub obrona.
-   **Rośliny mutujące:** nieprzewidywalne właściwości i rzadkie
    warianty.
-   **Rośliny środowiskowe:** oczyszczanie wody, stabilizacja gleby,
    poprawa wilgotności.

## 7.3. Parametry wzrostu

Nie należy symulować wszystkiego. Na początek wystarczy kilka czytelnych
parametrów: - woda, - temperatura, - światło, - czas wzrostu, - jakość
podłoża lub składniki odżywcze.

Każdy gatunek powinien mieć inne preferencje i tolerancje. Biom wpływa
na to, które rośliny rosną naturalnie, a które wymagają przygotowania
warunków.

## 7.4. Sąsiedztwo roślin

Rośliny mogą tworzyć małe, zrozumiałe zależności: - grzyby poprawiają
wilgotność, - kwiaty przyciągają zapylacze, - określone korzenie
poprawiają podłoże, - duże rośliny dają cień, - niektóre gatunki
konkurują o światło i przestrzeń, - rośliny mięsożerne ograniczają
szkodniki.

Celem jest tworzenie ciekawych kombinacji, a nie skomplikowana symulacja
każdego organizmu.

## 7.5. Przykładowe gatunki --- nazwy robocze

-   **Voidberry:** owoc dający krótkotrwały bonus do szybkości.
-   **Boomshroom:** grzyb reagujący wybuchem lub odrzutem.
-   **Snapper:** roślina obronna chwytająca intruzów.
-   **Crystal Bloom:** kwiat wytwarzający kryształy.
-   **Floatroot:** roślina z unoszącymi się owocami lub pęcherzami.
-   Nazwy są tymczasowe i mogą zostać zmienione.

## 7.6. Mutacje

Trzy źródła mutacji: 1. **Naturalne:** wynikają z biomu, temperatury,
światła i podłoża. 2. **Genetyczne:** uzyskiwane przez krzyżowanie lub
eksperymenty w laboratorium. 3. **Kosmiczne:** wynikają z anomalii,
meteorytów lub niezwykłych zjawisk.

Mutacje mogą zmieniać wygląd, tempo wzrostu, odporność, plon lub
dodatkowe właściwości. Powinny być czytelne wizualnie.

------------------------------------------------------------------------

# 8. Ekosystem i fauna

## 8.1. Role stworzeń

-   **Zapylacze:** zwiększają plony lub szansę na nasiona.
-   **Roślinożercy:** zjadają rośliny, ale mogą zostawiać nawóz.
-   **Drapieżniki:** kontrolują populację roślinożerców.
-   **Pasożyty:** atakują konkretne gatunki roślin lub stworzeń.
-   **Symbionty:** zapewniają korzyści w zamian za odpowiednie warunki.
-   **Zbieracze:** przenoszą nasiona lub gromadzą materiały.
-   **Stworzenia glebowe:** poprawiają podłoże lub pomagają w
    kompostowaniu.

## 8.2. Przykładowe stworzenia --- nazwy robocze

-   **Pollenbug:** zapylacz.
-   **Mudhopper:** stworzenie poprawiające glebę.
-   **Glowmole:** podziemny organizm związany z minerałami.
-   **Fruitling:** mały owocożerca lub roznosiciel nasion.
-   **Shellback:** źródło materiałów do nawozów.
-   **Skywhale:** duże stworzenie wpływające na pogodę lub środowisko.

## 8.3. Interakcje

Przykładowy łańcuch: - kwiaty przyciągają zapylacze, - zapylacze
zwiększają plon, - owoce przyciągają roślinożerców, - roślinożercy
zostawiają nawóz, - drapieżniki ograniczają ich liczebność.

Gracz może projektować farmę tak, aby korzystać z tych zależności. Nie
musi ręcznie kontrolować każdego stworzenia.

## 8.4. Przyciąganie i hodowla

-   Odpowiednie rośliny mogą przyciągać konkretne stworzenia.
-   Możliwe oswajanie, karmienie i tworzenie siedlisk.
-   Później można dodać jaja, inkubatory i hodowlę rzadkich gatunków.
-   Zwierzęta powinny być czymś więcej niż źródłem surowców.

------------------------------------------------------------------------

# 9. Baza, placówki i budowanie

## 9.1. Główna baza

Stałe centrum rozwoju, przygotowań i przechowywania odkryć. Powinna być
miejscem, do którego gracz chętnie wraca i które wizualnie zmienia się
wraz z postępem.

Podstawowe obiekty: - pola uprawne, - magazyn, - laboratorium, -
warsztat, - stacja wody, - źródło energii, - miejsce przygotowania
ekspedycji.

Późniejsze budynki: - szklarnia, - centrum hodowli, - inkubator, -
laboratorium genetyczne, - centrum automatyzacji, - stacja pojazdów, -
wieża obserwacyjna, - biodom.

## 9.2. Placówki terenowe

-   Małe farmy lub punkty logistyczne w odległych biomach.
-   Tymczasowe szklarnie, zbiorniki, magazynki i stacje ładowania.
-   Możliwość pozostawienia roślin do wzrostu.
-   Placówki mogą ułatwiać kolejne wyprawy i zapewniać lokalny punkt
    zaopatrzenia.
-   Należy ograniczyć konieczność ciągłego odwiedzania każdej placówki.

## 9.3. Swobodne budowanie

-   Budynki i urządzenia powinny być rozmieszczane intuicyjnie.
-   Nie wszystko musi być stawiane na siatce.
-   Teren, nachylenie, dostęp do wody i światła mogą mieć znaczenie.
-   System powinien jasno pokazywać, dlaczego obiekt można lub nie można
    umieścić w danym miejscu.

------------------------------------------------------------------------

# 10. Technologie uprawy i biotechnologia

-   **Hydroponika:** uprawa bez gleby, kontrola wody i składników
    odżywczych.
-   **Aeroponika:** korzenie zasilane mgiełką, dobre rozwiązanie dla
    pionowych upraw.
-   **Aquaponika:** obieg wody łączący rośliny, ryby i mikroorganizmy.
-   **Vertical farming:** wieże, półki i ściany uprawne.
-   **Laboratorium genetyczne:** krzyżowanie, mutacje i tworzenie nowych
    odmian.
-   **Inkubatory:** rozwój jaj lub młodych organizmów.
-   **Kompostowniki:** przetwarzanie odpadów organicznych w nawóz.

Każda technologia powinna rozwiązywać konkretny problem lub otwierać
nowy styl prowadzenia farmy.

------------------------------------------------------------------------

# 11. Crafting i ekwipunek

## 11.1. Crafting

Kierunek inspirowany prostotą craftingu z *Minecrafta*, ale z własnymi
stanowiskami i recepturami.

Możliwy podział: - podstawowe receptury z ekwipunku, - prostsze
narzędzia przy stole warsztatowym, - budynki i urządzenia w
warsztacie, - pojazdy i moduły w warsztacie pojazdów, - nawozy,
analizatory i odmiany w laboratorium biologicznym.

Receptury mogą być odblokowywane przez: - skanowanie nowych
organizmów, - odkrywanie materiałów, - eksplorację ruin, - wykonywanie
celów ekspedycji, - eksperymenty w laboratorium.

## 11.2. Narzędzia

-   łopata,
-   kilof,
-   siekiera,
-   konewka,
-   siewnik,
-   opryskiwacz,
-   skaner roślin i zwierząt,
-   narzędzie do pobierania próbek,
-   narzędzie do naprawy urządzeń.

## 11.3. Wyposażenie i gadżety

-   plecak o większej pojemności,
-   kombinezon przystosowany do biomu,
-   hełm i moduły ochronne,
-   jetpack,
-   linka z hakiem,
-   mini dron,
-   przenośna stacja naprawcza,
-   latarnia,
-   moduły energetyczne.

## 11.4. Moduły plecaka

-   **Seed Storage:** więcej miejsca na nasiona.
-   **Hydro Pack:** dodatkowa woda do uprawy.
-   **Scanner Boost:** większy zasięg lub dokładność skanowania.
-   **Cargo Expansion:** większa pojemność.
-   **Energy Cell:** dodatkowa energia.
-   **Drone Dock:** możliwość zabrania drona.
-   **Magnetic Collector:** zbieranie pobliskich drobnych zasobów.

Ograniczona pojemność ekwipunku ma wymuszać decyzje: co zabrać, co
zostawić i kiedy wrócić.

------------------------------------------------------------------------

# 12. Pojazdy, drony i logistyka

## 12.1. Pojazdy ręczne

-   **Mini Rover:** eksploracja i transport gracza.
-   **Farm Tractor:** sadzenie i praca na farmie.
-   **Harvester:** zbieranie dojrzałych roślin.
-   **Miner:** wydobywanie minerałów.
-   **Cargo Truck:** przewóz dużych ilości zasobów.
-   **Hovercraft:** szybki transport przez trudny teren.

## 12.2. Autonomizacja

Wraz z postępem gracz może odblokować: - autopilota, - wyznaczanie
tras, - automatyczne zbiory, - transport między bazą a placówkami, -
powrót do stacji ładowania, - omijanie przeszkód, - proste zachowania
awaryjne.

## 12.3. Drony

-   zwiad nieznanego terenu,
-   skanowanie roślin i stworzeń,
-   dostarczanie drobnych przedmiotów,
-   obserwacja zagrożeń,
-   pomoc w zarządzaniu uprawami.

## 12.4. Logistyka

Możliwe elementy: - rury wodne i nawozowe, - taśmy transportowe, -
sortowniki, - sieci magazynów, - stacje ładowania, - automatyczne linie
przetwarzania.

Przykład: plantacja → harvester → transport → przetwórnia → magazyn.

Automatyzacja powinna być nagrodą za rozwój i umożliwiać większą skalę,
nie zaś obowiązkowym mikrozarządzaniem.

------------------------------------------------------------------------

# 13. Obrona i walka

## 13.1. Filozofia walki

Walka służy przetrwaniu i ochronie ekosystemu. Nie powinna zmienić gry w
typowego shootera. Często lepszym rozwiązaniem może być ucieczka,
odstraszenie, pułapka lub wykorzystanie roślin.

## 13.2. Obrona

-   rośliny obronne,
-   pułapki,
-   odstraszacze,
-   tymczasowe bariery,
-   wieżyczki,
-   mobilne punkty obrony podczas ekspedycji.

## 13.3. Przykładowe wieżyczki

-   **Bullet Turret:** podstawowa obrona.
-   **Acid Turret:** obrażenia obszarowe lub osłabienie.
-   **Frost Turret:** spowalnianie.
-   **Pollen Turret:** efekt biologiczny lub przyciąganie stworzeń.
-   **Tesla Tower:** obrona energetyczna.
-   **Seed Cannon:** amunicja oparta na właściwościach roślin.

## 13.4. Pojazdy specjalistyczne

Możliwe późniejsze warianty: - **Tank:** pojazd obronny. - **Seeder
Tank:** rozstawianie roślin i nasion. - **Harvest Tank:** zbieranie
roślin. - **Support Tank:** naprawy, osłony i wsparcie.

Pojazdy mogą być modułowe. Nie należy jednak rozwijać rozbudowanego
systemu walki, zanim podstawowy farming i ekspedycje będą
satysfakcjonujące.

------------------------------------------------------------------------

# 14. Zagrożenia, wydarzenia i zmiany środowiska

Przykładowe wydarzenia: - **Meteoryt:** niszczy część upraw, pozostawia
minerały i może wywołać mutacje. - **Inwazja owadów:** atakuje określone
rośliny; można ją ograniczać przez drapieżniki lub rośliny obronne. -
**Burza elektromagnetyczna:** zakłóca urządzenia i zmienia zachowanie
stworzeń. - **Migracja zwierząt:** może zniszczyć uprawy, ale pozostawić
nawóz lub inne zasoby. - **Cykl dnia i nocy:** część roślin kwitnie
nocą, a niektóre stworzenia pojawiają się tylko o określonych porach. -
**Anomalia biomu:** czasowo zmienia wzrost, grawitację, temperaturę lub
zachowanie organizmów. - **Ekstremalna pogoda:** burze piaskowe, opady
toksyczne, mróz lub fale gorąca.

## 14.1. Wpływ gracza na świat --- pomysł do rozważenia

Działalność gracza może zmieniać lokalny ekosystem: - nadmierne
wydobycie może zwiększać niestabilność terenu, - rozbudowa farmy może
przyciągać roślinożerców, - wprowadzenie obcego gatunku może zmienić
lokalną równowagę, - zniszczenie siedliska może spowodować migrację
stworzeń.

To potencjalnie ciekawy system, ale należy zacząć od prostych,
czytelnych konsekwencji.

------------------------------------------------------------------------

# 15. Baza danych i skanowanie

System odkryć może być ważną nagrodą za eksplorację.

Gracz skanuje: - rośliny, - nasiona, - zwierzęta, - minerały, -
anomalie, - ruiny, - urządzenia.

Wpis w bazie danych może zawierać: - nazwę i ilustrację, - biom
występowania, - preferowane warunki, - zastosowanie, - relacje z innymi
organizmami, - znane mutacje, - poziom kompletności odkrycia.

Nie wszystkie informacje muszą być znane od razu. Obserwacja i
eksperymentowanie mogą uzupełniać wpis.

------------------------------------------------------------------------

# 16. Audio i klimat

Kierunek do dalszego opracowania: - spokojna, przyjazna muzyka w
bazie, - bardziej niepokojące motywy podczas ekspedycji, -
charakterystyczne dźwięki biomów, - czytelne sygnały zagrożeń i zmian
pogody, - odgłosy roślin, stworzeń i urządzeń podkreślające życie
świata.

Kontrast między spokojem farmy a niepewnością ekspedycji może wzmacniać
rytm gry.

------------------------------------------------------------------------

# 17. MVP --- pierwszy grywalny prototyp

Nie budować od razu całej planety, automatyzacji i dziesiątek biomów.
Najpierw sprawdzić, czy podstawowa pętla jest przyjemna.

## 17.1. Zakres prototypu

-   jeden mały fragment zielonej doliny,
-   kamera TPP i podstawowe sterowanie,
-   mała baza,
-   sadzenie, wzrost i zbieranie kilku roślin,
-   5--8 gatunków roślin,
-   2--3 proste mutacje,
-   2--3 stworzenia o różnych rolach,
-   skaner i podstawowy crafting,
-   mała ekspedycja poza bazę,
-   jedno zagrożenie lub wydarzenie,
-   tymczasowe ulepszenie ekspedycyjne,
-   możliwość ewakuacji,
-   zachowanie odkrycia po powrocie,
-   prosty przykład odblokowania nowej zawartości na wyższym poziomie
    biomu.

## 17.2. Pytania, na które MVP ma odpowiedzieć

-   Czy sadzenie i obserwowanie wzrostu daje satysfakcję?
-   Czy eksploracja dostarcza ciekawych odkryć?
-   Czy gracz rozumie, po co wraca do bazy?
-   Czy decyzja o ewakuacji tworzy napięcie?
-   Czy rozwój farmy realnie pomaga w kolejnej wyprawie?
-   Czy wyższy poziom biomu daje interesujący powód do powrotu?

------------------------------------------------------------------------

# 18. Ryzyka projektowe i zalecenia

## 18.1. Zbyt szeroki zakres

Projekt łączy farming, survival, roguelite, automatyzację, budowanie,
pojazdy i ekosystem. To duże ryzyko produkcyjne. Należy rozwijać systemy
etapami.

## 18.2. Farming nie może być dekoracją

Rośliny muszą mieć konkretne zastosowania i wpływać na możliwości
gracza. Jeśli farming będzie tylko zbieraniem jedzenia, straci swoją
wyjątkowość.

## 18.3. Nie przesadzić z mikrozarządzaniem

Woda, światło, temperatura, nawozy, choroby, zapylanie i sąsiedztwo mogą
szybko stać się uciążliwe. Każdy parametr powinien wnosić ciekawą
decyzję.

## 18.4. Uważać na czas rzeczywisty

Rośliny mogą rosnąć podczas wypraw, ale gracz nie powinien być zmuszany
do czekania ani ciągłego powrotu do bazy. Należy zaprojektować tempo
wzrostu i ewentualne przyspieszenia.

## 18.5. Automatyzacja ma pomagać

Autonomiczne pojazdy i placówki nie mogą wymagać ciągłego naprawiania i
nadzorowania. Ich obsługa powinna być prostsza niż praca ręczna, którą
zastępują.

## 18.6. Trudność ma odkrywać zawartość

Nie opierać progresji biomu wyłącznie na skalowaniu statystyk. Każdy
poziom powinien oferować nowe sytuacje, gatunki, lokacje lub systemy.

## 18.7. Czytelność przede wszystkim

Gracz powinien rozumieć: - dlaczego roślina nie rośnie, - dlaczego
stworzenie przybyło, - co powoduje zagrożenie, - jakie korzyści daje
dana technologia, - co zyska po wyprawie na wyższy poziom.

------------------------------------------------------------------------

# 19. Otwarte decyzje projektowe

Poniższe kwestie nie są jeszcze rozstrzygnięte. AI wspierające projekt
powinno pomagać je analizować, przedstawiać zalety i wady oraz
proponować małe eksperymenty.

1.  Czy ekspedycje mają limit czasu, narastające zagrożenie, czy oba
    systemy?
2.  Co dokładnie zwiększa poziom zagrożenia biomu?
3.  Czy gracz może wybrać poziom trudności biomu ręcznie, czy
    odblokowuje go stopniowo?
4.  Jakie zasoby zachowuje po nieudanej ekspedycji?
5.  Jak duża część planety jest dostępna bezpośrednio, a jak duża przez
    osobne obszary wypraw?
6.  Czy placówki terenowe pozostają aktywne między ekspedycjami?
7.  Jak rozwiązać wzrost roślin podczas nieobecności gracza?
8.  Jak duży nacisk położyć na walkę i broń?
9.  Czy pojazdy bojowe będą istotnym systemem, czy tylko opcjonalną
    późną technologią?
10. Jakie są granice swobodnego budowania?
11. Jak gracz pozyskuje wodę i energię w różnych biomach?
12. Jakie konsekwencje ma ingerencja w ekosystem?
13. Czy gra ma mieć zakończenie fabularne, czy głównym celem jest dalszy
    rozwój i odkrywanie?

------------------------------------------------------------------------

# 20. Wytyczne dla AI wspierającego planowanie projektu

AI powinno traktować ten dokument jako bazę koncepcji, a nie sztywną
specyfikację techniczną.

## Rola AI

-   Pomagać rozwijać koncepcję i przekładać ją na wykonalny plan.
-   Krytycznie oceniać pomysły, a nie bezwarunkowo je aprobować.
-   Wskazywać ryzyka, koszty produkcyjne i zależności między systemami.
-   Proponować prostsze rozwiązania, jeśli dają podobny efekt.
-   Dbać o spójność z głównymi filarami gry.
-   Rozdzielać ustalone decyzje, propozycje i otwarte pytania.
-   Nie dopisywać nowych dużych systemów bez sprawdzenia, czy są
    potrzebne.
-   Preferować małe prototypy, testy i iteracje zamiast projektowania
    całej gry naraz.

## Sposób oceniania nowych pomysłów

Przy każdym większym pomyśle AI powinno krótko ocenić: 1. Jak wzmacnia
główną fantazję gry? 2. Jak wpływa na farming, eksplorację lub
ekosystem? 3. Czy tworzy interesujące decyzje dla gracza? 4. Jakie inne
systemy są od niego zależne? 5. Jaki jest koszt i ryzyko implementacji?
6. Czy można przetestować go w małym prototypie? 7. Czy istnieje
prostsza alternatywa?

## Priorytety

1.  Najpierw sprawić, by farming i eksploracja były przyjemne.
2.  Następnie połączyć je w satysfakcjonującą pętlę ekspedycji i rozwoju
    bazy.
3.  Potem rozwijać różnorodność biomów, odkrycia i ekosystem.
4.  Dopiero później dodawać rozbudowaną automatyzację, flotę pojazdów i
    zaawansowaną obronę.

**Najważniejsze:** nie pozwolić, aby gra stała się zbiorem niezależnych
mechanik. Każdy system powinien wspierać eksplorację, farming lub rozwój
ekosystemu --- najlepiej więcej niż jeden z tych filarów.
