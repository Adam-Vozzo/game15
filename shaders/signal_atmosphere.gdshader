shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
uniform int fog_steps=24;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,91.8)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
    vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 pos=(INV_VIEW_MATRIX*v).xyz;
    vec3 ray=normalize(pos-origin);bool sky=depth<.00001;
    float distance=sky?120.:min(length(pos-origin),120.);
    vec3 col=texture(scene_texture,SCREEN_UV).rgb;
    if(sky){col=mix(vec3(.39,.43,.42),vec3(.69,.71,.70),smoothstep(-.08,.68,ray.y));}
    float transmittance=1.;vec3 fog=vec3(0.);
    for(int i=0;i<32;i++){
        if(i>=fog_steps){break;}
        float step_length=distance/float(fog_steps);
        vec3 p=origin+ray*(float(i)+.5)*step_length;
        float n=noise(p*vec3(.13,.21,.12)+vec3(atmosphere_time*.014,0.,atmosphere_time*.005));
        float low=exp(-max(p.y,0.)*.75);
        float density=.029+low*.055*smoothstep(.28,.77,n);
        vec3 tint=mix(vec3(.26,.30,.285),vec3(.59,.62,.605),smoothstep(0.,22.,p.y));
        float a=1.-exp(-density*step_length);
        fog+=transmittance*a*tint;transmittance*=1.-a;
    }
    ALBEDO=col*transmittance+fog;
}
