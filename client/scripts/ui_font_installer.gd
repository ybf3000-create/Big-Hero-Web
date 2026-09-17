extends Node

const UI_FONT: Font = preload("res://assets/fonts/NotoSansHans-Regular.otf")
const SYMBOL_FONT: Font = preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
const EMOJI_FONT: Font = preload("res://assets/fonts/NotoEmoji-VariableFont.ttf")
var _ui_font: Font


func _enter_tree() -> void:
	_ui_font = UI_FONT.duplicate()
	_ui_font.fallbacks = [SYMBOL_FONT, EMOJI_FONT]
	ThemeDB.fallback_font = _ui_font
