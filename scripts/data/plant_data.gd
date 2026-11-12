class_name PlantData
extends Resource
## Opis gatunku rośliny. Każdy gatunek to plik .tres w data/plants/.

## Kształt modelu budowanego w kodzie (prototyp bez assetów).
enum Shape { BUSH, CRYSTAL, SNAPPER, MUSHROOM, MIST }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Biom, w którym gatunek jest rodzimy (ważne dla Równowagi w M4).
@export var base_biome: StringName = &"zielona_dolina"
@export var shape: Shape = Shape.BUSH

@export_group("Wzrost")
## Liczba etapów; ostatni etap = dojrzała, gotowa do zbioru.
@export_range(2, 6) var stages: int = 3
## Ile cykli trwa jeden etap.
@export_range(1, 5) var cycles_per_stage: int = 1
## Czy roślina musi być podlana w cyklu, żeby urosnąć.
@export var needs_water: bool = true
## Minimalna odległość od innych roślin przy sadzeniu (metry).
@export var min_spacing: float = 1.0
## Nasiono-zagadka: kiełkuje (etap 0 -> 1) tylko po podlaniu tym zasobem
## zamiast zwykłej wody (np. &"water_misty"). Puste = zwykła woda.
@export var sprout_item: StringName

@export_group("Zbiór")
## Id przedmiotu z plonu; puste = roślina daje tylko nasiona.
@export var harvest_item: StringName
@export var harvest_item_name: String
@export var harvest_amount: Vector2i = Vector2i(1, 2)
@export var seeds_per_harvest: Vector2i = Vector2i(1, 2)
## Roślina-narzędzie (obrona bazy / wyprawa), np. Snapper.
@export var is_tool: bool = false

@export_group("Wygląd")
@export var leaf_color: Color = Color(0.35, 0.75, 0.35)
@export var accent_color: Color = Color(0.6, 0.3, 0.9)


func seed_item() -> StringName:
	return StringName("seed_%s" % id)


func last_stage() -> int:
	return stages - 1
