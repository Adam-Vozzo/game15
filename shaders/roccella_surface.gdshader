shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform vec4 tint:source_color=vec4(.5,.5,.5,1);
uniform bool textured=true;
uniform bool luminous=false;
uniform bool sea=false;
uniform bool paving=false;
uniform float flash=0.;
uniform float scene_time=0.;
uniform vec3 lamps[24];
uniform int lamp_count=0;
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec3 n=normalize(wn);
    vec3 base=textured?texture(base_texture,UV).rgb:tint.rgb;
    float exposure=.15+.14*max(dot(n,normalize(vec3(-.4,.8,.3))),0.);
    vec3 col=base*vec3(.63,.78,1.0)*exposure;
    col+=base*flash*(.42+.65*abs(dot(n,normalize(vec3(.3,.8,-.5)))))*vec3(.73,.84,1.);
    for(int i=0;i<24;i++){
        if(i>=lamp_count){break;}
        vec3 d=lamps[i]-wp;float dist=length(d);
        float lit=max(.14,dot(n,normalize(d)));
        col+=base*vec3(1.0,.49,.16)*exp(-dist*.49)*lit*1.3;
    }
    if(luminous){col=vec3(.95,.46,.13)*(.86+flash*.10);}
    if(paving){
        vec2 tile=floor(wp.xz*1.2);vec2 p=fract(wp.xz*1.2)-.5;
        float phase=fract(scene_time*1.55+hash(tile));
        float ring=exp(-abs(length(p)-phase*.48)*90.)*(1.-phase);
        float wet=smoothstep(.26,.60,hash(floor(wp.xz*.55)));
        col+=vec3(.06,.10,.14)*wet*(.3+flash)+ring*vec3(.08,.12,.16)*(.3+flash);
        // Thin rivulets are attached to the sloping stone stair.
        float stream=pow(.5+.5*sin(wp.x*18.+sin(wp.z*.42)*.6),26.);
        col+=vec3(.035,.065,.09)*stream*(.6+.4*sin(wp.z*3.+scene_time*8.));
    }
    if(sea){
        float wave=sin(wp.z*.41+scene_time*.8+sin(wp.x*.065))*sin(wp.x*.07+wp.z*.14-scene_time*.56);
        col=vec3(.035,.061,.075)+vec3(.065,.09,.105)*flash;
        col+=pow(max(0.,wave),7.)*vec3(.08,.12,.14)*(.5+flash);
    }
    ALBEDO=col;
}
