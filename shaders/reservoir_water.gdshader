shader_type spatial;
render_mode unshaded,cull_back;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform float scene_time=0.;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
float rings(vec2 p,vec2 at,float offset){
 float age=mod(scene_time+offset,4.3);
 float d=length(p-at);
 return sin(d*27.-age*14.)*exp(-pow((d-age*.65)/.45,2.))*exp(-age*.65);
}
void fragment(){
 float wave=sin(wp.x*1.7+wp.z*2.3+scene_time*.19)*.3+sin(wp.z*4.1-scene_time*.14)*.2;
 wave+=rings(wp.xz,vec2(-7.,-8.),0.)+rings(wp.xz,vec2(3.5,-23.),1.4)+rings(wp.xz,vec2(-3.1,-41.),2.1);
 vec2 uv=vec2(SCREEN_UV.x,1.-SCREEN_UV.y)+vec2(wave*.0008,wave*.0004);
 vec3 reflected=texture(reflection_texture,uv).rgb;
 float fresnel=pow(1.-abs(dot(normalize(VIEW),NORMAL)),3.);
 vec3 col=mix(vec3(.045,.068,.075),reflected,.72+fresnel*.20);
 ALBEDO=col+wave*.005;
}
