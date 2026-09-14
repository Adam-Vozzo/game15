shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform sampler2D paper : filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
float h(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float n(vec2 p) {
    vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
float wash(vec2 p) { return n(p)*.53+n(p*2.17+13.2)*.27+n(p*4.63-17.4)*.14+n(p*9.1)*.06; }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
    vec2 p=world_pos.xy*.8+world_pos.z*.17;
    float pigment=wash(p+vec2(wash(p+8.1),wash(p-17.0))*1.5);
    float grain=texture(paper,world_pos.xy*2.8).r;
    float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
    // Feather only the silhouette; pigment and paper never track the camera.
    float feather=smoothstep(.0,.33+(grain-.5)*.15,facing);
    vec3 col=mix(vec3(.83,.44,.92),vec3(.41,.26,.84),smoothstep(.12,.91,UV.y+pigment*.17));
    col=mix(col,vec3(.98,.81,.97),smoothstep(.59,.78,pigment)*.53);
    col+=(grain-.5)*.12;
    float fade=1.0-exp(-pow(length(world_pos-CAMERA_POSITION_WORLD)/43.0,1.7));
    ALBEDO=mix(col,vec3(1,.995,1),fade);
    ALPHA=feather*(.54+pigment*.31)*(1.0-smoothstep(.85,1.0,abs(UV.y-.5)*2.0)*.6);
}
