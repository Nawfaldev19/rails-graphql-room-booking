import react from '@vitejs/plugin-react-swc';
import { defineConfig } from 'vite';

// The web app is built into the Rails app's public folder, so that one server
// serves both the API and the pages. In development Vite serves the pages and
// forwards API calls to Rails.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'src/api/public', emptyOutDir: true, sourcemap: true },
  server: {
    port: 5174,
    proxy: { '/graphql': 'http://localhost:3400' },
  },
});
