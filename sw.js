const C="sanad-cache-v31",A=["./","./index.html","./admin.html","./donate.html","./admin/index.html","./style.css","./app.js","./i18n.js?v=28","./manifest.webmanifest","./manifest-admin.webmanifest","./icons/icon.svg","./icons/admin-app.svg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(A)));self.skipWaiting()});
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x))))));

self.addEventListener("push",event=>{
 let data={};
 try{data=event.data?event.data.json():{};}catch{data={body:event.data?.text()||"لديك تنبيه جديد في سند."};}
 const title=data.title||"تنبيه من سند";
 const options={
  body:data.body||"لديك تحديث جديد في منصة سند.",
  icon:"/icons/admin-app.svg",
  badge:"/icons/admin-app.svg",
  tag:data.tag||"sanad-notification",
  data:{url:data.url||"/admin"}
 };
 event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener("notificationclick",event=>{
 event.notification.close();
 event.waitUntil((async()=>{
  let target=new URL(event.notification.data?.url||"/admin",self.location.origin);
  if(target.origin!==self.location.origin)target=new URL("/admin",self.location.origin);
  const windows=await self.clients.matchAll({type:"window",includeUncontrolled:true});
  for(const client of windows){
   if(client.url.startsWith(self.location.origin)){
    await client.navigate(target.href);
    return client.focus();
   }
  }
  return self.clients.openWindow(target.href);
 })());
});
self.addEventListener("fetch",e=>{
 if(e.request.method!=="GET")return;
 const u=new URL(e.request.url);
 if(u.origin===self.location.origin && (u.pathname==="/admin"||u.pathname==="/admin/")){
  e.respondWith(fetch(new Request(new URL("/admin.html"+u.search+u.hash,self.location.origin),{method:"GET",credentials:"same-origin",cache:"no-store"})));
  return;
 }
 if(e.request.mode==="navigate"){
  e.respondWith(fetch(e.request).then(n=>{
   if(n.ok){const copy=n.clone();caches.open(C).then(c=>c.put(e.request,copy));}
   return n;
  }).catch(()=>caches.match(e.request).then(r=>r||caches.match("./index.html"))));
  return;
 }
 e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(n=>{
  if(n.ok){const copy=n.clone();caches.open(C).then(c=>c.put(e.request,copy));}
  return n;
 })));
});