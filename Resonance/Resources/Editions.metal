// Minimal editions. Distances are in half-screen heights; edge antialiasing
// follows the actual drawable resolution in both the library and desktop.
float inkMask(float dist) {
    float aa=max(.0004,fwidth(dist)*.65);
    return 1.-smoothstep(-aa,aa,dist);
}
float roundCut(float2 p,float2 halfSize,float radius) {
    float2 q=abs(p)-halfSize+radius;
    return length(max(q,0.))+min(max(q.x,q.y),0.)-radius;
}
float3 stock(float2 p,float3 pigment) {
    return pigment*(.82+.18*exp(-.65*dot(p-float2(-.46,.52),p-float2(-.46,.52))));
}

// A fold viewed nearly edge-on. The dark ground and the light on the underside
// stay attached to the hinge as it moves.
fragment float4 art_citron(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.46);
    float t=u.canvas.z*.43;
    float fold=p.y-.17-.31*sin(1.45*p.x+t*.52)-.085*p.x*p.x;
    float lift=.20+.10*sin(p.x*1.4-t*.35)+.10*u.canvas.w;
    float3 ground=stock(p,float3(.18,.20,.075))*(1.-.39*lobe(fold+.09,21.));
    float3 chartreuse=mix(float3(.61,.69,.11),float3(1.65,1.78,.49),smoothstep(-.9,.8,p.x-.29*tanh(fold)));
    float3 face=chartreuse*(.72+.24*lobe(fold-lift,8.))+.23*exp(-abs(fold)*10.);
    float seam=fold+lift*.46;
    float3 back=mix(float3(.30,.31,.065),float3(.85,.90,.24),saturate(-fold/lift));
    float3 col=mix(ground,back,inkMask(-seam));
    col=mix(col,face,inkMask(-fold));
    col+=float3(.67,.65,.24)*exp(-abs(fold)*125.);
    return finishArt(col,in,u);
}

fragment float4 art_alabaster(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.46;
    float3 c=stock(p,float3(.88,.80,.67));
    float2 sheet=rotate(p-float2(.24+.16*cos(t*.52),.06*sin(t*.47)),.26+.13*sin(t*.38));
    float spread=.06+.12*u.canvas.w;
    float back=roundCut(sheet+float2(spread,-spread*.7),float2(.68,.48),.13);
    float face=roundCut(sheet,float2(.68,.48),.13);
    c*=1.-.24*exp(-max(back,0.)*11.);
    c=mix(c,float3(1.22,1.09,.92),inkMask(back));
    c*=1.-.26*exp(-max(face+.016,0.)*30.);
    float3 china=mix(float3(1.24,1.19,1.08),float3(2.05,1.98,1.72),saturate(.56+.47*sheet.y+.27*sheet.x));
    c=mix(c,china,inkMask(face));
    c+=float3(.28,.27,.24)*exp(-abs(face)*125.)*smoothstep(-.32,.32,sheet.y+.4*sheet.x);
    return finishArt(c,in,u);
}

fragment float4 art_pistachio(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.42;
    float2 q=rotate(p-float2(.26+.13*sin(t*.42),.13*cos(t*.48)),.43+.16*cos(t*.36))/float2(.86,.53);
    float r=length(q), angle=.53*sin(t*.56)-.7;
    float bevel=exp(-pow((r-1.)/(.10+.12*u.canvas.w),2.));
    float diffuse=dot(q/max(.001,r),float2(cos(angle),sin(angle)));
    float3 base=stock(p,float3(.99,1.21,.63));
    base*=1.-.19*(1.-smoothstep(.57,1.,r));
    base+=bevel*(diffuse*.52-.07)*float3(.74,.91,.54);
    base+=float3(.34,.40,.22)*exp(-abs(r-1.065)*64.)*saturate(diffuse);
    return finishArt(base,in,u);
}

