/**
 * Servidor de desarrollo local
 * Sirve los archivos estaticos de /src en localhost:3000
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || process.env.APP_PORT || 3000;
const SRC_DIR = path.join(__dirname, '..', 'src');

const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.webmanifest': 'application/manifest+json',
};

const server = http.createServer((req, res) => {
    let urlPath = req.url.split('?')[0];
    if (urlPath === '/') urlPath = '/index.html';

    const filePath = path.join(SRC_DIR, urlPath);
    const ext = path.extname(filePath).toLowerCase();

    // Security: prevent directory traversal
    if (!filePath.startsWith(SRC_DIR)) {
        res.writeHead(403);
        res.end('Forbidden');
        return;
    }

    fs.readFile(filePath, (err, data) => {
        if (err) {
            if (err.code === 'ENOENT') {
                res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
                res.end('<h1>404 - Archivo no encontrado</h1><p><a href="/">Volver al inicio</a></p>');
            } else {
                res.writeHead(500);
                res.end('Error interno del servidor');
            }
            return;
        }

        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        res.writeHead(200, {
            'Content-Type': contentType,
            'Cache-Control': 'no-cache',
            'Access-Control-Allow-Origin': '*',
        });
        res.end(data);
    });
});

server.listen(PORT, () => {
    console.log('');
    console.log('  ╔══════════════════════════════════════════════════════╗');
    console.log('  ║   SISTEMA DE CONTROL DE AVANCE POR DESTAJO         ║');
    console.log('  ║   Frutas Tropicales Piura                          ║');
    console.log('  ╠══════════════════════════════════════════════════════╣');
    console.log(`  ║   Servidor: http://localhost:${PORT}                   ║`);
    console.log('  ║                                                      ║');
    console.log(`  ║   Panel Principal:  http://localhost:${PORT}            ║`);
    console.log(`  ║   Generador QR:     http://localhost:${PORT}/qr-generator/ ║`);
    console.log(`  ║   Escaner:          http://localhost:${PORT}/scanner/   ║`);
    console.log(`  ║   Dashboard TV:     http://localhost:${PORT}/dashboard/ ║`);
    console.log('  ║                                                      ║');
    console.log('  ║   Presiona Ctrl+C para detener                      ║');
    console.log('  ╚══════════════════════════════════════════════════════╝');
    console.log('');
});
