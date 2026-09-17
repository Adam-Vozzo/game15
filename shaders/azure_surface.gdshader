shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform int kind = 0;
uniform float scene_time = 0.0;
#include "res://shaders/azure_foam_motion.gdshaderinc"
#include "res://shaders/azure_atmosphere.gdshaderinc"
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
    if(kind==4) VERTEX=azure_foam_position(VERTEX,NORMAL,UV,scene_time);
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
    vec3 col=COLOR.rgb;
    if(kind==0) {
        // Broad, restrained colour modelling. No screen-space shading cutoff.
        float light=dot(normalize(world_normal),normalize(vec3(-.55,.72,.36)));
        vec3 shade=col*vec3(.77,.84,.98);
        vec3 sunlit=col*vec3(1.055,1.025,.975)+vec3(.018,.013,.003);
        col=mix(shade,sunlit,smoothstep(-.65,.80,light));
        col+=vec3(.024,.016,.003)*smoothstep(12.0,185.0,world_pos.y);
    } else if(kind==2) {
        vec2 p=world_pos.xz;
        // The drawing travels with the current, entirely in world coordinates.
        vec2 current=vec2(.22,world_pos.y<0.0?1.05:1.8);
        // Never multiply a position-dependent velocity by elapsed time: that
        // progressively shears the drawing, especially several orbits later.
        if(world_pos.y>30.0) current=vec2(.65,1.4);
        vec2 flowing=p-current*scene_time;
        flowing.x+=2.0*noise2(p*.045+vec2(0,-scene_time*.027));
        float variation=noise2(flowing*.024)+.35*noise2(flowing*.057+31.0);
        col=mix(col*.93,col*1.045,variation*.7);
        // Sparse unequal ink ripples advect downstream through a fixed field.
        vec2 cell=floor(flowing/vec2(6.7,4.3));vec2 f=fract(flowing/vec2(6.7,4.3));
        float seed=hash(cell);
        float ripple=.45+.13*sin(f.x*9.0+seed*14.0+scene_time*.30)+.06*sin(f.x*21.0+seed*5.0);
        float aa=max(fwidth(f.y-ripple)*.7,.003);
        float line=1.0-smoothstep(max(0.0,.015-aa),.015+aa,abs(f.y-ripple));
        float ends=smoothstep(.08,.23,f.x)*(1.0-smoothstep(.51,.79,f.x));
        float mark=line*ends*step(.69,seed);
        col=mix(col,vec3(.25,.47,.56),mark*.65);
        float shine=1.0-smoothstep(max(0.0,.014-aa),.014+aa,abs(f.y-ripple-.12));
        col=mix(col,vec3(.64,.85,.79),shine*ends*step(.84,seed)*.7);
        float lip=4.0+12.0*sin(p.x*.017)+5.0*sin(p.x*.039+.6);
        float distance_to_lip=lip-p.y;
        if(world_pos.y>30.0) distance_to_lip=UV.x;
        float approach=exp(-max(distance_to_lip,0.0)*.18)*step(0.0,world_pos.y);
        float sweep=noise2(vec2(flowing.x*.55,flowing.y*.14));
        float foam=smoothstep(.57,.76,sweep)*approach;
        col=mix(col,vec3(.76,.91,.83),foam*.85);
    } else if(kind==3) {
        // Metres along the authored lip, continuous through every bend.
        vec2 p=vec2(UV.x,world_pos.y);
        float top=world_pos.z< -70.0?42.0:18.0;
        // Equal travel-time coordinates: marks accelerate as they descend.
        float depth=max(0.0,top-p.y);
        float travel=(sqrt(36.0+19.6*depth)-6.0)/9.8;
        float flow=(travel-scene_time)*10.0;
        float offset=.14*sin(flow*.75+p.x*.6)+.055*sin(flow*1.7+p.x);
        float strand=abs(sin((p.x+offset)*2.6));
        float aa=max(fwidth(strand)*.7,.02);
        float fine=1.0-smoothstep(max(0.0,.14-aa),.14+aa,strand);
        float ribbons=noise2(vec2(p.x*.65,flow*.26));
        col=mix(vec3(.22,.51,.61),vec3(.46,.75,.69),ribbons);
        float whitewater=smoothstep(.51,.78,noise2(vec2(p.x*.32,flow*.32)));
        col=mix(col,vec3(.65,.84,.77),whitewater*.48);
        col=mix(col,vec3(.78,.90,.81),fine*(.35+.55*ribbons));
        float ink=abs(sin((p.x+offset*.8)*1.2+.6));
        float iaa=max(fwidth(ink)*.7,.02);
        float dark=1.0-smoothstep(max(0.0,.10-iaa),.10+iaa,ink);
        col=mix(col,vec3(.23,.36,.46),dark*.6);
        float edge=exp(-max(0.0,top-p.y)*1.1);
        col=mix(col,vec3(.88,.94,.84),edge*.8);
    } else if(kind==4) {
        vec2 p=vec2(UV.x,(1.0-UV.y)*13.0);
        vec2 churn=p*vec2(.25,.50)+vec2(scene_time*.28,-scene_time*.72);
        float eddy=noise2(churn)+.35*noise2(churn*2.2+19.0);
        col=mix(vec3(.65,.83,.81),vec3(.86,.95,.87),smoothstep(.12,1.12,eddy));
        float curl=abs(sin(p.y*1.1+eddy*5.0-scene_time*1.25));
        float line=(1.0-smoothstep(.07,.21,curl))*smoothstep(.35,.68,noise2(churn*.73+7.0));
        col=mix(col,vec3(.97,.98,.87),line*.72);
    } else if(kind==5) {
        col *= .96+.04*smoothstep(-.5,.8,dot(normalize(world_normal),vec3(-.3,.9,.2)));
    }
    // Atmospheric distance changes only the opacity of the fixed drawing.
    float distance_to_eye=length(VERTEX);
    ALBEDO=azure_aerial(col,distance_to_eye,world_pos.y);
}
