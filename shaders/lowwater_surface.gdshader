shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture:source_color,filter_nearest_mipmap,repeat_enable;
uniform float scene_time=0.;
uniform bool cutout=false;
uniform bool moss=false;
uniform bool earth=false;
varying vec3 world_p;
void vertex(){
 world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 // The top of each moss curtain remains fixed to its modeled branch.
 if(moss){float weight=1.-UV.y;VERTEX.x+=sin(scene_time*.45+world_p.z*.3)*.06*weight*weight;}
}
void fragment(){
 if(CAMERA_POSITION_WORLD.y<-.12 && !cutout && !FRONT_FACING){discard;}
 vec4 tex=texture(base_texture,UV);
 if(cutout && tex.a<.5){discard;}
 vec3 col=tex.rgb*COLOR.rgb;
 if(earth){
   vec3 broad=texture(base_texture,world_p.xz*.047+vec2(.27,.53)).rgb;
   col=mix(col,broad*COLOR.rgb,.5);
   float edge=abs(world_p.x-1.5-sin(world_p.z*.055)*1.3);
   col*=mix(.45,1.,smoothstep(2.7,5.2,edge));
 }
 if(!FRONT_FACING){NORMAL=-NORMAL;}
 // The low-resolution planar reflection camera sits below the water. Give its
 // separate view the same distant silver air without reflecting the postprocess.
 if(CAMERA_POSITION_WORLD.y<-.12){
   float haze=1.-exp(-length(world_p-CAMERA_POSITION_WORLD)*.036);
   ALBEDO=col;EMISSION=mix(col*.23,vec3(.42,.43,.365),haze);ALBEDO*=.10;
 }else{ALBEDO=col;}
 ROUGHNESS=.98;
}

void light(){
 // Thin foliage receives broad diffuse light on both faces. Absolute incidence
 // is invariant when the camera crosses a card, unlike a front/back normal flip.
 float incidence=dot(NORMAL,LIGHT);
 float response=cutout ? .62+.16*abs(incidence) : max(incidence,0.);
 DIFFUSE_LIGHT+=response*ATTENUATION*LIGHT_COLOR/PI;
}
