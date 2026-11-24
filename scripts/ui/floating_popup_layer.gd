class_name FloatingPopupLayer
extends Control
## Projects 3D world positions onto 2D screen space to animate floating damage & status popups.

@export var camera: Camera3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func spawn_popup(world_pos: Vector3, text: String, color: Color) -> void:
	if camera == null:
		return
	if camera.is_position_behind(world_pos):
		return

	var screen_pos := camera.unproject_position(world_pos)
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = screen_pos - Vector2(45.0, 12.0)
	add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 56.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)