fragment float4 art_mulberry(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.37); float t=u.canvas.z*.40;
    float x=p.x+.2*sin(.43*t), path=.41*tanh(2.3*x+.49*sin(t*.38))-.18*x;
    float halfWidth=.23+.09*u.canvas.w+.11*sin(1.82*x-t*.33);
    float v=(p.y-path)/halfWidth, d=abs(v)-1.;
    float3 ground=stock(p,float3(.13,.052,.12));
    ground*=1.-.38*lobe((p.y-path+.12)/halfWidth,1.5);
    float turn=.5+.5*tanh(3.8*x+sin(.40*t));
    float3 front=mix(float3(.29,.067,.22),float3(.97,.28,.53),lobe(v-.22+.46*sin(x*2.1+t*.29),3.1));
    float3 reverse=mix(float3(.11,.044,.14),float3(.43,.19,.44),.5+.5*v);
    float3 face=mix(front,reverse,turn)+.22*exp(-abs(d)*18.);
    return finishArt(mix(ground,face,inkMask(d)),in,u);
}

fragment float4 art_cornflower(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.22); float t=u.canvas.z*.46;
    float a=p.y-.39*sin(1.65*p.x+.44*t);
    float b=p.y+.35*sin(1.52*p.x+.6-.34*t)-.04;
    float width=.085+.095*u.canvas.w;
    float3 c=stock(p,float3(.19,.25,.43));
    float3 under=mix(float3(.38,.52,1.04),float3(.78,.97,1.67),saturate(.50+.5*b/width));
    c=mix(c,under,inkMask(abs(b)-width));
    c*=1.-.31*lobe((a+.055)/(width*1.3),1.4);
    float3 over=mix(float3(.40,.41,.79),float3(.84,.85,1.57),.47+.43*cos(2.3*p.x-t*.42));
    over+=float3(.30,.33,.45)*exp(-abs(a-width)*60.);
    return finishArt(mix(c,over,inkMask(abs(a)-width)),in,u);
}

fragment float4 art_tea(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.86); float t=u.canvas.z*.35;
    float2 q=p*1.5+float2(.18*t,-.11*t);
    float wet=fbm(q+float2(noise(q*1.3),0));
    float edge=p.y+.13*p.x+.21*sin(p.x*2.3-t*.36)+.56*(wet-.48);
    float spread=.09+.15*u.canvas.w;
    float pigment=1.-smoothstep(-spread,.025,edge);
    float3 c=mix(stock(p,float3(1.50,1.37,1.06)),float3(.40,.235,.142)*(.64+.73*wet),pigment);
    c*=1.-.31*exp(-abs(edge+.045)*28.);
    c+=float3(.25,.21,.15)*exp(-abs(edge-.05)*21.);
    return finishArt(c,in,u);
}

fragment float4 art_poppy(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u)-float2(-.04,.02),.22); float t=u.canvas.z*.43;
    float gap=.014+.036*u.canvas.w;
    float offset=.13+.19*sin(t*.71+.8);
    float left=max(length(p-float2(0,offset))-.565,p.x+gap);
    float right=max(length(p+float2(0,offset))-.565,-p.x+gap);
    float3 c=stock(p,float3(1.56,1.39,1.20));
    c=mix(c,float3(1.29,.115,.075)*(.94+.16*p.y),inkMask(left));
    c=mix(c,float3(.85,.068,.064)*(.93+.23*p.x),inkMask(right));
    c+=float3(.25,.13,.09)*exp(-abs(right)*90.)*smoothstep(-.1,.48,p.y);
    return finishArt(c,in,u);
}

