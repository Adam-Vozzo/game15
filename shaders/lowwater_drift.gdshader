shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float scene_time=0.;
uniform bool leaves=false;
uniform sampler2D sun_depth:filter_nearest,repeat_disable;
varying vec3 wp;
varying float opacity;
float sunlight(vec3 p){
 vec3 sun=normalize(vec3(-.40,.76,-.51));
 vec3 u=normalize(cross(vec3(0,1,0),sun));vec3 v=cross(sun,u);
 vec3 offset=p-vec3(0,0,-25);
 vec2 uv=vec2(dot(offset,u),-dot(offset,v))/160.+.5;
 vec2 packed=texture(sun_depth,uv).rg;
 float distance=(100.-dot(offset,sun))/200.;
 return smoothstep(distance-.002,distance+.001,packed.r+packed.g/255.);
}
void vertex(){
 vec3 anchor=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float seed=COLOR.r;float phase=seed*6.283185;
 vec2 corner=UV*2.-1.;
 // Remove the tiny source quad, accounting for glTF's V-axis conversion.
 anchor-=vec3(corner.x*.002,-corner.y*.002,0.);
 opacity=1.;
 if(leaves){
   // Long independent intervals: typically only four leaves across the canal.
   float period=42.+seed*35.;float age=mod(scene_time+COLOR.b*period,period);
   float fall=age/14.;
   opacity=smoothstep(0.,.08,fall)*(1.-smoothstep(.84,1.,fall));
   anchor+=vec3(sin(age*.68+phase)*.65+age*.075,-min(fall,1.)*(anchor.y-.8),cos(age*.43+phase)*.48);
   float angle=age*.83+phase;
   vec3 side=vec3(cos(angle),sin(angle)*.45,sin(angle));
   vec3 up=normalize(cross(side,vec3(.3,.4,1.)));
   wp=anchor+(side*corner.x*.055+up*corner.y*.11)*COLOR.g;
 }else{
   anchor+=vec3(sin(scene_time*.19+phase)*.48,sin(scene_time*.24+phase)*.38,cos(scene_time*.13+phase)*.38);
   float size=(.013+seed*.010)*COLOR.g;
   wp=anchor+(INV_VIEW_MATRIX[0].xyz*corner.x+INV_VIEW_MATRIX[1].xyz*corner.y)*size;
 }
 VERTEX=(VIEW_MATRIX*vec4(wp,1.)).xyz;
 POSITION=PROJECTION_MATRIX*vec4(VERTEX,1.);
}
void fragment(){
 vec2 p=UV*2.-1.;float lit=sunlight(wp);
 float distance=length(CAMERA_POSITION_WORLD-wp);
 if(leaves){
   float width=(1.-abs(p.y))*(.82+.12*cos(p.y*11.));
   if(abs(p.x)>width){discard;}
   ALBEDO=mix(vec3(.14,.145,.12),vec3(.58,.58,.48),lit);
   ALPHA=opacity*exp(-distance*.018);
 }else{
   float disc=1.-smoothstep(.25,1.,dot(p,p));
   ALBEDO=vec3(.91,.90,.76);
   ALPHA=disc*lit*.62*exp(-distance*.027)*smoothstep(.4,1.2,distance);
 }
}
