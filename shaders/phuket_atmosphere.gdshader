shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,91.8)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
 vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 world=(INV_VIEW_MATRIX*v).xyz;vec3 ray=normalize(world-origin);
 bool background=depth<.00001;float dist=background?1200.:length(world-origin);
 vec3 sun=normalize(vec3(-.38,.95,-.48));
 vec3 color=texture(scene_texture,SCREEN_UV).rgb;
 if(background){
   color=mix(vec3(.57,.81,.91),vec3(.045,.30,.66),smoothstep(-.06,.75,ray.y));
   vec3 q=ray*(4./max(ray.y+.13,.08))+vec3(atmosphere_time*.006,0,0);
   float cloud=noise(q)*.57+noise(q*2.1)*.28+noise(q*4.2)*.15;
   float mask=smoothstep(.60,.77,cloud)*smoothstep(.035,.18,ray.y);
   color=mix(color,vec3(.99,.99,.91),mask*.9);
   float a=max(dot(ray,sun),0.);
   color+=vec3(1.,.94,.72)*pow(a,64.)*.19;
   color=mix(color,vec3(1.),smoothstep(.99965,.99987,a));
 }else{
   float haze=1.-exp(-dist*.00115);
   float ribbon=exp(-pow((world.y-22.-sin(world.x*.011+atmosphere_time*.025)*9.)/20.,2.));
   haze=clamp(haze+ribbon*smoothstep(85.,250.,dist)*.23,0.,.78);
   color=mix(color,vec3(.57,.78,.84),haze);
 }
 // Lens ghosts are tied to the sun and rejected when it is behind solid geometry.
 vec4 sun_clip=PROJECTION_MATRIX*VIEW_MATRIX*vec4(origin+sun*500.,1.);
 vec2 sun_uv=sun_clip.xy/sun_clip.w*.5+.5;
 float visible=step(0.,sun_clip.w)*step(0.,sun_uv.x)*step(sun_uv.x,1.)*step(0.,sun_uv.y)*step(sun_uv.y,1.);
 float unblocked=0.;
 for(int i=0;i<5;i++){vec2 off=vec2(float(i-2)*.002,0);unblocked+=step(texture(depth_texture,clamp(sun_uv+off,vec2(0.),vec2(1.))).r,.00001)*.2;}
 vec2 aspect=vec2(VIEWPORT_SIZE.x/VIEWPORT_SIZE.y,1.);
 float halo=exp(-length((SCREEN_UV-sun_uv)*aspect)*25.);
 vec3 flare=vec3(1.,.76,.40)*halo*.28;
 flare+=vec3(.28,.21,.11)*exp(-abs(SCREEN_UV.y-sun_uv.y)*240.)*exp(-abs(SCREEN_UV.x-sun_uv.x)*15.);
 for(int i=0;i<3;i++){
   vec2 centre=mix(sun_uv,vec2(.5),1.35+float(i)*.50);
   float r=length((SCREEN_UV-centre)*aspect);
   flare+=vec3(.12,.21,.16)*(1.-smoothstep(.021+float(i)*.011,.033+float(i)*.015,r))*.23;
 }
 color+=flare*visible*unblocked;
 ALBEDO=floor(clamp(color,0.,1.)*127.+.5)/127.;
}
