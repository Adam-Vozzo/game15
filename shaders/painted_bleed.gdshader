shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D paper : filter_linear_mipmap, repeat_enable;
uniform float bleed_strength=1.0;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float tooth=texture(paper,world_pos.xy*2.8+world_pos.z*.31).r;
    float fine=texture(paper,world_pos.xz*5.1+world_pos.y*.21).r;
    // glTF reverses source V: the source ribbon's outer edge imports at V=0.
    float feather=pow(1.0-smoothstep(.05,1.0,1.0-UV.y+(tooth-.5)*.22),1.8);
    feather*=smoothstep(0.0,.12,UV.x)*(1.0-smoothstep(.88,1.0,UV.x));
    if(COLOR.a<.25) {
        float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
        feather=smoothstep(.02,.48,facing);
    }
    float fade=exp(-pow(length(world_pos-CAMERA_POSITION_WORLD)/43.0,1.7));
    ALBEDO=clamp(COLOR.rgb+(tooth-.5)*.085,vec3(0),vec3(1));
    ALPHA=COLOR.a*feather*(.65+fine*.6)*fade*bleed_strength;
}
