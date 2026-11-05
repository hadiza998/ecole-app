"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/", label: "Élèves" },
  { href: "/notes", label: "Notes" },
  { href: "/bulletin", label: "Bulletins" },
  { href: "/paiements", label: "Paiements" },
];

export default function Nav() {
  const pathname = usePathname();
  return (
    <nav className="nav">
      {links.map((l) => (
        <Link
          key={l.href}
          href={l.href}
          className={pathname === l.href ? "active" : ""}
        >
          {l.label}
        </Link>
      ))}
    </nav>
  );
}