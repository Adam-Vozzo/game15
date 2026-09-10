shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture:hint_screen_texture,filter_linear,repeat_disable;
// A channel-specific photographic print curve, applied after water and mist.
// No grain, camera-space material shading, or simulated damaged-plate marks.
void fragment(){
 vec3 source=texture(screen_texture,SCREEN_UV).rgb;
 float value=dot(source,vec3(.299,.587,.114));
 float glow=0.;
 float nearby=0.;
 for(int i=0;i<12;i++){
   float angle=float(i)*2.399963;
   vec2 offset=vec2(cos(angle),sin(angle))*(2.+float(i))*SCREEN_PIXEL_SIZE;
   vec3 sample_color=texture(screen_texture,clamp(SCREEN_UV+offset,vec2(0.),vec2(1.))).rgb;
   float light=dot(sample_color,vec3(.299,.587,.114));
   nearby+=light/12.;
   glow+=smoothstep(.49,.68,light)/12.;
 }
 value=mix(value,nearby,.085);
 float print_value=smoothstep(.115,.655,value);
 print_value=clamp(print_value+glow*.075,0.,1.);
 // Near-neutral blacks and warm paper whites retain just a trace of silver/olive.
 COLOR=vec4(mix(vec3(.003,.004,.004),vec3(1.,.995,.965),print_value),1.);
}
