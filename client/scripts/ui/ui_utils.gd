class_name UIUtils

const EquipData = preload("res://scripts/equip_data.gd")

const SUIT_COLORS := {
	"♠": Color(0.75, 0.78, 0.82),
	"♣": Color(0.75, 0.78, 0.82),
	"♥": Color(1.0, 0.15, 0.15),
	"♦": Color(1.0, 0.15, 0.15),
}


static func qcolor(q: int) -> Color:
	return EquipData.QUALITY_COLORS.get(q, Color.GRAY)


static func suit_color(s: String) -> Color:
	return SUIT_COLORS.get(s, Color(0.8, 0.8, 0.8))


## Return a display-safe label for data that may contain emoji icons.
## Godot Web renders Canvas text with the bundled CJK font; unknown emoji
## glyphs must never be allowed to replace otherwise readable Chinese text.
static func plain_text(value: String, fallback: String = "") -> String:
	var result := ""
	for i in range(value.length()):
		var codepoint := value.unicode_at(i)
		if _is_ignored_symbol(codepoint):
			continue
		if (codepoint >= 0x20 and codepoint <= 0x7E) or _is_cjk(codepoint) \
			or (codepoint >= 0x3000 and codepoint <= 0x303F) \
			or (codepoint >= 0xFF00 and codepoint <= 0xFFEF):
			result += value.substr(i, 1)
	return result.strip_edges() if not result.strip_edges().is_empty() else fallback


## Icons are decorative only. Keep them as a short Chinese/ASCII marker so a
## missing emoji font can never produce a tofu square in the UI.
static func safe_icon(value: String, fallback: String = "图") -> String:
	var safe := plain_text(value, "")
	if safe.is_empty():
		return fallback
	return safe.substr(0, 2)


static func _is_cjk(codepoint: int) -> bool:
	return (codepoint >= 0x3400 and codepoint <= 0x4DBF) \
		or (codepoint >= 0x4E00 and codepoint <= 0x9FFF) \
		or (codepoint >= 0xF900 and codepoint <= 0xFAFF)


static func _is_ignored_symbol(codepoint: int) -> bool:
	# Variation selectors, zero-width joiners and emoji/symbol blocks.
	return codepoint == 0x200D \
		or (codepoint >= 0xFE00 and codepoint <= 0xFE0F) \
		or (codepoint >= 0x1F000 and codepoint <= 0x1FAFF) \
		or (codepoint >= 0x2300 and codepoint <= 0x23FF) \
		or (codepoint >= 0x2600 and codepoint <= 0x27BF)


static func panel_style(node: Panel, clr: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = clr
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.35, 0.45, 0.6)
	node.add_theme_stylebox_override("panel", sb)


static func shrine_panel_style(node: Panel, bg: Color, border: Color, width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = width; style.border_width_right = width
	style.border_width_top = width; style.border_width_bottom = width
	style.border_color = border
	style.set_corner_radius_all(3)
	node.add_theme_stylebox_override("panel", style)


static func bar_style(node: ProgressBar, clr: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = clr.darkened(0.3)
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.35, 0.35, 0.45)
	node.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = clr
	node.add_theme_stylebox_override("fill", fill)


static func bar_style_light(node: ProgressBar, fill_color: Color, bg_color: Color, border: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = border
	node.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	node.add_theme_stylebox_override("fill", fill)


static func btn_style_mini(btn: Button, clr: Color) -> void:
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = clr
	n.border_width_left = 1; n.border_width_right = 1
	n.border_width_top = 1; n.border_width_bottom = 1
	n.border_color = clr.lightened(0.3)
	n.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	h.bg_color = clr.lightened(0.12)
	btn.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	p.bg_color = clr.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", p)
	var d: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	d.bg_color = Color("eadfdd")
	d.border_color = Color("c9b7b4")
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color("4f454d"))
	btn.add_theme_color_override("font_pressed_color", Color("352e38"))
	btn.add_theme_color_override("font_hover_pressed_color", Color("352e38"))
	btn.add_theme_color_override("font_focus_color", Color("4f454d"))
	btn.add_theme_color_override("font_disabled_color", Color("7d7072"))
	btn.flat = false


static func btn_transparent2(btn: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0)
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.06)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)


static func btn_style(btn: Button, clr: Color) -> void:
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = clr
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.border_color = Color(0.5, 0.5, 0.6, 0.7)
	n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	h.bg_color = clr.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	p.bg_color = clr.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color("352e38"))
	btn.add_theme_color_override("font_hover_color", Color("4f454d"))
	btn.add_theme_color_override("font_pressed_color", Color("352e38"))
	btn.add_theme_color_override("font_focus_color", Color("4f454d"))


static func set_button_text_color(btn: Button, color: Color) -> void:
	# Godot falls back to the project theme for any omitted interaction state.
	# Keep focused/pressed text readable on the light web UI as well.
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, color)


static func shrine_button_style(btn: Button, primary: bool = false) -> void:
	var base := Color("c94a55") if primary else Color("f4e8e7")
	var ink := Color("352e38")
	var border := Color("96353e") if primary else Color("b88d89")
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = border
	normal.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lightened(0.10)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base.darkened(0.10)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", ink)
	btn.add_theme_color_override("font_hover_color", ink)
	btn.add_theme_color_override("font_pressed_color", Color("5f5557") if not primary else ink)
	btn.add_theme_color_override("font_hover_pressed_color", Color("5f5557") if not primary else ink)
	btn.add_theme_color_override("font_focus_color", Color("5f5557") if not primary else ink)
