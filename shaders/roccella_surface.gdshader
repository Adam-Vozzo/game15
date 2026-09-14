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
uniform float reflection_height=-1000.;
uniform vec3 lamps[24];
uniform int lamp_count=0;
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void fragment(){
    bool mirrored=CAMERA_POSITION_WORLD.y<reflection_height-.20;
    if(mirrored && wp.y<reflection_height+.005){discard;}
    vec3 n=normalize(wn);
    vec3 base=textured?texture(base_texture,UV).rgb:tint.rgb;
    if(paving){base*=.52+.18*noise(wp.xz*.65);}
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
    if(paving && n.y>.5){
        vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
        float sheen=pow(1.-max(dot(n,eye),0.),3.);
        col+=vec3(.045,.073,.088)*sheen*(.45+flash)*(.3+.7*noise(wp.xz*.8));
        float stream=pow(.5+.5*sin(wp.x*13.+sin(wp.z*.62)),18.);
        col+=vec3(.022,.038,.047)*stream*(.55+.45*sin(wp.z*4.+scene_time*7.))*(.4+flash);
    }
    if(sea){
        float wave=sin(wp.z*.41+scene_time*.8+sin(wp.x*.065))*sin(wp.x*.07+wp.z*.14-scene_time*.56);
        col=vec3(.035,.061,.075)+vec3(.065,.09,.105)*flash;
        col+=pow(max(0.,wave),7.)*vec3(.08,.12,.14)*(.5+flash);
    }
    if(mirrored){col=mix(col,vec3(.055,.078,.095),1.-exp(-length(wp-CAMERA_POSITION_WORLD)*.018));}
    ALBEDO=col;
}
