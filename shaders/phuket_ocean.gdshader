shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float scene_time=0.;
uniform mat4 boat_inverse;
varying vec3 p;
float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 i=floor(q);vec2 f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float wave(vec2 q){return .09*sin(q.x*.38+q.y*.65-scene_time*1.12)+.045*sin(q.x*.81-q.y*.32-scene_time*1.61)+.024*noise(q*.73+vec2(scene_time*.12,-scene_time*.17));}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.y=wave(p.xz);p.y=VERTEX.y;}
void fragment(){
 // Clip only water inside the moving hull, between its bottom and gunwale.
 vec3 b=(boat_inverse*vec4(p,1.)).xyz;
 if(b.z>-4.2 && b.z<3.){
  float z0=-4.2;float z1=-3.1;float w0=.05;float w1=.62;float r0=1.25;float r1=.45;
  if(b.z>=-3.1){z0=-3.1;z1=-1.4;w0=.62;w1=.91;r0=.45;r1=.12;}
  if(b.z>=-1.4){z0=-1.4;z1=1.2;w0=.91;w1=.87;r0=.12;r1=.10;}
  if(b.z>=1.2){z0=1.2;z1=3.;w0=.87;w1=.53;r0=.10;r1=.40;}
  float t=(b.z-z0)/(z1-z0);float r=mix(r0,r1,t);
  float bottom=-.38+r;float top=.22+r;
  float width=mix(w0,w1,t)*mix(.62,1.,clamp((b.y-bottom)/.6,0.,1.));
  if(b.y>bottom && b.y<top && abs(b.x)<width+.005)discard;
 }
 float h=wave(p.xz);
 vec3 n=normalize(vec3(-(wave(p.xz+vec2(.07,0))-h)/.07,1.,-(wave(p.xz+vec2(0,.07))-h)/.07));
 vec3 eye=normalize(CAMERA_POSITION_WORLD-p);
 float depth=clamp((-p.z-3.)/90.,0.,1.);
 vec3 col=mix(vec3(.08,.60,.56),vec3(.015,.19,.35),smoothstep(0.,1.,depth));
 col*=.94+n.x*.18+n.z*.12;
 col*=.98+.04*noise(p.xz*.31+vec2(scene_time*.025,-scene_time*.018));
 float fresnel=pow(1.-max(dot(eye,n),0.),3.);
 col=mix(col,vec3(.19,.51,.72),fresnel*.50);
 float glint=pow(max(dot(reflect(-normalize(vec3(-.38,.95,-.48)),n),eye),0.),170.);
 float grain=hash(floor(p.xz*12.));
 col+=vec3(1.,.98,.82)*glint*(.35+grain*.65);
 float wash=abs(p.z-(.3+sin(scene_time*.63)*.9+sin(p.x*.12)*.35));
 float foam=(1.-smoothstep(.08,.48,wash))*step(.33,grain);
 col=mix(col,vec3(.89,.95,.86),foam*.77);
 float distance=length(CAMERA_POSITION_WORLD-p);
 col=mix(col,vec3(.53,.75,.84),1.-exp(-distance*.00065));
 ALBEDO=col;
 ALPHA=mix(.40,.98,smoothstep(-1.,22.,-p.z))+foam*.25;
}
