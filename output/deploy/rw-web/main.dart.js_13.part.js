((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,C,D,B={Na:function Na(d){this.a=d
this.b=0},ad1:function ad1(){},E8:function E8(d){this.b=d},Lh:function Lh(d){this.c=d},
a2R(d,e){var x,w,v=d.length,u=0
for(;;){if(!(u<v&&d[u]===0))break;++u}v-=u
x=new Uint8Array(v+e)
for(w=0;w<v;++w)x[w]=d[w+u]
return new B.aGe(x)},
aGe:function aGe(d){this.a=d},
btu(d,e){var x=C.a([],y.v)
C.a2V(d,1,40,"typeNumber")
C.awR(e,4,A.aeC,null,"errorCorrectLevel")
return new B.aGb(d,e,d*4+17,x)},
bJx(d,e){var x,w,v,u,t,s,r,q
for(x=y.t,w=1;w<40;++w){v=B.btx(w,d)
u=new B.Na(C.a([],x))
for(t=v.length,s=0,r=0;r<t;++r)s+=v[r].b
for(r=0;r<1;++r){q=e[r]
u.ps(4,4)
u.ps(q.b.length,B.bx6(4,w))
q.mK(u)}if(u.b<=s*8)break}return w},
bwA(d,e,f){var x,w,v,u,t,s,r,q=B.btx(d,e),p=new B.Na(C.a([],y.t))
for(x=0;x<f.length;++x){w=f[x]
p.ps(4,4)
p.ps(w.b.length,B.bx6(4,d))
w.mK(p)}for(v=q.length,u=0,x=0;x<v;++x)u+=q[x].b
t=u*8
v=p.b
if(v>t)throw C.i(new B.Lh("Input too long. "+v+" > "+t))
if(v+4<=t)p.ps(0,4)
while(D.x.aX(p.b,8)!==0)p.aeR(!1)
for(s=0;;s=r){if(p.b>=t)break
r=s+1
p.ps((s&1)===0?236:17,8)}return B.bP0(p,q)},
bP0(d,e){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h=y.T,g=C.b8(e.length,null,!1,h),f=C.b8(e.length,null,!1,h)
for(h=d.a,x=0,w=0,v=0,u=0;u<e.length;++u){t=e[u]
s=t.b
r=t.a-s
w=Math.max(w,s)
v=Math.max(v,r)
q=new Uint8Array(s)
g[u]=q
for(p=0;p<s;++p)q[p]=h[p+x]&255
x+=s
o=B.bPl(r)
t=o.a.length-1
n=B.a2R(q,t).ae2(o)
m=new Uint8Array(t)
f[u]=m
for(l=n.a,k=l.length,p=0;p<t;++p){j=p+k-t
m[p]=j>=0?l[j]:0}}i=C.a([],y.t)
for(p=0;p<w;++p)for(u=0;u<e.length;++u){h=g[u]
if(p<h.length)i.push(h[p])}for(p=0;p<v;++p)for(u=0;u<e.length;++u){h=f[u]
if(p<h.length)i.push(h[p])}return i},
bx6(d,e){var x,w=null
if(1<=e&&e<10){$label0$0:{x=8
if(1===d){x=10
break $label0$0}if(2===d){x=9
break $label0$0}if(4===d)break $label0$0
if(8===d)break $label0$0
x=C.ac(C.bC("mode:"+d,w))}return x}else if(e<27){$label1$1:{if(1===d){x=12
break $label1$1}if(2===d){x=11
break $label1$1}if(4===d){x=16
break $label1$1}if(8===d){x=10
break $label1$1}x=C.ac(C.bC("mode:"+d,w))}return x}else if(e<41){$label2$2:{if(1===d){x=14
break $label2$2}if(2===d){x=13
break $label2$2}if(4===d){x=16
break $label2$2}if(8===d){x=12
break $label2$2}x=C.ac(C.bC("mode:"+d,w))}return x}else throw C.i(C.bC("type:"+e,w))},
bPl(d){var x,w=y.t,v=B.a2R(C.a([1],w),0)
for(x=0;x<d;++x)v=v.e0(B.a2R(C.a([1,$.ajZ()[D.x.aX(x,255)]],w),0))
return v},
aGb:function aGb(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=null
_.e=g},
bJy(d){var x,w,v,u,t,s,r,q,p,o,n
for(x=y.Q,w=d.c,v=d.a,u=d.b,t=d.e,s=0,r=null,q=0;q<8;++q){p=new B.a2Q(w,v,u,q,C.a([],x))
o=d.d
p.a3Q(q,o==null?d.d=B.bwA(v,u,t):o,!0)
n=B.bQm(p)
if(q===0||s>n){r=p
s=n}}t=r.d
x=new B.a2Q(w,v,u,t,C.a([],x))
x.a3Q(t,d.gaNX(),!1)
return x},
bQp(d,e,f){var x
$label0$0:{if(0===d){x=(e+f&1)===0
break $label0$0}if(1===d){x=(e&1)===0
break $label0$0}if(2===d){x=D.x.aX(f,3)===0
break $label0$0}if(3===d){x=D.x.aX(e+f,3)===0
break $label0$0}if(4===d){x=(D.x.bm(e,2)+D.x.bm(f,3)&1)===0
break $label0$0}if(5===d){x=e*f
x=D.x.aX(x,2)+D.x.aX(x,3)===0
break $label0$0}if(6===d){x=e*f
x=(D.x.aX(x,2)+D.x.aX(x,3)&1)===0
break $label0$0}if(7===d){x=(D.x.aX(e*f,3)+D.x.aX(e+f,2)&1)===0
break $label0$0}x=C.ac(C.bC("bad maskPattern:"+d,null))}return x},
bQm(d){var x,w,v,u,t,s,r,q,p,o,n,m,l,k=d.a
for(x=0,w=0;w<k;++w)for(v=0;v<k;++v){u=d.fh(w,v)
for(t=0,s=-1;s<=1;++s){r=w+s
if(r<0||k<=r)continue
for(q=s===0,p=-1;p<=1;++p){o=v+p
if(o<0||k<=o)continue
if(q&&p===0)continue
if(u===d.fh(r,o))++t}}if(t>5)x+=3+t-5}for(r=k-1,w=0;w<r;w=n)for(n=w+1,v=0;v<r;){m=d.fh(w,v)?1:0
if(d.fh(n,v))++m;++v
if(d.fh(w,v))++m
if(d.fh(n,v))++m
if(m===0||m===4)x+=3}for(r=k-6,w=0;w<k;++w)for(v=0;v<r;++v)if(d.fh(w,v)&&!d.fh(w,v+1)&&d.fh(w,v+2)&&d.fh(w,v+3)&&d.fh(w,v+4)&&!d.fh(w,v+5)&&d.fh(w,v+6))x+=40
for(v=0;v<k;++v)for(w=0;w<r;++w)if(d.fh(w,v)&&!d.fh(w+1,v)&&d.fh(w+2,v)&&d.fh(w+3,v)&&d.fh(w+4,v)&&!d.fh(w+5,v)&&d.fh(w+6,v))x+=40
for(v=0,l=0;v<k;++v)for(w=0;w<k;++w)if(d.fh(w,v))++l
return x+Math.abs(100*l/k/k-50)/5*10},
a2Q:function a2Q(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
btx(d,e){var x,w,v,u,t,s,r=B.bPN(d,e),q=r.length/3|0,p=C.a([],y.J)
for(x=0;x<q;++x){w=x*3
v=r[w]
u=r[w+1]
t=r[w+2]
for(s=0;s<v;++s)p.push(new B.a2S(u,t))}return p},
bPN(d,e){var x
$label0$0:{if(1===e){x=A.nZ[(d-1)*4]
break $label0$0}if(0===e){x=A.nZ[(d-1)*4+1]
break $label0$0}if(3===e){x=A.nZ[(d-1)*4+2]
break $label0$0}if(2===e){x=A.nZ[(d-1)*4+3]
break $label0$0}x=C.ac(C.bC("bad rs block @ typeNumber: "+d+"/errorCorrectLevel:"+e,null))}return x},
a2S:function a2S(d,e){this.a=d
this.b=e},
aE2:function aE2(d,e){this.a=d
this.b=e},
btw(d,e,f,g,h,i,j,k){return new B.Nb(e,d,k,i,j,!0,g,f,null)},
Nb:function Nb(d,e,f,g,h,i,j,k,l){var _=this
_.c=d
_.e=e
_.f=f
_.w=g
_.x=h
_.Q=i
_.ch=j
_.CW=k
_.a=l},
ad2:function ad2(){var _=this
_.d=null
_.f=_.e=$
_.c=_.a=null},
b3j:function b3j(d){this.a=d},
Tf:function Tf(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
Nc:function Nc(d,e,f,g,h,i,j,k,l,m,n){var _=this
_.b=d
_.c=e
_.d=f
_.e=g
_.f=h
_.r=i
_.w=j
_.x=k
_.z=_.y=$
_.as=l
_.at=m
_.a=n},
b2Q:function b2Q(d,e,f){var _=this
_.a=d
_.b=e
_.c=f
_.f=_.e=_.d=$},
zc:function zc(d,e){this.a=d
this.b=e},
CL:function CL(d,e){this.a=d
this.b=e},
aGd:function aGd(d,e){this.a=d
this.b=e},
aGc:function aGc(d,e){this.a=d
this.b=e},
Ea:function Ea(d,e){this.a=d
this.b=e},
E9:function E9(d,e){this.a=d
this.b=e},
bJz(d,e,f){var x,w,v,u,t,s=C.bJ()
try{if(f!==-1){s.scO(B.btu(f,e))
v=s.am()
u=D.bP.bh(d)
v.e.push(new B.E8(u))
v.d=null}else{v=B.btu(B.bJx(e,C.a([new B.E8(D.bP.bh(d))],y.v)),e)
v.e.push(new B.E8(D.bP.bh(d)))
v.d=null
s.scO(v)}v=s.am()
return new B.Nd(A.uG,v,null)}catch(t){v=C.a4(t)
if(v instanceof B.Lh){x=v
return new B.Nd(A.aVp,null,x)}else if(y.L.b(v)){w=v
return new B.Nd(A.aVq,null,w)}else throw t}},
Nd:function Nd(d,e,f){this.a=d
this.b=e
this.c=f},
Ne:function Ne(d,e){this.a=d
this.b=e},
te(d,e,f,g){var x,w,v,u,t,s,r,q,p,o=null,n=e.length,m="",l=o
if(n!==0){w=0
for(;;){if(!(w<n)){x=0
break}if(e.charCodeAt(w)===64){m=D.m.a2(e,0,w)
x=w+1
break}++w}if(x<n&&e.charCodeAt(x)===91){for(v=x,u=-1;v<n;++v){t=e.charCodeAt(v)
if(t===37&&u<0){s=D.m.e5(e,"25",v+1)?v+2:v
u=v
v=s}else if(t===93)break}if(v===n)throw C.i(C.cJ("Invalid IPv6 host entry.",e,x))
r=u<0?v:u
C.bv0(e,x+1,r);++v
if(v!==n&&e.charCodeAt(v)!==58)throw C.i(C.cJ("Invalid end of authority",e,v))}else v=x
for(;v<n;++v)if(e.charCodeAt(v)===58){q=D.m.bD(e,v+1)
l=q.length!==0?C.io(q,o):o
break}p=D.m.a2(e,x,v)}else p=o
return C.lT(o,p,o,C.a(f.split("/"),y.s),l,o,g,d,m)},
byl(d){return d>=1?$.ak1()[d]:C.ac(C.bC("glog("+d+")",null))},
bP1(){var x,w=new Uint8Array(256)
for(x=0;x<8;++x)w[x]=D.x.AN(1,x)
for(x=8;x<256;++x)w[x]=w[x-4]^w[x-5]^w[x-6]^w[x-8]
return w},
bP2(){var x,w=new Uint8Array(256)
for(x=0;x<255;++x)w[$.ajZ()[x]]=x
return w},
bRO(d){var x,w=d<<10>>>0
for(x=w;B.Bb(x)-B.Bb(1335)>=0;)x=(x^D.x.kT(1335,B.Bb(x)-B.Bb(1335)))>>>0
return((w|x)^21522)>>>0},
bRP(d){var x,w=d<<12>>>0
for(x=w;B.Bb(x)-B.Bb(7973)>=0;)x=(x^D.x.kT(7973,B.Bb(x)-B.Bb(7973)))>>>0
return(w|x)>>>0},
Bb(d){var x
for(x=0;d!==0;){++x
d=d>>>1}return x}},A
J=c[1]
C=c[0]
D=c[2]
B=a.updateHolder(c[61],B)
A=c[99]
B.Na.prototype={
m(d,e,f){return C.ac(C.bR("cannot change"))},
i(d,e){return(D.x.Rg(this.a[D.x.bm(e,8)],7-D.x.aX(e,8))&1)===1},
gC(d){return this.b},
sC(d,e){C.ac(C.bR("Cannot change"))},
ps(d,e){var x
for(x=0;x<e;++x)this.aeR((D.x.F9(d,e-x-1)&1)===1)},
aeR(d){var x=this,w=D.x.bm(x.b,8),v=x.a
if(v.length<=w)v.push(0)
if(d)v[w]=v[w]|D.x.qh(128,D.x.aX(x.b,8));++x.b},
$ib2:1,
$iH:1,
$iD:1}
B.ad1.prototype={}
B.E8.prototype={
gC(d){return this.b.length},
mK(d){var x,w,v
for(x=this.b,w=x.length,v=0;v<w;++v)d.ps(x[v],8)},
$ibtv:1}
B.Lh.prototype={
j(d){return"QrInputTooLongException: "+this.c},
$iaR:1}
B.aGe.prototype={
i(d,e){return this.a[e]},
gC(d){return this.a.length},
e0(d){var x,w,v,u,t,s,r=this.a,q=r.length,p=d.a,o=p.length,n=new Uint8Array(q+o-1)
for(x=0;x<q;++x)for(w=0;w<o;++w){v=x+w
u=n[v]
t=r[x]
t=t>=1?$.ak1()[t]:C.ac(C.bC("glog("+t+")",null))
s=p[w]
s=s>=1?$.ak1()[s]:C.ac(C.bC("glog("+s+")",null))
n[v]=(u^$.ajZ()[D.x.aX(t+s,255)])>>>0}return B.a2R(n,0)},
ae2(d){var x,w,v,u=this.a,t=u.length,s=d.a,r=s.length
if(t-r<0)return this
x=B.byl(u[0])-B.byl(s[0])
w=new Uint8Array(t)
for(v=0;v<t;++v)w[v]=u[v]
for(v=0;v<r;++v){u=w[v]
t=s[v]
t=t>=1?$.ak1()[t]:C.ac(C.bC("glog("+t+")",null))
w[v]=(u^$.ajZ()[D.x.aX(t+x,255)])>>>0}return B.a2R(w,0).ae2(d)}}
B.aGb.prototype={
gaNX(){var x=this,w=x.d
return w==null?x.d=B.bwA(x.a,x.b,x.e):w}}
B.a2Q.prototype={
aFg(){var x,w,v,u=this.e
D.l.a1(u)
for(x=this.a,w=y.u,v=0;v<x;++v)u.push(C.b8(x,null,!1,w))},
fh(d,e){var x
if(d>=0){x=this.a
x=x<=d||e<0||x<=e}else x=!0
if(x)throw C.i(C.bC(""+d+" , "+e,null))
x=this.e[d][e]
x.toString
return x},
a3Q(d,e,f){var x,w=this
w.aFg()
w.Rb(0,0)
x=w.a-7
w.Rb(x,0)
w.Rb(0,x)
w.aGR()
w.aGS()
w.aGT(d,f)
if(w.b>=7)w.aGU(f)
w.aBg(e,d)},
Rb(d,e){var x,w,v,u,t,s,r,q,p,o,n,m,l,k
for(x=this.e,w=this.a,v=-1;v<=7;++v){u=d+v
if(u<=-1||w<=u)continue
for(t=0<=v,s=v<=6,r=v!==0,q=v===6,p=2<=v,o=v<=4,n=-1;n<=7;++n){m=e+n
if(m<=-1||w<=m)continue
l=!1
if(t)if(s)l=n===0||n===6
k=!0
if(!l){l=!1
if(0<=n)if(n<=6)l=!r||q
if(!l)l=p&&o&&2<=n&&n<=4
else l=k}else l=k
if(l)x[u][m]=!0
else x[u][m]=!1}}},
aGR(){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=A.aLD[this.b-1]
for(x=j.length,w=this.e,v=0;v<x;++v)for(u=0;u<x;++u){t=j[v]
s=j[u]
if(w[t][s]!=null)continue
for(r=-2;r<=2;++r)for(q=t+r,p=r!==-2,o=r!==2,n=r===0,m=-2;m<=2;++m){l=!0
if(p)if(o)if(m!==-2)if(m!==2)l=n&&m===0
k=s+m
if(l)w[q][k]=!0
else w[q][k]=!1}}},
aGS(){var x,w,v,u,t
for(x=this.a-8,w=this.e,v=8;v<x;++v){u=w[v]
if(u[6]!=null)continue
u[6]=(v&1)===0}for(t=8;t<x;++t){u=w[6]
if(u[t]!=null)continue
u[t]=(t&1)===0}},
aGT(d,e){var x,w,v,u,t,s,r=B.bRO((this.c<<3|d)>>>0)
for(x=this.e,w=this.a,v=w-15,u=!e,t=0;t<15;++t){s=u&&(D.x.qh(r,t)&1)===1
if(t<6)x[t][8]=s
else if(t<8)x[t+1][8]=s
else x[v+t][8]=s}for(t=0;t<15;++t){s=u&&(D.x.qh(r,t)&1)===1
if(t<8)x[8][w-t-1]=s
else{v=15-t-1
if(t<9)x[8][v+1]=s
else x[8][v]=s}}x[w-8][8]=u},
aGU(d){var x,w,v,u,t,s=B.bRP(this.b)
for(x=this.e,w=this.a,v=!d,u=0;u<18;++u){t=v&&(D.x.qh(s,u)&1)===1
x[D.x.bm(u,3)][D.x.aX(u,3)+w-8-3]=t}for(u=0;u<18;++u){t=v&&(D.x.qh(s,u)&1)===1
x[D.x.aX(u,3)+w-8-3][D.x.bm(u,3)]=t}},
aBg(d,e){var x,w,v,u,t,s,r,q,p,o=this.a,n=o-1
for(x=this.e,w=n,v=-1,u=7,t=0;w>0;w-=2){if(w===6)--w
for(;;){for(s=0;s<2;++s){r=w-s
if(x[n][r]==null){q=t<d.length&&(D.x.Rg(d[t],u)&1)===1
if(B.bQp(e,n,r))q=!q
x[n][r]=q;--u
if(u===-1){++t
u=7}}}n+=v
if(n<0||o<=n){n-=v
p=-v
v=p
break}}}}}
B.a2S.prototype={}
B.aE2.prototype={
a_v(d,e){var x=e!=null?e.J():"any"
return d.j(0)+":"+x},
aLx(d,e,f){if(e===A.oG)this.a.push(d)
else this.b.m(0,this.a_v(e,f),d)},
a9K(d,e){return this.aLx(d,e,null)},
Ki(d,e){return d===A.oG?D.l.gaa(this.a):this.b.i(0,this.a_v(d,e))},
aPD(d){return this.Ki(d,null)}}
B.Nb.prototype={
Y(){return new B.ad2()}}
B.ad2.prototype={
u(d){var x=this,w=x.a
w=x.e=B.bJz(w.c,1,w.f)
x.d=w.a===A.uG?w.b:null
return C.iy(new B.b3j(x))},
aEI(d,e){var x,w,v,u=null,t=this.d
t.toString
x=this.a
w=t.a
v=new B.Nc(w,t.b,!0,d,u,x.ch,x.CW,t,new B.aE2(C.a([],y.H),C.A(y.N,y.Z)),u,u)
v.z=w
v.aAf()
w=this.a
return new B.Tf(e,w.e,w.w,C.iW(u,u,u,v,D.az),"qr code",u)},
atS(d,e,f){var x,w,v,u=null,t=this.a
t.toString
x=C.I(u,u,D.r,u,u,u,u,u,u,u,u,u,u)
w=t.x
v=w==null?new C.V(C.S(1/0,e.a,e.b),C.S(1/0,e.c,e.d)).geM():w
return new B.Tf(v,t.e,t.w,x,"qr code",u)}}
B.Tf.prototype={
u(d){var x=this,w=null,v=x.c
return C.bz(w,w,C.I(w,new C.a2(x.e,x.f,w),D.r,x.d,w,w,w,v,w,w,w,w,v),!1,w,w,!1,w,!1,w,w,w,w,w,w,x.r,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,w,D.a6,w)},
gO(){return this.f}}
B.Nc.prototype={
aAf(){var x,w,v,u,t,s
this.y=B.bJy(this.x)
x=this.as
$.ap()
w=C.bn()
w.b=D.cD
x.a9K(w,A.oG)
w=C.bn()
w.b=D.cD
x.a9K(w,A.aVm)
for(v=0;v<3;++v){u=A.a2E[v]
w=new C.n6(D.dD,D.cD,D.hm,D.hn,D.et)
w.b=D.ct
t=x.b
s=u.J()
t.m(0,A.Pr.j(0)+":"+s,w)
w=new C.n6(D.dD,D.cD,D.hm,D.hn,D.et)
w.b=D.ct
s=u.J()
t.m(0,A.Ps.j(0)+":"+s,w)
s=u.J()
t.m(0,A.Pt.j(0)+":"+s,new C.n6(D.dD,D.cD,D.hm,D.hn,D.et))}},
aJ(a6,a7){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5=this
if(a7.geM()===0){C.dq().$1("[QR] WARN: width or height is zero. You should set a 'size' value or nest this painter in a Widget that defines a non-zero size")
return}x=a7.geM()
w=a5.x.c
v=new B.b2Q(w,x,0)
u=(w-1)*0
t=v.d=D.q.M4((x-u)/w*2)/2
s=t*w+u
v.e=s
s=v.f=(x-s)/2
a5.P3(A.rP,a6,v)
a5.P3(A.rQ,a6,v)
a5.P3(A.zo,a6,v)
r=a5.as.aPD(A.oG)
r.toString
x=a5.w
r.r=x.b.gq()
for(q=a6.a,x=x.a===A.oH,p=w-7,o=0;o<w;++o)for(n=o<7,m=o>=p,l=0;l<w;++l){k=l<7
j=k&&n
i=k&&m
h=l>=p&&n
if(j||i||h)continue
k=a5.y
k===$&&C.b()
if(k.fh(l,o))g=r
else g=null
if(g==null)continue
k=t+0
f=s+o*k
e=s+l*k
k=a5.azU(o,l,w)
d=k?0.5:0
k=a5.azV(o,l,w)
a0=k?0.5:0
k=t+d
a1=new C.Q(f,e,f+k,e+(t+a0))
if(x){a2=g.f4()
q.drawRect(C.e6(a1),a2)
a2.delete()}else{a3=C.kG(a1,new C.b5(k,k))
a2=g.f4()
q.drawRRect(C.q1(a3),a2)
a2.delete()}}x=a5.e
if(x!=null){w=x.b
w===$&&C.b()
w=w.a
w===$&&C.b()
w=J.aK(w.a.width())
t=x.b.a
t===$&&C.b()
t=J.aK(t.a.height())
a4=a5.aFT(a7,new C.V(w,t),null)
w=a4.a
t=(a7.a-w)/2
s=a4.b
q=(a7.b-s)/2
$.ap()
g=C.bn()
g.f=!0
g.Q=D.jU
p=x.b.a
p===$&&C.b()
p=J.aK(p.a.width())
k=x.b.a
k===$&&C.b()
k=J.aK(k.a.height())
a6.xt(x,D.ak.ur(new C.V(p,k),new C.Q(0,0,p,k)),D.ak.ur(a4,new C.Q(t,q,t+w,q+s)),g)}},
azV(d,e,f){var x,w=e+1
if(w>=f)return!1
x=this.y
x===$&&C.b()
return x.fh(w,d)},
azU(d,e,f){var x,w=d+1
if(w>=f)return!1
x=this.y
x===$&&C.b()
return x.fh(e,w)},
P3(d,e,f){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i=f.d
i===$&&C.b()
x=7*i+6*f.c-i
w=i/2
v=f.f
v===$&&C.b()
u=f.e
u===$&&C.b()
t=v+u-(x+w)
if(d===A.rP){v+=w
s=new C.t(v,v)}else{v+=w
s=d===A.rQ?new C.t(v,t):new C.t(t,v)}v=this.as
r=v.Ki(A.Pr,d)
r.c=i
u=this.r
q=u.b
r.r=q.gq()
p=v.Ki(A.Ps,d)
p.c=i
p.r=D.qj.gq()
o=v.Ki(A.Pt,d)
o.toString
o.r=q.gq()
v=s.a
q=s.b
n=new C.Q(v,q,v+x,q+x)
m=x-2*i
v+=i
q+=i
l=x-i*2-2*w
i=v+w
k=q+w
j=new C.Q(i,k,i+l,k+l)
if(u.a===A.oI){e.fc(n,r)
e.fc(new C.Q(v,q,v+m,q+m),p)
e.fc(j,o)}else{e.e_(C.kG(n,new C.b5(x,x)),r)
e.e_(C.kG(n,new C.b5(m,m)),p)
e.e_(C.kG(j,new C.b5(l,l)),o)}},
aFT(d,e,f){var x=0.25*d.geM()/e.gadU()
return new C.V(x*e.a,x*e.b)},
ex(d){var x,w,v=this
if(d instanceof B.Nc){if(v.c===d.c){x=v.z
x===$&&C.b()
w=d.z
w===$&&C.b()
x=x!==w||v.x!==d.x||v.e!=d.e||!v.r.k(0,d.r)||!v.w.k(0,d.w)}else x=!0
return x}return!0}}
B.b2Q.prototype={}
B.zc.prototype={
J(){return"QrCodeElement."+this.b}}
B.CL.prototype={
J(){return"FinderPatternPosition."+this.b}}
B.aGd.prototype={
J(){return"QrEyeShape."+this.b}}
B.aGc.prototype={
J(){return"QrDataModuleShape."+this.b}}
B.Ea.prototype={
gv(d){var x=this.b
return(C.dO(this.a)^x.gv(x))>>>0},
k(d,e){if(e==null)return!1
if(e instanceof B.Ea)return this.a===e.a&&this.b.k(0,e.b)
return!1}}
B.E9.prototype={
gv(d){var x=this.b
return(C.dO(this.a)^x.gv(x))>>>0},
k(d,e){if(e==null)return!1
if(e instanceof B.E9)return this.a===e.a&&this.b.k(0,e.b)
return!1}}
B.Nd.prototype={}
B.Ne.prototype={
J(){return"QrValidationStatus."+this.b}}
var z=a.updateTypes([])
B.b3j.prototype={
$2(d,e){var x,w=this.a,v=w.e
v===$&&C.b()
if(v.a!==A.uG)return w.atS(d,e,v.c)
x=w.a.x
w=w.aEI(null,x==null?new C.V(C.S(1/0,e.a,e.b),C.S(1/0,e.c,e.d)).geM():x)
return w},
$S:102};(function inheritance(){var x=a.mixin,w=a.inheritMany,v=a.inherit
w(C.w,[B.ad1,B.E8,B.Lh,B.aGe,B.aGb,B.a2Q,B.a2S,B.aE2,B.b2Q,B.Ea,B.E9,B.Nd])
v(B.Na,B.ad1)
v(B.Nb,C.N)
v(B.ad2,C.a8)
v(B.b3j,C.cO)
v(B.Tf,C.R)
v(B.Nc,C.tV)
w(C.iK,[B.zc,B.CL,B.aGd,B.aGc,B.Ne])
x(B.ad1,C.aL)})()
C.c8(b.typeUniverse,JSON.parse('{"Na":{"aL":["y"],"D":["y"],"b2":["y"],"H":["y"],"aL.E":"y","H.E":"y"},"E8":{"btv":[]},"Lh":{"aR":[]},"Nb":{"N":[],"c":[]},"ad2":{"a8":["Nb"]},"Tf":{"R":[],"c":[]},"Nc":{"at":[]}}'))
var y=(function rtii(){var x=C.B
return{L:x("aR"),S:x("x<D<u>>"),Q:x("x<D<y?>>"),H:x("x<pf>"),v:x("x<btv>"),J:x("x<a2S>"),s:x("x<f>"),t:x("x<u>"),Z:x("pf"),N:x("f"),T:x("D<u>?"),u:x("y?")}})();(function constants(){var x=a.makeConstList
A.rP=new B.CL(0,"topLeft")
A.zo=new B.CL(1,"topRight")
A.rQ=new B.CL(2,"bottomLeft")
A.ip=new C.b_(62034,"Lucide","lucide_icons",!1)
A.a2E=x([A.rP,A.zo,A.rQ],C.B("x<CL>"))
A.aeC=x([1,0,3,2],y.t)
A.aAz=x([6,18],y.t)
A.aAA=x([6,22],y.t)
A.aAD=x([6,26],y.t)
A.aAJ=x([6,30],y.t)
A.aAP=x([6,34],y.t)
A.aAB=x([6,22,38],y.t)
A.aAC=x([6,24,42],y.t)
A.aAE=x([6,26,46],y.t)
A.aAI=x([6,28,50],y.t)
A.aAK=x([6,30,54],y.t)
A.aAO=x([6,32,58],y.t)
A.aAQ=x([6,34,62],y.t)
A.aAF=x([6,26,46,66],y.t)
A.aAG=x([6,26,48,70],y.t)
A.aAH=x([6,26,50,74],y.t)
A.aAL=x([6,30,54,78],y.t)
A.aAM=x([6,30,56,82],y.t)
A.aAN=x([6,30,58,86],y.t)
A.aAR=x([6,34,62,90],y.t)
A.ayD=x([6,28,50,72,94],y.t)
A.aMB=x([6,26,50,74,98],y.t)
A.aNW=x([6,30,54,78,102],y.t)
A.aLC=x([6,28,54,80,106],y.t)
A.aMU=x([6,32,58,84,110],y.t)
A.aLc=x([6,30,58,86,114],y.t)
A.aKT=x([6,34,62,90,118],y.t)
A.aP1=x([6,26,50,74,98,122],y.t)
A.aNj=x([6,30,54,78,102,126],y.t)
A.aOt=x([6,26,52,78,104,130],y.t)
A.aML=x([6,30,56,82,108,134],y.t)
A.aOQ=x([6,34,60,86,112,138],y.t)
A.aIR=x([6,30,58,86,114,142],y.t)
A.aOp=x([6,34,62,90,118,146],y.t)
A.aMJ=x([6,30,54,78,102,126,150],y.t)
A.aN2=x([6,24,50,76,102,128,154],y.t)
A.aLZ=x([6,28,54,80,106,132,158],y.t)
A.aMP=x([6,32,58,84,110,136,162],y.t)
A.a2F=x([6,26,54,82,110,138,166],y.t)
A.aLd=x([6,30,58,86,114,142,170],y.t)
A.aLD=x([D.Ft,A.aAz,A.aAA,A.aAD,A.aAJ,A.aAP,A.aAB,A.aAC,A.aAE,A.aAI,A.aAK,A.aAO,A.aAQ,A.aAF,A.aAG,A.aAH,A.aAL,A.aAM,A.aAN,A.aAR,A.ayD,A.aMB,A.aNW,A.aLC,A.aMU,A.aLc,A.aKT,A.aP1,A.aNj,A.aOt,A.aML,A.aOQ,A.aIR,A.aOp,A.aMJ,A.aN2,A.aLZ,A.aMP,A.a2F,A.aLd],y.S)
A.aeH=x([1,26,19],y.t)
A.aeG=x([1,26,16],y.t)
A.aeF=x([1,26,13],y.t)
A.aeI=x([1,26,9],y.t)
A.aeM=x([1,44,34],y.t)
A.aeL=x([1,44,28],y.t)
A.aeK=x([1,44,22],y.t)
A.aeJ=x([1,44,16],y.t)
A.aeO=x([1,70,55],y.t)
A.aeN=x([1,70,44],y.t)
A.alp=x([2,35,17],y.t)
A.alo=x([2,35,13],y.t)
A.aeD=x([1,100,80],y.t)
A.alr=x([2,50,32],y.t)
A.alq=x([2,50,24],y.t)
A.awJ=x([4,25,9],y.t)
A.aeE=x([1,134,108],y.t)
A.als=x([2,67,43],y.t)
A.aLh=x([2,33,15,2,34,16],y.t)
A.aL4=x([2,33,11,2,34,12],y.t)
A.alt=x([2,86,68],y.t)
A.awM=x([4,43,27],y.t)
A.awL=x([4,43,19],y.t)
A.awK=x([4,43,15],y.t)
A.alu=x([2,98,78],y.t)
A.awN=x([4,49,31],y.t)
A.aME=x([2,32,14,4,33,15],y.t)
A.aM2=x([4,39,13,1,40,14],y.t)
A.alm=x([2,121,97],y.t)
A.aMQ=x([2,60,38,2,61,39],y.t)
A.aO4=x([4,40,18,2,41,19],y.t)
A.aOn=x([4,40,14,2,41,15],y.t)
A.aln=x([2,146,116],y.t)
A.all=x([3,58,36,2,59,37],y.t)
A.aMe=x([4,36,16,4,37,17],y.t)
A.aOc=x([4,36,12,4,37,13],y.t)
A.aMX=x([2,86,68,2,87,69],y.t)
A.aL_=x([4,69,43,1,70,44],y.t)
A.aOT=x([6,43,19,2,44,20],y.t)
A.aMV=x([6,43,15,2,44,16],y.t)
A.awH=x([4,101,81],y.t)
A.aN1=x([1,80,50,4,81,51],y.t)
A.aLt=x([4,50,22,4,51,23],y.t)
A.aNf=x([3,36,12,8,37,13],y.t)
A.aO6=x([2,116,92,2,117,93],y.t)
A.aKI=x([6,58,36,2,59,37],y.t)
A.aLH=x([4,46,20,6,47,21],y.t)
A.aKK=x([7,42,14,4,43,15],y.t)
A.awI=x([4,133,107],y.t)
A.aOA=x([8,59,37,1,60,38],y.t)
A.aOK=x([8,44,20,4,45,21],y.t)
A.aOY=x([12,33,11,4,34,12],y.t)
A.aM5=x([3,145,115,1,146,116],y.t)
A.aEe=x([4,64,40,5,65,41],y.t)
A.aNF=x([11,36,16,5,37,17],y.t)
A.aM3=x([11,36,12,5,37,13],y.t)
A.aMt=x([5,109,87,1,110,88],y.t)
A.aMR=x([5,65,41,5,66,42],y.t)
A.aLp=x([5,54,24,7,55,25],y.t)
A.a7g=x([11,36,12],y.t)
A.aL8=x([5,122,98,1,123,99],y.t)
A.aNJ=x([7,73,45,3,74,46],y.t)
A.aM4=x([15,43,19,2,44,20],y.t)
A.aLw=x([3,45,15,13,46,16],y.t)
A.aMo=x([1,135,107,5,136,108],y.t)
A.a2G=x([10,74,46,1,75,47],y.t)
A.aN7=x([1,50,22,15,51,23],y.t)
A.aKW=x([2,42,14,17,43,15],y.t)
A.aMN=x([5,150,120,1,151,121],y.t)
A.aLG=x([9,69,43,4,70,44],y.t)
A.aMf=x([17,50,22,1,51,23],y.t)
A.aNO=x([2,42,14,19,43,15],y.t)
A.aLv=x([3,141,113,4,142,114],y.t)
A.aOR=x([3,70,44,11,71,45],y.t)
A.aKE=x([17,47,21,4,48,22],y.t)
A.aqZ=x([9,39,13,16,40,14],y.t)
A.aKV=x([3,135,107,5,136,108],y.t)
A.aL9=x([3,67,41,13,68,42],y.t)
A.aOq=x([15,54,24,5,55,25],y.t)
A.aOM=x([15,43,15,10,44,16],y.t)
A.alh=x([4,144,116,4,145,117],y.t)
A.aei=x([17,68,42],y.t)
A.aKs=x([17,50,22,6,51,23],y.t)
A.aM9=x([19,46,16,6,47,17],y.t)
A.aLY=x([2,139,111,7,140,112],y.t)
A.aej=x([17,74,46],y.t)
A.aKt=x([7,54,24,16,55,25],y.t)
A.aoy=x([34,37,13],y.t)
A.aMZ=x([4,151,121,5,152,122],y.t)
A.aNd=x([4,75,47,14,76,48],y.t)
A.aLE=x([11,54,24,14,55,25],y.t)
A.a2I=x([16,45,15,14,46,16],y.t)
A.aOF=x([6,147,117,4,148,118],y.t)
A.aLn=x([6,73,45,14,74,46],y.t)
A.ali=x([11,54,24,16,55,25],y.t)
A.aMr=x([30,46,16,2,47,17],y.t)
A.aL7=x([8,132,106,4,133,107],y.t)
A.awE=x([8,75,47,13,76,48],y.t)
A.aOf=x([7,54,24,22,55,25],y.t)
A.aKx=x([22,45,15,13,46,16],y.t)
A.aOH=x([10,142,114,2,143,115],y.t)
A.aMh=x([19,74,46,4,75,47],y.t)
A.aKN=x([28,50,22,6,51,23],y.t)
A.aMM=x([33,46,16,4,47,17],y.t)
A.aKL=x([8,152,122,4,153,123],y.t)
A.aMT=x([22,73,45,3,74,46],y.t)
A.aOa=x([8,53,23,26,54,24],y.t)
A.aLj=x([12,45,15,28,46,16],y.t)
A.aKJ=x([3,147,117,10,148,118],y.t)
A.aOk=x([3,73,45,23,74,46],y.t)
A.aMb=x([4,54,24,31,55,25],y.t)
A.aNN=x([11,45,15,31,46,16],y.t)
A.aMK=x([7,146,116,7,147,117],y.t)
A.aOZ=x([21,73,45,7,74,46],y.t)
A.aMi=x([1,53,23,37,54,24],y.t)
A.aM6=x([19,45,15,26,46,16],y.t)
A.aOW=x([5,145,115,10,146,116],y.t)
A.aLy=x([19,75,47,10,76,48],y.t)
A.aOj=x([15,54,24,25,55,25],y.t)
A.aOb=x([23,45,15,25,46,16],y.t)
A.aOX=x([13,145,115,3,146,116],y.t)
A.aNH=x([2,74,46,29,75,47],y.t)
A.aEd=x([42,54,24,1,55,25],y.t)
A.aL1=x([23,45,15,28,46,16],y.t)
A.aeh=x([17,145,115],y.t)
A.aNQ=x([10,74,46,23,75,47],y.t)
A.awF=x([10,54,24,35,55,25],y.t)
A.aN9=x([19,45,15,35,46,16],y.t)
A.aMx=x([17,145,115,1,146,116],y.t)
A.aP3=x([14,74,46,21,75,47],y.t)
A.aLb=x([29,54,24,19,55,25],y.t)
A.aNI=x([11,45,15,46,46,16],y.t)
A.aL0=x([13,145,115,6,146,116],y.t)
A.aNL=x([14,74,46,23,75,47],y.t)
A.aNh=x([44,54,24,7,55,25],y.t)
A.aNE=x([59,46,16,1,47,17],y.t)
A.aNg=x([12,151,121,7,152,122],y.t)
A.aLf=x([12,75,47,26,76,48],y.t)
A.aHu=x([39,54,24,14,55,25],y.t)
A.aNi=x([22,45,15,41,46,16],y.t)
A.aLx=x([6,151,121,14,152,122],y.t)
A.aeB=x([6,75,47,34,76,48],y.t)
A.aND=x([46,54,24,10,55,25],y.t)
A.aLm=x([2,45,15,64,46,16],y.t)
A.aOJ=x([17,152,122,4,153,123],y.t)
A.aB7=x([29,74,46,14,75,47],y.t)
A.aN6=x([49,54,24,10,55,25],y.t)
A.aOr=x([24,45,15,46,46,16],y.t)
A.aMF=x([4,152,122,18,153,123],y.t)
A.aMS=x([13,74,46,32,75,47],y.t)
A.aLi=x([48,54,24,14,55,25],y.t)
A.aP_=x([42,45,15,32,46,16],y.t)
A.aOO=x([20,147,117,4,148,118],y.t)
A.aOv=x([40,75,47,7,76,48],y.t)
A.aOE=x([43,54,24,22,55,25],y.t)
A.aN0=x([10,45,15,67,46,16],y.t)
A.aKM=x([19,148,118,6,149,119],y.t)
A.aLQ=x([18,75,47,31,76,48],y.t)
A.aL2=x([34,54,24,34,55,25],y.t)
A.aLA=x([20,45,15,61,46,16],y.t)
A.nZ=x([A.aeH,A.aeG,A.aeF,A.aeI,A.aeM,A.aeL,A.aeK,A.aeJ,A.aeO,A.aeN,A.alp,A.alo,A.aeD,A.alr,A.alq,A.awJ,A.aeE,A.als,A.aLh,A.aL4,A.alt,A.awM,A.awL,A.awK,A.alu,A.awN,A.aME,A.aM2,A.alm,A.aMQ,A.aO4,A.aOn,A.aln,A.all,A.aMe,A.aOc,A.aMX,A.aL_,A.aOT,A.aMV,A.awH,A.aN1,A.aLt,A.aNf,A.aO6,A.aKI,A.aLH,A.aKK,A.awI,A.aOA,A.aOK,A.aOY,A.aM5,A.aEe,A.aNF,A.aM3,A.aMt,A.aMR,A.aLp,A.a7g,A.aL8,A.aNJ,A.aM4,A.aLw,A.aMo,A.a2G,A.aN7,A.aKW,A.aMN,A.aLG,A.aMf,A.aNO,A.aLv,A.aOR,A.aKE,A.aqZ,A.aKV,A.aL9,A.aOq,A.aOM,A.alh,A.aei,A.aKs,A.aM9,A.aLY,A.aej,A.aKt,A.aoy,A.aMZ,A.aNd,A.aLE,A.a2I,A.aOF,A.aLn,A.ali,A.aMr,A.aL7,A.awE,A.aOf,A.aKx,A.aOH,A.aMh,A.aKN,A.aMM,A.aKL,A.aMT,A.aOa,A.aLj,A.aKJ,A.aOk,A.aMb,A.aNN,A.aMK,A.aOZ,A.aMi,A.aM6,A.aOW,A.aLy,A.aOj,A.aOb,A.aOX,A.aNH,A.aEd,A.aL1,A.aeh,A.aNQ,A.awF,A.aN9,A.aMx,A.aP3,A.aLb,A.aNI,A.aL0,A.aNL,A.aNh,A.aNE,A.aNg,A.aLf,A.aHu,A.aNi,A.aLx,A.aeB,A.aND,A.aLm,A.aOJ,A.aB7,A.aN6,A.aOr,A.aMF,A.aMS,A.aLi,A.aP_,A.aOO,A.aOv,A.aOE,A.aN0,A.aKM,A.aLQ,A.aL2,A.aLA],y.S)
A.Pr=new B.zc(0,"finderPatternOuter")
A.Ps=new B.zc(1,"finderPatternInner")
A.Pt=new B.zc(2,"finderPatternDot")
A.oG=new B.zc(3,"codePixel")
A.aVm=new B.zc(4,"codePixelEmpty")
A.oH=new B.aGc(0,"square")
A.baj=new B.E9(A.oH,D.S)
A.oI=new B.aGd(0,"square")
A.bak=new B.Ea(A.oI,D.S)
A.uG=new B.Ne(0,"valid")
A.aVp=new B.Ne(1,"contentTooLong")
A.aVq=new B.Ne(2,"error")})();(function lazyInitializers(){var x=a.lazyFinal
x($,"c00","ak1",()=>B.bP2())
x($,"c_k","ajZ",()=>B.bP1())})()};
(a=>{a["KNncH1Ix8GXHrj/5o0/5GtJhHRE="]=a.current})($__dart_deferred_initializers__);