shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float sea_time=0.;
#include "res://shaders/sea_waves.gdshaderinc"
varying float opacity;
varying float seed;
void vertex(){
 seed=INSTANCE_CUSTOM.b;
 float lifetime=1.05+INSTANCE_CUSTOM.g*.75;
 float age=mod(sea_time+INSTANCE_CUSTOM.r*lifetime,lifetime);
 float birth=sea_time-age;
 vec3 anchor=MODEL_MATRIX[3].xyz;
 float crest=swell(anchor.xz,birth);
 float active=smoothstep(.45,1.05,crest);
 float phase=age/lifetime;
 opacity=active*sin(phase*3.14159)*.86*exp(-length(anchor-CAMERA_POSITION_WORLD)*.009);
 vec3 centre=anchor+vec3(-age*(1.2+seed),crest+.16+age*1.75-age*age*.85,age*.6);
 vec2 size=VERTEX.xy*(.6+phase*.9);
 vec3 world=centre+INV_VIEW_MATRIX[0].xyz*size.x+INV_VIEW_MATRIX[1].xyz*size.y;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.);
}
void fragment(){
 vec2 p=UV*2.-1.;
 float shape=1.-smoothstep(.25,1.,length(p*vec2(.85,1.)));
 float fleck=step(.54,sea_hash(floor(UV*vec2(46.,31.))+seed*137.));
 float threads=sea_noise(UV*vec2(9.,5.)+seed*31.);
 ALBEDO=vec3(.48,.62,.59);
 ALPHA=shape*fleck*smoothstep(.22,.7,threads)*opacity;
}
