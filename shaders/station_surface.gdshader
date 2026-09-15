shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform sampler2D base_texture:source_color,filter_linear_mipmap,repeat_enable;
uniform vec4 base_color:source_color=vec4(1.);
uniform bool textured=false;
uniform bool foliage=false;
uniform bool generated_asset=false;
uniform bool wet=false;
uniform bool masonry=false;
uniform float scene_time=0.;
varying vec3 wp;
varying vec4 vc;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;vc=COLOR;
 if(foliage){float w=COLOR.a*.045;VERTEX.x+=sin(wp.x*.38+wp.z*.26+scene_time*.75)*w;VERTEX.z+=cos(wp.z*.43+scene_time*.6)*w*.6;}
}
void fragment(){
 if(CAMERA_POSITION_WORLD.y<.22 && (wp.y<.24 || !FRONT_FACING)){discard;}
 vec3 col=textured?texture(base_texture,UV).rgb:base_color.rgb;
 if(!generated_asset)col*=vc.rgb;
 if(foliage){col=mix(col,col*vec3(.87,1.04,.88),.35);ROUGHNESS=1.;SPECULAR=.05;}
 else{ROUGHNESS=wet?.72:.92;SPECULAR=.12;}
 float moss=noise(wp.xz*.9+wp.y*.13)*noise(wp.xz*.31-wp.y*.19);
 if(masonry){vec2 wall=vec2(wp.x*.61+wp.z*.47,wp.y*.72);float growth=noise(wall*.41)*.63+noise(wall*1.6)*.37;float cover=smoothstep(.47,.64,growth);col=mix(col,col*vec3(.35,.67,.26),cover*.82);}
 if(!foliage && !generated_asset && wp.y<1.25){col=mix(col,col*vec3(.48,.76,.52),smoothstep(.14,.42,moss)*.38);}
 if(wp.y<.23){col=mix(col,vec3(.035,.27,.23),.43);float caustic=pow(max(0.,sin(wp.x*5.2+sin(wp.z*3.1+scene_time*.45))*sin(wp.z*5.8+sin(wp.x*2.4-scene_time*.6))),9.);col+=vec3(.07,.22,.17)*caustic;}
 ALBEDO=col;
 if(foliage){EMISSION=col*.08;BACKLIGHT=col*.18;}
}
