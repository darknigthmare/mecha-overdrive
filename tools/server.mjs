import { createReadStream, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import process from 'node:process';

const ROOT = resolve(fileURLToPath(new URL('..', import.meta.url)));
const numericArgument = process.argv.slice(2).find((argument) => /^\d+$/.test(argument));
const requestedPort = Number.parseInt(process.env.PORT || numericArgument || '8080', 10);
const BASE_PORT = Number.isInteger(requestedPort) && requestedPort > 0 && requestedPort < 65_536
  ? requestedPort
  : 8080;
const HOST = process.env.HOST || '127.0.0.1';
const SHOULD_OPEN = process.argv.includes('--open');
const MAX_PORT_ATTEMPTS = 100;
let activePort = BASE_PORT;
let attempts = 0;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.md': 'text/markdown; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
};

function safePath(urlPath) {
  try {
    const raw = decodeURIComponent((urlPath || '/').split('?')[0]);
    const relative = normalize(raw === '/' ? 'index.html' : raw.replace(/^[/\\]+/, ''));
    const absolute = resolve(join(ROOT, relative));
    return absolute === ROOT || absolute.startsWith(`${ROOT}${sep}`) ? absolute : null;
  } catch {
    return null;
  }
}

function openBrowser(url) {
  let command;
  let argumentsList;
  if (process.platform === 'win32') {
    command = 'cmd';
    argumentsList = ['/c', 'start', '', url];
  } else if (process.platform === 'darwin') {
    command = 'open';
    argumentsList = [url];
  } else {
    command = 'xdg-open';
    argumentsList = [url];
  }

  try {
    const child = spawn(command, argumentsList, { detached: true, stdio: 'ignore' });
    child.unref();
  } catch {
    // L’adresse reste affichée si aucun ouvre-URL système n’est disponible.
  }
}

const server = createServer((request, response) => {
  const path = safePath(request.url);
  if (!path) {
    response.writeHead(403, {
      'Content-Type': 'text/plain; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end('Accès interdit.');
    return;
  }

  try {
    const information = statSync(path);
    if (!information.isFile()) throw new Error('Not a file');

    response.writeHead(200, {
      'Content-Type': MIME[extname(path).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
      'Cross-Origin-Opener-Policy': 'same-origin',
    });

    if (request.method === 'HEAD') response.end();
    else createReadStream(path).pipe(response);
  } catch {
    response.writeHead(404, {
      'Content-Type': 'text/plain; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end('Fichier introuvable.');
  }
});

function listen() {
  server.listen(activePort, HOST);
}

server.on('listening', () => {
  const url = `http://${HOST}:${activePort}/index.html`;
  console.log('\nMECHA OVERDRIVE — Circuit Zero');
  console.log(`Serveur actif : ${url}`);
  if (activePort !== BASE_PORT) console.log(`Le port ${BASE_PORT} était occupé ; utilisation du port ${activePort}.`);
  console.log('Utilisez Ctrl+C pour arrêter.\n');
  if (SHOULD_OPEN) setTimeout(() => openBrowser(url), 350);
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE' && attempts < MAX_PORT_ATTEMPTS) {
    attempts += 1;
    activePort = BASE_PORT + attempts;
    setTimeout(listen, 10);
    return;
  }
  console.error(`Impossible de démarrer le serveur : ${error.message}`);
  process.exitCode = 1;
});

listen();
