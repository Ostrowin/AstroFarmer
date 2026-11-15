class_name DroneDock
extends StaticBody3D
## Dok drona nawadniającego (z warsztatu, stawiany na polu siatki jak słupek).
## Dron startuje z doku, podlewa spragnione rośliny w zasięgu i tankuje w stawie.
## E na doku zabiera go z powrotem do magazynu (dron znika razem z nim).

const MODEL := preload("res://art/models/machines/drone_dock.glb")
## Wysokość, na której dron siedzi na doku (płozy na lądowisku).
const LANDING_HEIGHT := 0.6

var drone: WateringDrone


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 0.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.1
	add_child(collision)
	add_child(MODEL.instantiate())


## Miejsce lądowania drona (globalnie).
func landing_point() -> Vector3:
	return global_position + Vector3(0, LANDING_HEIGHT, 0)


func get_status() -> String:
	if drone == null:
		return "Drone dock"
	return "Watering drone · %s · water %d/%d" % [drone.state_text(), drone.water, WateringDrone.TANK]
