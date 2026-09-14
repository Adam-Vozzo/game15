shader_type spatial;
render_mode unshaded, fog_disabled,cull_disabled;
uniform float scene_time=0.;
uniform float light_strength=1.25;
#include "res://shaders/signal_color.gdshaderinc"
varying vec3 world_position;
varying float edge;
void vertex(){
    vec3 anchor=VERTEX-vec3((UV.x-.5)*.054,(.5-UV.y)*.054,0.);
    world_position=(MODEL_MATRIX*vec4(anchor,1.)).xyz;
    edge=signal_edge(world_position,VIEW_MATRIX);
    vec4 center=MODELVIEW_MATRIX*vec4(anchor,1.);
    // Limit apparent size when walking through a branch; centers stay fixed.
    center.xy+=vec2(UV.x-.5,.5-UV.y)*min(.040,max(.001,-center.z*.0045));
    POSITION=PROJECTION_MATRIX*center;
}
void fragment(){
    // Brightness phases remain anchored to the cells, independently of colour.
    float phase=fract(sin(dot(world_position,vec3(21.7,41.1,93.8)))*4317.);
    float shimmer=.89+.08*sin(scene_time*.28+phase*6.283)+.03*sin(scene_time*.47+phase*27.);
    float wave=.94+.06*sin(world_position.y*.64-scene_time*.16);
    // Infrequent, several-second fades instead of five abrupt decisions/second.
    // The envelope is zero at wrap; bands never snap to a new random value.
    float band=floor(world_position.y*5.);
    float band_seed=fract(sin(band*127.1)*43758.5453);
    float cycle=fract(scene_time/(12.+band_seed*9.)+band_seed);
    float fade=smoothstep(.10,.19,cycle)*(1.-smoothstep(.22,.36,cycle));
    float dropout=1.-fade*.42;
    ALBEDO=signal_color(edge,COLOR.b)*shimmer*wave*COLOR.g*light_strength*dropout;
}