fragment float4 art_eucalyptus(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.42;
    float2 q=rotate(p-float2(.25+.10*cos(t*.59),.05),.22+.15*sin(t*.43));
    q=rotate(q,.28*sin(1.9*q.y+.42*t));
    float dist=roundCut(q,float2(.66,.52),.24+.08*u.canvas.w);
    float rim=.048+.070*u.canvas.w;
    float3 deep=stock(p,float3(.11,.24,.20));
    float3 slab=stock(p,float3(.74,.98,.79));
    float bevel=smoothstep(-rim,rim,dist);
    float light=.48+.46*tanh(4.*(q.y-.55*q.x+.16*sin(t*.46)));
    float3 c=mix(deep,slab,bevel);
    c+=float3(.64,.73,.58)*light*lobe(dist/rim,1.8);
    c*=1.-.26*(1.-light)*exp(-abs(dist+rim)*15.);
    c+=float3(.35,.42,.35)*exp(-abs(dist-rim*.87)*92.)*light;
    return finishArt(c,in,u);
}

fragment float4 art_flax(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.44;
    float2 q=rotate(p-float2(-.23+.17*sin(.54*t),-.31),.24+.14*sin(.36*t));
    float wedge=abs(q.x+.08*q.y)-q.y*(.66+.14*u.canvas.w);
    float fiber=.5+.5*sin(p.y*120.+p.x*8.);
    float3 c=stock(p,float3(1.11,.97,.69))*(.98+.022*fiber);
    c*=1.-.28*lobe(wedge-.054,99.);
    float3 front=mix(float3(.68,.53,.34),float3(1.57,1.37,.98),smoothstep(-.08,.11,q.x+.09*q.y));
    front*=.94+.036*cos(119.*q.x+13.*q.y);
    c=mix(c,front,inkMask(wedge));
    return finishArt(c,in,u);
}

fragment float4 art_sorbet(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.39;
    float d=p.x-.21+.27*p.y+.14*cos(2.5*p.y+t*.6)+.08*sin(t*.47);
    float soft=.18+.16*u.canvas.w;
    float3 left=stock(p,float3(1.45,.66,.43))*(1.-.38*lobe(d+.08,14.));
    float3 right=mix(float3(.85,.41,.32),float3(1.87,1.06,.68),smoothstep(.0,.89,d));
    float3 col=mix(left,right,smoothstep(-.005,.005,d));
    float focus=.58+.36*sin(1.6*p.y-t*.55);
    col+=float3(1.30,.99,.57)*exp(-abs(d)/soft*3.4)*focus;
    return finishArt(col,in,u);
}

// Music editions receive bounded, attack/release-filtered bands from Motion.
// Energy changes distance fields, membrane modes or orientation before lighting.
fragment float4 art_yuzu(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.27+.07*u.gesture.w*sin(u.canvas.z*.50)); float t=u.canvas.z;
    float x=p.x+.55, notch=.18+.12*u.canvas.w+.40*u.energy.x+.11*u.look.y;
    float upper=p.y-.18*u.gesture.w*sin(t*.47)-notch*x, lower=-p.y+.18*u.gesture.w*sin(t*.47)-.14*x;
    float d=max(upper,lower);
    float3 c=stock(p,float3(.072,.081,.053));
    float3 pulp=mix(float3(1.13,1.06,.10),float3(1.80,1.54,.43),smoothstep(.0,1.9,x));
    pulp*=.74+.28*smoothstep(-.17,.18,p.y+.17*u.energy.y);
    float crease=upper+.33*notch*x;
    pulp*=.73+.27*smoothstep(-.055,.11,crease);
    pulp+=float3(.34,.31,.11)*exp(-abs(crease)*13.)*smoothstep(.0,.75,x);
    c=mix(c,pulp,inkMask(d));
    c+=float3(.91,.90,.52)*exp(-abs(upper)*91.)*smoothstep(.0,.45,x)*(.32+.85*u.energy.z);
    return finishArt(c,in,u);
}

