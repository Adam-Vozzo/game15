shader_type spatial;
render_mode unshaded,cull_back;
#include "res://shaders/interior_common.gdshaderinc"
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform bool textured=false;
uniform bool reservoir=false;
uniform bool road=false;
uniform bool reflective_floor=false;
uniform bool metallic=false;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform int glow_kind=0;
uniform float scene_time=0.;
uniform vec3 car_position=vec3(0.);
uniform vec3 car_direction=vec3(1.,0.,0.);
varying vec3 wp;
varying vec3 wn;
float hash31(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float weather_noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 // The reflection camera must not see submerged pier faces or the basin bed.
 if(reservoir && CAMERA_POSITION_WORLD.y<0. && wp.y<.015){discard;}
 vec3 base=COLOR.rgb;
 if(textured){base*=texture(base_texture,UV).rgb;}
 vec3 col;
 if(reservoir){
   float height=clamp(wp.y/84.,0.,1.);
   float shelter=.18+.72*max(dot(wn,normalize(vec3(.55,.66,.43))),0.);
   float wet=mix(.42,1.,smoothstep(-.15,1.7+weather_noise(wp*.3)*1.2,wp.y));
   // Long water stains use geometry/world coordinates, fixed during free look.
   float streak=weather_noise(wp*vec3(.62,.11,.62));
   float mottling=weather_noise(wp*.37)*.17+weather_noise(wp*2.7)*.09;
   base*=wet*(.83+mottling)*mix(.94,1.02,smoothstep(.28,.65,streak));
   col=base*(shelter+height*.16+reservoir_beam(wp)*1.1);
   if(glow_kind==5){col=vec3(1.,1.,.95);}
   float fog=1.-exp(-max(length(VERTEX)-10.,0.)*.0062);
   col=mix(col,vec3(.39,.43,.45),fog);
 }else{
   bool inside=wp.z> -5.05 && abs(wp.x)<6.15;
   float light=.18;
   if(inside){
     vec3 illumination=vec3(.23,.22,.19);
     for(int i=0;i<4;i++){
       vec3 fixture=vec3((i%2==0)?-2.5:2.5,3.08,(i<2)?-2.2:2.2);
       vec3 delta=fixture-wp;float d=length(delta);
       float power=(i==0)?fixture_power(scene_time):1.;
       illumination+=vec3(1.,.86,.65)*power*(.18+.82*max(dot(wn,normalize(delta)),0.))/(1.+d*d*.28)*.78;
     }
     illumination+=vec3(.04,.10,.17)*exp(-abs(wp.z+5.)*.35);
     col=base*illumination;
     if(metallic){
       vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
       for(int i=0;i<4;i++){
         vec3 to_light=vec3(i%2==0?-2.5:2.5,3.08,i<2?-2.2:2.2)-wp;
         vec3 direction=normalize(to_light);
         col+=vec3(.14,.13,.11)*pow(max(dot(wn,normalize(eye+direction)),0.),48.)/(1.+dot(to_light,to_light)*.14);
       }
     }
   }else{
     light=.30+.23*max(dot(wn,normalize(vec3(-.2,.8,.4))),0.);
     col=base*vec3(.57,.77,1.)*light;
     for(int i=0;i<2;i++){
       vec3 delta=vec3(i==0?-13.:13.,5.35,-8.1)-wp;
       col+=base*vec3(.73,.77,.71)*max(dot(wn,normalize(delta)),.1)*2.2/(1.+dot(delta,delta)*.2);
     }
   }
   float pink=exp(-length((wp-vec3(.15,2.6,-4.9))*vec3(.65,.75,.55))*.85);
   float blue=exp(-length((wp-vec3(-7.5,3.7,-27.2))*vec3(.25,.45,.20))*.8);
   col+=base*(pink*vec3(.70,.035,.15)+blue*vec3(.025,.43,.52));
   if(reflective_floor && wp.y<.05 && wn.y>.9){
     vec3 reflected=texture(reflection_texture,vec2(SCREEN_UV.x,1.-SCREEN_UV.y)).rgb;
     col=mix(col,reflected,.09);
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
   if(glow_kind==3){col=vec3(1.,.86,.61)*(wp.x<0. && wp.z<0.?fixture_power(scene_time):1.);}
   if(glow_kind==4){col=vec3(1.,.91,.69);}
   if(!inside && glow_kind==0){col=mix(col,vec3(.025,.045,.066),1.-exp(-length(VERTEX)*.012));}
 }
 ALBEDO=clamp(col,0.,1.);
}
