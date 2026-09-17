shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;
uniform float scene_time = 0.0;
uniform int kind = 0; // gravity threads, impact droplets, mist, surface foam
uniform float density = 1.0;
uniform float strength = 1.0;
#include "res://shaders/azure_atmosphere.gdshaderinc"
varying float elevation;
varying float visibility;
varying vec2 shape_uv;
varying float seed;

void vertex() {
    vec2 corner=vec2(UV.x*2.0-1.0,1.0-UV.y*2.0);
    vec3 out_dir=normalize(vec3(NORMAL.x,0,NORMAL.z));
    vec3 side=vec3(out_dir.z,0,-out_dir.x);
    vec3 anchor=VERTEX-side*corner.x*.02-vec3(0,corner.y*.02,0);
    seed=COLOR.b;
    float phase=COLOR.r;
    float speed=COLOR.g;
    float height=COLOR.a*53.0;
    float lifetime=kind==0?(sqrt(36.0+19.6*height)-6.0)/9.8:mix(2.5,4.8,speed);
    if(kind==2) lifetime=mix(4.2,7.5,speed);
    if(kind==3) lifetime=mix(5.0,9.0,speed);
    float f=fract(scene_time/lifetime+phase);
    float age=f*lifetime;
    visibility=smoothstep(0.0,.10,f)*(1.0-smoothstep(.66,1.0,f))*step(seed,density)*strength;
    vec3 p=anchor;
    vec3 right=INV_VIEW_MATRIX[0].xyz;
    vec3 up=INV_VIEW_MATRIX[1].xyz;
    vec2 size=vec2(.1);
    if(kind==0) {
        float drop=6.0*age+4.9*age*age;
        float depth=clamp(drop/max(height,1.0),0.0,1.0);
        p.y-=drop;
        p+=out_dir*((height>40.0?2.8:2.0)*sin(min(depth*5.0,1.0)*1.570796)+.18);
        p+=side*.12*sin(age*3.5+phase*24.0);
        right=side;up=vec3(0,1,0);
        size=vec2(mix(.06,.17,seed),mix(.45,1.0,seed)+age*.82);
        visibility*=.85;
    } else if(kind==1) {
        // Ballistic spray begins at the actual receiving water level.
        float lift=mix(10.5,15.8,speed);
        p.y+=lift*age-4.8*age*age;
        p+=out_dir*age*mix(1.1,3.5,seed)+side*age*(phase-.5)*2.5;
        visibility*=smoothstep(-.1,.4,p.y-anchor.y);
        size=vec2(mix(.08,.24,seed),mix(.16,.48,seed));
    } else if(kind==2) {
        p+=out_dir*age*mix(.75,1.65,seed)+side*sin(age*.8+phase*18.0)*1.7;
        p.y+=age*mix(1.6,2.4,speed);
        size=vec2(mix(1.6,3.5,seed)*(1.0+f*.8));
        visibility*=.26;
    } else {
        p+=out_dir*age*mix(1.5,2.7,speed)+side*sin(age*.6+phase*12.0)*.8;
        right=side;up=out_dir;
        size=vec2(mix(.7,2.5,seed),mix(1.2,3.8,seed))*(.55+f*1.7);
        visibility*=.62;
    }
    VERTEX=p+right*corner.x*size.x+up*corner.y*size.y;
    elevation=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;
    shape_uv=corner;
}
void fragment() {
    float r=length(shape_uv);
    vec3 col=vec3(.84,.95,.87);
    float shape=0.0;
    if(kind==0 || kind==1) {
        // Long tapered strokes and small droplets, never square point sprites.
        shape=(1.0-smoothstep(.38,.90,abs(shape_uv.x)))*(1.0-smoothstep(.45,1.0,abs(shape_uv.y)));
        col=mix(vec3(.69,.87,.83),vec3(.97,.98,.85),seed);
    } else if(kind==2) {
        float edge=r+.10*sin(shape_uv.x*8.0+seed*16.0)*sin(shape_uv.y*7.0+seed*9.0);
        shape=1.0-smoothstep(.36,1.0,edge);
        col=vec3(.78,.91,.88);
    } else {
        float angle=atan(shape_uv.y,shape_uv.x);
        float edge=r+.075*sin(angle*5.0+seed*15.0)+.045*sin(angle*9.0);
        float band=(1.0-smoothstep(.72,.9,edge))*smoothstep(.47,.66,edge);
        shape=band*(.50+.50*sin(angle*2.0+seed*12.0));
    }
    ALBEDO=azure_aerial(col,length(VERTEX),elevation);
    ALPHA=clamp(shape*visibility,0.0,.85);
}
