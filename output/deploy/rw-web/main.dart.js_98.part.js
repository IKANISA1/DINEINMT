((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
bI8(d){return C.l.qR(D.aOs,new B.aBd(d),new B.aBe())},
bI6(d){var x
$label0$0:{if("food"===d){x=D.La
break $label0$0}if("drinks"===d){x=D.Lb
break $label0$0}x=null
break $label0$0}return x},
bI7(d){var x
$label0$0:{if("manual"===d){x=D.f0
break $label0$0}if("ai_gemini"===d){x=D.aSf
break $label0$0}x=D.uq
break $label0$0}return x},
nz:function nz(d,e){this.a=d
this.b=e},
aBd:function aBd(d){this.a=d},
aBe:function aBe(){},
kA:function kA(d,e){this.a=d
this.b=e},
M3:function M3(d,e){this.a=d
this.b=e},
bll(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1){return new B.bu(i,a1,d,e,u,g,v,w,h,f,t,r,o,p,n,k,l,m,q,j,s,x,a0)},
Dy(a2){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=null,d=A.aU(a2.i(0,"id")),a0=A.aU(a2.i(0,"venue_id")),a1=A.a5(a2.i(0,"admin_group_id"))
if(a1==null)a1=A.a5(a2.i(0,"adminGroupId"))
x=A.ev(a2.i(0,"admin_managed"))
if(x==null)x=A.ev(a2.i(0,"adminManaged"))
w=A.aU(a2.i(0,"name"))
v=A.a5(a2.i(0,"description"))
if(v==null)v=""
u=A.fx(a2.i(0,"price"))
if(u==null)u=e
if(u==null)u=0
t=A.ev(a2.i(0,"price_hidden"))
s=A.fx(a2.i(0,"highlight_rank"))
s=s==null?e:C.q.cu(s)
if(s==null){s=A.fx(a2.i(0,"highlightRank"))
s=s==null?e:C.q.cu(s)}r=A.a5(a2.i(0,"category"))
if(r==null)r="Uncategorized"
q=B.bI6(A.a5(a2.i(0,"class")))
p=A.a5(a2.i(0,"image_url"))
o=B.bI7(A.a5(a2.i(0,"image_source")))
n=A.a5(a2.i(0,"image_status"))
n=B.bI8(n==null?"pending":n)
m=A.a5(a2.i(0,"image_model"))
l=A.a5(a2.i(0,"image_error"))
k=A.a5(a2.i(0,"image_generated_at"))
k=A.oD(k==null?"":k)
j=A.ev(a2.i(0,"image_locked"))
i=A.a5(a2.i(0,"image_storage_path"))
h=A.fx(a2.i(0,"image_attempts"))
h=h==null?e:C.q.cu(h)
if(h==null)h=0
g=A.ev(a2.i(0,"is_available"))
f=y.L.a(a2.i(0,"tags"))
f=f==null?e:J.q5(f,y.N)
if(f==null)f=C.bb
return B.bll(a1,x===!0,r,v,s,d,h,l,k,j===!0,m,o,n,i,p,g!==!1,q,w,u,t===!0,f,0,a0)},
bQ9(d){var x=C.m.S(d).toLowerCase()
return x==="popular"||x==="bestseller"||x==="best seller"||x==="house favorite"||x==="house favourite"},
bQb(d){var x=C.m.S(d).toLowerCase()
return x==="signature"||x==="chef special"},
bxg(d){var x,w=C.m.S(d).toLowerCase()
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
bu:function bu(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1){var _=this
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
aBg:function aBg(){},
aBh:function aBh(){},
aBf:function aBf(d){this.a=d},
a1l:function a1l(d,e,f){this.a=d
this.e=e
this.f=f},
aBa:function aBa(){},
aBi:function aBi(){},
aBs:function aBs(){},
aBt:function aBt(){},
aBw:function aBw(d){this.a=d},
aBu:function aBu(){},
aBv:function aBv(d){this.a=d},
aBk:function aBk(){},
aBj:function aBj(){},
aBp:function aBp(){},
aBq:function aBq(d,e,f){this.a=d
this.b=e
this.c=f},
aBr:function aBr(){},
aBm:function aBm(){},
aBn:function aBn(d){this.a=d},
aBo:function aBo(){},
aBl:function aBl(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[71],B)
D=c[124]
B.nz.prototype={
J(){return"MenuItemImageStatus."+this.b},
gdC(){switch(this.a){case 0:var x="Pending"
break
case 1:x="Generating"
break
case 2:x="Ready"
break
case 3:x="Failed"
break
default:x=null}return x}}
B.kA.prototype={
J(){return"MenuItemClass."+this.b},
gdC(){switch(this.a){case 0:var x="Food"
break
case 1:x="Drinks"
break
default:x=null}return x}}
B.M3.prototype={
J(){return"MenuItemImageSource."+this.b},
gmj(){var x=null
switch(this.a){case 0:break
case 1:x="manual"
break
case 2:x="ai_gemini"
break}return x},
gdC(){switch(this.a){case 0:var x="Unknown"
break
case 1:x="Manual"
break
case 2:x="Gemini AI"
break
default:x=null}return x}}
B.bu.prototype={
ci(){var x,w,v,u=this,t=u.z
t=t==null?null:t.b
x=u.gC7()
x=x==null?null:x.gmj()
w=u.gxv()
v=u.ch
v=v==null?null:v.iw()
return A.a_(["id",u.a,"venue_id",u.b,"admin_group_id",u.c,"admin_managed",u.d,"name",u.e,"description",u.f,"price",u.r,"price_hidden",u.w,"highlight_rank",u.x,"category",u.y,"class",t,"image_url",u.Q,"image_source",x,"image_status",w.b,"image_model",u.ax,"image_error",u.ay,"image_generated_at",v,"image_locked",u.CW,"image_storage_path",u.cx,"image_attempts",u.cy,"is_available",u.db,"tags",u.dx],y.N,y.z)},
Jk(d,e,f,g,h,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var x=this,w=a6==null?x.e:a6,v=e==null?x.f:e,u=a7==null?x.r:a7,t=d==null?x.y:d,s=a5==null?x.z:a5,r=a3==null?x.Q:a3,q=a1==null?x.as:a1,p=a2==null?x.at:a2,o=a0==null?x.ax:a0,n=f==null?x.ay:f,m=g==null?x.ch:g,l=h==null?x.CW:h,k=a4==null?x.db:a4,j=a8==null?x.dx:a8,i=a9==null?x.dy:a9
return B.bll(x.c,x.d,t,v,x.x,x.a,x.cy,n,m,l,o,q,p,x.cx,r,k,s,w,u,x.w,j,i,x.b)},
aN4(d){var x=null
return this.Jk(x,x,x,x,x,x,x,x,x,x,x,x,x,x,d)},
aMy(d){var x=null
return this.Jk(x,x,x,x,x,x,x,x,x,d,x,x,x,x,x)},
aN6(d,e,f,g,h,i,j,k,l,m,n,o,p,q){return this.Jk(d,e,f,g,h,i,j,k,l,m,n,o,p,q,null)},
aMw(d){var x=null
return this.Jk(x,x,x,x,d,x,x,x,x,x,x,x,x,x,x)},
gul(){var x=this.Q
return x!=null&&C.m.S(x).length!==0},
gaSb(){return this.dy>=10||J.akd(this.dx,new B.aBg())},
gaSd(){return J.akd(this.dx,new B.aBh())},
gahY(){if(this.x!=null)return"Top Pick"
if(this.gaSb())return"Popular"
if(this.gaSd())return"Signature"
return null},
gaOD(){var x,w,v=A.a([],y.s)
for(x=J.bc(this.dx);x.t();){w=B.bxg(x.gN())
if(w==null||C.l.p(v,w))continue
v.push(w)}return v},
gMU(){var x,w,v,u,t=A.a([],y.s),s=this.gahY()
if(s!=null)t.push(s)
C.l.L(t,this.gaOD())
for(x=J.bc(this.dx);x.t();){w=C.m.S(x.gN())
if(w.length===0)continue
v=C.m.S(w)
u=v.toLowerCase()
if(!(u==="popular"||u==="bestseller"||u==="best seller"||u==="house favorite"||u==="house favourite")){u=v.toLowerCase()
v=u==="signature"||u==="chef special"||w.toLowerCase()==="top pick"||B.bxg(w)!=null}else v=!0
if(v)continue
if(C.l.fR(t,new B.aBf(w)))continue
t.push(w)}return t},
gC7(){var x=this.as
if(x!==D.uq)return x
if(this.gul())return D.f0
return null},
gxv(){if(this.gul()&&this.at===D.kB)return D.it
return this.at},
gjq(){var x=this
return[x.a,x.b,x.c,x.d,x.e,x.f,x.r,x.w,x.x,x.y,x.z,x.Q,x.as,x.at,x.CW,x.cx,x.cy,x.db,x.dx,x.dy]}}
B.a1l.prototype={}
B.aBa.prototype={
aBy(){var x,w,v=$.fg().gib()
if(v==null)return C.aX
x=v.a
if(x.length===0)return C.aX
w=y.N
return A.a_(["venue_session",A.a_(["access_token",x],w,w)],w,y.z)},
Ed(d,e,f,g){return this.agQ(d,e,!1,g)},
agQ(d,e,f,g){var x=0,w=A.o(y.o),v,u=this,t,s,r,q,p
var $async$Ed=A.k(function(h,i){if(h===1)return A.l(i,w)
for(;;)switch(x){case 0:q=A.A(y.N,y.z)
q.m(0,"itemId",e)
q.m(0,"forceRegenerate",d)
q.L(0,u.aBy())
p=y.P
x=3
return A.h(A.m4("generate_menu_item_image",null,q,!1),$async$Ed)
case 3:t=p.a(i)
q=A.a5(t.i(0,"status"))
if(q==null)q="unknown"
A.a5(t.i(0,"itemId"))
A.a5(t.i(0,"venueId"))
A.a5(t.i(0,"imageStatus"))
s=A.a5(t.i(0,"imageUrl"))
r=A.a5(t.i(0,"reason"))
A.a5(t.i(0,"model"))
A.a5(t.i(0,"error"))
v=new B.a1l(q,s,r)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$Ed,w)}}
B.aBi.prototype={
we(){var x,w,v=$.fg().gib()
if(v==null)return C.aX
x=v.a
if(x.length===0)return C.aX
w=y.N
return A.a_(["venue_session",A.a_(["access_token",x],w,w)],w,y.z)},
vo(d){return this.ahj(d)},
ahj(d){var x=0,w=A.o(y.u),v,u=this,t,s,r,q,p
var $async$vo=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:q=J
p=y.j
x=3
return A.h(A.ex().$3$payload$useAdminSession("get_menu_items",A.a_(["venueId",d],y.N,y.z),!1),$async$vo)
case 3:t=q.en(p.a(f),new B.aBs(),y.g)
s=A.Y(t,t.$ti.h("am.E"))
r=s.length!==0&&C.l.dQ(s,new B.aBt())
x=s.length===0||r?4:6
break
case 4:x=7
return A.h(u.zG(d),$async$vo)
case 7:x=5
break
case 6:x=8
return A.h(u.wk(d,s),$async$vo)
case 8:case 5:v=s
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$vo,w)},
Et(d){return this.ahi(d)},
ahi(d){var x=0,w=A.o(y.R),v,u
var $async$Et=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.ex().$3$payload$useAdminSession("get_menu_item_by_id",A.a_(["itemId",d],y.N,y.z),!1),$async$Et)
case 3:u=f
if(u==null){v=null
x=1
break}v=B.Dy(y.P.a(u))
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$Et,w)},
Es(d){return this.ahf(d)},
ahf(d){var x=0,w=A.o(y.u),v,u=this
var $async$Es=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.jz(),$async$Es)
case 3:v=u.Hh(f,"dinein.local_menu."+d)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$Es,w)},
E0(d,e){return this.aWV(d,e)},
aWV(d,e){var x=0,w=A.o(y.H),v=this,u
var $async$E0=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:u=A.A(y.N,y.z)
u.m(0,"itemId",d)
u.m(0,"isAvailable",e)
u.L(0,v.we())
x=2
return A.h(A.ex().$2$payload("toggle_menu_item_availability",u),$async$E0)
case 2:x=3
return A.h(v.wI(d,new B.aBw(e)),$async$E0)
case 3:return A.m(null,w)}})
return A.n($async$E0,w)},
BL(d){return this.aNK(d)},
aNK(d){var x=0,w=A.o(y.g),v,u=this,t,s,r,q
var $async$BL=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:s=A.A(y.N,y.z)
s.m(0,"item",d.ci())
s.L(0,u.we())
r=B
q=y.P
x=3
return A.h(A.ex().$2$payload("create_menu_item",s),$async$BL)
case 3:t=r.Dy(q.a(f))
x=4
return A.h(u.wf(t.b,A.a([t],y.m)),$async$BL)
case 4:if(!t.gul()&&!t.CW)u.Hg(t.a)
v=t
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$BL,w)},
yF(d,e){return this.aXc(d,e)},
aXc(d,e){var x=0,w=A.o(y.H),v=this,u,t,s
var $async$yF=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:s=A.A(y.N,y.z)
s.m(0,"itemId",d)
s.m(0,"updates",e)
s.L(0,v.we())
x=2
return A.h(A.ex().$3$payload$useAdminSession("update_menu_item",s,!1),$async$yF)
case 2:u=g
x=y.P.b(u)?3:4
break
case 3:t=B.Dy(u)
x=5
return A.h(v.wf(t.b,A.a([t],y.m)),$async$yF)
case 5:case 4:return A.m(null,w)}})
return A.n($async$yF,w)},
z8(d,e){return this.aiG(d,e)},
aiG(d,e){var x=0,w=A.o(y.u),v,u=this,t,s,r,q,p,o,n
var $async$z8=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:p=A.a([],y.s)
for(t=e.length,s=0;s<e.length;e.length===t||(0,A.M)(e),++s){r=C.m.S(e[s])
if(r.length===0||C.l.p(p,r))continue
p.push(r)
if(p.length===3)break}t=A.A(y.N,y.z)
t.m(0,"venueId",d)
t.m(0,"itemIds",p)
t.L(0,u.we())
o=J
n=y.j
x=3
return A.h(A.ex().$2$payload("set_menu_item_highlights",t),$async$z8)
case 3:t=o.en(n.a(g),new B.aBu(),y.g)
q=A.Y(t,t.$ti.h("am.E"))
x=4
return A.h(u.wk(d,q),$async$z8)
case 4:v=q
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$z8,w)},
BX(d){return this.aOk(d)},
aOk(d){var x=0,w=A.o(y.H),v=this,u
var $async$BX=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:u=A.A(y.N,y.z)
u.m(0,"itemId",d)
u.L(0,v.we())
x=2
return A.h(A.ex().$2$payload("delete_menu_item",u),$async$BX)
case 2:x=3
return A.h(v.wp(d),$async$BX)
case 3:return A.m(null,w)}})
return A.n($async$BX,w)},
Xc(d,e){return $.bAd().Ed(e,d,!1,null)},
Xb(d){return this.Xc(d,!1)},
z9(d,e){return this.aiH(d,e)},
aiH(d,e){var x=0,w=A.o(y.H),v=this,u,t
var $async$z9=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:u=y.N
t=A.A(u,y.z)
t.m(0,"itemId",d)
t.m(0,"updates",A.a_(["image_locked",e],u,y.y))
t.L(0,v.we())
x=2
return A.h(A.ex().$3$payload$useAdminSession("update_menu_item",t,!1),$async$z9)
case 2:x=3
return A.h(v.wI(d,new B.aBv(e)),$async$z9)
case 3:return A.m(null,w)}})
return A.n($async$z9,w)},
EH(d){return this.ahT(d)},
ahT(a1){var x=0,w=A.o(y.a),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0
var $async$EH=A.k(function(a2,a3){if(a2===1){t.push(a3)
x=u}for(;;)switch(x){case 0:u=4
m=$.iP().b
m===$&&A.b()
l=y.N
k=y.z
j=A.a_(["p_venue_id",a1],l,k)
i=m.ay
i===$&&A.b()
h=i.b
g=A.eP(h,l,l)
g.L(0,m.x)
h.L(0,g)
g=A.eP(i.b,l,l)
h=A.cx(i.a+"/rpc/get_venue_item_popularity",0,null)
m=A.bti(null,null,null,g,i.d,i.e,!1,null,i.c,h,k,k,k)
a0=y.j
x=7
return A.h(new A.a2D(m.a,m.b,!1,m.d,m.e,m.f,m.r,m.w,m.x,m.y,A.jt("supabase.postgrest")).aWA(j,!1,k),$async$EH)
case 7:s=a0.a(a3)
r=A.A(l,y.S)
for(m=J.bc(s),l=y.P;m.t();){q=m.gN()
p=l.a(q)
o=A.a5(J.ch(p,"menu_item_id"))
k=A.fx(J.ch(p,"total_ordered"))
f=k==null?null:C.q.cu(k)
n=f==null?0:f
if(o!=null&&n>0)J.kk(r,o,n)}v=r
x=1
break
u=2
x=6
break
case 4:u=3
d=t.pop()
v=D.L4
x=1
break
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$EH,w)},
Hg(d){return this.aEK(d)},
aEK(d){var x=0,w=A.o(y.H),v=1,u=[],t=this,s,r
var $async$Hg=A.k(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.h(t.Xb(d),$async$Hg)
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
return A.n($async$Hg,w)},
wk(d,e){return this.aEc(d,e)},
aEc(d,e){var x=0,w=A.o(y.H),v,u
var $async$wk=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jz(),$async$wk)
case 2:v=g
u=A.a0(e).h("a3<1,av<f,@>>")
u=A.Y(new A.a3(e,new B.aBk(),u),u.h("am.E"))
x=3
return A.h(v.qg("String","dinein.local_menu."+d,C.aH.kA(u,null)),$async$wk)
case 3:return A.m(null,w)}})
return A.n($async$wk,w)},
zG(d){return this.arv(d)},
arv(d){var x=0,w=A.o(y.H)
var $async$zG=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=3
return A.h(A.jz(),$async$zG)
case 3:x=2
return A.h(f.K(0,"dinein.local_menu."+d),$async$zG)
case 2:return A.m(null,w)}})
return A.n($async$zG,w)},
wf(d,e){return this.aBA(d,e)},
aBA(d,e){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o
var $async$wf=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jz(),$async$wf)
case 2:p=g
o=A.A(y.N,y.g)
for(u="dinein.local_menu."+d,t=v.Hh(p,u),s=t.length,r=0;r<t.length;t.length===s||(0,A.M)(t),++r){q=t[r]
o.m(0,q.a,q)}for(r=0;r<1;++r){q=e[r]
o.m(0,q.a,q)}t=o.$ti.h("bt<2>")
t=A.nw(new A.bt(o,t),new B.aBj(),t.h("H.E"),y.P)
o=A.Y(t,A.r(t).h("H.E"))
x=3
return A.h(p.qg("String",u,C.aH.kA(o,null)),$async$wf)
case 3:return A.m(null,w)}})
return A.n($async$wf,w)},
wI(d,e){return this.aJe(d,e)},
aJe(d,e){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o,n
var $async$wI=A.k(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jz(),$async$wI)
case 2:n=g
u=A.p_(n.a.gcm(),y.N),t=u.ga7(0),u=new A.f3(t,new B.aBp(),A.r(u).h("f3<1>"))
case 3:if(!u.t()){x=4
break}s=t.gN()
r={}
q=v.Hh(n,s)
r.a=!1
p=A.a0(q).h("a3<1,bu>")
o=A.Y(new A.a3(q,new B.aBq(r,d,e),p),p.h("am.E"))
if(!r.a){x=3
break}p=A.a0(o).h("a3<1,av<f,@>>")
p=A.Y(new A.a3(o,new B.aBr(),p),p.h("am.E"))
x=5
return A.h(n.qg("String",s,C.aH.kA(p,null)),$async$wI)
case 5:x=3
break
case 4:return A.m(null,w)}})
return A.n($async$wI,w)},
wp(d){return this.aF4(d)},
aF4(d){var x=0,w=A.o(y.H),v=this,u,t,s,r,q,p,o,n
var $async$wp=A.k(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:x=2
return A.h(A.jz(),$async$wp)
case 2:n=f
u=n.a,t=A.p_(u.gcm(),y.N),s=t.ga7(0),t=new A.f3(s,new B.aBm(),A.r(t).h("f3<1>"))
case 3:if(!t.t()){x=4
break}r=s.gN()
q=v.Hh(n,r)
p=A.a0(q).h("aq<1>")
p=A.Y(new A.aq(q,new B.aBn(d),p),p.h("H.E"))
p.$flags=1
o=p
p=o.length
if(p===q.length){x=3
break}x=p===0?5:6
break
case 5:u.K(0,r)
x=7
return A.h($.ajT().K(0,"flutter."+r),$async$wp)
case 7:x=3
break
case 6:p=A.a0(o).h("a3<1,av<f,@>>")
p=A.Y(new A.a3(o,new B.aBo(),p),p.h("am.E"))
x=8
return A.h(n.qg("String",r,C.aH.kA(p,null)),$async$wp)
case 8:x=3
break
case 4:return A.m(null,w)}})
return A.n($async$wp,w)},
Hh(d,e){var x,w=A.a5(d.a.i(0,e))
if(w==null||w.length===0)return D.tR
x=J.en(y.j.a(C.aH.ky(w,null)),new B.aBl(),y.g)
x=A.Y(x,x.$ti.h("am.E"))
return x}}
var z=a.updateTypes(["av<f,@>(bu)","bu(@)","bu(bu)","y(bu)","y(nz)","nz()"])
B.aBd.prototype={
$1(d){return d.b===this.a},
$S:z+4}
B.aBe.prototype={
$0(){return D.kB},
$S:z+5}
B.aBg.prototype={
$1(d){return B.bQ9(d)},
$S:13}
B.aBh.prototype={
$1(d){return B.bQb(d)},
$S:13}
B.aBf.prototype={
$1(d){return d.toLowerCase()===this.a.toLowerCase()},
$S:13}
B.aBs.prototype={
$1(d){return B.Dy(d)},
$S:z+1}
B.aBt.prototype={
$1(d){return d.w},
$S:z+3}
B.aBw.prototype={
$1(d){return d.aMy(this.a)},
$S:z+2}
B.aBu.prototype={
$1(d){return B.Dy(y.P.a(d))},
$S:z+1}
B.aBv.prototype={
$1(d){return d.aMw(this.a)},
$S:z+2}
B.aBk.prototype={
$1(d){return d.ci()},
$S:z+0}
B.aBj.prototype={
$1(d){return d.ci()},
$S:z+0}
B.aBp.prototype={
$1(d){return C.m.aS(d,"dinein.local_menu.")},
$S:13}
B.aBq.prototype={
$1(d){if(d.a!==this.b)return d
this.a.a=!0
return this.c.$1(d)},
$S:z+2}
B.aBr.prototype={
$1(d){return d.ci()},
$S:z+0}
B.aBm.prototype={
$1(d){return C.m.aS(d,"dinein.local_menu.")},
$S:13}
B.aBn.prototype={
$1(d){return d.a!==this.a},
$S:z+3}
B.aBo.prototype={
$1(d){return d.ci()},
$S:z+0}
B.aBl.prototype={
$1(d){return B.Dy(y.P.a(d))},
$S:z+1};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.iK,[B.nz,B.kA,B.M3])
x(A.cp,[B.aBd,B.aBg,B.aBh,B.aBf,B.aBs,B.aBt,B.aBw,B.aBu,B.aBv,B.aBk,B.aBj,B.aBp,B.aBq,B.aBr,B.aBm,B.aBn,B.aBo,B.aBl])
w(B.aBe,A.cI)
w(B.bu,A.xF)
x(A.w,[B.a1l,B.aBa,B.aBi])})()
var y=(function rtii(){var x=A.B
return{m:x("x<bu>"),s:x("x<f>"),u:x("D<bu>"),j:x("D<@>"),P:x("av<f,@>"),a:x("av<f,u>"),o:x("a1l"),g:x("bu"),N:x("f"),y:x("y"),z:x("@"),S:x("u"),L:x("D<@>?"),R:x("bu?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.tR=x([],y.m)
D.La=new B.kA(0,"food")
D.Lb=new B.kA(1,"drinks")
D.kB=new B.nz(0,"pending")
D.oq=new B.nz(1,"generating")
D.it=new B.nz(2,"ready")
D.Lc=new B.nz(3,"failed")
D.aOs=x([D.kB,D.oq,D.it,D.Lc],A.B("x<nz>"))
D.L4=new A.bT(C.cJ,[],A.B("bT<f,u>"))
D.uq=new B.M3(0,"unknown")
D.f0=new B.M3(1,"manual")
D.aSf=new B.M3(2,"aiGemini")})();(function lazyInitializers(){var x=a.lazyFinal
x($,"bXM","bAd",()=>new B.aBa())
x($,"bXO","od",()=>new B.aBi())})()};
(a=>{a["UbKjjPcD0J93KOSvv98bGZNtKnQ="]=a.current})($__dart_deferred_initializers__);