// Collection II. Coordinates are height-relative, preserving aspect ratio across displays.
float lineLight(float d,float width) { return exp(-abs(d)/max(width,.0001)); }
float2 localPointer(constant Uniforms &u) {
    return u.gesture.xy * float2(u.canvas.x/u.canvas.y,1) / max(.001,u.gesture.z);
}

fragment float4 art_velvet(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.43, range=u.gesture.w;
    float3 c=mix(float3(.016,.018,.066),float3(.082,.049,.17),saturate(.48+p.y*.36));
    // Integrate translucent curtain slices, varying their vertical rays along the arc.
    for(int i=0;i<14;i++) {
        float z=float(i)/13.,x=p.x+.45*z;
        float arc=-.21+.18*x+.30*sin(x*1.54+z*2.+range*.32*sin(t*.47))
            +.14*sin(x*3.2-z*2.1-t*.19)+.46*z;
        float h=p.y-arc;
        float curtain=exp(-max(h,0.)/(.14+.22*z+.16*u.energy.x))
            *smoothstep(-.026-.024*z,.023,h);
        float rays=.44+.56*noise(float2(x*(11.+15.*u.canvas.w)+z*5.+t*.13,z));
        float3 dye=mix(float3(.36,.13,.62),float3(.09,.65,.56),smoothstep(-.2,.85,x+.4*sin(z*4.+t*.21)));
        c+=dye*curtain*rays*(.109+.063*u.energy.y)
            +float3(.32,.49,.58)*lineLight(h,.009+.018*z)*(.065+.06*u.energy.z);
    }
    return finishArt(c,in,u);
}

float gildedHeight(float2 p,float t) {
    return .43*sin(p.x*2.65+sin(p.y*1.7+t*.12))+.31*sin(3.4*p.y-1.9*p.x+t*.24)
        +.11*sin(6.7*p.x+3.2*p.y+.58*cos(p.y*4.-t*.21));
}
fragment float4 art_golden(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.32); float t=u.canvas.z*.55;
    p.y+=u.gesture.w*.08*sin(t*.23+p.x);
    float h=gildedHeight(p,t), dx=gildedHeight(p+float2(.002,0),t)-h, dy=gildedHeight(p+float2(0,.002),t)-h;
    float3 n=normalize(float3(-dx*210.,-dy*(185.+42.*u.energy.x),1.));
    float3 r=reflect(float3(0,0,-1),n);
    float boundary=p.y-.24*sin(p.x*1.49+t*.12)-.14*h;
    float body=exp(-pow(abs(boundary)/(.28+.12*u.canvas.w),4.));
    float ribbon=exp(-pow((r.y+.32+.05*u.energy.y)*4.1,2.));
    float seam=lineLight(r.x-.29,.067+.035*u.energy.z);
    float3 c=float3(.025,.021,.023)+body*(float3(.38,.16,.042)*(.56+.6*r.z)
        +float3(1.55,.89,.34)*ribbon+float3(1.30,1.02,.64)*seam);
    c+=float3(.41,.26,.12)*lineLight(abs(boundary)-.29,.014)*(.6+.4*h);
    return finishArt(c,in,u);
}

fragment float4 art_ocean(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.47, m=u.gesture.w;
    float3 c=mix(float3(.012,.052,.10),float3(.025,.21,.24),saturate(.50+.43*p.y-.12*p.x));
    float shaft=sin(p.x*3.-p.y*2.+t*.18)+.42*cos(p.x*6.7-p.y*4.);
    c+=float3(.025,.07,.066)*smoothstep(.0,1.2,shaft)*saturate(p.y+.7);
    for(int i=0;i<4;i++) {
        float k=float(i),x=p.x+k*.30, angle=.40*k+.57*x+t*.11;
        float center=-.30+k*.13+.34*sin(x*1.42+angle)+m*.09*cos(2.8*x-t*.27+k);
        float width=.14+.13*(.5+.5*cos(x*2.1+k+t*.13))+.04*u.energy.x;
        float v=(p.y-center)/width;
        float mask=1.-smoothstep(.93,1.,abs(v));
        float crease=sin(v*(6.+u.canvas.w*3.)-x*2.3+k+u.energy.y*.34);
        float l=pow(.5+.5*crease,3.);
        float3 silk=mix(float3(.018,.17,.23),float3(.19,.68,.59),l*.78+.20);
        c=mix(c,silk,mask*(.36+.27*l));
        c+=float3(.28,.63,.58)*lineLight(abs(v)-1.,.035)*(.32+.20*u.energy.z);
    }
    return finishArt(c,in,u);
}

