((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var A,C,B={
brO(d){return new B.D4(d)},
awK:function awK(d){this.a=d},
D4:function D4(d){this.a=d},
awl:function awl(){}},D
A=c[0]
C=c[2]
B=a.updateHolder(c[51],B)
D=c[163]
B.awK.prototype={
a3f(){var x,w=$.ff().gib()
if(w==null||w.a.length===0)return C.aX
x=y.g
return A.a_(["venue_session",A.a_(["access_token",w.a],x,x)],x,y.b)},
ya(d){return this.aUT(d)},
aUT(d){var x=0,w=A.o(y.f),v,u=this,t,s,r,q,p,o
var $async$ya=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(u.a.aez(80,1080,1920,D.zR),$async$ya)
case 3:p=f
if(p==null){v=null
x=1
break}x=4
return A.h(p.nZ(),$async$ya)
case 4:t=f
s=t.byteLength
if(s>8388608)throw A.i(B.brO("Image is too large ("+C.q.ai(s/1024/1024,1)+"MB). Maximum size is 8MB."))
s=p.c
s===$&&A.b()
r=u.a7i(t,s)
s=A.A(y.g,y.b)
s.m(0,"venueId",d)
s.m(0,"image_data",r)
s.L(0,u.a3f())
o=y.k
x=5
return A.h(A.m3("upload_venue_image",null,s,!1),$async$ya)
case 5:q=o.a(f)
v=A.a5(q==null?null:q.i(0,"image_url"))
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$ya,w)},
y9(d,e){return this.aUS(d,e)},
aUS(d,e){var x=0,w=A.o(y.f),v,u=this,t,s,r,q,p,o
var $async$y9=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=3
return A.h(u.a.aez(80,1200,1200,D.zR),$async$y9)
case 3:p=g
if(p==null){v=null
x=1
break}x=4
return A.h(p.nZ(),$async$y9)
case 4:t=g
s=t.byteLength
if(s>8388608)throw A.i(B.brO("Image is too large ("+C.q.ai(s/1024/1024,1)+"MB). Maximum size is 8MB."))
s=p.c
s===$&&A.b()
r=u.a7i(t,s)
s=A.A(y.g,y.b)
s.m(0,"venueId",d)
s.m(0,"itemId",e)
s.m(0,"image_data",r)
s.L(0,u.a3f())
o=y.k
x=5
return A.h(A.m3("upload_menu_item_image",null,s,!1),$async$y9)
case 5:q=o.a(g)
v=A.a5(q==null?null:q.i(0,"image_url"))
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$y9,w)},
a7i(d,e){return"data:"+this.aBH(e)+";base64,"+C.hD.gk0().bh(d)},
aBH(d){var x=d.toLowerCase()
if(C.m.fp(x,".png"))return"image/png"
if(C.m.fp(x,".webp"))return"image/webp"
return"image/jpeg"}}
B.D4.prototype={
j(d){return this.a},
$iaR:1}
B.awl.prototype={
aez(d,e,f,g){var x=new A.a0A(C.xk,f,e,d,!0)
x.aoA(d,e,f,!0)
return $.bzF().pE(x,g)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inheritMany
x(A.w,[B.awK,B.D4,B.awl])})()
A.c8(b.typeUniverse,JSON.parse('{"D4":{"aR":[]}}'))
var y={g:A.B("f"),b:A.B("@"),k:A.B("av<f,@>?"),f:A.B("f?")};(function constants(){D.KP=new A.b_(62817,"Lucide","lucide_icons",!1)
D.zR=new A.a0B(1,"gallery")})();(function lazyInitializers(){var x=a.lazyFinal
x($,"bWS","bor",()=>new B.awK(new B.awl()))})()};
(a=>{a["BNZrLk972WiHTjLflqMbwp2VWj0="]=a.current})($__dart_deferred_initializers__);