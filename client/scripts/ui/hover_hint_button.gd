class_name HoverHintButton
extends Button

const TOOLTIP_WIDTH := 300.0


func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color("fffaf6f2")
	background.border_color = Color("b88d89")
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 9
	background.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", background)

	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 24, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("352e38"))
	panel.add_child(label)
	return panel