fragment float4 art_bloom(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u)-float2(.24,.02);
    p=rotate(p,-.22); p.y*=1.12;
    float t=u.canvas.z*.43, dist=length(p), a=atan2(p.y,p.x);
    float3 c=float3(.034,.026,.049)+float3(.12,.066,.12)*exp(-dist*2.);
    for(int i=0;i<4;i++){
        float k=float(i),count=9.-k;
        float twist=.30*k+.053*u.gesture.w*sin(t*.47+k)+.06*u.energy.y;
        float sector=2.*pi/count, ang=fract((a+twist)/sector+.5)*sector-sector*.5;
        float radius=(.87-.145*k)*(.93+.09*u.canvas.w+.055*u.energy.x+.025*cos(t*.37+k));
        float x=dist*cos(ang)/radius, y=dist*sin(ang)/radius;
        float shape=sqrt(pow((x-.48)/.51,2.)+pow(y/(.11+.11*(1.-saturate(x))),2.));
        float mask=1.-smoothstep(.983,1.005,shape);
        float rib=exp(-abs(y+.017*sin(x*4.+k))*24.);
        float curl=saturate(.53+2.1*y+.25*cos(x*4.+k)+.17*pow(saturate(shape),3.));
        float3 petal=mix(float3(.23,.13,.31),float3(.97,.70,.83),curl);
        petal+=float3(.50,.45,.58)*(rib*.32+lineLight(shape-.965,.035)*.63)*(1.+.23*u.energy.z);
        c=mix(c,petal*(.65+.30*x+.09*k),mask);
    }
    c+=float3(.34,.22,.25)*exp(-dist*38.);
    return finishArt(c,in,u);
}

fragment float4 art_harmonics(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u)-float2(.12,-.10),-.13); float t=u.canvas.z*.50;
    float3 c=float3(.024,.028,.035)+float3(.030,.030,.036)*exp(-dot(p,p));
    for(int i=0;i<23;i++){
        float k=float(i)/22., x=p.x+.50*(k-.5), span=.65+.60*k;
        float vx=clamp(x/span,-1.,1.), arch=sqrt(max(0.,1.-vx*vx));
        float y=-.40+.20*k+arch*(.50+.20*k+.11*u.canvas.w)
            +(.038*u.gesture.w*sin(t*.55+k*4.)+.075*u.energy.y)*arch*cos(x*3.+k*3.);
        float d=abs(p.y-y)*max(.14,arch);
        float ends=1.-smoothstep(span-.005,span+.005,abs(x));
        float3 alloy=mix(float3(.34,.48,.61),float3(.79,.68,.51),k);
        c+=ends*alloy*(.78*lineLight(d,max(.0012,fwidth(p.y)*.70))+.027*lineLight(d,.016))
            *(.65+.32*cos(k*4.-t*.14)+u.energy.z*.26);
    }
    return finishArt(c,in,u);
}

float glassFold(float2 p,float t,float detail){
    float x=p.x+.48*sin(p.y*2.3+t*.16)+.17*cos(2.8*p.x-p.y);
    return .64*cos(3.7*x+p.y*1.2)+.18*cos((7.+detail*2.)*x+p.y*2.45);
}
fragment float4 art_obsidian(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.59); float t=u.canvas.z*.23;
    p.x+=u.gesture.w*.12*sin(t*.35)+.065*u.gesture.z*exp(-dot(p-localPointer(u),p-localPointer(u))*2.);
    float h=glassFold(p,t,u.canvas.w);
    float2 grad=float2(glassFold(p+float2(.003,0),t,u.canvas.w)-h,glassFold(p+float2(0,.003),t,u.canvas.w)-h)/.003;
    float3 n=normalize(float3(-grad*.60,1)),r=reflect(float3(0,0,-1),n);
    float skylight=exp(-pow((r.y+.35)*5.,2.))*smoothstep(-.85,.27,r.x);
    float edge=lineLight(dot(r,normalize(float3(.58,.72,-.20)))-.36,.035);
    float3 col=float3(.027,.030,.040)+float3(.20,.22,.25)*(.5+.5*r.z)
       +float3(.75,.78,.79)*skylight+float3(.45,.42,.40)*edge;
    col*=.59+.32*smoothstep(-.85,.68,h);
    return finishArt(col,in,u);
}

fragment float4 art_sunset(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.49);float t=u.canvas.z*.15;
    float3 col=mix(float3(.46,.16,.14),float3(1.84,1.14,.83),saturate(.50+.27*p.y-.17*p.x));
    for(int i=0;i<4;i++){
        float k=float(i),x=p.x-.22*k;
        float fold=.31*sin(x*1.7+.75*k+t*.23)+.13*cos(x*3.6+k+.16*t);
        float s=p.y-(-.63+.36*k+fold+.10*u.gesture.w*sin(t*.37+k));
        float width=.21+.08*sin(1.6*x+k);
        float veil=smoothstep(-width,-width+.011,s)*(1.-smoothstep(width-.012,width,s));
        float pleat=.5+.5*cos(s*(19.+12.*u.canvas.w)+x*1.5+k);
        float3 dye=mix(float3(1.21,.38,.25),float3(2.2,1.57,1.06),pleat*.76+.09*k);
        col=mix(col,dye*(.8+.21*pleat),veil*.71);
        col+=float3(.58,.38,.27)*lineLight(abs(s)-width,.018);
        col*=1.-.17*exp(-abs(s+width+.029)*16.);
    }
    return finishArt(col,in,u);
}

