// Shared screen-space coordinates and final color transform for the gallery.
float2 galleryUV(Surface in, constant Uniforms &u) {
    return (in.uv*2.-1.)*float2(u.canvas.x/u.canvas.y,1.);
}
float4 finishArt(float3 col, Surface in, constant Uniforms &u) {
    float vignette=1.-.15*dot(in.uv-.5,in.uv-.5);
    return float4(grade(col*vignette,u)+(hash(in.position.xy)-.5)*.0036,1);
}

// Broad and narrow reflected studio lights give each surface a readable outline.
float lobe(float x,float sharpness) { return exp(-x*x*sharpness); }
float3 alloyLight(float3 n,float3 shadow,float3 body,float3 light,float t) {
    float3 r=reflect(float3(0,0,-1),n);
    float broad=lobe(r.y+.26*r.x-.22*sin(.19*t),7.)*(.45+.55*smoothstep(-1.,.45,r.x));
    float rim=lobe(r.x-.32*r.y+.48,170.)*(.42+.58*saturate(r.z+.6));
    return shadow+body*(.12+.74*broad)+light*(.58*rim+.28*pow(1.-saturate(n.z),3.));
}

fragment float4 art_nacre(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u)-.08*u.gesture.xy,.37); float t=u.canvas.z*.47;
    float warp=p.y+.31*sin(2.1*p.x+t*.48)+.22*cos(1.4*p.x-1.6*p.y-t*.34);
    float phase=warp*(8.+2.*u.canvas.w)+.81*sin(2.1*p.x+.56*t);
    float2 dw=float2(.651*cos(2.1*p.x+t*.48)-.308*sin(1.4*p.x-1.6*p.y-t*.34),
                     1.+.352*sin(1.4*p.x-1.6*p.y-t*.34));
    float2 dPhase=dw*(8.+2.*u.canvas.w)+float2(1.701*cos(2.1*p.x+.56*t),0.);
    float2 slope=(.5*cos(phase)+.24*cos(2.*phase+.43))*dPhase+.22*dw;
    float3 n=normalize(float3(-slope*.38,1.)), r=reflect(float3(0,0,-1),n);
    float shift=.5+.5*sin(2.1*r.x+2.7*r.y+.73*p.x+.32*t);
    float3 pigment=mix(float3(.31,.56,.56),float3(.79,.47,.77),shift);
    float3 c=alloyLight(n,float3(.115,.127,.17),pigment,float3(1.45,1.31,1.12),t);
    c+=pigment*.24+float3(.71,.77,.73)*lobe(r.y-.40,27.);
    return finishArt(c,in,u);
}

fragment float4 art_saffron(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),-.30); float t=u.canvas.z*.43;
    float3 c=float3(.075,.031,.042)+float3(.22,.062,.033)*lobe(p.y+.14,2.);
    for(int i=0;i<3;i++){
        float k=float(i), x=p.x+.17*k, turn=1.64*x-.42*t+.92*k;
        float center=.27*sin(1.47*x+.34*t+.43*k)+.18*k-.23;
        float halfWidth=(.19+.23*u.canvas.w)*(.16+.84*abs(cos(turn)));
        float v=(p.y-center)/halfWidth, d=abs(p.y-center)-halfWidth;
        float aa=max(fwidth(d),.001), mask=1.-smoothstep(-aa,aa,d);
        float3 back=float3(.32,.046,.055), front=float3(1.72,.57,.14);
        float3 silk=mix(back,front,smoothstep(-.75,.87,cos(turn)));
        float fold=v*.78+sin(turn)*.51;
        silk*=.44+.61*lobe(fold,3.)+.29*smoothstep(-.7,.8,v);
        silk+=float3(1.23,.82,.43)*lobe(fold-.43,30.);
        c*=1.-.25*lobe(d-.037,220.);
        c=mix(c,silk+float3(.65,.32,.12)*lobe(d,5800.),mask);
    }
    return finishArt(c,in,u);
}

