shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float scene_time=0.;
void fragment(){
 // Imported V runs downward. Each column has an independent gravity-driven run.
 vec2 uv=UV*vec2(23.,1.4);
 float column=floor(uv.x);
 float seed=fract(sin(column*127.1)*43758.54);
 float y=fract(uv.y-scene_time*(.13+seed*.17)+seed*7.);
 float x=fract(uv.x)-.5-sin(UV.y*16.+seed*19.)*.065;
 float trail=(1.-smoothstep(.016,.055,abs(x)))*smoothstep(.25,.96,y)*step(.24,seed);
 float bead=exp(-pow(x/.08,2.)-pow((y-.96)/.07,2.))*step(.24,seed);
 float haze=.012+.022*smoothstep(.4,1.,abs(UV.y-.5)*2.);
 ALBEDO=vec3(.39,.54,.61)+bead*.20;
 ALPHA=haze+trail*.16+bead*.36;
}
