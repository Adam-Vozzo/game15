shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform float scene_time=0.;
uniform float flash=0.;
uniform bool runoff=false;
varying float fade;
varying float phase;
varying vec3 wp;
void vertex(){
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    float seed=fract(sin(dot(p.xz,vec2(127.1,311.7)))*43758.5453);
    phase=fract(scene_time*(1.3+seed*.8)+seed*17.);
    fade=exp(-length(p-CAMERA_POSITION_WORLD)*.055);
    if(!runoff){
        float age=min(phase/.38,1.);
        p+=INV_VIEW_MATRIX[0].xyz*(UV.x-.5)*(.09+age*.09);
        p.y+=UV.y*.10*4.*age*(1.-age);
        fade*=1.-smoothstep(.22,.38,phase);
    }
    wp=p;VERTEX=(inverse(MODEL_MATRIX)*vec4(p,1.)).xyz;
}
void fragment(){
    float shape;
    if(runoff){
        float strands=.5+.5*sin(UV.x*24.+sin(UV.y*7.-scene_time*13.));
        shape=pow(strands,3.)*sin(UV.x*3.14159)*(.35+.25*sin(UV.y*25.-scene_time*19.));
    }else{
        // Two outward jets and a short central droplet, not a flat splash card.
        float jets=exp(-pow((abs(UV.x-.5)-(.10+UV.y*.30))/.055,2.));
        float drop=exp(-pow((UV.x-.5)/.05,2.))*smoothstep(.6,.85,UV.y);
        shape=(jets+drop)*sin(UV.y*3.14159);
    }
    ALBEDO=vec3(.40,.57,.66)+vec3(.4,.4,.35)*flash;
    ALPHA=clamp(shape*fade*(.45+flash*.25),0.,.9);
}
