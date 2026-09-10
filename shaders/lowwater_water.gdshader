shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float scene_time=0.;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
varying vec3 world_p;
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float centre=1.5+sin(world_p.z*.055)*1.3;
 float edge=abs(world_p.x-centre)/2.95;
 float ripple=sin(world_p.z*9.+sin(world_p.x*2.7+scene_time*.19)*.8+scene_time*.32);
 float fine=sin(world_p.z*23.+world_p.x*3.3-scene_time*.21);
 float opening=exp(-pow((world_p.z+26.)/22.,2.));
 vec2 uv=vec2(SCREEN_UV.x,1.-SCREEN_UV.y);
 uv.x+=ripple*.0006+fine*.0002;
 vec3 reflected=texture(reflection_texture,uv).rgb;
 vec3 col=mix(vec3(.11,.125,.10),reflected,.72);
 col*=1.-smoothstep(.72,1.,edge)*.4;
 col+=(ripple*.006+fine*.003)*(1.-edge);
 ALBEDO=col;
}
