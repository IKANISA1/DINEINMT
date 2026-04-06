((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
bHk(d){return C.l.qL(D.aOh,new B.aAK(d),new B.aAL())},
bHi(d){var x
$label0$0:{if("food"===d){x=D.L6
break $label0$0}if("drinks"===d){x=D.L7
break $label0$0}x=null
break $label0$0}return x},
bHj(d){var x
$label0$0:{if("manual"===d){x=D.eZ
break $label0$0}if("ai_gemini"===d){x=D.aS_
break $label0$0}x=D.um
break $label0$0}return x},
nw:function nw(d,e){this.a=d
this.b=e},
aAK:function aAK(d){this.a=d},
aAL:function aAL(){},
kv:function kv(d,e){this.a=d
this.b=e},
LY:function LY(d,e){this.a=d
this.b=e},
bkF(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1){return new B.by(i,a1,d,e,u,g,v,w,h,f,t,r,o,p,n,k,l,m,q,j,s,x,a0)},
LZ(a2){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=null,d=A.aT(a2.i(0,"id")),a0=A.aT(a2.i(0,"venue_id")),a1=A.a8(a2.i(0,"admin_group_id"))
if(a1==null)a1=A.a8(a2.i(0,"adminGroupId"))
x=A.et(a2.i(0,"admin_managed"))
if(x==null)x=A.et(a2.i(0,"adminManaged"))
w=A.aT(a2.i(0,"name"))
v=A.a8(a2.i(0,"description"))
if(v==null)v=""
u=A.hL(a2.i(0,"price"))
if(u==null)u=e
if(u==null)u=0
t=A.et(a2.i(0,"price_hidden"))
s=A.hL(a2.i(0,"highlight_rank"))
s=s==null?e:C.p.cJ(s)
if(s==null){s=A.hL(a2.i(0,"highlightRank"))
s=s==null?e:C.p.cJ(s)}r=A.a8(a2.i(0,"category"))
if(r==null)r="Uncategorized"
q=B.bHi(A.a8(a2.i(0,"class")))
p=A.a8(a2.i(0,"image_url"))
o=B.bHj(A.a8(a2.i(0,"image_source")))
n=A.a8(a2.i(0,"image_status"))
n=B.bHk(n==null?"pending":n)
m=A.a8(a2.i(0,"image_model"))
l=A.a8(a2.i(0,"image_error"))
k=A.a8(a2.i(0,"image_generated_at"))
k=A.oA(k==null?"":k)
j=A.et(a2.i(0,"image_locked"))
i=A.a8(a2.i(0,"image_storage_path"))
h=A.hL(a2.i(0,"image_attempts"))
h=h==null?e:C.p.cJ(h)
if(h==null)h=0
g=A.et(a2.i(0,"is_available"))
f=y.L.a(a2.i(0,"tags"))
f=f==null?e:J.to(f,y.N)
if(f==null)f=C.b7
return B.bkF(a1,x===!0,r,v,s,d,h,l,k,j===!0,m,o,n,i,p,g!==!1,q,w,u,t===!0,f,0,a0)},
bPk(d){var x=C.m.V(d).toLowerCase()
return x==="popular"||x==="bestseller"||x==="best seller"||x==="house favorite"||x==="house favourite"},
bPm(d){var x=C.m.V(d).toLowerCase()
return x==="signature"||x==="chef special"},
bwu(d){var x,w=C.m.V(d).toLowerCase()
$label0$0:{if("vegetarian"===w||"veg"===w){x="Vegetarian"
break $label0$0}if("vegan"===w){x="Vegan"
break $label0$0}if("halal"===w){x="Halal"
break $label0$0}if("kosher"===w){x="Kosher"
break $label0$0}if("gluten free"===w||"gluten-free"===w||"gf"===w){x="Gluten-Free"
break $label0$0}if("dairy free"===w||"dairy-free"===w||"lactose free"===w||"lactose-free"===w){x="Dairy-Free"
break $label0$0}if("nut free"===w||"nut-free"===w||"tree nut free"===w){x="Nut-Free"
break $label0$0}if("peanut free"===w||"peanut-free"===w){x="Peanut-Free"
break $label0$0}if("egg free"===w||"egg-free"===w){x="Egg-Free"
break $label0$0}if("soy free"===w||"soy-free"===w||"soya free"===w){x="Soy-Free"
break $label0$0}if("fish free"===w||"fish-free"===w){x="Fish-Free"
break $label0$0}if("shellfish free"===w||"shellfish-free"===w||"crustacean free"===w){x="Shellfish-Free"
break $label0$0}if("sesame free"===w||"sesame-free"===w){x="Sesame-Free"
break $label0$0}if("celery free"===w||"celery-free"===w){x="Celery-Free"
break $label0$0}if("mustard free"===w||"mustard-free"===w){x="Mustard-Free"
break $label0$0}if("sulphite free"===w||"sulphite-free"===w||"sulfite free"===w||"sulfite-free"===w){x="Sulphite-Free"
break $label0$0}if("lupin free"===w||"lupin-free"===w){x="Lupin-Free"
break $label0$0}if("mollusc free"===w||"mollusc-free"===w||"mollusk free"===w){x="Mollusc-Free"
break $label0$0}if("contains nuts"===w||"contains tree nuts"===w){x="Contains Nuts"
break $label0$0}if("contains gluten"===w||"contains wheat"===w){x="Contains Gluten"
break $label0$0}if("contains dairy"===w||"contains milk"===w||"contains lactose"===w){x="Contains Dairy"
break $label0$0}if("contains eggs"===w||"contains egg"===w){x="Contains Eggs"
break $label0$0}if("contains soy"===w||"contains soya"===w){x="Contains Soy"
break $label0$0}if("contains fish"===w){x="Contains Fish"
break $label0$0}if("contains shellfish"===w||"contains crustaceans"===w){x="Contains Shellfish"
break $label0$0}if("contains sesame"===w){x="Contains Sesame"
break $label0$0}if("contains peanuts"===w||"contains peanut"===w){x="Contains Peanuts"
break $label0$0}if("spicy"===w||"hot"===w){x="Spicy"
break $label0$0}x=null
break $label0$0}return x},
by:function by(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o
_.as=p
_.at=q
_.ax=r
_.ay=s
_.ch=t
_.CW=u
_.cx=v
_.cy=w
_.db=x
_.dx=a0
_.dy=a1},
aAN:function aAN(){},
aAO:function aAO(){},
aAM:function aAM(d){this.a=d},
a1b:function a1b(d,e,f){this.a=d
this.e=e
this.f=f},
aAJ:function aAJ(){},
aAP:function aAP(){},
aAZ:function aAZ(){},
aB_:function aB_(){},
aB2:function aB2(d){this.a=d},
aB0:function aB0(){},
aB1:function aB1(d){this.a=d},
aAR:function aAR(){},
aAQ:function aAQ(){},
aAW:function aAW(){},
aAX:function aAX(d,e,f){this.a=d
this.b=e
this.c=f},
aAY:function aAY(){},
aAT:function aAT(){},
aAU:function aAU(d){this.a=d},
aAV:function aAV(){},
aAS:function aAS(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[70],B)
D=c[123]
B.nw.prototype={
J(){return"MenuItemImageStatus."+this.b},
gdB(){switch(this.a){case 0:var x="Pending"
break
case 1:x="Generating"
break
case 2:x="Ready"
break
case 3:x="Failed"
break
default:x=null}return x}}
B.kv.prototype={
J(){return"MenuItemClass."+this.b},
gdB(){switch(this.a){case 0:var x="Food"
break
case 1:x="Drinks"
break
default:x=null}return x}}
B.LY.prototype={
J(){return"MenuItemImageSource."+this.b},
gmf(){var x=null
switch(this.a){case 0:break
case 1:x="manual"
break
case 2:x="ai_gemini"
break}return x},
gdB(){switch(this.a){case 0:var x="Unknown"
break
case 1:x="Manual"
break
case 2:x="Gemini AI"
break
default:x=null}return x}}
B.by.prototype={
cg(){var x,w,v,u=this,t=u.z
t=t==null?null:t.b
x=u.gC1()
x=x==null?null:x.gmf()
w=u.gxu()
v=u.ch
v=v==null?null:v.it()
return A.a0(["id",u.a,"venue_id",u.b,"admin_group_id",u.c,"admin_managed",u.d,"name",u.e,"description",u.f,"price",u.r,"price_hidden",u.w,"highlight_rank",u.x,"category",u.y,"class",t,"image_url",u.Q,"image_source",x,"image_status",w.b,"image_model",u.ax,"image_error",u.ay,"image_generated_at",v,"image_locked",u.CW,"image_storage_path",u.cx,"image_attempts",u.cy,"is_available",u.db,"tags",u.dx],y.N,y.z)},
J8(d,e,f,g,h,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var x=this,w=a6==null?x.e:a6,v=e==null?x.f:e,u=a7==null?x.r:a7,t=d==null?x.y:d,s=a5==null?x.z:a5,r=a3==null?x.Q:a3,q=a1==null?x.as:a1,p=a2==null?x.at:a2,o=a0==null?x.ax:a0,n=f==null?x.ay:f,m=g==null?x.ch:g,l=h==null?x.CW:h,k=a4==null?x.db:a4,j=a8==null?x.dx:a8,i=a9==null?x.dy:a9
return B.bkF(x.c,x.d,t,v,x.x,x.a,x.cy,n,m,l,o,q,p,x.cx,r,k,s,w,u,x.w,j,i,x.b)},
aMy(d){var x=null
return this.J8(x,x,x,x,x,x,x,x,x,x,x,x,x,x,d)},
aM1(d){var x=null
return this.J8(x,x,x,x,x,x,x,x,x,d,x,x,x,x,x)},
aMA(d,e,f,g,h,i,j,k,l,m,n,o,p,q){return this.J8(d,e,f,g,h,i,j,k,l,m,n,o,p,q,null)},
aM_(d){var x=null
return this.J8(x,x,x,x,d,x,x,x,x,x,x,x,x,x,x)},
guk(){var x=this.Q
return x!=null&&C.m.V(x).length!==0},
gaRE(){return this.dy>=10||J.ak0(this.dx,new B.aAN())},
gaRG(){return J.ak0(this.dx,new B.aAO())},
gahD(){if(this.x!=null)return"Top Pick"
if(this.gaRE())return"Popular"
if(this.gaRG())return"Signature"
return null},
gaO5(){var x,w,v=A.a([],y.s)
for(x=J.bb(this.dx);x.t();){w=B.bwu(x.gN())
if(w==null||C.l.p(v,w))continue
v.push(w)}return v},
gMI(){var x,w,v,u,t=A.a([],y.s),s=this.gahD()
if(s!=null)t.push(s)
C.l.L(t,this.gaO5())
for(x=J.bb(this.dx);x.t();){w=C.m.V(x.gN())
if(w.length===0)continue
v=C.m.V(w)
u=v.toLowerCase()
if(!(u==="popular"||u==="bestseller"||u==="best seller"||u==="house favorite"||u==="house favourite")){u=v.toLowerCase()
v=u==="signature"||u==="chef special"||w.toLowerCase()==="top pick"||B.bwu(w)!=null}else v=!0
if(v)continue
if(C.l.fP(t,new B.aAM(w)))continue
t.push(w)}return t},
gC1(){var x=this.as
if(x!==D.um)return x
if(this.guk())return D.eZ
return null},
gxu(){if(this.guk()&&this.at===D.kx)return D.im
return this.at},
gjp(){var x=this
return[x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,x.Q,x.as,x.at,x.CW,x.cx,x.cy,x.db,x.dx,x.dy]}}
B.a1b.prototype={}
B.aAJ.prototype={
aB9(){var x,w,v=$.fN().gjb()
if(v==null)return C.aY
x=v.a
if(x.length===0)return C.aY
w=y.N
return A.a0(["venue_session",A.a0(["access_token",x],w,w)],w,y.z)},
E6(d,e,f,g){return this.agz(d,e,!1,g)},
agz(d,e,f,g){var x=0,w=A.o(y.o),v,u=this,t,s,r,q,p
var $async$E6=A.k(function(h,i){if(h===1)return A.l(i,w)
for(;;)switch(x){case 0:q=A.A(y.N,y.z)
q.m(0,"itemId",e)
q.m(0,"forceRegenerate",d)
q.L(0,u.aB9())
p=y.P
x=3
return A.h(A.qs("generate_menu_item_image",null,q,!1),$async$E6)
case 3:t=p.a(i)
q=A.a8(t.i(0,"status"))
if(q==null)q="unknown"
A.a8(t.i(0,"itemId"))
A.a8(t.i(0,"venueId"))
A.a8(t.i(0,"imageStatus"))
s=A.a8(t.i(0,"imageUrl"))
r=A.a8(t.i(0,"reason"))
A.a8(t.i(0,"model"))
A.a8(t.i(0,"error"))
v=new B.a1b(q,s,r)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$E6,w)}}
B.aAP.prototype={
wd(){var x,w,v=$.fN().gjb()
if(v==null)return C.aY
x=v.a
if(x.length===0)return C.aY
w=y.N
return A.a0(["venue_session",A.a0(["access_token",x],w,w)],w,y.z)},
vn(d){return this.ah_(d)},
ah_(d){var x=0,w=A.o(y.u),v,u=this,t,s,r,q,p
var $async$vn=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:q=J
p=y.j
x=3
return A.h(A.eu().$3$payload$useAdminSession("get_menu_items",A.a0(["venueId",d],y.N,y.z),!1),$async$vn)
case 3:t=q.eS(p.a(f),new B.aAZ(),y.g)
s=A.Z(t,t.$ti.h("an.E"))
r=s.length!==0&&C.l.dQ(s,new B.aB_())
x=s.length===0||r?4:6
break
case 4:x=7
return A.h(u.zB(d),$async$vn)
case 7:x=5
break
case 6:x=8
return A.h(u.wj(d,s),$async$vn)
case 8:case 5:v=s
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$vn,w)},
Em(d){return this.agZ(d)},
agZ(d){var x=0,w=A.o(y.R),v,u
var $async$Em=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.eu().$3$payload$useAdminSession("get_menu_item_by_id",A.a0(["itemId",d],y.N,y.z),!1),$async$Em)
case 3:u=f
if(u==null){v=null
x=1
break}v=B.LZ(y.P.a(u))
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$Em,w)},
El(d){return this.agW(d)},
agW(d){var x=0,w=A.o(y.u),v,u=this
var $async$El=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.jr(),$async$El)
case 3:v=u.H7(f,"dinein.local_menu."+d)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$El,w)},
DU(d,e){return this.aWg(d,e)},
aWg(d,e){var x=0,w=A.o(y.H),v=this,u
var $async$DU=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:u=A.A(y.N,y.z)
u.m(0,"itemId",d)
u.m(0,"isAvailable",e)
u.L(0,v.wd())
x=2
return A.h(A.eu().$2$payload("toggle_menu_item_availability",u),$async$DU)
case 2:x=3
return A.h(v.wH(d,new B.aB2(e)),$async$DU)
case 3:return A.m(null,w)}})
return A.n($async$DU,w)},
BF(d){return this.aNc(d)},
aNc(d){var x=0,w=A.o(y.g),v,u=this,t,s,r,q
var $async$BF=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:s=A.A(y.N,y.z)
s.m(0,"item",d.cg())
s.L(0,u.wd())
r=B
q=y.P
x=3
return A.h(A.eu().$2$payload("create_menu_item",s),$async$BF)
case 3:t=r.LZ(q.a(f))
x=4
return A.h(u.we(t.b,A.a([t],y.m)),$async$BF)
case 4:if(!t.guk()&&!t.CW)u.H6(t.a)
v=t
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$BF,w)},
yA(d,e){return this.aWy(d,e)},
aWy(d,e){var x=0,w=A.o(y.H),v=this,u,t,s
var $async$yA=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:s=A.A(y.N,y.z)
s.m(0,"itemId",d)
s.m(0,"updates",e)
s.L(0,v.wd())
x=2
return A.h(A.eu().$3$payload$useAdminSession("update_menu_item",s,!1),$async$yA)
case 2:u=g
x=y.P.b(u)?3:4
break
case 3:t=B.LZ(u)
x=5
return A.h(v.we(t.b,A.a([t],y.m)),$async$yA)
case 5:case 4:return A.m(null,w)}})
return A.n($async$yA,w)},
z3(d,e){return this.aik(d,e)},
aik(d,e){var x=0,w=A.o(y.u),v,u=this,t,s,r,q,p,o,n
var $async$z3=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:p=A.a([],y.s)
for(t=e.length,s=0;s<e.length;e.length===t||(0,A.M)(e),++s){r=C.m.V(e[s])
if(r.length===0||C.l.p(p,r))continue
p.push(r)
if(p.length===3)break}t=A.A(y.N,y.z)
t.m(0,"venueId",d)
t.m(0,"itemIds",p)
t.L(0,u.wd())
o=J
n=y.j
x=3
return A.h(A.eu().$2$payload("set_menu_item_highlights",t),$async$z3)
case 3:t=o.eS(n.a(g),new B.aB0(),y.g)
q=A.Z(t,t.$ti.h("an.E"))
x=4
return A.h(u.wj(d,q),$async$z3)
case 4:v=q
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$z3,w)},
BR(d){return this.aNN(d)},
aNN(d){var x=0,w=A.o(y.H),v=this,u
var $async$BR=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:u=A.A(y.N,y.z)
u.m(0,"itemId",d)
u.L(0,v.wd())
x=2
return A.h(A.eu().$2$payload("delete_menu_item",u),$async$BR)
case 2:x=3
return A.h(v.wo(d),$async$BR)
case 3:return A.m(null,w)}})
return A.n($async$BR,w)},
X_(d,e){return $.bzr().E6(e,d,!1,null)},
WZ(d){return this.X_(d,!1)},
z4(d,e){return this.ail(d,e)},
ail(d,e){var x=0,w=A.o(y.H),v=this,u,t
var $async$z4=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:u=y.N
t=A.A(u,y.z)
t.m(0,"itemId",d)
t.m(0,"updates",A.a0(["image_locked",e],u,y.y))
t.L(0,v.wd())
x=2
return A.h(A.eu().$3$payload$useAdminSession("update_menu_item",t,!1),$async$z4)
case 2:x=3
return A.h(v.wH(d,new B.aB1(e)),$async$z4)
case 3:return A.m(null,w)}})
return A.n($async$z4,w)},
Ez(d){return this.ahy(d)},
ahy(a1){var x=0,w=A.o(y.a),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0
var $async$Ez=A.k(function(a2,a3){if(a2===1){t.push(a3)
x=u}for(;;)switch(x){case 0:u=4
m=$.iL().b
m===$&&A.b()
l=y.N
k=y.z
j=A.a0(["p_venue_id",a1],l,k)
i=m.ay
i===$&&A.b()
h=i.b
g=A.eN(h,l,l)
g.L(0,m.x)
h.L(0,g)
g=A.eN(i.b,l,l)
h=A.cE(i.a+"/rpc/get_venue_item_popularity",0,null)
m=A.bsv(null,null,null,g,i.d,i.e,!1,null,i.c,h,k,k,k)
a0=y.j
x=7
return A.h(new A.a2r(m.a,m.b,!1,m.d,m.e,m.f,m.r,m.w,m.x,m.y,A.jm("supabase.postgrest")).aVW(j,!1,k),$async$Ez)
case 7:s=a0.a(a3)
r=A.A(l,y.S)
for(m=J.bb(s),l=y.P;m.t();){q=m.gN()
p=l.a(q)
o=A.a8(J.ch(p,"menu_item_id"))
k=A.hL(J.ch(p,"total_ordered"))
f=k==null?null:C.p.cJ(k)
n=f==null?0:f
if(o!=null&&n>0)J.lR(r,o,n)}v=r
x=1
break
u=2
x=6
break
case 4:u=3
d=t.pop()
v=D.L0
x=1
break
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Ez,w)},
H6(d){return this.aEf(d)},
aEf(d){var x=0,w=A.o(y.H),v=1,u=[],t=this,s,r
var $async$H6=A.k(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.h(t.WZ(d),$async$H6)
case 6:v=1
x=5
break
case 3:v=2
r=u.pop()
x=5
break
case 2:x=1
break
case 5:return A.m(null,w)
case 1:return A.l(u.at(-1),w)}})
return A.n($async$H6,w)},
wj(d,e){return this.aDI(d,e)},
aDI(d,e){var x=0,w=A.o(y.H),v,u
var $async$wj=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jr(),$async$wj)
case 2:v=g
u=A.a_(e).h("a3<1,aw<f,@>>")
u=A.Z(new A.a3(e,new B.aAR(),u),u.h("an.E"))
x=3
return A.h(v.qa("String","dinein.local_menu."+d,C.aN.lj(u,null)),$async$wj)
case 3:return A.m(null,w)}})
return A.n($async$wj,w)},
zB(d){return this.ar9(d)},
ar9(d){var x=0,w=A.o(y.H)
var $async$zB=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.jr(),$async$zB)
case 3:x=2
return A.h(f.K(0,"dinein.local_menu."+d),$async$zB)
case 2:return A.m(null,w)}})
return A.n($async$zB,w)},
we(d,e){return this.aBa(d,e)},
aBa(d,e){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o
var $async$we=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jr(),$async$we)
case 2:p=g
o=A.A(y.N,y.g)
for(u="dinein.local_menu."+d,t=v.H7(p,u),s=t.length,r=0;r<t.length;t.length===s||(0,A.M)(t),++r){q=t[r]
o.m(0,q.a,q)}for(r=0;r<1;++r){q=e[r]
o.m(0,q.a,q)}t=o.$ti.h("bt<2>")
t=A.nt(new A.bt(o,t),new B.aAQ(),t.h("H.E"),y.P)
o=A.Z(t,A.r(t).h("H.E"))
x=3
return A.h(p.qa("String",u,C.aN.lj(o,null)),$async$we)
case 3:return A.m(null,w)}})
return A.n($async$we,w)},
wH(d,e){return this.aIL(d,e)},
aIL(d,e){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o,n
var $async$wH=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jr(),$async$wH)
case 2:n=g
u=A.oW(n.a.gcl(),y.N),t=u.ga7(0),u=new A.f2(t,new B.aAW(),A.r(u).h("f2<1>"))
case 3:if(!u.t()){x=4
break}s=t.gN()
r={}
q=v.H7(n,s)
r.a=!1
p=A.a_(q).h("a3<1,by>")
o=A.Z(new A.a3(q,new B.aAX(r,d,e),p),p.h("an.E"))
if(!r.a){x=3
break}p=A.a_(o).h("a3<1,aw<f,@>>")
p=A.Z(new A.a3(o,new B.aAY(),p),p.h("an.E"))
x=5
return A.h(n.qa("String",s,C.aN.lj(p,null)),$async$wH)
case 5:x=3
break
case 4:return A.m(null,w)}})
return A.n($async$wH,w)},
wo(d){return this.aEA(d)},
aEA(d){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o,n
var $async$wo=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jr(),$async$wo)
case 2:n=f
u=n.a,t=A.oW(u.gcl(),y.N),s=t.ga7(0),t=new A.f2(s,new B.aAT(),A.r(t).h("f2<1>"))
case 3:if(!t.t()){x=4
break}r=s.gN()
q=v.H7(n,r)
p=A.a_(q).h("aq<1>")
p=A.Z(new A.aq(q,new B.aAU(d),p),p.h("H.E"))
p.$flags=1
o=p
p=o.length
if(p===q.length){x=3
break}x=p===0?5:6
break
case 5:u.K(0,r)
x=7
return A.h($.ajG().K(0,"flutter."+r),$async$wo)
case 7:x=3
break
case 6:p=A.a_(o).h("a3<1,aw<f,@>>")
p=A.Z(new A.a3(o,new B.aAV(),p),p.h("an.E"))
x=8
return A.h(n.qa("String",r,C.aN.lj(p,null)),$async$wo)
case 8:x=3
break
case 4:return A.m(null,w)}})
return A.n($async$wo,w)},
H7(d,e){var x,w=A.a8(d.a.i(0,e))
if(w==null||w.length===0)return D.tM
x=J.eS(y.j.a(C.aN.mg(w,null)),new B.aAS(),y.g)
x=A.Z(x,x.$ti.h("an.E"))
return x}}
var z=a.updateTypes(["aw<f,@>(by)","by(@)","by(by)","y(by)","y(nw)","nw()"])
B.aAK.prototype={
$1(d){return d.b===this.a},
$S:z+4}
B.aAL.prototype={
$0(){return D.kx},
$S:z+5}
B.aAN.prototype={
$1(d){return B.bPk(d)},
$S:13}
B.aAO.prototype={
$1(d){return B.bPm(d)},
$S:13}
B.aAM.prototype={
$1(d){return d.toLowerCase()===this.a.toLowerCase()},
$S:13}
B.aAZ.prototype={
$1(d){return B.LZ(d)},
$S:z+1}
B.aB_.prototype={
$1(d){return d.w},
$S:z+3}
B.aB2.prototype={
$1(d){return d.aM1(this.a)},
$S:z+2}
B.aB0.prototype={
$1(d){return B.LZ(y.P.a(d))},
$S:z+1}
B.aB1.prototype={
$1(d){return d.aM_(this.a)},
$S:z+2}
B.aAR.prototype={
$1(d){return d.cg()},
$S:z+0}
B.aAQ.prototype={
$1(d){return d.cg()},
$S:z+0}
B.aAW.prototype={
$1(d){return C.m.aT(d,"dinein.local_menu.")},
$S:13}
B.aAX.prototype={
$1(d){if(d.a!==this.b)return d
this.a.a=!0
return this.c.$1(d)},
$S:z+2}
B.aAY.prototype={
$1(d){return d.cg()},
$S:z+0}
B.aAT.prototype={
$1(d){return C.m.aT(d,"dinein.local_menu.")},
$S:13}
B.aAU.prototype={
$1(d){return d.a!==this.a},
$S:z+3}
B.aAV.prototype={
$1(d){return d.cg()},
$S:z+0}
B.aAS.prototype={
$1(d){return B.LZ(y.P.a(d))},
$S:z+1};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.iG,[B.nw,B.kv,B.LY])
x(A.cp,[B.aAK,B.aAN,B.aAO,B.aAM,B.aAZ,B.aB_,B.aB2,B.aB0,B.aB1,B.aAR,B.aAQ,B.aAW,B.aAX,B.aAY,B.aAT,B.aAU,B.aAV,B.aAS])
w(B.aAL,A.cI)
w(B.by,A.xA)
x(A.w,[B.a1b,B.aAJ,B.aAP])})()
var y=(function rtii(){var x=A.B
return{m:x("x<by>"),s:x("x<f>"),u:x("E<by>"),j:x("E<@>"),P:x("aw<f,@>"),a:x("aw<f,u>"),o:x("a1b"),g:x("by"),N:x("f"),y:x("y"),z:x("@"),S:x("u"),L:x("E<@>?"),R:x("by?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.tM=x([],y.m)
D.L6=new B.kv(0,"food")
D.L7=new B.kv(1,"drinks")
D.kx=new B.nw(0,"pending")
D.oo=new B.nw(1,"generating")
D.im=new B.nw(2,"ready")
D.L8=new B.nw(3,"failed")
D.aOh=x([D.kx,D.oo,D.im,D.L8],A.B("x<nw>"))
D.L0=new A.bW(C.cJ,[],A.B("bW<f,u>"))
D.um=new B.LY(0,"unknown")
D.eZ=new B.LY(1,"manual")
D.aS_=new B.LY(2,"aiGemini")})();(function lazyInitializers(){var x=a.lazyFinal
x($,"bWV","bzr",()=>new B.aAJ())
x($,"bWW","oa",()=>new B.aAP())})()};
(a=>{a["prbP/ZHGZyW//AXA//LVassqzmY="]=a.current})($__dart_deferred_initializers__);