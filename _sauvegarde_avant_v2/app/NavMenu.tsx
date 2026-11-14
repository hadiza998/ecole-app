'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '../lib/supabase';

const MENUS: Record<string, [string, string][]> = {
  admin: [['/dashboard', 'Tableau de bord'], ['/professeurs', 'Professeurs'], ['/classes', 'Classes'], ['/eleves', 'Élèves'], ['/planning', 'Planning'], ['/notes', 'Notes'], ['/bulletin', 'Bulletins'], ['/paiements', 'Scolarité']],
  teacher: [['/classes', 'Mes classes'], ['/eleves', 'Élèves'], ['/notes', 'Notes'], ['/planning', 'Planning']],
  parent: [['/parent', 'Mon enfant'], ['/planning', 'Planning']],
};
const LABEL: Record<string, string> = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

export default function NavMenu() {
  const path = usePathname();
  const [role, setRole] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    async function load() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { if (alive) setRole(null); return; }
      const { data: p } = await supabase.from('profiles').select('role, active').eq('id', data.session.user.id).maybeSingle();
      if (alive) setRole(p && p.active !== false ? p.role : null);
    }
    load();
    const { data: sub } = supabase.auth.onAuthStateChange(() => load());
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, []);

  if (path === '/login' || !role) {
    return <div className="lk-nav"><span className="lk-brand">Lakol</span></div>;
  }
  return (
    <div className="lk-nav">
      <Link href="/" className="lk-brand">Lakol</Link>
      <div className="lk-links">
        {(MENUS[role] || []).map(([href, label]) => (
          <Link key={href} href={href} className={path === href || path.startsWith(href + '/') ? 'on' : ''}>{label}</Link>
        ))}
      </div>
      <span className="lk-role">{LABEL[role]}</span>
      <button className="nav-logout" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>Déconnexion</button>
    </div>
  );
}
