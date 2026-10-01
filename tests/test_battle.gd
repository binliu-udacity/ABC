extends SceneTree

const Battle = preload("res://levels/battle.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_placement_and_income()
	_test_arrows_and_loss()
	_test_mines()
	_test_jump_and_bone()
	_test_new_units()
	_test_ten_waves()
	print("%s: %d battle checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + explanation)

func run_for(battle, seconds: float) -> void:
	for _tick in range(roundi(seconds / 0.05)):
		battle.step(0.05)

func sandbox():
	var battle = Battle.new()
	battle.phase = "prep"
	battle.prep_left = 10000.0
	return battle

func _test_placement_and_income() -> void:
	var battle = Battle.new()
	check(battle.ink == 100, "initial ink")
	check(not battle.place("弓", 2, 0), "spawn row rejects guards")
	check(not battle.place("弓", 5, 10), "outside board rejects guards")
	check(battle.place("弓", 2, 10), "bow costs 100")
	check(battle.ink == 0, "placement deducts ink")
	check(not battle.place("盾", 2, 10), "occupied cell rejected")
	battle.ink = 200
	check(not battle.place("弓", 1, 10), "shared card cooldown")
	run_for(battle, 20.0)
	check(battle.elapsed == 0.0 and battle.ink == 200, "ready screen freezes time")
	battle.start()
	run_for(battle, 10.05)
	check(battle.ink == 250, "system grants exactly 50 each 10 seconds")
	check(battle.place("弓", 1, 10), "cooldown expires")
	var economy = sandbox()
	check(economy.place("砚", 0, 10), "place ink guard")
	run_for(economy, 30.05)
	check(economy.ink == 250, "ink guard gives 50 after 30 seconds plus system income")

func _test_arrows_and_loss() -> void:
	var battle = sandbox()
	battle.place("弓", 2, 10)
	battle.spawn_enemy("卒", 2)
	run_for(battle, 12.0)
	check(battle.enemies.is_empty() and battle.kills == 1, "bow kills approaching soldier")
	var loss = sandbox()
	loss.spawn_enemy("卒", 0)
	run_for(loss, 24.0)
	check(loss.phase == "lost", "one leak loses the game")
	var time_at_loss: float = loss.elapsed
	run_for(loss, 20.0)
	check(loss.elapsed == time_at_loss, "result freezes simulation")
	var ice = sandbox()
	ice.ink = 150
	ice.place("冰", 2, 10)
	var enemy: Dictionary = ice.spawn_enemy("甲", 2)
	run_for(ice, 3.0)
	check(float(enemy.slow_left) > 0.0 and float(enemy.hp) < 1201.0, "ice arrow applies damage and slow")

func _test_mines() -> void:
	var unready = sandbox()
	unready.place("雷", 2, 1)
	var soldier: Dictionary = unready.spawn_enemy("卒", 2)
	run_for(unready, 6.0)
	check(unready.guards.is_empty(), "unready mine can be attacked and destroyed")
	check(float(soldier.hp) == 200.0, "destroyed mine does not explode")
	var ready = sandbox()
	ready.place("雷", 2, 5)
	run_for(ready, 15.05)
	var first: Dictionary = ready.spawn_enemy("甲", 2)
	first.y = 5.0
	var second: Dictionary = ready.spawn_enemy("砂", 2)
	second.y = 5.6
	var adjacent: Dictionary = ready.spawn_enemy("卒", 1)
	adjacent.y = 5.0
	var other_row: Dictionary = ready.spawn_enemy("卒", 2)
	other_row.y = 4.0
	ready.step(0.05)
	check(float(first.hp) <= 0.0 and float(second.hp) <= 0.0, "mine damages all enemies in its cell")
	check(float(adjacent.hp) == 200.0 and float(other_row.hp) == 200.0, "mine does not damage adjacent cells")
	check(ready.guards.is_empty() and ready.kills == 2, "mine disappears after exploding")
	var jump_mine = sandbox()
	jump_mine.place("雷", 1, 5)
	run_for(jump_mine, 15.05)
	var jumper: Dictionary = jump_mine.spawn_enemy("跳", 1)
	jumper.y = 5.0
	jump_mine.step(0.05)
	check(jump_mine.kills == 1, "jump triggers ready mine")

func _test_jump_and_bone() -> void:
	var jump = sandbox()
	jump.ink = 150
	jump.place("盾", 1, 2)
	jump.place("弓", 1, 3)
	var jumper: Dictionary = jump.spawn_enemy("跳", 1)
	jumper.y = 1.9
	run_for(jump, 3.0)
	check(float(jump.guard_at(1, 2).hp) == 1200.0, "jump passes shield without damaging it")
	check(float(jump.guard_at(1, 3).hp) < 80.0, "jump attacks other guards")
	var bone = sandbox()
	bone.place("盾", 2, 2)
	var skeleton: Dictionary = bone.spawn_enemy("骨", 2)
	skeleton.y = 2.02
	skeleton.hp = 284.0
	run_for(bone, 1.05)
	check(float(bone.guard_at(2, 2).hp) == 1156.0, "bone below half health deals 44 per second")
	var speed = sandbox()
	var fast: Dictionary = speed.spawn_enemy("骨", 1)
	fast.hp = 284.0
	run_for(speed, 1.0)
	check(absf(float(fast.y) - 1.2) < 0.001, "bone below half moves at 0.7 cells per second")

func _test_ten_waves() -> void:
	# 用实际墨滴和共享冷却布阵，验证经济与防御组合能够通关。
	var battle = Battle.new()
	battle.place("砚", 0, 10)
	battle.place("盾", 2, 8)
	battle.start()
	var plan := [[2, 10], [0, 9], [4, 10], [1, 10], [3, 10],
		[2, 9], [0, 8], [4, 9], [1, 9], [3, 9],
		[2, 7], [0, 7], [4, 8], [1, 8], [3, 8]]
	for _tick in range(20000):
		if battle.phase in ["lost", "won"]:
			break
		if battle.wave >= 5 and battle.guard_at(2, 6).is_empty():
			if battle.ink >= 300:
				battle.place("闪", 2, 6)
			else:
				battle.step(0.05)
				continue
		for cell in plan:
			if battle.guard_at(int(cell[0]), int(cell[1])).is_empty():
				if battle.ink >= 100 and float(battle.cooldowns["弓"]) <= 0.0:
					battle.place("弓", int(cell[0]), int(cell[1]))
				break
		battle.step(0.05)
	check(battle.phase == "won", "legal economic strategy can complete ten waves: " + battle.feedback)
	check(battle.wave == 10 and battle.kills == 31, "all planned enemies handled across ten waves")

func _test_new_units() -> void:
	var flight = sandbox()
	flight.ink = 1000
	flight.place("盾", 1, 5)
	flight.place("雷", 1, 6)
	flight.guards[1].age = 15.0
	var wing: Dictionary = flight.spawn_enemy("翼", 1)
	wing.y = 4.9
	run_for(flight, 4.0)
	check(float(wing.y) > 6.5 and float(wing.hp) == 190.0, "wing flies over shield and ready mine")
	check(flight.guards.size() == 2 and float(flight.guards[0].hp) == 1200.0, "wing does not attack or trigger mine")
	for kind in ["弓", "冰", "焰", "霜", "弩"]:
		var projectiles = sandbox()
		var flying: Dictionary = projectiles.spawn_enemy("翼", 2)
		flying.y = 5.0
		var ground: Dictionary = projectiles.spawn_enemy("卒", 2)
		ground.y = 4.5
		projectiles.arrows.append({"col": 2, "y": 5.5, "kind": kind, "damage": 30.0})
		projectiles._tick_arrows(0.2)
		check(float(flying.hp) == 190.0 and float(ground.hp) == 170.0, kind + " skips wing and hits ground target")
		check(float(flying.slow_left) == 0.0 and float(flying.permanent_speed) == 1.0 and not bool(flying.burning), kind + " cannot apply effects to wing")
	var explosion = sandbox()
	explosion.place("雷", 2, 5)
	var air: Dictionary = explosion.spawn_enemy("翼", 2)
	air.y = 5.5
	explosion._explode(explosion.guards[0])
	check(float(air.hp) == 190.0, "wing immune to mine blast triggered by another enemy")
	var column_attack = sandbox()
	column_attack.ink = 250
	column_attack.place("电", 2, 5)
	var forward: Dictionary = column_attack.spawn_enemy("卒", 2)
	var behind: Dictionary = column_attack.spawn_enemy("翼", 2)
	behind.y = 9.0
	var other: Dictionary = column_attack.spawn_enemy("卒", 1)
	column_attack._tick_guards(1.0)
	check(float(forward.hp) == 172.0 and float(behind.hp) == 162.0, "electric attacks entire column including wing and behind")
	check(float(other.hp) == 200.0, "electric does not hit another column")
	check(column_attack.effects.size() == 1 and column_attack.effects[0].kind == "column_beam", "electric uses one full-column beam")
	var global_attack = sandbox()
	global_attack.ink = 300
	global_attack.place("闪", 2, 5)
	var a: Dictionary = global_attack.spawn_enemy("卒", 0)
	var b: Dictionary = global_attack.spawn_enemy("翼", 4)
	b.y = 9.0
	global_attack._tick_guards(1.0)
	check(float(a.hp) == 175.0 and float(b.hp) == 165.0, "flash attacks all columns and flying enemies")
	var burn = sandbox()
	var burning: Dictionary = burn.spawn_enemy("玄", 2)
	burning.y = 5.0
	burn.arrows.append({"col": 2, "y": 5.5, "kind": "焰", "damage": 38.0})
	burn._tick_arrows(0.1)
	check(float(burning.hp) == 3563.0 and bool(burning.burning), "flame hits for 38 and starts permanent burn")
	burn._tick_status(2.0)
	check(float(burning.hp) == 3543.0, "burn deals 10 each second")
	burn.arrows.append({"col": 2, "y": 5.5, "kind": "焰", "damage": 38.0})
	burn._tick_arrows(0.1)
	check(bool(burning.burning), "repeated flame keeps burning")
	burn._tick_status(5.0)
	check(float(burning.hp) == 3455.0 and bool(burning.burning), "repeated burn does not stack damage")
	burn._tick_status(1.0)
	check(float(burning.hp) == 3445.0, "burn continues beyond five seconds without flame guard")
	burn._tick_status(10.0)
	check(float(burning.hp) == 3345.0 and bool(burning.burning), "burn remains permanent")
	var frost = sandbox()
	var slowed: Dictionary = frost.spawn_enemy("玄", 2)
	slowed.y = 5.0
	for _hit in range(2):
		frost.arrows.append({"col": 2, "y": 5.5, "kind": "霜", "damage": 35.0})
		frost._tick_arrows(0.1)
	check(float(slowed.hp) == 3531.0 and float(slowed.permanent_speed) == 0.8, "frost hits for 35 and permanent slow does not stack")
	frost._tick_enemies(1.0)
	check(absf(float(slowed.y) - 5.192) < 0.001, "xuan uses 0.24 speed times permanent slow")
	slowed.slow_left = 10.0
	frost._tick_enemies(1.0)
	check(absf(float(slowed.y) - 5.312) < 0.001, "ice and frost take strongest slow")
	var crossbow = sandbox()
	crossbow.ink = 180
	crossbow.place("弩", 2, 10)
	crossbow.spawn_enemy("玄", 2)
	crossbow._tick_guards(0.75)
	crossbow._tick_guards(0.75)
	check(crossbow.arrows.size() == 2 and float(crossbow.arrows[0].damage) == 32.0, "crossbow fires every 0.75 seconds with 32 damage")