fragment float4 art_porcelain(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u)-float2(.19,-.08); float t=u.canvas.z*.82;
    float2 q=rotate(p,-.39);
    float span=.40+.15*u.canvas.w+.41*u.energy.x;
    float2 high=q-float2(-span,.14*u.gesture.w*sin(t*.52));
    float2 low=q-float2(span,-.09+.18*u.energy.y);
    high.y+=.17*sin(high.x*2.4+t*.42);
    low.y-=.14*cos(low.x*2.1-t*.43);
    float bump=exp(-dot(high*float2(1.58,2.74),high*float2(1.58,2.74)));
    float dip=exp(-dot(low*float2(1.72,2.9),low*float2(1.72,2.9)));
    float2 front=high*float2(2.496,7.508);
    front.x+=front.y*.408*cos(high.x*2.4+t*.42);
    float2 rear=low*float2(2.958,8.41);
    rear.x+=rear.y*.294*sin(low.x*2.1-t*.43);
    float2 slope=2.*(rear*dip-front*bump)*(.54+.68*u.energy.x);
    float3 n=normalize(float3(-slope,1.));
    float3 light=normalize(float3(-.76+.4*u.energy.z,.63+.33*sin(t*.61),.65));
    float3 c=stock(p,float3(1.94,1.86,1.66))*(.42+.77*saturate(dot(n,light)));
    c+=float3(.62,.59,.48)*pow(saturate(dot(n,normalize(light+float3(0,0,1)))),18.)*(dip+bump);
    float glancing=n.x+.32*n.y-.22-.52*u.energy.x;
    c+=float3(.91,.83,.66)*lobe(glancing/.052,1.)*smoothstep(.09,.53,bump+dip);
    return finishArt(c,in,u);
}

fragment float4 art_morello(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u)-float2(-.08,0),.23); float t=u.canvas.z*.76;
    float interval=.36+.15*u.gesture.w*sin(t*.60)-.43*u.energy.x;
    float a=length(p+float2(interval,-.05))-(.55+.04*u.canvas.w);
    float b=length(p-float2(interval,.06+.20*u.energy.y))-.55;
    float ma=inkMask(a), mb=inkMask(b);
    float3 c=stock(p,float3(.35,.095,.151));
    c=mix(c,float3(1.16,.16,.25)*(.79+.23*p.y),ma);
    c=mix(c,float3(.78,.235,.37)*(.82+.17*p.x),mb);
    c=mix(c,float3(.26,.045,.098),ma*mb);
    c+=float3(.78,.34,.35)*exp(-abs(b)*98.)*(.29+.74*u.energy.z)*smoothstep(-.75,.46,p.y);
    return finishArt(c,in,u);
}

fragment float4 art_lichen(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.69;
    float2 q=rotate(p-float2(.16,.07),.34+.13*u.gesture.w*sin(t*.53))/.81;
    float k=3.55+.72*u.canvas.w+.59*u.energy.x;
    float mode=cos(k*q.x)*cos(1.68*q.y)-cos(k*q.y)*cos(1.68*q.x);
    mode+=.40*sin(2.22*q.x+1.24*q.y+.54*t)+.89*(u.energy.y-u.energy.x);
    float envelope=exp(-pow(length(q)/1.09,4.));
    float luminous=exp(-abs(mode)*(17.-7.*u.energy.z));
    float3 c=stock(p,float3(.10,.13,.065))+envelope*float3(.11,.13,.045);
    c+=float3(.71,.84,.22)*envelope*(luminous+.16*lobe(mode,9.))*(.81+.32*u.energy.w);
    return finishArt(c,in,u);
}

