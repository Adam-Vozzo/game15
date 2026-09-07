shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float atmosphere_time=0.0;
uniform int fog_steps=32;
#include "res://shaders/scene_depth.gdshaderinc"
float hash3(vec3 p){p=fract(p*.3183099+vec3(.1,.2,.3));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){return noise3(p)*.55+noise3(p*2.03)*.28+noise3(p*4.07)*.12+noise3(p*8.11)*.05;}
float terrain_height(vec2 p){return sin(p.x*.065+p.y*.035)*1.5+cos(p.y*.095-p.x*.03)*.8+sin(p.x*.2+p.y*.16)*.18;}
vec3 sky_color(vec3 rd){
    vec3 moon=normalize(vec3(-.38,.37,-.8));float alignment=max(dot(rd,moon),0.);
    vec3 cloudp=rd*(7./max(rd.y+.4,.15));
    float cloud=fbm(cloudp*vec3(.8,1.,.8)+vec3(-atmosphere_time*.038,0.,atmosphere_time*.011));
    vec3 sky=mix(vec3(.15,.195,.197),vec3(.038,.066,.080),smoothstep(-.15,.85,rd.y));
    sky+=vec3(.20,.245,.225)*pow(alignment,13.);
    sky+=vec3(.33,.36,.31)*pow(alignment,160.);
    sky+=vec3(.88,.91,.80)*smoothstep(.9991,.99965,alignment);
    sky*=1.-smoothstep(.30,.85,cloud)*.55;
    sky+=vec3(.05,.06,.055)*cloud*pow(alignment,7.);
    return sky;
}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    vec3 ndc=vec3(SCREEN_UV,depth)*2.-1.;
    vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.);view/=view.w;
    vec3 world=(INV_VIEW_MATRIX*view).xyz;
    vec3 origin=INV_VIEW_MATRIX[3].xyz;
    vec3 ray=normalize(world-origin);
    float distance_to_surface=min(length(world-origin),115.);
    vec3 color=depth<.00001?sky_color(ray):texture(scene_texture,SCREEN_UV).rgb;
    if(depth>=.00001){color*=contact_occlusion(SCREEN_UV,view.xyz,VIEWPORT_SIZE,INV_PROJECTION_MATRIX,PROJECTION_MATRIX);}
    float trans=1.;vec3 fog=vec3(0.);float previous=0.;
    float jitter=hash3(vec3(floor(SCREEN_UV*VIEWPORT_SIZE),1.));
    float moon_alignment=pow(max(dot(ray,normalize(vec3(-.38,.37,-.8))),0.),12.);
    for(int i=0;i<40;i++){
        if(i>=fog_steps){break;}
        float f=(float(i)+.55+jitter*.35)/float(fog_steps);
        float distance=f*f*distance_to_surface;float step_length=distance-previous;previous=distance;
        vec3 p=origin+ray*distance;
        vec3 drift=p*vec3(.070,.21,.065)+vec3(-atmosphere_time*.060,0.,atmosphere_time*.018);
        float billow=fbm(drift);
        float floor_y=terrain_height(p.xz);
        float low=exp(-max(p.y-floor_y-.35,0.)*.40);
        float ribbons=pow(smoothstep(.22,.78,billow),1.6);
        float rolling_height=.55+sin(p.x*.11+atmosphere_time*.15)*.20;
        float near_ribbon=exp(-pow((p.y-floor_y-rolling_height)/.40,2.))*smoothstep(.3,.7,billow);
        float density=.004+low*ribbons*.17+near_ribbon*.035;
        float extinction=1.-exp(-density*step_length);
        float illumination=.8+.2*noise3(p*.12+vec3(-atmosphere_time*.045,0.,0.));
        vec3 silver=mix(vec3(.205,.265,.265),vec3(.38,.43,.37),clamp(moon_alignment*.7+p.y*.035,0.,1.))*illumination;
        fog+=trans*extinction*silver;trans*=1.-extinction;
    }
    color=color*trans+fog;
    color=deepen_shadows(color,1.17,.003,1.06);
    float edge=smoothstep(.8,.15,length((SCREEN_UV-.5)*vec2(1.,.83)));
    color*=.76+edge*.24;
    float grain=(hash3(vec3(FRAGCOORD.xy,floor(atmosphere_time*12.)))-.5)*.008;
    float dither=(mod(FRAGCOORD.x+mod(FRAGCOORD.y,2.)*2.,4.)/4.-.375)/90.;
    color=floor((color+dither)*96.)/96.+grain;
    ALBEDO=max(color,vec3(0.));
}


