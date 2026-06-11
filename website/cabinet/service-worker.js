const CACHE='numino-cabinet-v1';
const PRECACHE=['.','manifest.json','icons/Icon-192.png','icons/Icon-512.png','icons/Icon-maskable-192.png','icons/Icon-maskable-512.png','https://unpkg.com/leaflet@1.9.4/dist/leaflet.css','https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'];

self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(PRECACHE)));self.skipWaiting();});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==CACHE).map(x=>caches.delete(x)))));self.clients.claim();});
self.addEventListener('fetch',e=>{const r=e.request,u=new URL(r.url);if(r.method!=='GET')return;
if(u.origin===location.origin||u.hostname.endsWith('unpkg.com')){e.respondWith(caches.match(r).then(c=>c||fetch(r).then(res=>{if(u.hostname.endsWith('unpkg.com')&&res.ok){const cl=res.clone();caches.open(CACHE).then(ca=>ca.put(r,cl));}return res;})));return;}
e.respondWith(fetch(r).catch(()=>caches.match(r).then(c=>!c&&r.mode==='navigate'?caches.match('.'):c)));});
