shader_type spatial;
render_mode unshaded,fog_disabled,cull_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D scene_texture:hint_screen_texture,filter_nearest;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest;
uniform float atmosphere_time=0.;
uniform float flash=0.;
uniform float storm_phase=0.;
uniform int fog_steps=24;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,91.8)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
float segment_distance(vec2 p,vec2 a,vec2 b){
    vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.,1.));
}
vec2 bolt_point(float i,float seed){
    return vec2(-.40+.15*sin(i*.29+seed)+.14*(hash(vec3(i,seed,7.))-.5),.30+i*.112+.055*hash(vec3(i,seed,3.)));
}
float lightning(vec3 ray){
    float dt=storm_phase-7.;float angle=0.;float seed=1.;
    if(storm_phase>=18.4){dt=storm_phase-18.4;angle=1.8;seed=4.;}
    if(storm_phase>=34.){dt=storm_phase-34.;angle=-1.45;seed=7.;}
    if(dt<0.||dt>.52){return 0.;}
    // A fixed celestial direction, independent of the camera position/heading.
    vec3 d=vec3(cos(angle)*ray.x-sin(angle)*ray.z,ray.y,sin(angle)*ray.x+cos(angle)*ray.z);
    if(d.z>=-.12){return 0.;}
    vec2 p=d.xy/-d.z;float distance=10.;
    for(int i=0;i<17;i++){
        vec2 a=bolt_point(float(i),seed),b=bolt_point(float(i+1),seed);
        distance=min(distance,segment_distance(p,a,b));
    }
    for(int branch=0;branch<3;branch++){
        vec2 a=bolt_point(5.+float(branch)*4.,seed);
        float side=branch==1?1.:-1.;
        for(int j=0;j<5;j++){
            vec2 b=a+vec2(side*(.035+.065*hash(vec3(float(j),float(branch),seed))),-.025-.07*hash(vec3(float(j),seed,12.)));
            distance=min(distance,segment_distance(p,a,b));a=b;
        }
    }
    float pulse=(dt<.16?1.:0.)+smoothstep(.25,.27,dt)*(1.-smoothstep(.34,.52,dt))*.8;
    return (3.8*(1.-smoothstep(.0018,.0045,distance))+.8*exp(-distance*60.))*pulse;
}
void fragment(){
    float depth=texture(depth_texture,SCREEN_UV).r;
    vec4 v=INV_PROJECTION_MATRIX*vec4(vec3(SCREEN_UV,depth)*2.-1.,1.);v/=v.w;
    vec3 origin=INV_VIEW_MATRIX[3].xyz;vec3 pos=(INV_VIEW_MATRIX*v).xyz;
    vec3 ray=normalize(pos-origin);bool sky=depth<.00001;
    float distance=sky?260.:min(length(pos-origin),260.);
    vec3 col=texture(scene_texture,SCREEN_UV).rgb;
    if(sky){
        float cloud=noise(ray*vec3(9.,21.,9.)+vec3(atmosphere_time*.007,0.,0.));
        col=mix(vec3(.045,.067,.085),vec3(.12,.15,.17),cloud)*(.8+flash*2.5);
        col+=flash*vec3(.22,.27,.33)*pow(max(0.,dot(ray,normalize(vec3(.2,.2,-1.)))),5.);
        col+=vec3(.72,.84,1.)*lightning(ray);
    }
    float trans=1.;vec3 fog=vec3(0.);
    for(int i=0;i<32;i++){
        if(i>=fog_steps){break;}
        float step_length=distance/float(fog_steps);
        vec3 p=origin+ray*(float(i)+.5)*step_length;
        float n=noise(p*vec3(.029,.065,.034)+vec3(atmosphere_time*.043,0.,atmosphere_time*.012));
        float density=(.015+.027*smoothstep(.26,.76,n))*(1.-flash*.87);
        vec3 tint=mix(vec3(.062,.088,.108),vec3(.13,.16,.18),smoothstep(-20.,60.,p.y));
        tint+=flash*vec3(.055,.070,.09);
        float a=1.-exp(-density*step_length);fog+=trans*a*tint;trans*=1.-a;
    }
    ALBEDO=col*trans+fog;
}