float3 lightRoom(float2 p) {
    float3 room=mix(float3(.36,.56,.62),float3(1.82,1.39,1.13),smoothstep(-1.3,1.2,p.x+.40*p.y));
    float panel=.5+.5*tanh((p.x+.47*p.y+.35)*7.);
    room+=float3(.32,.38,.40)*lineLight(p.x+.31*p.y+.55,.057);
    room*=.80+.20*smoothstep(-.018,.018,p.y+.18*p.x+.20);
    return room*(.63+.34*panel)+float3(.41,.39,.36)*exp(-pow((p.y-.42+.18*p.x)*4.,2.));
}
fragment float4 art_glass(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);float t=u.canvas.z*.14;
    float3 col=lightRoom(p)*(.81+.10*fbm(p*2.));
    for(int i=0;i<3;i++){
        float k=float(i);
        float2 center=float2(-.58+.54*k,-.12+.20*sin(k*2.4+t*.31)*u.gesture.w)
            +u.gesture.xy*(.045+.022*k);
        float2 q=rotate(p-center,.38-.49*k+.12*sin(t*.27+k));
        float2 axes=float2(.30+.047*k,.67-.07*k);
        float2 v=q/axes;float r=dot(v,v);
        col*=1.-.16*exp(-dot((q-float2(.09,-.22))/axes,(q-float2(.09,-.22))/axes)*1.7);
        float z=sqrt(max(0.,1.-r)), inside=1.-smoothstep(.985,1.007,r);
        float3 n=normalize(float3(v.x*.63,v.y*.41,z+.03));
        float2 transmitted=p-.66*n.xy*(.49+.61*z);
        float3 lens=lightRoom(transmitted+float2(.14*k,.22));
        float frost=(i==1 ? .36+.27*u.canvas.w : .04);
        lens=mix(lens,float3(.98,1.08,1.11),frost);
        float fresnel=pow(1.-z,2.5);
        float3 trim=mix(float3(.27,.62,.65),float3(.89,.65,.55),k*.5);
        lens=mix(lens*(.88+.10*z),trim,fresnel*.81)+float3(.92,.91,.83)*lineLight(r-.977,.021)
            +.47*exp(-pow((n.x-.37)*8.,2.))*smoothstep(.17,.72,n.y);
        float bevel=lineLight(r-.86,.050)*smoothstep(-.6,.56,-n.x+n.y);
        lens+=float3(.52,.78,.88)*bevel+float3(.51,.40,.34)*lineLight(n.x+.52*n.y+.35,.11)*(.2+.32*z);
        col=mix(col,lens,inside);
    }
    return finishArt(col,in,u);
}

fragment float4 art_ember(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);float t=u.canvas.z*.14;
    float drift=fbm(float2(p.x*2.-t*.05,p.y*.95+t*.08));
    float shaft=p.x+.43*p.y-.46-.27*(drift-.5);
    float falloff=exp(-abs(shaft)*2.)*smoothstep(-1.5,.7,p.y+.55);
    float3 col=float3(.040,.023,.022)+float3(.44,.20,.073)*falloff*(.36+.63*drift);
    for(int i=0;i<4;i++){
        float k=float(i),scale=10.+5.*k;
        float2 pos=(p+float2(.042*u.gesture.w*sin(p.y*2.+t*.41+k),-t*(.014+.007*k)))*scale;
        float2 id=floor(pos),f=fract(pos)-.5;
        float seed=hash(id+17.*k);
        f-=(float2(hash(id+2.3),hash(id+8.1))-.5)*.67;
        float size=.034+.043*(1.-k/3.);
        float mote=exp(-dot(f,f)/(size*size));
        col+=float3(1.08,.58,.24)*mote*smoothstep(.79-.21*u.canvas.w,.96,seed)*(.08+.74*falloff);
    }
    return finishArt(col,in,u);
}

fragment float4 art_horizon(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);float t=u.canvas.z*.12;
    float phase=.5+.5*sin(t*.31), haze=exp(-pow((p.y-.05)*2.6,2.));
    float3 col=mix(float3(.47,.45,.95),float3(1.91,1.10,1.16),(1.-smoothstep(-.03,.98,p.y)));
    col+=float3(.81,.42,.18)*haze*exp(-abs(p.x+.65)*.82);
    // Broad curved strata are lit along their upper edge and absorb light below it.
    for(int i=0;i<5;i++){
        float k=float(i),x=p.x-.27*k;
        float y=.19-.19*k+.12*x+.15*sin(x*(.71+k*.12)+k*.91+t*.07)
            +u.gesture.w*.044*cos(x*1.6+t*.34+k);
        float below=y-p.y, edge=exp(-max(0.,below)*(8.+2.*k));
        float3 dusk=mix(float3(1.32,.52,.40),float3(.16,.12,.39),k*.23);
        float3 lilac=mix(float3(1.37,.91,1.18),float3(.60,.32,.66),k*.23);
        float3 layer=mix(dusk,lilac,smoothstep(-1.3,1.5,x+.36*phase));
        layer+=float3(.70,.41,.31)*edge*(.37+.54*u.canvas.w);
        col=mix(col,layer,smoothstep(-.004,.004,below));
    }
    return finishArt(col,in,u);
}
