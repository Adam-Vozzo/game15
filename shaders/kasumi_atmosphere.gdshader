shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float atmosphere_time=0.0;
uniform int fog_steps=28;
#include "res://shaders/scene_depth.gdshaderinc"
#include "res://shaders/kasumi_sky.gdshaderinc"
vec3 warm_light(vec2 uv){
    vec3 source=texture(scene_texture,clamp(uv,vec2(0.),vec2(1.))).rgb;
    // Only warm luminous windows/lanterns feed the halo, not the dusk sky.
    float bright=smoothstep(.48,.85,max(source.r,max(source.g,source.b)));
    float warm=smoothstep(.06,.22,source.r-source.b);
    return source*bright*warm;
}
vec3 lamp_glow(vec2 uv,vec2 size){
    vec3 glow=vec3(0.);
    for(int ring=0;ring<3;ring++){
        float radius=3.+float(ring)*5.;
        float weight=ring==0?.10:(ring==1?.065:.035);
        for(int j=0;j<8;j++){
            float angle=float(j)*.785398+float(ring)*.23;
            glow+=warm_light(uv+vec2(cos(angle),sin(angle))*radius/size)*weight;
        }
    }
    return glow*vec3(1.,.78,.48)*.85;
}
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
    vec3 sun=normalize(vec3(-.38,.06,-1.));float toward=pow(max(dot(ray,sun),0.),6.);
    for(int i=0;i<32;i++){
        if(i>=fog_steps){break;}
        float f=(float(i)+.45+jitter*.45)/float(fog_steps);float d=f*f*distance;float stride=d-previous;previous=d;
        vec3 p=origin+ray*d;
        float ground=.03+max(0.,-p.z)*.007+sin(p.x*.032)*sin(p.z*.033)*.07;
        float above=max(p.y-ground,0.);
        vec3 drift=vec3(-atmosphere_time*.035,0.,atmosphere_time*.011);
        float billow=knoise(p*vec3(.072,.14,.059)+drift)*.68+knoise(p*vec3(.18,.21,.17)+drift*1.3)*.32;
        float ribbon=exp(-pow((above-1.1-sin(p.x*.037+p.z*.09+atmosphere_time*.055)*.75)/1.9,2.));
        float low=exp(-above*.13);
        // Eye-height haze closes off the lane beyond the nearest shopfronts.
        // Ease it in over the first few metres so foreground detail stays readable.
        float close_haze=.028*exp(-above*.095)*smoothstep(2.5,9.,d);
        float density=.004*exp(-above*.026)+close_haze+low*pow(smoothstep(.28,.68,billow),1.5)*.057+ribbon*pow(billow,2.)*.036;
        float a=1.-exp(-density*stride);
        vec3 light=mix(vec3(.085,.115,.15),vec3(.14,.17,.21),smoothstep(4.,65.,above));
        light+=vec3(.028,.013,.008)*toward;
        scatter+=trans*a*light;trans*=1.-a;
    }
    color=color*trans+scatter;
    vec2 rain=SCREEN_UV*vec2(340.,21.);rain.x+=SCREEN_UV.y*18.;rain.y+=atmosphere_time*8.;
    vec2 cell=floor(rain),local=fract(rain);
    float streak=(1.-smoothstep(.012,.046,abs(local.x-.5)))*step(.94,khash(vec3(cell,2.)))*smoothstep(.15,.75,local.y);
    color+=vec3(.06,.08,.10)*streak*.14;
    color+=lamp_glow(SCREEN_UV,VIEWPORT_SIZE);
    color=deepen_shadows(color,1.13,.004,1.08);
    float vignette=smoothstep(.85,.20,length((SCREEN_UV-.5)*vec2(1.,.78)));
    ALBEDO=max(color*(.91+.09*vignette),vec3(0.));
}
