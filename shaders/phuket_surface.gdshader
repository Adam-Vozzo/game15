shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform float scene_time=0.;
uniform float palm_motion=0.;
uniform float sand_surface=0.;
uniform float limestone=0.;
varying vec3 world_p;
varying vec3 world_n;
void vertex(){
 if(palm_motion>.5){float tip=clamp(length(VERTEX.xz)/5.,0.,1.);VERTEX.x+=tip*tip*sin(scene_time*.9+VERTEX.z*.8)*.16;VERTEX.y+=tip*sin(scene_time*1.2+VERTEX.x)*.06;}
 world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 world_n=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
 vec3 c=texture(base_texture,UV).rgb*COLOR.rgb;
 if(limestone>.5){
   vec3 w=pow(abs(world_n),vec3(4.));w/=max(dot(w,vec3(1.)),.001);
   c=(texture(base_texture,world_p.zy*vec2(.022,.011)).rgb*w.x+texture(base_texture,world_p.xz*.025).rgb*w.y+texture(base_texture,world_p.xy*vec2(.022,.011)).rgb*w.z)*COLOR.rgb;
 }
 if(sand_surface>.5){
  float wet=1.-smoothstep(-.5,3.8+sin(scene_time*.63)*.5,world_p.z);
  c=mix(c,c*vec3(.67,.77,.81),wet*.53);
  c*=.96+.04*sin(world_p.x*.17+world_p.z*.23);
 }
 if(!FRONT_FACING){NORMAL=-NORMAL;}
 ALBEDO=c;ROUGHNESS=.86;
}
