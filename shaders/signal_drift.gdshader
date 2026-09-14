shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,fog_disabled,cull_disabled;
uniform float scene_time=0.;
#include "res://shaders/signal_color.gdshaderinc"
varying float life;
varying vec3 world_position;
varying float seed;
varying float edge;
void vertex(){
    // Each Blender-authored fragment begins on the tree. Wrap occurs invisibly.
    vec3 anchor=VERTEX-vec3((UV.x-.5)*.054,(.5-UV.y)*.054,0.);
    // Fragments inherit the gradient at their point of departure.
    edge=signal_edge((MODEL_MATRIX*vec4(anchor,1.)).xyz,VIEW_MATRIX);
    seed=fract(sin(dot(anchor,vec3(71.3,19.7,41.1)))*4317.);
    float phase=fract(sin(dot(anchor,vec3(21.7,41.1,93.8)))*4317.);
    life=fract(phase+scene_time/(5.5+seed*5.));
    float lift=life*life*(3.8+seed*4.2);
    anchor.y+=lift;
    anchor.x+=sin(life*4.+seed*24.)*life*1.05;
    anchor.z+=cos(life*3.+seed*17.)*life*.85;
    world_position=(MODEL_MATRIX*vec4(anchor,1.)).xyz;
    vec4 center=MODELVIEW_MATRIX*vec4(anchor,1.);
    center.xy+=vec2(UV.x-.5,.5-UV.y)*min(.054,max(.001,-center.z*.006))*(.7+seed*.7);
    POSITION=PROJECTION_MATRIX*center;
}
void fragment(){
    float fade=smoothstep(0.,.12,life)*(1.-smoothstep(.30,1.,life));
    float shimmer=.88+.12*sin(scene_time*.55+seed*9.);
    ALBEDO=signal_color(edge,COLOR.b)*1.3;
    ALPHA=fade*shimmer*.78*exp(-distance(CAMERA_POSITION_WORLD,world_position)*.029);
}
