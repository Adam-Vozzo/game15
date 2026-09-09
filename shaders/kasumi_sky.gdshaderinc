float khash(vec3 p) { p=fract(p*.3183099+vec3(.1,.2,.3));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
float knoise(vec3 p) {
    vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(mix(khash(i),khash(i+vec3(1,0,0)),f.x),mix(khash(i+vec3(0,1,0)),khash(i+vec3(1,1,0)),f.x),f.y),mix(mix(khash(i+vec3(0,0,1)),khash(i+vec3(1,0,1)),f.x),mix(khash(i+vec3(0,1,1)),khash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float kfbm(vec3 p) {return knoise(p)*.56+knoise(p*2.04)*.28+knoise(p*4.11)*.11+knoise(p*8.12)*.05;}
vec3 kasumi_sky(vec3 ray,float clock) {
    float h=max(ray.y,0.);
    vec3 sun=normalize(vec3(-.38,.06,-1.));float align=max(dot(ray,sun),0.);
    vec2 dome=ray.xz/(h+.42)*1.8;
    vec3 p=vec3(dome.x,1.1,dome.y)+vec3(clock*.009,0.,clock*.002);
    float cloud=kfbm(p);float veil=kfbm(p*.38+vec3(11,7,3));
    float mass=smoothstep(.31,.65,cloud+veil*.12);
    vec3 clear=mix(vec3(.20,.205,.25),vec3(.045,.073,.12),smoothstep(0.,.88,h));
    clear+=vec3(.13,.060,.026)*pow(align,22.);
    vec3 under=mix(vec3(.026,.041,.064),vec3(.095,.12,.16),veil);
    vec3 color=mix(clear,under,mass*.95);
    float edge=exp(-pow((cloud-.41)/.065,2.));
    color+=vec3(.050,.028,.018)*edge*pow(align,8.);
    color=mix(vec3(.12,.15,.19),color,smoothstep(-.08,.11,ray.y));
    vec3 moon=normalize(vec3(-.38,.37,-.8));
    float moon_alignment=max(dot(ray,moon),0.);
    float moon_veil=1.-mass*.70;
    color+=vec3(.12,.17,.19)*pow(moon_alignment,16.)*moon_veil;
    color+=vec3(.20,.25,.25)*pow(moon_alignment,180.)*moon_veil;
    float disc=smoothstep(.9991,.99965,moon_alignment);
    float lunar_detail=.88+.12*knoise(ray*430.);
    color+=vec3(.72,.79,.72)*disc*lunar_detail*moon_veil;
    return color;
}
