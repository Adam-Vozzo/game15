shader_type canvas_item;
uniform sampler2D scene_texture:hint_screen_texture,filter_linear;
void fragment(){
    vec3 col=texture(scene_texture,SCREEN_UV).rgb;
    vec3 halo=vec3(0.);
    for(int i=0;i<8;i++){
        float a=float(i)*6.2831853/8.;vec2 d=vec2(cos(a),sin(a));
        halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*2.).rgb-vec3(.48),vec3(0.))*.055;
        halo+=max(texture(scene_texture,SCREEN_UV+d*SCREEN_PIXEL_SIZE*6.).rgb-vec3(.52),vec3(0.))*.035;
    }
    col=max(col-vec3(.022),vec3(0.))*1.09+halo;
    col*=1.-.15*smoothstep(.2,.77,length((UV-.5)*vec2(1.,.8)));
    COLOR=vec4(col,1.);
}
