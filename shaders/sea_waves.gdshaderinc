// Same phases and sharpened crest profile as NightCrossing.wave_height().
float swell(vec2 p,float t){
 float group=.78+.22*sin(dot(p,vec2(.043,-.027))-t*.31);
 float a=dot(p,vec2(.23,.34))-t*1.65+.38*sin(dot(p,vec2(.065,-.11))-t*.47);
 float b=dot(p,vec2(-.41,.19))-t*1.97+.29*sin(dot(p,vec2(.13,.049))+t*.38);
 float c=dot(p,vec2(.68,.53))-t*2.8;
 return group*1.10*(sin(a)+.22*cos(2.*a))+.55*(sin(b)+.20*cos(2.*b))+.19*sin(c)
       +.24*sin(dot(p,vec2(-.17,.073))-t*.91)+.12*sin(dot(p,vec2(.91,-.38))-t*3.43);
}
float sea_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float sea_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(sea_hash(i),sea_hash(i+vec2(1,0)),f.x),mix(sea_hash(i+vec2(0,1)),sea_hash(i+1.),f.x),f.y);}
