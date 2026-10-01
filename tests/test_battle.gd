extends SceneTree

const Battle = preload("res://levels/battle.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_placement_and_income()
	_test_arrows_and_loss()
	_test_mines()
	_test_jump_and_bone()
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
		for cell in plan:
			if battle.guard_at(int(cell[0]), int(cell[1])).is_empty():
				if battle.ink >= 100 and float(battle.cooldowns["弓"]) <= 0.0:
					battle.place("弓", int(cell[0]), int(cell[1]))
				break
		battle.step(0.05)
	check(battle.phase == "won", "legal economic strategy can complete ten waves: " + battle.feedback)
	check(battle.wave == 10 and battle.kills == 31, "all planned enemies handled across ten waves")
