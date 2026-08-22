const CACHE = 'mecha-overdrive-cz-v1.2.0';
const CORE = [
  './', './index.html', './styles.css', './manifest.webmanifest', './media/icon.svg',
  './media/openai/mecha-overdrive-hero.png', './js/core.js', './js/data.js', './js/storage.js',
  './js/audio.js', './js/input.js', './js/track.js', './js/renderer.js', './js/game.js',
  './js/ui.js', './js/main.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const isGodot3D = url.pathname === '/godot3d' || url.pathname.startsWith('/godot3d/');
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || isGodot3D) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(async () => {
      // Vercel cleanUrls redirects /index.html to /. A redirected cached
      // response cannot safely satisfy an offline navigation, so use the
      // canonical root document installed in CORE as the app-shell fallback.
      const root = await caches.match('./');
      return root || caches.match('./index.html');
    }));
    return;
  }
  event.respondWith(caches.match(event.request).then((cached) => cached || fetch(event.request).then((response) => {
    if (response.ok && response.type === 'basic') {
      const copy = response.clone();
      event.waitUntil(caches.open(CACHE).then((cache) => cache.put(event.request, copy)));
    }
    return response;
  })));
});
