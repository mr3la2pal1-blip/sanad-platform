const C="sanad-cache-v2",A=["./","./index.html","./admin.html","./admin/index.html","./style.css","./app.js","./manifest.webmanifest","./icons/icon.svg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(A)));self.skipWaiting()});
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x))))));
self.addEventListener("fetch",e=>{
 if(e.request.method!=="GET")return;
 const u=new URL(e.request.url);
 if(u.origin===self.location.origin && /^\/admin\/?$/.test(u.pathname)){
  e.respondWith(Response.redirect(new URL("/admin.html"+u.search+u.hash,self.location.origin),302));
  return;
 }
 e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(n=>{if(n.ok){const copy=n.clone();caches.open(C).then(c=>c.put(e.request,copy));}return n;}).catch(()=>caches.match("./index.html"))));
});