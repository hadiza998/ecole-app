'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '../lib/supabase';

type Item = [string, string, string];
const MENUS: Record<string, Item[]> = {
  admin: [
    ['/dashboard', 'Tableau de bord', 'grid'], ['/classes', 'Classes', 'book'], ['/eleves', 'Élèves', 'user'],
    ['/professeurs', 'Professeurs', 'users'], ['/planning', 'Planning', 'calendar'], ['/notes', 'Notes', 'edit'],
    ['/bulletin', 'Bulletins', 'file'], ['/paiements', 'Scolarité', 'card'],
  ],
  teacher: [['/classes', 'Mes classes', 'book'], ['/eleves', 'Élèves', 'user'], ['/notes', 'Notes', 'edit'], ['/planning', 'Planning', 'calendar']],
  parent: [['/parent', 'Mon enfant', 'user'], ['/planning', 'Planning', 'calendar']],
};
const LABEL: Record<string, string> = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

function Icon({ name }: { name: string }) {
  const p: Record<string, React.ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" /><rect x="3" y="14" width="7" height="7" rx="1.5" /></>,
    users: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></>,
    book: <><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" /><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" /></>,
    user: <><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" /></>,
    calendar: <><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></>,
    edit: <><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" /></>,
    file: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6M16 13H8M16 17H8" /></>,
    card: <><rect x="1" y="4" width="22" height="16" rx="2" /><path d="M1 10h22" /></>,
  };
  return <svg viewBox="0 0 24 24">{p[name]}</svg>;
}

export default function NavMenu() {
  const path = usePathname();
  const [me, setMe] = useState<{ role: string; name: string } | null>(null);

  useEffect(() => {
    let alive = true;
    async function load() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { if (alive) setMe(null); return; }
      const { data: p } = await supabase.from('profiles').select('role, active, full_name').eq('id', data.session.user.id).maybeSingle();
      if (alive) setMe(p && p.active !== false ? { role: p.role, name: p.full_name } : null);
    }
    load();
    const { data: sub } = supabase.auth.onAuthStateChange(() => load());
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, []);

  if (path === '/login' || !me) return null;
  const initials = me.name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
  return (
    <aside className="lk-side no-print">
      <Link href="/" className="lk-brand"><span className="lk-logo" />Lakol</Link>
      <div className="lk-navlabel">Menu</div>
      <nav className="lk-links">
        {(MENUS[me.role] || []).map(([href, label, icon]) => (
          <Link key={href} href={href} className={path === href || path.startsWith(href + '/') ? 'on' : ''}>
            <Icon name={icon} />{label}
          </Link>
        ))}
      </nav>
      <div className="lk-user">
        <span className="avatar">{initials}</span>
        <div className="who"><b>{me.name}</b><span>{LABEL[me.role]}</span></div>
        <button className="nav-logout" title="Déconnexion" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>
          <svg viewBox="0 0 24 24"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" /></svg>
        </button>
      </div>
    </aside>
  );
}