fragment float4 art_petrol(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.36;
    float2 q=p;
    for(int i=0;i<3;i++){
        float k=float(i); q+=float2(sin(q.y*(1.66+.21*k)+.29*t+k),cos(q.x*1.83+t*.22-k))*(.42-.063*k);
        q=rotate(q,.32);
    }
    float film=.55*q.y+.22*cos(1.6*q.x-.22*t)+.16*sin(2.4*q.y+t*.28);
    float phase=film*(9.+9.*u.canvas.w);
    float3 spectrum=mix(float3(.075,.12,.30),float3(.10,.52,.52),.5+.5*cos(phase));
    spectrum=mix(spectrum,float3(.53,.29,.44),lobe(cos(.5*phase+.87),5.));
    spectrum+=float3(.42,.26,.10)*lobe(cos(.5*phase-.92),13.);
    float body=smoothstep(-.53,.31,film)*(1.-smoothstep(.56,1.18,film));
    float3 c=float3(.026,.045,.061)+body*(float3(.072,.083,.110)+spectrum*.90);
    c+=float3(.62,.71,.66)*lobe(film-.21,1250.)+.075*body*lobe(cos(phase*1.8),12.);
    return finishArt(c,in,u);
}

fragment float4 art_caustics(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u)-u.gesture.xy*.09,-.32); float t=u.canvas.z*.41;
    float3 c=mix(float3(.016,.036,.14),float3(.058,.15,.36),saturate(.55+.24*p.x-.22*p.y));
    // Superpose three refracted line families. Their crossings concentrate light.
    for(int i=0;i<3;i++){
        float k=float(i), x=p.x+(.09+.18*k)*sin(p.y*2.-t*.33+k);
        float wave=p.y+.37*sin(x*(2.2+.14*k)+.48*t+.31*k)
                 +.23*cos(2.3*x-1.44*p.y-.36*t+.78*k)+.10*k-.12;
        float d=abs(wave), width=.013+.016*u.canvas.w+.009*k;
        float focus=1./(1.+pow(d/width,2.));
        c+=mix(float3(.025,.37,1.02),float3(.52,.97,1.22),k*.4)*(focus*.67+.20*lobe(d,14.));
        c+=float3(.061,.10,.27)*lobe(d-.22,90.);
    }
    return finishArt(c,in,u);
}

fragment float4 art_lamina(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.43); float t=u.canvas.z*.33;
    float3 c=float3(.14,.050,.09)+float3(.17,.08,.12)*lobe(p.y-.7,2.);
    for(int i=0;i<11;i++){
        float k=1.-float(i)/10., edge=-.91+k*(1.+.58*u.canvas.w)+.43*sin(1.15*p.x+2.5*k+t*.43)
            +.17*cos(2.23*p.x-2.4*k-t*.28);
        float d=edge-p.y, inside=smoothstep(-.003,.003,d);
        float3 skin=mix(float3(.36,.10,.20),float3(1.20,.52,.52),k);
        float shade=exp(-max(d,0.)*7.);
        c=mix(c,skin*(.58+.42*shade),inside*(.51+.22*shade));
        c+=float3(.74,.44,.35)*exp(-abs(d)*105.)*(.53+.31*cos(k*4.+p.x+t*.21));
    }
    return finishArt(c,in,u);
}

fragment float4 art_loom(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u); float t=u.canvas.z*.39;
    float2 q=rotate(p,-.40); float pitch=49.+34.*u.canvas.w;
    float3 c=float3(.022,.040,.044);
    for(int i=0;i<2;i++){
        float k=float(i);
        float path=q.y+.25*sin(q.x*1.85+t*.44+k*.58)+.16*cos(2.2*q.x-.27*t+k*1.1);
        path+=k*(.13*q.x+.09*sin(q.y*2.1+t*.25));
        float phase=path*pitch+k*.77, aa=clamp(fwidth(phase),.02,2.);
        float filament=1.-smoothstep(.13,.13+aa,abs(sin(phase)));
        float width=exp(-pow(abs(path+.12-.22*k)/.59,4.));
        float3 dye=mix(float3(.27,.80,.66),float3(1.12,.75,.40),k);
        c+=width*dye*(filament*(.36+.39*lobe(q.x-.34*sin(t*.24+k),1.7))+.034);
    }
    return finishArt(c,in,u);
}

