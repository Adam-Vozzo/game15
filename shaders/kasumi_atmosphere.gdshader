shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float atmosphere_time=0.0;
uniform int fog_steps=28;
#include "res://shaders/scene_depth.gdshaderinc"
#include "res://shaders/kasumi_sky.gdshaderinc"
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    vec4 view=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);view/=view.w;
    vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 world=(INV_VIEW_MATRIX*view).xyz;
    vec3 ray=normalize(world-origin);bool background=depth<.00001;
    float distance=background?650.:min(length(world-origin),650.);
    vec3 color=background?kasumi_sky(ray,atmosphere_time):texture(scene_texture,SCREEN_UV).rgb;
    if(!background){color*=contact_occlusion(SCREEN_UV,view.xyz,VIEWPORT_SIZE,INV_PROJECTION_MATRIX,PROJECTION_MATRIX);}
    float trans=1.;vec3 scatter=vec3(0.);float previous=0.;
    float jitter=khash(vec3(floor(FRAGCOORD.xy),1.));
    vec3 sun=normalize(vec3(-.38,.48,-1.));float toward=pow(max(dot(ray,sun),0.),6.);
    for(int i=0;i<32;i++){
        if(i>=fog_steps){break;}
        float f=(float(i)+.45+jitter*.45)/float(fog_steps);float d=f*f*distance;float stride=d-previous;previous=d;
        vec3 p=origin+ray*d;
        float ground=.03+max(0.,-p.z)*.007+sin(p.x*.032)*sin(p.z*.033)*.07;
        float above=max(p.y-ground,0.);
        vec3 drift=vec3(-atmosphere_time*.035,0.,atmosphere_time*.011);
        float billow=knoise(p*vec3(.072,.14,.059)+drift)*.68+knoise(p*vec3(.18,.21,.17)+drift*1.3)*.32;
        float ribbon=exp(-pow((above-1.1-sin(p.x*.037+p.z*.09+atmosphere_time*.055)*.75)/1.9,2.));
        float low=exp(-above*.17);
        float density=.0022*exp(-above*.026)+low*pow(smoothstep(.32,.72,billow),1.7)*.037+ribbon*pow(billow,2.)*.022;
        float a=1.-exp(-density*stride);
        vec3 light=mix(vec3(.38,.46,.49),vec3(.51,.57,.58),smoothstep(4.,65.,above));
        light+=vec3(.075,.065,.045)*toward;
        scatter+=trans*a*light;trans*=1.-a;
    }
    color=color*trans+scatter;
    vec2 rain=SCREEN_UV*vec2(340.,21.);rain.x+=SCREEN_UV.y*18.;rain.y+=atmosphere_time*8.;
    vec2 cell=floor(rain),local=fract(rain);
    float streak=(1.-smoothstep(.012,.046,abs(local.x-.5)))*step(.94,khash(vec3(cell,2.)))*smoothstep(.15,.75,local.y);
    color+=vec3(.11,.14,.15)*streak*.20;
    color=deepen_shadows(color,1.13,.004,1.08);
    float vignette=smoothstep(.85,.20,length((SCREEN_UV-.5)*vec2(1.,.78)));
    ALBEDO=max(color*(.91+.09*vignette),vec3(0.));
}
