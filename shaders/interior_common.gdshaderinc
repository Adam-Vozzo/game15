float fixture_power(float t){
 // A short, irregular ballast failure about twice a minute; the remaining
 // fittings keep the room readable. All inputs use the pausable scene clock.
 float phase=mod(t+3.,29.7);
 float dip=1.;
 if(phase>14.1 && phase<14.82){dip=.28+.72*step(.28,sin(t*53.)*sin(t*19.));}
 if(phase>15.0 && phase<15.17){dip=.18;}
 return dip;
}
float opening_beam(vec3 p,vec4 hole){
 vec2 projected=p.xz+(84.-p.y)*vec2(.16,.10);
 vec2 q=abs(projected-hole.xy)/(hole.zw*.5);
 return (1.-smoothstep(.72,1.,q.x))*(1.-smoothstep(.72,1.,q.y))*step(0.,p.y)*step(p.y,84.);
}
float reservoir_beam(vec3 p){
 return max(opening_beam(p,vec4(8.,-21.,7.,10.)),max(opening_beam(p,vec4(8.,-73.,7.,10.)),opening_beam(p,vec4(-44.,-125.,8.,12.))));
}
