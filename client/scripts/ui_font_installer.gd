extends Node

const UI_FONT: Font = preload("res://assets/fonts/NotoSansHans-Regular.otf")
const SYMBOL_FONT: Font = preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
const EMOJI_FONT: Font = preload("res://assets/fonts/NotoEmoji-VariableFont.ttf")
var _ui_font: Font


func _enter_tree() -> void:
	_ui_font = UI_FONT.duplicate()
	# Emoji first: the symbols font intentionally covers only monochrome symbols
	# and can otherwise win fallback selection with a tofu glyph for emoji codepoints.
	_ui_font.fallbacks = [EMOJI_FONT, SYMBOL_FONT]
	ThemeDB.fallback_font = _ui_font
