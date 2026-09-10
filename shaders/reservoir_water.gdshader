shader_type spatial;
render_mode unshaded,cull_back;
#include "res://shaders/interior_common.gdshaderinc"
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform float scene_time=0.;
uniform float impact_strength=1.;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
float rings(vec2 p,vec2 at,float offset){
 float age=mod(scene_time+offset,4.3);
 float d=length(p-at);
 return sin(d*27.-age*14.)*exp(-pow((d-age*.65)/.45,2.))*exp(-age*.65);
}
float outlet(vec2 p){
 float d=length(p-vec2(-7.,-8.));
 return sin(d*34.-scene_time*14.)*exp(-d*1.45)*smoothstep(0.,.08,d)*impact_strength;
}
float surface(vec2 p){
 return sin(p.x*1.7+p.y*2.3+scene_time*.19)*.12+sin(p.y*4.1-scene_time*.14)*.07
 +outlet(p)*.9+rings(p,vec2(3.5,-23.),1.4)*.18+rings(p,vec2(-3.1,-41.),2.1)*.18+rings(p,vec2(30.,-80.),.4)*.18;
}
void fragment(){
 float wave=surface(wp.xz);
 vec2 slope=vec2(surface(wp.xz+vec2(.045,0.))-wave,surface(wp.xz+vec2(0.,.045))-wave)/.045;
 vec2 uv=clamp(vec2(SCREEN_UV.x,1.-SCREEN_UV.y)+slope*.0022,vec2(.001),vec2(.999));
 vec3 reflected=texture(reflection_texture,uv).rgb;
 float fresnel=pow(1.-abs(dot(normalize(VIEW),NORMAL)),3.);
 vec3 col=mix(vec3(.018,.028,.032),reflected,.70+fresnel*.23);
 float impact=exp(-length(wp.xz-vec2(-7.,-8.))*7.)*impact_strength;
 float crest=max(outlet(wp.xz),0.);
 col+=vec3(.30,.36,.37)*(crest*.19+impact*(.17+.05*sin(scene_time*17.)));
 col+=vec3(.48,.52,.53)*reservoir_beam(vec3(wp.x,.08,wp.z))*(.05+.035*wave);
 ALBEDO=col+wave*.007;
}
