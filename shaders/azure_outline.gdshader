shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
uniform float thickness = .045;
uniform bool foam = false;
uniform float scene_time = 0.0;
#include "res://shaders/azure_foam_motion.gdshaderinc"
#include "res://shaders/azure_atmosphere.gdshaderinc"
varying float elevation;
void vertex() {
    if(foam) VERTEX=azure_foam_position(VERTEX,NORMAL,UV,scene_time);
    VERTEX += NORMAL*thickness;
    elevation=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment() {
    ALBEDO=azure_aerial(vec3(.30,.34,.40),length(VERTEX),elevation);
}
