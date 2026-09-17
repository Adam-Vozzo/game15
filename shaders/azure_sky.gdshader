shader_type sky;

void sky() {
    float elevation=max(EYEDIR.y,0.0);
    vec3 horizon=vec3(.63,.83,.94);
    vec3 blue=vec3(.38,.70,.91);
    vec3 zenith=vec3(.24,.55,.84);
    vec3 colour=mix(horizon,blue,smoothstep(-.025,.30,EYEDIR.y));
    colour=mix(colour,zenith,smoothstep(.25,1.0,elevation)*.74);
    vec3 sun=normalize(vec3(-.55,.72,.36));
    float toward=max(dot(EYEDIR,sun),0.0);
    colour=mix(colour,vec3(.98,.93,.76),pow(toward,20.0)*.20);
    float disc=smoothstep(.99952,.99972,toward);
    COLOR=mix(colour,vec3(1.0,.98,.83),disc*.88);
}
