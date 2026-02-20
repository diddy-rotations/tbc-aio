import { defineConfig } from 'astro/config';

export default defineConfig({
  output: 'static',
  site: 'https://flux-aio.github.io',
  base: '/tbc',
  build: {
    inlineStylesheets: 'always',
  },
});
