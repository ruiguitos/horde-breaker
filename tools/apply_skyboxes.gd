extends SceneTree

## Writes the atmosphere presets: the sky behind each one, and the Forward+
## effects that only became affordable when the renderer changed.
##
## Run:  <godot> --headless --path . --script res://tools/apply_skyboxes.gd
##
## Edit the presets here, not in the .tres files — this tool rewrites all four
## and any hand edit to the fields it touches is lost on the next run.
##
## The sky tells the player how bad things have got; so does the fog. Volumetric
## density climbs with the threat level, which is what makes the map close in as
## a run wears on: streets that read clean across a whole sector at threat 0 fade
## out a block away by nightmare. SSAO sits the buildings on the ground — with
## flat ambient light the painted blocks looked like they were floating.
##
## SSIL is off, and that was measured rather than assumed. tests/bench_horde.gd
## with 140 enemies, three runs each: 127 / 127 / 134 FPS without it, 107 / 105 /
## 108 with. About 1.6 ms a frame, a sixth of the frame rate, for indirect light
## that this much fog hides anyway. Fog and SSAO together cost nothing that shows
## above the run-to-run spread.

## How much light the sky contributes. Kept low: these are bright panoramas and
## the game wants an overcast, oppressive read, not a sunny afternoon.
const SKY_ENERGY := 0.35
## Volumetric fog only builds out to this distance, so it costs the same whatever
## the world measures. A sector is 64 m; 80 m carries the fog to the end of the
## street the player is looking down.
const FOG_LENGTH := 80.0

const PRESETS := {
	"res://resources/atmosphere_presets/calm.tres": {
		"sky": "res://assets/models/kenney_skyboxes/skybox-day.png",
		"fog_density": 0.008,
		"fog_albedo": Color(0.74, 0.77, 0.80),
		"depth_fog_density": 0.0018,
		"ssao_intensity": 1.3,
	},
	"res://resources/atmosphere_presets/threat_5.tres": {
		"sky": "res://assets/models/kenney_skyboxes/skybox-morning.png",
		"fog_density": 0.016,
		"fog_albedo": Color(0.76, 0.71, 0.64),
		"depth_fog_density": 0.0026,
		"ssao_intensity": 1.5,
	},
	"res://resources/atmosphere_presets/threat_10.tres": {
		"sky": "res://assets/models/kenney_skyboxes/skybox-night.png",
		"fog_density": 0.028,
		"fog_albedo": Color(0.70, 0.60, 0.54),
		"depth_fog_density": 0.0038,
		"ssao_intensity": 1.7,
	},
	"res://resources/atmosphere_presets/nightmare.tres": {
		"sky": "res://assets/models/kenney_skyboxes/skybox-alien.png",
		"fog_density": 0.042,
		"fog_albedo": Color(0.66, 0.50, 0.46),
		"depth_fog_density": 0.0052,
		"ssao_intensity": 1.9,
	},
}
## Flip to true and re-run tests/bench_horde.gd before believing it is free.
const ENABLE_SSIL := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var changed := 0
	for preset_path: String in PRESETS:
		var settings: Dictionary = PRESETS[preset_path]
		var environment: Environment = load(preset_path)
		if environment == null:
			push_warning("Missing preset: %s" % preset_path)
			continue
		if not _apply_sky(environment, String(settings["sky"])):
			continue
		_apply_fog(environment, settings)
		_apply_ambient_occlusion(environment, float(settings["ssao_intensity"]))
		var error := ResourceSaver.save(environment, preset_path)
		if error != OK:
			push_error("Could not save %s: %d" % [preset_path, error])
			continue
		changed += 1
		print("ATMOSPHERE: %s  sky=%s  fog=%.3f  ssao=%.1f" % [
			preset_path.get_file(),
			String(settings["sky"]).get_file(),
			float(settings["fog_density"]),
			float(settings["ssao_intensity"]),
		])
	print("DONE: %d presets updated (ssil %s)" % [
		changed, "on" if ENABLE_SSIL else "off"
	])
	quit(0)


func _apply_sky(environment: Environment, texture_path: String) -> bool:
	var texture: Texture2D = load(texture_path)
	if texture == null:
		push_warning("Missing sky texture: %s" % texture_path)
		return false
	var material := PanoramaSkyMaterial.new()
	material.panorama = texture
	material.energy_multiplier = SKY_ENERGY
	var sky := Sky.new()
	sky.sky_material = material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	# Let the sky light the scene, but softly — the directional light is still
	# what carries the shadows.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.6
	return true


func _apply_fog(environment: Environment, settings: Dictionary) -> void:
	# Depth fog still does the long-distance work; the volumetric layer is what
	# catches the lights and gives the streets some air to hang in.
	environment.fog_enabled = true
	environment.fog_density = float(settings["depth_fog_density"])
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = float(settings["fog_density"])
	environment.volumetric_fog_albedo = settings["fog_albedo"]
	environment.volumetric_fog_length = FOG_LENGTH
	# Forward scattering: the fog brightens towards the light instead of sitting
	# as an even haze, so the sun still reads as a direction.
	environment.volumetric_fog_anisotropy = 0.3
	environment.volumetric_fog_ambient_inject = 0.6
	environment.volumetric_fog_sky_affect = 0.35


func _apply_ambient_occlusion(environment: Environment, intensity: float) -> void:
	environment.ssao_enabled = true
	environment.ssao_intensity = intensity
	# Radius in metres. The buildings are 8 m blocks, so a wide radius is what
	# darkens the corner where two of them meet rather than only their edges.
	environment.ssao_radius = 1.6
	environment.ssao_power = 1.4
	environment.ssao_light_affect = 0.15
	environment.ssil_enabled = ENABLE_SSIL
	environment.ssil_intensity = 1.0
	environment.ssil_radius = 3.0
