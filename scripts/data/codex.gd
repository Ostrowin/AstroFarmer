class_name Codex
extends RefCounted
## Baza danych: wpisy o roślinach, stworzeniach i minerałach.
## Każdy wpis ma kilka faktów, odkrywanych różnymi akcjami ("how"):
##   scan (skaner Q), grow (wyhodowane w bazie), harvest (zbiór w bazie),
##   eat, hit (trafienie z pistoletu), trap, boom, pickup, craft, repel (obrona w najeździe),
##   raid (przetrwany najazd), sprout (obudzenie Mgielnika).
## Czysta logika: funkcje dostają słownik research z GameState
## (id -> Array nazw "how"), żeby dało się je testować bez autoloadów.

## Ile wpisów poziomu 1 trzeba odkryć, żeby odblokować poziom 2 doliny.
const LEVEL2_REQUIRED := 6

const CATEGORIES := ["Rośliny", "Stworzenia", "Minerały i próbki"]

const ENTRIES := {
	&"voidberry": {"name": "Voidberry", "category": "Rośliny", "level": 1, "facts": [
		{"how": "scan", "text": "Krzew o fioletowych owocach, rośnie dziko na łące.", "hint": "zeskanuj dziki krzew (Q)"},
		{"how": "harvest", "text": "W bazie daje 2-3 owoce i 1-2 nasiona na zbiór.", "hint": "zbierz dojrzałą roślinę w bazie"},
		{"how": "eat", "text": "Owoc leczy Kondycję: dziki 25, z plecaka 30. Kuchnia robi z niego dania.", "hint": "zjedz owoc na wyprawie"},
	]},
	&"crystal_bloom": {"name": "Crystal Bloom", "category": "Rośliny", "level": 1, "facts": [
		{"how": "scan", "text": "Kwiat, który wyciąga minerały z gleby i zamyka je w kryształach.", "hint": "zeskanuj nasiona na wyprawie"},
		{"how": "grow", "text": "Nie potrzebuje wody, ale każdy etap trwa 2 cykle.", "hint": "wyhoduj go w bazie"},
		{"how": "harvest", "text": "Daje kryształy, surowiec warsztatu. Planeta ich pilnuje (+1 Uwagi za wywieziony kryształ).", "hint": "zbierz go w bazie"},
	]},
	&"snapper": {"name": "Snapper", "category": "Rośliny", "level": 1, "facts": [
		{"how": "scan", "text": "Mięsożerna paszcza. Hodowany na nasiona.", "hint": "zeskanuj nasiona na wyprawie"},
		{"how": "trap", "text": "Rzucone nasiono wyrasta w 1.5 s i trzyma drapieżnika 4 s.", "hint": "złap coś rzuconym Snapperem"},
		{"how": "repel", "text": "Dojrzały w bazie łapie 2 Chrupiki w promieniu 3 m.", "hint": "obroń nim farmę w najeździe"},
	]},
	&"boomshroom": {"name": "Boomshroom", "category": "Rośliny", "level": 1, "facts": [
		{"how": "scan", "text": "Grzyb, który wybucha chmurą zarodników.", "hint": "zeskanuj nasiona na wyprawie"},
		{"how": "boom", "text": "Rzucony robi puff i ogłusza wszystko w 4 m. Odrzuca też ciebie.", "hint": "ogłusz coś rzuconym Boomshroomem"},
		{"how": "repel", "text": "Dojrzały w bazie odrzuca 3 Chrupiki w promieniu 4.5 m.", "hint": "obroń nim farmę w najeździe"},
	]},
	&"pollenbug": {"name": "Pyłkowiec", "category": "Stworzenia", "level": 1, "facts": [
		{"how": "scan", "text": "Latający zapylacz. Krąży przy dzikich krzewach i ucieka, gdy podejdziesz.", "hint": "zeskanuj go w locie"},
		{"how": "hit", "text": "Trafiony spada i gubi kulkę pyłku. Zabity też ją zostawia, ale wtedy już nie zapyla.", "hint": "trafić go z pistoletu"},
		{"how": "pickup", "text": "Pyłek to składnik Pyłkowych ciastek w kuchni.", "hint": "podnieś pyłek"},
	]},
	&"chrupik": {"name": "Chrupik", "category": "Stworzenia", "level": 1, "facts": [
		{"how": "scan", "text": "Płochliwy roślinożerca. Stadko objada dzikie krzewy, gdy łąka się budzi.", "hint": "zeskanuj stadko"},
		{"how": "hit", "text": "Chrupiki nie atakują ludzi: trafiony ucieka w panice, zabity zostawia nawóz.", "hint": "trafić go z pistoletu"},
		{"how": "raid", "text": "To one najeżdżają farmę, gdy Niepokój fauny dojdzie do 100%.", "hint": "przetrwaj najazd w bazie"},
	]},
	&"thornback": {"name": "Thornback", "category": "Stworzenia", "level": 1, "facts": [
		{"how": "scan", "text": "Drapieżnik z kolcami. Śpi w legowisku na północy łąki.", "hint": "zeskanuj go z bezpiecznej odległości"},
		{"how": "hit", "text": "Postrzelony budzi się i rzuca na ciebie. Ranny ucieka, zabity zostawia kolce (warsztat: Pistolet Mk2).", "hint": "trafić go z pistoletu"},
		{"how": "trap", "text": "Snapper trzyma go 4 s. Przy Przebudzeniu 100 poluje na ciebie wszędzie.", "hint": "złap go Snapperem"},
	]},
	&"glowmoss": {"name": "Lśniący mech", "category": "Minerały i próbki", "level": 1, "facts": [
		{"how": "scan", "text": "Świecący mech z najtrudniej dostępnych miejsc łąki.", "hint": "zeskanuj go na wyprawie"},
		{"how": "pickup", "text": "Zerwanie go budzi planetę: Przebudzenie +12.", "hint": "podnieś próbkę"},
		{"how": "craft", "text": "Wywieziony: +10 Uwagi planety. Potrzebny do ulepszeń w warsztacie.", "hint": "zużyj go w warsztacie"},
	]},
	&"crystal_vein": {"name": "Żyła kryształów", "category": "Minerały i próbki", "level": 1, "facts": [
		{"how": "scan", "text": "Kryształy wyrastające wprost z gruntu łąki.", "hint": "zeskanuj je na wyprawie"},
		{"how": "pickup", "text": "Lekkie: każdy kryształ to 1 miejsce w plecaku.", "hint": "podnieś kryształ"},
		{"how": "craft", "text": "Z 2 kryształów warsztat robi 3 słupki płotu.", "hint": "zrób coś w warsztacie"},
	]},
	&"misty_spring": {"name": "Mgliste źródło", "category": "Minerały i próbki", "level": 2, "facts": [
		{"how": "scan", "text": "Źródło zimnej, świecącej wody. Bije tylko na poziomie 2 łąki.", "hint": "znajdź je na poziomie 2"},
		{"how": "pickup", "text": "Wodę nosi się w plecaku: 1 porcja = 1 miejsce.", "hint": "nabierz wody (E)"},
		{"how": "sprout", "text": "Tylko ta woda budzi nasiono Mgielnika.", "hint": "podlej nią Mgielnika w bazie"},
	]},
	&"mistbloom": {"name": "Mgielnik", "category": "Rośliny", "level": 2, "facts": [
		{"how": "scan", "text": "Nasiono w twardej łupinie. Zwykła woda go nie budzi.", "hint": "zeskanuj nasiono na poziomie 2"},
		{"how": "grow", "text": "Obudzony rośnie zwyczajnie i świeci w mgle.", "hint": "wyhoduj go w bazie"},
		{"how": "harvest", "text": "Mgielny owoc: z niego kuchnia robi Mgielny napar.", "hint": "zbierz go w bazie"},
	]},
}