fragment float4 art_mercury(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=rotate(galleryUV(in,u),.28)-u.gesture.xy*.09; float t=u.canvas.z*.43;
    float field=0.; float2 gradient=0.;
    for(int i=0;i<4;i++){
        float k=float(i);
        float2 center=float2((k-1.5)*.63+.21*sin(t*.53+1.63*k),.43*sin(t*.63+k*2.02));
        float2 q=(p-center)*float2(1.03,1.24+.18*k);
        float tension=4.8+1.9*u.canvas.w, density=exp(-dot(q,q)*tension);
        field+=density;
        gradient-=2.*tension*density*q*float2(1.03,1.24+.18*k);
    }
    float d=field-.47, edge=smoothstep(-.006,.006,d);
    float height=sqrt(max(0.,d)+.001);
    float3 n=normalize(float3(-.41*gradient,height));
    float3 alloy=alloyLight(n,float3(.060,.072,.078),float3(.70,.75,.81),float3(1.18,1.13,.99),t);
    float3 r=reflect(float3(0,0,-1),n);
    alloy+=float3(.54,.49,.43)*lobe(r.y+.52,36.)+.21*lobe(d,8000.);
    float3 c=float3(.045,.055,.061)*(.79+.44*lobe(field-.30,7.));
    return finishArt(mix(c,alloy,edge),in,u);
}

fragment float4 art_prism(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u)-.08*u.gesture.xy; float t=u.canvas.z*.32;
    float3 c=mix(float3(.079,.12,.20),float3(.59,.39,.39),smoothstep(-1.7,1.8,p.x+.42*p.y));
    for(int i=0;i<5;i++){
        float k=float(i), a=-.59+.24*k+.10*sin(t*.39+k);
        float2 q=rotate(p,a); float x=q.x+.29*sin(t*.44+k*1.63)-.40*(k-2.);
        float d=abs(x)-(.29+.07*sin(k)), mask=1.-smoothstep(-.004,.004,d);
        float3 dye=mix(float3(.26,.66,.82),float3(.91,.49,.46),k*.25);
        c=mix(c,c*(.67+.37*dye)+.17*dye+.14*lobe(q.y+.8*x-.27*k,8.),mask);
        float spread=.009+.025*u.canvas.w;
        c+=float3(.77,.78,.86)*exp(-abs(d)*59.)
          +float3(.69,.19,.10)*lobe((d+spread)/spread,5.)
          +float3(.11,.43,.68)*lobe((d-spread)/spread,5.);
    }
    return finishArt(c,in,u);
}

fragment float4 art_carbon(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 q=galleryUV(in,u)-float2(-1.13,-.73); float t=u.canvas.z*.39;
    float r=length(q), angle=atan2(q.y,q.x);
    float phase=angle+.17*sin(1.78*r-t*.41)+.09*cos(3.8*r+t*.23);
    // Integer angular frequencies keep the polar seam continuous at ±pi.
    float flutes=mix(cos(phase*18.),cos(phase*24.),u.canvas.w);
    float2 radial=q/max(.001,r), tangent=float2(-radial.y,radial.x);
    float dFlutes=mix(-18.*sin(phase*18.),-24.*sin(phase*24.),u.canvas.w);
    float slope=.41*dFlutes+1.20*cos(phase*8.-t*.36);
    float bend=.3026*cos(1.78*r-t*.41)-.342*sin(3.8*r+t*.23);
    float2 grad=radial*(.41*flutes+.15*sin(8.*phase-t*.36)+r*bend*slope)+slope*tangent;
    float3 n=normalize(float3(-grad*.29,1.));
    float3 c=alloyLight(n,float3(.033,.038,.045),float3(.26,.29,.33),float3(.84,.77,.65),t);
    c+=float3(.37,.34,.31)*pow(saturate(flutes),13.)*smoothstep(.04,.85,r);
    return finishArt(c,in,u);
}

fragment float4 art_echo(Surface in [[stage_in]],constant Uniforms &u [[buffer(0)]]) {
    float2 p=galleryUV(in,u)-float2(.19,.02)-.11*u.gesture.xy; float t=u.canvas.z*.4;
    float3 c=float3(.037,.031,.091);
    for(int i=0;i<9;i++){
        float k=float(i)/8.;
        float2 q=rotate(p-float2(.34*k*sin(.51*t+k*2.2),.19*k*cos(.36*t+k*2.4)),.38+.68*k+.15*sin(t*.32));
        q*=float2(.83+.18*k,1.3-.15*k);
        float a=atan2(q.y,q.x), radius=.16+k*(.85+.25*u.canvas.w);
        float d=length(q)-radius*(1.+.12*cos(3.*a+.42*t+k)+.075*sin(2.*a-t*.24));
        float3 dye=mix(float3(.55,.28,.87),float3(.39,.59,.84),k);
        c+=dye*(exp(-abs(d)*73.)*.61+lobe(d+.028,430.)*.27)
          *(.53+.41*cos(a-.31*t+k));
        c+=float3(.055,.025,.09)*lobe(d-.071,110.);
    }
    return finishArt(c,in,u);
}
