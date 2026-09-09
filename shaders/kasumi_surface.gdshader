shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D foliage : source_color, filter_nearest, repeat_disable;
uniform int foliage_kind = 0;
uniform int tile = 0;
uniform float scene_time = 0.0;
uniform float cloth = 0.0;
uniform float plant = 0.0;
uniform float mountain = 0.0;
uniform float terrain_surface = 0.0;
uniform vec4 shelter_bounds[20];
uniform int shelter_count = 0;
uniform vec4 lamp_anchors[12];
#include "res://shaders/kasumi_sky.gdshaderinc"
varying vec3 world_p;
varying vec3 world_n;
varying vec3 vertex_light;

vec3 ground_patch(vec2 p,vec2 cell,float column){
    vec2 offset=vec2(khash(vec3(cell,2.)),khash(vec3(cell,7.)))*17.;
    vec2 uv=p*.58+offset;
    return texture(atlas,vec2(column*.5,0.)+(fract(uv)*126.+1.)/256.).rgb;
}
vec3 ground_pigment(vec2 p,float column){
    vec2 cell=floor(p*.24),f=fract(p*.24);f=f*f*(3.-2.*f);
    return mix(mix(ground_patch(p,cell,column),ground_patch(p,cell+vec2(1,0),column),f.x),mix(ground_patch(p,cell+vec2(0,1),column),ground_patch(p,cell+vec2(1,1),column),f.x),f.y);
}

void vertex() {
    vec3 anchor = MODEL_MATRIX[3].xyz;
    if (cloth > .5) {
        float weight = pow(clamp(-VERTEX.y,0.,1.2),2.);
        VERTEX.x += weight*sin(scene_time*.91+anchor.z*.29)*.07;
        VERTEX.z += weight*sin(scene_time*1.26+VERTEX.x*3.)*.045;
    }
    if (plant > .5) {
        // Position is measured from the modeled root, not UV orientation.
        float weight = plant > 1.5 ? pow(clamp(VERTEX.y/9.,0.,1.),2.)*.28 : pow(max(VERTEX.y,0.),1.6)*.13;
        float gust = sin(scene_time*1.20+anchor.x*.18+anchor.z*.12)*.65+sin(scene_time*2.05+anchor.z*.38)*.22;
        VERTEX.x += weight*gust;
        VERTEX.z += weight*sin(scene_time*.94+anchor.x*.23)*.32;
    }
    world_p = (MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    world_n = normalize(mat3(MODEL_MATRIX)*NORMAL);
    float facing = max(dot(world_n,normalize(vec3(-.35,.75,-.40))),0.);
    float sky_fill = .24+.055*max(world_n.y,0.);
    vertex_light = vec3(.80,.90,.96)*(sky_fill+facing*.22)*(terrain_surface>.5?vec3(.94):COLOR.rgb);
}
void fragment() {
    // Perspective-correct object UVs keep architectural details fixed during motion.
    vec2 uv = UV;
    if ((tile==4 || tile==5) && world_n.y>.6) { uv=world_p.xz*.72; }
    vec2 origin = vec2(float(tile%2),float((tile%4)/2))*.5;
    vec2 sample_uv = origin+(fract(uv)*126.+1.)/256.;
    vec3 pigment = texture(atlas,sample_uv).rgb;
    if(terrain_surface>.5){
        float outskirts=smoothstep(10.,21.,abs(world_p.x));
        float path=1.-smoothstep(1.0,3.2,min(abs(world_p.z-17.),abs(world_p.z+51.)));
        float growth=knoise(vec3(world_p.x*.11,3.,world_p.z*.11));
        float moss=outskirts*(1.-path*.80)*smoothstep(.23,.76,growth);
        pigment=mix(ground_pigment(world_p.xz,0.),ground_pigment(world_p.xz,1.),moss*.73);
        pigment*=.92+.14*knoise(world_p*.08);
    }
    if(plant>1.5 && tile==11){
        vec2 cell=vec2(float(foliage_kind%2),float(foliage_kind/2))*.5;
        vec4 leaf=texture(foliage,cell+(clamp(UV,vec2(0.),vec2(1.))*126.+1.)/256.);
        if(leaf.a<.5){discard;}
        pigment=leaf.rgb;
    }
    vec3 color = pigment*vertex_light;
    if(terrain_surface>.5){
        // Ground contact shade is anchored to the masonry, independent of camera/depth samples.
        float shelter=0.;
        for(int i=0;i<20;i++){
            if(i>=shelter_count){break;}
            vec4 bounds=shelter_bounds[i];
            vec2 q=abs(world_p.xz-(bounds.xy+bounds.zw*.5))-bounds.zw*.5;
            float edge=length(max(q,vec2(0.)))+min(max(q.x,q.y),0.);
            shelter=max(shelter,1.-smoothstep(-.08,.85,edge));
        }
        color*=1.-shelter*.28;
    }
    float far_ground=smoothstep(65.,145.,length(world_p.xz));
    if (mountain>.5 || ((tile==4 || tile==5) && plant<.5)) {
        float land=sin(world_p.x*.063+sin(world_p.z*.036)*2.)*sin(world_p.z*.044)*.5+.5;
        vec3 distant=mix(vec3(.030,.050,.064),vec3(.055,.078,.092),land);
        color=mix(color,distant,mountain>.5?1.:far_ground);
    }
    if (tile==7) { color= pigment*vec3(1.15,.88,.60); }
    else if(mountain<.5){
        for(int i=0;i<12;i++){
            vec3 delta=lamp_anchors[i].xyz-world_p;
            float distance=length(delta);
            float falloff=pow(1.-smoothstep(.2,3.6,distance),2.);
            float facing=max(dot(normalize(world_n),delta/max(distance,.01)),0.);
            color+=pigment*vec3(.65,.30,.09)*falloff*(.2+.8*facing)*lamp_anchors[i].w;
        }
    }
    if (tile==4 || tile==3) {
        vec3 eye = normalize(INV_VIEW_MATRIX[3].xyz-world_p);
        float sheen = pow(1.-abs(dot(eye,normalize(world_n))),4.);
        float wet = smoothstep(.15,.75,sin(world_p.x*1.8+sin(world_p.z*.42))*sin(world_p.z*.69));
        color = mix(color,color*.73+vec3(.025,.038,.052)*sheen,wet*.68*max(world_n.y,0.));
        if(tile==4 && world_n.y>.85 && abs(world_p.x)<2.10){
            vec2 q=world_p.xz*vec2(.77,.31);
            float pool=knoise(vec3(q.x,1.3,q.y))*.70+knoise(vec3(q.x*3.1,4.3,q.y*3.1))*.30;
            float patch=smoothstep(.55,.72,pool)*(1.-smoothstep(1.65,2.1,abs(world_p.x)));
            vec3 reflected=reflect(-eye,vec3(sin(world_p.z*8.+scene_time)*.004,1.,0.));
            vec3 reflection=kasumi_sky(reflected,scene_time)*.49;
            vec2 cell=fract(world_p.xz*2.1)-.5;
            float age=fract(scene_time*.65+khash(vec3(floor(world_p.xz*2.1),4.)));
            float ring=(1.-smoothstep(.01,.025,abs(length(cell)-age*.55)))*(1.-age);
            // Keep the soil readable beneath a shallow wet sheen.
            reflection=max(reflection,color*.85);
            color=mix(color,reflection+ring*.009,patch*(.20+sheen*.55));
        }
    }
    if (tile==6) { color*=.52; color+=vec3(.010,.020,.032)*max(world_n.y*.1+.65,0.); }
    ALBEDO = max(color,vec3(0.));
}
