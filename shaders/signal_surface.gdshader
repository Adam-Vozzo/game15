shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled;
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform bool needles=false;
uniform bool earth=false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
    vec4 tex=texture(base_texture,UV);
    if(needles && tex.a<.45){discard;}
    vec3 col=tex.rgb;
    float lighting=.66+.34*abs(dot(normalize(world_normal),normalize(vec3(-.3,.8,.2))));
    if(earth){
        float path=-2.9+sin(world_position.z*.095)*2.1;
        float route=1.-smoothstep(.85,1.75,abs(world_position.x-path));
        // Isotropic litter, with offset/rotated samples rather than enlarging
        // the old diagonal texture wave into apparent dune ridges.
        vec2 rotated=mat2(vec2(.8,-.6),vec2(.6,.8))*world_position.xz*.37+vec2(.37,.61);
        col=mix(col,texture(base_texture,rotated).rgb,.34);
        col=mix(col*.78,vec3(.20,.255,.245)+col*.12,route);
    }
    // Slight spill is fixed around the feature trunk, never tied to the view.
    float spill=exp(-length(world_position.xz-vec2(1.6,-3.))*.75)*exp(-abs(world_position.y-1.5)*.4);
    ALBEDO=col*lighting*(needles?.51:.70)+vec3(.045,.10,.088)*spill;
}
