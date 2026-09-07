shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D surface_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float snap = 0.15;
uniform float surface_brightness : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_normal;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec2 grid = VIEWPORT_SIZE * 0.6;
    vec2 snapped = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
    clip.xy = mix(clip.xy, snapped, snap);
    POSITION = clip;
}
void fragment() {
    vec3 pigment = texture(surface_texture, UV).rgb * tint;
    float light = 0.26 + 0.68 * max(dot(normalize(world_normal), normalize(vec3(-0.4,0.8,-0.5))), 0.0);
    float moss = smoothstep(0.45, 0.95, world_normal.y) * 0.12;
    ALBEDO = (pigment * light + vec3(0.010,0.018,0.009) * moss) * surface_brightness;
}

