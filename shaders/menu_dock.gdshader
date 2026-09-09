shader_type canvas_item;
uniform vec2 panel_size=vec2(1280.,170.);
void fragment(){
 float curve=.08+.43*exp(-pow(abs(UV.x-.5)/.30,4.));
 float d=(UV.y-curve)*panel_size.y;
 vec3 col=mix(vec3(.68,.71,.75),vec3(.85,.87,.89),smoothstep(.1,1.,UV.y));
 col=mix(vec3(.30,.72,.83),col,smoothstep(1.,4.,d));
 COLOR=vec4(col,smoothstep(-1.,1.,d));
}
