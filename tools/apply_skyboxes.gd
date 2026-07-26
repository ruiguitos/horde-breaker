extends SceneTree

## Puts a Kenney skybox behind each atmosphere preset, so the sky itself tells
## the player how bad things have got. The textures are 4096x2048 equirectangular
## panoramas, which is exactly what PanoramaSkyMaterial wants.
##
## Run:  <godot> --headless --path . --script res://tools/apply_skyboxes.gd

const SKY_BY_PRESET := {
	"res://resources/atmosphere_presets/calm.tres":
		"res://assets/models/kenney_skyboxes/skybox-day.png",
	"res://resources/atmosphere_presets/threat_5.tres":
		"res://assets/models/kenney_skyboxes/skybox-morning.png",
	"res://resources/atmosphere_presets/threat_10.tres":
		"res://assets/models/kenney_skyboxes/skybox-night.png",
	"res://resources/atmosphere_presets/nightmare.tres":
		"res://assets/models/kenney_skyboxes/skybox-alien.png",
}
## How much light the sky contributes. Kept low: these are bright panoramas and
## the game wants an overcast, oppressive read, not a sunny afternoon.
const SKY_ENERGY := 0.35


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var changed := 0
	for preset_path: String in SKY_BY_PRESET:
		var environment: Environment = load(preset_path)
		if environment == null:
			push_warning("Missing preset: %s" % preset_path)
			continue
		var texture: Texture2D = load(SKY_BY_PRESET[preset_path])
		if texture == null:
			push_warning("Missing sky texture for %s" % preset_path)
			continue
		var material := PanoramaSkyMaterial.new()
		material.panorama = texture
		material.energy_multiplier = SKY_ENERGY
		var sky := Sky.new()
		sky.sky_material = material
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		# Let the sky light the scene, but softly — the directional light is
		# still what carries the shadows.
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_sky_contribution = 0.6
		var error := ResourceSaver.save(environment, preset_path)
		if error != OK:
			push_error("Could not save %s: %d" % [preset_path, error])
			continue
		changed += 1
		print("SKY: %s -> %s" % [
			preset_path.get_file(), String(SKY_BY_PRESET[preset_path]).get_file()
		])
	print("DONE: %d presets updated" % changed)
	quit(0)
