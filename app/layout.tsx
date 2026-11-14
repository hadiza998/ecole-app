import { Suspense } from 'react';
import type { Viewport } from 'next';
import './globals.css';
import NavMenu from './NavMenu';

export const metadata = { title: "Lakol — gestion d'école", description: "Gestion d'école privée" };

export const viewport: Viewport = { width: 'device-width', initialScale: 1, viewportFit: 'cover', themeColor: '#3B2BA8' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
      </head>
      <body>
        <div className="lk-shell">
          <Suspense fallback={null}><NavMenu /></Suspense>
          <main className="lk-main"><Suspense fallback={<div className="lk-page"><p className="meta">Chargement…</p></div>}>{children}</Suspense></main>
        </div>
      </body>
    </html>
  );
}
