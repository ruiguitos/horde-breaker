// Derived from Terrain3D's MIT-licensed minimum shader.
// Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_disabled, skip_vertex_transform;

#define SKIP_PASS 0
#define VERTEX_PASS 1

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	#define fma(a, b, c) ((a) * (b) + (c))
	#define dFdxCoarse(a) dFdx(a)
	#define dFdyCoarse(a) dFdy(a)
#endif

uniform vec3 _camera_pos = vec3(0.0);
uniform float _mesh_size = 48.0;
uniform uint _background_mode = 0u;
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0;
uniform float _region_size = 256.0;
uniform float _region_texel_size = 0.00390625;
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform highp sampler2DArray _height_maps : repeat_disable;

uniform vec3 grass_color : source_color = vec3(0.20, 0.30, 0.13);
uniform vec3 soil_color : source_color = vec3(0.25, 0.15, 0.07);
uniform float slope_start : hint_range(0.0, 1.0) = 0.08;
uniform float slope_end : hint_range(0.0, 1.0) = 0.42;

varying float v_vertex_xz_dist;
varying vec3 v_world_position;


ivec3 get_index_coord(const vec2 uv, const int search) {
	vec2 r_uv = round(uv);
	vec2 o_uv = mod(r_uv, _region_size);
	ivec2 pos;
	int bounds;
	int layer_index = -1;
	for (int i = -1; i < clamp(search, SKIP_PASS, VERTEX_PASS); i++) {
		if ((layer_index == -1 && _background_mode == 0u) || i < 0) {
			r_uv -= i == -1
				? vec2(0.0)
				: vec2(float(o_uv.x <= o_uv.y), float(o_uv.y <= o_uv.x));
			pos = ivec2(floor(r_uv * _region_texel_size)) + (_region_map_size / 2);
			bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
			layer_index = (_region_map[pos.y * _region_map_size + pos.x] * bounds - 1);
		}
	}
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);
}


void vertex() {
	v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_vertex_xz_dist = length(v_world_position.xz - _camera_pos.xz);

	float scale = MODEL_MATRIX[0][0];
	float vertex_lerp = smoothstep(
		0.55,
		0.95,
		(v_vertex_xz_dist / scale - _mesh_size - 4.0) / (_mesh_size - 2.0)
	);
	vec2 v_fract = fract(VERTEX.xz * 0.5) * 2.0;
	vec2 shift = scale < _vertex_spacing + 0.000001
		? mix(
			v_fract,
			vec2(v_fract.x, -v_fract.y),
			round(
				fract(round(mod(v_world_position.z * _vertex_density, 4.0))
				* round(mod(v_world_position.x * _vertex_density, 4.0)) * 0.25)
			)
		)
		: v_fract * round(
			(fract(v_world_position.xz * 0.25 / scale) - 0.5) * 4.0
		);
	vec2 start_pos = v_world_position.xz * _vertex_density;
	vec2 end_pos = (v_world_position.xz - shift * scale) * _vertex_density;
	v_world_position.xz -= shift * scale * vertex_lerp;

	ivec3 start_coord = get_index_coord(start_pos, VERTEX_PASS);
	if (_background_mode == 0u && start_coord.z < 0) {
		v_world_position.x = 0.0 / 0.0;
	} else {
		ivec3 end_coord = get_index_coord(end_pos, VERTEX_PASS);
		float height = mix(
			texelFetch(_height_maps, start_coord, 0).r,
			texelFetch(_height_maps, end_coord, 0).r,
			vertex_lerp
		);
		v_world_position.y = height;
	}

	VERTEX = (VIEW_MATRIX * vec4(v_world_position, 1.0)).xyz;
}


void fragment() {
	vec3 world_normal = normalize(
		cross(dFdyCoarse(v_world_position), dFdxCoarse(v_world_position))
	);
	world_normal *= sign(world_normal.y);
	NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float soil_weight = smoothstep(slope_start, slope_end, slope);
	float macro_variation =
		sin(v_world_position.x * 0.055) * cos(v_world_position.z * 0.043) * 0.035;
	ALBEDO = mix(grass_color, soil_color, soil_weight) + vec3(macro_variation);
	ROUGHNESS = 0.96;
}
