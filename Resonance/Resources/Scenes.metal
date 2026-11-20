#include <metal_stdlib>
using namespace metal;

constant float pi = 3.14159265;
struct Uniforms {
    float4 canvas;  // pixel size, integrated time, scene detail
    float4 energy;  // bass, midrange, treble, level
    float4 look;    // brightness, onset, scene, palette
    float4 tint;
    float4 lowSpectrum, highSpectrum;
    float4 gesture; // filtered local cursor x/y, strength, motion amount
};
struct Surface { float4 position [[position]]; float2 uv; };
struct Fabric { float4 position [[position]]; float3 normal; float3 world; float2 uv; };
struct Dust { float4 position [[position]]; float size [[point_size]]; float4 color; };

float hash(float2 p) {
    float3 q = fract(float3(p.xyx)*float3(.1031,.1030,.0973));
    q += dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z);
}
float noise(float2 p) {
    float2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+float2(1,0)),f.x),mix(hash(i+float2(0,1)),hash(i+1.),f.x),f.y);
}
float fbm(float2 p) {
    float sum=0., amp=.52;
    for(int i=0;i<5;i++){sum+=amp*noise(p); p=float2(p.x*.8-p.y*.6,p.x*.6+p.y*.8)*2.04+3.17; amp*=.49;}
    return sum;
}
float2 rotate(float2 p,float a){float c=cos(a),s=sin(a); return float2(c*p.x-s*p.y,s*p.x+c*p.y);}
// Each duotone has separate body and highlight pigments. Preserve the material's
// luminance and a small amount of its reflected source color under the new dye.
struct Duotone { float3 body, highlight; };
constant Duotone collectionDyes[] = {
    {float3(.22,1.20,.84), float3(.92,1.28,.90)}, // Deep Jade
    {float3(.73,.51,1.53), float3(1.47,.98,1.62)}, // Ultraviolet
    {float3(1.52,.98,.52), float3(1.35,1.22,.99)}, // Champagne
    {float3(1.49,.67,.92), float3(1.42,1.04,1.15)}, // Rose Quartz
    {float3(.30,.94,1.43), float3(.76,1.33,1.25)}, // Petrol Blue
    {float3(1.68,.70,.38), float3(1.56,1.13,.72)}, // Terracotta
    {float3(.62,.95,1.44), float3(1.04,1.30,1.51)}, // Glacier
    {float3(1.52,.35,.50), float3(1.61,.84,.76)} // Garnet
};
float3 grade(float3 rgb, constant Uniforms &u) {
    float l=dot(rgb,float3(.22,.63,.15));
    if(u.look.w==1.) rgb=mix(rgb,float3(.86,.92,1.)*l, .82);
    if(u.look.w==2.) rgb=mix(rgb,float3(1.36,.86,.60)*l,.88);
    int dye=int(u.look.w)-4;
    if(dye>=0 && dye<8){
        Duotone pigments=collectionDyes[dye];
        float3 pigment=mix(pigments.body,pigments.highlight,smoothstep(.14,1.25,l));
        rgb=mix(rgb,l*pigment,.90);
    }
    rgb *= u.tint.rgb*u.look.x*(.93+.12*u.energy.w);
    return 1.-exp(-max(rgb,0.));
}
vertex Surface plane(uint id [[vertex_id]]) {
    float2 uv=float2((id<<1)&2,id&2); return {float4(uv*2.-1.,.98,1.),uv};
}
// Interpolate the eight measured spectral regions across the geometry.
float spectral(float position, constant Uniforms &u) {
    float index = saturate(position)*7.; int a=int(index), b=min(7,a+1);
    float x=a<4 ? u.lowSpectrum[a] : u.highSpectrum[a-4];
    float y=b<4 ? u.lowSpectrum[b] : u.highSpectrum[b-4];
    return mix(x,y,fract(index));
}
float3 cosmic(float2 p,constant Uniforms &u) {
    float t=u.canvas.z*.075, detail=u.canvas.w;
    p=rotate(p-float2(.28,.025),-.23+.04*u.gesture.w*sin(t*.29));
    float impact=u.look.y, bass=u.energy.x, mid=u.energy.y, air=u.energy.z;
    p /= 1.+.12*bass+.065*impact;
    float2 q=p*float2(.70,1.25);
    q.y+=.22*mid*sin(2.9*q.x+t);
    float field=fbm(q*2.4+float2(.12*t,0));
    float fil=fbm(q*(3.+detail*2.)+float2(field*3.2,t*.12));
    float d=p.y-(.13+.25*bass)*sin(2.4*p.x+t*.23)-(.33+.65*mid)*(field-.5);
    d-=.12*spectral(.5+p.x*.3,u)*sin(p.x*5.-t);
    float gas=exp(-abs(d)*(5.2-1.7*bass))*(.17+pow(fil,3.)*(5.6+5.*mid+4.*impact));
    float3 col=float3(.016,.021,.046)+gas*mix(float3(.07,.13,.28),float3(.51,.27,.30),smoothstep(.27,.71,field));
    col+=float3(.66,.49,.38)*exp(-abs(d+(fil-.53)*.37)*29.)*pow(fil,2.)*(1.+u.energy.x*.50);
    // Backlit planetary limb interrupts the distant gas.
    float2 local=p-float2(.28,.035); float r=.29+.10*bass;
    float limb=length(local)-r; float facing=saturate(dot(normalize(local+.0001),normalize(float2(-.52,.9))));
    col=mix(float3(.021,.029,.055)+.042*fil, col,smoothstep(-.003,.003,limb));
    col+=float3(.82,.68,.56)*facing*facing*(.67*exp(-abs(limb)*310.)+.18*exp(-abs(limb)*32.));
    float wave=length(local)-r-(1.-impact)*.82;
    col+=float3(.79,.40,.21)*impact*exp(-abs(wave)*(23.+18.*impact))*(.45+fil);
    col+=float3(.25,.42,.77)*air*exp(-abs(d+.18*field)*11.)*(.3+fil);
    for(int j=0;j<2;j++){
        float2 st=p*(75.+float(j)*54.)+float2(t*.23,j*43.);
        float star=hash(floor(st)); float s=length(fract(st)-.5);
        col+=float3(.56,.69,.85)*step(.985,star)*exp(-s*s*42.)*(.2+.2*star+1.6*air)*smoothstep(-.002,.005,limb);
    }
    return col;
}
float3 frequency(float2 p,constant Uniforms &u) {
    float t=u.canvas.z*.28; p.x-=.11; p=rotate(p,-.12);
    float3 c=float3(.014,.019,.022)+float3(.02,.028,.025)*exp(-dot(p,p)*1.7);
    for(int i=0;i<7;i++){
        float lane=float(i)-3., x=p.x, e=exp(-x*x*1.65);
        float y=e*((.12+.14*u.gesture.w)*sin(3.3*x+t)+(.105+.086*u.energy.x)*sin(6.2*x-t*1.12)+lane*(.014+.015*u.canvas.w)*cos(x*2.4+t*.36));
        float local=spectral(.5+.32*x,u);
        y+=e*((.31*u.energy.x+.075*u.look.y)*sin(x*3.5+t+.8)
             +.19*u.energy.y*sin(8.*x-t*1.3)+local*.11*sin(14.*x+t+lane*.19)
             +lane*(.042*u.energy.z+.018*u.look.y)*cos(x*3.6-t*.5));
        float d=abs(p.y-y); float aa=max(fwidth(p.y-y),.001);
        float3 shade=mix(float3(.22,.36,.36),float3(.89,.76,.51),float(i)/6.);
        c+=shade*((.62+.65*u.energy.z)*(1.-smoothstep(.0007,.0007+aa,d))+(.045+.17*u.look.y+.08*u.energy.y)*exp(-d*(95.-36.*u.energy.x)))*e;
    }
    return c;
}
fragment float4 atmosphere(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=(in.uv-.5)*2.; p.x*=u.canvas.x/u.canvas.y;
    int scene=int(u.look.z);
    float3 col;
    if(scene==3) col=cosmic(p,u);
    else if(scene==4) col=frequency(p,u);
    else if(scene==1) col=float3(.014,.022,.037)+float3(.04,.07,.084)*exp(-dot(p,p)*1.24);
    else if(scene==2) col=mix(float3(.018,.02,.027),float3(.14,.15,.18),exp(-length(p-float2(.42,.26))*1.7));
    else {
        float mist=exp(-dot((p-float2(.4,.0))*float2(.8,1.8),(p-float2(.4,0))*float2(.8,1.8)));
        col=float3(.022,.029,.065)+mist*float3(.07,.079,.17)+float3(.065,.019,.07)*exp(-length(p+float2(.7,.2))*1.9);
    }
    col*=1.-.21*smoothstep(.2,1.3,length(in.uv-.5)*1.7);
    return float4(grade(col,u)+(hash(in.position.xy)-.5)*.003,1);
}
float2 gridUV(uint id,uint nx,uint ny) {
    uint cell=id/6, corner=id%6;
    uint x=cell%nx+(corner==1||corner==2||corner==4);
    uint y=cell/nx+(corner==2||corner==4||corner==5);
    return float2(x,y)/float2(nx,ny);
}
// A pleated sheet twisted along its long axis. Its folds occlude one another in depth.
float3 silk(float2 uv,constant Uniforms &u) {
    float x=(uv.x-.5)*5.6, s=uv.y*2.-1., t=u.canvas.z*.19;
    float theta=.75*x+.84*sin(x*.98-t*.31)+.55*u.gesture.w*sin(t*.42)+.15;
    float local=spectral(uv.x,u);
    float width=(.48+.25*cos(x*.94+t*.3))*(1.+.48*u.energy.x);
    theta+=.96*u.energy.y*sin(x*1.7+t)+.22*u.look.y;
    float curl=theta+1.30*s+.19*sin(x*2.2+s*2.4+t);
    float fold=.052*sin(s*(9.+u.canvas.w*8.)+x*2.1+t)+.006*sin(s*32.-x*4.);
    fold+=.046*(u.energy.z+local)*sin(s*18.-x*4.3+t);
    float lift=.25*sin(x*1.38+t*.48)+.12*x
              +(.26*u.energy.x+.10*u.look.y)*sin(t+x*2.+.5)+.13*local*cos(x*5.+t);
    return float3(x+.09*s*sin(x+t),lift+width*s*cos(curl)+fold, .3+width*s*sin(curl)+fold*1.25);
}
float3 alloy(float2 uv,constant Uniforms &u) {
    float a=uv.x*2.*pi,b=uv.y*2.*pi,t=u.canvas.z*.13;
    float local=spectral(.5-.5*cos(a),u);
    float major=.91+(.13+.19*u.energy.x)*cos(3.*a+t*.38)+.095*local*sin(5.*a-t);
    float twist=2.*a+t*.46+.5*u.canvas.w+.88*u.energy.y*sin(2.*a+t)+.77*u.look.y;
    float sectionX=(.30+.17*u.energy.x+.08*u.look.y)*cos(b), sectionY=(.145+.055*u.canvas.w)*sin(b);
    float2 section=rotate(float2(sectionX,sectionY),twist);
    float3 v=float3((major+section.x)*cos(a),(major+section.x)*sin(a),section.y+.29*sin(2.*a+t*.43));
    v.yz=rotate(v.yz,.84+.12*u.gesture.w*sin(t*.25)); v.xy=rotate(v.xy,.32+.07*sin(t*.32)+.19*u.look.y);
    return v+float3(.18,.025,0);
}
vertex Fabric sculpture(uint id [[vertex_id]],constant Uniforms &u [[buffer(0)]]) {
    float2 uv=gridUV(id,168,52); bool metal=u.look.z==2.;
    float e=.0005;
    float3 p=metal?alloy(uv,u):silk(uv,u);
    float3 dx=(metal?alloy(uv+float2(e,0),u):silk(uv+float2(e,0),u))-p;
    float3 dy=(metal?alloy(uv+float2(0,e),u):silk(uv+float2(0,e),u))-p;
    float lens=1./(1.-p.z*.135);
    return {float4(p.xy*lens*float2(u.canvas.y/u.canvas.x,1.),.52-p.z*.25,1.),normalize(cross(dx,dy)),p,uv};
}
fragment float4 aurora(Fabric in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float3 n=normalize(in.normal); float2 uv=in.uv;
    float face=abs(n.z), grazing=pow(1.-face,1.35);
    float tilt=n.y*.48+uv.y*.76+.16*sin(in.world.x*1.43+u.canvas.z*.11);
    float3 ink=mix(float3(.11,.065,.31),float3(.32,.16,.59),smoothstep(-.3,.45,tilt));
    ink=mix(ink,float3(.12,.49,.57),smoothstep(.38,.86,tilt));
    float glint=pow(saturate(abs(dot(n,normalize(float3(.18,-.77,.62))))),13.);
    float filament=.5+.5*cos(uv.y*440.+2.*sin(in.world.x*1.56+uv.y*12.)+u.energy.z*.8);
    float stripe=smoothstep(.90,1.,filament)*(1.-smoothstep(.09,.48,fwidth(uv.y)*70.));
    float hem=exp(-min(uv.y,1.-uv.y)*95.);
    float rim=pow(1.-abs(n.z),3.5);
    float sheen=pow(saturate(dot(n,normalize(float3(-.35,.61,.71)))),5.);
    float3 color=ink*(.42+.88*face+.12*stripe)+grazing*float3(.28,.39,.55)+sheen*float3(.34,.28,.35)+rim*float3(.16,.27,.26)
        +glint*float3(.52,.53,.64)+(.14+.18*u.energy.z)*stripe*ink+hem*float3(.52,.56,.67);
    return float4(grade(color,u),1);
}
fragment float4 chrome(Fabric in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float3 n=normalize(in.normal), v=normalize(float3(0,0,5)-in.world);
    float3 r=reflect(-v,n); r.yz=rotate(r.yz,.42*u.energy.z);
    float strip=smoothstep(.28,.34,r.y)*(1.-smoothstep(.58,.62,r.y));
    float softbox=exp(-pow((r.x+.53)*5.,2.))*smoothstep(-.55,.55,r.z);
    float seam=.72*exp(-abs(r.y+.28)*43.);
    float3 c=float3(.044,.048,.058)+float3(.43,.48,.54)*(.5+.5*r.y)
          +float3(.92,.93,.98)*strip+float3(.68,.59,.50)*softbox+float3(.55,.75,.82)*seam;
    c*=.48+.49*smoothstep(-.67,.76,in.world.z)+.09*u.energy.y;
    return float4(grade(c,u),1);
}
vertex Dust motes(uint id [[vertex_id]],constant Uniforms &u [[buffer(0)]]) {
    float seed=float(id); float a=hash(float2(seed,11.)),b=hash(float2(seed,25.)),c=hash(float2(seed,43.));
    float t=u.canvas.z*.14, x=(a-.5)*3.8;
    float local=spectral(a,u);
    float theta=b*2.*pi+x*(2.8+1.1*u.energy.y)+t*.51+local*.48;
    float shell=floor(c*5.)/5.;
    float radius=(.16+.31*shell+.07*c*c)*(.74+.44*u.canvas.w+.32*u.energy.x+.13*u.look.y);
    float3 p=float3(x, (.19+.12*u.gesture.w)*sin(1.9*x+t*.52)+radius*sin(theta),radius*cos(theta));
    p.y+=(.082+.11*u.energy.y)*sin(5.*x+theta+t)*c; p.x+=.18*u.look.y*cos(theta); p.xy=rotate(p.xy,.21);
    float focus=smoothstep(-.45,.39,p.z);
    float size=(1.1+2.1*c+2.2*(1.-focus)+1.7*u.energy.z)*u.canvas.y/700.;
    float3 color=mix(float3(.22,.56,.63),float3(.92,.73,.48),smoothstep(.17,.83,b));
    float light=(.49+.89*focus)*(.78+.22*sin(a*80.+t+u.energy.z*2.));
    return {float4(p.xy*float2(u.canvas.y/u.canvas.x,1.)/(1.-p.z*.24),.3,1.),clamp(size,1.,9.),float4(grade(color*(light+.45*u.look.y+.38*local),u),focus)};
}
fragment float4 moteLight(Dust in [[stage_in]], float2 pt [[point_coord]]) {
    float d=length(pt-.5)*2.; return float4(in.color.rgb*exp(-d*d*(2.+in.color.a))*(1.-smoothstep(.5,1.,d)),1);
}
