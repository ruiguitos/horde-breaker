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
		# Sorted by level, so the one taken twice leads.
		_check("highest level first (%s LV %d)" % [first["name"], first["level"]],
			int(first["level"]) == 2)
		_check("carries a readable name", not String(first["name"]).is_empty())
		_check("carries its rarity", not String(first["rarity"]).is_empty())
		_check("carries its ceiling (%d)" % int(first["max_level"]),
			int(first["max_level"]) >= int(first["level"]))

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

	# Laid out in columns rather than one list: a single column had to be cut off
	# with "+N more", which hid exactly what the player opened the menu to check.
	var columns := pause_menu.get_node_or_null(
		"RunCard/Body/Content/UpgradesColumns"
	) as HBoxContainer
	_check("upgrades are laid out in columns", columns != null)
	if columns != null:
		var entries: Array[String] = []
		for column in columns.get_children():
			for child in column.get_children():
				var label := child as Label
				if label != null:
					entries.append(label.text)
		_check("every upgrade taken is listed (%d)" % entries.size(),
			entries.size() == taken.size())
		var shows_level := false
		for entry in entries:
			if entry.contains("LV 2"):
				shows_level = true
		_check("a stacked card shows its level", shows_level)

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
