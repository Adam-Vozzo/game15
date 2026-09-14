// Same phases and sharpened crest profile as NightCrossing.wave_height().
float swell(vec2 p,float t){
 vec2 q=p+vec2(2.7*sin(dot(p,vec2(.031,.071))+t*.13),2.1*sin(dot(p,vec2(-.053,.029))-t*.17));
 float group=.58+.26*sin(dot(p,vec2(.073,-.047))-t*.31)+.16*cos(dot(p,vec2(.039,.081))+t*.23);
 float cross_group=.61+.39*sin(dot(p,vec2(-.067,.093))+t*.27);
 float a=dot(q,vec2(.23,.34))-t*1.65+.73*sin(dot(p,vec2(.065,-.11))-t*.47);
 float b=dot(q,vec2(-.41,.19))-t*1.97+.64*sin(dot(p,vec2(.13,.049))+t*.38);
 float c=dot(q,vec2(.68,.53))-t*2.8+.41*sin(p.y*.17-t*.29);
 return group*1.23*(sin(a)+.19*sin(2.*a))+.71*cross_group*(sin(b)+.17*sin(2.*b))+.21*sin(c)
       +.32*sin(dot(q,vec2(-.17,.073))-t*.91)+.13*sin(dot(q,vec2(.91,-.38))-t*3.43)
       +.18*sin(dot(p,vec2(.117,-.263))-t*1.38+.6*sin(p.x*.083+t*.19));
}
float sea_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float sea_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(sea_hash(i),sea_hash(i+vec2(1,0)),f.x),mix(sea_hash(i+vec2(0,1)),sea_hash(i+1.),f.x),f.y);}
