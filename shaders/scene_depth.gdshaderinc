// Shared by the two atmosphere passes. Occlusion is applied to geometry before
// fog, so distant mist and the sky do not acquire dirty screen-space outlines.
uniform float ao_strength : hint_range(0.0, 1.0) = 0.62;
uniform float ao_radius : hint_range(0.1, 2.0) = 1.0;
uniform int ao_samples : hint_range(4, 12) = 12;

vec3 depth_position(vec2 uv, float depth, mat4 inverse_projection) {
    // Compatibility uses OpenGL NDC, including the -1..1 depth range.
    vec4 p = inverse_projection * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 nearby_position(vec2 uv, mat4 inverse_projection) {
    return depth_position(uv, texture(depth_texture, uv).r, inverse_projection);
}

float contact_occlusion(vec2 uv, vec3 position, vec2 viewport_size, mat4 inverse_projection, mat4 projection) {
    if (ao_strength <= 0.0 || -position.z > 55.0) { return 1.0; }
    vec2 pixel = 1.0 / viewport_size;
    // Pick the shorter tangent on either side of a pixel to avoid reconstructing
    // a normal across the discontinuity at a tree, roof, or grass silhouette.
    vec3 left = position - nearby_position(uv - vec2(pixel.x, 0.0), inverse_projection);
    vec3 right = nearby_position(uv + vec2(pixel.x, 0.0), inverse_projection) - position;
    vec3 down = position - nearby_position(uv - vec2(0.0, pixel.y), inverse_projection);
    vec3 up = nearby_position(uv + vec2(0.0, pixel.y), inverse_projection) - position;
    vec3 dx = dot(left,left) < dot(right,right) ? left : right;
    vec3 dy = dot(down,down) < dot(up,up) ? down : up;
    vec3 normal = cross(dx,dy);
    if (dot(normal,normal) < 0.00000001) { return 1.0; }
    normal = normalize(normal);
    if (dot(normal,-position) < 0.0) { normal = -normal; }
    vec2 radius_uv = vec2(projection[0][0],projection[1][1]) * ao_radius * 0.5 / max(-position.z,0.1);
    float obscured = 0.0;
    for (int i = 0; i < 12; i++) {
        if (i >= ao_samples) { break; }
        float angle = float(i) * 2.39996323;
        float radius = sqrt((float(i)+0.5)/float(ao_samples));
        vec2 sample_uv = uv + vec2(cos(angle),sin(angle)) * radius_uv * radius;
        if (any(lessThan(sample_uv,pixel)) || any(greaterThan(sample_uv,vec2(1.0)-pixel))) { continue; }
        float sample_depth = texture(depth_texture,sample_uv).r;
        if (sample_depth < 0.00001) { continue; }
        vec3 delta = depth_position(sample_uv,sample_depth,inverse_projection) - position;
        float separation = length(delta);
        float horizon = max(dot(normal,delta)/max(separation,0.0001)-0.10,0.0);
        // World-space range rejection prevents dark halos from distant geometry.
        obscured += horizon * (1.0-smoothstep(ao_radius*0.20,ao_radius,separation));
    }
    float fade = 1.0-smoothstep(22.0,55.0,-position.z);
    return 1.0-clamp(obscured/float(ao_samples)*ao_strength*3.2*fade,0.0,0.38);
}

vec3 deepen_shadows(vec3 color, float contrast, float black_point, float gain) {
    // Grade luminance so hue stays stable and bright moon/sun/window colors survive.
    float luminance = max(dot(color,vec3(0.2126,0.7152,0.0722)),0.00001);
    float shaped = pow(max((luminance-black_point)/(1.0-black_point),0.0),contrast)*gain;
    return color * (shaped/luminance);
}
