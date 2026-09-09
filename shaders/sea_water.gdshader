shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float sea_time=0.;
uniform mat4 boat_inverse;
#include "res://shaders/sea_waves.gdshaderinc"
varying vec3 water_position;
void vertex(){vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.y=swell(world.xz,sea_time);water_position=vec3(world.x,VERTEX.y,world.z);}
void fragment(){
 vec3 hull=(boat_inverse*vec4(water_position,1.)).xyz;
 float hull_width=hull.z < -4.1 ? max(0.,(hull.z+5.9)/1.8)*1.17 : (hull.z < -2.2 ? mix(1.17,1.7,(hull.z+4.1)/1.9) : 1.7);
 // Occlusion is confined BELOW the solid deck. Never cut an exposed wave crest.
 if(hull.y < .80 && hull.z > -5.9 && hull.z < 2.7 && abs(hull.x)<hull_width*.98){discard;}
 vec2 p=water_position.xz;float h=swell(p,sea_time);
 vec2 slope=vec2(swell(p+vec2(.12,0),sea_time)-h,swell(p+vec2(0,.12),sea_time)-h)/.12;
 vec3 normal=normalize(vec3(-slope.x,1.,-slope.y));
 float grain=sea_noise(p*6.+vec2(sea_time*.18,0.));
 normal=normalize(normal+vec3((grain-.5)*.11,0.,(sea_noise(p*3.-sea_time*.3)-.5)*.12));
 vec3 eye=normalize(CAMERA_POSITION_WORLD-water_position);
 float rim=pow(1.-max(dot(normal,eye),0.),3.);
 vec3 color=mix(vec3(.018,.051,.055),vec3(.060,.151,.149),clamp(h*.26+.42,0.,1.));
 color+=rim*vec3(.035,.060,.064);
 vec3 moon=normalize(vec3(-.32,.48,-.8));
 float spec=pow(max(dot(reflect(-moon,normal),eye),0.),60.);
 color+=vec3(.38,.53,.49)*spec*(.45+grain*.55);
 float crest=smoothstep(.48,1.3,h)*smoothstep(.27,.62,grain);
 float broken=step(.53,sea_noise(p*11.+sea_time*.28));
 color=mix(color,vec3(.47,.59,.53),crest*broken*.92);
 // A feathered wake around the hull, never a flat second water plane.
 float wake=exp(-pow((abs(p.x)-1.85)/.55,2.))*smoothstep(-5.,-1.,p.y)*(1.-smoothstep(2.,8.,p.y));
 color+=vec3(.19,.26,.24)*wake*step(.60,grain);
 ALBEDO=color;
}
