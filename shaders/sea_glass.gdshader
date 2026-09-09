shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float sea_time=0.;
#include "res://shaders/sea_waves.gdshaderinc"
void fragment(){
 vec2 uv=UV*vec2(49.,3.);
 float column=floor(uv.x);float seed=sea_hash(vec2(column,9.));
 float y=fract(uv.y-sea_time*(.17+seed*.29)+seed*7.);
 float x=fract(uv.x)-.5-sin(UV.y*22.+seed*19.)*.055;
 float trail=(1.-smoothstep(.015,.044,abs(x)))*smoothstep(.42,.96,y)*step(.43,seed);
 float droplet=exp(-pow(x/.062,2.)-pow((y-.96)/.05,2.))*step(.43,seed);
 ALBEDO=vec3(.22,.36,.35);
 ALPHA=trail*.15+droplet*.34;
}
