import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', 'C2_');
  return { plugins: [react()], server: { proxy: {
    '/api': env.C2_GATEWAY_URL || 'http://127.0.0.1:8080',
    '/exams': env.C2_USER_URL || 'http://127.0.0.1:5039'
  } } };
});
