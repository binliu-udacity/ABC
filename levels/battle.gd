extends RefCounted

# 战斗规则与画面分开：这里不画图，方便修改数值和验证规则。
const GuardData = preload("res://player/guard_data.gd")
const EnemyData = preload("res://enemies/enemy_data.gd")
const COLUMNS := 5
const ROWS := 11
const MAX_WAVES := 10
const INK_INTERVAL := 10.0
const INK_AMOUNT := 50
const PREP_TIME := 8.0
const SPAWN_INTERVAL := 4.0
const ARROW_SPEED := 8.0

# 波次和出场列是原型试用值，列号从 0 开始。第一只卒从画面第三列出场。
const WAVES: Array = [
	[["卒", 2]],
	[["卒", 0], ["卒", 4]],
	[["卒", 1], ["卒", 3], ["卒", 2]],
	[["砂", 2], ["卒", 0], ["卒", 4]],
	[["跳", 1], ["卒", 3], ["砂", 2]],
	[["骨", 2], ["卒", 0], ["跳", 4]],
	[["甲", 2], ["砂", 1], ["卒", 3]],
	[["骨", 0], ["跳", 4], ["砂", 2], ["卒", 1]],
	[["甲", 3], ["骨", 1], ["跳", 0], ["砂", 4]],
	[["甲", 2], ["骨", 0], ["跳", 4], ["砂", 1], ["卒", 3]],
]

var ink := 100
var ink_clock := 0.0
var cooldowns: Dictionary = {}
var guards: Array = []
var enemies: Array = []
var arrows: Array = []
var effects: Array = []
var phase := "ready"
var wave := 0
var prep_left := 12.0
var spawn_left := 0.0
var spawn_index := 0
var kills := 0
var elapsed := 0.0
var feedback := "先选择守兵，再点击格子。第一波从第三列进攻。"

func _init() -> void:
	for kind in GuardData.UNITS:
		cooldowns[kind] = 0.0

func start() -> void:
	if phase == "ready":
		phase = "prep"
		feedback = "准备时间开始：顶部数字表示下一波各列敌人数。"

func place(kind: String, column: int, row: int) -> bool:
	if phase in ["lost", "won"]:
		return false
	if not GuardData.UNITS.has(kind):
		return false
	if column < 0 or column >= COLUMNS or row < 1 or row >= ROWS:
		feedback = "出生行不能放置守兵。"
		return false
	if not guard_at(column, row).is_empty():
		feedback = "这个格子已经有守兵。"
		return false
	var data: Dictionary = GuardData.UNITS[kind]
	if float(cooldowns[kind]) > 0.0:
		feedback = "这张守兵卡还在冷却。"
		return false
	if ink < int(data.cost):
		feedback = "墨滴不足，等待系统或砚提供墨滴。"
		return false
	ink -= int(data.cost)
	cooldowns[kind] = data.cooldown
	guards.append({"kind": kind, "col": column, "row": row,
		"hp": data.hp, "max_hp": data.hp, "age": 0.0, "clock": 0.0})
	feedback = "已放置「%s」。" % kind
	return true

func guard_at(column: int, row: int) -> Dictionary:
	for guard in guards:
		if int(guard.col) == column and int(guard.row) == row and float(guard.hp) > 0.0:
			return guard
	return {}

func spawn_enemy(kind: String, column: int) -> Dictionary:
	var data: Dictionary = EnemyData.UNITS[kind]
	var enemy := {"kind": kind, "col": column, "y": 0.5,
		"hp": data.hp, "max_hp": data.hp, "attack_clock": 0.0,
		"slow_left": 0.0, "target_row": -1}
	enemies.append(enemy)
	return enemy

func next_wave_counts() -> Array:
	var counts := [0, 0, 0, 0, 0]
	if wave < MAX_WAVES:
		for entry in WAVES[wave]:
			counts[int(entry[1])] += 1
	return counts

func step(delta: float) -> void:
	if phase in ["ready", "lost", "won"]:
		return
	elapsed += delta
	ink_clock += delta
	while ink_clock >= INK_INTERVAL:
		ink_clock -= INK_INTERVAL
		ink += INK_AMOUNT
	for kind in cooldowns:
		cooldowns[kind] = maxf(0.0, float(cooldowns[kind]) - delta)
	for effect in effects:
		effect.left -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return float(effect.left) > 0.0)
	_tick_waves(delta)
	_tick_guards(delta)
	_tick_arrows(delta)
	_tick_enemies(delta)
	_cleanup()
	if phase == "combat" and spawn_index >= WAVES[wave - 1].size() and enemies.is_empty():
		if wave == MAX_WAVES:
			phase = "won"
			feedback = "十波全部守住！"
		else:
			phase = "prep"
			prep_left = PREP_TIME
			feedback = "第 %d 波守住了，准备下一波。" % wave

