shader_type canvas_item;
uniform vec2 panel_size=vec2(250.,150.);
uniform float corner_radius=15.;
uniform float scanline_strength=.025;
varying vec2 tile_position;
void vertex(){tile_position=VERTEX;}
void fragment(){
 vec4 col=texture(TEXTURE,UV);
 vec2 p=abs(tile_position-panel_size*.5)-(panel_size*.5-vec2(corner_radius));
 float corner=length(max(p,vec2(0.)))+min(max(p.x,p.y),0.)-corner_radius;
 col.rgb*=1.-scanline_strength+scanline_strength*sin(tile_position.y*3.14159);
 col.a*=1.-smoothstep(-1.,1.,corner);
 COLOR=col;
}