fragment float4 art_mica(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float t=u.canvas.z*.74;
    float2 q=rotate(galleryUV(in,u)-float2(.16,.015),-.22+.16*u.gesture.w*sin(t*.56)+.27*u.energy.x);
    float2 size=float2(.93,.55+.09*u.canvas.w);
    float outer=abs(q.x)/size.x+abs(q.y)/size.y-1.;
    float hinge=.10+.27*sin(.51*t)+.67*u.energy.x+.28*u.look.y;
    float slope=q.x+hinge*q.y;
    float3 c=stock(q,float3(.21,.19,.22))*(1.-.24*lobe(outer-.11,36.));
    float3 facet=mix(float3(.66,.57,.52),float3(1.05,.94,.98),smoothstep(-.003,.003,slope));
    float crease=q.y-.11*q.x+.13+.16*u.energy.y;
    facet=mix(facet,facet*float3(.48,.50,.60),smoothstep(-.003,.003,-crease));
    float transmitted=q.y+.38*q.x-.12+.29*slope*sign(crease)+.09*sin(t*.52);
    facet*=.74+.23*cos(q.y*2.2+hinge);
    facet+=float3(.39,.39,.45)*lobe(transmitted,21.)+float3(.23,.18,.16)*lobe(transmitted+.38,420.);
    facet+=float3(.40,.41,.44)*exp(-abs(crease)*60.)*(.45+.71*u.energy.z);
    return finishArt(mix(c,facet,inkMask(outer)),in,u);
}

fragment float4 art_pollen(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u)-float2(.19,-.01); float t=u.canvas.z*.78;
    float2 q=rotate(p,.37+.55*u.gesture.w*sin(.61*t+.58)); q.y*=1.47;
    float r=length(q), radius=.55+.17*u.energy.x;
    float2 dir=q/max(.001,r);
    float span=1.83+.37*cos(t*.62)+.83*u.energy.y+.49*u.energy.x;
    float2 tip=radius*float2(cos(span),sin(span));
    float gap=dir.x-cos(span);
    float dist=gap>0. ? abs(r-radius) : length(float2(q.x,abs(q.y))-tip);
    float width=(.018+.033*u.canvas.w)*(.50+.63*(.5+.5*dir.y));
    float3 c=stock(p,float3(.145,.112,.060));
    c+=float3(.29,.23,.10)*exp(-abs(r-radius)*51.);
    float3 pollen=mix(float3(.97,.82,.13),float3(1.73,1.62,.46),.45+.44*dir.y);
    c=mix(c,pollen,inkMask(dist-width));
    c+=float3(.65,.56,.21)*lobe(length(q-tip),174.)*(.42+.89*u.energy.z+.39*u.look.y);
    return finishArt(c,in,u);
}

fragment float4 art_counterpoint(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.27); float t=u.canvas.z*.82;
    float3 c=stock(p,float3(.062,.108,.22));
    for(int i=0;i<2;i++) {
        float k=float(i), x=p.x*(i==0 ? 1. : -1.);
        float voice=i==0 ? u.energy.x : u.energy.y;
        float curve=.33*tanh(2.4*x+.61*u.gesture.w*sin(.64*t+k))+.13*x+.18*k+.47*(voice-.12)*cos(2.1*x+k);
        float pressure=.025+(.115+.059*u.canvas.w+.19*voice)*lobe(x+.36,1.65);
        float ends=saturate(1.-pow(abs((x+.10)/1.24),2.));
        float d=max(abs(p.y-curve)-pressure*ends,abs(x+.10)-1.24);
        float3 ink=mix(float3(.40,.65,.99),float3(.78,.73,1.36),k);
        c*=1.-.19*lobe(d-.029,300.);
        c=mix(c,ink*(.73+.23*cos(x*2.4-t*.44)),inkMask(d));
        c+=float3(.36,.45,.53)*exp(-abs(d)*90.)*(.27+.60*u.energy.z);
    }
    return finishArt(c,in,u);
}

