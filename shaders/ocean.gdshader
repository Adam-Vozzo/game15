shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float scene_time=0.0;
varying vec3 world_p;
void vertex(){
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    VERTEX.y+=sin(p.x*.28+p.z*.62-scene_time*.72)*.032+sin(p.z*1.8-scene_time*1.15)*.012;
    world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment(){
    vec3 normal=normalize(vec3(-.025*cos(world_p.x*.28+world_p.z*.62-scene_time*.72),1.,-.07*cos(world_p.z*1.8-scene_time*1.15)));
    vec3 view=normalize(INV_VIEW_MATRIX[3].xyz-world_p);
    float fresnel=pow(1.-max(dot(view,normal),0.),2.5);
    vec3 color=mix(vec3(.026,.115,.119),vec3(.21,.25,.28),fresnel);
    vec3 sun=normalize(vec3(-.27,.105,-1.));
    float sparkle=pow(max(dot(reflect(-sun,normal),view),0.),150.);
    color+=vec3(.98,.54,.23)*sparkle*.9;
    float ripples=sin(world_p.z*8.+sin(world_p.x*.8)*1.7-scene_time*1.2)*.006;
    color+=ripples;
    float shore=-.08+sin(world_p.x*.09)*1.1;
    float wash=world_p.z-shore+.50+sin(scene_time*.62+world_p.x*.06)*.38;
    float foam=exp(-abs(wash)*8.)*(.65+.35*sin(world_p.x*7.+world_p.z*3.));
    color=mix(color,vec3(.55,.59,.48),foam*.72);
    ALBEDO=color;
}
