shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void vertex() { POSITION=vec4(VERTEX.xy,1.0,1.0); }
void fragment() { ALBEDO=texture(screen_texture,SCREEN_UV).rgb; }
