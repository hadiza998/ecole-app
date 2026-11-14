'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '../lib/supabase';
import Logo, { Wordmark } from './components/Logo';
import Icon from './components/Icon';

type Item = [string, string, string];
const MENUS: Record<string, Item[]> = {
  admin: [
    ['/dashboard', 'Tableau de bord', 'grid'], ['/annonces', 'Annonces', 'megaphone'], ['/messages', 'Messages', 'mail'], ['/classes', 'Classes', 'book'], ['/eleves', 'Élèves', 'user'],
    ['/professeurs', 'Professeurs', 'users'], ['/planning', 'Planning', 'calendar'],
    ['/bulletin', 'Bulletins', 'file'], ['/paiements', 'Scolarité', 'card'], ['/journal', 'Journal', 'shield'], ['/parametres', 'Paramètres', 'gear'],
  ],
  teacher: [['/annonces', 'Annonces', 'megaphone'], ['/messages', 'Messages', 'mail'], ['/classes', 'Mes classes', 'book'], ['/eleves', 'Élèves', 'user'], ['/notes', 'Notes', 'edit'], ['/vie-scolaire', 'Vie scolaire', 'heart'], ['/planning', 'Planning', 'calendar']],
  parent: [['/parent', 'Mon enfant', 'user'], ['/annonces', 'Annonces', 'megaphone'], ['/messages', 'Messages', 'mail'], ['/planning', 'Planning', 'calendar']],
};
// éléments affichés dans la barre du bas sur téléphone (le reste va dans « Plus »)
const TABS: Record<string, string[]> = {
  admin: ['/dashboard', '/eleves', '/messages', '/paiements'],
  teacher: ['/classes', '/notes', '/vie-scolaire', '/messages'],
  parent: ['/parent', '/annonces', '/messages', '/planning'],
};
const SHORT: Record<string, string> = { 'Tableau de bord': 'Accueil', 'Vie scolaire': 'Vie scol.', 'Mes classes': 'Classes', 'Mon enfant': 'Enfant' };
const LABEL: Record<string, string> = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

export default function NavMenu() {
  const path = usePathname();
  const [me, setMe] = useState<{ role: string; name: string } | null>(null);
  const [more, setMore] = useState(false);
  const [badges, setBadges] = useState<{ msg: number; ann: number }>({ msg: 0, ann: 0 });

  useEffect(() => {
    let alive = true;
    async function load() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { if (alive) setMe(null); return; }
      const { data: p } = await supabase.from('profiles').select('role, active, full_name').eq('id', data.session.user.id).maybeSingle();
      if (alive) setMe(p && p.active !== false ? { role: p.role, name: p.full_name } : null);
    }
    load();
    async function loadBadges() {
      const { data: s } = await supabase.auth.getSession();
      if (!s.session) return;
      let seen = '1970-01-01T00:00:00Z';
      try { seen = localStorage.getItem('lakol_ann_seen') || seen; } catch (e) {}
      const [m, a] = await Promise.all([
        supabase.rpc('unread_messages'),
        supabase.from('announcements').select('id', { count: 'exact', head: true }).gt('created_at', seen),
      ]);
      if (alive) setBadges({ msg: Number(m.data) || 0, ann: a.count || 0 });
    }
    load(); loadBadges();
    const { data: sub } = supabase.auth.onAuthStateChange(() => { load(); loadBadges(); });
    const timer = setInterval(loadBadges, 45000);
    window.addEventListener('lakol:refresh', loadBadges);
    return () => { alive = false; sub.subscription.unsubscribe(); clearInterval(timer); window.removeEventListener('lakol:refresh', loadBadges); };
  }, []);

  useEffect(() => { setMore(false); }, [path]);

  if (path === '/login' || !me) return null;
  const initials = me.name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
  const items = MENUS[me.role] || [];
  const tabKeys = TABS[me.role] || [];
  const tabs = items.filter(([h]) => tabKeys.includes(h));
  const rest = items.filter(([h]) => !tabKeys.includes(h));
  const isOn = (href: string) => path === href || path.startsWith(href + '/');
  const nb = (href: string) => (href === '/messages' && badges.msg > 0 ? badges.msg : href === '/annonces' && badges.ann > 0 ? badges.ann : 0);
  const restBadge = rest.reduce((n, [h]) => n + nb(h), 0);
  const logout = async () => { await supabase.auth.signOut(); window.location.href = '/login'; };
  return (
    <>
      <aside className="lk-side no-print">
        <Link href="/" className="lk-brand"><Logo id="lgn" size={34} /><Wordmark height={20} /></Link>
        <div className="lk-navlabel">Menu</div>
        <nav className="lk-links">
          {items.map(([href, label, icon]) => (
            <Link key={href} href={href} className={isOn(href) ? 'on' : ''}>
              <Icon name={icon} />{label}
              {nb(href) > 0 && <em className="nbadge">{nb(href)}</em>}
            </Link>
          ))}
        </nav>
        <div className="lk-user">
          <span className="avatar">{initials}</span>
          <Link href="/profil" className="who" title="Mon profil"><b>{me.name}</b><span>{LABEL[me.role]} · profil</span></Link>
          <button className="nav-logout" title="Déconnexion" aria-label="Déconnexion" onClick={logout}><Icon name="logout" /></button>
        </div>
      </aside>

      {/* téléphone : barre du bas + feuille « Plus » */}
      <nav className="lk-tabbar no-print" aria-label="Navigation">
        {tabs.map(([href, label, icon]) => (
          <Link key={href} href={href} className={isOn(href) ? 'on' : ''}>
            <span className="ti"><Icon name={icon} />{nb(href) > 0 && <em className="nbadge">{nb(href)}</em>}</span>
            <span>{SHORT[label] || label}</span>
          </Link>
        ))}
        <button type="button" className={'tabmore' + (more ? ' on' : '')} onClick={() => setMore(!more)} aria-expanded={more}>
          <span className="ti"><Icon name="more" />{restBadge > 0 && <em className="nbadge">{restBadge}</em>}</span>
          <span>Plus</span>
        </button>
      </nav>
      {more && (
        <div className="lk-sheet-wrap no-print" onClick={() => setMore(false)}>
          <div className="lk-sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Menu">
            <div className="lk-sheet-grip" />
            <Link href="/profil" className="lk-sheet-me">
              <span className="avatar">{initials}</span>
              <span><b>{me.name}</b><small>{LABEL[me.role]} · mon profil</small></span>
            </Link>
            <div className="lk-sheet-grid">
              {rest.map(([href, label, icon]) => (
                <Link key={href} href={href} className={isOn(href) ? 'on' : ''}>
                  <span className="ti"><Icon name={icon} />{nb(href) > 0 && <em className="nbadge">{nb(href)}</em>}</span>
                  <span>{label}</span>
                </Link>
              ))}
            </div>
            <button type="button" className="btn-ghost lk-sheet-out" onClick={logout}><Icon name="logout" /> Se déconnecter</button>
          </div>
        </div>
      )}
    </>
  );
}
