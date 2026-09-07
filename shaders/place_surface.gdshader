shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D base_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 base_color : source_color = vec3(1.0);
uniform vec3 light_color = vec3(1.0);
uniform vec3 light_direction = vec3(-0.4,0.6,-0.5);
uniform float scene_time = 0.0;
uniform float glow = 0.0;
uniform float motion = 0.0;
uniform float wetness = 0.0;
uniform float sand_surface = 0.0;
varying vec3 world_p;
varying vec3 world_n;
void vertex(){
    if(motion>1.5){float weight=clamp(-VERTEX.y,0.,1.);VERTEX.z+=weight*weight*sin(scene_time*1.1+VERTEX.x*2.5)*.065;}
    else if(motion>.5){float weight=clamp(length(VERTEX.xz)/3.5,0.,1.);VERTEX.x+=weight*weight*sin(scene_time*.85+VERTEX.z)*.10;VERTEX.y+=weight*sin(scene_time*1.05+VERTEX.x*.7)*.035;}
    world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    world_n=normalize(mat3(MODEL_MATRIX)*NORMAL);
    vec4 clip=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.);
    vec2 grid=VIEWPORT_SIZE*.75;clip.xy=mix(clip.xy,floor(clip.xy/clip.w*grid+.5)/grid*clip.w,.12);POSITION=clip;
}
void fragment(){
    vec3 pigment=texture(base_texture,UV).rgb*base_color;
    float light=.40+.70*max(dot(normalize(world_n),normalize(light_direction)),0.);
    vec3 color=pigment*light*light_color;
    if(sand_surface>.5){
        float edge=world_p.z-sin(world_p.x*.09)*1.1;
        float wet=1.-smoothstep(.1,2.9+sin(scene_time*.62)*.4,edge);
        color=mix(color,color*.73+vec3(.018,.022,.025),wet*.85);
    }
    if(wetness>.5){
        float puddle=smoothstep(.56,.80,sin(world_p.x*1.2+sin(world_p.z*.7))*.28+sin(world_p.z*.9+world_p.x*.8)*.22+.5);
        vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-world_p);
        float sheen=pow(1.-abs(dot(eye,normalize(world_n))),3.0);
        color=mix(color,color*.48+vec3(.12,.16,.17)*sheen,puddle*.85);
        float warm=exp(-pow((abs(world_p.x)-3.2)/.5,2.0))*pow(max(sin(world_p.z*1.3),0.),6.0);
        color+=vec3(.19,.12,.04)*warm*puddle*sheen;
        vec2 cell=fract(world_p.xz*.55)-.5;float ring=abs(fract(length(cell)*2.-scene_time*.42)-.45);
        color+=vec3(.055,.065,.066)*puddle*(1.-smoothstep(.014,.033,ring))*.4;
    }
    ALBEDO=mix(color,pigment*1.25,glow);
}
