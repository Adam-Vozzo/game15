shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
#include "res://shaders/sea_waves.gdshaderinc"
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
 vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 pos=(INV_VIEW_MATRIX*v).xyz;
 vec3 ray=normalize(pos-origin);bool sky=depth<.00001;
 float distance=sky?650.:length(pos-origin);
 vec3 col=texture(scene_texture,SCREEN_UV).rgb;
 vec3 moon=normalize(vec3(-.32,.48,-.8));float alignment=max(dot(ray,moon),0.);
 if(sky){
   vec2 cp=ray.xz/max(.12,ray.y+.2)*2.;
   float cloud=sea_noise(cp+vec2(atmosphere_time*.015,0.))*.65+sea_noise(cp*3.-atmosphere_time*.01)*.35;
   col=mix(vec3(.025,.043,.052),vec3(.070,.107,.112),clamp(ray.y*.7+.3,0.,1.));
   col*=.55+cloud*.55;
   col+=vec3(.12,.17,.16)*pow(alignment,18.)*(1.-cloud*.8);
   col+=vec3(.39,.47,.39)*smoothstep(.9986,.9995,alignment)*smoothstep(.25,.6,cloud);
 }else{
   float fog=1.-exp(-max(distance-7.,0.)*.016);
   col=mix(col,vec3(.044,.077,.082),fog*.94);
 }
 // Rain outside the cabin: depth rejects all interior surfaces.
 vec2 rain=SCREEN_UV*vec2(230.,16.);rain.x+=SCREEN_UV.y*13.;rain.y-=atmosphere_time*10.;
 vec2 cell=floor(rain),f=fract(rain);
 float streak=(1.-smoothstep(.01,.07,abs(f.x-.5)))*smoothstep(.1,.8,f.y)*step(.88,sea_hash(cell));
 col+=vec3(.10,.16,.17)*streak*smoothstep(4.,9.,distance)*.65;
 // Small warm halo around the actual cabin lamp, without screen-space occlusion.
 vec3 glow=vec3(0.);
 for(int i=0;i<12;i++){
   float a=float(i)*2.39996;vec2 offset=vec2(cos(a),sin(a))*(3.+float(i))/VIEWPORT_SIZE;
   vec3 s=texture(scene_texture,clamp(SCREEN_UV+offset,vec2(0.),vec2(1.))).rgb;
   glow+=s*smoothstep(.65,.95,s.r)*smoothstep(.15,.4,s.r-s.b)*.055;
 }
 col+=glow*vec3(1.,.67,.3);
 float vignette=1.-.20*smoothstep(.25,.73,length(SCREEN_UV-.5));
 col=pow(max(col,vec3(0.)),vec3(1.06))*vignette;
 float dither=(sea_hash(floor(FRAGCOORD.xy))-.5)/100.;
 ALBEDO=floor(clamp(col+dither,0.,1.)*63.+.5)/63.;
}
