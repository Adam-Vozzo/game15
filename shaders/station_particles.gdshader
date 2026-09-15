shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform float scene_time=0.;
uniform bool mote=false;
varying vec3 wp;
varying float seed;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;seed=COLOR.r;
 if(mote){VERTEX.x+=sin(scene_time*.17+wp.z)*.5;VERTEX.z+=cos(scene_time*.15+wp.x)*.4;VERTEX.y+=sin(scene_time*.21+wp.x+wp.z)*.7;}
}
void fragment(){
 if(mote){ALBEDO=vec3(.92,.99,.61);ALPHA=.32*(1.-smoothstep(.18,.50,length(UV-.5)));}
 else{float streak=pow(.5+.5*sin(wp.y*8.+scene_time*12.+wp.x),5.);float core=1.-smoothstep(.05,.48,abs(UV.x-.5));ALBEDO=vec3(.56,.88,.82);ALPHA=core*(.18+streak*.31);}
}
