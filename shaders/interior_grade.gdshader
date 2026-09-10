shader_type canvas_item;
uniform sampler2D scene_texture:hint_screen_texture,filter_linear;
uniform bool reservoir=false;
void fragment(){
 vec3 col=texture(scene_texture,SCREEN_UV).rgb;
 vec3 halo=vec3(0.);
 for(int i=0;i<12;i++){
   float a=float(i)*6.2831853/12.;
   vec2 d=vec2(cos(a),sin(a));
   halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*4.).rgb-vec3(.52),vec3(0.))/12.;
   halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*12.).rgb-vec3(.56),vec3(0.))/20.;
   halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*30.).rgb-vec3(.64),vec3(0.))/28.;
 }
 // A scene-local print curve separates deep shelter from luminous openings.
 col=max((col-vec3(reservoir?.045:.015))*(reservoir?1.28:1.16),vec3(0.));
 col+=halo*(reservoir?.95:1.45);
 col=pow(col,vec3(reservoir?1.10:.96));
 float vignette=1.-.13*smoothstep(.25,.78,length((UV-.5)*vec2(1.,.8)));
 col*=vignette;
 COLOR=vec4(col,1.);
}
