import './globals.css';
import NavMenu from './NavMenu';

export const metadata = { title: 'Lakol — gestion d\'école', description: 'Gestion d\'école privée pour le Niger et l\'Afrique' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
      </head>
      <body>
        <div className="lk-shell">
          <NavMenu />
          <main className="lk-main">{children}</main>
        </div>
      </body>
    </html>
  );
}
