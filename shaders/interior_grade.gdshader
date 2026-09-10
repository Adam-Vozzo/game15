shader_type canvas_item;
uniform sampler2D scene_texture:hint_screen_texture,filter_linear;
uniform bool reservoir=false;
void fragment(){
 vec3 col=texture(scene_texture,SCREEN_UV).rgb;
 vec3 halo=vec3(0.);
 for(int i=0;i<12;i++){
   float a=float(i)*6.2831853/12.;
   vec2 d=vec2(cos(a),sin(a));
   halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*5.).rgb-vec3(.62),vec3(0.))/12.;
   halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*16.).rgb-vec3(.65),vec3(0.))/24.;
 }
 col+=halo*(reservoir?.48:.9);
 col=pow(max(col,vec3(0.)),vec3(1.04));
 COLOR=vec4(col,1.);
}
