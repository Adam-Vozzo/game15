shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
#include "res://shaders/scene_depth.gdshaderinc"
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    float visibility=1.0;
    if(depth>=0.00001){
        vec3 p=depth_position(SCREEN_UV,depth,INV_PROJECTION_MATRIX);
        visibility=contact_occlusion(SCREEN_UV,p,VIEWPORT_SIZE,INV_PROJECTION_MATRIX,PROJECTION_MATRIX);
    }
    ALBEDO=vec3(visibility);
}
