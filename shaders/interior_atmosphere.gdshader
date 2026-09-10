shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
#include "res://shaders/interior_common.gdshaderinc"
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform bool reservoir=false;
uniform float atmosphere_time=0.;
uniform float shaft_strength=1.;
uniform int fog_steps=36;
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 vec3 col=texture(scene_texture,SCREEN_UV).rgb;
 if(reservoir){
   float depth=texture(depth_texture,SCREEN_UV).r;
   vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
   vec3 origin=INV_VIEW_MATRIX[3].xyz;
   vec3 pos=(INV_VIEW_MATRIX*v).xyz;
   vec3 ray=normalize(pos-origin);
   float distance=min(length(pos-origin),260.);
   float sum=0.;
   // World-space aperture projection. No camera-facing shaft cards or hard
   // screen-space shading cutoffs. Near-weighted samples preserve close beams.
   float previous=0.;
   for(int i=0;i<48;i++){
     if(i>=fog_steps){break;}
     float f=(float(i)+1.)/float(fog_steps);
     float end=f*f*distance;
     float step_length=end-previous;
     vec3 p=origin+ray*(previous+step_length*.5);
     float air=.91+.09*sin(p.x*.29+p.z*.19+atmosphere_time*.045);
     sum+=reservoir_beam(p)*air*step_length*exp(-(previous+step_length*.5)*.011);
     previous=end;
   }
   col+=vec3(.59,.65,.64)*(1.-exp(-sum*.026))*shaft_strength;
 }
 ALBEDO=col;
}
