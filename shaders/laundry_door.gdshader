shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float scene_time=0.;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=(UV-.5)*2.;
 float radius=length(p);
 vec3 normal=normalize(vec3(sqrt(max(1.-dot(p,p)*.45,.03)),p.y*.67,p.x*.67));
 vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
 vec3 light=normalize(vec3(-2.5,3.08,wp.z<0.?-2.2:2.2)-wp);
 float shine=pow(max(dot(normal,normalize(eye+light)),0.),38.);
 float rim=smoothstep(.80,.99,radius);
 ALBEDO=vec3(.32,.43,.44)+vec3(.58,.51,.33)*shine;
 ALPHA=.025+rim*.07+shine*.30;
}
