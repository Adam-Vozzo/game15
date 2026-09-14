// User-directed colour across the apparent tree silhouette. The lattice and
// particle anchors stay in world space; only the red-white-cyan colour follows
// the viewer. Shared by fixed cells and their detached fragments.
uniform vec3 feature_root=vec3(1.6,.13,-3.);
uniform float feature_height=11.4;
float signal_edge(vec3 anchor, mat4 camera_view) {
    float height=clamp(anchor.y-feature_root.y,0.,feature_height);
    float radius=max(.20,feature_height*.325*pow(max(0.,1.-height/feature_height),.73));
    vec3 point=(camera_view*vec4(anchor,1.)).xyz;
    vec3 axis=(camera_view*vec4(feature_root.x,anchor.y,feature_root.z,1.)).xyz;
    // Perspective-correct horizontal separation from the trunk at this height.
    float separation=abs(point.x/max(.08,-point.z)-axis.x/max(.08,-axis.z));
    return clamp(separation*max(.08,-axis.z)/radius,0.,1.);
}
vec3 signal_color(float edge,float variation) {
    // Colour is a restrained bias among mostly silver glints, not solid bands.
    float scattered_edge=clamp(edge+(variation-.5)*.24,0.,1.);
    vec3 color=mix(vec3(.76,.27,.23),vec3(.88,.93,.90),smoothstep(0.,.48,scattered_edge));
    color=mix(color,vec3(.25,.63,.58),smoothstep(.43,.95,scattered_edge));
    float silver=smoothstep(.25,.72,variation)*.86;
    return mix(color,vec3(.88,.93,.90),silver);
}
