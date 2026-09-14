shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
varying vec3 world_pos;
void vertex() {
    VERTEX+=NORMAL*.065;
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment() {
    float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
    float fade=1.0-exp(-pow(length(world_pos-CAMERA_POSITION_WORLD)/36.0,1.7));
    ALBEDO=mix(vec3(.25,.18,.32),vec3(1,.995,1),fade);
    ALPHA=(1.0-smoothstep(.035,.12,facing))*.90*(1.0-fade);
}
