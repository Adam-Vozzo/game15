shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float wind_time=0.0;
uniform float wind_height=0.8;
uniform vec3 dry_color : source_color = vec3(0.12,0.16,0.125);
varying float blade_height;
varying float variation;
void vertex() {
    // Blender/glTF flips UV.y on export. Local height keeps the roots fixed
    // regardless of texture coordinates, with more bending toward the tips.
    blade_height = clamp(VERTEX.y / max(wind_height, 0.001), 0.0, 1.0);
    vec3 root=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
    variation=fract(sin(dot(root.xz,vec2(12.9,78.2)))*43758.5);
    float bend=blade_height*blade_height;
    float gust=sin(root.x*.17+root.z*.11-wind_time*1.9)*.15+sin(root.z*.57-wind_time*3.4)*.07;
    VERTEX.x+=bend*(.12+gust);
    VERTEX.z+=bend*sin(wind_time*2.0+root.x)*.045;
}
void fragment() {
    ALBEDO = dry_color * (0.55 + blade_height*0.60 + variation*0.3);
}
