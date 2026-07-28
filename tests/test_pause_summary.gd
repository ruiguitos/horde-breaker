extends SceneTree

## The pause panel reports the run: how it is going, and which upgrade cards were
## taken. RunUpgrades applies a card and forgets it, so the run had no record of
## its own build — this covers the record and the panel that reads it.

const ARENA_SCENE := "res://scenes/world/test_arena.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if change_scene_to_file(ARENA_SCENE) != OK:
		_check("arena loads", false)
		_report()
		return
	await scene_changed
	for _frame in 60:
		await process_frame

	var progression := get_first_node_in_group(&"run_progression")
	_check("run progression is present", progression != null)
	if progression == null:
		_report()
		return

	_check(
		"nothing taken at the start",
		(progression.call(&"get_taken_upgrades") as Array).is_empty()
	)

	# Take the same card twice and a different one once.
	progression.call(&"apply_upgrade", &"damage")
	progression.call(&"apply_upgrade", &"damage")
	progression.call(&"apply_upgrade", &"move_speed")
	var taken: Array = progression.call(&"get_taken_upgrades")
	_check("two distinct upgrades recorded (%d)" % taken.size(), taken.size() == 2)
	_check("three cards counted", int(progression.call(&"get_taken_upgrade_count")) == 3)
	if taken.size() == 2:
		var first: Dictionary = taken[0]
		# Sorted by count, so the repeated one leads.
		_check("most-taken first (%s ×%d)" % [first["name"], first["count"]],
			int(first["count"]) == 2)
		_check("carries a readable name", not String(first["name"]).is_empty())

	# The panel has to survive being opened with a run in progress.
	var pause_menu := current_scene.find_child("PauseMenu", true, false)
	_check("pause menu is present", pause_menu != null)
	if pause_menu == null:
		_report()
		return
	pause_menu.call(&"pause_game")
	await process_frame
	_check("pausing shows the panel", bool(pause_menu.get(&"visible")))
	_check("tree is paused", paused)

	var summary := pause_menu.get_node_or_null(
		"RunCard/Body/Content/RunSummary"
	) as Label
	_check("summary label exists", summary != null)
	if summary != null:
		var text := summary.text
		_check("summary reports survival time", text.contains("SURVIVED"))
		_check("summary reports kills", text.contains("KILLS"))
		_check("summary reports the run level", text.contains("RUN LEVEL"))

	var list := pause_menu.get_node_or_null(
		"RunCard/Body/Content/UpgradesList"
	) as Label
	_check("upgrades label exists", list != null)
	if list != null:
		_check("upgrades are listed when taken", list.visible and not list.text.is_empty())
		_check("a repeated card shows its count", list.text.contains("×2"))

	pause_menu.call(&"resume_game")
	await process_frame
	_check("resuming unpauses", not paused)
	_report()


func _report() -> void:
	print("TEST: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("TEST: %s" % label)
	else:
		_failed += 1
		print("TEST FAIL: %s" % label)
