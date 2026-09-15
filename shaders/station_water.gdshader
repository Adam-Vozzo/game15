shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform sampler2D scene_texture:hint_screen_texture,filter_linear;
uniform float scene_time=0.;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 vec2 rip=vec2(sin(p.y*2.4+sin(p.x*1.3)+scene_time*.9),cos(p.x*3.2+sin(p.y*1.8)-scene_time*.7))*.018;
 vec3 n=normalize(vec3(rip.x,1.,rip.y));vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
 float fr=.22+.65*pow(1.-max(dot(n,eye),0.),3.);
 vec3 reflection=texture(reflection_texture,clamp(vec2(SCREEN_UV.x,1.-SCREEN_UV.y)+rip*.13,vec2(.003),vec2(.997))).rgb;
 vec3 below=texture(scene_texture,SCREEN_UV+rip*.06).rgb;
 vec3 water=mix(below*vec3(.35,.85,.75),vec3(.025,.47,.49),.58);
 vec3 col=mix(water,reflection*.92,fr*.75);
 float glint=pow(max(0.,dot(n,normalize(normalize(vec3(.44,.81,.40))+eye))),150.);
 float rings=0.;
 for(int side=0;side<2;side++)for(int row=0;row<2;row++){
   vec2 centre=vec2(side==0?-8.8:9.,row==0?-30.:-10.);float r=length(p-centre);float phase=fract(scene_time*.68+float(side)*.31+float(row)*.17);
   rings+=exp(-pow((r-phase*1.0)/.028,2.))*(1.-phase)*.65;
 }
 col+=vec3(.63,.83,.58)*glint*.35+vec3(.35,.67,.58)*rings;
 ALBEDO=mix(col,vec3(.45,.69,.64),1.-exp(-distance(CAMERA_POSITION_WORLD,wp)*.003));
 ALPHA=.94;
}
