import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'prompt',
      injectRegister: false,
      filename: 'sw.js',
      manifestFilename: 'manifest.webmanifest',
      includeAssets: [
        'assets/app-icon-180.png',
        'assets/app-icon-192.png',
        'assets/app-icon-512.png',
        'assets/app-icon-1024.png',
        'assets/recipe-category-icons.png',
        'assets/product-category-icons.png'
      ],
      manifest: {
        id: '/',
        name: 'Astra Nutrition OS',
        short_name: 'Astra',
        description: 'Персональный дневник питания, рецептов, прогресса и тренировок',
        lang: 'ru',
        start_url: '/#dashboard',
        scope: '/',
        display: 'standalone',
        display_override: ['standalone', 'minimal-ui', 'browser'],
        background_color: '#f7f8fa',
        theme_color: '#0b1248',
        orientation: 'any',
        categories: ['health', 'fitness', 'food'],
        prefer_related_applications: false,
        icons: [
          {
            src: '/assets/app-icon-192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any'
          },
          {
            src: '/assets/app-icon-512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any maskable'
          }
        ],
        shortcuts: [
          {
            name: 'Дневник питания',
            short_name: 'Дневник',
            url: '/#diary',
            icons: [{ src: '/assets/app-icon-192.png', sizes: '192x192', type: 'image/png' }]
          },
          {
            name: 'Рецепты',
            short_name: 'Рецепты',
            url: '/#recipes',
            icons: [{ src: '/assets/app-icon-192.png', sizes: '192x192', type: 'image/png' }]
          },
          {
            name: 'Прогресс',
            short_name: 'Прогресс',
            url: '/#progress',
            icons: [{ src: '/assets/app-icon-192.png', sizes: '192x192', type: 'image/png' }]
          }
        ]
      },
      workbox: {
        cleanupOutdatedCaches: true,
        navigateFallback: '/index.html',
        navigateFallbackDenylist: [/^\/api\//],
        globPatterns: ['**/*.{js,css,html}']
      }
    })
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:8787'
    }
  }
});
