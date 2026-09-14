shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform float scene_time=0.;
uniform float flash=0.;
varying float distance_fade;
void vertex(){
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    float seed=p.y;
    float speed=fract(sin(dot(p.xz,vec2(127.1,311.7)))*43758.5453);
    float travel=fract(seed-scene_time*(.19+speed*.035));
    p.y=-22.+travel*100.;
    p.x+=travel*7.;p.z+=travel*2.;
    vec3 right=INV_VIEW_MATRIX[0].xyz;
    float distance=length(p-CAMERA_POSITION_WORLD);
    float close_scale=smoothstep(.4,2.5,distance);
    p+=right*(UV.x-.5)*(.030+seed*.030)*close_scale;
    p+=vec3(.14,1.45,.04)*(UV.y-.5)*close_scale;
    distance_fade=exp(-distance*.016)*close_scale;
    VERTEX=(inverse(MODEL_MATRIX)*vec4(p,1.)).xyz;
}
void fragment(){
    float taper=pow(max(0.,sin(UV.y*3.14159)),.6);
    ALBEDO=vec3(.43,.55,.65)+vec3(.33,.35,.35)*flash;
    ALPHA=taper*distance_fade*(.35+flash*.35);
}
