import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const animationsDir = path.resolve(__dirname, '../content-animations');

const mimeTypes: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.glb': 'model/gltf-binary',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
};

function serveContentAnimations(): Plugin {
  const middleware = (req: any, res: any, next: () => void) => {
    const rawUrl: string = req.url || '';
    if (!rawUrl.startsWith('/c2-3d/')) return next();
    const cleanPath = decodeURIComponent(rawUrl.slice('/c2-3d/'.length).split('?')[0]);
    const filePath = path.resolve(animationsDir, cleanPath);
    if (!filePath.startsWith(animationsDir) || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      return next();
    }
    const ext = path.extname(filePath).toLowerCase();
    res.setHeader('Content-Type', mimeTypes[ext] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-store, max-age=0');
    fs.createReadStream(filePath).pipe(res);
  };
  return {
    name: 'serve-c2-3d-animations',
    configureServer(server) {
      server.middlewares.use(middleware);
    },
    configurePreviewServer(server) {
      server.middlewares.use(middleware);
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', 'C2_');
  return {
    plugins: [react(), serveContentAnimations()],
    server: {
      proxy: {
        '/api': env.C2_GATEWAY_URL || 'http://127.0.0.1:8080',
        '/exams': env.C2_USER_URL || 'http://127.0.0.1:5039',
      },
    },
  };
});
