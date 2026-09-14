shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform sampler2D reflection_texture:filter_linear,repeat_disable;
uniform float reflection_height=36.;
uniform float scene_time=0.;
uniform float flash=0.;
uniform vec3 lamps[24];
uniform int lamp_count=0;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    // Static irregular shorelines; only the small water ripples move.
    vec2 local=(UV-.5)*2.;
    float shore=1.-length(local)+.15*(noise(wp.xz*1.7)-.5)+.13*sin(local.x*5.+local.y*3.);
    float edge=smoothstep(.015,.16,shore);
    vec2 gradient=vec2(0.);float rings=0.;
    vec2 cell=floor(wp.xz*3.);
    for(int x=-1;x<=1;x++)for(int z=-1;z<=1;z++){
        vec2 tile=cell+vec2(float(x),float(z));float seed=hash(tile);
        vec2 centre=(tile+vec2(.15+.7*seed,.15+.7*hash(tile+31.)))/3.;
        vec2 delta=wp.xz-centre;float radius=length(delta);
        float phase=fract(scene_time*(.85+seed*.7)+seed*11.);
        float wave=exp(-pow((radius-phase*.20)/.012,2.))*(1.-phase)*step(.25,seed);
        rings+=wave;gradient+=normalize(delta+vec2(.0001))*wave*.028;
    }
    gradient+=vec2(sin(wp.z*15.+scene_time*1.8),cos(wp.x*12.-scene_time*1.3))*.004;
    vec3 normal=normalize(vec3(gradient.x,1.,gradient.y));
    vec3 eye=normalize(CAMERA_POSITION_WORLD-wp);
    float fresnel=.20+.65*pow(1.-max(dot(normal,eye),0.),3.);
    vec3 sky=vec3(.10,.16,.20)+vec3(.27,.34,.41)*flash;
    vec2 reflection_uv=vec2(SCREEN_UV.x,1.-SCREEN_UV.y)+gradient*.13;
    vec3 reflected=texture(reflection_texture,clamp(reflection_uv,vec2(.002),vec2(.998))).rgb;
    // A single local mirror is sufficient for the terrace under the player.
    // Other elevations keep their own sky/lamplight rather than a wrong mirror.
    float local_mirror=1.-smoothstep(.12,.30,abs(wp.y-reflection_height));
    vec3 col=mix(vec3(.025,.046,.057),sky,fresnel);
    col=mix(col,reflected*(.82+flash*.18),local_mirror*(.38+fresnel*.50));
    for(int i=0;i<24;i++){
        if(i>=lamp_count){break;}
        vec3 delta=lamps[i]-wp;
        vec3 halfway=normalize(normalize(delta)+eye);
        float sheen=pow(max(dot(normal,halfway),0.),36.)*exp(-length(delta)*.11);
        col+=vec3(.85,.38,.10)*sheen*.7;
    }
    col+=vec3(.10,.16,.19)*rings*(.25+flash*.45);
    col+=vec3(.055,.09,.11)*exp(-abs(shore-.09)*55.)*(.5+flash);
    // Transparent water follows the opaque-screen fog composite.
    float transmission=exp(-distance(CAMERA_POSITION_WORLD,wp)*.027*(1.-flash*.87));
    vec3 fog_tint=mix(vec3(.062,.088,.108),vec3(.13,.16,.18),smoothstep(-20.,60.,wp.y))+flash*vec3(.055,.070,.09);
    ALBEDO=mix(fog_tint,col,transmission);
    ALPHA=edge*(.78+fresnel*.18);
}