fragment float4 art_guava(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.81;
    float2 q=rotate(p-float2(.12,.01),-.34+.07*sin(t*.55));
    q.y+=.14*u.gesture.w*sin(q.x*2.9+t*.50)+.19*u.energy.y*cos(3.1*q.x);
    float width=.30+.11*u.canvas.w+.34*u.energy.x+.14*u.look.y;
    float d=roundCut(q,float2(.86,width),width*.95);
    float3 field=stock(p,float3(1.61,.49,.59));
    float3 depth=mix(float3(.51,.086,.22),float3(1.22,.27,.38),saturate(.48+.6*q.x+.3*q.y));
    depth+=float3(.43,.24,.14)*exp(-abs(d+.065)*14.);
    float3 col=mix(field,depth,inkMask(d));
    col+=float3(.66,.37,.26)*exp(-abs(d)*46.)*(.49+.78*u.energy.z)*smoothstep(-.63,.38,q.x-q.y);
    return finishArt(col,in,u);
}

fragment float4 art_bistre(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.16); float t=u.canvas.z*.92;
    float x=p.x, envelope=exp(-x*x*.96);
    float fundamental=(.05+.10*u.gesture.w+.52*u.energy.x)*sin(2.9*x+t*.57);
    float harmonic=(.032+.29*u.energy.y)*sin(5.7*x-.67*t)+(.013+.12*spectral(.77,u))*sin(10.1*x+.38*t);
    float path=envelope*(fundamental+harmonic);
    float d=p.y-path, width=.009+(.014+.016*u.canvas.w)*envelope;
    float3 c=stock(p,float3(1.46,1.27,.96));
    c*=1.-.36*lobe((d+.06+.04*envelope)/.042,1.3)*(.33+.65*envelope);
    float3 ink=mix(float3(.115,.073,.063),float3(.52,.33,.20),smoothstep(-width,width,d));
    c=mix(c,ink,inkMask(abs(d)-width));
    return finishArt(c,in,u);
}

fragment float4 art_spearmint(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.83;
    float2 q=rotate(p,.28+.07*sin(.44*t));
    float arch=(.13+.16*u.gesture.w)*cos(q.x*1.9+.52*t)+.13*q.x;
    float y=q.y-arch;
    float gap=(.095+.24*u.energy.x+.12*u.look.y)*exp(-q.x*q.x*.88);
    float offset=.08+.26*u.energy.y;
    float upper=y-gap, lower=-y-gap;
    float3 mint=stock(p,float3(.71,1.43,1.12));
    float3 c=float3(.11,.38,.31)+float3(.09,.32,.21)*lobe(y+offset,24.);
    float roll=.040+.14*u.canvas.w;
    float3 upperFace=mint*(.79+.26*smoothstep(.0,.56,upper));
    upperFace+=float3(.52,.76,.53)*lobe(upper-roll,80.)*(.63+.28*sin(q.x*1.8+t*.36));
    float3 lowerFace=mint*(.44+.44*smoothstep(.0,.37,lower));
    lowerFace+=float3(.29,.53,.46)*lobe(lower-.17-offset,55.);
    c=mix(c,upperFace,inkMask(-upper));
    c=mix(c,lowerFace,inkMask(-lower));
    c+=float3(.49,.79,.62)*exp(-abs(upper)*106.)*(.44+.88*u.energy.z);
    return finishArt(c,in,u);
}

 // Grazing light reveals each relief. Derivatives convert the height field to
 // a surface normal, with the same scale on Retina and low-resolution displays.
 float4 atelierFinish(Surface in, constant Uniforms &u, float height, float3 dark, float3 pigment) {
     float2 slope=float2(dfdx(height),-dfdy(height))*u.canvas.y*(.14+.25*u.canvas.w);
     float3 normal=normalize(float3(-slope,1.));
     float3 reflection=reflect(float3(0,0,-1),normal);
     float diffuse=saturate(dot(normal,normalize(float3(-.48,.68,.68))));
     float3 color=mix(dark*.34,pigment,(.16+.54*diffuse)*saturate(.64+.33*height));
     color+=pigment*.55*lobe(reflection.y+.33*reflection.x-.47,16.);
     color+=mix(pigment,float3(1),.55)*.65*lobe(reflection.x-.21*reflection.y+.5,105.);
     return finishArt(color,in,u);
 }

