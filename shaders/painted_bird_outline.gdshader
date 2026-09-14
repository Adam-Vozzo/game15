shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
varying vec3 world_pos;
void vertex() {
    VERTEX+=NORMAL*.008;
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    float fade=1.0-exp(-pow(length(world_pos-CAMERA_POSITION_WORLD)/43.0,1.7));
    ALBEDO=mix(vec3(.27,.18,.30),vec3(1,.995,1),fade);
}
