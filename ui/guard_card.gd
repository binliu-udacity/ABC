extends Button

# 方形守兵卡：阴影的高度就是剩余冷却比例。
var kind := ""
var price := 0
var shade: ColorRect
var selection_ring: Panel

func _ready() -> void:
	clip_contents = true
	var base := StyleBoxFlat.new()
	base.bg_color = Color("f2ead8")
	base.border_color = Color("bfad8a")
	base.set_border_width_all(1)
	base.set_corner_radius_all(8)
	add_theme_stylebox_override("normal", base)
	var hover_style := base.duplicate()
	hover_style.bg_color = Color("e7dbc0")
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", hover_style)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("aa583c")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(8)
	add_theme_stylebox_override("focus", focus_style)
	var glyph := Label.new()
	glyph.text = kind
	glyph.position = Vector2(0, size.y * 0.1)
	glyph.size = Vector2(size.x, size.y * 0.47)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", roundi(size.x * 0.35))
	glyph.add_theme_color_override("font_color", Color("278047"))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glyph)
	var cost := Label.new()
	cost.text = "%d 墨滴" % price
	cost.position = Vector2(0, size.y * 0.65)
	cost.size = Vector2(size.x, size.y * 0.28)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", maxi(13, roundi(size.x * 0.14)))
	cost.add_theme_color_override("font_color", Color("263c43"))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost)
	shade = ColorRect.new()
	shade.color = Color(0.08, 0.13, 0.12, 0.52)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	selection_ring = Panel.new()
	selection_ring.size = size
	selection_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_style := focus_style.duplicate()
	selected_style.set_border_width_all(3)
	selection_ring.add_theme_stylebox_override("panel", selected_style)
	add_child(selection_ring)

func update_state(remaining: float, total: float, affordable: bool, is_selected: bool) -> void:
	var ratio := clampf(remaining / total, 0.0, 1.0) if total > 0.0 else 0.0
	if not affordable:
		ratio = 1.0
	var inside := size - Vector2(4, 4)
	shade.size = Vector2(inside.x, inside.y * ratio)
	shade.position = Vector2(2, 2 + inside.y * (1.0 - ratio))
	shade.visible = ratio > 0.0
	selection_ring.visible = is_selected
