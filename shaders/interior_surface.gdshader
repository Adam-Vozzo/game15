shader_type spatial;
render_mode unshaded,cull_back;
#include "res://shaders/interior_common.gdshaderinc"
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform bool textured=false;
uniform bool reservoir=false;
uniform bool road=false;
uniform bool reflective_floor=false;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform int glow_kind=0;
uniform float scene_time=0.;
uniform vec3 car_position=vec3(0.);
uniform vec3 car_direction=vec3(1.,0.,0.);
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 // The reflection camera must not see submerged pier faces or the basin bed.
 if(reservoir && CAMERA_POSITION_WORLD.y<0. && wp.y<.015){discard;}
 vec3 base=COLOR.rgb;
 if(textured){base*=texture(base_texture,UV).rgb;}
 vec3 col;
 if(reservoir){
   float height=clamp(wp.y/84.,0.,1.);
   float shelter=.38+.32*max(dot(wn,normalize(vec3(.35,.8,.3))),0.);
   float wet=1.-.42*exp(-max(wp.y,0.)*.55);
   // Long water stains use geometry/world coordinates, fixed during free look.
   float streak=sin(wp.x*1.43+wp.z*2.1+sin(wp.x*.63+wp.z*.87))*sin(wp.x*5.3+wp.z*4.1);
   base*=wet*(.97-.05*smoothstep(.3,.9,streak));
   col=base*(shelter+height*.20+reservoir_beam(wp)*.7);
   if(glow_kind==5){col=vec3(1.,1.,.95);}
   float fog=1.-exp(-length(VERTEX)*.012);
   col=mix(col,vec3(.44,.49,.50),fog);
 }else{
   bool inside=wp.z> -5.05 && abs(wp.x)<6.15;
   float light=.18;
   if(inside){
     light=.35+.38*fixture_power(scene_time);
     light*=.72+.28*max(wn.y,0.);
   }else{light=.42+.25*max(wn.y,0.);}
   col=base*light;
   float pink=exp(-length((wp-vec3(.15,2.6,-4.9))*vec3(.65,.75,.55))*.85);
   float blue=exp(-length((wp-vec3(-7.5,3.7,-27.2))*vec3(.25,.45,.20))*.8);
   col+=base*(pink*vec3(.70,.035,.15)+blue*vec3(.025,.43,.52));
   if(reflective_floor && wp.y<.05 && wn.y>.9){
     vec3 reflected=texture(reflection_texture,vec2(SCREEN_UV.x,1.-SCREEN_UV.y)).rgb;
     col=mix(col,reflected,.16);
     col+=vec3(.20,.004,.035)*exp(-pow((wp.x-.15)/1.4,2.))*exp(-abs(wp.z+5.)*.4);
   }
   if(road){
     // Elongated wet neon reflections are located beneath actual signs.
     float streak= .7+.3*sin(wp.z*13.+sin(wp.x*31.)+scene_time*.13);
     col+=vec3(.42,.014,.07)*exp(-pow((wp.x-.15)/1.2,2.))*exp(-abs(wp.z+6.)*.22)*streak;
     col+=vec3(.008,.21,.27)*exp(-pow((wp.x+7.5)/1.6,2.))*exp(-abs(wp.z+24.)*.13)*streak;
     vec3 relative=wp-car_position;
     float along=dot(relative,car_direction);
     float lateral=length(relative-car_direction*along);
     col+=vec3(.36,.32,.22)*smoothstep(1.,3.,along)*(1.-smoothstep(4.,14.,along))*exp(-pow(lateral/(.6+max(along,0.)*.13),2.));
   }
   if(glow_kind==1){col=vec3(1.,.075,.25);}
   if(glow_kind==2){col=vec3(.11,.86,.93)*(.94+.06*sin(scene_time*.7));}
   if(glow_kind==3){col=vec3(.72,.92,.84)*fixture_power(scene_time);}
   if(glow_kind==4){col=vec3(1.,.91,.69);}
   if(!inside && glow_kind==0){col=mix(col,vec3(.025,.045,.066),1.-exp(-length(VERTEX)*.012));}
 }
 ALBEDO=clamp(col,0.,1.);
}
