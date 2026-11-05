import type { Metadata } from "next";
import Link from "next/link";
import Nav from "./NavMenu";
import "./globals.css";

export const metadata: Metadata = {
  title: "Lakol : gestion scolaire",
  description: "Notes, bulletins et paiements pour les écoles du Niger",
};

function Logo() {
  return (
    <svg width="38" height="38" viewBox="0 0 38 38" aria-hidden="true">
      <defs>
        <linearGradient id="lg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#E05206" />
          <stop offset="1" stopColor="#0DB02B" />
        </linearGradient>
      </defs>
      <rect width="38" height="38" rx="11" fill="url(#lg)" />
      <path d="M19 9 L32 15.5 L19 22 L6 15.5 Z" fill="#fff" />
      <path
        d="M11 19.5 V25 C11 27 14.6 29 19 29 C23.4 29 27 27 27 25 V19.5 L19 23.5 Z"
        fill="#fff"
        fillOpacity=".85"
      />
      <line x1="31" y1="16.5" x2="31" y2="24" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body suppressHydrationWarning>
        <div className="flagbar" />
        <header className="site-header">
          <div className="header-inner">
            <Link href="/" className="brand">
              <Logo />
              <span>
                <span className="name">Lakol</span>
                <small>Gestion scolaire · Niger</small>
              </span>
            </Link>
            <Nav />
          </div>
        </header>
        {children}
        <footer className="site-footer">Lakol · Conçu pour les écoles du Niger</footer>
      </body>
    </html>
  );
}