shader_type spatial;
render_mode cull_disabled;
uniform float sea_time=0.;
varying vec3 local_p;
void vertex(){
 local_p=VERTEX;
 float tail=smoothstep(0.,9.,VERTEX.z);
 VERTEX.y+=sin(sea_time*1.05-VERTEX.z*.24)*tail*.8;
}
void fragment(){
 float belly=1.-smoothstep(-1.2,.15,local_p.y);
 float mottling=sin(local_p.x*13.+sin(local_p.z*5.))*sin(local_p.z*17.);
 vec3 skin=mix(vec3(.11,.17,.19),vec3(.23,.28,.27),belly);
 skin*=.94+.06*mottling;
 ALBEDO=skin;ROUGHNESS=.33;SPECULAR=.65;
 EMISSION=skin*.18;
}
