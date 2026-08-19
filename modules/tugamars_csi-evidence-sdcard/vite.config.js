import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  build: {
    lib: {
      entry: './web/Main.svelte',
      name: 'TugamarsCsiEvidenceSdcard',
      fileName: () => 'main.js',
      formats: ['es']
    },
    outDir: './web/dist',
    emptyOutDir: true
  }
});
