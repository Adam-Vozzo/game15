// Shared aerial colour keeps ink, foam and particles in the same sunny air.
vec3 azure_aerial(vec3 colour, float distance_to_eye, float elevation) {
    float air=1.0-exp(-max(distance_to_eye-70.0,0.0)*.00135);
    air=min(air,.68);
    vec3 haze=mix(vec3(.78,.87,.91),vec3(.57,.76,.92),smoothstep(-35.0,180.0,elevation));
    return mix(colour,haze,air);
}