// Auric Register — Gold leaf
fragment float4 art_auric(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float edge=p.y+.36*p.x+.13*cos(2.1*p.x);
    float height=tanh(edge*5.)+.08*sin(42.*edge)*exp(-abs(edge)*3.);
    return atelierFinish(in,u,height,float3(0.086,0.086,0.106),float3(0.788,0.608,0.322));
}

// Vellum Arch — Limestone
fragment float4 art_vellum(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float arc=length((p-float2(.31,-.64))*float2(.84,1.))-.88;
    float height=.62*tanh(12.*arc)+.12*cos(25.*arc)*exp(-3.*abs(arc));
    return atelierFinish(in,u,height,float3(0.412,0.345,0.290),float3(0.937,0.855,0.745));
}

// Claret Press — Burgundy lacquer
fragment float4 art_claret(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float a=length(p-float2(-.47,.18))-.72,b=length(p-float2(.5,-.22))-.66;
    float height=.42*tanh(10.*a)+.58*tanh(14.*b);
    return atelierFinish(in,u,height,float3(0.196,0.082,0.145),float3(0.710,0.420,0.455));
}

// Celadon Flute — Celadon ceramic
fragment float4 art_celadon(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float2 q=p-float2(-1.75,-1.3);
    float height=sin(23.*atan2(q.y,q.x))*.26+.16*length(q);
    return atelierFinish(in,u,height,float3(0.145,0.294,0.282),float3(0.773,0.851,0.722));
}

// Basalt Index — Basalt and brass
fragment float4 art_basalt(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float k=p.x+.45*p.y-.28;
    float height=.47*abs(k)+.19*exp(-19.*abs(k))+.24*tanh(8.*(p.y-.4));
    return atelierFinish(in,u,height,float3(0.141,0.145,0.169),float3(0.647,0.545,0.376));
}

// Shell Cameo — Mother of pearl
fragment float4 art_shell(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float r=length((p-float2(.35,0))*float2(.72,1.));
    float height=sqrt(max(.001,1.-min(1.,r*r)))+.036*cos(30.*r);
    return atelierFinish(in,u,height,float3(0.439,0.329,0.396),float3(0.918,0.792,0.765));
}

// Ochre Folio — Saffron paper
fragment float4 art_folio(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float z=p.y-.34*p.x;
    float height=.34*tanh(15.*(z+.3))+.32*tanh(18.*(z-.18))-.22*tanh(11.*(p.x+.36));
    return atelierFinish(in,u,height,float3(0.471,0.333,0.188),float3(0.898,0.722,0.424));
}

// Lapis Intaglio — Lapis lazuli
fragment float4 art_lapis(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float2 q=p-float2(.4,-.14);
    float r=length(q);
    float height=.28*cos(12.*r-2.*atan2(q.y,q.x))*smoothstep(.04,.38,r);
    return atelierFinish(in,u,height,float3(0.063,0.165,0.325),float3(0.447,0.624,0.769));
}

// Sable Suede — Brushed suede
fragment float4 art_suede(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float d=p.y+.42*sin(1.4*p.x-.2);
    float height=.58*exp(-5.*d*d)-.22*exp(-22.*(d+.39)*(d+.39));
    return atelierFinish(in,u,height,float3(0.227,0.149,0.137),float3(0.776,0.584,0.514));
}

// Opal Inset — Opaline enamel
fragment float4 art_opal(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float d=roundCut(rotate(p-float2(.28,.04),.32),float2(.68,.44),.25);
    float height=.6*tanh(10.*d)+.08*exp(-90.*abs(d));
    return atelierFinish(in,u,height,float3(0.392,0.369,0.498),float3(0.827,0.839,0.918));
}

