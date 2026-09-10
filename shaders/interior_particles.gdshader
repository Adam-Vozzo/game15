shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
#include "res://shaders/interior_common.gdshaderinc"
uniform int mode=0;
uniform float scene_time=0.;
varying vec3 wp;
varying float life;
void vertex(){
 // Wrap the particle anchor, not its individual corners; otherwise a streak
 // stretches across the entire volume as its top crosses the cycle boundary.
 if(mode==0){float offset=(1.-UV.y)*.18;VERTEX.y=mod(VERTEX.y-offset-scene_time*7.,9.)+offset;VERTEX.x+=sin(scene_time*.24)*.20;}
 if(mode==1){float offset=(1.-UV.y)*.075;float span=VERTEX.x< -6.?2.2:84.;VERTEX.y=mod(VERTEX.y-offset-scene_time*2.8,span)+offset;}
 if(mode==2){VERTEX.x+=sin(scene_time*.17+VERTEX.z)*.27;VERTEX.y+=sin(scene_time*.13+VERTEX.x)*.20;}
 if(mode==3){
   float sag=(2.2-VERTEX.y)/2.2;
   VERTEX.x+=sin(VERTEX.y*23.-scene_time*18.)*.012*sag;
   VERTEX.z+=sin(VERTEX.y*17.-scene_time*21.)*.009*sag;
 }
 if(mode==4){
   vec3 anchor=VERTEX-vec3((UV.x-.5)*.034,(.5-UV.y)*.038,0.);
   float seed=fract(sin(dot(anchor.xz,vec2(91.17,71.3)))*43758.54);
   life=fract(scene_time*(1.4+seed*.7)+seed);
   vec2 direction=normalize(anchor.xz-vec2(-7.,-8.));
   anchor.xz=vec2(-7.,-8.)+direction*(.04+life*(.24+seed*.48));
   anchor.y=.025+sin(life*3.14159)*(.10+seed*.21);
   VERTEX=anchor+INV_VIEW_MATRIX[0].xyz*(UV.x-.5)*.034+INV_VIEW_MATRIX[1].xyz*(.5-UV.y)*.038;
 }
 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment(){
 if(mode==0){ALBEDO=vec3(.36,.52,.61);ALPHA=.22;}
 if(mode==1){ALBEDO=vec3(.55,.65,.64);ALPHA=.50*smoothstep(0.,.15,wp.y);}
 if(mode==2){
   ALBEDO=vec3(.91,.92,.82);
   ALPHA=reservoir_beam(wp)*.62*(1.-smoothstep(.18,.51,length(UV-.5)));
 }
 if(mode==3){ALBEDO=vec3(.43,.54,.57)+sin(wp.y*8.-scene_time*6.)*.045;ALPHA=.46+.06*sin(wp.y*30.-scene_time*16.);}
 if(mode==4){ALBEDO=vec3(.76,.83,.83);ALPHA=(1.-smoothstep(.2,.51,length(UV-.5)))*sin(life*3.14159)*.85;}
}
