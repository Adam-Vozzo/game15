shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float atmosphere_time=0.0;
uniform int place_kind=0;
#include "res://shaders/scene_depth.gdshaderinc"
float hash3(vec3 p){p=fract(p*.3183099+vec3(.1,.2,.3));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){return noise3(p)*.58+noise3(p*2.03)*.28+noise3(p*4.1)*.14;}
vec3 sky(vec3 ray){
    float height=clamp(ray.y,0.,1.);
    vec3 p=ray*(7./max(ray.y+.20,.07));
    float cloud=fbm(p*vec3(.7,1.5,.7)+vec3(atmosphere_time*.015,0.,0.));
    if(place_kind==0){
        vec3 sun=normalize(vec3(-.27,.105,-1.));float align=max(dot(sun,ray),0.);
        vec3 c=mix(vec3(.64,.33,.24),vec3(.15,.18,.29),smoothstep(0.,.8,height));
        c+=vec3(.25,.15,.06)*pow(align,9.);
        c+=vec3(.8,.54,.19)*smoothstep(.9989,.9997,align);
        c=mix(c,c*vec3(.69,.66,.74),smoothstep(.53,.77,cloud)*.60);
        c+=vec3(.10,.036,.016)*smoothstep(.38,.65,cloud)*pow(align,4.);
        return c;
    }
    return mix(vec3(.38,.43,.43),vec3(.19,.245,.265),height)*(.83+.17*cloud);
}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    vec4 view=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);view/=view.w;
    vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 world=(INV_VIEW_MATRIX*view).xyz;
    vec3 ray=normalize(world-origin);float distance=min(length(world-origin),place_kind==0?380.:125.);
    vec3 color=depth<.00001?sky(ray):texture(scene_texture,SCREEN_UV).rgb;
    if(depth>=.00001){color*=contact_occlusion(SCREEN_UV,view.xyz,VIEWPORT_SIZE,INV_PROJECTION_MATRIX,PROJECTION_MATRIX);}
    float trans=1.;vec3 scatter=vec3(0.);float prev=0.;
    float jitter=hash3(vec3(floor(FRAGCOORD.xy),1.));
    for(int i=0;i<24;i++){
        float f=(float(i)+.5+jitter*.45)/24.;float d=f*f*distance;float step=d-prev;prev=d;
        vec3 p=origin+ray*d;float n=fbm(p*vec3(.06,.13,.065)+vec3(-atmosphere_time*.020,0.,atmosphere_time*.009));
        float low=exp(-max(p.y-.6,0.)*.28);
        float density=place_kind==0 ? .0015+low*n*.0035 : .005+low*pow(smoothstep(.22,.80,n),1.4)*.072;
        float a=1.-exp(-density*step);
        vec3 light=place_kind==0 ? vec3(.54,.36,.29) : vec3(.34,.405,.405);
        scatter+=trans*a*light;trans*=1.-a;
    }
    color=color*trans+scatter;
    if(place_kind==1){
        vec2 rain=SCREEN_UV*vec2(290.,16.);rain.x+=SCREEN_UV.y*16.;rain.y+=atmosphere_time*7.;
        vec2 cell=floor(rain);vec2 local=fract(rain);
        float streak=(1.-smoothstep(.02,.06,abs(local.x-.5)))*step(.90,hash3(vec3(cell,2.)))*smoothstep(.1,.7,local.y);
        color+=vec3(.10,.12,.12)*streak*.17;
    }
    color=place_kind==0 ? deepen_shadows(color,1.24,.008,1.10) : deepen_shadows(color,1.23,.006,1.08);
    float edge=smoothstep(.83,.15,length((SCREEN_UV-.5)*vec2(1.,.8)));color*=.84+.16*edge;
    float dither=(mod(FRAGCOORD.x+mod(FRAGCOORD.y,2.)*2.,4.)/4.-.375)/95.;
    color=floor((color+dither)*112.)/112.;color+=(hash3(vec3(FRAGCOORD.xy,floor(atmosphere_time*10.)))-.5)*.005;
    ALBEDO=max(color,vec3(0.));
}
