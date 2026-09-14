extends Node

const UI_FONT: Font = preload("res://assets/fonts/NotoSansHans-Regular.otf")


func _enter_tree() -> void:
	ThemeDB.fallback_font = UI_FONT
