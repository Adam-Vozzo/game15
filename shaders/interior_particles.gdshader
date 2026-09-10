shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
#include "res://shaders/interior_common.gdshaderinc"
uniform int mode=0;
uniform float scene_time=0.;
varying vec3 wp;
void vertex(){
 // Wrap the particle anchor, not its individual corners; otherwise a streak
 // stretches across the entire volume as its top crosses the cycle boundary.
 if(mode==0){float offset=(1.-UV.y)*.18;VERTEX.y=mod(VERTEX.y-offset-scene_time*7.,9.)+offset;VERTEX.x+=sin(scene_time*.24)*.20;}
 if(mode==1){float offset=(1.-UV.y)*.075;float span=VERTEX.x< -6.?2.2:84.;VERTEX.y=mod(VERTEX.y-offset-scene_time*2.8,span)+offset;}
 if(mode==2){VERTEX.x+=sin(scene_time*.17+VERTEX.z)*.27;VERTEX.y+=sin(scene_time*.13+VERTEX.x)*.20;}
 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment(){
 if(mode==0){ALBEDO=vec3(.36,.52,.61);ALPHA=.22;}
 if(mode==1){ALBEDO=vec3(.55,.65,.64);ALPHA=.50*smoothstep(0.,.15,wp.y);}
 if(mode==2){
   ALBEDO=vec3(.91,.92,.82);
   ALPHA=reservoir_beam(wp)*.62*(1.-smoothstep(.18,.51,length(UV-.5)));
 }
}