## Jaki wpis odkrywa użycie przedmiotu w warsztacie.
const CRAFT_SOURCES := {
	&"crystal": &"crystal_vein",
	&"sample_glowmoss": &"glowmoss",
}

## Stare nazwy akcji z wcześniejszych zapisów -> nowe.
const RENAMED_HOWS := {"stun": "hit"}


static func has_entry(id: StringName) -> bool:
	return ENTRIES.has(id)


static func entry_name(id: StringName) -> String:
	return ENTRIES[id]["name"] if ENTRIES.has(id) else String(id)


## Fakt dla danej akcji albo pusty słownik.
static func fact(id: StringName, how: String) -> Dictionary:
	if not ENTRIES.has(id):
		return {}
	for item: Dictionary in ENTRIES[id]["facts"]:
		if item["how"] == how:
			return item
	return {}


static func known_count(research: Dictionary, id: StringName) -> int:
	return (research.get(id, []) as Array).size()


static func fact_count(id: StringName) -> int:
	return (ENTRIES[id]["facts"] as Array).size()


## Ile wpisów danego poziomu ma choć jeden fakt.
static func discovered_count(research: Dictionary, level: int) -> int:
	var count := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) == level and known_count(research, id) > 0:
			count += 1
	return count


static func entry_count(level: int) -> int:
	var count := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) == level:
			count += 1
	return count


## Kompletność bazy danych w procentach (fakty ze wszystkich wpisów do danego poziomu).
static func completion(research: Dictionary, max_level := 2) -> int:
	var known := 0
	var total := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) > max_level:
			continue
		known += known_count(research, id)
		total += fact_count(id)
	return roundi(100.0 * known / maxf(1.0, total))
