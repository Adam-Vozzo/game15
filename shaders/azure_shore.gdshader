shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;
uniform float scene_time=0.0;
uniform float strength=1.0;
#include "res://shaders/azure_atmosphere.gdshaderinc"
varying float elevation;

void vertex() { elevation=(MODEL_MATRIX*vec4(VERTEX,1.0)).y; }

void fragment() {
    float u=UV.x;
    float v=1.0-UV.y;
    // UV.x is shoreline distance in metres; UV.y crosses the narrow ribbon.
    // Bounded wash and broken outer curls retain their scale for long visits.
    float scallop=.06*sin(u*1.9+scene_time*.75)+.025*sin(u*4.3-scene_time*.48);
    float outer=.69+.08*sin(u*.8+scene_time*.39)+scallop;
    float wash=(1.0-smoothstep(outer-.18,outer,v))*(.43+.16*sin(u*2.7-scene_time*.62));
    float curl=(1.0-smoothstep(.025,.075,abs(v-outer+.07)))*smoothstep(-.4,.4,sin(u*1.9+scene_time*.45));
    float inner=(1.0-smoothstep(.27,.46,v))*.42;
    float alpha=max(inner,max(wash,curl*.8))*smoothstep(.0,.09,v);
    vec3 col=mix(vec3(.69,.86,.80),vec3(.90,.96,.86),clamp(inner+curl,0.0,1.0));
    ALBEDO=azure_aerial(col,length(VERTEX),elevation);
    ALPHA=clamp(alpha*strength,0.0,.85);
}
