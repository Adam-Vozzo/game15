shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
uniform int fog_steps=48;
uniform sampler2D sun_depth:filter_nearest,repeat_disable;
uniform float shaft_strength=.72;
uniform float ground_mist_strength=.095;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,91.8)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
float ground_height(vec2 p){
 float center=1.5+sin(p.y*.055)*1.3;
 float bank=smoothstep(0.,1.,clamp((abs(p.x-center)-2.6)/1.6,0.,1.));
 return max(-.12,-.72+bank*(1.4+.14*sin(p.x*.25+p.y*.13)+.09*cos(p.y*.31)));
}
float sunlight(vec3 p){
 // Same orthographic sun basis and packing as the Blender alpha-aware bake.
 vec3 sun=normalize(vec3(-.40,.76,-.51));
 vec3 axis_u=normalize(cross(vec3(0.,1.,0.),sun));
 vec3 axis_v=cross(sun,axis_u);
 vec3 offset=p-vec3(0.,0.,-25.);
 vec2 uv=vec2(dot(offset,axis_u),-dot(offset,axis_v))/160.+.5;
 if(any(lessThan(uv,vec2(0.)))||any(greaterThan(uv,vec2(1.)))){return 1.;}
 float distance=(100.-dot(offset,sun))/200.;
 float lit=0.;
 for(int j=0;j<4;j++){
   vec2 tap=vec2(float(j%2),float(j/2))-.5;
   vec2 packed=texture(sun_depth,uv+tap/384.).rg;
   float blocker=packed.r+packed.g/255.;
   lit+=smoothstep(distance-.002,distance+.001,blocker)*.25;
 }
 return lit;
}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 float depth=texture(depth_texture,SCREEN_UV).r;
 vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
 vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 pos=(INV_VIEW_MATRIX*v).xyz;
 vec3 ray=normalize(pos-origin);bool sky=depth<.00001;
 float distance=sky?135.:min(length(pos-origin),135.);
 vec3 col=texture(scene_texture,SCREEN_UV).rgb;
 vec3 light_direction=normalize(vec3(-.40,.76,-.51));
 if(sky){
   float cloud=noise(ray*4.+vec3(atmosphere_time*.003,0.,0.));
   col=vec3(.60,.61,.53)+vec3(.34,.32,.235)*pow(max(dot(ray,light_direction),0.),6.);
   col*=.92+cloud*.13;
 }
 float previous=0.;
 float transmittance=1.;vec3 fog=vec3(0.);
 for(int i=0;i<64;i++){
   if(i>=fog_steps){break;}
   // More samples in the near field resolve thin mist above the banks.
   float fraction=(float(i)+1.)/float(fog_steps);
   float next_distance=fraction*fraction*distance;
   float step_length=next_distance-previous;
   vec3 p=origin+ray*(previous+step_length*.5);
   previous=next_distance;
   vec3 q=p*vec3(.075,.16,.068)+vec3(atmosphere_time*.013,0.,atmosphere_time*.004);
   float n=noise(q)*.72+noise(q*2.13)*.28;
   float low=exp(-max(p.y-.2,0.)*.24);
   float density=.007+low*(.016+.026*smoothstep(.28,.72,n));
   float height=p.y-ground_height(p.xz);
   float ribbon_noise=noise(p*vec3(.24,.14,.18)+vec3(-atmosphere_time*.027,0.,atmosphere_time*.012));
   float ribbon_height=.30+.12*sin(p.z*.18+atmosphere_time*.055);
   float ribbon=exp(-pow((height-ribbon_height)/.28,2.))*smoothstep(.28,.70,ribbon_noise);
   density+=ribbon*ground_mist_strength;
   float clearing=exp(-dot((p.xz-vec2(-3.,-37.))/vec2(20.,28.),(p.xz-vec2(-3.,-37.))/vec2(20.,28.)));
   vec3 mist_color=mix(vec3(.285,.305,.265),vec3(.84,.83,.73),clearing);
   mist_color=mix(mist_color,vec3(.63,.65,.59),ribbon*.35);
   // Only air reached by sun through the modeled leaf gaps scatters bright
   // light. World-space depth keeps the shafts fixed through free camera turns.
   float lit=sunlight(p);
   density+=lit*.018*exp(-pow((height-3.5)/4.,2.));
   mist_color+=vec3(1.,.99,.88)*shaft_strength*lit*(1.-clearing*.72);
   float a=1.-exp(-density*step_length);
   fog+=transmittance*a*mist_color;
   transmittance*=1.-a;
 }
 col=col*transmittance+fog;
 // A restrained warm silver palette; depth and world-space air carry the softness.
 float luma=dot(col,vec3(.299,.587,.114));
 col=mix(col,vec3(luma*1.025,luma*1.015,luma*.92),.70);
 col*=1.-.12*smoothstep(.30,.75,length(SCREEN_UV-.5));
 ALBEDO=clamp(col,0.,1.);
}
