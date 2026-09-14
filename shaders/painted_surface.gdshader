shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D paper : filter_linear_mipmap, repeat_enable;
uniform int kind = 0; // wash, ink, water, crown, petal, sun
uniform float scene_time = 0.0;
uniform bool local_pigment=false;
uniform vec3 lotus_centers[7];
varying vec3 world_pos;
varying vec3 object_pos;
varying vec3 world_normal;
varying vec3 object_normal;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float wash(vec2 p) { return noise2(p)*.56+noise2(p*2.13+17.3)*.28+noise2(p*4.37-8.1)*.16; }
void vertex() {
    object_pos=VERTEX;
    object_normal=NORMAL;
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
    vec3 white=vec3(1.0,.995,1.0);
    vec3 col=COLOR.rgb;
    vec3 pigment_pos=local_pigment?object_pos:world_pos;
    vec3 n=abs(normalize(local_pigment?object_normal:world_normal));
    n/=max(.001,n.x+n.y+n.z);
    float grain=texture(paper,pigment_pos.xy*2.8).r*n.z+texture(paper,pigment_pos.xz*2.8).r*n.y+texture(paper,pigment_pos.yz*2.8).r*n.x;
    vec2 p=pigment_pos.xz*.40+vec2(pigment_pos.y*.20,pigment_pos.y*.33);
    float pigment=wash(p+vec2(wash(p*.74),wash(p*.83+31.0))*1.8);
    if(local_pigment) pigment=wash(p*5.7+vec2(wash(p*3.2+1.2),wash(p*2.8+13.4)));
    float bloom=noise2(p*2.6+vec2(4.1,7.3));
    if(kind==1) {
        col=mix(col,vec3(.70,.64,.77),grain*.22);
    } else if(kind==2) {
        vec2 q=world_pos.xz;
        float lavender=wash(q*.18+vec2(wash(q*.09)*3.0,0));
        float pink=wash(q*.27+vec2(18,34));
        float blue=wash(q*.23-vec2(23,7));
        col=mix(vec3(.96,.89,.98),vec3(.65,.56,.94),smoothstep(.29,.73,lavender)*.80);
        col=mix(col,vec3(.69,.91,.98),smoothstep(.46,.70,blue)*.57);
        col=mix(col,vec3(.98,.77,.93),smoothstep(.48,.75,pink)*.48);
        for(int i=0;i<7;i++) {
            float d=length(q-lotus_centers[i].xy)/(lotus_centers[i].z*2.4);
            float bleed=exp(-d*d*2.2)*(.65+noise2(q*3.3)*.35);
            col=mix(col,vec3(.52,.93,.78),bleed*.67);
        }
        // Slow glazes vary wet pigment density; their coordinates stay in world space.
        float ripple=sin(length(q-vec2(-4.2,7))*4.2-scene_time*.65);
        col-=vec3(.024,.027,.006)*ripple*exp(-length(q-vec2(-4.2,7))*.14);
        float deposit=smoothstep(.44,.50,lavender)-smoothstep(.50,.56,lavender);
        col-=vec3(.040,.045,.010)*deposit;
        col+=(grain-.5)*.12;
    } else if(kind==3) {
        float edge=abs(UV.y-.5)*2.0;
        float density=(.60+pigment*.61)*(1.0-smoothstep(.55,1.0,edge)*.8);
        col=mix(vec3(.87,.59,.94),col,smoothstep(.25,.80,UV.y+pigment*.18));
        col=mix(white,col,density);
        col=mix(col,white,smoothstep(.70,.84,bloom)*.25);
        col+=(grain-.5)*.065;
    } else if(kind==5) {
        col=mix(vec3(1,.57,.13),vec3(1,.27,.08),pigment);
        col+=(grain-.5)*.045;
    } else if(kind==8) {
        float pool=smoothstep(.63,1.05,length((UV-.5)*2.0)+noise2(world_pos.xz*7.0)*.16);
        float mottled=wash(world_pos.xz*2.8);
        col=mix(white,col,.42+mottled*.51+pool*.17);
        col=mix(col,vec3(.29,.71,.61),pool*.23);
        col=mix(col,white,smoothstep(.64,.82,noise2(world_pos.xz*5.3))*.30);
        col+=(grain-.5)*.10;
    } else if(kind==9) {
        float patch=wash(world_pos.xz*1.7+vec2(world_pos.y*.4));
        col=mix(white,col,.43+patch*.65);
        col=mix(col,vec3(.71,.84,.98),smoothstep(.47,.71,patch)*.30);
        col=mix(col,vec3(.96,.77,.92),smoothstep(.50,.72,noise2(world_pos.xz*.8+11.0))*.28);
        col=mix(col,white,smoothstep(.60,.78,noise2(world_pos.xz*3.3))*.32);
        col+=(grain-.5)*.10;
    } else {
        float density=.57+pigment*.57;
        if(local_pigment) density=.38+pigment*.94;
        if(kind==4 && !local_pigment) density=.32+wash(world_pos.xz*3.1+world_pos.y)*.91;
        col=mix(white,col,density);
        // Two pigment glazes and a subtle dry-paper break create interior variation.
        col=mix(col,vec3(.70,.82,.97),smoothstep(.50,.74,pigment)*.20);
        col+=(grain-.5)*.10;
        if(kind==4) {
            float edge=pow(abs(UV.x-.5)*2.0,8.0);
            col-=vec3(.12,.10,.08)*edge*.23;
        }
    }
    float distance_to_eye=length(world_pos-CAMERA_POSITION_WORLD);
    float fade=1.0-exp(-pow(distance_to_eye/43.0,1.7));
    if(kind==5)fade=0.0;
    ALBEDO=mix(clamp(col,vec3(0),vec3(1)),white,fade);
}