func _tick_waves(delta: float) -> void:
	if phase == "prep":
		prep_left -= delta
		if prep_left <= 0.0:
			wave += 1
			phase = "combat"
			spawn_index = 0
			spawn_left = 0.0
			feedback = "第 %d 波开始！" % wave
	if phase == "combat":
		spawn_left -= delta
		while spawn_left <= 0.0 and spawn_index < WAVES[wave - 1].size():
			var entry: Array = WAVES[wave - 1][spawn_index]
			spawn_enemy(str(entry[0]), int(entry[1]))
			spawn_index += 1
			spawn_left += SPAWN_INTERVAL

func _tick_guards(delta: float) -> void:
	for guard in guards:
		if float(guard.hp) <= 0.0:
			continue
		guard.age += delta
		guard.clock += delta
		var kind: String = guard.kind
		var data: Dictionary = GuardData.UNITS[kind]
		if kind == "砚":
			while float(guard.clock) >= float(data.interval):
				guard.clock -= float(data.interval)
				ink += 50
				effects.append({"col": guard.col, "y": float(guard.row) + 0.5, "left": 0.7, "kind": "ink"})
		elif kind in ["弓", "冰"]:
			if float(guard.clock) >= float(data.interval) and _has_target(guard):
				guard.clock = 0.0
				arrows.append({"col": guard.col, "y": float(guard.row) + 0.2, "kind": kind, "damage": data.damage})
			else:
				guard.clock = minf(float(guard.clock), float(data.interval))

func _has_target(guard: Dictionary) -> bool:
	for enemy in enemies:
		if float(enemy.hp) > 0.0 and int(enemy.col) == int(guard.col) and float(enemy.y) < float(guard.row) + 0.5:
			return true
	return false

func _tick_arrows(delta: float) -> void:
	var remaining: Array = []
	for arrow in arrows:
		var old_y: float = arrow.y
		arrow.y -= ARROW_SPEED * delta
		var target: Dictionary = {}
		for enemy in enemies:
			if float(enemy.hp) <= 0.0 or int(enemy.col) != int(arrow.col):
				continue
			if float(enemy.y) >= float(arrow.y) - 0.22 and float(enemy.y) <= old_y + 0.22:
				if target.is_empty() or float(enemy.y) > float(target.y):
					target = enemy
		if not target.is_empty():
			target.hp -= float(arrow.damage)
			if arrow.kind == "冰":
				target.slow_left = 10.0 # 重复命中刷新时间，不叠加减速。
		elif float(arrow.y) >= 0.0:
			remaining.append(arrow)
	arrows = remaining

func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if float(enemy.hp) <= 0.0:
			continue
		var data: Dictionary = EnemyData.UNITS[enemy.kind]
		var speed: float = data.speed
		var damage: float = data.damage
		if enemy.kind == "骨" and float(enemy.hp) < float(enemy.max_hp) * 0.5:
			speed = 0.7
			damage = 44.0
		if float(enemy.slow_left) > 0.0:
			speed *= 0.5
		enemy.slow_left = maxf(0.0, float(enemy.slow_left) - delta)
		var destination: float = float(enemy.y) + speed * delta
		var blocker: Dictionary = {}
		for guard in guards:
			if float(guard.hp) <= 0.0 or int(guard.col) != int(enemy.col):
				continue
			if enemy.kind == "跳" and guard.kind == "盾":
				continue
			var contact_y := float(guard.row) + 0.02
			if float(enemy.y) <= float(guard.row) + 0.85 and contact_y <= destination:
				if blocker.is_empty() or int(guard.row) < int(blocker.row):
					blocker = guard
		if blocker.is_empty():
			enemy.y = destination
			enemy.attack_clock = 0.0
			enemy.target_row = -1
		else:
			enemy.y = maxf(float(enemy.y), float(blocker.row) + 0.02)
			if blocker.kind == "雷" and float(blocker.age) >= 15.0:
				_explode(blocker)
				continue
			if int(enemy.target_row) != int(blocker.row):
				enemy.attack_clock = 0.0
				enemy.target_row = blocker.row
			enemy.attack_clock += delta
			while float(enemy.attack_clock) >= 1.0 and float(blocker.hp) > 0.0:
				enemy.attack_clock -= 1.0
				blocker.hp -= damage
		if float(enemy.y) >= ROWS:
			phase = "lost"
			feedback = "「%s」越过了第 %d 列底线，诗卷失守。" % [enemy.kind, int(enemy.col) + 1]
			return

func _explode(guard: Dictionary) -> void:
	guard.hp = 0.0
	for enemy in enemies:
		if int(enemy.col) == int(guard.col) and floori(float(enemy.y)) == int(guard.row):
			enemy.hp -= 1800.0
	effects.append({"col": guard.col, "y": float(guard.row) + 0.5, "left": 0.6, "kind": "blast"})
	feedback = "雷爆炸了！只伤害所在格内的敌人。"

func _cleanup() -> void:
	for enemy in enemies:
		if float(enemy.hp) <= 0.0:
			kills += 1
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp) > 0.0)
	guards = guards.filter(func(guard: Dictionary) -> bool: return float(guard.hp) > 0.0)
