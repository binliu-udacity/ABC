extends Control

const Battle = preload("res://levels/battle.gd")
const GuardData = preload("res://player/guard_data.gd")
const FONT = preload("res://assets/fonts/noto_sans_sc_medium.tres")
const ORIGIN := Vector2(70, 128)
const CELL := Vector2(96, 56)
const BOARD := Rect2(ORIGIN, Vector2(480, 616))
const INK_COLOR := Color("263c43")
const MUTED := Color("6c7777")
const ACCENT := Color("aa583c")
const GUARD_COLORS: Dictionary = {
	"砚": Color("476d63"), "弓": Color("386779"), "盾": Color("807353"),
	"冰": Color("4894b2"), "雷": Color("946238"),
}
const DESCRIPTIONS: Dictionary = {
	"砚": "每 30 秒产出 50 墨滴 · 生命 60",
	"弓": "每秒一箭，伤害 30 · 生命 80",
	"盾": "挡住敌人 · 生命 1200 · 跳会穿过",
	"冰": "每秒一箭，伤害 30 · 减速 50%，持续 10 秒",
	"雷": "准备 15 秒，接触引爆 · 本格伤害 1800 · 生命 60",
}

var battle = Battle.new()
var selected := "弓"
var paused := false
var accumulator := 0.0
var hover := Vector2i(-1, -1)
var cards: Dictionary = {}
var ink_label: Label
var wave_label: Label
var status_label: Label
var message_label: Label
var selection_label: Label
var begin_button: Button
var pause_button: Button
var result_panel: Panel
var result_title: Label
var result_text: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var game_theme := Theme.new()
	game_theme.default_font = FONT
	game_theme.default_font_size = 18
	theme = game_theme
	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	_label("诗词塔防：守卷之役", Vector2(64, 28), Vector2(750, 45), 32)
	_label("十波守卷  /  父子共创第一版", Vector2(66, 78), Vector2(500, 30), 16, MUTED)
	wave_label = _label("", Vector2(640, 30), Vector2(480, 42), 24)
	ink_label = _label("", Vector2(640, 85), Vector2(480, 42), 30)
	status_label = _label("", Vector2(640, 132), Vector2(480, 48), 17, MUTED)
	_label("选择守兵", Vector2(640, 190), Vector2(480, 30), 20)
	var card_y := 230.0
	for kind in GuardData.UNITS:
		var button := _button("", Vector2(640, card_y), Vector2(490, 62))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = DESCRIPTIONS[kind]
		button.pressed.connect(_select.bind(str(kind)))
		cards[kind] = button
		card_y += 72.0
	selection_label = _label("", Vector2(640, 597), Vector2(490, 65), 17)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	begin_button = _button("开始守卷", Vector2(640, 680), Vector2(230, 50))
	begin_button.pressed.connect(_begin)
	pause_button = _button("暂停", Vector2(890, 680), Vector2(240, 50))
	pause_button.pressed.connect(_toggle_pause)
	var restart := _button("重新开始", Vector2(640, 744), Vector2(230, 44))
	restart.pressed.connect(_restart)
	var cancel := _button("取消选择", Vector2(890, 744), Vector2(240, 44))
	cancel.pressed.connect(_select.bind(""))
	message_label = _label("", Vector2(64, 800), Vector2(1070, 40), 17, ACCENT)
	_label("诗卷底线 · 漏过一个敌人就失败", Vector2(70, 752), Vector2(480, 30), 17, ACCENT)
	result_panel = Panel.new()
	result_panel.position = Vector2(270, 270)
	result_panel.size = Vector2(660, 260)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("f9f2df")
	panel_style.border_color = ACCENT
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	result_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(result_panel)
	result_title = _label("", Vector2(310, 295), Vector2(580, 55), 32)
	result_text = _label("", Vector2(310, 365), Vector2(580, 70), 20)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var again := _button("再守一次", Vector2(460, 455), Vector2(280, 50))
	again.pressed.connect(_restart)
	# 结算内容一起显隐，放进面板并保留相对位置。
	for node in [result_title, result_text, again]:
		var relative: Vector2 = node.position - result_panel.position
		node.reparent(result_panel)
		node.position = relative
	result_panel.hide()

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color = INK_COLOR) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK_COLOR)
	button.add_theme_color_override("font_hover_color", INK_COLOR)
	button.add_theme_color_override("font_pressed_color", INK_COLOR)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f2ead8") if state != "hover" else Color("e7dbc0")
		style.border_color = Color("bfad8a") if state != "pressed" else ACCENT
		style.set_border_width_all(1 if state != "focus" else 2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 16
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	add_child(button)
	return button

func _select(kind: String) -> void:
	selected = kind
	_refresh_ui()

func _begin() -> void:
	battle.start()
	_refresh_ui()

func _toggle_pause() -> void:
	if battle.phase in ["prep", "combat"]:
		paused = not paused
		_refresh_ui()

func _restart() -> void:
	battle = Battle.new()
	paused = false
	accumulator = 0.0
	selected = "弓"
	_refresh_ui()

func _process(delta: float) -> void:
	if not paused:
		accumulator += minf(delta, 0.25)
		while accumulator >= 0.05:
			battle.step(0.05)
			accumulator -= 0.05
	var pointer := get_local_mouse_position()
	hover = Vector2i(floori((pointer.x - ORIGIN.x) / CELL.x), floori((pointer.y - ORIGIN.y) / CELL.y))
	_refresh_ui()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_select("")
		elif event.keycode == KEY_P:
			_toggle_pause()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_select("")
		elif event.button_index == MOUSE_BUTTON_LEFT and BOARD.has_point(get_local_mouse_position()):
			if not paused and not selected.is_empty():
				# 点击位置立即计算，不能使用上一帧的悬停位置。
				var pointer := get_local_mouse_position()
				var column := floori((pointer.x - ORIGIN.x) / CELL.x)
				var row := floori((pointer.y - ORIGIN.y) / CELL.y)
				battle.place(selected, column, row)
				_refresh_ui()

func _refresh_ui() -> void:
	ink_label.text = "墨滴  %d" % battle.ink
	wave_label.text = "第 %d / 10 波   ·   击败 %d" % [battle.wave, battle.kills]
	var state := "布阵后点击开始"
	if battle.phase == "prep":
		state = "下一波准备：%d 秒" % ceili(battle.prep_left)
	elif battle.phase == "combat":
		state = "战斗中 · 场上 %d 个敌人" % battle.enemies.size()
	if paused:
		state = "已暂停 · 点击继续按钮恢复"
	status_label.text = "%s\n每 10 秒 +50 墨滴 · 下次 %d 秒" % [state, ceili(10.0 - battle.ink_clock)]
	message_label.text = battle.feedback
	for kind in cards:
		var data: Dictionary = GuardData.UNITS[kind]
		var cooldown: float = battle.cooldowns[kind]
		var suffix := ""
		if cooldown > 0.0:
			suffix = " · 冷却 %ds" % ceili(cooldown)
		elif battle.ink < int(data.cost):
			suffix = " · 墨滴不足"
		cards[kind].text = "%s %s    %d 墨滴%s" % ["●" if kind == selected else "○", kind, int(data.cost), suffix]
	selection_label.text = "点击卡牌，再点击棋盘放置。右键 / Esc 取消。"
	if not selected.is_empty():
		selection_label.text = "已选「%s」\n%s" % [selected, DESCRIPTIONS[selected]]
	begin_button.disabled = battle.phase != "ready"
	pause_button.disabled = battle.phase not in ["prep", "combat"]
	pause_button.text = "继续" if paused else "暂停  [P]"
	result_panel.visible = battle.phase in ["lost", "won"]
	if result_panel.visible:
		result_title.text = "诗卷失守" if battle.phase == "lost" else "十波守住了！"
		result_text.text = "%s\n本局击败 %d 个敌人。试试另一种布阵吧。" % [battle.feedback, battle.kills]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f7f1e4"))
	draw_rect(Rect2(610, 20, 550, 774), Color("eee4ce"))
	var counts: Array = battle.next_wave_counts()
	for row in range(11):
		for column in range(5):
			var rect := Rect2(ORIGIN + Vector2(column, row) * CELL, CELL)
			var color := Color("eee6d3") if (row + column) % 2 == 0 else Color("f4eedf")
			if row == 0:
				color = Color("d9c9b2")
			draw_rect(rect, color)
			draw_rect(rect, Color("cbbb9d"), false, 1.0)
			if row == 0:
				var caption := "出生行"
				if battle.phase in ["ready", "prep"]:
					caption = "下波 %d" % counts[column]
				_center_text(caption, rect.get_center(), 16, MUTED)
		_center_text(str(11 - row), Vector2(47, ORIGIN.y + (row + 0.5) * CELL.y), 15, MUTED)
	if hover.x >= 0 and hover.x < 5 and hover.y >= 0 and hover.y < 11 and not selected.is_empty():
		var hover_rect := Rect2(ORIGIN + Vector2(hover) * CELL, CELL)
		var valid := hover.y > 0 and battle.guard_at(hover.x, hover.y).is_empty()
		draw_rect(hover_rect.grow(-2), Color(0.2, 0.5, 0.4, 0.18) if valid else Color(0.8, 0.2, 0.2, 0.2))
	for guard in battle.guards:
		var at := _board_position(int(guard.col), float(guard.row) + 0.5) + Vector2(-12, 0)
		var color: Color = GUARD_COLORS[guard.kind]
		draw_circle(at, 21, color)
		_center_text(str(guard.kind), at, 28, Color("fff8e7"))
		_health_bar(at + Vector2(-23, 22), 46, float(guard.hp) / float(guard.max_hp), Color("57816b"))
		if guard.kind == "雷":
			var ready := float(guard.age) >= 15.0
			_center_text("就绪" if ready else str(ceili(15.0 - float(guard.age))), at + Vector2(34, 6), 13, ACCENT)
	for enemy in battle.enemies:
		var at := _board_position(int(enemy.col), float(enemy.y)) + Vector2(17, 0)
		var color := Color("a74739")
		if enemy.kind == "骨" and float(enemy.hp) < float(enemy.max_hp) / 2.0:
			color = Color("db372c")
		elif enemy.kind == "甲":
			color = Color("68616a")
		elif enemy.kind == "跳":
			color = Color("a56839")
		if float(enemy.slow_left) > 0.0:
			draw_circle(at, 23, Color("8ec5d9"))
		draw_circle(at, 19, color)
		_center_text(str(enemy.kind), at, 26, Color("fff7e9"))
		_health_bar(at + Vector2(-21, -27), 42, float(enemy.hp) / float(enemy.max_hp), ACCENT)
	for arrow in battle.arrows:
		var at := _board_position(int(arrow.col), float(arrow.y))
		var color := Color("409ebd") if arrow.kind == "冰" else INK_COLOR
		draw_line(at + Vector2(0, 10), at - Vector2(0, 10), color, 2.0)
		draw_line(at - Vector2(0, 10), at + Vector2(-4, -4), color, 2.0)
		draw_line(at - Vector2(0, 10), at + Vector2(4, -4), color, 2.0)
	for effect in battle.effects:
		var at := _board_position(int(effect.col), float(effect.y))
		if effect.kind == "blast":
			draw_rect(Rect2(at - CELL / 2.0, CELL), Color(0.95, 0.55, 0.15, float(effect.left)))
		else:
			_center_text("+50", at + Vector2(0, -12), 22, Color("3f795b"))
	draw_line(Vector2(70, 744), Vector2(550, 744), ACCENT, 4.0)
	if paused:
		draw_rect(BOARD, Color(0.1, 0.2, 0.2, 0.45))
		_center_text("暂停", BOARD.get_center(), 38, Color.WHITE)

func _board_position(column: int, y: float) -> Vector2:
	return ORIGIN + Vector2((column + 0.5) * CELL.x, y * CELL.y)

func _center_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	var dimensions: Vector2 = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(FONT, at + Vector2(-dimensions.x / 2.0, font_size * 0.35), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _health_bar(at: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("d5c8b5"))
	draw_rect(Rect2(at, Vector2(width * clampf(ratio, 0.0, 1.0), 4)), color)
