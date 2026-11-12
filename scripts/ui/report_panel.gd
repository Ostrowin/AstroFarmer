class_name ReportPanel
extends UiPanel
## Raport po powrocie z wyprawy (albo po przeczekaniu cyklu):
## sekcje z tytułem i liniami, np. Wyprawa / Farma / Najazd / Planeta.

const SECTION_COLORS := {
	"good": Color(0.6, 1.0, 0.6),
	"bad": Color(1.0, 0.6, 0.55),
	"info": Color(0.8, 0.95, 1.0),
	"raid": Color(1.0, 0.8, 0.45),
}


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


## sections: [{"title": String, "lines": Array[String], "tone": "good"/"bad"/"info"/"raid"}]
func show_report(title: String, sections: Array) -> void:
	clear()
	_box.add_child(label(title, 28))
	for section: Dictionary in sections:
		var lines: Array = section.get("lines", [])
		if lines.is_empty():
			continue
		var color: Color = SECTION_COLORS.get(section.get("tone", "info"), Color.WHITE)
		_box.add_child(label(section.get("title", ""), 20, 0.0, color))
		for line in lines:
			_box.add_child(label("· " + String(line), 16, 640))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Dalej [E]", close))
	_box.add_child(buttons)
	open_panel(720, 0)
	# Wysokość dopasuje się do treści: panel rośnie w dół od środka, więc wyśrodkuj po klatce.
	_center.call_deferred()


func _center() -> void:
	var height := get_combined_minimum_size().y
	offset_top = -height * 0.5
	offset_bottom = height * 0.5
