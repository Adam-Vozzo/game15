shader_type canvas_item;
uniform float menu_time = 0.0;
void fragment() {
    vec2 uv = UV;
    float band = sin(uv.y * 1050.0) * .006;
    float glow = exp(-length((uv-vec2(.5,.36))*vec2(1.0,1.2))*3.0);
    vec3 color = mix(vec3(.84,.86,.87),vec3(.98,.985,.985),glow);
    color += band;
    color += .009*sin(uv.x*4.0+menu_time*.08);
    COLOR=vec4(color,1.0);
}
