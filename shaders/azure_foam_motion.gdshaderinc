// Connected, surface-anchored billows. UV.x is shoreline metres and UV.y
// wraps the closed source cross-section (glTF reverses its V coordinate).
vec3 azure_foam_position(vec3 p, vec3 n, vec2 uv, float t) {
    float angle=(1.0-uv.y)*6.283185;
    float crest=pow(max(sin(angle),0.0),1.35);
    float surge=.66*sin(uv.x*.31-t*1.65)+.34*sin(uv.x*.73+t*2.05+.9);
    float scale=p.y<0.0?2.35:1.55;
    vec2 outward=normalize(n.xz+vec2(.00001));
    float roll=sin(angle*1.8-t*2.15+uv.x*.23);
    p.y+=crest*scale*surge;
    p.xz+=outward*crest*(.70*roll+.28*surge);
    return p;
}
