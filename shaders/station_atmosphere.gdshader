shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,91.8)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
 vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 world=(INV_VIEW_MATRIX*v).xyz;vec3 ray=normalize(world-origin);
 bool background=depth<.00001;float dist=background?180.:length(world-origin);
 vec3 color=texture(scene_texture,SCREEN_UV).rgb;vec3 sun=normalize(vec3(.44,.81,.40));
 if(background){
   color=mix(vec3(.72,.88,.80),vec3(.12,.52,.73),smoothstep(-.08,.8,ray.y));
   vec3 q=ray*(3./max(ray.y+.18,.09))+vec3(atmosphere_time*.004,0,0);
   float cloud=noise(q)*.6+noise(q*2.1)*.3+noise(q*4.2)*.1;
   color=mix(color,vec3(.99,1.,.92),smoothstep(.58,.68,cloud)*smoothstep(.01,.18,ray.y));
   color+=vec3(.5,.39,.18)*pow(max(dot(ray,sun),0.),72.);
 }else{
   float haze=1.-exp(-dist*.005);color=mix(color,vec3(.58,.76,.65),haze);
 }
 // Light air occupies the actual open centre. It is integrated in world space,
 // and the scene depth stops it at the nearest physical surface.
 float light_air=0.;
 for(int i=0;i<16;i++){
   float d=(float(i)+.5)/16.*min(dist,65.);vec3 p=origin+ray*d;
   vec3 roof=p+sun*max(0.,(12.-p.y)/sun.y);
   float aperture=(1.-smoothstep(9.5,11.5,abs(roof.x)))*smoothstep(-40.,-36.,roof.z)*(1.-smoothstep(18.,21.,roof.z));
   float density=exp(-pow((p.y-2.3)/3.0,2.))*.0025;
   light_air+=aperture*density*min(dist,65.)/16.;
 }
 color=mix(color,vec3(.88,.93,.64),clamp(light_air,0.,.15));
 ALBEDO=color;
}
