import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const PORT = 8765;
const WEB_DIR = path.join(import.meta.dirname, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const server = http.createServer((req, res) => {
  req.on('error', () => {});
  res.on('error', () => {});

  let reqPath = decodeURI(req.url.split('?')[0]);
  if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
  
  let filePath = path.join(WEB_DIR, reqPath);

  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end('Acceso denegado');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || stats.isDirectory()) {
      filePath = path.join(WEB_DIR, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    // index.html nunca se cachea para que F5 / Ctrl+F5 siempre recargue limpio
    const isHtml = (ext === '.html' || ext === '');
    const isImmutable = ['.wasm', '.png', '.jpg', '.ttf', '.woff', '.woff2'].includes(ext);
    
    let cacheControl;
    if (isHtml) {
      cacheControl = 'no-store, no-cache, must-revalidate, max-age=0';
    } else if (isImmutable) {
      cacheControl = 'public, max-age=86400, stale-while-revalidate=3600';
    } else {
      cacheControl = 'no-cache';
    }

    fs.stat(filePath, (statErr, finalStats) => {
      if (statErr) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Archivo no encontrado');
        return;
      }

      res.writeHead(200, {
        'Content-Type': contentType,
        'Content-Length': finalStats.size,
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': cacheControl,
      });

      if (req.method === 'HEAD') {
        res.end();
        return;
      }

      const stream = fs.createReadStream(filePath);
      stream.on('error', () => {
        if (!res.headersSent) res.writeHead(500);
        res.end();
      });
      stream.pipe(res);
    });
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Servidor de Aula Puntos SENATI corriendo en http://localhost:${PORT}`);
});
