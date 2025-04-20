// my_service_worker.js
const CACHE_NAME = 'my-pwa-cache-v10'; // Incrementamos la versión de la caché
const urlsToCache = [
  '/',
  '/index.html',
  '/main.dart.js',
  // Añade aquí los demás assets esenciales
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  '/manifest.json',
  '/favicon.png',
  // ... (añade aquí los demás assets esenciales)
];

self.addEventListener('install', (event) => {
  console.log('Service Worker installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Opened cache');
        return cache.addAll(urlsToCache);
      })
      .catch((error) => {
        console.error('Error adding to cache:', error);
      })
  );
});

self.addEventListener('activate', (event) => {
  console.log('Service Worker activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      // Fuerza al Service Worker a tomar el control de todas las páginas
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', (event) => {
  console.log('Fetch event:', event.request.url, event.request.method); // Añadido
  // Intercept POST requests to /share
  if (event.request.method === 'POST' && event.request.url.endsWith('/share')) {
    console.log('POST request intercepted:', event.request.url); // Añadido
    event.respondWith(fetch(event.request).then(response => {
      // Enviar un mensaje a la página web
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({
            type: 'sharedFiles',
            data: {
              success: true,
              files: {
                audio_normalized: 'audio_normalized',
                text_ref_txt: 'text_ref_txt',
                transcription_json: 'transcription_json',
              },
            },
          });
        });
      });
      return response;
    }));
  } else {
    // Handle other requests as usual
    event.respondWith(
      caches.match(event.request)
        .then((response) => {
          if (response) {
            console.log('Found in cache:', event.request.url);
            return response;
          }
          console.log('Not found in cache, fetching from network:', event.request.url);
          return fetch(event.request)
            .then((networkResponse) => {
              // Si la petición es exitosa, la añadimos a la caché
              if (networkResponse.ok) {
                return caches.open(CACHE_NAME).then((cache) => {
                  return cache.put(event.request, networkResponse.clone()).then(() => {
                    return networkResponse;
                  });
                });
              }
              return networkResponse;
            })
            .catch((error) => {
              console.error('Error fetching from network:', error);
              // Aquí puedes devolver una respuesta de error personalizada
              return new Response('<h1>Error</h1>', {
                headers: { 'Content-Type': 'text/html' },
              });
            });
        })
    );
  }
});

self.addEventListener('message', (event) => {
  console.log('-------- Service Worker received a message:', event.data);

  // Check if the message has the data you're expecting
  if (event.data && event.data.type === 'navigation') {
    const path = event.data.path;
    console.log('Navigating to:', path);

    // You can't directly navigate from the Service Worker.
    // You need to send a message back to the client (Flutter app)
    // to handle the navigation.
    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({ type: 'navigate', path: path });
      });
    });
  }
});