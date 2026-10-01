extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(explanation)

func run_checks() -> void:
	var scene = load("res://levels/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var bow = scene.cards["弓"]
	var ice = scene.cards["冰"]
	check(scene.BOARD.size == Vector2(700, 682), "larger board")
	check(bow.size == Vector2(88, 88), "compact square card")
	check(scene.cards.size() == 10, "all ten guards available")
	for card in scene.cards.values():
		check(card.position.y + card.size.y < scene.selection_label.position.y, "cards fit above description")
	check(bow.position.x > scene.BOARD.end.x, "cards outside board")
	check(ice.shade.visible and ice.shade.size.y == 84.0, "insufficient ink fully shades card")
	scene.battle.ink = 1000
	scene.battle.cooldowns["弓"] = 2.5
	scene._refresh_ui()
	check(bow.shade.visible and bow.shade.size.y == 42.0, "half cooldown shades half card")
	check(bow.selection_ring.visible, "selection visible above shade")
	check(bow.shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "shade does not block card selection")
	scene.battle.phase = "prep"
	scene.battle.prep_left = 1000.0
	scene.battle.step(1.0)
	scene._refresh_ui()
	check(bow.shade.size.y < 42.0, "shade shrinks with time")
	scene._toggle_pause()
	var paused_height: float = bow.shade.size.y
	scene._process(1.0)
	check(bow.shade.size.y == paused_height, "pause freezes cooldown shade")
	scene.battle.ink = 0
	scene._refresh_ui()
	check(bow.shade.size.y == 84.0, "insufficient ink overrides partial cooldown")
	scene.battle.ink = 1000
	scene.battle.cooldowns["弓"] = 0.0
	scene._refresh_ui()
	check(not bow.shade.visible, "affordable ready card has no shade")
	print("%s: %d UI checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