// Quicksilver Silk — Platinum satin
fragment float4 art_quicksilk(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float d=p.y+.46*sin(p.x*2.+t)+.13*cos(3.*p.x-t*.6);
    float height=.7*tanh(d*4.)+.12*cos(d*16.+t);
    return atelierFinish(in,u,height,float3(0.145,0.161,0.212),float3(0.714,0.753,0.824));
}

// Honey Veil — Amber resin
fragment float4 art_honey(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float a=p.y-.27*cos(2.*p.x+t),b=p.y+.34*sin(p.x*2.5-t*.7);
    float height=.46*tanh(a*7.)+.48*tanh((b+.19)*6.);
    return atelierFinish(in,u,height,float3(0.314,0.153,0.067),float3(0.902,0.643,0.294));
}

// Malachite Current — Green lacquer
fragment float4 art_malachite(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float z=length((p-float2(.55*sin(t),-.44))*float2(.68,1.))+.1*sin(3.*p.y+t);
    float height=.28*cos(z*15.-t);
    return atelierFinish(in,u,height,float3(0.063,0.208,0.180),float3(0.498,0.765,0.616));
}

// Blush Membrane — Blush porcelain
fragment float4 art_blush(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float a=length(p-float2(.7*cos(t),.28*sin(t))),b=length(p-float2(-.7*cos(t+.7),-.32));
    float height=exp(-2.*a*a)-.78*exp(-3.*b*b);
    return atelierFinish(in,u,height,float3(0.388,0.239,0.290),float3(0.941,0.733,0.702));
}

// Indigo Nocturne — Indigo foil
fragment float4 art_nocturne(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float2 q=p-float2(-1.3,.85);
    float a=atan2(q.y,q.x);
    float height=.24*cos(10.*a+2.*sin(t+length(q)))*smoothstep(0.,.6,length(q));
    return atelierFinish(in,u,height,float3(0.141,0.118,0.267),float3(0.620,0.604,0.796));
}

// Bronze Torsion — Brushed bronze
fragment float4 art_bronze(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float z=p.y*cos(t*.52+p.x)+.35*sin(p.x*1.7-t);
    float height=.8*exp(-5.*z*z)+.16*z;
    return atelierFinish(in,u,height,float3(0.263,0.169,0.145),float3(0.808,0.592,0.392));
}

// Pearl Halation — Pearlescent glass
fragment float4 art_halation(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float r=length((p-float2(.42,.18*sin(t)))*float2(.76+.10*cos(t),1.));
    float height=.5*tanh((r-.55-.10*sin(t))*8.)+.16*cos(19.*r-t);
    return atelierFinish(in,u,height,float3(0.400,0.388,0.451),float3(0.898,0.843,0.808));
}

// Oxide Passage — Copper oxide
fragment float4 art_oxide(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float2 q=rotate(p,.39+.09*sin(t));
    float height=.5*tanh((q.x-.23*cos(t))*7.)+.32*tanh((q.y+.32*sin(t*.81))*11.);
    return atelierFinish(in,u,height,float3(0.180,0.259,0.251),float3(0.769,0.565,0.412));
}

// Iris Suture — Violet enamel
fragment float4 art_iris(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float a=p.y-.42*sin(1.9*p.x+t),b=p.y+.44*sin(1.7*p.x-t);
    float height=.49*exp(-13.*a*a)-.45*exp(-12.*b*b);
    return atelierFinish(in,u,height,float3(0.196,0.125,0.243),float3(0.698,0.529,0.776));
}

// Lagoon Lens — Aquamarine glass
fragment float4 art_lagoon(Surface in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u);
    float t=u.canvas.z*.32;
    float a=length(p-float2(.49*cos(t),.26*sin(t))),b=length(p-float2(-.62,.25*cos(t)));
    float height=.33*cos(5.*a+t*.6)+.26*cos(6.*b-t*.72);
    return atelierFinish(in,u,height,float3(0.063,0.200,0.239),float3(0.420,0.780,0.773));
}
