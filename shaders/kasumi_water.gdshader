shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float scene_time=0.0;
#include "res://shaders/kasumi_sky.gdshaderinc"
varying vec3 world_p;
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-world_p);
    float wave=sin(world_p.x*3.1+world_p.z*.9+scene_time*.7)*.010+sin(world_p.z*8.-scene_time*.8)*.004;
    vec3 normal=normalize(vec3(wave,1.,wave*.5));
    vec3 reflected=reflect(-eye,normal);
    float fresnel=.14+.72*pow(1.-max(dot(eye,normal),0.),3.);
    vec3 sky=kasumi_sky(reflected,scene_time)*.67;
    vec3 mud=vec3(.038,.061,.062);
    vec2 cell=fract(world_p.xz*1.8)-.5;
    float age=fract(scene_time*.52+khash(vec3(floor(world_p.xz*1.8),0.)));
    float ring=1.-smoothstep(.011,.030,abs(length(cell)-age*.58));
    ALBEDO=mix(mud,sky,fresnel)+vec3(.08,.10,.11)*ring*(1.-age)*.15;
}
