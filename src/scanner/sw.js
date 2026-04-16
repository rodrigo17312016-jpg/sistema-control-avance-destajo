const CACHE_NAME = 'escaner-avance-v2';

const URLS_TO_CACHE = [
    'index.html',
    'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
    'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js'
];

// Instalacion: cachear recursos esenciales
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            return cache.addAll(URLS_TO_CACHE);
        })
    );
    self.skipWaiting();
});

// Activacion: limpiar caches antiguos
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames
                    .filter((name) => name !== CACHE_NAME)
                    .map((name) => caches.delete(name))
            );
        })
    );
    self.clients.claim();
});

// Fetch: NETWORK-FIRST (intenta red primero, cache como fallback offline)
self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET') return;
    if (event.request.url.includes('supabase.co/rest') || event.request.url.includes('supabase.co/auth')) return;

    event.respondWith(
        fetch(event.request).then((networkResponse) => {
            // Si la red responde, actualizar cache y devolver
            if (networkResponse && networkResponse.status === 200) {
                const responseClone = networkResponse.clone();
                caches.open(CACHE_NAME).then((cache) => {
                    cache.put(event.request, responseClone);
                });
            }
            return networkResponse;
        }).catch(() => {
            // Sin internet: usar cache
            return caches.match(event.request).then((cachedResponse) => {
                if (cachedResponse) return cachedResponse;
                if (event.request.mode === 'navigate') {
                    return caches.match('index.html');
                }
            });
        })
    );
});
