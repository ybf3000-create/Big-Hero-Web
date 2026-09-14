class_name GridTile
extends Control
## 平行四边形地块 — 上边靠右、等大拼接、2D 立体透视
## 图标+名称在平行四边形内左下角

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

const SHEAR: float = 45.0       # 水平偏移
const BORDER_W: float = 2.0


func _ready() -> void:
	_icon_label = Label.new()
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 21)
	add_child(_icon_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", Color("352e38"))
	add_child(_name_label)

	_resize_labels()


func setup(icon: String, gname: String, fill: Color, border: Color) -> void:
	icon_text = icon
	name_text = gname
	fill_color = fill
	border_color = border
	if _icon_label:
		_icon_label.text = icon
	if _name_label:
		_name_label.text = gname
	queue_redraw()


func _draw() -> void:
	var w := size.x - SHEAR         # 上下边水平宽度
	var s := SHEAR
	var h := size.y

	# 上边靠右：(s,0)→(w+s,0)，下边靠左：(0,h)→(w,h)
	var points := PackedVector2Array([
		Vector2(s, 0),              # 左上
		Vector2(w + s, 0),          # 右上
		Vector2(w, h),              # 右下
		Vector2(0, h),              # 左下
	])

	draw_colored_polygon(points, fill_color)
	# 和纸格子的浅色顶沿，让相邻地块保持清晰但不过度厚重。
	draw_line(points[0], points[1], Color(1, 1, 1, 0.58), 2.0, true)
	var border := border_color
	border.a = 0.92
	draw_polyline(points, border, BORDER_W, true)


func set_label_positions(_x: float, _y: float) -> void:
	_resize_labels()


func _resize_labels() -> void:
	# 标签在平行四边形内左下角
	var h := size.y
	if _icon_label:
		_icon_label.position = Vector2(SHEAR + 6 - 35, h - 26)
		_icon_label.size = Vector2(28, 22)
	if _name_label:
		_name_label.position = Vector2(SHEAR + 36 - 35, h - 26)
		_name_label.size = Vector2(size.x - SHEAR - 42, 22)
