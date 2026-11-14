#!/bin/bash
# Lakol v8d : fiche élève refaite (bandeau arche parent, carte élève, devoirs à venir, notes par matière avec barres).  nouveau design arche sur le tableau de bord et la version ordinateur (menu, bandeau, connexion), vraie distinction mode clair / mode sombre, animations pour tous les rôles.  interface smartphone (barre du bas, formulaires qui ne zooment plus, connexion refaite), emojis remplacés par des icônes,
# double authentification conseillée mais plus obligatoire. Nouveau design aux couleurs du logo (arche) et mode sombre automatique. Page de connexion en arche (téléphone), bandeau du tableau de bord en arche, animations « portail qui s'ouvre ». Contient aussi la v8, la v7b, la v7 et la v6b.
# À lancer depuis le dossier ecole-app.
set -e
if [ ! -f package.json ] || [ ! -d app ]; then echo "Lance ce script depuis le dossier ecole-app (celui qui contient package.json et app)."; exit 1; fi
B="_sauvegarde_avant_v8d"; mkdir -p "$B"
save(){ if [ -f "$1" ] && [ ! -f "$B/$1" ]; then mkdir -p "$B/$(dirname "$1")"; cp "$1" "$B/$1"; fi; }






save ".github/workflows/sauvegarde-quotidienne.yml"
mkdir -p "$(dirname ".github/workflows/sauvegarde-quotidienne.yml")"
cat > '.github/workflows/sauvegarde-quotidienne.yml' <<'LAKOL_EOF'
name: Sauvegarde quotidienne de la base Lakol

on:
  schedule:
    - cron: '17 3 * * *'     # tous les jours à 03h17 UTC
  workflow_dispatch:         # permet aussi de la lancer à la main (onglet Actions)

jobs:
  sauvegarde:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - name: Installer les outils PostgreSQL 17
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y -qq postgresql-common gnupg
          sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
          sudo apt-get install -y -qq postgresql-client-17

      - name: Exporter et chiffrer la base
        env:
          DB_URL: ${{ secrets.SUPABASE_DB_URL }}
          BACKUP_PASSPHRASE: ${{ secrets.BACKUP_PASSPHRASE }}
          PG_BIN: /usr/lib/postgresql/17/bin
        run: bash scripts/backup.sh sauvegardes

      - name: Garder le fichier chiffré pendant 90 jours
        uses: actions/upload-artifact@v4
        with:
          name: sauvegarde-lakol-${{ github.run_number }}
          path: sauvegardes/*.gpg
          retention-days: 90
          if-no-files-found: error
LAKOL_EOF

save "app/NavMenu.tsx"
mkdir -p "$(dirname "app/NavMenu.tsx")"
cat > 'app/NavMenu.tsx' <<'LAKOL_EOF'
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
LAKOL_EOF

save "app/annonces/page.js"
mkdir -p "$(dirname "app/annonces/page.js")"
cat > 'app/annonces/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { pingNotify, refreshBadges } from '../../lib/notify';
import Icon from '../components/Icon';

const KINDS = { info: ['Information', ''], urgent: ['Urgent', 'coral'], closure: ['Pas de cours', 'amber'] };
const AUD = { all: 'Tout le monde', parents: 'Parents', teachers: 'Professeurs' };

export default function Annonces() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [list, setList] = useState([]);
  const [f, setF] = useState({ title: '', body: '', audience: 'all', kind: 'info', pinned: false });
  const [msg, setMsg] = useState('');
  const isAdmin = profile?.role === 'admin';

  async function load() {
    const { data } = await supabase.from('announcements').select('id, title, body, audience, kind, pinned, created_at').order('pinned', { ascending: false }).order('created_at', { ascending: false });
    setList(data || []);
    try { localStorage.setItem('lakol_ann_seen', new Date().toISOString()); } catch (e) {}
    refreshBadges();
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function publish(e) {
    e.preventDefault(); setMsg('');
    if (!f.title.trim() || !f.body.trim()) return setMsg('Écris un titre et un message.');
    const { error } = await supabase.from('announcements').insert({ school_id: profile.school_id, title: f.title.trim(), body: f.body.trim(), audience: f.audience, kind: f.kind, pinned: f.pinned });
    if (error) return setMsg(error.message);
    setF({ title: '', body: '', audience: 'all', kind: 'info', pinned: false }); setMsg('Annonce publiée. Les emails partent.');
    pingNotify(); load();
  }
  const togglePin = async (a) => { await supabase.from('announcements').update({ pinned: !a.pinned }).eq('id', a.id); load(); };
  const del = async (a) => { if (confirm('Supprimer cette annonce ?')) { await supabase.from('announcements').delete().eq('id', a.id); load(); } };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Annonces</h1><div className="sub">Les informations générales de l'école.</div></div></div>

      {isAdmin && (
        <form className="lk-card" onSubmit={publish}>
          <h3>Nouvelle annonce</h3>
          <div className="chips">
            {Object.entries(KINDS).map(([k, [l, c]]) => <button type="button" key={k} className={c + (f.kind === k ? ' on' : '')} onClick={() => setF({ ...f, kind: k })}>{l}</button>)}
          </div>
          <input placeholder="Titre (ex. Pas de cours demain)" value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} />
          <textarea rows={4} placeholder="Message…" value={f.body} onChange={(e) => setF({ ...f, body: e.target.value })} />
          <div className="lk-inline">
            <span className="lk-label">Pour :</span>
            <div className="chips">{Object.entries(AUD).map(([k, l]) => <button type="button" key={k} className={f.audience === k ? 'on' : ''} onClick={() => setF({ ...f, audience: k })}>{l}</button>)}</div>
            <label className="meta"><input type="checkbox" checked={f.pinned} onChange={(e) => setF({ ...f, pinned: e.target.checked })} /> <Icon name="pin" /> Épingler en haut</label>
          </div>
          <div className="lk-inline"><button>Publier et prévenir</button>{msg && <span className="meta">{msg}</span>}</div>
        </form>
      )}

      {list.length === 0 && <div className="empty">Aucune annonce pour le moment.</div>}
      {list.map((a) => (
        <div className={'lk-card ann ' + a.kind} key={a.id}>
          <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
            <div className="actions">
              <span className={'badge ' + (a.kind === 'urgent' ? 'bad' : a.kind === 'closure' ? 'mid' : '')}>{KINDS[a.kind][0]}</span>
              {a.pinned && <span className="badge"><Icon name="pin" /> Épinglée</span>}
              {isAdmin && <span className="tag">{AUD[a.audience]}</span>}
            </div>
            <span className="meta">{new Date(a.created_at).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</span>
          </div>
          <h3 style={{ fontSize: '1.15rem' }}>{a.title}</h3>
          <p style={{ margin: 0, whiteSpace: 'pre-line' }}>{a.body}</p>
          {isAdmin && <div className="actions"><button className="btn-small btn-ghost" onClick={() => togglePin(a)}>{a.pinned ? 'Désépingler' : 'Épingler'}</button><button className="btn-small btn-danger" onClick={() => del(a)}>Supprimer</button></div>}
        </div>
      ))}
    </div>
  );
}
LAKOL_EOF

save "app/api/notify/route.js"
mkdir -p "$(dirname "app/api/notify/route.js")"
cat > 'app/api/notify/route.js' <<'LAKOL_EOF'
import { createClient } from '@supabase/supabase-js';


const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

function emailHtml(subject, body, siteUrl) {
  return `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px">
<div style="font-size:22px;font-weight:800;color:#6D4AFF;margin-bottom:14px">Lakol</div>
<h2 style="margin:0 0 10px;color:#1B1740">${esc(subject)}</h2>
<p style="white-space:pre-line;color:#333;line-height:1.55">${esc(body)}</p>
<p style="margin-top:22px"><a href="${siteUrl}" style="background:#6D4AFF;color:#fff;padding:10px 22px;border-radius:99px;text-decoration:none;font-weight:700">Ouvrir Lakol</a></p>
<p style="color:#999;font-size:12px;margin-top:26px">Tu reçois cet email car les notifications sont activées dans ton profil Lakol.</p></div>`;
}

export async function POST(request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const secret = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const mailKey = process.env.BREVO_API_KEY;
  const from = process.env.MAIL_FROM;
  if (!secret) return Response.json({ ok: false, error: 'SUPABASE_SERVICE_ROLE_KEY manquant' });

  // Seul un utilisateur connecté peut déclencher l'envoi
  const token = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) return Response.json({ ok: false, error: 'Non connecté' }, { status: 401 });
  const { data: u } = await createClient(url, anon).auth.getUser(token);
  if (!u?.user) return Response.json({ ok: false, error: 'Non connecté' }, { status: 401 });

  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const channels = [];
  if (mailKey && from) channels.push('email');
  if (!channels.length) return Response.json({ ok: true, sent: 0, note: 'Envoi non configuré' });

  // Les notifications de plus de 3 jours ne sont plus envoyées
  await admin.from('notification_queue').update({ status: 'skipped', error: 'trop ancienne' })
    .eq('status', 'pending').lt('created_at', new Date(Date.now() - 3 * 864e5).toISOString());

  const { data: todo } = await admin.from('notification_queue').select('id').eq('status', 'pending').in('channel', channels).order('created_at').limit(40);
  if (!todo?.length) return Response.json({ ok: true, sent: 0 });
  // « Je prends ces lignes » pour éviter les doubles envois
  const { data: rows } = await admin.from('notification_queue').update({ status: 'sending' })
    .in('id', todo.map((r) => r.id)).eq('status', 'pending').select('id, user_id, channel, subject, body');
  if (!rows?.length) return Response.json({ ok: true, sent: 0 });

  const { data: profs } = await admin.from('profiles').select('id, email, phone').in('id', [...new Set(rows.map((r) => r.user_id))]);
  const byId = Object.fromEntries((profs || []).map((p) => [p.id, p]));
  const site = process.env.SITE_URL || new URL(request.url).origin;
  let sent = 0, failed = 0;

  for (const r of rows) {
    const p = byId[r.user_id];
    let error = null;
    try {
      if (r.channel === 'email') {
        if (!p?.email) throw new Error('Pas d\'email');
        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST', headers: { 'api-key': mailKey, 'content-type': 'application/json', accept: 'application/json' },
          body: JSON.stringify({ sender: { name: 'Lakol', email: from }, to: [{ email: p.email }], subject: r.subject, htmlContent: emailHtml(r.subject, r.body, site) }),
        });
        if (!res.ok) throw new Error((await res.text()).slice(0, 300));
      } else {
        throw new Error('Canal non pris en charge');
      }
    } catch (e) { error = String(e.message || e); }
    await admin.from('notification_queue').update(error ? { status: 'failed', error } : { status: 'sent', sent_at: new Date().toISOString() }).eq('id', r.id);
    error ? failed++ : sent++;
  }
  return Response.json({ ok: true, sent, failed });
}
LAKOL_EOF

save "app/apple-icon.png"
mkdir -p "$(dirname "app/apple-icon.png")"
base64 -d > 'app/apple-icon.png' <<'LAKOL_EOF'
iVBORw0KGgoAAAANSUhEUgAAALQAAAC0CAIAAACyr5FlAAAQAElEQVR4AeydCXwURfbH3ysIGMIZ
5QgBBAEBQRB1QcFVVBSRQwQSDlGS4M0SFAURBblEVPBAFFH+KIqC4oJGWV2BFVYO14sECLeA7Cok
XBIIN1P/3+tJYoCZSc8wmenpdH+KoubVq+u977yq7pkk6qLKzZ3kWMCjBRQ5l2MBLxZw4PBiGEdM
5MDhUODVAg4cXk3jVDhwOAx4tYADh1fTOBUOHAEwUFKaOHCUFE8HsE4HjgCMVlKaOHCUFE8HsE4H
jgCMVlKaOHCUFE8HsE4HjgCMVlKaOHCUFE8HsM6gwhHA+E4TC1vAgcPCzgn31Bw4wu0BC4/vwGFh
54R7ag4c4faAhcd34LCwc8I9NQeOcHvAwuM7cITbORYe34HDws4J99QcOMLtAQuP78BhYeeEe2oO
HOH2gIXHL1lwXHhhlauuvrxnYqfHhz3wxpvPfvr5jCXL5n73Q9qazEW//Lp8z4EMpK07luMlhIuX
zoXC69PGQ7lHwu1oGBtb2cKuDP7U7A/HZU0bptzb6+2ZL6zbsHjj1qVfLZo9bfqEJ558OKFX57bX
/aV58yb1G1wcV7NaxYoV3NatVKkCXkLYokUTKCT27gLlN996Dg03/bJs7fpF02dMTB6Q2OSyBm59
G+f2hKNs2TLd7uzw7vsvbd+5ctnyT55/cQReVq9R9fwdWSOuWvceHV+Y9NS/V/x9268rwFyXru3P
v1tr9mBdOAKwl1Lq5vZtsRFs3LIUbuvU+ebyFWIC6MdkkwoVy4O5mbMmg5LX3hjX7sZrMQGTbSNC
zSZwlCkThb3j54wv5857AxtBsTJxrl9BSe8+XefNf/PH9IX9kxNKly59rk4kSiIeDuwgDz7UD1hg
74ivVSO8Pqhdu+akl57GZO57oC8mFt7JnP/okQ1H954df1y9cNyEoUE5T5y/Nd094Dw7YeIT3//0
xR3dbnVLIjSPVDgaNKz7xZfvTn97Ik6I1jR9zfjqM955MW3hzEsbXWLNGRY5q8iDI6Z8Obwvl6+a
3/qalkUuL+wK17a5atnyeYhtIT4GBWXhEQYHnkT954c07OilSpUKyvpD0AnOpzgVrfxuwV9atQjB
cEEcImLgYGY8qVz41SxLHS/MeyKuZnVsMYMGJ5tvEoBmcJtEBhxVq8amLXwHTyojKGCc6yeEkFGj
H/lkwXQ8xT+31oKSCIADT7K/+XbeNddGwAnDjINvaHfNv5Z9VLduLTPK4dWxOhw4dS5a8mH16hcV
k5mysvZmrtu89JtV8z76YsorM5FQwEsIs7P3FdOguJFZ9M0cnJ+Kqf9gdWtpODp3aY/7VTx/DNZq
d+/KnvHWnL69/vbXNj0aN2hXtUqLZo1vbvfXhITuDz784FPjxryKhAJeQti00U1QgBqU7+qT+n9v
z0XzYM2kcuWKC9JmdOh4Q7A6LI5+rAtHUkrCzFmTzn/NLpfrxx/WTBj/2g3X9bz8sluefGLioq+/
3bhh6759B8x0DjUof/3VsuHDnkNzQIOufvpxrdbaTHMfOtHRF7w3+5U+d3XzoRPeKovCkfpIyouT
n8YdSsDWyT18ZOEXSwYNHNmk4Y0db7375ckz1mduCbi3gobYbtDVbbf0Q0RJHTgKQ+TmHi2o9beA
D+qmTB3z8N/6+9swNPpWhAMfYo18ZnDA6z916tQbr7/XtPFNSXcPmfth2v79fwTclY+G6HbOh59h
iKaNbpz2xvsY1Iey76ox44b0TOjkWycstZaD45Zbr3916piAbbFq5U83XJfwzNOTz3xDB9xf0Q0x
0KinJmHQ7/+TXrS2F42p08Z1uM1y5w9rwYFniO++/xKCrRcb+hLjvuOhB0Z07ZSyedM2X3rFU4dB
O93WH4fZPXv2BzACnt/MnDW59TVXBNC2+JpYCI5ateLmfDy1TJmoAFb73aqf27Tq9snHCwNoG8Qm
uA1u27obJhNAn1j4B3Nfs9TniFaBA08PZ8+dUqlSxQDMii3/js4DcnIOBdA26E0OHDiIyeCGOYCe
sfz3Zr8MUwTQtjiaWAWO5198smnTS/1d4fHjJ+5NGTbqqUm4X/W3bfHpYzK4YX74gREnTpz0d5SW
VzYbP2Gov62KSd8ScHTp2v6epJ7+rvD337I63HzXZwv+6W/D0OjP+3ghbqGzdu/xd7gB9/Xuao1v
CYUfjoaX1ps6bby/FsRzLTyPyszc7G/DUOqvydiAu5iM9PX+Dvra62Pr1avtb6ug64cfjmlvPVeu
XLRfC5v1zjy8KbG7+9UqLMp4wNr+xj6z35/v1+gwyPQZE/1qUgzK4f5LTSn39mrRoolfC/v6n8se
H+J3pPFriKArP5o65qsvl/rVLQ4f9/Tv4VeToCuHM3LExlYeOcq/J6HYRwYkWeW85pcz7ksZtnbt
Rr+ajBrzSMHP4fnVMFjK4YRjzPjH/PpmJR5zJXZ/8Nix42YWX63ipS0v7t6l5ZjOLcegUK1iQzOt
ik8H0+6dMHDvXj8ekeHOdvS4IcU3pSJ7Dhsclza6pFfvLkXOr0ABd60gw8x3LGrHtnzgpr8nX//e
rZcPuyy+Q9P4DigkX//+/TfOqx0bzkeQ2Vl7+yT+DQspWFSRhX5331nvkjpFqhWTQtjgeGzo/cxs
flUP3jd8/foiPlaNKhXd+YrRfdtMq1wu/tyeq8TU7tP2zY5XjoLaubWhkaSvzsTzD/NjMfPjQ+83
rx9czfDAgfu0bnd2ML+SSS9M/+LzJUXqt282pGmt27ypaSKt6LI6Hdu1eNSbTgjkaZ8teuWlGeYH
6pnYCR8smNcPomZ44Hj08fvMf7q2aeMvzz/3RpFrrlf1mua1fe5TisAHMTer16VujWuL7PB8FGKi
+Nqa0fc3j516U/zMDrUfveqi9nXKV4vO+3GKCeOnbli/1WT/MNSQMAWPMMARX6tGQqIfX18Y+tiz
RdrxgqgKXVqO9qGmmVxG5HCx1sy3tBpZJirQH8D3MQxRaebHrr5oS0qTtG6XPHtdXK/GlbvUrzii
dfU5nS/OTG48/Zb4imWV1nr0qJd8dnNGZZ++XatVL65v0Z4x0pkv1JkvQ/EqZUAv858tLV60fNXK
n4qc1qU12kWX8fVrdzSON4gcyJk16+joKvXiry+yW38V6leOWpRQb3ir6lGlMJKH1t0bVl7eq8Gt
dSv8a8mK5d9+70HDkwjmgtE81RSvLAxwJPbqbHJNeIc9M3KyGeXyF/j6xSwueEoihybkiByKISkf
U81Mz2Z1tH6oeezSxAbNLiriaW9c+agPbq/zUruaY0f48Qy0T987zM4keHqhhqPtdX+pEWfWKx/M
XrDZ3Dd3KlzgNepqGEsRaCBhQiPXOHswxZQzOw10UGQqF1Uq+fLYC0qbtWevRpVO7PrfR3M+L7Jn
t0LN+Oqtr2npLocsN7uYYE0ooZfZ0waeB4wfM8XkuKVUWa+aCiyACcJuQswu0rhnASuloy7w2sT/
irFtqter5H0O53RYppSaenP8s+Om4OHYOZWeBYmmI67n9v5LQwpHWflVXV5vNc+a/GuvvoNPrc4S
enuJ5wEeq3DUkISYASZABhuUQJVJIgoKwUg31i7fv1msvz1hA0qo4Zo+bbbJhvgcH4cPk8pBUQsp
HNhTYmKK2JLdq8Jp4603P3CXzeTQ96AGAnDCQA4SFLsjhzChsMtowkHEQ5tARN0bVgykGVFSsypv
vzXHZNvKlSte2+ZKk8pBUQspHG3aXmVy0j/+sMavT+Q9Rg6Ne1cWJjTIkMghTGiQgUlAjjxIqU6F
MoH1FBdTem/WHjw2Ndm8TdurTWoGRS2YcBQ5IfNr+/If3xTZW2EFOWMWfg0sQIMiRAstHOCcAUqI
pExkyJFTkK7aFQP5UjQGL61UzfJR5hdr3oDo/PxT6ODAgaPllU1Nztjfbz8w8dk9S7QgAg3YVkAD
WEEBu4wiF9Bx11JwrmrRpQPuqE6FKPOLbdW6RakQ/taa0MHRqvUVJs9TO3f+tmXzdr/MfdaZQzMI
QLQg43koyf4CGpggR0LMkEhzDk5+jVhYed3eY4Vfmi+7tP4p6+j6zC0mf0QbBmwdwp9tCR0cLa64
zKTVvkhbbFKzQO2sM4dBAIMJI3JooQExIx8O1GqwQlJf0MP5FAKGY9sfJ46dlmng0ziTE2je3L8v
zpns1qNa6OC4pP7FHmdwrtB8mC1oWzhywPegIf95BsjAsw2CUJIixAwp4H8OWuhYuy/AyLF2b94P
YZtfcoOGdQtWXdyF0MFR3xwch3IOr1r5s7/LZs7zNN6GWpEL7d2xQYEMDVYAhOTu0waiiGKcVaEV
lJS29eD+o6cC6GrG2rwvhq1Y/mPOQVM/lFW/gdn3WADzOatJCOEwt6rVqzPPmqKZl39GDoWYIDTg
tEEqjww8DyUGMXIKARMap1ScTyEy07UJnQPHXcO/3WVC8QyVWev2f787L3K4XK5160z9mEX9+raL
HGXKRJn81U3ZWXvPMKG5F8wSOTSTJDcTzAYfYIKAgfChGHsKMQsfYIgRZShY14KtOV9uzzHf2+7D
J0atzCKigibZ2aYWHlezGoxZ0KpYCyGKHI0bNzC5DJM2Oqs3w+sgQwschMjBIEA4gJ4SSiDHKURi
CfYU8AG5wRP+D1Ya9u9d5jeXR5b+fuSUq/DQ5t8VjRrVL9yw+MohgqNa9QtNriErK5Bf08bEiAOa
DQ4UykIJIodx/tBCCWSKhQ+JLpoQOcCQyTmZU9ude6r5e5un/LzntMvlo8XiXw81e3fTkp25Z+lk
m/79dOaNedYQ/r4MERzlypn6SAWzzzYXXaFZOCFygIP8aIGzBWsmYYJIOGDhQ8gAH0yQi/dQoCBf
x0/rcd9l3z5/x84cDz8/cfD46YFLfuuzcGfWEQ+nV/ORIzrarDHPc3mhgsPc521YjHkbQfnPhHiA
F8zgQyjBeRMS7CBKzhyaGVGEQAaiBSSsSaGEBsWSfs4+evXsrVe+v7ln2o5hy34ftXxXv3/82mbO
libvbPx4k9ffQWX+XRFdLphfNvBhglDB4UfkCGRb0XKPSiAAHGhgoVhyFBAewAFrRAtwQ4pdMAZD
kwhVVFyXJvrvoZPL/pf7TuaBaWv2/3PH4S0HTpyUsb2OmG16PzUfhr0OZq7CenAEdLcCT8MfxCwE
GHkBHEaB3dwgp3wyIDdnohBpmY8c5aLtFTmiTa9n/36vgdeHl0AGdhP4XiM2YDdhgu+1ETOkwBox
I58bIoXIoUGJjw5DX5Vl+l1ht22Fmf00t3/qQgAZBCA3yAABGnuNO4oo0FH4/oUIcorUCx+/hWbq
IdpWin0xYE8x7kcQLeR5F5O7jGihhYOC+xewA4YIckKTYp9WZA9gEzg0aEB0UIRoAa8LHwqvNYEM
7DIil8gBNa0MhkQe2Z4LweztAgdMBX8jVyRkgBVwAg5AhiHXioQMJjwRIcWIHBrKTvJpAZvAQQwm
sHeQC6uVMoEA7CyQgwMCGXL+IOEDZMhTEPABVSf5soBNwFOMSAAAC9dJREFU4IDXyYgQwgETcpCh
FUsUQQ4ywAeTRg4yFAsx7MsuTh0sYBM4sBL4G75H5HDn4MPYQRBLtFEmd65BhvBBzrYCo/lONoED
kcOdDAI0IUgwkWIXVs9kxA8yYgkZDLE25MjslYK8GpvA4abBzQdigzwNEyY0KRIypCysSCzB7gM2
FAkfQTam3bqzCRzwtBZ/G/er8LtigCLEwF8KfGiUETlIcR43kDP+OcmXBWwCB3yv5dQJJnDPwogQ
gAMxA8S4sHwWJoQMcMOEKlJGjionebeATeAwyIC/ETkMMhQLAeCAtMGBJvAhZVBCxOQiQk7O5dMC
doGD4XkhwDhvShlwSFIMDjTIYA1KZGdhQkRBGdHFp2WcShjJHkYQ37NxnkCJtGKhhIUSLBFlYkiI
FHSIGHxIjCHn8mkB20QOdkcF4UDOE+J7zVRAicGNMGGQQSSfEmtyLp8WsAsciBF5UQGUkGAhn6oQ
9g7NrJkQMzQTARfkSijRwgc5lw8L2AQOYjBhnCpYci0EMPK8yKHclJAhIRfswah1IgcM4SvZBA5j
NwEfRExy3kTufkYu8YNBgQYfbMBBmqSsyYkcVMRlEziIGKcK4nwy3JEDHBgRQsggQq0RORinEw05
asm5fFnAJnBI5GDSwgT4QFQgEEByCjFOpvJ8jEAPFHAKgdyt78swTh2RTeBAVMBuggjhglOZwQGB
DBJKhAPsI4bcKGOXATGog8hJvixgEzg01ojIAY+DA3gffEgZlJBwY5w/QIw2iEGOEAI5OZdPC9gE
Dnga/obXsZtokAE+FKEMOSIKoojQoyDFJy+gRpMizT4N41QSjGQLK8D3cHah8wQ4wOLyIwdeKWEF
9IiaYhdWzfjnJF8WsEnkEJdjW1GMU4U2IocGDazzIodIiFBLIoEOKZR82cWpgwVsAgcgAA2IHCDD
8D24IBEygQOcNlCWXUYxdhnNiCKEnJzLpwVsAgc8reV+FUxo0CCUKBIOkGP9EjkgZ+GDDSxssm6s
rRiTTYxkkAGv47wJAkiiCBOiBSgRVlgT4x/4EGKICZSAJ3IunxawCRzwt3AAAsCAIo0owgT3a4XX
eKrB2Fm0AhMETUQUUhwT36DObSm1O6bUul1SfOeUmp1T4rqk1OiaUuOOlOrdUqrdmVK1e3LVHskX
9Ui+sGdybEJybGJylV7JlXsnV+qTXLGvpAp3JZfvlxzTL6ns9e1UrN9/OIGsfdkEDtAAfwsBTC6Q
oUAGmCAQo8EHCAE38IQi6IAPyGNqNax1W3KtjinxtyeDjLhOSXFdkmt0TapxR3K1O5KqdUuuemdS
1e4pF3ZPMshIAhmVEpNARsXeSYCjQp+k8v2SYvr1j7k7qdw9SRWeGVP5k/mVPvqobL+7MI49kk3g
gL+xUyBHtCAFJkiDBjABMvAEDMTgEzjIZa9xRxHJDX2N3CCGtVGL86wWTYMtaQVN6c2IN+QinacP
HSAgoxAZo0DONaqXfeC+mHdnlmrcCJWRnmwCh/hViRfhoUKRg0GMVobXkSOiMNys832ZJxevM4EP
rYwc/oYm9BnKhBhDikAMetbwtuI8fSm79ck9CuQyDaJS9S8pN31aqQYh+p1/mEgxJZvAAc/BQ5Iz
iS9hLfiYwQHleRfxQ3xMGt6VMnyM06v4Nb8Vi2ahVvC0JAU5aT5XH22JmIUb0dFkwETGxUpFPzOK
ogL8UxtGH+HPbAKHhiUV/EfwEGIAKUJueJQMGuDd/EQghsWj8CsZJDFJK0OOVsTskshB2nA2iNEK
ZQ25JkLPkCMXFpWMQhhXaEMZ1X8mVffisvff++frCCzZBA5i+EYbORG8y5IbBBh+VcghkVwrFn8z
o1YrEg6kLbl9bLTVpEgTERM40IY+IZfzh6GvJIfE4AMk/alPZ15le3Q/UxBhr2wCB/zt9iXBc6xR
lhig2H0OcBmRABJxtrzLWciA7+EsBQJEX3oQfZQZ+u5+CvTBgRaewBCJJtqyJoV/kmMU8mjIqCgV
F4dBIjR5XFPkrQWeg4e0Mt7TzOAA3oJHQYlmQlljTcxgggyPQihJwdOkWfS1Yrd+flsiztdnEAA1
9/0LiSaiCDM0tcKImsAKeb6wuXiuiASpTeA4lrvX8FCeFwmeg/UVPErE4j/xIsOLDAJQ1ixViAFG
Ga1QZ+RMpERfcsgMYrTRm1YMtjQakltTetMEfcjxn5d02uWlIgLEQYQjnKs9mL1F3KYM3zO8pcW7
2E2YEFFIMTggZrzXScG38Ci59SEXr8teQ25uXFiHgiZ0GBLRR2tphcjBaEWKwQQK6E0raYUW3tLp
zED+Qoi33kIstwkcf+zeDG/B0+I5I+bDf6RAgCYmtxy+JPABYhQ8SqIPTfE07mkZL0Uf5leoklYG
GSxs5bdyRw7IwYToM2voM/55Tq7sPTr37F+A71nVklKbwJG7/797tn9Pbk+DBvG6mwDxrlbINTEJ
H+J7QjnPu6IJHyMqgAnSihA5NBv6aEWFWhERswYKikEbCsKKT/udnL+AIvnyubiIWlhG2oSTp45p
eI5JckxeEfxHCv6GjxnuJMWG70niAeQgA/6WPUVqoaALWhly0QcNTGhFefoo50Ua6EPdW3Jt3Xp8
zlxvtREhtw8cx3L2bF48De9peBG5hi9lB2G3v917AXKphb+NWiMSaJGADwZJhFbQ18yIMVpI0sSU
RxL8yWzQZuQs+pB5TqdPHxkznnz+4RXPDa0ktQ8csOqv332y8R+vnjp1Qit4Lt/rUiZSrKHhLjO5
KRECmF3CEPSNBEpERxNDX5OUiQrpE0Nf9iAhhjxfev/+3MFDXDt2eK6OHKmt4IDZd66a9/3rA3L3
7IQXNZMWJsSXeMdrBSaEAPGrEh8TFNggAC2lTFqxRB3mP/XRiomUoY+cDX0mtCVP16kVKw/fdc/p
jAxPlREmsxscMH9u1vb/TOr7w8tJW+ZPzv7p64Pb0g9ulZSzJf3Q1vScLasPo7B59eHNGYc3pedu
Sj+8Mf3IpvTcDelHNqQfXZ9+dEPG0fWrj63POLYu/XhmxvG16SdQWJt+cl3GiYz0k2syTmakn8rI
OLU6/XR6xql0I1+9+sT8T4+OHns4sfeR4SP04cOYhrlkaS0bwuG2d+7vW3etWLB59th1UwatnzJo
wyuDNr48aNPkQVsmpW55YdAvz6dumzho+3OpO55N3Tk+defY1P+NTf1tdOrvz6TuGpma9fTgrBGp
e0YM3js8dd8Tg/cPHfzH44P/GDI4Z8jgQ48MPjz4kdxBg4+kGvkgI0999NjLr5xc8i/Xrt3u0e2R
2xYOe7gnvKtw4Aiv/S09ugOHpd0T3sk5cITX/pYe3YHD0u4J7+QcOMJrf0uPblU4LG20kjI5B46S
4ukA1unAEYDRSkoTy8ExbPhDJTZZDTrLwTH0iQdLbHLgsJoFnPl4tYDlIofXmToVIbeAA0fITV58
Awa7ZweOYFvURv05cNjImcFeSojgyDl4KNgzL7n9hcyYIYIjM3NzyXVmsFe+du2mYHfpub8QwZGR
vsHz+I7UfwusWRMiY4YIjpycQx9+8Kn/dnBanG2B92b9/VBOiL7AHCI4sMQnhz33y9aI/1EOLCSM
adsvv454YmLIJhA6OI4cOda5Y9KSxStCtraCgexRWLxo+e0d+h8/fiJkywkdHFjS3r0Heic8PGjg
yLTPFm3f/l9InFSkBbZt2/nZp18PfOjpPokD9+07UKR+EBVCCod73nM/TBuQ9HirKztXrdLCSUVa
oPVVXe5NHvrx3M/d1gtlHgY4Qrk8Z6zzsYADx/lYz+ZtHThs7uDzWZ4Dx/lYz+ZtHThs7uCAl4eG
DhwwgpM8W8CBw7NdHCks4MABIzjJswUcODzbxZHCAg4cMIKTPFvAgcOzXRwpLODAASM4ybMFHDg8
28W7tATVOHCUIGf7u1QHDn8tVoL0HThKkLP9XaoDh78WK0H6DhwlyNn+LtWBw1+LlSB9B44S5Gx/
lxo8OPwd2dG3vAUcOCzvovBN0IEjfLa3/MgOHJZ3Ufgm6MARPttbfmQHDsu7KHwT/H8AAAD//3gm
N8MAAAAGSURBVAMA2TAaxZJ2tAkAAAAASUVORK5CYII=
LAKOL_EOF

save "app/bulletin/page.js"
mkdir -p "$(dirname "app/bulletin/page.js")"
cat > 'app/bulletin/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { useSettings } from '../../lib/useSettings';
import { mean, subjectAvg, generalAvg, appreciation, wDOf, fmt } from '../../lib/grades';
import { periodList, periodTitle, yearLabel, yearUpper, ordinal, BULLETIN } from '../../lib/settings';
import { exportPdf, exportDocx, safeName } from '../../lib/bulletinExport';
import Icon from '../components/Icon';

export default function Bulletin() {
  const { profile, status } = useProfile(['admin']);
  const st = useSettings(status === 'ok');
  const [school, setSchool] = useState(null);
  const [classes, setClasses] = useState([]);
  const [classId, setClassId] = useState('');
  const [term, setTerm] = useState(1);
  const [studentId, setStudentId] = useState('all');
  const [students, setStudents] = useState([]);
  const [grades, setGrades] = useState([]);
  const [coefs, setCoefs] = useState({});
  const [busy, setBusy] = useState('');
  const [err, setErr] = useState('');

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('schools').select('name, city').maybeSingle().then(({ data }) => setSchool(data));
    supabase.from('classes').select('id, name, school_year').order('name').then(({ data }) => { setClasses(data || []); if (data?.length) setClassId(data[0].id); });
  }, [status]);
  useEffect(() => {
    if (!classId) return;
    (async () => {
      const { data: s } = await supabase.from('students').select('id, first_name, last_name').eq('class_id', classId).order('last_name');
      setStudents(s || []); setStudentId('all');
      const ids = (s || []).map((x) => x.id);
      const { data: g } = ids.length ? await supabase.from('grades').select('student_id, subject_id, term, kind, score, subjects(name, coefficient)').in('student_id', ids) : { data: [] };
      setGrades(g || []);
      const { data: cc } = await supabase.from('class_coefficients').select('subject_id, coefficient').eq('class_id', classId);
      setCoefs(Object.fromEntries((cc || []).map((x) => [x.subject_id, Number(x.coefficient)])));
    })();
  }, [classId]);
  useEffect(() => { if (term > st.periods) setTerm(1); }, [st.periods]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const lang = st.language, B = BULLETIN[lang] || BULLETIN.fr, wD = wDOf(st);
  const termKey = term === 0 ? null : term;
  function compute(sid) {
    const mine = grades.filter((g) => g.student_id === sid && (termKey == null || g.term === termKey));
    const bySub = {};
    mine.forEach((g) => { (bySub[g.subject_id] ||= { name: g.subjects?.name, coef: coefs[g.subject_id] ?? Number(g.subjects?.coefficient || 1), list: [] }).list.push(g); });
    const lines = Object.values(bySub).sort((a, b) => a.name.localeCompare(b.name)).map((s) => ({
      name: s.name, coef: s.coef,
      dev: mean(s.list.filter((g) => g.kind === 'devoir').map((g) => Number(g.score))),
      comp: mean(s.list.filter((g) => g.kind === 'composition').map((g) => Number(g.score))),
      avg: subjectAvg(s.list, wD),
    }));
    return { lines, gen: generalAvg(lines.map((l) => ({ avg: l.avg, coef: l.coef }))) };
  }
  const data = students.map((s) => ({ s, ...compute(s.id) }));
  const ranked = [...data].filter((d) => d.gen != null).sort((a, b) => b.gen - a.gen);
  const rankOf = (id) => { const i = ranked.findIndex((d) => d.s.id === id); return i < 0 ? '–' : `${ordinal(i + 1, lang)} / ${ranked.length}`; };
  const cls = classes.find((c) => c.id === classId);
  const shown = studentId === 'all' ? data : data.filter((d) => d.s.id === studentId);
  const periodText = term === 0 ? yearLabel(lang) : periodTitle(term, st, lang);
  const periodCode = term === 0 ? (lang === 'en' ? 'Year' : 'Annee') : safeName(periodText);

  async function download(kind) {
    setErr(''); setBusy(kind);
    try {
      const items = shown.map(({ s, lines, gen }) => ({ name: `${s.last_name} ${s.first_name}`, className: cls?.name || '', year: cls?.school_year || '', lines, gen, rank: rankOf(s.id) }));
      const meta = { school: school?.name, city: school?.city, st, periodTitle: (term === 0 ? yearUpper(lang) : periodText.toUpperCase()) };
      const base = shown.length === 1 ? `Bulletin_${safeName(shown[0].s.last_name)}_${safeName(shown[0].s.first_name)}_${periodCode}` : `Bulletins_${safeName(cls?.name || 'classe')}_${periodCode}`;
      if (kind === 'pdf') await exportPdf(items, meta, `${base}.pdf`); else await exportDocx(items, meta, `${base}.docx`);
    } catch (e) { setErr('Le téléchargement a échoué : ' + (e.message || e)); }
    setBusy('');
  }

  return (
    <div className="lk-page">
      <div className="topbar no-print">
        <div><h1>Bulletins</h1><div className="sub">Télécharge en PDF, en Word (modifiable) ou imprime. Choisis un élève ou toute la classe.</div></div>
        <div className="lk-inline" style={{ flexWrap: 'wrap' }}>
          <button disabled={!!busy || shown.length === 0} onClick={() => download('pdf')}>{busy === 'pdf' ? 'Création…' : <><Icon name="download" /> PDF</>}</button>
          <button className="btn-ghost" disabled={!!busy || shown.length === 0} onClick={() => download('docx')}>{busy === 'docx' ? 'Création…' : <><Icon name="file" /> Word (modifiable)</>}</button>
          <button className="btn-ghost" onClick={() => window.print()}><Icon name="print" /> Imprimer</button>
        </div>
      </div>
      {err && <div className="notice no-print">{err}</div>}
      <div className="lk-card no-print lk-inline">
        <select value={classId} onChange={(e) => setClassId(e.target.value)}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
        <select value={studentId} onChange={(e) => setStudentId(e.target.value)}>
          <option value="all">Toute la classe ({students.length})</option>
          {students.map((s) => <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>)}
        </select>
        <select value={term} onChange={(e) => setTerm(Number(e.target.value))}>
          {periodList(st).map((t) => <option key={t} value={t}>{periodTitle(t, st)}</option>)}<option value={0}>{yearLabel('fr')}</option>
        </select>
      </div>
      {shown.length === 0 && <div className="empty">Aucun élève dans cette classe.</div>}
      {shown.map(({ s, lines, gen }) => (
        <div className="bul" key={s.id}>
          <div className="head">
            <div style={{ whiteSpace: 'pre-line' }}>{st.bulletin_header}</div>
            <div><b>{school?.name}</b><br /><small>{school?.city}</small></div>
          </div>
          <h2>{B.title} — {term === 0 ? yearUpper(lang) : periodText.toUpperCase()}</h2>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '.95rem' }}>
            <span>{B.student} : <b>{s.last_name} {s.first_name}</b></span><span>{B.cls} : <b>{cls?.name}</b> · {cls?.school_year}</span>
          </div>
          <table>
            <thead><tr><th>{B.subject}</th><th>{B.coef}</th><th>{B.dev}</th><th>{B.comp}</th><th>{B.avg}</th><th>{B.points}</th><th>{B.remark}</th></tr></thead>
            <tbody>
              {lines.map((l) => (
                <tr key={l.name}><td>{l.name}</td><td>{l.coef}</td><td>{fmt(l.dev)}</td><td>{fmt(l.comp)}</td><td><b>{fmt(l.avg)}</b></td><td>{fmt(l.avg * l.coef)}</td><td>{appreciation(l.avg, st, lang)}</td></tr>
              ))}
              {lines.length === 0 && <tr><td colSpan={7}>{B.none}</td></tr>}
            </tbody>
          </table>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '1rem' }}>
            <span>{B.general} : <b>{fmt(gen)}/{st.scale}</b> — {appreciation(gen, st, lang)}</span>{st.show_rank && <span>{B.rank} : <b>{rankOf(s.id)}</b></span>}
          </div>
          <div className="sign"><span>{B.teacher}</span><span>{B.director}</span><span>{B.parents}</span></div>
        </div>
      ))}
    </div>
  );
}
LAKOL_EOF

save "app/classes/page.js"
mkdir -p "$(dirname "app/classes/page.js")"
cat > 'app/classes/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentGrid, { filledRows } from '../components/StudentGrid';
import { useSettings } from '../../lib/useSettings';
import { periodWord } from '../../lib/settings';
import Icon from '../components/Icon';

const DAYS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const norm = (s) => s.trim().replace(/\s+/g, ' ');
const year = () => { const d = new Date(); const y = d.getMonth() >= 8 ? d.getFullYear() : d.getFullYear() - 1; return `${y}-${y + 1}`; };
const nice = (m) => (/duplicate key|unique/i.test(m) ? 'Cette classe existe déjà dans l\'école.' : m);

// Choix des matières + combien de devoirs / compositions par trimestre
function SubjectPicker({ subjects, value, onToggle, onPlan, me, reload, setErr, allowManage }) {
  const st = useSettings();
  const [nw, setNw] = useState({ name: '', coef: '1' });
  async function add() {
    if (!nw.name.trim()) return;
    const { data, error } = await supabase.from('subjects').insert({ school_id: me.school_id, name: norm(nw.name), coefficient: Number(nw.coef) || 1 }).select().single();
    if (error) return setErr(error.message);
    setNw({ name: '', coef: '1' }); await reload(); onToggle(data.id);
  }
  async function rename(s) {
    const v = prompt('Nouveau nom de la matière', s.name);
    if (!v || !v.trim()) return;
    const c = prompt('Coefficient', s.coefficient);
    const { error } = await supabase.from('subjects').update({ name: norm(v), coefficient: Number(c) || s.coefficient }).eq('id', s.id);
    if (error) setErr(error.message); else reload();
  }
  async function del(s) {
    if (!confirm(`Supprimer définitivement la matière « ${s.name} » ?`)) return;
    const { error } = await supabase.rpc('delete_subject', { p_id: s.id });
    if (error) setErr(error.message); else reload();
  }
  const chosenIds = Object.keys(value);
  return (
    <div className="lk-stack">
      <div className="chips">
        {subjects.map((s) => (
          <button type="button" key={s.id} className={value[s.id] ? 'on' : ''} onClick={() => onToggle(s.id)}>
            {s.name} <small style={{ color: 'inherit', opacity: .7 }}>coef {s.coefficient}</small>
          </button>
        ))}
        {subjects.length === 0 && <span className="meta">Aucune matière : ajoute-en une ci-dessous.</span>}
      </div>
      {allowManage && subjects.some((s) => s.created_by === me.id) && (
        <div className="meta">Tes matières :{' '}
          {subjects.filter((s) => s.created_by === me.id).map((s) => (
            <span key={s.id} className="tag" style={{ marginRight: 6 }}>{s.name}{' '}
              <a style={{ cursor: 'pointer' }} onClick={() => rename(s)} title="Modifier"><Icon name="edit" size={14} /></a>{' '}
              <a style={{ cursor: 'pointer', color: 'var(--red)' }} onClick={() => del(s)} title="Supprimer"><Icon name="x" size={14} /></a></span>
          ))}
        </div>
      )}
      <div className="lk-inline">
        <input placeholder="Nouvelle matière (ex. Maths)" value={nw.name} onChange={(e) => setNw({ ...nw, name: e.target.value })} />
        <input type="number" min="0.5" step="0.5" value={nw.coef} onChange={(e) => setNw({ ...nw, coef: e.target.value })} style={{ maxWidth: 90 }} title="Coefficient" />
        <button type="button" className="btn-ghost" onClick={add}>+ Ajouter la matière</button>
      </div>
      {chosenIds.length > 0 && (
        <div className="lk-grid-box">
          <b>Ton programme par {periodWord(st)}</b>
          {chosenIds.map((id) => {
            const s = subjects.find((x) => x.id === id); if (!s) return null;
            return (
              <div className="lk-inline" key={id}>
                <span className="person" style={{ minWidth: 110 }}>{s.name}</span>
                <label className="meta">Devoirs</label>
                <input type="number" min="0" max="10" value={value[id].d} onChange={(e) => onPlan(id, 'd', e.target.value)} style={{ maxWidth: 80 }} />
                <label className="meta">Compositions</label>
                <input type="number" min="0" max="5" value={value[id].c} onChange={(e) => onPlan(id, 'c', e.target.value)} style={{ maxWidth: 80 }} />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function Classes() {
  const { profile, status } = useProfile(['admin', 'teacher']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [mine, setMine] = useState([]);       // mes lignes de teaching
  const [counts, setCounts] = useState({});
  const [subs, setSubs] = useState({});
  const [err, setErr] = useState('');
  const [mode, setMode] = useState(null);      // 'create' | classId (rejoindre)
  const [manage, setManage] = useState(null);
  const isTeacher = profile?.role === 'teacher';

  // formulaire de création
  const [name, setName] = useState(''); const [yr, setYr] = useState('');
  useEffect(() => { setYr(year()); }, []);  // la date du jour se lit après l'affichage (exigé par Next.js)
  const [plan, setPlan] = useState({});        // subjectId -> {d,c}
  const [slots, setSlots] = useState([]);
  const [rows, setRows] = useState([]);
  const [busy, setBusy] = useState(false);

  async function load() {
    const [c, s, t, st] = await Promise.all([
      supabase.from('classes').select('id, name, school_year, created_by').order('name'),
      supabase.from('subjects').select('id, name, coefficient, created_by').order('name'),
      supabase.from('teaching').select('class_id, subject_id, devoirs_per_term, compositions_per_term, teacher_id, subjects(name)'),
      supabase.from('students').select('id, class_id'),
    ]);
    setClasses(c.data || []); setSubjects(s.data || []);
    const all = t.data || [];
    setMine(all.filter((x) => x.teacher_id === profile.id));
    const sb = {}; all.forEach((x) => { (sb[x.class_id] ||= new Set()).add(x.subjects?.name); });
    setSubs(Object.fromEntries(Object.entries(sb).map(([k, v]) => [k, [...v]])));
    const cnt = {}; (st.data || []).forEach((x) => { cnt[x.class_id] = (cnt[x.class_id] || 0) + 1; });
    setCounts(cnt);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);
  const reloadSubjects = async () => setSubjects((await supabase.from('subjects').select('id, name, coefficient, created_by').order('name')).data || []);

  const toggleDraft = (id) => setPlan((p) => { const n = { ...p }; if (n[id]) delete n[id]; else n[id] = { d: 2, c: 1 }; return n; });
  const planDraft = (id, k, v) => setPlan((p) => ({ ...p, [id]: { ...p[id], [k]: v } }));

  const duplicate = name.trim() && classes.find((c) => norm(c.name).toLowerCase() === norm(name).toLowerCase() && c.school_year === yr.trim());

  async function create(e) {
    e.preventDefault(); setErr('');
    if (!name.trim()) return setErr('Donne un nom à la classe (ex. 6e A).');
    if (duplicate) return setErr('Cette classe existe déjà : rejoins-la plutôt que de la recréer.');
    const ids = Object.keys(plan);
    if (isTeacher && ids.length === 0) return setErr('Choisis au moins une matière que tu enseignes.');
    for (const s of slots) if (s.end <= s.start) return setErr("Dans les horaires, l'heure de fin doit être après le début.");
    setBusy(true);
    const { data: id, error } = await supabase.rpc('create_class', { p_name: name, p_year: yr, p_subject_ids: ids, p_students: [] });
    if (error) { setBusy(false); return setErr(nice(error.message)); }
    for (const sid of ids) await supabase.from('teaching').update({ devoirs_per_term: Number(plan[sid].d) || 0, compositions_per_term: Number(plan[sid].c) || 0 }).eq('class_id', id).eq('subject_id', sid).eq('teacher_id', profile.id);
    if (slots.length) await supabase.from('timetable').insert(slots.map((s) => ({ school_id: profile.school_id, class_id: id, day: Number(s.day), start_time: s.start, end_time: s.end, subject_id: s.subject_id || null, teacher_id: isTeacher ? profile.id : null })));
    const list = filledRows(rows);
    if (list.length) await supabase.from('students').insert(list.map((r) => ({ school_id: profile.school_id, class_id: id, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—' })));
    setBusy(false); setMode(null); setName(''); setPlan({}); setSlots([]); setRows([]); load();
  }

  async function join(classId) {
    setErr('');
    const ids = Object.keys(plan);
    if (!ids.length) return setErr('Choisis au moins une matière.');
    const { error } = await supabase.rpc('join_class', { p_class_id: classId, p_subject_ids: ids });
    if (error) return setErr(error.message);
    for (const sid of ids) await supabase.from('teaching').update({ devoirs_per_term: Number(plan[sid].d) || 0, compositions_per_term: Number(plan[sid].c) || 0 }).eq('class_id', classId).eq('subject_id', sid).eq('teacher_id', profile.id);
    setMode(null); setPlan({}); load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const myIds = new Set([...mine.map((x) => x.class_id), ...classes.filter((c) => c.created_by === profile.id).map((c) => c.id)]);
  const myClasses = isTeacher ? classes.filter((c) => myIds.has(c.id)) : classes;
  const others = isTeacher ? classes.filter((c) => !myIds.has(c.id)) : [];

  const card = (c, joinable) => (
    <div className="lk-card lift" key={c.id}>
      <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
        <div>
          <h3>{c.name} <small>{c.school_year}</small></h3>
          <span className="meta">{counts[c.id] || 0} élève(s){subs[c.id]?.length ? ' · ' + subs[c.id].join(', ') : ''}</span>
        </div>
        <div className="actions">
          {joinable ? (
            <button className="btn-small" onClick={() => { setMode(mode === c.id ? null : c.id); setPlan({}); }}>Rejoindre</button>
          ) : (
            <>
              <Link className="btn-small" href={`/eleves?classe=${c.id}`}>Élèves</Link>
              <Link className="btn-small" href="/planning">Planning</Link>
              <button className="btn-small btn-ghost" onClick={() => setManage(manage === c.id ? null : c.id)}>{manage === c.id ? 'Fermer' : <><Icon name="edit" size={14} /> Gérer</>}</button>
            </>
          )}
        </div>
      </div>
      {joinable && mode === c.id && (
        <div className="lk-stack">
          <b>Avec quelle(s) matière(s) rejoins-tu {c.name} ?</b>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggleDraft} onPlan={planDraft} me={profile} reload={reloadSubjects} setErr={setErr} allowManage />
          <div><button onClick={() => join(c.id)}>Rejoindre la classe</button></div>
        </div>
      )}
      {!joinable && manage === c.id && <Manage c={c} me={profile} isTeacher={isTeacher} subjects={subjects} mine={mine} reload={load} reloadSubjects={reloadSubjects} setErr={setErr} canEdit={!isTeacher || c.created_by === profile.id} />}
    </div>
  );

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>{isTeacher ? 'Mes classes' : 'Classes'}</h1><div className="sub">Chaque classe est unique dans l'école.</div></div>
        <button onClick={() => { setMode(mode === 'create' ? null : 'create'); setPlan({}); }}>{mode === 'create' ? 'Fermer' : '+ Nouvelle classe'}</button>
      </div>
      {err && <div className="notice">{err}</div>}

      {mode === 'create' && (
        <form className="lk-card lk-stack" onSubmit={create}>
          <div className="lk-step"><b>1</b><h3>La classe</h3></div>
          <div className="lk-inline">
            <input placeholder="Nom (ex. 3e B)" value={name} onChange={(e) => setName(e.target.value)} />
            <input placeholder="Année scolaire" value={yr} onChange={(e) => setYr(e.target.value)} style={{ maxWidth: 160 }} />
          </div>
          {duplicate && (
            <div className="notice">La classe « {duplicate.name} » existe déjà. {isTeacher && <a style={{ cursor: 'pointer', fontWeight: 700 }} onClick={() => { setMode(duplicate.id); setPlan({}); }}>Rejoins-la avec ta matière →</a>}</div>
          )}
          <div className="lk-step"><b>2</b><h3>{isTeacher ? 'Tes matières et ton programme' : 'Les matières'}</h3></div>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggleDraft} onPlan={planDraft} me={profile} reload={reloadSubjects} setErr={setErr} allowManage />
          <div className="lk-step"><b>3</b><h3>Jours et horaires de cours <small>(facultatif)</small></h3></div>
          {slots.map((s, i) => (
            <div className="lk-inline" key={i}>
              <select value={s.day} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, day: e.target.value } : x))}>{DAYS.map((d, k) => <option key={d} value={k + 1}>{d}</option>)}</select>
              <input type="time" value={s.start} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, start: e.target.value } : x))} />
              <input type="time" value={s.end} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, end: e.target.value } : x))} />
              <select value={s.subject_id} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, subject_id: e.target.value } : x))}>
                <option value="">Matière</option>{subjects.filter((x) => plan[x.id]).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
              </select>
              <button type="button" className="btn-small btn-danger" onClick={() => setSlots(slots.filter((_, j) => j !== i))} aria-label="Retirer"><Icon name="x" size={14} /></button>
            </div>
          ))}
          <div><button type="button" className="btn-ghost btn-small" onClick={() => setSlots([...slots, { day: '1', start: '08:00', end: '09:00', subject_id: Object.keys(plan)[0] || '' }])}>+ Ajouter un créneau</button></div>
          <div className="lk-step"><b>4</b><h3>Les élèves</h3></div>
          <StudentGrid rows={rows} setRows={setRows} />
          <button disabled={busy || !!duplicate}>{busy ? 'Création…' : 'Créer la classe'}</button>
        </form>
      )}

      {myClasses.length === 0 && mode !== 'create' && <div className="empty">{isTeacher ? "Tu n'as pas encore de classe. Crée-en une ou rejoins une classe existante." : 'Aucune classe pour le moment.'}</div>}
      {myClasses.map((c) => card(c, false))}

      {others.length > 0 && (
        <>
          <h3 style={{ marginTop: 10 }}>Autres classes de l'école</h3>
          <div className="meta" style={{ marginTop: -12 }}>Tu enseignes dans une de ces classes ? Rejoins-la avec ta matière.</div>
          {others.map((c) => card(c, true))}
        </>
      )}
    </div>
  );
}

// Panneau « Gérer » d'une classe
function Manage({ c, me, isTeacher, subjects, mine, reload, reloadSubjects, setErr, canEdit }) {
  const [name, setName] = useState(c.name);
  const [yr, setYr] = useState(c.school_year);
  const [students, setStudents] = useState([]);
  const [edit, setEdit] = useState(null);
  const [rows, setRows] = useState([]);
  const myRows = mine.filter((x) => x.class_id === c.id);
  const value = Object.fromEntries(myRows.map((x) => [x.subject_id, { d: x.devoirs_per_term, c: x.compositions_per_term }]));
  const [plan, setPlan] = useState(value);
  useEffect(() => setPlan(value), [mine]);

  const loadStudents = async () => setStudents((await supabase.from('students').select('id, first_name, last_name, access_code').eq('class_id', c.id).order('last_name')).data || []);
  useEffect(() => { loadStudents(); }, [c.id]);

  async function saveClass() {
    setErr('');
    const { error } = await supabase.from('classes').update({ name: norm(name), school_year: yr.trim() }).eq('id', c.id);
    if (error) setErr(nice(error.message)); else reload();
  }
  async function toggle(id) {
    setErr('');
    if (plan[id]) {
      if (!confirm('Retirer cette matière de ta classe ? (Les notes déjà saisies sont conservées.)')) return;
      const { error } = await supabase.from('teaching').delete().eq('class_id', c.id).eq('subject_id', id).eq('teacher_id', me.id);
      if (error) return setErr(error.message);
    } else {
      const { error } = await supabase.rpc('join_class', { p_class_id: c.id, p_subject_ids: [id] });
      if (error) return setErr(error.message);
    }
    reload();
  }
  async function savePlan(id, k, v) {
    setPlan((p) => ({ ...p, [id]: { ...p[id], [k]: v } }));
    await supabase.from('teaching').update(k === 'd' ? { devoirs_per_term: Number(v) || 0 } : { compositions_per_term: Number(v) || 0 }).eq('class_id', c.id).eq('subject_id', id).eq('teacher_id', me.id);
  }
  async function addStudents() {
    const list = filledRows(rows); if (!list.length) return;
    const { error } = await supabase.from('students').insert(list.map((r) => ({ school_id: me.school_id, class_id: c.id, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—' })));
    if (error) setErr(error.message); else { setRows([]); loadStudents(); reload(); }
  }
  async function saveStudent() {
    const { error } = await supabase.from('students').update({ first_name: edit.first_name.trim(), last_name: edit.last_name.trim() }).eq('id', edit.id);
    if (error) setErr(error.message); else { setEdit(null); loadStudents(); }
  }
  async function delStudent(s) {
    if (!confirm(`Retirer ${s.first_name} ${s.last_name} (et ses notes) ?`)) return;
    await supabase.from('students').delete().eq('id', s.id); loadStudents(); reload();
  }
  async function delClass() {
    if (!confirm(`Supprimer la classe ${c.name} avec ses élèves et leurs notes ?`)) return;
    const { error } = await supabase.from('classes').delete().eq('id', c.id);
    if (error) setErr(error.message); else reload();
  }

  return (
    <div className="lk-stack" style={{ borderTop: '1px solid var(--line)', paddingTop: 14 }}>
      {canEdit && (
        <div className="lk-inline">
          <input value={name} onChange={(e) => setName(e.target.value)} />
          <input value={yr} onChange={(e) => setYr(e.target.value)} style={{ maxWidth: 150 }} />
          <button className="btn-small" onClick={saveClass}>Enregistrer</button>
        </div>
      )}
      {isTeacher && (
        <>
          <h4>Mes matières dans cette classe</h4>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggle} onPlan={savePlan} me={me} reload={reloadSubjects} setErr={setErr} allowManage />
        </>
      )}
      <h4>Élèves ({students.length})</h4>
      {students.map((s) => (
        <div className="row" key={s.id}>
          {edit?.id === s.id ? (
            <div className="lk-inline" style={{ flex: 1 }}>
              <input value={edit.last_name} onChange={(e) => setEdit({ ...edit, last_name: e.target.value })} />
              <input value={edit.first_name} onChange={(e) => setEdit({ ...edit, first_name: e.target.value })} />
              <button className="btn-small" onClick={saveStudent}>OK</button>
              <button className="btn-small btn-ghost" onClick={() => setEdit(null)}>Annuler</button>
            </div>
          ) : (
            <>
              <div className="person">{s.last_name} {s.first_name} <code>{s.access_code}</code></div>
              <div className="actions"><button className="btn-small btn-ghost" onClick={() => setEdit(s)}>Modifier</button><button className="btn-small btn-danger" onClick={() => delStudent(s)}>Retirer</button></div>
            </>
          )}
        </div>
      ))}
      <StudentGrid rows={rows} setRows={setRows} />
      {rows.length > 0 && <div><button onClick={addStudents}>Ajouter ces élèves</button></div>}
      {canEdit && <div><button className="btn-small btn-danger" onClick={delClass}>Supprimer cette classe</button></div>}
    </div>
  );
}
LAKOL_EOF

save "app/components/Icon.js"
mkdir -p "$(dirname "app/components/Icon.js")"
cat > 'app/components/Icon.js' <<'LAKOL_EOF'
// Icônes SVG de Lakol (style trait fin). Remplacent tous les emojis.
const P = {
  grid: <><rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" /><rect x="3" y="14" width="7" height="7" rx="1.5" /></>,
  users: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></>,
  book: <><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" /><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" /></>,
  user: <><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" /></>,
  calendar: <><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></>,
  edit: <><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" /></>,
  file: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6M16 13H8M16 17H8" /></>,
  mail: <><path d="M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z" /><path d="M22 6l-10 7L2 6" /></>,
  megaphone: <><path d="M3 11v2a1 1 0 0 0 1 1h3l7 4V6L7 10H4a1 1 0 0 0-1 1z" /><path d="M18 8a5 5 0 0 1 0 8" /></>,
  heart: <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z" />,
  shield: <><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" /><path d="M9 12l2 2 4-4" /></>,
  gear: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></>,
  card: <><rect x="1" y="4" width="22" height="16" rx="2" /><path d="M1 10h22" /></>,
  // ajoutées pour remplacer les emojis
  school: <><path d="M3 21h18" /><path d="M5 21V10l7-5 7 5v11" /><path d="M9 21v-6h6v6" /><path d="M12 5V2" /></>,
  cap: <><path d="M22 10L12 5 2 10l10 5z" /><path d="M6 12v5c0 1.5 2.7 3 6 3s6-1.5 6-3v-5" /></>,
  check: <path d="M20 6L9 17l-5-5" />,
  x: <path d="M18 6L6 18M6 6l12 12" />,
  plus: <path d="M12 5v14M5 12h14" />,
  more: <><circle cx="5" cy="12" r="1.2" /><circle cx="12" cy="12" r="1.2" /><circle cx="19" cy="12" r="1.2" /></>,
  download: <><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><path d="M7 10l5 5 5-5M12 15V3" /></>,
  print: <><path d="M6 9V2h12v7" /><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" /><rect x="6" y="14" width="12" height="8" /></>,
  pin: <><path d="M12 17v5" /><path d="M9 3h6l-1 6 4 4v2H6v-2l4-4z" /></>,
  alert: <><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z" /><path d="M12 9v4M12 17h.01" /></>,
  lock: <><rect x="3" y="11" width="18" height="11" rx="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></>,
  phone: <><rect x="6" y="2" width="12" height="20" rx="3" /><path d="M11 18h2" /></>,
  bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" /></>,
  target: <><circle cx="12" cy="12" r="10" /><circle cx="12" cy="12" r="6" /><circle cx="12" cy="12" r="2" /></>,
  sun: <><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></>,
  clock: <><circle cx="12" cy="12" r="10" /><path d="M12 6v6l4 2" /></>,
  chat: <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />,
  bolt: <path d="M13 2L3 14h9l-1 8 10-12h-9z" />,
  bag: <><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" /><path d="M3 6h18" /><path d="M16 10a4 4 0 0 1-8 0" /></>,
  frown: <><circle cx="12" cy="12" r="10" /><path d="M16 16s-1.5-2-4-2-4 2-4 2M9 9h.01M15 9h.01" /></>,
  star: <path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.9L12 17.8 5.8 21.1 7 14.2 2 9.3l6.9-1z" />,
  tag: <><path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L2 12V2h10l8.6 8.6a2 2 0 0 1 0 2.8z" /><path d="M7 7h.01" /></>,
  cash: <><rect x="2" y="6" width="20" height="12" rx="2" /><circle cx="12" cy="12" r="3" /><path d="M6 12h.01M18 12h.01" /></>,
  list: <><path d="M8 6h13M8 12h13M8 18h13" /><path d="M3 6h.01M3 12h.01M3 18h.01" /></>,
  back: <path d="M19 12H5M12 19l-7-7 7-7" />,
  next: <path d="M5 12h14M12 5l7 7-7 7" />,
  logout: <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />,
  eye: <><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></>,
  eyeoff: <><path d="M17.9 17.9A10.1 10.1 0 0 1 12 20c-7 0-11-8-11-8a18.5 18.5 0 0 1 5.1-5.9M9.9 4.2A9.1 9.1 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.2 3.2M14.1 14.1a3 3 0 1 1-4.2-4.2" /><path d="M1 1l22 22" /></>,
  bar: <path d="M18 20V10M12 20V4M6 20v-6" />,
};

export default function Icon({ name, size = 0, className = '', style = undefined }) {
  const s = size ? { width: size, height: size, ...style } : style;
  return <svg className={('ic ' + className).trim()} viewBox="0 0 24 24" aria-hidden="true" style={s}>{P[name] || null}</svg>;
}
LAKOL_EOF

save "app/components/Logo.js"
mkdir -p "$(dirname "app/components/Logo.js")"
cat > 'app/components/Logo.js' <<'LAKOL_EOF'
// Logo Lakol : une arche (la porte de l'école) avec un L dedans, et un point corail.
// Logo = la tuile sombre seule. Wordmark = le nom « lakol. » dessiné en traits.
export default function Logo({ size = 36, id = 'lg', tile = 'dark' }) {
  const bg = tile === 'violet' ? '#6D4AFF' : '#14102E';
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-label="Lakol" role="img" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={tile === 'violet' ? '#FFFFFF' : '#8B5CF6'} />
          <stop offset="1" stopColor={tile === 'violet' ? '#BAF3FA' : '#22D3EE'} />
        </linearGradient>
      </defs>
      <rect width="48" height="48" rx="15" fill={bg} />
      {tile === 'dark' && <rect x=".5" y=".5" width="47" height="47" rx="14.5" fill="none" stroke="#fff" strokeOpacity=".14" />}
      <path d="M11 39V22a13 13 0 0 1 26 0v17z" fill="none" stroke="#fff" strokeWidth="3.6" strokeLinejoin="round" />
      <path d="M20 17v15h9" fill="none" stroke={`url(#${id})`} strokeWidth="4.6" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="31.5" cy="18.5" r="2.7" fill="#FF7A59" />
    </svg>
  );
}

export function Wordmark({ height = 22, color = 'currentColor' }) {
  return (
    <svg height={height} viewBox="-2 0 86 30" role="img" aria-label="lakol" style={{ flexShrink: 0, overflow: 'visible' }}>
      <g fill="none" stroke={color} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 4v22" /><circle cx="17" cy="19" r="7" /><path d="M24 12v14" />
        <path d="M31 4v22M41 12L31 20.5M34.5 18.2L42 26" /><circle cx="55" cy="19" r="7" /><path d="M69 4v22" />
      </g>
      <circle cx="77.5" cy="24.5" r="2.7" fill="#FF7A59" />
    </svg>
  );
}
LAKOL_EOF

save "app/components/MfaCode.js"
mkdir -p "$(dirname "app/components/MfaCode.js")"
cat > 'app/components/MfaCode.js' <<'LAKOL_EOF'
'use client';
import { useState } from 'react';
import { supabase } from '../../lib/supabase';

// Demande le code à 6 chiffres de l'application d'authentification (Google Authenticator, etc.)
export default function MfaCode({ onDone, onCancel }) {
  const [code, setCode] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault(); setErr(''); setBusy(true);
    const { data: f } = await supabase.auth.mfa.listFactors();
    const factors = f?.totp || [];
    if (!factors.length) { setBusy(false); return setErr('Aucun appareil enregistré sur ce compte.'); }
    let ok = false;
    for (const fac of factors) {
      const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: fac.id, code: code.trim() });
      if (!error) { ok = true; break; }
    }
    setBusy(false);
    if (!ok) return setErr('Code incorrect ou expiré. Utilise le code actuel affiché dans ton application.');
    onDone();
  }

  return (
    <form className="auth-box" onSubmit={submit}>
      <h1>Vérification en 2 étapes</h1>
      <p className="meta" style={{ margin: 0 }}>Ouvre ton application d'authentification et écris le code à 6 chiffres de Lakol.</p>
      <input inputMode="numeric" autoComplete="one-time-code" autoFocus maxLength={6} placeholder="000000" value={code}
        onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} style={{ textAlign: 'center', fontSize: '1.5rem', letterSpacing: '.4em' }} />
      {err && <div className="notice">{err}</div>}
      <button disabled={busy || code.length !== 6}>{busy ? '…' : 'Valider'}</button>
      {onCancel && <button type="button" className="btn-ghost" onClick={onCancel}>Annuler</button>}
    </form>
  );
}
LAKOL_EOF

save "app/components/StudentFile.js"
mkdir -p "$(dirname "app/components/StudentFile.js")"
cat > 'app/components/StudentFile.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { KINDS, KindIcon } from '../../lib/kinds';
import { subjectAvg, generalAvg, appreciation, wDOf, fmt, fcfa, METHODS } from '../../lib/grades';
import { useSettings } from '../../lib/useSettings';
import { periodList, periodShort } from '../../lib/settings';
import Icon from './Icon';

// Fiche élève. role = 'admin' | 'teacher' | 'parent'.
// La scolarité (frais, paiements) n'est affichée qu'au directeur et aux parents.
export default function StudentFile({ studentId, role }) {
  const [student, setStudent] = useState(null);
  const [grades, setGrades] = useState([]);
  const [fees, setFees] = useState([]);
  const [payments, setPayments] = useState([]);
  const [att, setAtt] = useState([]);
  const [behav, setBehav] = useState([]);
  const [todo, setTodo] = useState([]);
  const [loading, setLoading] = useState(true);
  const [coefs, setCoefs] = useState({});
  const st = useSettings();
  const showMoney = role === 'admin' || role === 'parent';

  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data: s } = await supabase.from('students')
        .select('id, first_name, last_name, class_id, matricule, access_code, classes(name, school_year)')
        .eq('id', studentId).maybeSingle();
      setStudent(s);
      const { data: cc } = s?.class_id ? await supabase.from('class_coefficients').select('subject_id, coefficient').eq('class_id', s.class_id) : { data: [] };
      setCoefs(Object.fromEntries((cc || []).map((x) => [x.subject_id, Number(x.coefficient)])));
      const { data: g } = await supabase.from('grades')
        .select('id, term, kind, score, title, subject_id, created_at, subjects(name, coefficient)')
        .eq('student_id', studentId).order('created_at', { ascending: false });
      setGrades(g || []);
      const [a, b, t] = await Promise.all([
        supabase.from('attendance').select('id, date, status').eq('student_id', studentId).neq('status', 'present').order('date', { ascending: false }),
        supabase.from('behavior_notes').select('id, date, kind, comment').eq('student_id', studentId).order('date', { ascending: false }),
        s?.class_id ? supabase.from('assignments').select('id, kind, title, due_date, chapters, subjects(name)').eq('class_id', s.class_id).gte('due_date', new Date().toISOString().slice(0, 10)).order('due_date') : { data: [] },
      ]);
      setAtt(a.data || []); setBehav(b.data || []); setTodo(t.data || []);
      if (showMoney && s) {
        const [f, p] = await Promise.all([
          s.class_id ? supabase.from('fees').select('id, label, amount').or(`class_id.eq.${s.class_id},class_id.is.null`) : supabase.from('fees').select('id, label, amount').is('class_id', null),
          supabase.from('payments').select('id, amount, method, paid_at, fee_id').eq('student_id', studentId).order('paid_at', { ascending: false }),
        ]);
        setFees(f.data || []);
        setPayments(p.data || []);
      }
      setLoading(false);
    })();
  }, [studentId, showMoney]);

  if (loading) return <p className="meta">Chargement…</p>;
  if (!student) return <div className="empty">Élève introuvable.</div>;

  // matières
  const bySubject = {};
  grades.forEach((g) => {
    const id = g.subject_id;
    if (!bySubject[id]) bySubject[id] = { name: g.subjects?.name || '?', coef: coefs[id] ?? g.subjects?.coefficient ?? 1, list: [] };
    bySubject[id].list.push(g);
  });
  const subjects = Object.values(bySubject).sort((a, b) => a.name.localeCompare(b.name));
  const wD = wDOf(st), periods = periodList(st);
  const termAvgs = periods.map((t) =>
    generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list.filter((g) => g.term === t), wD), coef: s.coef })))
  );
  const yearAvg = generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list, wD), coef: s.coef })));

  const due = fees.reduce((s, f) => s + f.amount, 0);
  const paid = payments.reduce((s, p) => s + p.amount, 0);
  const left = Math.max(0, due - paid);
  const pct = due ? Math.min(100, Math.round((paid / due) * 100)) : 0;

  return (
    <div className="lk-stack">
      <div className="lk-card sf-head">
        <div className="sf-avatar">{(student.first_name[0] || '') + (student.last_name[0] || '')}</div>
        <div className="sf-id">
          <h2>{student.first_name} {student.last_name}</h2>
          <div className="meta">{student.classes?.name || 'Sans classe'} · {student.classes?.school_year || ''}</div>
          {role !== 'parent' && student.access_code && (
            <div className="meta">Code parent : <code>{student.access_code}</code></div>
          )}
        </div>
        <div className="sf-score">
          <span>{fmt(yearAvg)}</span>
          <small>{yearAvg != null ? appreciation(yearAvg, st) : 'Pas de notes'}</small>
        </div>
      </div>

      {todo.length > 0 && (
        <div className="lk-card">
          <h3><Icon name="calendar" /> À venir pour la classe</h3>
          <div className="sf-todo">
          {todo.map((x) => {
            const n = Math.round((new Date(x.due_date) - new Date(new Date().toISOString().slice(0, 10))) / 864e5);
            const d = new Date(x.due_date);
            const k = x.kind === 'devoir' ? 'mid' : 'bad';
            return (
              <div className="sf-item" key={x.id}>
                <div className={'sf-date ' + k}><b>{d.getDate()}</b><small>{d.toLocaleDateString('fr-FR', { month: 'short' }).replace('.', '')}</small></div>
                <div className="sf-info">
                  <strong>{x.title}</strong>
                  <div className="sf-sub">
                    <span className={'badge ' + k}>{x.kind === 'devoir' ? 'Devoir' : x.kind === 'examen' ? 'Examen' : 'Composition'}</span>
                    {x.subjects?.name && <span className="tag">{x.subjects.name}</span>}
                  </div>
                  {x.chapters && <span className="meta">Chapitres : {x.chapters}</span>}
                </div>
                <span className={'sf-when' + (n <= 2 ? ' soon' : '')}>{n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} j`}</span>
              </div>
            );
          })}
          </div>
        </div>
      )}

      <div className="lk-card">
        <h3>Notes par matière</h3>
        {subjects.length === 0 ? <div className="empty">Aucune note pour le moment.</div> : (
          <div className="sf-subjects">
            {subjects.map((s) => {
              const v = subjectAvg(s.list, wD);
              const low = v != null && v < st.pass_mark;
              return (
                <div className="sf-subj" key={s.name}>
                  <div className="sf-subj-top">
                    <div><strong>{s.name}</strong><small>coef {s.coef}</small></div>
                    <span className={'sf-val' + (low ? ' low' : '')}>{fmt(v)}</span>
                  </div>
                  <div className="sf-track"><i className={low ? 'low' : ''} style={{ width: (v != null ? Math.min(100, (v / st.scale) * 100) : 0) + '%' }} /></div>
                  <div className="sf-terms">
                    {periods.map((t) => {
                      const tv = subjectAvg(s.list.filter((g) => g.term === t), wD);
                      return <span key={t} className={tv != null && tv < st.pass_mark ? 'low' : ''}>{periodShort(t, st)} <b>{fmt(tv)}</b></span>;
                    })}
                  </div>
                </div>
              );
            })}
            <div className="sf-general">
              <span>Moyenne générale</span>
              <div>{termAvgs.map((v, i) => <small key={i}>{periodShort(periods[i], st)} <b>{fmt(v)}</b></small>)}<strong>{fmt(yearAvg)}</strong></div>
            </div>
          </div>
        )}
        {grades.length > 0 && (
          <details className="lk-details">
            <summary>Voir toutes les notes ({grades.length})</summary>
            {grades.map((g) => (
              <div className="row" key={g.id}>
                <div className="person">{g.subjects?.name} <span className="tag">{g.title || (g.kind === 'devoir' ? 'Devoir' : 'Composition')} · {g.kind === 'devoir' ? 'Devoir' : 'Composition'} · {periodShort(g.term, st)}</span></div>
                <span className="score">{fmt(g.score)}/{st.scale}</span>
              </div>
            ))}
          </details>
        )}
      </div>

      <div className="lk-card">
        <h3>Vie scolaire</h3>
        <div className="lk-inline">
          <span className="badge bad">{att.filter((a) => a.status === 'absent').length} absence(s)</span>
          <span className="badge mid">{att.filter((a) => a.status === 'late').length} retard(s)</span>
          <span className="badge">{behav.length} remarque(s)</span>
        </div>
        {behav.length === 0 && att.length === 0 && <span className="meta">Rien à signaler pour le moment</span>}
        {behav.map((b) => (
          <div className="row" key={b.id}>
            <div className="person"><KindIcon k={b.kind} /> <span className={'badge ' + (b.kind === 'positif' ? 'ok' : 'bad')}>{KINDS[b.kind]?.[0]}</span> {b.comment && <span className="meta">{b.comment}</span>}</div>
            <span className="meta">{new Date(b.date).toLocaleDateString('fr-FR')}</span>
          </div>
        ))}
        {att.length > 0 && (
          <details className="lk-details"><summary>Absences et retards</summary>
            {att.map((a) => <div className="row" key={a.id}><div className="person">{new Date(a.date).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</div><span className={'badge ' + (a.status === 'absent' ? 'bad' : 'mid')}>{a.status === 'absent' ? 'Absent' : 'En retard'}</span></div>)}
          </details>
        )}
      </div>

      {showMoney && (
        <div className="lk-card">
          <h3>Scolarité</h3>
          {fees.length === 0 ? <div className="empty">Aucun frais défini pour cette classe.</div> : (
            <>
              <div className="stats">
                <div className="stat"><small>À payer au total</small><strong>{fcfa(due)}</strong></div>
                <div className="stat"><small>Déjà payé</small><strong className="lk-ok">{fcfa(paid)}</strong></div>
                <div className="stat"><small>Reste à payer</small><strong className={left ? 'lk-warn' : 'lk-ok'}>{left ? fcfa(left) : 'Soldé'}</strong></div>
              </div>
              <div className="bar"><div style={{ width: pct + '%' }} /></div>
              <div className="meta">{pct}% réglé</div>
              {fees.map((f) => <div className="row" key={f.id}><div className="person">{f.label}</div><span>{fcfa(f.amount)}</span></div>)}
            </>
          )}
          {payments.length > 0 && (
            <details className="lk-details" open>
              <summary>Historique des paiements</summary>
              {payments.map((p) => (
                <div className="row" key={p.id}>
                  <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                  <span>{fcfa(p.amount)}</span>
                </div>
              ))}
            </details>
          )}
        </div>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/components/StudentGrid.js"
mkdir -p "$(dirname "app/components/StudentGrid.js")"
cat > 'app/components/StudentGrid.js' <<'LAKOL_EOF'
'use client';
import { useState } from 'react';
import Icon from './Icon';

// "Combien d'élèves ?" -> des cases vides apparaissent pour écrire les noms.
export default function StudentGrid({ rows, setRows }) {
  const [count, setCount] = useState('');

  function generate() {
    const n = Math.max(0, Math.min(200, parseInt(count, 10) || 0));
    if (!n) return;
    const next = rows.slice(0, n);
    while (next.length < n) next.push({ last: '', first: '' });
    setRows(next);
  }
  const update = (i, k, v) => setRows(rows.map((r, j) => (j === i ? { ...r, [k]: v } : r)));
  const remove = (i) => setRows(rows.filter((_, j) => j !== i));

  return (
    <div className="lk-grid-box">
      <div className="lk-inline">
        <label className="lk-label">Combien d'élèves dans la classe ?</label>
        <input type="number" min="1" max="200" placeholder="ex. 35" value={count}
          onChange={(e) => setCount(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); generate(); } }}
          style={{ maxWidth: 120 }} />
        <button type="button" className="btn-ghost" onClick={generate}>Créer les cases</button>
      </div>

      {rows.length > 0 && (
        <>
          <div className="lk-rows">
            {rows.map((r, i) => (
              <div className="lk-rowline" key={i}>
                <span className="lk-num">{i + 1}</span>
                <input placeholder="Nom" value={r.last} onChange={(e) => update(i, 'last', e.target.value)} />
                <input placeholder="Prénom" value={r.first} onChange={(e) => update(i, 'first', e.target.value)} />
                <button type="button" className="btn-small btn-danger" title="Retirer" aria-label="Retirer" onClick={() => remove(i)}><Icon name="x" size={14} /></button>
              </div>
            ))}
          </div>
          <div className="lk-inline">
            <button type="button" className="btn-ghost btn-small"
              onClick={() => setRows([...rows, { last: '', first: '' }])}>+ Ajouter une case</button>
            <span className="meta">{rows.filter((r) => r.last.trim() || r.first.trim()).length} / {rows.length} remplie(s)</span>
          </div>
        </>
      )}
    </div>
  );
}

export const filledRows = (rows) => rows.filter((r) => r.last.trim() || r.first.trim());
LAKOL_EOF

save "app/dashboard/page.js"
mkdir -p "$(dirname "app/dashboard/page.js")"
cat > 'app/dashboard/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, fmt, METHODS } from '../../lib/grades';
import { useSettings } from '../../lib/useSettings';
import { periodList, periodShort } from '../../lib/settings';
import Icon from '../components/Icon';

export default function Dashboard() {
  const { profile, status } = useProfile(['admin']);
  const st = useSettings(status === 'ok');
  const [term, setTerm] = useState(null);
  const [d, setD] = useState(null);
  const [code, setCode] = useState('');
  const [err, setErr] = useState('');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.rpc('dashboard_overview', { p_term: term }).then(({ data, error }) => {
      if (error) setErr(error.message); else setD(data);
    });
  }, [status, term]);
  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('school_secrets').select('join_code').maybeSingle().then(({ data }) => setCode(data?.join_code || ''));
  }, [status]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const rate = d && d.total_due ? Math.round((d.total_paid / d.total_due) * 100) : 0;
  return (
    <div className="lk-page">
      <div className="hero">
      <div className="topbar">
        <div><h1>Bonjour {profile.full_name.split(' ')[0]}</h1><div className="sub">{new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })} · vue d'ensemble de l'école</div></div>
        <div className="tabs">
          {[[null, 'Année'], ...periodList(st).map((t) => [t, periodShort(t, st)])].map(([v, l]) => (
            <button key={l} className={term === v ? 'on' : ''} onClick={() => setTerm(v)}>{l}</button>
          ))}
        </div>
      </div>
      </div>
      {err && <div className="notice">{err}</div>}
      {!d ? <p className="meta">Chargement…</p> : (
        <>
          <div className="stats">
            <div className="stat"><i><Icon name="cap" /></i><small>Élèves</small><strong>{d.students}</strong></div>
            <div className="stat c2"><i><Icon name="book" /></i><small>Classes</small><strong>{d.classes}</strong></div>
            <div className="stat c3"><i><Icon name="users" /></i><small>Professeurs</small><strong>{d.teachers}</strong></div>
            <div className="stat c4"><i><Icon name="cash" /></i><small>Scolarité encaissée</small><strong className="lk-ok">{fcfa(d.total_paid)}</strong><small>sur {fcfa(d.total_due)}</small></div>
          </div>
          <div className="grid2">
            <div className="lk-card lk-inline" style={{ flexWrap: 'nowrap', flexDirection: 'row' }}>
              <div className="donut" style={{ '--p': Math.min(100, rate) }}><span>{rate}%<small>réglé</small></span></div>
              <div><h3>Recouvrement</h3><p className="meta" style={{ margin: '4px 0' }}>Reste à encaisser</p><strong className="lk-warn" style={{ fontSize: '1.4rem' }}>{fcfa(Math.max(0, d.total_due - d.total_paid))}</strong></div>
            </div>
            <div className="lk-card">
              <h3>Moyenne par classe</h3>
              {d.class_stats.filter((c) => c.average != null).length === 0 ? <span className="meta">Pas encore de notes.</span> :
                d.class_stats.filter((c) => c.average != null).map((c) => (
                  <div className="hbar" key={c.id}><span>{c.name}</span><div className="track"><div className={'fill' + (c.average < st.pass_mark ? ' low' : '')} style={{ width: (c.average / st.scale) * 100 + '%' }} /></div><b>{fmt(c.average)}</b></div>
                ))}
            </div>
          </div>
          

          <div className="lk-card">
            <h3>Classes</h3>
            {d.class_stats.length === 0 ? <div className="empty">Aucune classe pour l'instant. Un professeur ou toi peut en créer une dans « Classes ».</div> : (
              <div className="lk-scroll"><table className="data">
                <thead><tr><th>Classe</th><th>Élèves</th><th>Moyenne</th><th>En difficulté (&lt;10)</th><th></th></tr></thead>
                <tbody>{d.class_stats.map((c) => (
                  <tr key={c.id}>
                    <td>{c.name} <small className="meta">{c.school_year}</small></td>
                    <td>{c.students}</td>
                    <td className={c.average != null && c.average < st.pass_mark ? 'lk-low' : ''}>{fmt(c.average)}</td>
                    <td>{c.struggling > 0 ? <span className="badge bad">{c.struggling}</span> : '–'}</td>
                    <td><Link href={`/eleves?classe=${c.id}`}>Voir les élèves →</Link></td>
                  </tr>
                ))}</tbody>
              </table></div>
            )}
          </div>

          <div className="grid2">
            <div className="lk-card">
              <h3>Impayés les plus élevés</h3>
              {d.top_unpaid.length === 0 ? <div className="empty">Tout est à jour</div> : d.top_unpaid.map((s) => (
                <Link className="row" href={`/eleves/${s.id}`} key={s.id}>
                  <div className="person">{s.first_name} {s.last_name} <span className="tag">{s.class_name}</span></div>
                  <strong className="lk-warn">{fcfa(s.remaining)}</strong>
                </Link>
              ))}
              <Link href="/paiements">Gérer la scolarité →</Link>
            </div>
            <div className="lk-card">
              <h3>Derniers paiements</h3>
              {d.recent_payments.length === 0 ? <div className="empty">Aucun paiement enregistré.</div> : d.recent_payments.map((p) => (
                <div className="row" key={p.id}>
                  <div className="person">{p.first_name} {p.last_name} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                  <strong className="lk-ok">{fcfa(p.amount)}</strong>
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      <div className="grid2">
        <a className="lk-card lift" href="/annonces"><h3><Icon name="megaphone" /> Annonces</h3><span className="meta">Publie une information pour tous : pas de cours, réunion, rentrée… Les parents sont prévenus par email.</span><b>Écrire une annonce →</b></a>
        <a className="lk-card lift" href="/messages"><h3><Icon name="chat" /> Messages</h3><span className="meta">Écris à un parent, à un professeur, ou envoie un message groupé à toute une classe.</span><b>Ouvrir la messagerie →</b></a>
      </div>

      <div className="lk-card lk-inline">
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0 }}>Code de l'école (pour inviter les professeurs)</h3>
          <span className="meta">Donne ce code à chaque professeur : il le saisit à son inscription.</span>
        </div>
        <code className="lk-code">{code || '…'}</code>
        <button className="btn-ghost" onClick={() => { navigator.clipboard?.writeText(code); setCopied(true); setTimeout(() => setCopied(false), 1500); }}>{copied ? 'Copié' : 'Copier'}</button>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/eleves/[id]/page.js"
mkdir -p "$(dirname "app/eleves/[id]/page.js")"
cat > 'app/eleves/[id]/page.js' <<'LAKOL_EOF'
'use client';
import { useParams, useRouter } from 'next/navigation';
import StudentFile from '../../components/StudentFile';
import { useProfile, Blocked } from '../../../lib/useProfile';
import Icon from '../../components/Icon';

export default function FicheEleve() {
  const { id } = useParams();
  const router = useRouter();
  const { profile, status } = useProfile(['admin', 'teacher']);
  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  return (
    <div className="lk-page">
      <button className="btn-ghost btn-small" onClick={() => router.back()}><Icon name="back" size={16} /> Retour</button>
      <StudentFile studentId={id} role={profile.role} />
    </div>
  );
}
LAKOL_EOF

save "app/eleves/page.js"
mkdir -p "$(dirname "app/eleves/page.js")"
cat > 'app/eleves/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentGrid, { filledRows } from '../components/StudentGrid';

export default function Eleves() {
  const { profile, status } = useProfile(['admin', 'teacher']);
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [classId, setClassId] = useState('');
  const [q, setQ] = useState('');
  const [adding, setAdding] = useState(false);
  const [target, setTarget] = useState('');
  const [rows, setRows] = useState([]);
  const [edit, setEdit] = useState(null);
  const [err, setErr] = useState('');

  async function load() {
    const [s, c] = await Promise.all([
      supabase.from('students').select('id, first_name, last_name, class_id, access_code, classes(name)').order('last_name'),
      supabase.from('classes').select('id, name').order('name'),
    ]);
    setStudents(s.data || []); setClasses(c.data || []);
  }
  useEffect(() => {
    if (status !== 'ok') return;
    const c = new URLSearchParams(window.location.search).get('classe');
    if (c) setClassId(c);
    load();
  }, [status]);

  async function saveAll(e) {
    e.preventDefault(); setErr('');
    const list = filledRows(rows);
    if (!target) return setErr('Choisis la classe.');
    if (!list.length) return setErr('Écris au moins un nom.');
    const { error } = await supabase.from('students').insert(list.map((r) => ({
      school_id: profile.school_id, class_id: target, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—',
    })));
    if (error) return setErr(error.message);
    setRows([]); setAdding(false); load();
  }
  async function saveEdit() {
    const { error } = await supabase.from('students').update({
      first_name: edit.first_name.trim(), last_name: edit.last_name.trim(), class_id: edit.class_id || null,
    }).eq('id', edit.id);
    if (error) setErr(error.message); else { setEdit(null); load(); }
  }
  async function del(s) {
    if (!confirm(`Supprimer ${s.first_name} ${s.last_name} et toutes ses notes ?`)) return;
    await supabase.from('students').delete().eq('id', s.id); load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const shown = students.filter((s) => (!classId || s.class_id === classId) && `${s.first_name} ${s.last_name}`.toLowerCase().includes(q.toLowerCase()));

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Élèves <small className="meta">({shown.length})</small></h1>
        <button onClick={() => { setAdding(!adding); setTarget(classId || classes[0]?.id || ''); }}>{adding ? 'Fermer' : '+ Ajouter des élèves'}</button>
      </div>
      {err && <div className="notice">{err}</div>}

      {adding && (
        <form className="lk-card lk-stack" onSubmit={saveAll}>
          {classes.length === 0 ? <div className="empty">Crée d'abord une classe dans « Classes ».</div> : (
            <>
              <div className="lk-inline">
                <label className="lk-label">Classe</label>
                <select value={target} onChange={(e) => setTarget(e.target.value)}>
                  {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <StudentGrid rows={rows} setRows={setRows} />
              <button disabled={!filledRows(rows).length}>Enregistrer {filledRows(rows).length || ''} élève(s)</button>
            </>
          )}
        </form>
      )}

      <div className="lk-inline">
        <input placeholder="Rechercher…" value={q} onChange={(e) => setQ(e.target.value)} />
        <select value={classId} onChange={(e) => setClassId(e.target.value)}>
          <option value="">Toutes les classes</option>
          {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>

      {shown.length === 0 && <div className="empty">Aucun élève. Utilise « Ajouter des élèves ».</div>}
      {shown.map((s) => (
        <div className="row" key={s.id}>
          {edit?.id === s.id ? (
            <div className="lk-inline" style={{ flex: 1 }}>
              <input value={edit.last_name} onChange={(e) => setEdit({ ...edit, last_name: e.target.value })} />
              <input value={edit.first_name} onChange={(e) => setEdit({ ...edit, first_name: e.target.value })} />
              <select value={edit.class_id || ''} onChange={(e) => setEdit({ ...edit, class_id: e.target.value })}>
                {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              <button className="btn-small" onClick={saveEdit}>OK</button>
              <button className="btn-small btn-ghost" onClick={() => setEdit(null)}>Annuler</button>
            </div>
          ) : (
            <>
              <Link href={`/eleves/${s.id}`} className="person">
                <span className="avatar">{(s.first_name[0] || '') + (s.last_name[0] || '')}</span>
                {s.first_name} {s.last_name} <span className="tag">{s.classes?.name || 'Sans classe'}</span>
              </Link>
              <div className="actions">
                <code title="Code à donner aux parents">{s.access_code}</code>
                <button className="btn-small btn-ghost" onClick={() => setEdit(s)}>Modifier</button>
                <button className="btn-small btn-danger" onClick={() => del(s)}>Supprimer</button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
LAKOL_EOF

save "app/globals.css"
mkdir -p "$(dirname "app/globals.css")"
cat > 'app/globals.css' <<'LAKOL_EOF'
/* ===== LAKOL — design "arche" : encre, violet, turquoise, un accent corail ===== */
:root{
  color-scheme:light dark;
  --ink:#14102E; --bg:#F6F5FB; --surface:#fff; --surface2:#F9F8FD; --hover:#F4F2FC; --line:#E7E4F2;
  --text:#14102E; --muted:#6A6786; --faint:#A09DBA;
  --brand:#6D4AFF; --btn:#6D4AFF; --brand-soft:#EFEBFF; --brand-ink:#5233E0;
  --teal:#0EA5A4; --teal-soft:#DDF6F3; --teal-ink:#0B7F7E;
  --coral:#FF7A59; --coral-soft:#FFEAE4;
  --amber:#E39A0B; --amber-soft:#FFF1D6; --amber-ink:#8A5A00;
  --green:#12A150; --green-soft:#DDF6E7; --green-ink:#0B6B4B;
  --red:#E5484D; --red-soft:#FFE6E6;
  --blue:#3B82F6; --blue-soft:#E3EEFF;
  --input-bg:#fff; --track:#ECE9F7;
  --radius:16px; --shadow:0 1px 2px rgba(80,60,200,.06),0 10px 28px rgba(80,60,200,.07);
  --sheet-shadow:0 -12px 40px rgba(20,16,46,.22);
  --page-glow:radial-gradient(1000px 420px at 88% -8%,#E4DCFF 0%,transparent 62%);
  --side:#FFFFFF; --side-text:#14102E; --side-muted:#6A6786; --side-hover:#F4F1FF; --side-on:#EFEBFF; --side-on-text:#4C2FD6; --side-bar:#6D4AFF; --side-user:#F6F4FF; --side-line:#E7E4F2;
  --hero-bg:linear-gradient(135deg,#EAE4FF 0%,#D2C6FF 100%); --hero-text:#14102E; --hero-sub:#4C4670; --hero-art:rgba(255,255,255,.62); --hero-art-line:rgba(255,255,255,.95);
  --hero-tabs:rgba(255,255,255,.6); --hero-tabs-line:rgba(109,74,255,.2); --hero-tab-text:#4C4670; --hero-tab-on-bg:#14102E; --hero-tab-on-text:#fff; --hero-border:rgba(109,74,255,.16);
}
@media (prefers-color-scheme:dark){
  :root{
    --ink:#0A0818; --bg:#0D0A1F; --surface:#16122B; --surface2:#1B1635; --hover:#1D1838; --line:#2A2447;
    --text:#EEEBFF; --muted:#A29EC4; --faint:#6F6A94;
    --brand:#9B82FF; --btn:#7557FF; --brand-soft:#2A2250; --brand-ink:#C3B5FF;
    --teal:#2DD4BF; --teal-soft:#0F2F2E; --teal-ink:#5EEAD4;
    --coral:#FF8A6B; --coral-soft:#3A2220;
    --amber:#FBBF24; --amber-soft:#33280F; --amber-ink:#FCD98A;
    --green:#34D399; --green-soft:#0F2E22; --green-ink:#86EFC0;
    --red:#FF7A7F; --red-soft:#3A1C20;
    --blue:#60A5FA; --blue-soft:#15233F;
    --input-bg:#110E24; --track:#2A2447;
    --shadow:0 1px 0 rgba(255,255,255,.04) inset,0 12px 32px rgba(0,0,0,.35);
    --sheet-shadow:0 -12px 40px rgba(0,0,0,.6);
    --page-glow:radial-gradient(1000px 520px at 88% -10%,rgba(109,74,255,.24) 0%,transparent 62%);
    --side:#090716; --side-text:#EEEBFF; --side-muted:rgba(238,235,255,.62); --side-hover:rgba(255,255,255,.07); --side-on:rgba(255,255,255,.1); --side-on-text:#fff; --side-bar:#22D3EE; --side-user:rgba(255,255,255,.06); --side-line:rgba(255,255,255,.06);
    --hero-bg:linear-gradient(125deg,#14102E 0%,#2A1F7A 100%); --hero-text:#fff; --hero-sub:rgba(255,255,255,.78); --hero-art:rgba(255,255,255,.05); --hero-art-line:rgba(255,255,255,.16);
    --hero-tabs:rgba(255,255,255,.1); --hero-tabs-line:rgba(255,255,255,.1); --hero-tab-text:rgba(255,255,255,.8); --hero-tab-on-bg:#fff; --hero-tab-on-text:#14102E; --hero-border:rgba(255,255,255,.07);
  }
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
html{-webkit-text-size-adjust:100%;text-size-adjust:100%}
body{font-family:"Plus Jakarta Sans",system-ui,-apple-system,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);font-size:15px;line-height:1.5;-webkit-font-smoothing:antialiased;overflow-x:hidden;-webkit-tap-highlight-color:transparent;background-image:var(--page-glow);background-repeat:no-repeat}
a{color:var(--brand);text-decoration:none}
h1{font-size:1.65rem;margin:0;letter-spacing:-.025em;font-weight:800;line-height:1.2}
h2{font-size:1.2rem;margin:0;font-weight:700;letter-spacing:-.01em}
h3{font-size:1rem;margin:0;font-weight:700}
h4{font-size:.9rem;margin:0}
code{font-family:ui-monospace,Menlo,monospace;background:var(--brand-soft);border-radius:8px;padding:2px 8px;font-size:.82rem;color:var(--brand-ink);font-weight:600}
small{color:var(--muted)}
.meta{color:var(--muted);font-size:.86rem}

/* icônes */
.ic{display:inline-block;width:1.15em;height:1.15em;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round;vertical-align:-.22em;flex-shrink:0}
button .ic{margin-right:2px}
.lk-card h3 .ic{color:var(--brand);margin-right:4px}

.lk-shell{display:flex;min-height:100vh;position:relative}
.lk-main{flex:1;min-width:0}
.lk-page{max-width:1120px;margin:0 auto;padding:30px 30px 90px;display:flex;flex-direction:column;gap:20px}
.lk-stack{display:flex;flex-direction:column;gap:16px}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
.topbar .sub{color:var(--muted);font-size:.92rem;margin-top:3px}

/* bandeau d'accueil : encre, avec une arche en filigrane */
.hero{position:relative;overflow:hidden;border-radius:24px;padding:30px 32px;min-height:150px;color:var(--hero-text);background:var(--hero-bg);border:1px solid var(--hero-border)}
.hero h1{color:var(--hero-text);font-size:1.75rem}
.hero .sub{color:var(--hero-sub);margin-top:4px}
.hero:before{content:"";position:absolute;right:300px;bottom:0;width:132px;height:132px;background:var(--hero-art);border:3px solid var(--hero-art-line);border-bottom:0;border-radius:66px 66px 0 0}
.hero:after{content:"";position:absolute;right:292px;top:18px;width:16px;height:16px;border-radius:50%;background:var(--coral)}
.hero>*{position:relative;z-index:1}

/* menu latéral */
.lk-side{width:248px;flex-shrink:0;background:var(--side);padding:20px 14px;display:flex;flex-direction:column;gap:6px;position:sticky;top:0;height:100vh;color:var(--side-text);border-right:1px solid var(--side-line)}
.lk-brand{display:flex;align-items:center;gap:11px;padding:4px 10px 18px;font-weight:800;font-size:1.4rem;letter-spacing:-.03em;color:var(--side-text)}
.lk-navlabel{font-size:.68rem;text-transform:uppercase;letter-spacing:.12em;color:var(--side-muted);opacity:.8;padding:12px 12px 4px}
.lk-links{display:flex;flex-direction:column;gap:2px;flex:1;overflow-y:auto}
.lk-links a{display:flex;align-items:center;gap:12px;padding:10px 14px;border-radius:12px;color:var(--side-muted);font-weight:600;font-size:.9rem;transition:background .15s,color .15s}
.lk-links a svg{width:19px;height:19px;flex-shrink:0;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.lk-links a:hover{background:var(--side-hover);color:var(--side-text)}
.lk-links a.on{background:var(--side-on);color:var(--side-on-text);box-shadow:inset 3px 0 0 var(--side-bar)}
.lk-links a.on svg{color:var(--side-bar)}
.lk-user{display:flex;align-items:center;gap:10px;padding:10px 12px;background:var(--side-user);border-radius:14px}
.lk-user .who{flex:1;min-width:0}
.lk-user b{display:block;font-size:.86rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--side-text)}
.lk-user span{font-size:.74rem;color:var(--side-muted)}
.nav-logout{background:var(--side-hover);border:0;color:var(--side-text);cursor:pointer;padding:8px;min-height:0;border-radius:10px;display:flex;box-shadow:none}
.nav-logout:hover{background:var(--coral);color:#fff;filter:none;box-shadow:none}
.nav-logout svg{width:17px;height:17px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}

/* cartes */
.lk-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:20px;display:flex;flex-direction:column;gap:12px;box-shadow:var(--shadow);transition:border-color .15s}
.lk-card.lift:hover,a.lk-card:hover{border-color:var(--brand)}
.lk-off{opacity:.55}
.lk-inline{display:flex;flex-wrap:wrap;gap:10px;align-items:center}
.lk-inline input,.lk-inline select{flex:1;min-width:120px}
.lk-label{font-size:.85rem;color:var(--muted);font-weight:600}
.lk-scroll{overflow-x:auto}
.lk-ok{color:var(--green)}.lk-warn{color:var(--amber)}.lk-low{color:var(--red)}
.lk-past{opacity:.5}
.lk-code{font-family:ui-monospace,Menlo,monospace;font-size:1.2rem;letter-spacing:.2em;padding:8px 16px;border-radius:12px;background:var(--brand-soft);border:1.5px dashed var(--brand);color:var(--brand-ink);font-weight:700}
.lk-details summary{cursor:pointer;color:var(--muted);font-size:.9rem;margin:6px 0;font-weight:600}
.lk-hero{flex-direction:row;align-items:center;flex-wrap:wrap;gap:18px}
.lk-hero .avatar{width:64px;height:64px;font-size:1.3rem}
.lk-bigscore{text-align:center;padding:12px 22px;border-radius:16px;background:var(--teal-soft)}
.lk-bigscore span{display:block;font-size:2rem;font-weight:800;color:var(--teal-ink);line-height:1.1}
.lk-bigscore small{color:var(--teal-ink)}
.lk-grid-box{display:flex;flex-direction:column;gap:12px;padding:14px;border-radius:14px;background:var(--surface2);border:1.5px dashed var(--line)}
.lk-rows{display:flex;flex-direction:column;gap:8px;max-height:440px;overflow-y:auto;padding-right:4px}
.lk-rowline{display:flex;gap:8px;align-items:center}.lk-rowline input{flex:1;min-width:0}
.lk-num{width:28px;text-align:right;color:var(--faint);font-size:.82rem;font-weight:600}
.lk-step{display:flex;align-items:center;gap:10px}
.lk-step b{width:28px;height:28px;border-radius:50%;background:var(--btn);color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:.85rem}

input,select,textarea{font:inherit;color:var(--text);background:var(--input-bg);border:1.5px solid var(--line);border-radius:12px;padding:9px 14px;min-height:42px;outline:none;transition:border-color .15s,box-shadow .15s;width:100%}
input::placeholder,textarea::placeholder{color:var(--faint)}
input[type=checkbox]{width:auto;min-height:0;accent-color:var(--btn)}
input:focus,select:focus,textarea:focus{border-color:var(--brand);box-shadow:0 0 0 3px color-mix(in srgb,var(--brand) 22%,transparent)}
button{font:inherit;font-weight:700;cursor:pointer;border:0;border-radius:12px;padding:9px 20px;min-height:42px;background:var(--btn);color:#fff;box-shadow:none;transition:filter .15s,background .15s,border-color .15s}
button:hover{filter:brightness(1.08)}
button:active{filter:brightness(.95)}
button:disabled{opacity:.5;cursor:not-allowed;filter:none}
.btn-ghost{background:var(--surface);color:var(--brand-ink);border:1.5px solid var(--line)}
.btn-ghost:hover{background:var(--hover);filter:none;border-color:var(--brand)}
.btn-danger{background:var(--coral-soft);color:var(--red)}
.btn-danger:hover{background:var(--red);color:#fff;filter:none}
.btn-small{padding:5px 13px;min-height:0;font-size:.8rem;border-radius:10px}
a.btn-small{display:inline-flex;align-items:center;font-weight:700;background:var(--surface);color:var(--brand-ink);border:1.5px solid var(--line);border-radius:10px}
a.btn-small:hover{background:var(--hover)}

.row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 8px;border-bottom:1px solid var(--line);color:var(--text);border-radius:12px;transition:background .15s}
.row:last-child{border-bottom:0}
.row:hover{background:var(--hover)}
.person{display:flex;align-items:center;gap:10px;font-weight:600;color:var(--text);flex-wrap:wrap}
.actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.avatar{width:40px;height:40px;border-radius:50%;background:var(--brand-soft);color:var(--brand-ink);font-weight:800;display:inline-flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0}
.score{font-weight:800}
.notice{background:var(--amber-soft);color:var(--amber-ink);border-radius:14px;padding:11px 16px;font-weight:500}
.notice.ok{background:var(--green-soft);color:var(--green-ink)}
.empty{padding:28px;text-align:center;color:var(--muted);background:var(--surface2);border:1.5px dashed var(--line);border-radius:var(--radius)}
.tag{display:inline-block;padding:2px 10px;border-radius:99px;font-size:.74rem;font-weight:700;background:var(--brand-soft);color:var(--brand-ink)}
.badge{display:inline-block;padding:3px 11px;border-radius:99px;font-size:.76rem;font-weight:700;background:var(--brand-soft);color:var(--brand-ink)}
.badge.ok{background:var(--green-soft);color:var(--green-ink)}.badge.mid{background:var(--amber-soft);color:var(--amber-ink)}.badge.bad{background:var(--red-soft);color:var(--red)}

/* cartes chiffres : fond neutre, pastille d'icône colorée */
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.stat{border-radius:var(--radius);padding:18px;display:flex;flex-direction:column;gap:3px;background:var(--surface);color:var(--text);border:1px solid var(--line);box-shadow:var(--shadow)}
.stat small{color:var(--muted);font-size:.8rem;font-weight:600}
.stat strong{font-size:1.55rem;letter-spacing:-.02em;font-weight:800}
.stat i{font-style:normal;width:40px;height:44px;border-radius:20px 20px 9px 9px;display:flex;align-items:center;justify-content:center;margin-bottom:8px;background:var(--brand-soft);color:var(--brand-ink)}
.stat i svg{width:21px;height:21px}
.stat.c2 i{background:var(--teal-soft);color:var(--teal-ink)}
.stat.c3 i{background:var(--coral-soft);color:var(--coral)}
.stat.c4 i{background:var(--amber-soft);color:var(--amber-ink)}
.bar{height:10px;border-radius:99px;background:var(--track);overflow:hidden}
.bar div{height:100%;background:linear-gradient(90deg,#6D4AFF,#22D3EE);border-radius:99px;transition:width .6s}

.donut{--p:0;width:132px;height:132px;border-radius:50%;background:conic-gradient(var(--teal) calc(var(--p)*1%),var(--track) 0);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.donut span{width:96px;height:96px;border-radius:50%;background:var(--surface);display:flex;flex-direction:column;align-items:center;justify-content:center;font-weight:800;font-size:1.4rem}
.donut small{font-weight:600;font-size:.7rem}
.hbar{display:grid;grid-template-columns:90px 1fr 46px;gap:10px;align-items:center;font-size:.88rem;font-weight:600}
.hbar .track{height:12px;background:var(--track);border-radius:99px;overflow:hidden}
.hbar .fill{height:100%;border-radius:99px;background:linear-gradient(90deg,#14B8A6,#22D3EE)}.hbar .fill.low{background:linear-gradient(90deg,#FF7A59,#FF9A5B)}
.hbar b{text-align:right}

table.data{width:100%;border-collapse:collapse}
table.data th,table.data td{padding:12px;text-align:left;border-bottom:1px solid var(--line)}
table.data th{font-size:.72rem;text-transform:uppercase;letter-spacing:.07em;color:var(--faint);font-weight:700}
table.data tbody tr:hover{background:var(--hover)}
.lk-total td{background:var(--brand-soft);font-weight:700}

.tabs,.chips{display:flex;gap:8px;flex-wrap:wrap}
.tabs{background:var(--surface2);border:1px solid var(--line);padding:4px;border-radius:14px;width:fit-content}
.tabs button{background:transparent;color:var(--muted);padding:7px 16px;min-height:0;box-shadow:none;border-radius:10px}
.tabs button:hover{background:var(--hover);filter:none;color:var(--text)}
.tabs button.on{background:var(--surface);color:var(--text);box-shadow:0 1px 3px rgba(20,16,46,.12)}
.chips button{background:var(--surface);color:var(--text);border:1.5px solid var(--line);padding:7px 15px;min-height:0;font-weight:600;border-radius:10px}
.chips button:hover{border-color:var(--brand);filter:none}
.chips button.on{background:var(--btn);color:#fff;border-color:transparent}
.chips button.coral.on{background:#F2603F}
.chips button.teal.on{background:#0E9B8F}
.chips button.amber.on{background:#C98400}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px}
.week{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.day h4{color:var(--muted);text-transform:uppercase;letter-spacing:.07em;font-size:.72rem}
.slot{display:flex;flex-direction:column;gap:2px;padding:10px 14px;border-radius:12px;background:var(--teal-soft);border-left:4px solid var(--teal);position:relative;font-size:.88rem}
.slot:nth-of-type(3n+2){background:var(--brand-soft);border-left-color:var(--brand)}
.slot:nth-of-type(3n){background:var(--coral-soft);border-left-color:var(--coral)}
.slot button{position:absolute;top:6px;right:6px}

.chip-score{display:inline-block;padding:3px 11px;border-radius:99px;background:var(--brand-soft);font-weight:700;font-size:.82rem;cursor:pointer;border:0;min-height:0;color:var(--brand-ink)}
.chip-score:hover{background:var(--btn);color:#fff;filter:none}
.score-in{max-width:90px;text-align:center;font-weight:800}
.stt{display:flex;gap:6px}
.stt button{background:var(--surface);color:var(--text);border:1.5px solid var(--line);padding:5px 12px;min-height:0;font-size:.8rem}
.stt button.present.on{background:var(--green);color:#fff;border-color:var(--green)}
.stt button.late.on{background:var(--amber);color:#1b1200;border-color:var(--amber)}
.stt button.absent.on{background:var(--red);color:#fff;border-color:var(--red)}

/* connexion */
.auth{display:grid;grid-template-columns:1.05fr 1fr;min-height:100vh;position:relative}
.auth-hero .lk-brand{color:#fff}
.auth-hero{background:linear-gradient(150deg,#14102E 0%,#2A1F7A 100%);color:#fff;padding:56px;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden}
.auth-hero:before{content:"";position:absolute;right:-30px;bottom:-40px;width:340px;height:420px;border:6px solid rgba(255,255,255,.08);border-bottom:0;border-radius:170px 170px 0 0}
.auth-hero:after{content:"";position:absolute;right:230px;top:150px;width:22px;height:22px;border-radius:50%;background:var(--coral)}
.auth-hero h1{font-size:2.4rem;line-height:1.12;max-width:440px;position:relative;color:#fff}
.auth-hero p{opacity:.88;max-width:440px;position:relative}
.auth-hero .lk-brand{padding:0;position:relative}
.auth-feats{display:flex;flex-direction:column;gap:10px;position:relative}
.auth-feats span{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.08);padding:9px 16px;border-radius:12px;width:fit-content;font-size:.9rem;font-weight:600}
.auth-form{display:flex;align-items:center;justify-content:center;padding:32px;background:var(--page-glow),var(--bg);background-repeat:no-repeat}
.auth-sheet{width:100%;max-width:420px;margin-top:34px}
.auth-mobile{display:none}
.auth-card{position:relative;padding:76px 32px 30px;border-radius:170px 170px 26px 26px;
  --text:#14102E;--muted:#4C4670;--faint:#6A6786;--line:rgba(109,74,255,.28);--input-bg:rgba(255,255,255,.72);--btn:#14102E;--brand-ink:#4C2FD6;--brand:#6D4AFF;--surface:rgba(255,255,255,.6);--hover:rgba(255,255,255,.9);--brand-soft:rgba(255,255,255,.95);color:var(--text)}
.auth-card:before{content:"";position:absolute;inset:0;border-radius:inherit;background:linear-gradient(180deg,#E9E3FF 0%,#D6CBFF 100%);z-index:0;box-shadow:0 24px 60px rgba(80,60,200,.18)}
.auth-card>.auth-box{position:relative;z-index:1}
.auth-arch-logo{display:block;z-index:2;position:absolute;left:50%;top:0;transform:translate(-50%,-50%)}
.auth-box h1{text-align:center}
.auth-box>.meta{text-align:center}
.auth-switch{text-align:center;color:var(--muted);font-size:.9rem;margin-top:14px}
.auth-switch .btn-link{padding:2px 4px;font-size:inherit}
.auth-box{width:100%;max-width:400px;display:flex;flex-direction:column;gap:14px}
.roles{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.roles button{background:var(--surface);color:var(--text);border:1.5px solid var(--line);border-radius:14px;flex-direction:column;display:flex;align-items:center;gap:4px;padding:12px 6px;font-size:.84rem}
.roles button.on{border-color:var(--brand);background:var(--brand-soft);color:var(--brand-ink)}
.pw{position:relative}
.pw input{padding-right:50px}
.pw-eye{position:absolute;right:4px;top:50%;transform:translateY(-50%);background:none;box-shadow:none;color:var(--muted);padding:0;min-height:0;width:42px;height:42px;border-radius:50%;display:flex;align-items:center;justify-content:center}
.pw-eye:hover{background:var(--hover);filter:none}
.pw-eye .ic{margin:0;width:20px;height:20px}
.btn-link{background:none;color:var(--brand-ink);padding:6px;min-height:0;font-size:.92rem}
.btn-link:hover{background:none;filter:none;text-decoration:underline}
.auth-sep{display:flex;align-items:center;gap:12px;color:var(--muted);font-size:.84rem;margin:2px 0}
.auth-sep:before,.auth-sep:after{content:"";flex:1;height:1px;background:var(--line)}

/* bulletin : reste un document blanc, même en mode sombre */
.bul{color-scheme:light;background:#fff;color:#111;padding:28px 34px;border:1px solid #ccc;border-radius:6px;font-family:Georgia,"Times New Roman",serif;display:flex;flex-direction:column;gap:12px;page-break-after:always;break-after:page}
.bul .head{display:flex;justify-content:space-between;text-align:center;font-size:.8rem;text-transform:uppercase;gap:10px}
.bul h2{text-align:center;font-size:1.3rem;letter-spacing:.1em;margin:6px 0;color:#111}
.bul small{color:#444}
.bul table{width:100%;border-collapse:collapse;font-size:.9rem}
.bul th,.bul td{border:1px solid #333;padding:5px 8px;text-align:center;color:#111}
.bul td:first-child,.bul th:first-child{text-align:left}
.bul .sign{display:flex;justify-content:space-between;margin-top:26px;font-size:.85rem}

/* téléphone : barre du bas et feuille « Plus » (cachées sur ordinateur) */
.lk-tabbar,.lk-sheet-wrap{display:none}

.hero .tabs{background:var(--hero-tabs);border-color:var(--hero-tabs-line)}
.hero .tabs button{color:var(--hero-tab-text)}
.hero .tabs button:hover{background:rgba(255,255,255,.35);color:var(--hero-text)}
.hero .tabs button.on{background:var(--hero-tab-on-bg);color:var(--hero-tab-on-text)}
.hero .topbar{align-items:flex-start}

/* planning : grille horaire */
.tt-wrap{padding:14px;overflow-x:auto}
.tt{display:grid;grid-template-columns:54px repeat(6,minmax(120px,1fr));min-width:820px}
.tt-head{text-align:center;font-weight:700;font-size:.8rem;color:var(--muted);padding:8px 4px 10px;text-transform:uppercase;letter-spacing:.06em}
.tt-head.today{color:var(--brand)}
.tt-hours{position:relative}
.tt-hours span{position:absolute;right:8px;transform:translateY(-50%);font-size:.72rem;color:var(--faint);font-weight:600}
.tt-col{position:relative;border-left:1px dashed var(--line);background-image:repeating-linear-gradient(to bottom,transparent 0,transparent calc(var(--hh) - 1px),var(--line) calc(var(--hh) - 1px),var(--line) var(--hh));cursor:cell}
.tt-col.today{background-color:color-mix(in srgb,var(--brand) 7%,transparent)}
.tt-block{position:absolute;left:4px;right:4px;border-radius:10px;padding:6px 10px;color:#fff;display:flex;flex-direction:column;gap:1px;overflow:hidden;transition:transform .15s;cursor:default;font-size:.82rem}
.tt-block:hover{transform:scale(1.02);z-index:3;box-shadow:0 8px 20px rgba(20,16,46,.3)}
.tt-block b{font-size:.86rem;line-height:1.2}.tt-block span{opacity:.92;font-size:.74rem}
.tt-block button{position:absolute;top:4px;right:4px;padding:0;width:20px;height:20px;min-height:0;font-size:.65rem;background:rgba(255,255,255,.25);box-shadow:none;opacity:0;display:flex;align-items:center;justify-content:center;border-radius:6px}
.tt-block:hover button{opacity:1}
.tt-list{display:none}
.pill-course{display:flex;flex-direction:column;gap:1px;padding:9px 16px;border-radius:12px;color:#fff;min-width:150px;position:relative}
.pill-course span{font-size:.8rem;opacity:.92}
.pill-course em{position:absolute;top:8px;right:10px;font-style:normal;font-size:.68rem;font-weight:700;background:rgba(255,255,255,.26);border-radius:99px;padding:1px 8px}
.pill-course.live{outline:2px solid var(--coral);outline-offset:2px}
.asg h3{font-size:1.05rem}

/* messagerie, annonces, badges */
.nbadge{margin-left:auto;font-style:normal;background:var(--coral);color:#fff;font-size:.68rem;font-weight:800;min-width:20px;height:20px;border-radius:99px;display:inline-flex;align-items:center;justify-content:center;padding:0 6px}
.lk-user a.who{color:inherit}
.msg-layout{display:grid;grid-template-columns:340px 1fr;gap:18px;align-items:stretch}
.msg-list{gap:4px;max-height:calc(100vh - 220px);overflow-y:auto}
.msg-pane{min-height:420px;max-height:calc(100vh - 220px)}
.conv{display:flex;align-items:center;gap:12px;padding:10px;border-radius:12px;cursor:pointer;transition:background .15s}
.conv:hover{background:var(--hover)}.conv.on{background:var(--brand-soft)}
.conv-main{flex:1;min-width:0}.conv-top{display:flex;justify-content:space-between;gap:8px}
.conv-last{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.msg-contacts{display:flex;flex-direction:column;gap:2px;overflow-y:auto}
.thread{flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:8px;padding:8px 2px}
.bubble{max-width:75%;padding:10px 14px;border-radius:18px;line-height:1.4;white-space:pre-wrap;word-break:break-word}
.bubble small{display:block;font-size:.66rem;margin-top:3px;opacity:.7;color:inherit}
.bubble.me{align-self:flex-end;background:var(--btn);color:#fff;border-bottom-right-radius:5px}
.bubble.them{align-self:flex-start;background:var(--surface2);border:1px solid var(--line);border-bottom-left-radius:5px}
.back{display:none}
.ann{border-left:5px solid var(--brand)}
.ann.urgent{border-left-color:var(--red);background:linear-gradient(90deg,var(--red-soft),var(--surface) 45%)}
.ann.closure{border-left-color:var(--amber);background:linear-gradient(90deg,var(--amber-soft),var(--surface) 45%)}
.lk-inline input[type=checkbox]{flex:0 0 auto;min-width:0}
.jr-ic{width:36px;height:36px;border-radius:11px;background:var(--brand-soft);color:var(--brand-ink);display:inline-flex;align-items:center;justify-content:center;flex-shrink:0}
@media(max-width:800px){
  .msg-layout{grid-template-columns:1fr}
  .msg-layout.has-thread .msg-list{display:none}
  .msg-layout:not(.has-thread) .msg-pane{display:none}
  .back{display:inline-flex}
}
@media(max-width:700px){.tt{display:none}.tt-list{display:block}}

/* ===== téléphone ===== */
@media screen and (max-width:900px){
  .lk-shell{flex-direction:column}
  .lk-side{display:none}
  :root{--radius:14px}
  body{font-size:13.5px}
  h1{font-size:1.2rem}
  h2{font-size:1.05rem}
  h3{font-size:.95rem}
  .meta{font-size:.8rem}
  .topbar .sub{font-size:.82rem}
  .lk-page{padding:12px 12px calc(76px + env(safe-area-inset-bottom));gap:12px}
  .lk-card{padding:13px;gap:8px}
  .hero{padding:16px;border-radius:18px}
  .hero h1{font-size:1.25rem}
  .hero .sub{font-size:.8rem}
  .hero{border-radius:90px 90px 18px 18px;padding:34px 16px 16px;text-align:center}
  .hero:before{display:none}
  .hero:after{left:50%;right:auto;top:16px;margin-left:-5px;width:10px;height:10px}
  .hero .topbar{flex-direction:column;align-items:center}
  .hero .tabs{margin:0 auto}
  .topbar{align-items:flex-start}
  .topbar>.actions,.topbar>.lk-inline{width:100%}
  .topbar>.actions>*{flex:1}

  /* barre du bas */
  .lk-tabbar{display:flex;position:fixed;left:0;right:0;bottom:0;z-index:40;background:var(--surface);border-top:1px solid var(--line);padding:4px 4px calc(4px + env(safe-area-inset-bottom))}
  .lk-tabbar a,.lk-tabbar button.tabmore{flex:1;min-width:0;display:flex;flex-direction:column;align-items:center;gap:1px;color:var(--muted);font-size:.62rem;font-weight:700;background:none;box-shadow:none;border-radius:12px;padding:4px 2px;min-height:44px;line-height:1.15;text-align:center;white-space:nowrap}
  .lk-tabbar a:hover,.lk-tabbar button.tabmore:hover{filter:none}
  .ti{position:relative;display:flex;align-items:center;justify-content:center;width:46px;height:26px;border-radius:99px;transition:background .15s}
  .ti .ic{width:19px;height:19px;margin:0}
  .ti .nbadge{position:absolute;top:-5px;right:-1px;margin:0;min-width:18px;height:18px;font-size:.62rem}
  .lk-tabbar a.on,.lk-tabbar button.tabmore.on{color:var(--brand-ink)}
  .lk-tabbar a.on .ti,.lk-tabbar button.tabmore.on .ti{background:var(--brand-soft)}
  .lk-sheet-wrap{display:flex;align-items:flex-end;position:fixed;inset:0;z-index:50;background:rgba(10,8,24,.55)}
  .lk-sheet{width:100%;background:var(--surface);border-radius:22px 22px 0 0;padding:10px 16px calc(18px + env(safe-area-inset-bottom));display:flex;flex-direction:column;gap:14px;max-height:85dvh;overflow-y:auto;box-shadow:var(--sheet-shadow)}
  .lk-sheet-grip{width:42px;height:5px;border-radius:99px;background:var(--line);margin:0 auto}
  .lk-sheet-me{display:flex;align-items:center;gap:12px;padding:10px 12px;border-radius:14px;background:var(--surface2);border:1px solid var(--line);color:var(--text)}
  .lk-sheet-me b{display:block;font-size:.95rem}
  .lk-sheet-me small{color:var(--muted)}
  .lk-sheet-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
  .lk-sheet-grid a{display:flex;flex-direction:column;align-items:center;gap:6px;padding:10px 4px;border-radius:14px;background:var(--surface2);border:1px solid var(--line);color:var(--text);font-size:.74rem;font-weight:700;text-align:center}
  .lk-sheet-grid a.on{background:var(--brand-soft);border-color:var(--brand);color:var(--brand-ink)}
  .lk-sheet-grid .ti{background:var(--surface);width:38px;height:38px;border-radius:12px}
  .lk-sheet-grid .ti .ic{width:20px;height:20px}
  .lk-sheet-out{width:100%}

  /* champs : 16 px minimum, sinon l'iPhone zoome tout seul à chaque saisie */
  input,select,textarea{font-size:16px;min-height:40px;padding:6px 12px}
  input[type=checkbox]{width:20px;height:20px;min-height:0}
  input[type=date]{min-width:0;-webkit-appearance:none;appearance:none}
  button{min-height:40px;padding:7px 14px;font-size:.85rem}
  .btn-small{min-height:32px;padding:4px 11px;font-size:.76rem}
  .tabs{width:100%;flex-wrap:wrap;gap:4px}
  .tabs button{flex:1 1 auto;min-height:34px;padding:5px 10px;text-align:center;line-height:1.2;font-size:.82rem}
  .chips button{min-height:34px;padding:5px 11px;font-size:.82rem}
  .stt button{min-height:34px;padding:5px 11px;font-size:.78rem}
  .score-in{font-size:16px}
  .lk-inline>select,.lk-inline>input:not([type=checkbox]){max-width:none!important;flex:1 1 150px}
  .lk-inline>button{flex:1 1 auto;white-space:nowrap}
  .lk-card.lk-inline{flex-direction:row}
  .badge{font-size:.7rem;padding:2px 9px}
  .avatar{width:34px;height:34px;font-size:.76rem}

  /* mises en page */
  .stats{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}
  .stat{padding:11px}
  .stat strong{font-size:1.02rem}
  .stat small{font-size:.72rem}
  .stat i{width:30px;height:33px;border-radius:15px 15px 6px 6px;margin-bottom:4px}
  .stat i svg{width:17px;height:17px}
  .grid2,.week{grid-template-columns:minmax(0,1fr)}
  .row{flex-wrap:wrap;padding:8px 2px}
  .hbar{grid-template-columns:72px 1fr 40px}
  table.data th,table.data td{padding:8px 6px;font-size:.8rem}
  table.data{min-width:480px}
  .lk-code{font-size:1rem;letter-spacing:.14em;padding:6px 12px}
  .donut{width:92px;height:92px}.donut span{width:66px;height:66px;font-size:1rem}
  .msg-list{max-height:none}
  .msg-pane{min-height:360px;max-height:calc(100dvh - 200px)}
  .bubble{max-width:86%;padding:8px 12px;font-size:.88rem}
  .notice{padding:9px 12px;font-size:.85rem}
  .bul{padding:16px 14px;overflow-x:auto}
  .bul .head{flex-wrap:wrap;font-size:.7rem}
  .bul table{font-size:.78rem;min-width:420px}

  /* connexion : le formulaire vit dans une grande arche */
  .auth{display:block;min-height:100dvh;background:radial-gradient(circle at 82% 4%,#3A2A9A 0,transparent 52%),linear-gradient(170deg,#14102E 0%,#0F0B26 100%)}
  .auth-hero{display:none}
  .auth-form{min-height:100dvh;padding:0 0 calc(24px + env(safe-area-inset-bottom));background:transparent;align-items:stretch;justify-content:flex-start;flex-direction:column}
  .auth-mobile{display:flex;color:#fff;justify-content:center;padding:calc(26px + env(safe-area-inset-top)) 20px 0}
  .auth-sheet{flex:1;max-width:none;padding:0 20px;margin-top:54px;display:flex;flex-direction:column}
  .auth-card{flex:1;padding:70px 20px 24px;border-radius:170px 170px 24px 24px}
  .auth-card:before{box-shadow:none}
  .auth-box{max-width:460px;margin:0 auto;gap:11px}
  .auth-box h1{font-size:1.35rem}
  .roles{gap:8px}
  .roles button{min-height:64px;padding:8px 4px;font-size:.76rem;justify-content:center}
  .roles button .ic{width:20px;height:20px}
  .auth-switch{color:rgba(255,255,255,.75);margin:18px 0 6px}
  .auth-switch .btn-link{color:#fff;font-weight:800;min-height:0;padding:2px 4px}
}
@media (prefers-color-scheme:dark){
  .auth-card:before{background:linear-gradient(180deg,#221B52 0%,#17123A 100%);border:1px solid rgba(160,140,255,.35);box-shadow:0 0 80px rgba(109,74,255,.25)}
  .auth-card{--text:#EEEBFF;--muted:#B5B0D6;--faint:#8B86B3;--line:rgba(255,255,255,.14);--input-bg:rgba(0,0,0,.28);--btn:#7557FF;--brand-ink:#C3B5FF;--brand:#9B82FF;--surface:rgba(255,255,255,.06);--hover:rgba(255,255,255,.1);--brand-soft:rgba(155,130,255,.22)}
}
@media screen and (max-width:380px){
  .stats{grid-template-columns:minmax(0,1fr)}
  .lk-page{padding-left:12px;padding-right:12px}
  .lk-tabbar a,.lk-tabbar button.tabmore{font-size:.6rem}
}
@media print{
  :root{color-scheme:light}
  .lk-side,.lk-tabbar,.lk-sheet-wrap,.no-print{display:none!important}
  body{background:#fff;color:#111}.lk-page{padding:0;max-width:none}
  .bul{border:0;padding:10mm 8mm}
}

/* ===== mouvement : le portail s'ouvre ===== */
@keyframes portal-open{from{clip-path:inset(0 50% 0 50% round 999px)}to{clip-path:inset(0 0 0 0 round 22px)}}
@keyframes portal-open-m{from{clip-path:inset(0 50% 0 50% round 999px)}to{clip-path:inset(0 0 0 0 round 90px 90px 18px 18px)}}
@keyframes arch-open{from{clip-path:inset(46% 28% 0 28% round 170px 170px 24px 24px);opacity:.4}to{clip-path:inset(0 0 0 0 round 170px 170px 24px 24px);opacity:1}}
@keyframes rise{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
@keyframes drop-in{from{opacity:0;transform:translate(-50%,-90%) scale(.6)}to{opacity:1;transform:translate(-50%,-50%) scale(1)}}
@keyframes glow-in{from{opacity:0}to{opacity:1}}
.hero{animation:portal-open .75s cubic-bezier(.2,.8,.2,1) both}
.hero>*{animation:glow-in .5s .35s both}
.lk-page>*:not(.hero){animation:rise .5s cubic-bezier(.2,.8,.2,1) both}
.lk-page>*:nth-child(2){animation-delay:.12s}
.lk-page>*:nth-child(3){animation-delay:.2s}
.lk-page>*:nth-child(4){animation-delay:.28s}
.lk-page>*:nth-child(5){animation-delay:.34s}
.lk-page>*:nth-child(n+6){animation-delay:.4s}
.stats>.stat{animation:rise .5s cubic-bezier(.2,.8,.2,1) both}
.stats>.stat:nth-child(1){animation-delay:.25s}.stats>.stat:nth-child(2){animation-delay:.32s}.stats>.stat:nth-child(3){animation-delay:.39s}.stats>.stat:nth-child(4){animation-delay:.46s}
.lk-sheet-wrap{animation:glow-in .2s both}
.lk-sheet{animation:rise .28s cubic-bezier(.2,.8,.2,1) both}
@media screen and (max-width:900px){
  .hero{animation-name:portal-open-m}
  .auth-card:before{animation:arch-open .85s cubic-bezier(.2,.8,.2,1) both}
  .auth-card>.auth-box{animation:rise .5s .45s cubic-bezier(.2,.8,.2,1) both}
  .auth-arch-logo{animation:drop-in .6s .35s cubic-bezier(.2,.9,.3,1.2) both}
  .auth-mobile{animation:glow-in .6s both}
  .auth-switch{animation:glow-in .5s .8s both}
}
/* mouvement pour tous les rôles : listes, cartes, retours tactiles */
.lk-card,.card,.grid>*,.lk-rows>*,.msg-list>*,.tt-list>*,.lk-grid-box>*{animation:rise .45s cubic-bezier(.2,.8,.2,1) both}
.grid>*:nth-child(2),.lk-rows>*:nth-child(2),.msg-list>*:nth-child(2),.tt-list>*:nth-child(2){animation-delay:.06s}
.grid>*:nth-child(3),.lk-rows>*:nth-child(3),.msg-list>*:nth-child(3),.tt-list>*:nth-child(3){animation-delay:.12s}
.grid>*:nth-child(4),.lk-rows>*:nth-child(4),.msg-list>*:nth-child(4),.tt-list>*:nth-child(4){animation-delay:.18s}
.grid>*:nth-child(5),.lk-rows>*:nth-child(5),.msg-list>*:nth-child(5),.tt-list>*:nth-child(5){animation-delay:.24s}
.grid>*:nth-child(n+6),.lk-rows>*:nth-child(n+6),.msg-list>*:nth-child(n+6),.tt-list>*:nth-child(n+6){animation-delay:.3s}
.lk-card,.card,.stat{transition:transform .2s,box-shadow .2s,border-color .2s}
@media (hover:hover){.lk-card:hover,.stat:hover{transform:translateY(-2px);border-color:color-mix(in srgb,var(--brand) 40%,var(--line))}}
button,.btn,.lk-tabbar a{transition:transform .12s,background .15s,filter .15s}
button:active,.btn:active,.lk-tabbar a:active{transform:scale(.97)}
.lk-tabbar a.on svg{animation:pop .35s cubic-bezier(.2,.9,.3,1.4)}
@keyframes pop{from{transform:scale(.7)}to{transform:scale(1)}}
.auth-card:before{animation:arch-open .85s cubic-bezier(.2,.8,.2,1) both}
.auth-card>.auth-box{animation:rise .5s .45s cubic-bezier(.2,.8,.2,1) both}
.auth-arch-logo{animation:drop-in .6s .35s cubic-bezier(.2,.9,.3,1.2) both}
.auth-hero>*{animation:rise .6s .2s both}

/* ===== fiche élève (directeur, professeur, parent) ===== */
.sf-head{flex-direction:row;align-items:center;gap:16px;flex-wrap:wrap;position:relative;overflow:hidden}
.sf-avatar{width:60px;height:70px;border-radius:30px 30px 12px 12px;background:linear-gradient(180deg,#E9E3FF,#D6CBFF);color:#3B22B8;font-weight:800;font-size:1.25rem;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.sf-id{flex:1;min-width:150px}.sf-id h2{margin:0;font-size:1.25rem}
.sf-score{text-align:center;padding:12px 22px;border-radius:60px 60px 16px 16px;background:linear-gradient(180deg,var(--teal-soft),transparent 140%);border:1px solid color-mix(in srgb,var(--teal-ink) 22%,transparent);min-width:112px}
.sf-score span{display:block;font-size:2rem;font-weight:800;color:var(--teal-ink);line-height:1.1}
.sf-score small{color:var(--teal-ink);font-weight:700}
.sf-todo{display:flex;flex-direction:column;gap:10px;margin-top:10px}
.sf-item{display:flex;align-items:center;gap:14px;padding:12px;border-radius:16px;background:var(--surface2);border:1px solid var(--line)}
.sf-date{width:46px;height:54px;border-radius:23px 23px 10px 10px;display:flex;flex-direction:column;align-items:center;justify-content:center;flex-shrink:0;background:var(--amber-soft);color:var(--amber-ink)}
.sf-date.bad{background:var(--red-soft);color:var(--red)}
.sf-date b{font-size:1.1rem;line-height:1}.sf-date small{font-size:.66rem;text-transform:uppercase;font-weight:700;letter-spacing:.04em}
.sf-info{flex:1;min-width:0;display:flex;flex-direction:column;gap:5px}
.sf-info strong{font-size:.98rem}
.sf-sub{display:flex;gap:6px;flex-wrap:wrap}
.sf-when{font-size:.74rem;font-weight:800;padding:5px 11px;border-radius:99px;background:var(--brand-soft);color:var(--brand-ink);white-space:nowrap}
.sf-when.soon{background:var(--coral-soft);color:#C2410C}
.sf-subjects{display:flex;flex-direction:column;gap:10px;margin-top:10px}
.sf-subj{padding:14px;border-radius:16px;background:var(--surface2);border:1px solid var(--line);display:flex;flex-direction:column;gap:9px}
.sf-subj-top{display:flex;justify-content:space-between;align-items:center;gap:10px}
.sf-subj-top strong{display:block}.sf-subj-top small{color:var(--faint);font-weight:600}
.sf-val{font-size:1.35rem;font-weight:800;color:var(--teal-ink)}.sf-val.low{color:var(--red)}
.sf-track{height:8px;border-radius:99px;background:var(--track);overflow:hidden}
.sf-track i{display:block;height:100%;border-radius:99px;background:linear-gradient(90deg,#14B8A6,#22D3EE);transform-origin:left;animation:grow .8s .2s cubic-bezier(.2,.8,.2,1) both}
.sf-track i.low{background:linear-gradient(90deg,#FF7A59,#F43F5E)}
@keyframes grow{from{transform:scaleX(0)}to{transform:scaleX(1)}}
.sf-terms{display:flex;gap:8px;flex-wrap:wrap}
.sf-terms span{font-size:.76rem;color:var(--muted);padding:3px 10px;border-radius:99px;background:var(--hover);font-weight:600}
.sf-terms span b{color:var(--text);margin-left:3px}.sf-terms span.low b{color:var(--red)}
.sf-general{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;padding:16px 18px;border-radius:18px;background:var(--hero-bg);color:var(--hero-text);font-weight:700}
.sf-general>div{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.sf-general small{font-size:.76rem;color:var(--hero-sub);font-weight:600}.sf-general small b{color:var(--hero-text)}
.sf-general strong{font-size:1.5rem;font-weight:800}
@media screen and (max-width:900px){
  .sf-head{padding:14px}
  .sf-avatar{width:50px;height:58px;border-radius:25px 25px 10px 10px;font-size:1.05rem}
  .sf-id h2{font-size:1.05rem}
  .sf-score{padding:8px 16px;min-width:90px;flex:1 1 100%;display:flex;align-items:baseline;justify-content:center;gap:10px;border-radius:99px}
  .sf-score span{font-size:1.6rem}
  .sf-item{padding:10px;gap:10px}
  .sf-when{align-self:flex-start}
}
@media (prefers-reduced-motion:reduce){*,*:before,*:after{animation:none!important;transition:none!important}}
@media print{*{animation:none!important}}
LAKOL_EOF

save "app/icon.svg"
mkdir -p "$(dirname "app/icon.svg")"
cat > 'app/icon.svg' <<'LAKOL_EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8B5CF6"/><stop offset="1" stop-color="#22D3EE"/></linearGradient></defs><rect width="48" height="48" rx="15" fill="#14102E"/><path d="M11 39V22a13 13 0 0 1 26 0v17z" fill="none" stroke="#fff" stroke-width="3.6" stroke-linejoin="round"/><path d="M20 17v15h9" fill="none" stroke="url(#g)" stroke-width="4.6" stroke-linecap="round" stroke-linejoin="round"/><circle cx="31.5" cy="18.5" r="2.7" fill="#FF7A59"/></svg>
LAKOL_EOF

save "app/journal/page.js"
mkdir -p "$(dirname "app/journal/page.js")"
cat > 'app/journal/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import Icon from '../components/Icon';

const ENT = {
  '': ['Tout', 'list'], note: ['Notes', 'edit'], paiement: ['Paiements', 'card'], frais: ['Frais', 'tag'], eleve: ['Élèves', 'cap'],
  classe: ['Classes', 'school'], compte: ['Comptes', 'user'], salaire: ['Salaires', 'cash'], parametres: ['Paramètres', 'gear'],
};
const ACT = { create: ['Ajout', 'ok'], update: ['Modif.', 'mid'], delete: ['Suppression', 'bad'] };
const ROLE = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };
const PAGE = 50;

export default function Journal() {
  const { status } = useProfile(['admin']);
  const [rows, setRows] = useState([]);
  const [entity, setEntity] = useState('');
  const [q, setQ] = useState('');
  const [more, setMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');

  async function load(reset) {
    setLoading(true);
    const from = reset ? 0 : rows.length;
    let query = supabase.from('audit_log').select('id, actor_name, actor_role, action, entity, summary, created_at').order('created_at', { ascending: false }).range(from, from + PAGE - 1);
    if (entity) query = query.eq('entity', entity);
    const { data, error } = await query;
    if (error) setErr(error.message); else { setErr(''); setRows(reset ? data : [...rows, ...data]); setMore((data || []).length === PAGE); }
    setLoading(false);
  }
  useEffect(() => { if (status === 'ok') load(true); }, [status, entity]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  const shown = q.trim() ? rows.filter((r) => (r.summary + ' ' + (r.actor_name || '')).toLowerCase().includes(q.trim().toLowerCase())) : rows;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Journal des modifications</h1><div className="sub">Qui a changé quoi, et quand. Personne ne peut modifier ou effacer ce journal, pas même le directeur.</div></div></div>
      <div className="lk-card">
        <div className="lk-inline" style={{ flexWrap: 'wrap' }}>
          <div className="tabs" style={{ flexWrap: 'wrap' }}>{Object.entries(ENT).map(([k, [l, ic]]) => <button key={k} className={entity === k ? 'on' : ''} onClick={() => setEntity(k)}><Icon name={ic} /> {l}</button>)}</div>
        </div>
        <div className="lk-inline"><input placeholder="Chercher (nom d'élève, de professeur, montant…)" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      </div>
      {err && <div className="notice">{err}</div>}
      <div className="lk-card">
        {shown.length === 0 && !loading && <div className="empty">Rien à afficher pour l'instant. Les nouvelles modifications apparaîtront ici.</div>}
        {shown.map((r) => {
          const [al, ac] = ACT[r.action] || [r.action, 'mid'];
          return (
            <div className="row" key={r.id} style={{ alignItems: 'flex-start' }}>
              <div className="person" style={{ alignItems: 'flex-start' }}>
                <span className="jr-ic"><Icon name={(ENT[r.entity] || ['', 'list'])[1]} /></span>
                <div>
                  <div><span className={'badge ' + ac}>{al}</span> {r.summary}</div>
                  <div className="meta">{r.actor_name}{r.actor_role ? ` · ${ROLE[r.actor_role] || r.actor_role}` : ''}</div>
                </div>
              </div>
              <span className="meta" style={{ whiteSpace: 'nowrap' }}>{new Date(r.created_at).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</span>
            </div>
          );
        })}
        {loading && <p className="meta">Chargement…</p>}
        {more && !loading && <div className="lk-inline"><button className="btn-ghost" onClick={() => load(false)}>Voir plus</button></div>}
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/layout.tsx"
mkdir -p "$(dirname "app/layout.tsx")"
cat > 'app/layout.tsx' <<'LAKOL_EOF'
import { Suspense } from 'react';
import type { Viewport } from 'next';
import './globals.css';
import NavMenu from './NavMenu';

export const metadata = {
  title: "Lakol — gestion d'école", description: "Gestion d'école privée",
  manifest: '/manifest.webmanifest',
  appleWebApp: { capable: true, title: 'Lakol', statusBarStyle: 'default' as const },
};

export const viewport: Viewport = { width: 'device-width', initialScale: 1, viewportFit: 'cover', themeColor: [{ media: '(prefers-color-scheme: light)', color: '#F6F5FB' }, { media: '(prefers-color-scheme: dark)', color: '#0D0A1F' }] };

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
LAKOL_EOF

save "app/login/page.js"
mkdir -p "$(dirname "app/login/page.js")"
cat > 'app/login/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';
import Logo, { Wordmark } from '../components/Logo';
import MfaCode from '../components/MfaCode';
import Icon from '../components/Icon';

const ROLES = [['admin', 'school', 'Directeur'], ['teacher', 'book', 'Professeur'], ['parent', 'users', 'Parent']];

export default function Login() {
  const router = useRouter();
  const [mode, setMode] = useState('in');
  const [role, setRole] = useState('admin');
  const [f, setF] = useState({ email: '', password: '', full_name: '', school_name: '', city: '', school_code: '', student_code: '' });
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [info, setInfo] = useState('');
  const [needCode, setNeedCode] = useState(false);
  const [show, setShow] = useState(false);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  // Déjà connecté (ou retour du lien de confirmation par email) : on continue, ou on demande le code à 6 chiffres
  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) return;
      const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') setNeedCode(true); else router.replace('/');
    })();
  }, []);

  async function afterLogin() {
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') return setNeedCode(true);
    router.replace('/');
  }

  async function forgot(e) {
    e.preventDefault(); setErr(''); setInfo('');
    if (!f.email.trim()) return setErr('Écris ton email.');
    setBusy(true);
    await supabase.auth.resetPasswordForEmail(f.email.trim(), { redirectTo: window.location.origin + '/reinitialiser' });
    setBusy(false);
    setInfo('Si un compte existe avec cet email, un message vient de partir avec un lien pour choisir un nouveau mot de passe.');
  }

  async function submit(e) {
    e.preventDefault(); setErr(''); setInfo('');
    if (mode === 'forgot') return forgot(e);
    if (mode === 'up' && (f.password.length < 10 || !/[A-Za-z]/.test(f.password) || !/[0-9]/.test(f.password))) {
      return setErr('Choisis un mot de passe d\'au moins 10 caractères, avec des lettres et des chiffres.');
    }
    setBusy(true);
    let res;
    if (mode === 'in') {
      res = await supabase.auth.signInWithPassword({ email: f.email.trim(), password: f.password });
    } else {
      res = await supabase.auth.signUp({
        email: f.email.trim(), password: f.password,
        options: { emailRedirectTo: window.location.origin + '/login', data: { role, full_name: f.full_name, school_name: f.school_name, city: f.city, school_code: f.school_code, student_code: f.student_code } },
      });
    }
    setBusy(false);
    if (res.error) {
      const m = res.error.message || '';
      if (/already registered/i.test(m)) setErr('Cet email a déjà un compte. Clique sur « Se connecter ».');
      else if (/Invalid login/i.test(m)) setErr('Email ou mot de passe incorrect.');
      else if (/Database error/i.test(m)) setErr("Code invalide. Vérifie le code de l'école (professeur) ou le code de l'élève (parent).");
      else if (/at least|weak|password/i.test(m)) setErr('Mot de passe refusé : choisis-en un plus long (10 caractères minimum, lettres et chiffres).');
      else if (/not confirmed/i.test(m)) setErr('Ton email n\'est pas encore confirmé. Ouvre le message que nous t\'avons envoyé et clique sur le lien.');
      else if (/rate limit|too many/i.test(m)) setErr('Trop d\'essais. Attends quelques minutes puis réessaie.');
      else setErr(m);
      return;
    }
    if (!res.data.session) { setInfo('Compte créé. Nous t\'avons envoyé un email : clique sur le lien pour confirmer ton adresse, puis connecte-toi ici.'); setMode('in'); return; }
    afterLogin();
  }

  return (
    <div className="auth">
      <div className="auth-hero">
        <div className="lk-brand"><Logo size={42} id="lgl" /><Wordmark height={26} /></div>
        <div className="lk-stack">
          <h1>La gestion de ton école, simple et moderne.</h1>
          <p>Notes, bulletins, scolarité, emplois du temps : tout au même endroit, pour le directeur, les professeurs et les parents.</p>
          <div className="auth-feats"><span><Icon name="check" size={15} /> Notes et bulletins en quelques clics</span><span><Icon name="check" size={15} /> Suivi de la scolarité en FCFA</span><span><Icon name="check" size={15} /> Devoirs, présence et comportement</span></div>
        </div>
        <span />
      </div>
      <div className="auth-form">
        {/* en-tête affiché seulement sur téléphone */}
        <div className="auth-mobile"><Wordmark height={24} /></div>
        <div className="auth-sheet">
        <div className="auth-card">
        <div className="auth-arch-logo"><Logo size={66} id="lgm" /></div>
        {needCode ? <MfaCode onDone={() => router.replace('/')} onCancel={async () => { await supabase.auth.signOut(); setNeedCode(false); }} /> :
        <form className="auth-box" onSubmit={submit}>
          <h1>{mode === 'in' ? 'Bon retour' : mode === 'forgot' ? 'Mot de passe oublié' : 'Créer un compte'}</h1>
          <p className="meta" style={{ margin: 0 }}>{mode === 'in' ? 'Connecte-toi pour continuer.' : mode === 'forgot' ? 'Écris ton email : nous t\'envoyons un lien pour en choisir un nouveau.' : 'Choisis ton profil.'}</p>
          {mode === 'up' && (
            <>
              <div className="roles">
                {ROLES.map(([k, ic, l]) => <button type="button" key={k} className={role === k ? 'on' : ''} onClick={() => setRole(k)}><Icon name={ic} size={24} />{l}</button>)}
              </div>
              <input placeholder="Ton nom complet" value={f.full_name} onChange={set('full_name')} required autoComplete="name" />
              {role === 'admin' && <><input placeholder="Nom de l'école" value={f.school_name} onChange={set('school_name')} required /><input placeholder="Ville" value={f.city} onChange={set('city')} autoComplete="address-level2" /></>}
              {role === 'teacher' && <input placeholder="Code de l'école (donné par le directeur)" value={f.school_code} onChange={set('school_code')} required autoCapitalize="characters" autoCorrect="off" />}
              {role === 'parent' && <input placeholder="Code de l'élève (donné par l'école)" value={f.student_code} onChange={set('student_code')} required autoCapitalize="characters" autoCorrect="off" />}
            </>
          )}
          <input type="email" inputMode="email" placeholder="Email" value={f.email} onChange={set('email')} required autoComplete="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} />
          {mode !== 'forgot' && (
            <div className="pw">
              <input type={show ? 'text' : 'password'} placeholder="Mot de passe" value={f.password} onChange={set('password')} required autoComplete={mode === 'up' ? 'new-password' : 'current-password'} autoCapitalize="none" />
              <button type="button" className="pw-eye" onClick={() => setShow(!show)} aria-label={show ? 'Cacher le mot de passe' : 'Voir le mot de passe'}><Icon name={show ? 'eyeoff' : 'eye'} /></button>
            </div>
          )}
          {mode === 'up' && <span className="meta" style={{ marginTop: -6 }}>Au moins 10 caractères, avec des lettres et des chiffres.</span>}
          {err && <div className="notice">{err}</div>}
          {info && <div className="notice ok">{info}</div>}
          <button disabled={busy}>{busy ? 'Un instant…' : mode === 'in' ? 'Se connecter' : mode === 'forgot' ? 'Envoyer le lien' : 'Créer mon compte'}</button>
          {mode === 'in' && <button type="button" className="btn-link" onClick={() => { setMode('forgot'); setErr(''); setInfo(''); }}>Mot de passe oublié ?</button>}
        </form>}
        </div>
        {!needCode && (
          <div className="auth-switch">
            {mode === 'in' ? 'Nouveau sur Lakol ?' : mode === 'forgot' ? 'Tu t\'en souviens ?' : 'Tu as déjà un compte ?'}{' '}
            <button type="button" className="btn-link" onClick={() => { setMode(mode === 'in' ? 'up' : 'in'); setErr(''); setInfo(''); }}>
              {mode === 'in' ? 'Créer un compte' : 'Se connecter'}
            </button>
          </div>
        )}
        </div>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/messages/page.js"
mkdir -p "$(dirname "app/messages/page.js")"
cat > 'app/messages/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { pingNotify, refreshBadges } from '../../lib/notify';
import Icon from '../components/Icon';

const ROLE = { admin: 'Direction', teacher: 'Professeur', parent: 'Parent' };
const initials = (n) => (n || '?').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
const when = (d) => { const x = new Date(d); const same = x.toDateString() === new Date().toDateString(); return same ? x.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : x.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }); };

export default function Messages() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [convs, setConvs] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [classes, setClasses] = useState([]);
  const [other, setOther] = useState(null);       // { id, name, role }
  const [thread, setThread] = useState([]);
  const [body, setBody] = useState('');
  const [panel, setPanel] = useState(null);       // 'new' | 'bulk'
  const [q, setQ] = useState('');
  const [bulk, setBulk] = useState({ target: 'class', class_id: '', body: '' });
  const [info, setInfo] = useState('');
  const [err, setErr] = useState('');
  const endRef = useRef(null);
  const isParent = profile?.role === 'parent';

  async function loadConvs() {
    const { data } = await supabase.rpc('my_conversations');
    setConvs(data || []);
  }
  async function loadThread(o) {
    if (!o) return;
    const me = profile.id;
    const { data } = await supabase.from('messages').select('id, sender_id, body, created_at')
      .or(`and(sender_id.eq.${me},recipient_id.eq.${o.id}),and(sender_id.eq.${o.id},recipient_id.eq.${me})`).order('created_at');
    setThread(data || []);
    await supabase.rpc('mark_thread_read', { p_other: o.id });
    refreshBadges(); loadConvs();
  }

  useEffect(() => {
    if (status !== 'ok') return;
    loadConvs();
    supabase.rpc('my_contacts').then(({ data }) => setContacts(data || []));
    (async () => {
      if (profile.role === 'parent') return;
      let list;
      if (profile.role === 'teacher') {
        const { data: t } = await supabase.from('teaching').select('class_id').eq('teacher_id', profile.id);
        const ids = [...new Set((t || []).map((x) => x.class_id))];
        list = ids.length ? (await supabase.from('classes').select('id, name').in('id', ids).order('name')).data : [];
      } else list = (await supabase.from('classes').select('id, name').order('name')).data;
      setClasses(list || []); setBulk((b) => ({ ...b, class_id: list?.[0]?.id || '' }));
    })();
  }, [status]);

  useEffect(() => { loadThread(other); }, [other?.id]);
  useEffect(() => { endRef.current?.scrollIntoView({ block: 'end' }); }, [thread.length]);
  // rafraîchit toutes les 20 s
  useEffect(() => {
    if (status !== 'ok') return;
    const t = setInterval(() => { loadConvs(); if (other) loadThread(other); }, 20000);
    return () => clearInterval(t);
  }, [status, other?.id]);

  async function send(e) {
    e.preventDefault(); setErr('');
    if (!body.trim() || !other) return;
    const { error } = await supabase.rpc('send_message', { p_recipient: other.id, p_student: null, p_body: body });
    if (error) return setErr(error.message);
    setBody(''); pingNotify(); loadThread(other);
  }
  async function sendBulk(e) {
    e.preventDefault(); setErr(''); setInfo('');
    const { data, error } = await supabase.rpc('send_bulk', { p_target: bulk.target, p_class_id: bulk.target === 'class' ? bulk.class_id : null, p_body: bulk.body });
    if (error) return setErr(error.message);
    setInfo(`Message envoyé à ${data} personne(s).`); setBulk({ ...bulk, body: '' }); pingNotify(); loadConvs();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const filtered = contacts.filter((c) => c.full_name.toLowerCase().includes(q.toLowerCase()));
  const open = (id, name, role) => { setOther({ id, name, role }); setPanel(null); };

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>Messages</h1><div className="sub">{isParent ? 'Écris aux professeurs et à la direction.' : 'Écris aux parents (un par un ou en groupe).'}</div></div>
        <div className="actions">
          <button onClick={() => { setPanel(panel === 'new' ? null : 'new'); setOther(null); }}><Icon name="mail" /> Écrire</button>
          {!isParent && <button className="btn-ghost" onClick={() => { setPanel(panel === 'bulk' ? null : 'bulk'); setOther(null); setInfo(''); }}><Icon name="megaphone" /> Message groupé</button>}
        </div>
      </div>
      {err && <div className="notice">{err}</div>}

      <div className={'msg-layout' + (other ? ' has-thread' : '')}>
        <div className="lk-card msg-list">
          {convs.length === 0 && <span className="meta">Aucune conversation pour le moment.</span>}
          {convs.map((c) => (
            <div key={c.other_id} className={'conv' + (other?.id === c.other_id ? ' on' : '')} onClick={() => open(c.other_id, c.other_name, c.other_role)}>
              <span className="avatar">{initials(c.other_name)}</span>
              <div className="conv-main">
                <div className="conv-top"><b>{c.other_name}</b><span className="meta">{when(c.last_at)}</span></div>
                <div className="conv-last meta">{c.last_from_me ? 'Toi : ' : ''}{c.last_body}</div>
              </div>
              {c.unread > 0 && <em className="nbadge">{c.unread}</em>}
            </div>
          ))}
        </div>

        <div className="lk-card msg-pane">
          {panel === 'new' && (
            <>
              <h3>À qui veux-tu écrire ?</h3>
              <input placeholder="Rechercher un nom…" value={q} onChange={(e) => setQ(e.target.value)} />
              {filtered.length === 0 && <span className="meta">Personne à contacter pour le moment.</span>}
              <div className="msg-contacts">
                {filtered.map((c) => (
                  <div className="conv" key={c.id} onClick={() => open(c.id, c.full_name, c.role)}>
                    <span className="avatar">{initials(c.full_name)}</span>
                    <div className="conv-main"><b>{c.full_name} <span className="tag">{ROLE[c.role]}</span></b><div className="meta">{c.context}</div></div>
                  </div>
                ))}
              </div>
            </>
          )}

          {panel === 'bulk' && (
            <form className="lk-stack" onSubmit={sendBulk}>
              <h3><Icon name="megaphone" /> Message groupé</h3>
              <div className="chips">
                {profile.role === 'admin' && <button type="button" className={bulk.target === 'parents' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'parents' })}>Tous les parents</button>}
                {profile.role === 'admin' && <button type="button" className={bulk.target === 'teachers' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'teachers' })}>Tous les professeurs</button>}
                <button type="button" className={bulk.target === 'class' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'class' })}>Parents d'une classe</button>
              </div>
              {bulk.target === 'class' && (
                <select value={bulk.class_id} onChange={(e) => setBulk({ ...bulk, class_id: e.target.value })}>
                  {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              )}
              <textarea rows={4} placeholder="Ton message…" value={bulk.body} onChange={(e) => setBulk({ ...bulk, body: e.target.value })} />
              <div className="lk-inline"><button disabled={!bulk.body.trim()}>Envoyer</button>{info && <span className="meta">{info}</span>}</div>
              <span className="meta">Chaque personne reçoit le message en privé et peut te répondre.</span>
            </form>
          )}

          {!panel && other && (
            <>
              <div className="lk-inline">
                <button className="btn-small btn-ghost back" onClick={() => setOther(null)} aria-label="Retour"><Icon name="back" size={16} /></button>
                <span className="avatar">{initials(other.name)}</span>
                <div><b>{other.name}</b> <span className="tag">{ROLE[other.role]}</span></div>
              </div>
              <div className="thread">
                {thread.map((m) => (
                  <div key={m.id} className={'bubble ' + (m.sender_id === profile.id ? 'me' : 'them')}>
                    {m.body}<small>{when(m.created_at)}</small>
                  </div>
                ))}
                <div ref={endRef} />
              </div>
              <form className="lk-inline" onSubmit={send}>
                <input placeholder="Écris ton message…" value={body} onChange={(e) => setBody(e.target.value)} />
                <button disabled={!body.trim()} style={{ flex: '0 0 auto' }}>Envoyer</button>
              </form>
            </>
          )}

          {!panel && !other && <div className="empty" style={{ margin: 'auto' }}>Choisis une conversation ou écris un nouveau message.</div>}
        </div>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/notes/page.js"
mkdir -p "$(dirname "app/notes/page.js")"
cat > 'app/notes/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fmt } from '../../lib/grades';
import { pingNotify } from '../../lib/notify';
import { useSettings } from '../../lib/useSettings';
import { periodList, periodTab, periodWord } from '../../lib/settings';

export default function Notes() {
  const { profile, status } = useProfile(['teacher']);
  const st = useSettings(status === 'ok');
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [classId, setClassId] = useState('');
  const [subjectId, setSubjectId] = useState('');
  const [term, setTerm] = useState(1);
  const [kind, setKind] = useState('devoir');
  const [students, setStudents] = useState([]);
  const [grades, setGrades] = useState([]);
  const [vals, setVals] = useState({});
  const [title, setTitle] = useState('');
  const [titleTouched, setTitleTouched] = useState(false);
  const [plan, setPlan] = useState({});
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('classes').select('id, name').order('name').then(({ data }) => {
      setClasses(data || []); if (data?.length) setClassId(data[0].id);
    });
  }, [status]);

  // matières de la classe (celles que le prof enseigne ; toutes pour le directeur)
  useEffect(() => {
    if (!classId) return;
    (async () => {
      let list;
      if (profile.role === 'admin') list = (await supabase.from('subjects').select('id, name').order('name')).data || [];
      else {
        const { data } = await supabase.from('teaching').select('subject_id, devoirs_per_term, compositions_per_term, subjects(id, name)').eq('class_id', classId).eq('teacher_id', profile.id);
        list = (data || []).map((x) => x.subjects).filter(Boolean);
        setPlan(Object.fromEntries((data || []).map((x) => [x.subject_id, { d: x.devoirs_per_term, c: x.compositions_per_term }])));
      }
      setSubjects(list); setSubjectId(list[0]?.id || '');
    })();
  }, [classId]);

  async function load() {
    if (!classId || !subjectId) { setStudents([]); setGrades([]); return; }
    const { data: s } = await supabase.from('students').select('id, first_name, last_name').eq('class_id', classId).order('last_name');
    setStudents(s || []);
    const ids = (s || []).map((x) => x.id);
    if (ids.length) {
      const { data: g } = await supabase.from('grades').select('id, student_id, score, kind, term, title, created_at').in('student_id', ids).eq('subject_id', subjectId).eq('term', term).order('created_at');
      setGrades(g || []);
    } else setGrades([]);
    setVals({});
  }
  useEffect(() => { load(); }, [classId, subjectId, term, kind]);

  // Notes déjà saisies de ce type, regroupées par nom (Devoir 1, Interro surprise…)
  const labelOf = (g) => (g.title && g.title.trim()) || (g.kind === 'composition' ? 'Composition' : 'Devoir');
  const ofKind = grades.filter((g) => g.kind === kind);
  const names = [...new Set(ofKind.map(labelOf))];
  const suggestion = kind === 'composition' ? (names.includes('Composition') ? `Composition ${names.length + 1}` : 'Composition') : `Devoir ${names.length + 1}`;
  useEffect(() => { if (!titleTouched) setTitle(suggestion); }, [suggestion, titleTouched]);
  useEffect(() => { setTitleTouched(false); }, [classId, subjectId, term, kind]);
  const planned = plan[subjectId] || {};
  const countD = new Set(grades.filter((g) => g.kind === 'devoir').map(labelOf)).size;
  const countC = new Set(grades.filter((g) => g.kind === 'composition').map(labelOf)).size;

  async function saveAll() {
    setMsg('');
    const bad = Object.values(vals).some((v) => v !== '' && (isNaN(Number(v.replace(',', '.'))) || Number(v.replace(',', '.')) < 0 || Number(v.replace(',', '.')) > st.scale));
    if (bad) return setMsg(`Les notes doivent être entre 0 et ${st.scale}.`);
    const name = title.trim();
    const rows = Object.entries(vals).filter(([, v]) => v !== '').map(([sid, v]) => ({
      school_id: profile.school_id, student_id: sid, subject_id: subjectId, term, kind, title: name, score: Number(v.replace(',', '.')), created_by: profile.id,
    }));
    if (!rows.length) return setMsg('Écris au moins une note.');
    if (!name) return setMsg('Donne un nom à cette note (ex. Devoir 2, Interro surprise).');
    const same = grades.filter((g) => labelOf(g).toLowerCase() === name.toLowerCase());
    const dup = students.filter((st) => vals[st.id] && same.some((g) => g.student_id === st.id && g.kind === kind));
    if (dup.length) return setMsg(`« ${name} » existe déjà pour ${dup.map((d) => d.first_name).join(', ')}. Clique sur sa note pour la modifier, ou change le nom.`);
    const { error } = await supabase.from('grades').insert(rows);
    if (error) return setMsg(error.message);
    setMsg(`${rows.length} note(s) « ${name} » enregistrée(s). Les parents sont prévenus.`); pingNotify(); setTitleTouched(false); load();
  }
  async function editGrade(g) {
    const v = prompt(`Note « ${labelOf(g)} » sur ${st.scale} (laisse vide pour supprimer)`, g.score);
    if (v === null) return;
    if (v.trim() === '') { await supabase.from('grades').delete().eq('id', g.id); return load(); }
    const n = Number(v.replace(',', '.'));
    if (isNaN(n) || n < 0 || n > st.scale) return alert(`Note entre 0 et ${st.scale}`);
    const t = prompt('Nom de cette note', labelOf(g));
    await supabase.from('grades').update({ score: n, title: (t || '').trim() || g.title || null }).eq('id', g.id); load();
  }
  // Entrée = passer à l'élève suivant
  const next = (e) => { if (e.key === 'Enter') { e.preventDefault(); const all = [...document.querySelectorAll('.score-in')]; all[all.indexOf(e.target) + 1]?.focus(); } };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Saisie des notes</h1><div className="sub">Écris les notes de toute la classe d'un coup. Entrée = élève suivant.</div></div></div>
      <div className="lk-card">
        <div className="lk-inline">
          <select value={classId} onChange={(e) => setClassId(e.target.value)}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
          <select value={subjectId} onChange={(e) => setSubjectId(e.target.value)}>{subjects.length === 0 && <option value="">Aucune matière</option>}{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select>
        </div>
        <div className="lk-inline">
          <div className="tabs">{periodList(st).map((t) => <button key={t} className={term === t ? 'on' : ''} onClick={() => setTerm(t)}>{periodTab(t, st)}</button>)}</div>
          <div className="tabs">{[['devoir', 'Devoir'], ['composition', 'Composition']].map(([k, l]) => <button key={k} className={kind === k ? 'on' : ''} onClick={() => setKind(k)}>{l}</button>)}</div>
        </div>
      </div>

      {subjectId && (
        <div className="lk-card">
          <label className="meta" htmlFor="gname">Nom de cette note</label>
          <div className="lk-inline">
            <input id="gname" list="gnames" maxLength={60} value={title} placeholder="ex. Devoir 2, Interro surprise, Exposé…"
              onChange={(e) => { setTitle(e.target.value); setTitleTouched(true); }} />
            <datalist id="gnames">{['Interro surprise', 'Exposé', 'Devoir maison', 'Test', 'Rattrapage', ...names].map((n) => <option key={n} value={n} />)}</datalist>
          </div>
          <div className="meta">
            Une note non prévue ? Choisis « Devoir » ou « Composition » ci-dessus (elle compte dans la moyenne) et donne-lui son propre nom.
            {(planned.d != null || planned.c != null) && <> Prévu ce {periodWord(st)} : {planned.d ?? 0} devoir(s), {planned.c ?? 0} composition(s). Déjà saisi : {countD} devoir(s), {countC} composition(s).</>}
          </div>
        </div>
      )}

      {subjects.length === 0 && classId && <div className="empty">{profile.role === 'teacher' ? "Tu n'enseignes aucune matière dans cette classe." : 'Aucune matière. Ajoute-en dans « Classes ».'}</div>}
      {students.length > 0 && subjectId && (
        <div className="lk-card">
          {students.map((s) => {
            const mine = grades.filter((g) => g.student_id === s.id && g.kind === kind);
            return (
              <div className="row" key={s.id}>
                <div className="person"><span className="avatar">{(s.first_name[0] || '') + (s.last_name[0] || '')}</span>{s.last_name} {s.first_name}</div>
                <div className="actions">
                  {mine.map((g) => <button key={g.id} className="chip-score" title="Cliquer pour modifier ou supprimer" onClick={() => editGrade(g)}><small style={{ opacity: .7 }}>{labelOf(g)}</small> {fmt(g.score)}</button>)}
                  <input className="score-in" inputMode="decimal" placeholder={`/${st.scale}`} value={vals[s.id] || ''} onKeyDown={next}
                    onChange={(e) => setVals({ ...vals, [s.id]: e.target.value })} />
                </div>
              </div>
            );
          })}
          <div className="lk-inline"><button onClick={saveAll}>Enregistrer les notes</button>{msg && <span className="meta">{msg}</span>}</div>
        </div>
      )}
      {students.length === 0 && classId && subjectId && <div className="empty">Aucun élève dans cette classe.</div>}
    </div>
  );
}
LAKOL_EOF

save "app/page.js"
mkdir -p "$(dirname "app/page.js")"
cat > 'app/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../lib/supabase';
import { Blocked } from '../lib/useProfile';

export default function Home() {
  const router = useRouter();
  const [blocked, setBlocked] = useState(false);
  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) return router.replace('/login');
      const { data: p } = await supabase.from('profiles').select('role, active').eq('id', data.session.user.id).maybeSingle();
      if (!p || p.active === false) return setBlocked(true);
      router.replace(p.role === 'admin' ? '/dashboard' : p.role === 'teacher' ? '/classes' : '/parent');
    })();
  }, []);
  if (blocked) return <Blocked />;
  return <div className="lk-page"><p className="meta">Chargement…</p></div>;
}
LAKOL_EOF

save "app/paiements/page.js"
mkdir -p "$(dirname "app/paiements/page.js")"
cat > 'app/paiements/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, METHODS } from '../../lib/grades';
import Icon from '../components/Icon';

export default function Paiements() {
  const { profile, status } = useProfile(['admin']);
  const [tab, setTab] = useState('eleves');
  const [rows, setRows] = useState([]);
  const [classes, setClasses] = useState([]);
  const [fees, setFees] = useState([]);
  const [filter, setFilter] = useState('tous');
  const [classId, setClassId] = useState('');
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(null);
  const [hist, setHist] = useState([]);
  const [form, setForm] = useState({ amount: '', method: 'cash', fee_id: '' });
  const [fee, setFee] = useState({ label: '', amount: '', all: true, targets: [] });
  const [err, setErr] = useState('');

  async function load() {
    const [b, c, f] = await Promise.all([
      supabase.rpc('student_balances'),
      supabase.from('classes').select('id, name').order('name'),
      supabase.from('fees').select('id, class_id, label, amount').order('label'),
    ]);
    if (b.error) setErr(b.error.message);
    setRows(b.data || []); setClasses(c.data || []); setFees(f.data || []);
    if (!classId && c.data?.length) setClassId(c.data[0].id);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function openStudent(s) {
    if (open?.student_id === s.student_id) { setOpen(null); return; }
    setOpen(s);
    setForm({ amount: String(Math.max(0, s.due - s.paid) || ''), method: 'cash', fee_id: '' });
    const { data } = await supabase.from('payments').select('id, amount, method, paid_at').eq('student_id', s.student_id).order('paid_at', { ascending: false });
    setHist(data || []);
  }
  async function addPayment(e) {
    e.preventDefault(); setErr('');
    const amount = parseInt(form.amount, 10);
    if (!amount) return;
    const { error } = await supabase.from('payments').insert({
      school_id: profile.school_id, student_id: open.student_id, amount, method: form.method, fee_id: form.fee_id || null,
    });
    if (error) return setErr(error.message);
    const s = open; setOpen(null); await load(); openStudent({ ...s, paid: s.paid + amount });
  }
  async function delPayment(id) {
    if (!confirm('Supprimer ce paiement ?')) return;
    await supabase.from('payments').delete().eq('id', id);
    const s = open; setOpen(null); await load();
    const r = (await supabase.rpc('student_balances')).data?.find((x) => x.student_id === s.student_id);
    if (r) openStudent(r);
  }

  async function addFee(e) {
    e.preventDefault(); setErr('');
    const amount = parseInt(fee.amount, 10);
    if (!fee.label.trim() || !amount) return;
    if (!fee.all && fee.targets.length === 0) return setErr('Choisis au moins une classe.');
    const targets = fee.all ? [null] : fee.targets;
    const { error } = await supabase.from('fees').insert(targets.map((id) => ({ school_id: profile.school_id, class_id: id, label: fee.label.trim(), amount })));
    if (error) return setErr(error.message);
    setFee({ label: '', amount: '', all: true, targets: [] }); load();
  }
  async function editFee(f) {
    const v = prompt(`Nouveau montant pour « ${f.label} » (FCFA)`, f.amount);
    const n = parseInt(v, 10);
    if (!n) return;
    await supabase.from('fees').update({ amount: n }).eq('id', f.id); load();
  }
  async function delFee(f) {
    if (!confirm(`Supprimer le frais « ${f.label} » ?`)) return;
    await supabase.from('fees').delete().eq('id', f.id); load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const state = (r) => (r.due === 0 ? ['Aucun frais', ''] : r.paid >= r.due ? ['Soldé', 'ok'] : r.paid > 0 ? ['Partiel', 'mid'] : ['Impayé', 'bad']);
  const shown = rows.filter((r) => {
    const s = state(r)[0];
    if (filter === 'impayes' && s !== 'Impayé') return false;
    if (filter === 'partiels' && s !== 'Partiel') return false;
    if (filter === 'soldes' && s !== 'Soldé') return false;
    if (classId && tab === 'eleves' && classId !== 'all' && r.class_id !== classId) return false;
    return `${r.first_name} ${r.last_name}`.toLowerCase().includes(q.toLowerCase());
  });
  const totDue = shown.reduce((s, r) => s + Number(r.due), 0);
  const totPaid = shown.reduce((s, r) => s + Number(r.paid), 0);

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Scolarité</h1>
        <div className="tabs">
          <button className={tab === 'eleves' ? 'on' : ''} onClick={() => setTab('eleves')}>Élèves</button>
          <button className={tab === 'frais' ? 'on' : ''} onClick={() => setTab('frais')}>Frais par classe</button>
        </div>
      </div>
      {err && <div className="notice">{err}</div>}

      {tab === 'eleves' && (
        <>
          <div className="lk-inline">
            <input placeholder="Rechercher un élève…" value={q} onChange={(e) => setQ(e.target.value)} />
            <select value={classId} onChange={(e) => setClassId(e.target.value)}>
              <option value="all">Toutes les classes</option>
              {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div className="chips">
            {[['tous', 'Tous'], ['impayes', 'Impayés'], ['partiels', 'Partiels'], ['soldes', 'Soldés']].map(([k, l]) => (
              <button key={k} className={filter === k ? 'on' : ''} onClick={() => setFilter(k)}>{l}</button>
            ))}
          </div>
          <div className="meta">Encaissé : <strong>{fcfa(totPaid)}</strong> sur {fcfa(totDue)} · reste {fcfa(Math.max(0, totDue - totPaid))}</div>
          {shown.length === 0 && <div className="empty">Aucun élève ne correspond.</div>}
          {shown.map((r) => {
            const [label, cls] = state(r);
            return (
              <div className="lk-card" key={r.student_id}>
                <div className="lk-inline" style={{ justifyContent: 'space-between', cursor: 'pointer' }} onClick={() => openStudent(r)}>
                  <div className="person">{r.first_name} {r.last_name} <span className="tag">{r.class_name}</span></div>
                  <div><span className="meta">{fcfa(r.paid)} / {fcfa(r.due)}</span> <span className={'badge ' + cls}>{label}</span></div>
                </div>
                {open?.student_id === r.student_id && (
                  <>
                    <form className="lk-inline" onSubmit={addPayment}>
                      <input type="number" min="1" placeholder="Montant" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} style={{ maxWidth: 140 }} />
                      <select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
                        {Object.entries(METHODS).filter(([k]) => k !== 'virement').map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </select>
                      <select value={form.fee_id} onChange={(e) => setForm({ ...form, fee_id: e.target.value })}>
                        <option value="">Frais (facultatif)</option>
                        {fees.filter((f) => f.class_id === r.class_id || f.class_id === null).map((f) => <option key={f.id} value={f.id}>{f.label}</option>)}
                      </select>
                      <button>Encaisser</button>
                    </form>
                    {hist.map((p) => (
                      <div className="row" key={p.id}>
                        <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                        <span>{fcfa(p.amount)} <button className="btn-small btn-danger" onClick={() => delPayment(p.id)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
                      </div>
                    ))}
                  </>
                )}
              </div>
            );
          })}
        </>
      )}

      {tab === 'frais' && (
        <>
          <div className="lk-card">
            <h3><Icon name="school" /> Frais pour toute l'école</h3>
            <span className="meta">S'appliquent automatiquement à chaque élève, même dans les classes créées plus tard.</span>
            {fees.filter((f) => f.class_id === null).length === 0 && <span className="meta">Aucun frais général pour le moment.</span>}
            {fees.filter((f) => f.class_id === null).map((f) => (
              <div className="row" key={f.id}>
                <div className="person">{f.label}</div>
                <span>{fcfa(f.amount)} <button className="btn-small btn-ghost" onClick={() => editFee(f)}>Modifier</button> <button className="btn-small btn-danger" onClick={() => delFee(f)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
              </div>
            ))}
          </div>

          <div className="lk-card">
            <h3><Icon name="target" /> Frais spécifiques à une classe</h3>
            {classes.filter((c) => fees.some((f) => f.class_id === c.id)).length === 0 && <span className="meta">Aucun frais spécifique pour le moment.</span>}
            {classes.filter((c) => fees.some((f) => f.class_id === c.id)).map((c) => (
              <div key={c.id}>
                <span className="tag">{c.name}</span>
                {fees.filter((f) => f.class_id === c.id).map((f) => (
                  <div className="row" key={f.id}>
                    <div className="person">{f.label}</div>
                    <span>{fcfa(f.amount)} <button className="btn-small btn-ghost" onClick={() => editFee(f)}>Modifier</button> <button className="btn-small btn-danger" onClick={() => delFee(f)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
                  </div>
                ))}
              </div>
            ))}
          </div>

          <form className="lk-card" onSubmit={addFee}>
            <h3>Ajouter un frais</h3>
            <div className="lk-inline">
              <input placeholder="Nom (ex. Scolarité, Inscription, Uniforme)" value={fee.label} onChange={(e) => setFee({ ...fee, label: e.target.value })} />
              <input type="number" min="1" placeholder="Montant FCFA" value={fee.amount} onChange={(e) => setFee({ ...fee, amount: e.target.value })} style={{ maxWidth: 170 }} />
            </div>
            <div className="chips">
              <button type="button" className={fee.all ? 'on' : ''} onClick={() => setFee({ ...fee, all: true })}><Icon name="school" /> Toute l'école</button>
              {classes.map((c) => (
                <button type="button" key={c.id} className={!fee.all && fee.targets.includes(c.id) ? 'on' : ''}
                  onClick={() => setFee({ ...fee, all: false, targets: fee.targets.includes(c.id) ? fee.targets.filter((x) => x !== c.id) : [...fee.targets, c.id] })}>{c.name}</button>
              ))}
            </div>
            <div><button>Ajouter le frais</button></div>
          </form>
        </>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/parametres/page.js"
mkdir -p "$(dirname "app/parametres/page.js")"
cat > 'app/parametres/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { useSettings } from '../../lib/useSettings';
import { PRESETS, DEFAULTS, periodWord } from '../../lib/settings';
import { appreciation, fmt } from '../../lib/grades';

const Row = ({ label, hint, children }) => (
  <div style={{ display: 'grid', gap: 4, padding: '10px 0', borderBottom: '1px solid var(--line)' }}>
    <b>{label}</b>
    {hint && <span className="meta">{hint}</span>}
    <div className="lk-inline" style={{ flexWrap: 'wrap' }}>{children}</div>
  </div>
);

export default function Parametres() {
  const { profile, status } = useProfile(['admin']);
  const saved = useSettings(status === 'ok');
  const [f, setF] = useState(DEFAULTS);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const [classes, setClasses] = useState([]);
  const [cid, setCid] = useState('');
  const [subs, setSubs] = useState([]);
  const [cm, setCm] = useState('');

  useEffect(() => { setF(saved); }, [saved]);
  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('classes').select('id, name').order('name').then(({ data }) => { setClasses(data || []); if (data?.length) setCid(data[0].id); });
  }, [status]);

  async function loadSubs() {
    if (!cid) return setSubs([]);
    const [t, c] = await Promise.all([
      supabase.from('teaching').select('subject_id, subjects(id, name, coefficient)').eq('class_id', cid),
      supabase.from('class_coefficients').select('subject_id, coefficient').eq('class_id', cid),
    ]);
    const over = Object.fromEntries((c.data || []).map((x) => [x.subject_id, Number(x.coefficient)]));
    const seen = new Set(), list = [];
    (t.data || []).forEach((x) => { if (x.subjects && !seen.has(x.subject_id)) { seen.add(x.subject_id); list.push({ ...x.subjects, custom: over[x.subject_id] }); } });
    setSubs(list.sort((a, b) => a.name.localeCompare(b.name)));
  }
  useEffect(() => { loadSubs(); setCm(''); }, [cid]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const set = (k, v) => setF((p) => ({ ...p, [k]: v }));
  const applyPreset = (p) => { setF((x) => ({ ...x, ...p.values })); setMsg({ ok: true, t: `Modèle « ${p.label} » appliqué. Vérifie puis clique sur Enregistrer.` }); };

  async function save() {
    setBusy(true); setMsg(null);
    const { error } = await supabase.rpc('update_school_settings', { p_settings: {
      period_name: f.period_name, periods: Number(f.periods), scale: Number(f.scale), weight_devoir: Number(f.weight_devoir),
      pass_mark: Number(String(f.pass_mark).replace(',', '.')), show_rank: !!f.show_rank, language: f.language, bulletin_header: f.bulletin_header || '',
    } });
    setBusy(false);
    setMsg(error ? { ok: false, t: error.message } : { ok: true, t: 'Paramètres enregistrés. Ils s\'appliquent partout (notes, bulletins, tableau de bord).' });
  }

  async function saveCoef(s, value) {
    const v = value.trim().replace(',', '.');
    if (v === '' && s.custom == null) return;
    if (v === '') await supabase.from('class_coefficients').delete().eq('class_id', cid).eq('subject_id', s.id);
    else {
      const n = Number(v);
      if (!(n > 0 && n <= 20)) return setCm('Le coefficient doit être entre 0,5 et 20.');
      if (n === s.custom) return;
      const { error } = await supabase.from('class_coefficients').upsert({ class_id: cid, subject_id: s.id, coefficient: n });
      if (error) return setCm(error.message);
    }
    setCm('Enregistré'); loadSubs();
  }

  // Exemple en direct : devoirs à 60 % du barème, composition à 75 %
  const wD = Number(f.weight_devoir) / 100, scale = Number(f.scale) || 20;
  const exD = scale * 0.6, exC = scale * 0.75, exAvg = wD * exD + (1 - wD) * exC;
  const pw = periodWord(f);

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Paramètres de l'école</h1><div className="sub">Adapte Lakol à la façon de travailler de ton école. Seul le directeur voit cette page.</div></div></div>

      <div className="lk-card">
        <h3>Modèle de départ</h3>
        <div className="lk-inline" style={{ flexWrap: 'wrap' }}>
          {PRESETS.map((p) => <button key={p.id} type="button" className="btn-ghost" onClick={() => applyPreset(p)}>{p.label}<br /><small style={{ opacity: .7 }}>{p.hint}</small></button>)}
        </div>
      </div>

      <div className="lk-card">
        <h3>Notes et bulletins</h3>
        <Row label="Découpage de l'année">
          <div className="tabs">{[['trimestre', 'Trimestres'], ['semestre', 'Semestres']].map(([k, l]) => <button key={k} type="button" className={f.period_name === k ? 'on' : ''} onClick={() => set('period_name', k)}>{l}</button>)}</div>
          <select value={f.periods} onChange={(e) => set('periods', Number(e.target.value))} style={{ maxWidth: 160 }}>{[2, 3, 4].map((n) => <option key={n} value={n}>{n} périodes</option>)}</select>
        </Row>
        <Row label="Barème des notes" hint="Les notes déjà saisies ne sont pas converties : change le barème avant la saisie.">
          <div className="tabs">{[10, 20, 100].map((n) => <button key={n} type="button" className={Number(f.scale) === n ? 'on' : ''} onClick={() => set('scale', n)}>/{n}</button>)}</div>
        </Row>
        <Row label="Poids des devoirs dans la moyenne" hint={`Le reste va aux compositions. Si une matière n'a que des devoirs (ou que des compositions), la moyenne est simple.`}>
          <input type="range" min="0" max="100" step="5" value={f.weight_devoir} onChange={(e) => set('weight_devoir', Number(e.target.value))} style={{ maxWidth: 260 }} />
          <b>Devoirs {f.weight_devoir} % · Compositions {100 - f.weight_devoir} %</b>
        </Row>
        <Row label={`Note de passage (sur ${scale})`} hint="Sert aux mentions et aux couleurs (rouge en dessous).">
          <input inputMode="decimal" value={f.pass_mark} onChange={(e) => set('pass_mark', e.target.value)} style={{ maxWidth: 110 }} />
        </Row>
        <Row label="Rang dans la classe sur le bulletin">
          <label className="lk-inline"><input type="checkbox" checked={!!f.show_rank} onChange={(e) => set('show_rank', e.target.checked)} /> Afficher le rang</label>
        </Row>
        <Row label="Langue du bulletin" hint="Titres et mentions du document (PDF, Word, impression). L'arabe viendra plus tard.">
          <select value={f.language} onChange={(e) => set('language', e.target.value)} style={{ maxWidth: 200 }}><option value="fr">Français</option><option value="en">English</option></select>
        </Row>
        <Row label="En-tête du bulletin (en haut à gauche)" hint="Ex. nom du pays et devise, ou « Ministère de l'Éducation ». Une ligne par retour à la ligne.">
          <textarea rows={2} maxLength={160} value={f.bulletin_header} onChange={(e) => set('bulletin_header', e.target.value)} style={{ width: '100%' }} />
        </Row>

        <div className="lk-grid-box" style={{ marginTop: 14 }}>
          <b>Exemple avec ces réglages</b>
          <div className="meta">Un élève a {fmt(exD)}/{scale} en devoirs et {fmt(exC)}/{scale} en composition. Moyenne de la matière : <b>{fmt(exAvg)}/{scale}</b> — {appreciation(exAvg, { scale, pass_mark: Number(String(f.pass_mark).replace(',', '.')) || 0 }, f.language)}.</div>
        </div>

        <div className="lk-inline" style={{ marginTop: 14 }}>
          <button onClick={save} disabled={busy}>{busy ? 'Enregistrement…' : 'Enregistrer les paramètres'}</button>
          {msg && <span className={msg.ok ? 'lk-ok' : 'lk-low'}>{msg.t}</span>}
        </div>
      </div>

      <div className="lk-card">
        <h3>Coefficients par classe</h3>
        <p className="meta">La 6e et la terminale n'ont pas les mêmes coefficients. Laisse vide pour garder le coefficient normal de la matière.</p>
        <div className="lk-inline">
          <select value={cid} onChange={(e) => setCid(e.target.value)}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
          {cm && <span className="meta">{cm}</span>}
        </div>
        {subs.length === 0 && <div className="empty">Aucune matière pour cette classe (un professeur doit d'abord la choisir).</div>}
        {subs.map((s) => (
          <div className="row" key={cid + s.id}>
            <div className="person">{s.name} <span className="tag">normal : {s.coefficient}</span></div>
            <input inputMode="decimal" defaultValue={s.custom ?? ''} placeholder={String(s.coefficient)} style={{ maxWidth: 90 }}
              onBlur={(e) => saveCoef(s, e.target.value)} onKeyDown={(e) => e.key === 'Enter' && e.target.blur()} />
          </div>
        ))}
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/parent/page.js"
mkdir -p "$(dirname "app/parent/page.js")"
cat > 'app/parent/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentFile from '../components/StudentFile';

export default function Parent() {
  const { profile, status } = useProfile(['parent']);
  const [kids, setKids] = useState([]);
  const [current, setCurrent] = useState(null);
  const [code, setCode] = useState('');
  const [msg, setMsg] = useState('');

  async function load() {
    const { data } = await supabase.from('students')
      .select('id, first_name, last_name, classes(name)').order('first_name');
    setKids(data || []);
    if (data?.length && !current) setCurrent(data[0].id);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function link(e) {
    e.preventDefault();
    setMsg('');
    const { error } = await supabase.rpc('link_child', { p_code: code.trim().toUpperCase() });
    if (error) setMsg(error.message); else { setCode(''); setMsg('Enfant ajouté'); load(); }
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  return (
    <div className="lk-page">
      <div className="hero">
        <div className="topbar">
          <div>
            <h1>Bonjour {(profile.full_name || '').split(' ')[0]}</h1>
            <div className="sub">{kids.length > 1 ? 'Choisis un enfant pour voir sa fiche' : 'Suivi de la scolarité de ton enfant'}</div>
          </div>
        </div>
        {kids.length > 1 && (
          <div className="tabs">
            {kids.map((k) => (
              <button key={k.id} className={current === k.id ? 'on' : ''} onClick={() => setCurrent(k.id)}>
                {k.first_name} <small>{k.classes?.name}</small>
              </button>
            ))}
          </div>
        )}
      </div>
      {current ? <StudentFile key={current} studentId={current} role="parent" /> : <div className="empty">Aucun enfant lié à ton compte.</div>}
      <form className="lk-card lk-inline" onSubmit={link}>
        <label className="lk-label">Ajouter un autre enfant</label>
        <input placeholder="Code de l'élève (8 caractères)" value={code} onChange={(e) => setCode(e.target.value)} />
        <button disabled={!code.trim()}>Ajouter</button>
        {msg && <span className="meta">{msg}</span>}
      </form>
    </div>
  );
}
LAKOL_EOF

save "app/planning/page.js"
mkdir -p "$(dirname "app/planning/page.js")"
cat > 'app/planning/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { pingNotify } from '../../lib/notify';
import { useSettings } from '../../lib/useSettings';
import { termOfDate, periodWord } from '../../lib/settings';
import Icon from '../components/Icon';

const DAYS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const KINDS = { devoir: ['Devoir', 'mid'], examen: ['Examen', 'bad'], composition: ['Composition', ''] };
const PALETTE = ['#6D4AFF', '#0E9B8F', '#F2603F', '#C98400', '#D63384', '#3B82F6'];
const HOUR_H = 56;
const hm = (t) => (t || '').slice(0, 5);
const mins = (t) => { const [h, m] = hm(t).split(':').map(Number); return h * 60 + m; };
const ymd = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const daysUntil = (d) => Math.round((new Date(d + 'T00:00') - new Date(ymd() + 'T00:00')) / 864e5);
const colorOf = (name, list) => PALETTE[Math.max(0, list.indexOf(name || '')) % PALETTE.length];

export default function Planning() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const st = useSettings(status === 'ok');
  const termOf = (date) => termOfDate(date, st);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [classId, setClassId] = useState('');
  const [tab, setTab] = useState('edt');
  const [slots, setSlots] = useState([]);
  const [todo, setTodo] = useState([]);
  const [plans, setPlans] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [slot, setSlot] = useState({ day: '1', start: '08:00', end: '09:00', subject_id: '', room: '' });
  const [a, setA] = useState({ kind: 'devoir', subject_id: '', title: '', due_date: '', chapters: '' });
  useEffect(() => { setA((p) => (p.due_date ? p : { ...p, due_date: ymd() })); }, []);
  const [err, setErr] = useState('');
  const formRef = useRef(null);
  const canEdit = profile?.role !== 'parent';

  useEffect(() => {
    if (status !== 'ok') return;
    (async () => {
      let list;
      if (profile.role === 'teacher') {
        const { data: t } = await supabase.from('teaching').select('class_id').eq('teacher_id', profile.id);
        const { data: cr } = await supabase.from('classes').select('id').eq('created_by', profile.id);
        const ids = [...new Set([...(t || []).map((x) => x.class_id), ...(cr || []).map((x) => x.id)])];
        list = ids.length ? (await supabase.from('classes').select('id, name').in('id', ids).order('name')).data : [];
      } else list = (await supabase.from('classes').select('id, name').order('name')).data;
      setClasses(list || []); if (list?.length) setClassId(list[0].id);
      setSubjects((await supabase.from('subjects').select('id, name').order('name')).data || []);
    })();
  }, [status]);

  async function load() {
    if (!classId) return;
    const [t, d, pl] = await Promise.all([
      supabase.from('timetable').select('id, day, start_time, end_time, room, subject_id, subjects(name)').eq('class_id', classId).order('start_time'),
      supabase.from('assignments').select('id, kind, title, due_date, chapters, term, subject_id, subjects(name)').eq('class_id', classId).order('due_date'),
      profile.role !== 'parent' ? supabase.from('teaching').select('subject_id, devoirs_per_term, compositions_per_term, subjects(name)').eq('class_id', classId) : { data: [] },
    ]);
    setSlots(t.data || []); setTodo(d.data || []); setPlans(pl.data || []);
    const e = t.error || d.error;
    setErr(e ? (/assignments|schema cache|does not exist|chapters/i.test(e.message) ? "La migration SQL n'est pas à jour dans Supabase." : e.message) : '');
  }
  useEffect(() => { load(); }, [classId]);

  async function addSlot(e) {
    e?.preventDefault(); setErr('');
    if (slot.end <= slot.start) return setErr("L'heure de fin doit être après le début.");
    const day = Number(slot.day);
    const clash = slots.find((s) => s.day === day && hm(s.start_time) < slot.end && hm(s.end_time) > slot.start);
    if (clash) return setErr(`Ce créneau chevauche ${clash.subjects?.name || 'un autre cours'} (${hm(clash.start_time)}–${hm(clash.end_time)}).`);
    const { error } = await supabase.from('timetable').insert({
      school_id: profile.school_id, class_id: classId, day, start_time: slot.start, end_time: slot.end,
      subject_id: slot.subject_id || null, teacher_id: profile.role === 'teacher' ? profile.id : null, room: slot.room || null,
    });
    if (error) setErr(error.message); else { setSlot({ ...slot, start: slot.end, end: slot.end, room: '' }); load(); }
  }
  async function addAssignment(e) {
    e.preventDefault(); setErr('');
    if (!a.title.trim()) return;
    const { error } = await supabase.from('assignments').insert({
      school_id: profile.school_id, class_id: classId, kind: a.kind, subject_id: a.subject_id || null,
      title: a.title.trim(), due_date: a.due_date, term: termOf(a.due_date), chapters: a.chapters.trim() || null, created_by: profile.id,
    });
    if (error) setErr(error.message); else { setA({ ...a, title: '', chapters: '' }); pingNotify(); load(); }
  }
  const del = async (table, id) => { await supabase.from(table).delete().eq('id', id); load(); };
  const pick = (day, start) => {
    if (!canEdit) return;
    const [h, m] = start.split(':').map(Number);
    const end = `${String(Math.min(h + 1, 23)).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    setSlot({ ...slot, day: String(day), start, end }); setShowForm(true);
    setTimeout(() => formRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 50);
  };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const names = [...new Set(subjects.map((s) => s.name))];
  // plage horaire affichée
  const lo = Math.min(7, ...slots.map((s) => Math.floor(mins(s.start_time) / 60)));
  const hi = Math.max(16, ...slots.map((s) => Math.ceil(mins(s.end_time) / 60)));
  const hours = Array.from({ length: hi - lo + 1 }, (_, i) => lo + i);
  const todayIdx = (new Date().getDay() + 6) % 7 + 1; // 1 = lundi
  const todaySlots = slots.filter((s) => s.day === todayIdx).sort((x, y) => mins(x.start_time) - mins(y.start_time));
  const nowMin = new Date().getHours() * 60 + new Date().getMinutes();
  const nextCourse = todaySlots.find((s) => mins(s.end_time) > nowMin);

  const upcoming = todo.filter((x) => x.due_date >= ymd());
  const past = todo.filter((x) => x.due_date < ymd()).reverse();
  const groups = [
    ['Cette semaine', upcoming.filter((x) => daysUntil(x.due_date) <= 7)],
    ['Semaine prochaine', upcoming.filter((x) => daysUntil(x.due_date) > 7 && daysUntil(x.due_date) <= 14)],
    ['Plus tard', upcoming.filter((x) => daysUntil(x.due_date) > 14)],
  ].filter(([, l]) => l.length);
  const curTerm = termOf(ymd());
  const countOf = (sid, kinds) => todo.filter((x) => x.subject_id === sid && kinds.includes(x.kind) && (x.term || termOf(x.due_date)) === curTerm).length;

  const card = (x, isPast) => {
    const n = daysUntil(x.due_date);
    const [label, cls] = KINDS[x.kind];
    return (
      <div className={'lk-card lift asg' + (isPast ? ' lk-past' : '')} key={x.id}>
        <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
          <span className={'badge ' + cls}>{label}</span>
          {!isPast && <span className={'badge ' + (n <= 1 ? 'bad' : n <= 7 ? 'mid' : '')}>{n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} jours`}</span>}
        </div>
        <h3>{x.title}</h3>
        <div className="meta">{x.subjects?.name && <b>{x.subjects.name} · </b>}{new Date(x.due_date + 'T00:00').toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</div>
        {x.chapters && <div className="tag" style={{ width: 'fit-content' }}><Icon name="book" size={14} /> Chapitres : {x.chapters}</div>}
        {canEdit && <div><button className="btn-small btn-danger" onClick={() => del('assignments', x.id)}>Supprimer</button></div>}
      </div>
    );
  };

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>Planning</h1><div className="sub">Emploi du temps, devoirs et examens de la classe.</div></div>
        <div className="tabs">
          <button className={tab === 'edt' ? 'on' : ''} onClick={() => setTab('edt')}><Icon name="calendar" /> Emploi du temps</button>
          <button className={tab === 'dev' ? 'on' : ''} onClick={() => setTab('dev')}><Icon name="edit" /> Devoirs &amp; examens {upcoming.length > 0 && <small style={{ color: 'inherit' }}>({upcoming.length})</small>}</button>
        </div>
      </div>
      {err && <div className="notice">{err}</div>}
      {classes.length === 0 && <div className="empty">{profile.role === 'parent' ? "Aucune classe liée à ton enfant pour le moment." : <>Aucune classe pour le moment. <a href="/classes">Crée ou rejoins une classe →</a></>}</div>}

      {classes.length > 0 && (
        <div className="chips">
          {classes.map((c) => <button key={c.id} className={classId === c.id ? 'on' : ''} onClick={() => setClassId(c.id)}>{c.name}</button>)}
        </div>
      )}

      {classId && tab === 'edt' && (
        <>
          <div className="lk-card today">
            <h3><Icon name="sun" /> Aujourd'hui · {DAYS[todayIdx - 1] || 'Dimanche'}</h3>
            {todaySlots.length === 0 ? <span className="meta">Pas de cours aujourd'hui pour cette classe.</span> : (
              <div className="lk-inline" style={{ gap: 10 }}>
                {todaySlots.map((s) => {
                  const live = mins(s.start_time) <= nowMin && nowMin < mins(s.end_time);
                  return (
                    <div className={'pill-course' + (live ? ' live' : '')} key={s.id} style={{ background: colorOf(s.subjects?.name, names) }}>
                      <b>{s.subjects?.name || 'Cours'}</b><span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span>
                      {live && <em>En cours</em>}{!live && nextCourse?.id === s.id && <em>Prochain</em>}
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {canEdit && (
            <div ref={formRef}>
              {!showForm ? <button onClick={() => setShowForm(true)}>+ Ajouter un cours</button> : (
                <form className="lk-card lk-inline" onSubmit={addSlot}>
                  <select value={slot.day} onChange={(e) => setSlot({ ...slot, day: e.target.value })}>{DAYS.map((d, i) => <option key={d} value={i + 1}>{d}</option>)}</select>
                  <input type="time" value={slot.start} onChange={(e) => setSlot({ ...slot, start: e.target.value })} />
                  <span className="meta">à</span>
                  <input type="time" value={slot.end} onChange={(e) => setSlot({ ...slot, end: e.target.value })} />
                  <select value={slot.subject_id} onChange={(e) => setSlot({ ...slot, subject_id: e.target.value })}>
                    <option value="">Matière</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                  <input placeholder="Salle" value={slot.room} onChange={(e) => setSlot({ ...slot, room: e.target.value })} style={{ maxWidth: 100 }} />
                  <button>Ajouter</button>
                  <button type="button" className="btn-ghost" onClick={() => setShowForm(false)}>Fermer</button>
                </form>
              )}
              {canEdit && <div className="meta" style={{ marginTop: 6 }}>Astuce : clique sur une case vide de la grille pour préremplir le jour et l'heure.</div>}
            </div>
          )}

          <div className="lk-card tt-wrap">
            <div className="tt" style={{ '--hh': HOUR_H + 'px' }}>
              <div className="tt-head" />
              {DAYS.map((d, i) => <div key={d} className={'tt-head' + (i + 1 === todayIdx ? ' today' : '')}>{d}</div>)}
              <div className="tt-hours" style={{ height: hours.length * HOUR_H }}>
                {hours.map((h, i) => <span key={h} style={{ top: i * HOUR_H }}>{String(h).padStart(2, '0')}:00</span>)}
              </div>
              {DAYS.map((d, i) => (
                <div key={d} className={'tt-col' + (i + 1 === todayIdx ? ' today' : '')} style={{ height: hours.length * HOUR_H }}
                  onClick={(e) => {
                    if (e.target !== e.currentTarget) return;
                    const y = e.nativeEvent.offsetY; const m = Math.floor((y / HOUR_H) * 2) * 30 + lo * 60;
                    pick(i + 1, `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
                  }}>
                  {slots.filter((s) => s.day === i + 1).map((s) => (
                    <div className="tt-block" key={s.id} style={{ top: ((mins(s.start_time) - lo * 60) / 60) * HOUR_H, height: ((mins(s.end_time) - mins(s.start_time)) / 60) * HOUR_H - 3, background: colorOf(s.subjects?.name, names) }}>
                      <b>{s.subjects?.name || 'Cours'}</b>
                      <span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span>
                      {canEdit && <button title="Supprimer" onClick={(e) => { e.stopPropagation(); del('timetable', s.id); }} aria-label="Supprimer"><Icon name="x" size={12} /></button>}
                    </div>
                  ))}
                </div>
              ))}
            </div>
            {/* version téléphone : liste par jour */}
            <div className="tt-list">
              {DAYS.map((d, i) => {
                const list = slots.filter((s) => s.day === i + 1).sort((x, y) => mins(x.start_time) - mins(y.start_time));
                return (
                  <div key={d}>
                    <h4 className={i + 1 === todayIdx ? 'lk-ok' : ''}>{d}</h4>
                    {list.length === 0 && <span className="meta">—</span>}
                    {list.map((s) => <div className="pill-course" key={s.id} style={{ background: colorOf(s.subjects?.name, names), margin: '4px 0' }}><b>{s.subjects?.name || 'Cours'}</b><span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span></div>)}
                  </div>
                );
              })}
            </div>
            {slots.length === 0 && <div className="empty">Aucun cours pour le moment.</div>}
          </div>
        </>
      )}

      {classId && tab === 'dev' && (
        <>
          {canEdit && (
            <form className="lk-card" onSubmit={addAssignment}>
              <h3>Publier un devoir ou un examen</h3>
              <div className="chips">
                {Object.entries(KINDS).map(([k, [l]]) => <button type="button" key={k} className={(k === 'devoir' ? 'amber ' : k === 'examen' ? 'coral ' : '') + (a.kind === k ? 'on' : '')} onClick={() => setA({ ...a, kind: k })}>{l}</button>)}
              </div>
              <div className="lk-inline">
                <select value={a.subject_id} onChange={(e) => setA({ ...a, subject_id: e.target.value })}>
                  <option value="">Matière</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
                <input type="date" value={a.due_date} onChange={(e) => setA({ ...a, due_date: e.target.value })} style={{ maxWidth: 190 }} />
              </div>
              <input placeholder="Sujet (ex. Exercices p.42)" value={a.title} onChange={(e) => setA({ ...a, title: e.target.value })} />
              <input placeholder="Chapitres (facultatif, ex. 1, 2 et 3)" value={a.chapters} onChange={(e) => setA({ ...a, chapters: e.target.value })} />
              <div><button>Publier</button></div>
            </form>
          )}

          {plans.length > 0 && (
            <div className="lk-card">
              <h3><Icon name="target" /> Programme du {periodWord(st)} {curTerm}</h3>
              {plans.map((p, i) => {
                const d = countOf(p.subject_id, ['devoir']); const c = countOf(p.subject_id, ['composition', 'examen']);
                return (
                  <div className="row" key={i}>
                    <div className="person">{p.subjects?.name}</div>
                    <div className="actions">
                      <span className={'badge ' + (d >= p.devoirs_per_term ? 'ok' : 'mid')}>Devoirs {d}/{p.devoirs_per_term}</span>
                      <span className={'badge ' + (c >= p.compositions_per_term ? 'ok' : 'mid')}>Compositions {c}/{p.compositions_per_term}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {groups.length === 0 && <div className="empty">Rien de prévu pour le moment</div>}
          {groups.map(([title, list]) => (
            <div className="lk-stack" key={title}>
              <h3>{title}</h3>
              <div className="grid2">{list.map((x) => card(x, false))}</div>
            </div>
          ))}
          {past.length > 0 && <details className="lk-details"><summary>Passés ({past.length})</summary><div className="grid2">{past.map((x) => card(x, true))}</div></details>}
        </>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/professeurs/page.js"
mkdir -p "$(dirname "app/professeurs/page.js")"
cat > 'app/professeurs/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, METHODS } from '../../lib/grades';
import Icon from '../components/Icon';

const thisMonth = () => new Date().toISOString().slice(0, 7);

export default function Professeurs() {
  const { profile, status } = useProfile(['admin']);
  const [month, setMonth] = useState(thisMonth());
  const [teachers, setTeachers] = useState([]);
  const [teaching, setTeaching] = useState([]);
  const [pay, setPay] = useState({});       // teacher_id -> salaire mensuel
  const [paid, setPaid] = useState([]);     // paiements du mois
  const [code, setCode] = useState('');
  const [open, setOpen] = useState(null);   // prof dont le formulaire de paiement est ouvert
  const [form, setForm] = useState({ amount: '', method: 'cash', note: '' });
  const [err, setErr] = useState('');

  async function load() {
    const [t, tc, sp, sal, sc] = await Promise.all([
      supabase.from('profiles').select('id, full_name, email, active').eq('role', 'teacher').order('full_name'),
      supabase.from('teaching').select('teacher_id, classes(name), subjects(name)'),
      supabase.from('staff_pay').select('teacher_id, monthly_salary'),
      supabase.from('salary_payments').select('id, teacher_id, amount, method, note, paid_at').eq('month', month).order('paid_at', { ascending: false }),
      supabase.from('school_secrets').select('join_code').maybeSingle(),
    ]);
    setTeachers(t.data || []);
    setTeaching(tc.data || []);
    setPay(Object.fromEntries((sp.data || []).map((x) => [x.teacher_id, x.monthly_salary])));
    setPaid(sal.data || []);
    setCode(sc.data?.join_code || '');
  }
  useEffect(() => { if (status === 'ok') load(); }, [status, month]);

  async function saveSalary(id, value) {
    setErr('');
    const n = Math.max(0, parseInt(value, 10) || 0);
    const { error } = await supabase.from('staff_pay').upsert({ teacher_id: id, school_id: profile.school_id, monthly_salary: n });
    if (error) setErr(error.message); else load();
  }
  async function submitPay(e, t) {
    e.preventDefault(); setErr('');
    const amount = parseInt(form.amount, 10);
    if (!amount) return;
    const { error } = await supabase.from('salary_payments').insert({
      school_id: profile.school_id, teacher_id: t.id, month, amount, method: form.method,
      note: form.note || null, created_by: profile.id,
    });
    if (error) return setErr(error.message);
    setOpen(null); setForm({ amount: '', method: 'cash', note: '' }); load();
  }
  async function delPay(id) {
    if (!confirm('Supprimer ce paiement de salaire ?')) return;
    await supabase.from('salary_payments').delete().eq('id', id); load();
  }
  async function toggle(t) {
    if (t.active && !confirm(`Désactiver ${t.full_name} ? Il/elle ne pourra plus se connecter aux données de l'école.`)) return;
    await supabase.from('profiles').update({ active: !t.active }).eq('id', t.id); load();
  }
  async function regen() {
    if (!confirm('Générer un nouveau code ? L\'ancien ne fonctionnera plus pour les nouvelles inscriptions.')) return;
    const { data, error } = await supabase.rpc('regenerate_join_code');
    if (error) setErr(error.message); else setCode(data);
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const totalSalaries = teachers.filter((t) => t.active).reduce((s, t) => s + (pay[t.id] || 0), 0);
  const totalPaid = paid.reduce((s, p) => s + p.amount, 0);

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Professeurs</h1>
        <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} style={{ maxWidth: 170 }} />
      </div>
      {err && <div className="notice">{err}</div>}
      <div className="stats">
        <div className="stat"><small>Professeurs actifs</small><strong>{teachers.filter((t) => t.active).length}</strong></div>
        <div className="stat"><small>Masse salariale / mois</small><strong>{fcfa(totalSalaries)}</strong></div>
        <div className="stat"><small>Versé en {month}</small><strong className="lk-ok">{fcfa(totalPaid)}</strong></div>
        <div className="stat"><small>Reste à verser</small><strong className="lk-warn">{fcfa(Math.max(0, totalSalaries - totalPaid))}</strong></div>
      </div>

      {teachers.length === 0 && (
        <div className="empty">Aucun professeur pour l'instant. Donne-leur le code de l'école ci-dessous : ils s'inscrivent eux-mêmes.</div>
      )}

      {teachers.map((t) => {
        const mine = teaching.filter((x) => x.teacher_id === t.id);
        const classes = [...new Set(mine.map((x) => x.classes?.name).filter(Boolean))];
        const subjects = [...new Set(mine.map((x) => x.subjects?.name).filter(Boolean))];
        const myPaid = paid.filter((p) => p.teacher_id === t.id);
        const sum = myPaid.reduce((s, p) => s + p.amount, 0);
        const salary = pay[t.id] || 0;
        const st = !salary ? null : sum >= salary ? ['Payé', 'ok'] : sum > 0 ? ['Partiel', 'mid'] : ['À payer', 'bad'];
        return (
          <div className={'lk-card' + (t.active ? '' : ' lk-off')} key={t.id}>
            <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
              <div>
                <h3 style={{ margin: 0 }}>{t.full_name} {!t.active && <span className="badge bad">Désactivé</span>}</h3>
                <span className="meta">{t.email}</span>
              </div>
              {st && <span className={'badge ' + st[1]}>{st[0]}</span>}
            </div>
            <div className="meta">
              {classes.length ? <>Classes : {classes.join(', ')} · Matières : {subjects.join(', ')}</> : 'Aucune classe pour le moment'}
            </div>
            <div className="lk-inline">
              <label className="lk-label">Salaire mensuel (FCFA)</label>
              <input type="number" min="0" defaultValue={salary} key={salary} style={{ maxWidth: 160 }}
                onBlur={(e) => { if (Number(e.target.value) !== salary) saveSalary(t.id, e.target.value); }} />
              <span className="meta">Versé : {fcfa(sum)}</span>
              <button className="btn-small" onClick={() => { setOpen(open === t.id ? null : t.id); setForm({ amount: String(Math.max(0, salary - sum) || ''), method: 'cash', note: '' }); }}>Payer le salaire</button>
              <button className="btn-ghost btn-small" onClick={() => toggle(t)}>{t.active ? 'Désactiver' : 'Réactiver'}</button>
            </div>
            {open === t.id && (
              <form className="lk-inline" onSubmit={(e) => submitPay(e, t)}>
                <input type="number" min="1" placeholder="Montant" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} style={{ maxWidth: 140 }} />
                <select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
                  {Object.entries(METHODS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
                <input placeholder="Note (facultatif)" value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
                <button>Enregistrer</button>
              </form>
            )}
            {myPaid.map((p) => (
              <div className="row" key={p.id}>
                <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span> {p.note && <span className="meta">{p.note}</span>}</div>
                <span>{fcfa(p.amount)} <button className="btn-small btn-danger" onClick={() => delPay(p.id)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
              </div>
            ))}
          </div>
        );
      })}

      <div className="lk-card lk-inline">
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0 }}>Code de l'école</h3>
          <span className="meta">À donner aux nouveaux professeurs.</span>
        </div>
        <code className="lk-code">{code}</code>
        <button className="btn-ghost" onClick={regen}>Nouveau code</button>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/profil/page.js"
mkdir -p "$(dirname "app/profil/page.js")"
cat > 'app/profil/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import Link from 'next/link';
import { useProfile, Blocked } from '../../lib/useProfile';
import Icon from '../components/Icon';

const ROLE = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

export default function Profil() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [emailOn, setEmailOn] = useState(true);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('profiles').select('notify_email').eq('id', profile.id).maybeSingle().then(({ data }) => {
      if (data) setEmailOn(data.notify_email);
    });
  }, [status]);

  async function save(e) {
    e.preventDefault(); setMsg('');
    const { error } = await supabase.rpc('update_my_contact', { p_phone: null, p_email_on: emailOn, p_sms_on: false });
    setMsg(error ? error.message : 'Enregistré');
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Mon profil</h1><div className="sub">Choisis comment être prévenu(e) des annonces, messages et nouvelles notes.</div></div></div>
      <div className="lk-card lk-hero">
        <div className="avatar">{profile.full_name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase()}</div>
        <div><h2>{profile.full_name}</h2><div className="meta">{ROLE[profile.role]} · {profile.email}</div></div>
      </div>
      <div className="lk-card">
        <h3><Icon name="shield" /> Sécurité</h3>
        <span className="meta">Conseillé : active la double authentification (un code à 6 chiffres en plus du mot de passe). Facultatif.</span>
        <div className="lk-inline"><Link href="/securite" className="btn-ghost" style={{ display: 'inline-block', padding: '10px 18px', borderRadius: 12 }}>Gérer la sécurité de mon compte</Link></div>
      </div>
      <form className="lk-card" onSubmit={save}>
        <h3><Icon name="bell" /> Notifications</h3>
        <label className="lk-inline"><input type="checkbox" checked={emailOn} onChange={(e) => setEmailOn(e.target.checked)} /> <span>Recevoir un <b>email</b> ({profile.email})</span></label>
        <span className="meta">Tu reçois un email pour chaque annonce, nouveau message, nouvelle note et nouveau devoir ou examen. Les SMS arriveront plus tard.</span>
        <div className="lk-inline"><button>Enregistrer</button>{msg && <span className="meta">{msg}</span>}</div>
      </form>
    </div>
  );
}
LAKOL_EOF

save "app/reinitialiser/page.js"
mkdir -p "$(dirname "app/reinitialiser/page.js")"
cat > 'app/reinitialiser/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';
import Logo, { Wordmark } from '../components/Logo';
import MfaCode from '../components/MfaCode';

// Page ouverte depuis le lien « mot de passe oublié » reçu par email
export default function Reinitialiser() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [needCode, setNeedCode] = useState(false);
  const [pw, setPw] = useState(''); const [pw2, setPw2] = useState('');
  const [err, setErr] = useState(''); const [ok, setOk] = useState(false); const [busy, setBusy] = useState(false);

  async function check() {
    const { data } = await supabase.auth.getSession();
    if (!data.session) return false;
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    setNeedCode(!!(aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2'));
    setReady(true);
    return true;
  }
  useEffect(() => {
    check();
    const { data: sub } = supabase.auth.onAuthStateChange((ev) => { if (ev === 'PASSWORD_RECOVERY' || ev === 'SIGNED_IN') check(); });
    const t = setTimeout(async () => { if (!(await check())) setErr('Ce lien est expiré ou déjà utilisé. Retourne à la connexion et demande un nouveau lien.'); }, 4000);
    return () => { sub.subscription.unsubscribe(); clearTimeout(t); };
  }, []);

  async function submit(e) {
    e.preventDefault(); setErr('');
    if (pw.length < 10 || !/[A-Za-z]/.test(pw) || !/[0-9]/.test(pw)) return setErr('Au moins 10 caractères, avec des lettres et des chiffres.');
    if (pw !== pw2) return setErr('Les deux mots de passe ne sont pas identiques.');
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) return setErr(error.message);
    setOk(true); setTimeout(() => router.replace('/'), 1500);
  }

  return (
    <div className="auth">
      <div className="auth-hero"><div className="lk-brand"><Logo size={42} id="lgr" /><Wordmark height={26} /></div><span /><span /></div>
      <div className="auth-form">
        {ready && needCode ? <MfaCode onDone={() => setNeedCode(false)} /> : (
          <form className="auth-box" onSubmit={submit}>
            <h1>Nouveau mot de passe</h1>
            {!ready && !err && <p className="meta">Vérification du lien…</p>}
            {ready && !ok && (<>
              <input type="password" placeholder="Nouveau mot de passe (10 caractères min.)" value={pw} onChange={(e) => setPw(e.target.value)} autoComplete="new-password" required />
              <input type="password" placeholder="Répète le mot de passe" value={pw2} onChange={(e) => setPw2(e.target.value)} autoComplete="new-password" required />
              <button disabled={busy}>{busy ? '…' : 'Enregistrer'}</button>
            </>)}
            {ok && <div className="notice ok">Mot de passe changé. Redirection…</div>}
            {err && <div className="notice">{err}</div>}
            <button type="button" className="btn-ghost" onClick={() => router.replace('/login')}>Retour à la connexion</button>
          </form>
        )}
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/securite/page.js"
mkdir -p "$(dirname "app/securite/page.js")"
cat > 'app/securite/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import Icon from '../components/Icon';

export default function Securite() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [factors, setFactors] = useState([]);
  const [enroll, setEnroll] = useState(null);
  const [code, setCode] = useState('');
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const isAdmin = profile?.role === 'admin';

  async function load() {
    const { data } = await supabase.auth.mfa.listFactors();
    setFactors(data?.totp || []);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function start() {
    setMsg(null); setBusy(true);
    const { data: all } = await supabase.auth.mfa.listFactors();
    for (const f of (all?.all || []).filter((x) => x.status === 'unverified')) await supabase.auth.mfa.unenroll({ factorId: f.id });
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'Lakol ' + new Date().toISOString().slice(0, 16).replace('T', ' ') });
    setBusy(false);
    if (error) return setMsg({ ok: false, t: error.message });
    setEnroll({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
    setCode('');
  }

  async function verify(e) {
    e.preventDefault(); setMsg(null); setBusy(true);
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: enroll.id, code: code.trim() });
    setBusy(false);
    if (error) return setMsg({ ok: false, t: 'Code incorrect. Vérifie l\'heure de ton téléphone et réessaie avec le code actuel.' });
    setEnroll(null); setCode('');
    await load();
    setMsg({ ok: true, t: 'Double authentification activée.' });
  }

  async function remove(f) {
    if (!window.confirm('Retirer cet appareil ? Tu ne pourras plus l\'utiliser pour te connecter.')) return;
    const { error } = await supabase.auth.mfa.unenroll({ factorId: f.id });
    if (error) return setMsg({ ok: false, t: error.message });
    await load(); setMsg({ ok: true, t: 'Appareil retiré.' });
  }

  async function cancel() {
    if (enroll) await supabase.auth.mfa.unenroll({ factorId: enroll.id });
    setEnroll(null); setMsg(null);
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  const active = factors.length > 0;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Sécurité du compte</h1><div className="sub">Protège ton compte avec un code à 6 chiffres en plus du mot de passe.</div></div></div>

      {isAdmin && !active && (
        <div className="notice"><Icon name="shield" /> Conseil : en tant que directeur, tu gères les données de tous les élèves. Activer la double authentification est fortement recommandé, mais ce n'est pas obligatoire. Ça prend 2 minutes.</div>
      )}

      <div className="lk-card">
        <h3>Double authentification {active ? <span className="badge ok">Activée</span> : <span className="badge bad">Désactivée</span>}</h3>
        {!active && !enroll && (
          <>
            <p className="meta">Même si quelqu'un trouve ton mot de passe, il ne pourra pas entrer sans le code de ton téléphone. Il te faut une application d'authentification (Google Authenticator, Microsoft Authenticator, Authy…).</p>
            <div className="lk-inline"><button onClick={start} disabled={busy}>{busy ? '…' : 'Activer la double authentification'}</button></div>
          </>
        )}

        {enroll && (
          <form onSubmit={verify} className="lk-grid-box" style={{ display: 'grid', gap: 12 }}>
            <b>1. Scanne ce QR code avec ton application d'authentification</b>
            <img src={enroll.qr} alt="QR code" width={190} height={190} style={{ background: '#fff', padding: 8, borderRadius: 12 }} />
            <span className="meta">Tu ne peux pas scanner ? Écris cette clé dans l'application : <code style={{ wordBreak: 'break-all' }}>{enroll.secret}</code></span>
            <b>2. Écris le code à 6 chiffres affiché</b>
            <input inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="000000" value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
              style={{ maxWidth: 200, textAlign: 'center', fontSize: '1.4rem', letterSpacing: '.35em' }} />
            <div className="lk-inline"><button disabled={busy || code.length !== 6}>{busy ? '…' : 'Confirmer'}</button><button type="button" className="btn-ghost" onClick={cancel}>Annuler</button></div>
          </form>
        )}

        {active && !enroll && (
          <>
            <p className="meta">À chaque connexion, Lakol te demandera le code de ton application.</p>
            {factors.map((f) => (
              <div className="row" key={f.id}>
                <div className="person"><Icon name="phone" /> {f.friendly_name || 'Appareil'} <span className="meta">ajouté le {new Date(f.created_at).toLocaleDateString('fr-FR')}</span></div>
                <button className="btn-ghost" onClick={() => remove(f)}>Retirer</button>
              </div>
            ))}
            {factors.length === 1 && <p className="meta">Conseil : ajoute un 2e appareil pour ne pas être bloqué si tu perds ton téléphone.</p>}
            <div className="lk-inline"><button className="btn-ghost" onClick={start} disabled={busy}><Icon name="plus" /> Ajouter un autre appareil</button></div>
          </>
        )}
        {msg && <div className={msg.ok ? 'lk-ok' : 'lk-low'} style={{ marginTop: 10 }}>{msg.t}</div>}
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/vie-scolaire/page.js"
mkdir -p "$(dirname "app/vie-scolaire/page.js")"
cat > 'app/vie-scolaire/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const today = () => new Date().toISOString().slice(0, 10);
import { KINDS, KindIcon } from '../../lib/kinds';
import Icon from '../components/Icon';

export default function VieScolaire() {
  const { profile, status } = useProfile(['teacher']);
  const [tab, setTab] = useState('presence');
  const [classes, setClasses] = useState([]);
  const [classId, setClassId] = useState('');
  const [students, setStudents] = useState([]);
  const [date, setDate] = useState('');
  useEffect(() => { setDate(today()); }, []);
  const [att, setAtt] = useState({});
  const [saved, setSaved] = useState('');
  const [notes, setNotes] = useState([]);
  const [f, setF] = useState({ student_id: '', kind: 'bavardage', comment: '', visible: true });
  const [err, setErr] = useState('');

  useEffect(() => {
    if (status !== 'ok') return;
    (async () => {
      const { data: t } = await supabase.from('teaching').select('class_id').eq('teacher_id', profile.id);
      const { data: created } = await supabase.from('classes').select('id').eq('created_by', profile.id);
      const ids = [...new Set([...(t || []).map((x) => x.class_id), ...(created || []).map((x) => x.id)])];
      const { data: c } = ids.length ? await supabase.from('classes').select('id, name').in('id', ids).order('name') : { data: [] };
      setClasses(c || []); if (c?.length) setClassId(c[0].id);
    })();
  }, [status]);

  async function load() {
    if (!classId || !date) return;
    const { data: s } = await supabase.from('students').select('id, first_name, last_name').eq('class_id', classId).order('last_name');
    setStudents(s || []); setF((x) => ({ ...x, student_id: s?.[0]?.id || '' }));
    const { data: a } = await supabase.from('attendance').select('student_id, status').eq('class_id', classId).eq('date', date).eq('created_by', profile.id);
    setAtt(Object.fromEntries((a || []).map((x) => [x.student_id, x.status]))); setSaved('');
    const { data: n } = await supabase.from('behavior_notes').select('id, date, kind, comment, visible_to_parent, students(first_name, last_name)').eq('class_id', classId).order('date', { ascending: false }).order('created_at', { ascending: false }).limit(30);
    setNotes(n || []);
  }
  useEffect(() => { load(); }, [classId, date]);

  async function savePresence() {
    setErr('');
    const rows = students.filter((s) => att[s.id]).map((s) => ({ school_id: profile.school_id, class_id: classId, student_id: s.id, date, status: att[s.id], created_by: profile.id }));
    if (!rows.length) return setErr("Marque au moins un élève.");
    const { error } = await supabase.from('attendance').upsert(rows, { onConflict: 'student_id,class_id,date,created_by' });
    if (error) setErr(error.message); else setSaved(`Présence du ${new Date(date).toLocaleDateString('fr-FR')} enregistrée.`);
  }
  async function addNote(e) {
    e.preventDefault(); setErr('');
    if (!f.student_id) return;
    const { error } = await supabase.from('behavior_notes').insert({ school_id: profile.school_id, class_id: classId, student_id: f.student_id, date, kind: f.kind, comment: f.comment.trim() || null, visible_to_parent: f.visible, created_by: profile.id });
    if (error) return setErr(error.message);
    setF({ ...f, comment: '' }); load();
  }
  const delNote = async (id) => { await supabase.from('behavior_notes').delete().eq('id', id); load(); };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  const allPresent = () => setAtt(Object.fromEntries(students.map((s) => [s.id, 'present'])));
  const count = (k) => students.filter((s) => att[s.id] === k).length;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Vie scolaire</h1><div className="sub">Présence et comportement de tes élèves. Les parents voient les remarques.</div></div></div>
      {err && <div className="notice">{err}</div>}
      {classes.length === 0 ? <div className="empty">Tu n'as pas encore de classe. Crée-en une dans « Mes classes ».</div> : (
        <>
          <div className="lk-card lk-inline">
            <select value={classId} onChange={(e) => setClassId(e.target.value)} style={{ maxWidth: 220 }}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} style={{ maxWidth: 180 }} />
            <div className="tabs">
              <button className={tab === 'presence' ? 'on' : ''} onClick={() => setTab('presence')}>Présence</button>
              <button className={tab === 'comportement' ? 'on' : ''} onClick={() => setTab('comportement')}>Comportement</button>
            </div>
          </div>

          {tab === 'presence' && (
            <div className="lk-card">
              <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
                <span className="meta">{count('present')} présent(s) · {count('late')} en retard · {count('absent')} absent(s)</span>
                <button className="btn-ghost btn-small" onClick={allPresent}>Tout le monde présent</button>
              </div>
              {students.length === 0 && <div className="empty">Aucun élève dans cette classe.</div>}
              {students.map((s) => (
                <div className="row" key={s.id}>
                  <div className="person"><span className="avatar">{(s.first_name[0] || '') + (s.last_name[0] || '')}</span>{s.last_name} {s.first_name}</div>
                  <div className="stt">
                    {[['present', 'Présent'], ['late', 'Retard'], ['absent', 'Absent']].map(([k, l]) => (
                      <button key={k} className={k + (att[s.id] === k ? ' on' : '')} onClick={() => setAtt({ ...att, [s.id]: k })}>{l}</button>
                    ))}
                  </div>
                </div>
              ))}
              <div className="lk-inline"><button onClick={savePresence}>Enregistrer la présence</button>{saved && <span className="meta">{saved}</span>}</div>
            </div>
          )}

          {tab === 'comportement' && (
            <>
              <form className="lk-card" onSubmit={addNote}>
                <h3>Nouvelle remarque</h3>
                <select value={f.student_id} onChange={(e) => setF({ ...f, student_id: e.target.value })}>
                  {students.map((s) => <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>)}
                </select>
                <div className="chips">
                  {Object.entries(KINDS).map(([k, [l]]) => (
                    <button type="button" key={k} className={(k === 'positif' ? 'teal ' : 'coral ') + (f.kind === k ? 'on' : '')} onClick={() => setF({ ...f, kind: k })}><KindIcon k={k} /> {l}</button>
                  ))}
                </div>
                <textarea rows={2} placeholder="Précision (facultatif)" value={f.comment} onChange={(e) => setF({ ...f, comment: e.target.value })} />
                <label className="meta"><input type="checkbox" checked={f.visible} onChange={(e) => setF({ ...f, visible: e.target.checked })} /> Visible par les parents</label>
                <div><button disabled={!f.student_id}>Ajouter la remarque</button></div>
              </form>
              <div className="lk-card">
                <h3>Dernières remarques</h3>
                {notes.length === 0 && <span className="meta">Aucune remarque pour le moment.</span>}
                {notes.map((n) => (
                  <div className="row" key={n.id}>
                    <div className="person"><KindIcon k={n.kind} /> <b>{n.students?.last_name} {n.students?.first_name}</b> <span className={'badge ' + (n.kind === 'positif' ? 'ok' : 'bad')}>{KINDS[n.kind]?.[0]}</span> {n.comment && <span className="meta">{n.comment}</span>}</div>
                    <span className="meta">{new Date(n.date).toLocaleDateString('fr-FR')} {!n.visible_to_parent && <Icon name="lock" size={14} />} <button className="btn-small btn-danger" onClick={() => delNote(n.id)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
                  </div>
                ))}
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
LAKOL_EOF

save "docs/PLAN_URGENCE.md"
mkdir -p "$(dirname "docs/PLAN_URGENCE.md")"
cat > 'docs/PLAN_URGENCE.md' <<'LAKOL_EOF'
# Lakol : plan d'urgence

Ce document dit quoi faire quand quelque chose tourne mal. Garde-le aussi dans un endroit sûr hors de GitHub (par exemple imprimé ou dans ton gestionnaire de mots de passe).

## Ce qui est sauvegardé, et où

| Quoi | Où | Fréquence | Durée de conservation |
|---|---|---|---|
| Toute la base (élèves, notes, paiements, comptes, journal) | GitHub, onglet **Actions**, fichier chiffré | Chaque jour à 03h17 UTC | 90 jours |
| Le code de l'application | GitHub | À chaque `git push` | Illimitée |
| Le plan de la base | `supabase/schema_complet.sql` dans le projet | À chaque nouvelle migration | Illimitée |
| Copie Supabase (plan Pro seulement) | Supabase, Database > Backups | Chaque jour | 7 jours |

Le fichier de sauvegarde est **chiffré** (AES-256). Sans le mot de passe `BACKUP_PASSPHRASE`, il est illisible, même pour GitHub. **Si tu perds ce mot de passe, les sauvegardes sont perdues.** Garde-le dans un gestionnaire de mots de passe ET sur papier, dans deux endroits différents.

Les 3 secrets à connaître (GitHub : dépôt > Settings > Secrets and variables > Actions) :
- `SUPABASE_DB_URL` : adresse de connexion à la base (Supabase > Connect > Session pooler).
- `BACKUP_PASSPHRASE` : mot de passe de chiffrement des sauvegardes.

## Chaque semaine (2 minutes)
1. GitHub > onglet **Actions** > « Sauvegarde quotidienne » : la dernière ligne doit être verte ✅. Si elle est rouge ❌, GitHub t'envoie aussi un email : corrige le jour même.
2. Vérifie qu'un fichier `sauvegarde-lakol-...` existe dans le dernier passage.

## Chaque trimestre : tester la restauration (30 minutes)
Une sauvegarde jamais testée n'est pas une sauvegarde.
1. Crée un projet Supabase **gratuit de test** (il ne sert qu'à ça).
2. Dans son SQL Editor, lance le contenu de `supabase/schema_complet.sql`.
3. Télécharge le dernier fichier de sauvegarde (GitHub > Actions > passage > Artifacts) et décompresse le .zip pour obtenir le fichier `.gpg`.
4. Dans le Terminal (il faut `postgresql` et `gpg` installés : `brew install libpq gnupg`) :
   ```
   BACKUP_PASSPHRASE='ton-mot-de-passe' bash scripts/restaurer.sh lakol_XXXX.dump.gpg "adresse-de-la-base-de-test"
   ```
5. Regarde dans le projet de test : les élèves, les notes et les comptes sont là. Puis supprime le projet de test.

## Urgence 1 : des données ont été effacées ou abîmées
1. **Ne rien supprimer de plus.** Note l'heure approximative du problème.
2. Regarde le **Journal** dans Lakol (menu directeur) : il dit qui a changé quoi, et quand.
3. Si les données sont perdues pour de bon : crée un nouveau projet Supabase, lance `supabase/schema_complet.sql`, puis restaure la dernière bonne sauvegarde (étapes du test ci-dessus, avec le vrai nouveau projet).
4. Dans le nouveau projet : mets les 2 clés (URL et clé publique) dans Netlify (Site configuration > Environment variables) et dans `.env.local`, puis redéploie.
5. Remets aussi dans Supabase les réglages d'authentification (voir « Réglages Supabase » ci-dessous).
6. Prévient les parents et les professeurs : les données saisies depuis la dernière sauvegarde (max. 24 h) sont à ressaisir.

## Urgence 2 : le directeur a perdu son téléphone (double authentification)
1. Supabase > **Authentication > Users** > clique sur l'utilisateur > supprime son « facteur » (MFA).
2. Il se reconnecte avec son mot de passe : Lakol lui fait refaire l'activation avec le nouveau téléphone.
3. Pense à garder la clé de secours affichée lors de l'activation, et à ajouter un 2e appareil.

## Urgence 3 : une clé secrète a fuité (SUPABASE_SERVICE_ROLE_KEY, BREVO_API_KEY, mot de passe de base)
1. Supabase > Project Settings > **API Keys** : régénère la clé secrète. Brevo : supprime la clé et crée-en une nouvelle.
2. Mets les nouvelles valeurs dans Netlify et `.env.local`, puis redéploie.
3. Supabase > Project Settings > Database : « Reset database password », puis mets à jour le secret GitHub `SUPABASE_DB_URL`.
4. Regarde le Journal : y a-t-il des modifications que personne ne reconnaît ?

## Urgence 4 : le compte d'un professeur ou d'un parent est piraté
1. Dans Lakol, le directeur **désactive** le compte (menu Professeurs). Il ne voit plus rien immédiatement.
2. Supabase > Authentication > Users : supprime ses sessions ou son compte.
3. Regarde le Journal pour voir ce qui a été modifié par ce compte, et corrige.

## Urgence 5 : Lakol ne répond plus
1. https://status.supabase.com et https://www.netlifystatus.com : est-ce une panne chez eux ?
2. Projet Supabase gratuit : il se met en **pause après environ 1 semaine sans activité**. Supabase > Restore project (les données sont gardées). Le plan Pro évite ça.
3. Netlify > Deploys : le dernier déploiement est-il en erreur ? Reviens au précédent (« Publish deploy »).

## Réglages Supabase à retrouver après une restauration
- Authentication > Sign In / Providers > Email : « Confirm email » activé, longueur minimale du mot de passe 10.
- Authentication > Multi-Factor : TOTP activé.
- Authentication > URL Configuration : l'adresse du site Netlify (+ `http://localhost:3000` pour tester).
- Authentication > SMTP Settings : l'envoi par Brevo.

## Objectifs (à ajuster)
- Perte de données maximale acceptable : 24 heures (sauvegarde quotidienne). Avec le plan Pro + récupération à la minute près : 2 minutes.
- Temps pour remettre en route : environ 2 heures avec ce plan.
LAKOL_EOF

save "lib/bulletinExport.js"
mkdir -p "$(dirname "lib/bulletinExport.js")"
cat > 'lib/bulletinExport.js' <<'LAKOL_EOF'
// Téléchargement des bulletins en PDF et en Word (.docx modifiable). Tout se fait dans le navigateur.
import { fmt, appreciation } from './grades';
import { BULLETIN } from './settings';

const plain = (s) => String(s ?? '').replace(/[–—]/g, '-');
export const safeName = (s) => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w-]+/g, '_').replace(/^_+|_+$/g, '');

function save(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// items : [{ name, className, year, lines:[{name,coef,dev,comp,avg}], gen, rank }]
// meta  : { school, city, st, periodTitle }
function rowsOf(it, meta) {
  const { st } = meta;
  return it.lines.map((l) => [l.name, String(l.coef), fmt(l.dev), fmt(l.comp), fmt(l.avg), fmt(l.avg * l.coef), appreciation(l.avg, st, st.language)]);
}

export async function exportPdf(items, meta, filename) {
  const { jsPDF } = await import('jspdf');
  const autoTable = (await import('jspdf-autotable')).default;
  const B = BULLETIN[meta.st.language] || BULLETIN.fr;
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  items.forEach((it, i) => {
    if (i) doc.addPage();
    const W = doc.internal.pageSize.getWidth();
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(60);
    doc.text(plain(meta.st.bulletin_header || '').split('\n'), 15, 16);
    doc.setFont('helvetica', 'bold'); doc.text(plain(meta.school || ''), W - 15, 16, { align: 'right' });
    doc.setFont('helvetica', 'normal'); doc.text(plain(meta.city || ''), W - 15, 21, { align: 'right' });
    doc.setDrawColor(109, 74, 255); doc.setLineWidth(0.6); doc.line(15, 32, W - 15, 32);

    doc.setTextColor(27, 23, 64); doc.setFont('helvetica', 'bold'); doc.setFontSize(15);
    doc.text(plain(`${B.title} - ${meta.periodTitle}`), W / 2, 43, { align: 'center' });
    doc.setFontSize(10.5); doc.setFont('helvetica', 'normal'); doc.setTextColor(30);
    doc.text(plain(`${B.student} : ${it.name}`), 15, 54);
    doc.text(plain(`${B.cls} : ${it.className}  ${it.year ? '(' + it.year + ')' : ''}`), W - 15, 54, { align: 'right' });

    autoTable(doc, {
      startY: 60, theme: 'grid',
      head: [[B.subject, B.coef, B.dev, B.comp, B.avg, B.points, B.remark]],
      body: it.lines.length ? rowsOf(it, meta).map((r) => r.map(plain)) : [[{ content: B.none, colSpan: 7, styles: { halign: 'center' } }]],
      styles: { font: 'helvetica', fontSize: 9.5, cellPadding: 2.2, lineColor: [210, 205, 235], textColor: 40 },
      headStyles: { fillColor: [109, 74, 255], textColor: 255, halign: 'center' },
      alternateRowStyles: { fillColor: [247, 245, 255] },
      columnStyles: { 0: { halign: 'left' }, 1: { halign: 'center', cellWidth: 13 }, 2: { halign: 'center', cellWidth: 21 }, 3: { halign: 'center', cellWidth: 29 }, 4: { halign: 'center', cellWidth: 22, fontStyle: 'bold' }, 5: { halign: 'center', cellWidth: 18 }, 6: { halign: 'left', cellWidth: 30 } },
      margin: { left: 15, right: 15 },
    });
    let y = doc.lastAutoTable.finalY + 10;
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11.5); doc.setTextColor(27, 23, 64);
    doc.text(plain(`${B.general} : ${fmt(it.gen)}/${meta.st.scale}  -  ${appreciation(it.gen, meta.st, meta.st.language)}`), 15, y);
    if (meta.st.show_rank) doc.text(plain(`${B.rank} : ${it.rank}`), W - 15, y, { align: 'right' });
    y += 34; if (y > 270) { doc.addPage(); y = 40; }
    doc.setFont('helvetica', 'normal'); doc.setFontSize(10); doc.setTextColor(60);
    [B.teacher, B.director, B.parents].forEach((t, k) => doc.text(t, 15 + k * ((W - 30) / 3) + (W - 30) / 6, y, { align: 'center' }));
  });
  doc.save(filename);
}

export async function exportDocx(items, meta, filename) {
  const d = await import('docx');
  const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType, BorderStyle, ShadingType, TabStopType } = d;
  const B = BULLETIN[meta.st.language] || BULLETIN.fr;
  const USABLE = 10206; // A4 avec marges de 1,5 cm, en twips
  const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
  const noBorders = { top: none, bottom: none, left: none, right: none };
  const line = { style: BorderStyle.SINGLE, size: 4, color: 'D2CDEB' };
  const cellBorders = { top: line, bottom: line, left: line, right: line };
  const P = (text, o = {}) => new Paragraph({ alignment: o.align, spacing: { after: o.after ?? 60 }, pageBreakBefore: o.pageBreak, children: [new TextRun({ text: String(text), bold: o.bold, size: o.size ?? 21, color: o.color })] });
  const cell = (text, w, o = {}) => new TableCell({
    width: { size: w, type: WidthType.DXA }, borders: o.borders || cellBorders,
    shading: o.fill ? { type: ShadingType.CLEAR, fill: o.fill, color: 'auto' } : undefined,
    margins: { top: 60, bottom: 60, left: 90, right: 90 },
    children: [new Paragraph({ alignment: o.align ?? AlignmentType.CENTER, children: [new TextRun({ text: String(text), bold: o.bold, color: o.color, size: o.size ?? 19 })] })],
  });
  const COLS = [2600, 700, 1000, 1500, 1100, 1000, 2306];

  const children = [];
  items.forEach((it, i) => {
    const hdr = (meta.st.bulletin_header || '').split('\n');
    children.push(new Table({
      width: { size: USABLE, type: WidthType.DXA }, columnWidths: [USABLE / 2, USABLE / 2], borders: { ...noBorders, insideHorizontal: none, insideVertical: none },
      rows: [new TableRow({ children: [
        new TableCell({ width: { size: USABLE / 2, type: WidthType.DXA }, borders: noBorders, children: hdr.map((t, k) => new Paragraph({ children: [new TextRun({ text: t, size: k ? 17 : 19, bold: k === 0 })] })) }),
        new TableCell({ width: { size: USABLE / 2, type: WidthType.DXA }, borders: noBorders, children: [
          new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: meta.school || '', bold: true, size: 21 })] }),
          new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: meta.city || '', size: 17 })] }),
        ] }),
      ] })],
    }));
    // l'élément précédent est un tableau : saut de page porté par le paragraphe suivant
    children.push(P('', { after: 120, pageBreak: false }));
    children.push(P(`${B.title} - ${meta.periodTitle}`, { align: AlignmentType.CENTER, bold: true, size: 30, color: '1B1740', after: 160 }));
    children.push(new Paragraph({ spacing: { after: 160 }, tabStops: [{ type: TabStopType.RIGHT, position: USABLE }], children: [
      new TextRun({ text: `${B.student} : `, size: 21 }), new TextRun({ text: it.name, bold: true, size: 21 }),
      new TextRun({ text: `\t${B.cls} : `, size: 21 }), new TextRun({ text: `${it.className}${it.year ? ' (' + it.year + ')' : ''}`, bold: true, size: 21 }),
    ] }));
    const head = new TableRow({ tableHeader: true, children: [B.subject, B.coef, B.dev, B.comp, B.avg, B.points, B.remark].map((t, k) => cell(t, COLS[k], { bold: true, color: 'FFFFFF', fill: '6D4AFF' })) });
    const body = it.lines.length
      ? rowsOf(it, meta).map((r) => new TableRow({ children: r.map((t, k) => cell(t, COLS[k], { align: k === 0 || k === 6 ? AlignmentType.LEFT : AlignmentType.CENTER, bold: k === 4 })) }))
      : [new TableRow({ children: [new TableCell({ columnSpan: 7, width: { size: USABLE, type: WidthType.DXA }, borders: cellBorders, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: B.none, size: 19 })] })] })] })];
    children.push(new Table({ width: { size: USABLE, type: WidthType.DXA }, columnWidths: COLS, rows: [head, ...body] }));
    children.push(new Paragraph({ spacing: { before: 240, after: 120 }, tabStops: [{ type: TabStopType.RIGHT, position: USABLE }], children: [
      new TextRun({ text: `${B.general} : ${fmt(it.gen)}/${meta.st.scale}  -  ${appreciation(it.gen, meta.st, meta.st.language)}`, bold: true, size: 23 }),
      ...(meta.st.show_rank ? [new TextRun({ text: `\t${B.rank} : ${it.rank}`, bold: true, size: 23 })] : []),
    ] }));
    children.push(P('', { after: 600 }));
    children.push(new Table({
      width: { size: USABLE, type: WidthType.DXA }, columnWidths: [USABLE / 3, USABLE / 3, USABLE / 3], borders: { ...noBorders, insideHorizontal: none, insideVertical: none },
      rows: [new TableRow({ children: [B.teacher, B.director, B.parents].map((t) => cell(t, USABLE / 3, { borders: noBorders, size: 20 })) })],
    }));
    if (i < items.length - 1) children.push(new Paragraph({ pageBreakBefore: true, children: [] }));
  });

  const doc = new Document({
    creator: 'Lakol', title: `${B.title} - ${meta.periodTitle}`,
    styles: { default: { document: { run: { font: 'Arial' } } } },
    sections: [{ properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 850, bottom: 850, left: 850, right: 850 } } }, children }],
  });
  save(await Packer.toBlob(doc), filename);
}
LAKOL_EOF

save "lib/grades.js"
mkdir -p "$(dirname "lib/grades.js")"
cat > 'lib/grades.js' <<'LAKOL_EOF'
export const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);

import { BULLETIN } from './settings';

// Moyenne d'une matière = poids devoirs × moyenne des devoirs + poids compositions × moyenne des compositions
// wD = part des devoirs (0.5 par défaut = moitié-moitié)
export function subjectAvg(grades, wD = 0.5) {
  const d = grades.filter((g) => g.kind === 'devoir').map((g) => Number(g.score));
  const c = grades.filter((g) => g.kind === 'composition').map((g) => Number(g.score));
  if (d.length && c.length) return wD * mean(d) + (1 - wD) * mean(c);
  return mean([...d, ...c].map(Number));
}
export const wDOf = (st) => (st?.weight_devoir ?? 50) / 100;

// rows : [{ avg, coef }]  -> moyenne générale pondérée
export function generalAvg(rows) {
  const ok = rows.filter((r) => r.avg != null);
  const total = ok.reduce((s, r) => s + Number(r.coef), 0);
  if (!total) return null;
  return ok.reduce((s, r) => s + r.avg * Number(r.coef), 0) / total;
}

// Mention : seuils en % du barème (80 / 70 / 60), « Passable » à partir de la note de passage
export function appreciation(avg, st, lang = 'fr') {
  if (avg == null) return '';
  const scale = st?.scale ?? 20, pass = st?.pass_mark ?? 10;
  const m = (BULLETIN[lang] || BULLETIN.fr).marks;
  const pct = (avg / scale) * 100, passPct = (pass / scale) * 100;
  if (pct >= 80 && 80 > passPct) return m[0];
  if (pct >= 70 && 70 > passPct) return m[1];
  if (pct >= 60 && 60 > passPct) return m[2];
  return avg >= pass ? m[3] : m[4];
}

export const fmt = (n) => (n == null ? '–' : Number(n).toFixed(2).replace('.', ','));
export const fcfa = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} F`;
export const METHODS = { moov: 'Moov Money', airtel: 'Airtel Money', orange: 'Orange Money', nita: 'NITA', cash: 'Espèces', virement: 'Virement' };
LAKOL_EOF

save "lib/kinds.js"
mkdir -p "$(dirname "lib/kinds.js")"
cat > 'lib/kinds.js' <<'LAKOL_EOF'
import Icon from '../app/components/Icon';

// [libellé, nom d'icône]
export const KINDS = {
  bavardage: ['Bavardage', 'chat'], perturbation: ['Perturbation', 'bolt'], retard: ['Retard', 'clock'],
  oubli_materiel: ['Oubli de matériel', 'bag'], insolence: ['Insolence', 'frown'], positif: ['Félicitations', 'star'], autre: ['Autre', 'edit'],
};

export function KindIcon({ k }) {
  return <Icon name={(KINDS[k] || [])[1] || 'edit'} size={15} />;
}
LAKOL_EOF

save "lib/notify.js"
mkdir -p "$(dirname "lib/notify.js")"
cat > 'lib/notify.js' <<'LAKOL_EOF'
import { supabase } from './supabase';

// Demande au serveur d'envoyer les emails / SMS en attente (sans bloquer l'écran).
export function pingNotify() {
  supabase.auth.getSession().then(({ data }) => {
    if (!data.session) return;
    fetch('/api/notify', { method: 'POST', headers: { Authorization: `Bearer ${data.session.access_token}` } }).catch(() => {});
  });
}

// Demande au menu de rafraîchir ses pastilles (messages non lus, annonces)
export const refreshBadges = () => { if (typeof window !== 'undefined') window.dispatchEvent(new Event('lakol:refresh')); };
LAKOL_EOF

save "lib/settings.js"
mkdir -p "$(dirname "lib/settings.js")"
cat > 'lib/settings.js' <<'LAKOL_EOF'
// Paramètres de l'école : valeurs par défaut, modèles de départ, libellés
export const DEFAULTS = {
  period_name: 'trimestre', periods: 3, scale: 20, weight_devoir: 50, pass_mark: 10, show_rank: true, language: 'fr',
  bulletin_header: 'République du Niger\nFraternité · Travail · Progrès',
};

export const PRESETS = [
  { id: 'niger', label: 'Standard Niger', hint: '3 trimestres · /20 · passage 10', values: { period_name: 'trimestre', periods: 3, scale: 20, weight_devoir: 50, pass_mark: 10, language: 'fr' } },
  { id: 'semestres', label: 'Semestres', hint: '2 semestres · /20 · passage 10', values: { period_name: 'semestre', periods: 2, scale: 20, weight_devoir: 50, pass_mark: 10, language: 'fr' } },
  { id: 'anglophone', label: 'Anglophone', hint: '3 terms · /100 · passage 50 · bulletin en anglais', values: { period_name: 'trimestre', periods: 3, scale: 100, weight_devoir: 40, pass_mark: 50, language: 'en' } },
];

export const normalize = (s) => ({ ...DEFAULTS, ...(s || {}) });

const WORDS = {
  fr: { trimestre: 'trimestre', semestre: 'semestre', ord: (n) => (n === 1 ? '1er' : `${n}e`), year: 'ANNÉE', yearLong: 'Année complète' },
  en: { trimestre: 'term', semestre: 'semester', ord: (n) => ({ 1: '1st', 2: '2nd', 3: '3rd' }[n] || `${n}th`), year: 'FULL YEAR', yearLong: 'Full year' },
};
const W = (lang) => WORDS[lang] || WORDS.fr;

export const periodWord = (st, lang = 'fr') => W(lang)[st.period_name] || 'trimestre'; // « trimestre » / « term »
export const periodTitle = (n, st, lang = 'fr') => `${W(lang).ord(n)} ${periodWord(st, lang)}`; // « 2e trimestre »
export const periodShort = (n, st) => `${st.period_name === 'semestre' ? 'S' : 'T'}${n}`; // « T2 »
export const periodTab = (n, st) => { const w = periodWord(st); return `${w[0].toUpperCase()}${w.slice(1)} ${n}`; }; // « Trimestre 2 »
export const periodList = (st) => Array.from({ length: st.periods }, (_, i) => i + 1);
export const yearLabel = (lang = 'fr') => W(lang).yearLong;
export const yearUpper = (lang = 'fr') => W(lang).year;

// Période correspondant à une date (année scolaire septembre → août)
export function termOfDate(date, st) {
  const m = Number(String(date).slice(5, 7));
  if (st.periods === 2) return m >= 9 || m === 1 ? 1 : 2;
  if (st.periods === 4) return m >= 9 && m <= 11 ? 1 : m === 12 || m <= 2 ? 2 : m <= 5 ? 3 : 4;
  return m >= 9 ? 1 : m <= 3 ? 2 : 3;
}

// Mots du bulletin
export const BULLETIN = {
  fr: { title: 'BULLETIN DE NOTES', student: 'Élève', cls: 'Classe', subject: 'Matière', coef: 'Coef', dev: 'Devoirs', comp: 'Composition', avg: 'Moyenne', points: 'Points', remark: 'Appréciation',
    general: 'Moyenne générale', rank: 'Rang', none: 'Aucune note', teacher: 'Le professeur principal', director: 'Le Directeur', parents: 'Les parents', of: 'sur',
    marks: ['Très bien', 'Bien', 'Assez bien', 'Passable', 'Insuffisant'] },
  en: { title: 'REPORT CARD', student: 'Student', cls: 'Class', subject: 'Subject', coef: 'Coef.', dev: 'Tests', comp: 'Exams', avg: 'Average', points: 'Points', remark: 'Remark',
    general: 'Overall average', rank: 'Rank', none: 'No grades', teacher: 'Class teacher', director: 'Principal', parents: 'Parents', of: 'of',
    marks: ['Excellent', 'Very good', 'Good', 'Pass', 'Fail'] },
};

export const ordinal = (n, lang = 'fr') => W(lang).ord(n);
LAKOL_EOF

save "lib/supabase.js"
mkdir -p "$(dirname "lib/supabase.js")"
cat > 'lib/supabase.js' <<'LAKOL_EOF'
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
);
export default supabase;
LAKOL_EOF

save "lib/useProfile.js"
mkdir -p "$(dirname "lib/useProfile.js")"
cat > 'lib/useProfile.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from './supabase';

// Charge le profil connecté. allowed = liste des rôles autorisés sur la page.
export function useProfile(allowed) {
  const router = useRouter();
  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState('loading');

  useEffect(() => {
    let alive = true;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { router.replace('/login'); return; }
      // Double authentification : si le compte l'a activée, la session doit être confirmée avec le code
      const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') { router.replace('/login'); return; }
      const { data: p } = await supabase
        .from('profiles')
        .select('id, full_name, role, school_id, active, email')
        .eq('id', data.session.user.id)
        .maybeSingle();
      if (!alive) return;
      if (!p || p.active === false) { setStatus('blocked'); return; }
      if (allowed && !allowed.includes(p.role)) { router.replace('/'); return; }
      if (!alive) return;
      setProfile(p);
      setStatus('ok');
    })();
    return () => { alive = false; };
  }, []);

  return { profile, status };
}

export function Blocked() {
  return (
    <div className="lk-page"><div className="lk-card">
      <h2>Compte inactif</h2>
      <p className="meta">Ton compte est introuvable ou a été désactivé par le directeur de l'école.</p>
      <button className="btn-ghost" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>Se déconnecter</button>
    </div></div>
  );
}
LAKOL_EOF

save "lib/useSettings.js"
mkdir -p "$(dirname "lib/useSettings.js")"
cat > 'lib/useSettings.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from './supabase';
import { DEFAULTS, normalize } from './settings';

// Paramètres de l'école de l'utilisateur connecté (valeurs par défaut tant que ça charge)
export function useSettings(enabled = true) {
  const [st, setSt] = useState(DEFAULTS);
  useEffect(() => {
    if (!enabled) return;
    supabase.from('schools').select('settings').maybeSingle().then(({ data }) => { if (data?.settings) setSt(normalize(data.settings)); });
  }, [enabled]);
  return st;
}
LAKOL_EOF

save "public/icon-192.png"
mkdir -p "$(dirname "public/icon-192.png")"
base64 -d > 'public/icon-192.png' <<'LAKOL_EOF'
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
6apq00kyvSkAAAAASUVORK5CYII=
LAKOL_EOF

save "public/icon-512.png"
mkdir -p "$(dirname "public/icon-512.png")"
base64 -d > 'public/icon-512.png' <<'LAKOL_EOF'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAQAElEQVR4AexdB5gcxdF9o4wkMkgg
IQQIMDnnDAYbk3P4jcnJgCRMzhmRg0TOJpucc84ZJKLJGGxAIqMc+3/VPRvudLrb3dvdmd19/c3W
1FRXVXe/3ns1O3s6dZhrtmV0CAEhIASEQAMi0AFqQkAICAEh0JAIqAA05LZr0UIAgEBoeARUABr+
LSAAhIAQaFQEVAAadee1biEgBBoeARWAhn0LaOFCQAg0OgIqAI3+DtD6hYAQaFgEVAAaduu1cCEg
BBoVgcy6VQAySOgsBISAEGgwBFQAGmzDtVwhIASEQAYBFYAMEjoLgUZBQOsUAjECKgAxEDoJASEg
BBoNARWARttxrVcICAEhECOgAhAD0TgnrVQICAEhEBBQAQg4SAoBISAEGg4BFYCG23ItWAgIgUZF
oPm6VQCaI6JrISAEhECDIKAC0CAbrWUKASEgBJojoALQHBFdC4F6RUDrEgLNEFABaAaILoWAEBAC
jYKACkCj7LTWKQSEgBBohoAKQDNA6vdSKxMCQkAINEVABaApHroSAkJACDQMAioADbPVWqgQEAKN
isCM1q0CMCNkZBcCQkAI1DkCKgB1vsFanhAQAkJgRgioAMwIGdmFQL0goHUIgRkgoAIwA2BkFgJC
QAjUOwIqAPW+w1qfEBACQmAGCKgAzACY+jFrJUJACAiBlhFQAWgZF1mFgBAQAnWPgApA3W+xFigE
hECjItDWulUA2kJI/UJACAiBOkVABaBON1bLEgJCQAi0hYAKQFsIqV8I1CoCmrcQaAMBFYA2AFK3
EBACQqBeEVABqNed1bqEgBAQAm0goALQBkC1262ZCwEhIARaR0AFoHV81CsEhIAQqFsEVADqdmu1
MCEgBBoVgULXrQJQKFLyEwJCQAjUGQIqAHW2oVqOEBACQqBQBFQACkVKfkKgVhDQPIVAgQioABQI
lNyEgBAQAvWGgApAve2o1iMEhIAQKBABFYACgaodN81UCAgBIVAYAioAheEkLyEgBIRA3SGgAlB3
W6oFCQEh0KgIFLtuFYBiEZO/EBACQqBOEFABqJON1DKEgBAQAsUioAJQLGLyFwJpRUDzEgJFIqAC
UCRgchcCQkAI1AsCKgD1spNahxAQAkKgSARUAIoELL3umpkQEAJCoDgEVACKw0veQkAICIG6QUAF
oG62UgsRAkKgUREodd0qAKUipzghIASEQI0joAJQ4xuo6QsBISAESkVABaBU5BQnBNKCgOYhBEpE
QAWgROAUJgSEgBCodQRUAGp9BzV/ISAEhECJCKgAlAhcesI0EyEgBIRAaQioAJSGm6KEgBAQAjWP
gApAzW+hFiAEhECjItDedasAtBdBxQsBISAEahQBFYAa3ThNWwgIASHQXgRUANqLoOKFQFIIaFwh
0E4EVADaCaDChYAQEAK1ioAKQK3unOYtBISAEGgnAioA7QQwuXCNLASEgBBoHwIqAO3DT9FCQAgI
gZpFQAWgZrdOExcCQqBRESjXulUAyoWk8ggBISAEagwBFYAa2zBNVwgIASFQLgRUAMqFpPIIgWoh
oHGEQJkQUAEoE5BKIwSEgBCoNQRUAGptxzTfdiMwxxyz9Zu/z+JLLLzmWiutvMqyVHg5++yztjux
EgiBGkNABaDGNgzQhFtGYMCA/htutNbe++581DEHnnHWURddeup1N5x3x92XP/zYDc+/dNfb7z7y
yRfP//DLCB4ff/7c2yMeofHeB66Je0fkeulGZ/ay6/a7LmMSpmJCpt1rn53+uOGaHKjlGcgqBGoN
ARWAWtuxhp9v9+4zLbnUoptu9scDB+523gXH33XvlW+NePj7H99+9c37b739EjL1oYfvyzKw085b
bLb5huutv3p8j9+vT4H3+HTr188+HzBw/Q3WYBKmYkKmPfPso/91x6UciMO9OfzhO++54tzzj+M0
Ntl0gyWWXGSmmbo1/OYIgBpDQAWgxjasoaY711xzrLTyMtvtsOnhR+5/yWWnPfTo9R98/PR//vfq
sy/c8c8bzz/plEN23X27ddZddf75+3bs2LGayHC4/v37rrvearvtsT2ncf1NFzz34p1ff/sap8dJ
XnzpaYcdsd+222+y4kpL83FTNSemseocgXIvTwWg3IgqX/sQmG22WbbZ9i/DLjnl3Q+e+OjTZx55
/MbLrhhyxFF/32GnzVdZdbleveZsX/rKRnN6nOSOO29+5NEHXH7lGY8+cRMfN414//ELLzppq63/
PMusM1d2eGUXAkUioAJQJGByrwACvKHm97HHHj/wyWduJWNecfWZO//flvP26VWBoRJI2adv77/u
svVV15796RfPP/7UzUcfe9Dqa6zAJScwFQ0pBJoioALQFA9dVRGBAQv357P1m28d9vlXL/L72IMP
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
+fJJTsL5pgAAAABJRU5ErkJggg==
LAKOL_EOF

save "public/manifest.webmanifest"
mkdir -p "$(dirname "public/manifest.webmanifest")"
cat > 'public/manifest.webmanifest' <<'LAKOL_EOF'
{
  "name": "Lakol",
  "short_name": "Lakol",
  "description": "Gestion d'école privée",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#F2F0FF",
  "theme_color": "#14102E",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
LAKOL_EOF

save "scripts/backup.sh"
mkdir -p "$(dirname "scripts/backup.sh")"
cat > 'scripts/backup.sh' <<'LAKOL_EOF'
#!/bin/bash
# Sauvegarde chiffrée de la base Lakol (schémas public + auth).
# Variables obligatoires : DB_URL (adresse de connexion Supabase), BACKUP_PASSPHRASE (mot de passe de chiffrement)
# Variable facultative : PG_BIN (dossier contenant pg_dump et pg_restore)
# Usage : bash scripts/backup.sh [dossier_de_sortie]
set -euo pipefail
: "${DB_URL:?Variable DB_URL manquante (adresse de connexion à la base)}"
: "${BACKUP_PASSPHRASE:?Variable BACKUP_PASSPHRASE manquante (mot de passe de chiffrement)}"
P="${PG_BIN:+$PG_BIN/}"
OUT="${1:-.}"; mkdir -p "$OUT"
RAW="$OUT/lakol_$(date -u +%Y-%m-%d_%H%M).dump"

"${P}pg_dump" "$DB_URL" --format=custom --no-owner --no-privileges --schema=public --schema=auth --file "$RAW"

# Contrôle 1 : le fichier est lisible et contient les tables importantes
LISTE="$RAW.liste"
"${P}pg_restore" --list "$RAW" > "$LISTE"
for t in "public students" "public grades" "public payments" "public profiles" "auth users"; do
  grep -q "TABLE DATA $t " "$LISTE" || { echo "❌ Sauvegarde invalide : table « $t » absente"; rm -f "$RAW" "$LISTE"; exit 1; }
done
# Contrôle 2 : taille minimale
[ "$(wc -c < "$RAW")" -gt 20000 ] || { echo "❌ Sauvegarde trop petite, elle est suspecte"; rm -f "$RAW" "$LISTE"; exit 1; }
rm -f "$LISTE"

# Chiffrement (les données des élèves ne doivent jamais traîner en clair)
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$RAW.gpg" "$RAW"
rm -f "$RAW"
echo "✅ Sauvegarde créée : $RAW.gpg ($(wc -c < "$RAW.gpg") octets)"
LAKOL_EOF

save "scripts/restaurer.sh"
mkdir -p "$(dirname "scripts/restaurer.sh")"
cat > 'scripts/restaurer.sh' <<'LAKOL_EOF'
#!/bin/bash
# Restaure une sauvegarde Lakol dans un projet Supabase NEUF (dont le schéma a déjà été créé avec supabase/schema_complet.sql).
# Usage : BACKUP_PASSPHRASE='...' bash scripts/restaurer.sh lakol_2026-11-14_0317.dump.gpg "postgresql://...adresse de la NOUVELLE base..."
# Variable facultative : PG_BIN (dossier contenant pg_restore et psql)
set -euo pipefail
FILE="${1:?Donne le fichier .gpg}"; NEW_DB="${2:?Donne ladresse de la NOUVELLE base}"
: "${BACKUP_PASSPHRASE:?Variable BACKUP_PASSPHRASE manquante}"
P="${PG_BIN:+$PG_BIN/}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 --decrypt --output "$TMP/lakol.dump" "$FILE"
{
  echo "set session_replication_role = replica;"   # pas de déclencheurs (journal, emails) pendant la restauration
  "${P}pg_restore" --data-only --no-owner --schema=public -f - "$TMP/lakol.dump"
  "${P}pg_restore" --data-only --no-owner --schema=auth -t users -t identities -t mfa_factors -f - "$TMP/lakol.dump"
} | "${P}psql" "$NEW_DB" -v ON_ERROR_STOP=1 -q
echo "✅ Restauration terminée. Vérifie les comptes (Authentication > Users) et connecte-toi."
LAKOL_EOF

save "supabase/schema_complet.sql"
mkdir -p "$(dirname "supabase/schema_complet.sql")"
cat > 'supabase/schema_complet.sql' <<'LAKOL_EOF'
-- LAKOL : schéma complet de la base (schema + migrations 1 à 6), pour recréer la base dans un NOUVEAU projet Supabase.
-- À lancer dans Supabase > SQL Editor d'un projet vide. Régénéré à chaque nouvelle migration.

-- ================= schema.sql =================
-- =====================================================
-- Gestion d'école privée : schéma MVP (Supabase / Postgres)
-- Colle tout ce fichier dans Supabase > SQL Editor > Run
-- =====================================================

-- ---------- TABLES ----------

create table schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  phone text,
  created_at timestamptz default now()
);

-- Un profil par utilisateur connecté (lié à Supabase Auth)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid references schools(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('admin', 'teacher', 'parent')),
  phone text,
  created_at timestamptz default now()
);

create table classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,                -- ex. 6e A
  school_year text not null,         -- ex. 2026-2027
  created_at timestamptz default now()
);

create table students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid references classes(id) on delete set null,
  first_name text not null,
  last_name text not null,
  birth_date date,
  matricule text,
  created_at timestamptz default now(),
  unique (school_id, matricule)
);

create table parents_students (
  parent_id uuid not null references profiles(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  primary key (parent_id, student_id)
);

create table subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,
  coefficient numeric(4,2) not null default 1
);

-- Qui enseigne quelle matière à quelle classe
create table teaching (
  teacher_id uuid not null references profiles(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  primary key (teacher_id, class_id, subject_id)
);

create table grades (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  term int not null check (term between 1 and 3),   -- trimestre
  kind text not null check (kind in ('devoir', 'composition')),
  score numeric(4,2) not null check (score between 0 and 20),
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

create table fees (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid references classes(id) on delete cascade,
  label text not null,               -- ex. Scolarité, Inscription
  amount integer not null            -- en FCFA
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  fee_id uuid references fees(id) on delete set null,
  amount integer not null,           -- en FCFA
  method text not null check (method in ('moov', 'airtel', 'orange', 'nita', 'cash')),
  reference text,
  paid_at timestamptz default now()
);

-- ---------- INDEX ----------
create index on students (school_id, class_id);
create index on grades (student_id, subject_id, term);
create index on payments (student_id);

-- ---------- FONCTIONS UTILITAIRES (pour la sécurité) ----------
-- security definer = évite les boucles infinies dans les règles RLS

create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid()
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

-- ---------- SÉCURITÉ : ROW LEVEL SECURITY ----------
-- Règle d'or : un utilisateur ne voit que les données de SON école.

alter table schools enable row level security;
alter table profiles enable row level security;
alter table classes enable row level security;
alter table students enable row level security;
alter table parents_students enable row level security;
alter table subjects enable row level security;
alter table teaching enable row level security;
alter table grades enable row level security;
alter table fees enable row level security;
alter table payments enable row level security;

-- schools
create policy "voir son école" on schools
  for select using (id = my_school_id());

-- profiles
create policy "voir les profils de son école" on profiles
  for select using (school_id = my_school_id() or id = auth.uid());
create policy "admin gère les profils" on profiles
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- classes, subjects, fees : tout le monde de l'école lit, l'admin écrit
create policy "lire classes" on classes
  for select using (school_id = my_school_id());
create policy "admin écrit classes" on classes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create policy "lire matières" on subjects
  for select using (school_id = my_school_id());
create policy "admin écrit matières" on subjects
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create policy "lire frais" on fees
  for select using (school_id = my_school_id());
create policy "admin écrit frais" on fees
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- students : admin et enseignants voient tous les élèves de l'école,
-- un parent voit seulement ses enfants
create policy "staff voit élèves" on students
  for select using (
    school_id = my_school_id() and my_role() in ('admin', 'teacher')
  );
create policy "parent voit ses enfants" on students
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = students.id and ps.parent_id = auth.uid()
    )
  );
create policy "admin écrit élèves" on students
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- parents_students
create policy "voir liens parents" on parents_students
  for select using (
    parent_id = auth.uid()
    or (my_role() in ('admin', 'teacher')
        and exists (select 1 from students s
                    where s.id = student_id and s.school_id = my_school_id()))
  );
create policy "admin écrit liens parents" on parents_students
  for all using (
    my_role() = 'admin'
    and exists (select 1 from students s
                where s.id = student_id and s.school_id = my_school_id())
  )
  with check (
    my_role() = 'admin'
    and exists (select 1 from students s
                where s.id = student_id and s.school_id = my_school_id())
  );

-- teaching
create policy "voir affectations" on teaching
  for select using (
    teacher_id = auth.uid()
    or (my_role() = 'admin'
        and exists (select 1 from classes c
                    where c.id = class_id and c.school_id = my_school_id()))
  );
create policy "admin écrit affectations" on teaching
  for all using (
    my_role() = 'admin'
    and exists (select 1 from classes c
                where c.id = class_id and c.school_id = my_school_id())
  )
  with check (
    my_role() = 'admin'
    and exists (select 1 from classes c
                where c.id = class_id and c.school_id = my_school_id())
  );

-- grades
create policy "staff voit notes" on grades
  for select using (
    school_id = my_school_id() and my_role() in ('admin', 'teacher')
  );
create policy "parent voit notes de ses enfants" on grades
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = grades.student_id and ps.parent_id = auth.uid()
    )
  );
create policy "admin écrit notes" on grades
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
-- Un enseignant écrit seulement les notes de SES classes/matières
create policy "enseignant ajoute notes" on grades
  for insert with check (
    school_id = my_school_id()
    and my_role() = 'teacher'
    and exists (
      select 1 from teaching t
      join students s on s.class_id = t.class_id
      where t.teacher_id = auth.uid()
        and t.subject_id = grades.subject_id
        and s.id = grades.student_id
    )
  );
create policy "enseignant modifie ses notes" on grades
  for update using (
    school_id = my_school_id() and my_role() = 'teacher' and created_by = auth.uid()
  );

-- payments : admin gère, parent voit les paiements de ses enfants
create policy "admin gère paiements" on payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "parent voit paiements de ses enfants" on payments
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = payments.student_id and ps.parent_id = auth.uid()
    )
  );

-- ---------- VUE : MOYENNES PAR ÉLÈVE, MATIÈRE ET TRIMESTRE ----------
-- Calculées à la demande, jamais stockées.
-- security_invoker = les règles RLS s'appliquent aussi à la vue.
create or replace view student_subject_averages
with (security_invoker = true) as
select
  g.student_id,
  g.subject_id,
  g.term,
  round(avg(g.score), 2) as average
from grades g
group by g.student_id, g.subject_id, g.term;

-- ================= lakol_migration_1.sql =================
-- =====================================================
-- LAKOL : migration 1
-- Rôles (directeur / professeur / parent), classes créées par les
-- profs, présences, comportement, emploi du temps, inscription par code.
-- Supabase > SQL Editor > New query > colle tout > Run
-- (dans la base, le rôle "admin" = Directeur dans l'application)
-- =====================================================

-- ---------- 1. NOUVELLES COLONNES ----------
alter table classes
  add column if not exists created_by uuid references profiles(id) on delete set null;

-- Code donné aux parents pour rejoindre leur enfant
alter table students
  add column if not exists access_code text unique
  default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));

-- ---------- 2. CODE SECRET DE L'ÉCOLE (visible seulement par le directeur) ----------
create table if not exists school_secrets (
  school_id uuid primary key references schools(id) on delete cascade,
  join_code text not null unique
    default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6))
);
insert into school_secrets (school_id) select id from schools on conflict do nothing;

-- ---------- 3. NOUVELLES TABLES ----------
create table if not exists timetable (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid references subjects(id) on delete set null,
  teacher_id uuid references profiles(id) on delete set null,
  day int not null check (day between 1 and 6),       -- 1 = lundi ... 6 = samedi
  start_time time not null,
  end_time time not null,
  room text,
  created_at timestamptz default now()
);

create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  date date not null default current_date,
  status text not null check (status in ('present', 'absent', 'late')),
  note text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique (student_id, class_id, date, created_by)
);

create table if not exists behavior_notes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  date date not null default current_date,
  kind text not null check (kind in
    ('bavardage', 'perturbation', 'retard', 'oubli_materiel', 'insolence', 'positif', 'autre')),
  comment text,
  visible_to_parent boolean not null default true,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now()
);

create index if not exists attendance_class_date on attendance (class_id, date);
create index if not exists behavior_student on behavior_notes (student_id);
create index if not exists timetable_class on timetable (class_id);

-- ---------- 4. FONCTIONS UTILITAIRES (évitent les boucles de sécurité) ----------
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid()
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function public.is_parent_of(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from parents_students where student_id = sid and parent_id = auth.uid()
  )
$$;

create or replace function public.student_in_my_school(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from students where id = sid and school_id = my_school_id())
$$;

create or replace function public.class_in_my_school(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from classes where id = cid and school_id = my_school_id())
$$;

-- Le prof enseigne dans la classe, ou l'a créée
create or replace function public.teaches_class(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from teaching where teacher_id = auth.uid() and class_id = cid)
      or exists (select 1 from classes where id = cid and created_by = auth.uid())
$$;

create or replace function public.teaches_student(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from students s where s.id = sid and teaches_class(s.class_id)
  )
$$;

create or replace function public.teaches_subject_to(sid uuid, subj uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from teaching t
    join students s on s.class_id = t.class_id
    where t.teacher_id = auth.uid() and t.subject_id = subj and s.id = sid
  )
$$;

create or replace function public.parent_has_child_in_class(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from parents_students ps
    join students s on s.id = ps.student_id
    where ps.parent_id = auth.uid() and s.class_id = cid
  )
$$;

-- ---------- 5. INSCRIPTION PAR RÔLE ----------
-- À la création d'un compte, on lit les infos données à l'inscription.
--  admin   : crée une nouvelle école
--  teacher : rejoint une école avec le code de l'école
--  parent  : rejoint un enfant avec le code de l'élève
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role text := meta->>'role';
  v_name text := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(coalesce(new.email, 'utilisateur'), '@', 1));
  v_school uuid;
  v_student uuid;
begin
  if v_role = 'admin' then
    insert into schools (name, city)
    values (coalesce(nullif(trim(meta->>'school_name'), ''), 'Mon école'), nullif(trim(meta->>'city'), ''))
    returning id into v_school;
    insert into school_secrets (school_id) values (v_school);
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'admin');

  elsif v_role = 'teacher' then
    select school_id into v_school from school_secrets
      where join_code = upper(trim(meta->>'school_code'));
    if v_school is null then
      raise exception 'Code école invalide';
    end if;
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'teacher');

  elsif v_role = 'parent' then
    select id, school_id into v_student, v_school from students
      where access_code = upper(trim(meta->>'student_code'));
    if v_student is null then
      raise exception 'Code élève invalide';
    end if;
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'parent');
    insert into parents_students (parent_id, student_id) values (new.id, v_student);
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Un parent ajoute un 2e enfant avec son code
create or replace function public.link_child(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_student uuid;
  v_school uuid;
begin
  if my_role() is distinct from 'parent' then
    raise exception 'Non autorisé';
  end if;
  select id, school_id into v_student, v_school from students
    where access_code = upper(trim(p_code));
  if v_student is null or v_school <> my_school_id() then
    raise exception 'Code invalide';
  end if;
  insert into parents_students (parent_id, student_id)
  values (auth.uid(), v_student) on conflict do nothing;
end $$;

-- Un prof (ou directeur) crée une classe, ses matières et ses élèves d'un coup
-- p_students : une ligne par élève, au format "Nom Prénom"
create or replace function public.create_class(
  p_name text, p_year text, p_subject_ids uuid[], p_students text[]
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_class uuid;
  v_subject uuid;
  v_line text;
  v_last text;
  v_first text;
begin
  if my_role() not in ('teacher', 'admin') then
    raise exception 'Non autorisé';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Donne un nom à la classe';
  end if;

  insert into classes (school_id, name, school_year, created_by)
  values (v_school, trim(p_name), coalesce(nullif(trim(p_year), ''), '2026-2027'), auth.uid())
  returning id into v_class;

  if p_subject_ids is not null then
    foreach v_subject in array p_subject_ids loop
      if exists (select 1 from subjects where id = v_subject and school_id = v_school) then
        insert into teaching (teacher_id, class_id, subject_id)
        values (auth.uid(), v_class, v_subject) on conflict do nothing;
      end if;
    end loop;
  end if;

  if p_students is not null then
    foreach v_line in array p_students loop
      v_line := trim(v_line);
      if v_line <> '' then
        v_last := split_part(v_line, ' ', 1);
        v_first := trim(substr(v_line, length(v_last) + 1));
        insert into students (school_id, class_id, last_name, first_name)
        values (v_school, v_class, v_last, v_first);
      end if;
    end loop;
  end if;

  return v_class;
end $$;

-- ---------- 6. RÈGLES DE SÉCURITÉ (on repart de zéro) ----------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('schools', 'profiles', 'classes', 'subjects', 'students',
                        'parents_students', 'teaching', 'grades')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table school_secrets enable row level security;
alter table timetable enable row level security;
alter table attendance enable row level security;
alter table behavior_notes enable row level security;

-- schools / school_secrets
create policy "schools_select" on schools
  for select using (id = my_school_id());
create policy "secrets_admin" on school_secrets
  for select using (school_id = my_school_id() and my_role() = 'admin');

-- profiles
create policy "profiles_self" on profiles
  for select using (id = auth.uid());
create policy "profiles_admin_select" on profiles
  for select using (my_role() = 'admin' and school_id = my_school_id());
create policy "profiles_admin_write" on profiles
  for all using (my_role() = 'admin' and school_id = my_school_id())
  with check (my_role() = 'admin' and school_id = my_school_id());

-- classes
create policy "classes_select" on classes
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(id))
      or (my_role() = 'parent' and parent_has_child_in_class(id))
    )
  );
create policy "classes_admin_write" on classes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "classes_teacher_update" on classes
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "classes_teacher_delete" on classes
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- subjects : tout le monde lit, prof et directeur ajoutent, directeur gère
create policy "subjects_select" on subjects
  for select using (school_id = my_school_id());
create policy "subjects_insert" on subjects
  for insert with check (school_id = my_school_id() and my_role() in ('admin', 'teacher'));
create policy "subjects_admin_all" on subjects
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- teaching
create policy "teaching_select" on teaching
  for select using (
    teacher_id = auth.uid()
    or (my_role() = 'admin' and class_in_my_school(class_id))
  );
create policy "teaching_teacher_insert" on teaching
  for insert with check (
    my_role() = 'teacher' and teacher_id = auth.uid() and teaches_class(class_id)
  );
create policy "teaching_teacher_delete" on teaching
  for delete using (my_role() = 'teacher' and teacher_id = auth.uid());
create policy "teaching_admin_all" on teaching
  for all using (my_role() = 'admin' and class_in_my_school(class_id))
  with check (my_role() = 'admin' and class_in_my_school(class_id));

-- students
create policy "students_select" on students
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and is_parent_of(id))
  );
create policy "students_admin_write" on students
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "students_teacher_insert" on students
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id)
  );
create policy "students_teacher_update" on students
  for update using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and teaches_class(class_id));
create policy "students_teacher_delete" on students
  for delete using (my_role() = 'teacher' and teaches_class(class_id));

-- parents_students
create policy "ps_select" on parents_students
  for select using (
    parent_id = auth.uid()
    or (my_role() = 'admin' and student_in_my_school(student_id))
  );
create policy "ps_admin_write" on parents_students
  for all using (my_role() = 'admin' and student_in_my_school(student_id))
  with check (my_role() = 'admin' and student_in_my_school(student_id));

-- grades
create policy "grades_select" on grades
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_student(student_id))
    or (my_role() = 'parent' and is_parent_of(student_id))
  );
create policy "grades_admin_write" on grades
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "grades_teacher_insert" on grades
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_subject_to(student_id, subject_id)
  );
create policy "grades_teacher_update" on grades
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "grades_teacher_delete" on grades
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- timetable
create policy "timetable_select" on timetable
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(class_id))
      or (my_role() = 'parent' and parent_has_child_in_class(class_id))
    )
  );
create policy "timetable_admin_write" on timetable
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "timetable_teacher_write" on timetable
  for all using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id));

-- attendance
create policy "attendance_select" on attendance
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and is_parent_of(student_id))
  );
create policy "attendance_admin_write" on attendance
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "attendance_teacher_insert" on attendance
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_class(class_id)
  );
create policy "attendance_teacher_update" on attendance
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "attendance_teacher_delete" on attendance
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- behavior_notes (le parent ne voit que les notes marquées "visibles")
create policy "behavior_select" on behavior_notes
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and visible_to_parent and is_parent_of(student_id))
  );
create policy "behavior_admin_write" on behavior_notes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "behavior_teacher_insert" on behavior_notes
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_class(class_id)
  );
create policy "behavior_teacher_update" on behavior_notes
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "behavior_teacher_delete" on behavior_notes
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- ================= lakol_migration_2.sql =================
-- =====================================================
-- LAKOL : migration 2
-- Directeur (vue d'ensemble, professeurs, salaires), scolarité
-- réservée au directeur et aux parents, comptes désactivables.
-- Prérequis : lakol_migration_1.sql déjà lancée.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. COMPTES : ACTIF / EMAIL ----------
alter table profiles add column if not exists active boolean not null default true;
alter table profiles add column if not exists email text;

update profiles p set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

-- Un compte désactivé n'a plus ni rôle ni école : il ne voit plus rien.
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid() and active
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active
$$;

create or replace function public.profile_in_my_school(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = pid and school_id = my_school_id())
$$;

-- L'inscription enregistre aussi l'email
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role text := meta->>'role';
  v_name text := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(coalesce(new.email, 'utilisateur'), '@', 1));
  v_school uuid;
  v_student uuid;
begin
  if v_role = 'admin' then
    insert into schools (name, city)
    values (coalesce(nullif(trim(meta->>'school_name'), ''), 'Mon école'), nullif(trim(meta->>'city'), ''))
    returning id into v_school;
    insert into school_secrets (school_id) values (v_school);
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'admin', new.email);

  elsif v_role = 'teacher' then
    select school_id into v_school from school_secrets
      where join_code = upper(trim(meta->>'school_code'));
    if v_school is null then
      raise exception 'Code école invalide';
    end if;
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'teacher', new.email);

  elsif v_role = 'parent' then
    select id, school_id into v_student, v_school from students
      where access_code = upper(trim(meta->>'student_code'));
    if v_student is null then
      raise exception 'Code élève invalide';
    end if;
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'parent', new.email);
    insert into parents_students (parent_id, student_id) values (new.id, v_student);
  end if;

  return new;
end $$;

-- ---------- 2. SALAIRES ----------
create table if not exists staff_pay (
  teacher_id uuid primary key references profiles(id) on delete cascade,
  school_id uuid not null references schools(id) on delete cascade,
  monthly_salary integer not null default 0 check (monthly_salary >= 0)
);

create table if not exists salary_payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  teacher_id uuid not null references profiles(id) on delete cascade,
  month text not null check (month ~ '^[0-9]{4}-[0-9]{2}$'),   -- ex. 2026-11
  amount integer not null check (amount > 0),
  method text not null default 'cash'
    check (method in ('moov', 'airtel', 'orange', 'nita', 'cash', 'virement')),
  note text,
  paid_at timestamptz default now(),
  created_by uuid references profiles(id) on delete set null
);
create index if not exists salary_payments_teacher on salary_payments (teacher_id, month);

alter table staff_pay enable row level security;
alter table salary_payments enable row level security;
alter table fees enable row level security;
alter table payments enable row level security;

-- ---------- 3. RÈGLES DE SÉCURITÉ ----------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('fees', 'payments', 'staff_pay', 'salary_payments')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Frais de scolarité : directeur gère, parents voient ceux de la classe de leur enfant.
-- Les professeurs n'y ont PAS accès.
create policy "fees_admin" on fees
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin'
    and (class_id is null or class_in_my_school(class_id))
  );
create policy "fees_parent" on fees
  for select using (
    my_role() = 'parent' and class_id is not null and parent_has_child_in_class(class_id)
  );

-- Paiements de scolarité : directeur gère, parents voient ceux de leurs enfants.
create policy "payments_admin" on payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and student_in_my_school(student_id)
  );
create policy "payments_parent" on payments
  for select using (my_role() = 'parent' and is_parent_of(student_id));

-- Salaires : directeur gère, chaque professeur voit uniquement le sien.
create policy "staffpay_admin" on staff_pay
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and profile_in_my_school(teacher_id)
  );
create policy "staffpay_self" on staff_pay
  for select using (teacher_id = auth.uid());

create policy "salarypay_admin" on salary_payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and profile_in_my_school(teacher_id)
  );
create policy "salarypay_self" on salary_payments
  for select using (teacher_id = auth.uid());

-- ---------- 4. FONCTIONS POUR LE DIRECTEUR ----------

-- Nouveau code d'école (si l'ancien a été partagé trop largement)
create or replace function public.regenerate_join_code()
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
  update school_secrets set join_code = v_code where school_id = my_school_id();
  return v_code;
end $$;

-- Situation de scolarité de chaque élève (dû, payé)
create or replace function public.student_balances()
returns table (
  student_id uuid, first_name text, last_name text,
  class_id uuid, class_name text, due bigint, paid bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  return query
  select s.id, s.first_name, s.last_name, s.class_id, c.name,
    coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id), 0)::bigint,
    coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0)::bigint
  from students s
  left join classes c on c.id = s.class_id
  where s.school_id = my_school_id()
  order by s.last_name, s.first_name;
end $$;

-- Vue d'ensemble de l'école. p_term = 1, 2, 3 ou null (tous les trimestres).
-- Moyenne d'une matière = (moyenne des devoirs + composition) / 2, puis
-- moyenne générale pondérée par les coefficients (comme le bulletin).
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;

  with subj as (
    select g.student_id, g.subject_id, sb.coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then (avg(g.score) filter (where g.kind = 'devoir')
               + avg(g.score) filter (where g.kind = 'composition')) / 2
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, sb.coefficient
  ),
  stu as (
    select student_id,
      sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < 10) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles
                 where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce(
      (select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5
      ) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school
        order by p.paid_at desc limit 6
      ) y), '[]'::jsonb)
  ) into v_result;

  return v_result;
end $$;

-- ---------- 5. DEVOIRS ET EXAMENS À VENIR (planning de classe) ----------
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid references subjects(id) on delete set null,
  kind text not null default 'devoir' check (kind in ('devoir', 'examen', 'composition')),
  title text not null,
  due_date date not null,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);
create index if not exists assignments_class on assignments (class_id, due_date);
alter table assignments enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'assignments'
  loop execute format('drop policy %I on public.assignments', r.policyname); end loop;
end $$;

create policy "assign_select" on assignments
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(class_id))
      or (my_role() = 'parent' and parent_has_child_in_class(class_id))
    )
  );
create policy "assign_admin_write" on assignments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin' and class_in_my_school(class_id));
create policy "assign_teacher_write" on assignments
  for all using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id));

-- ================= lakol_migration_3.sql =================
-- =====================================================
-- LAKOL : migration 3
-- Le directeur ne touche plus aux notes, classes uniques et visibles
-- par tous, matières modifiables, frais généraux, plan des devoirs.
-- Prérequis : migrations 1 et 2 déjà lancées.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. LE DIRECTEUR NE MODIFIE PLUS LES NOTES (lecture seule) ----------
drop policy if exists "grades_admin_write" on grades;

-- ---------- 2. CLASSES : UNE SEULE "3e B" PAR ÉCOLE ET PAR ANNÉE ----------
drop index if exists classes_unique_name;
do $$
begin
  create unique index if not exists classes_unique_name
    on classes (school_id, lower(regexp_replace(trim(name), '\s+', ' ', 'g')), school_year);
exception when others then
  raise notice 'Des classes en double existent déjà : supprime les doublons puis relance cette migration.';
end $$;

-- Toutes les classes de l'école sont visibles par le directeur et les professeurs
-- (pour pouvoir rejoindre une classe existante). Le parent ne voit que celles de ses enfants.
drop policy if exists "classes_select" on classes;
create policy "classes_select" on classes
  for select using (
    school_id = my_school_id() and (
      my_role() in ('admin', 'teacher')
      or (my_role() = 'parent' and parent_has_child_in_class(id))
    )
  );

-- ---------- 3. MATIÈRES ET PLAN DE CLASSE ----------
alter table subjects add column if not exists created_by uuid references profiles(id) on delete set null;
alter table subjects alter column created_by set default auth.uid();

drop policy if exists "subjects_update_own" on subjects;
create policy "subjects_update_own" on subjects
  for update using (my_role() = 'teacher' and created_by = auth.uid())
  with check (school_id = my_school_id());

-- Combien de devoirs / compositions le professeur prévoit par trimestre
alter table teaching add column if not exists devoirs_per_term int not null default 2;
alter table teaching add column if not exists compositions_per_term int not null default 1;
drop policy if exists "teaching_teacher_update" on teaching;
create policy "teaching_teacher_update" on teaching
  for update using (my_role() = 'teacher' and teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

-- Chapitres (facultatif) et trimestre pour chaque devoir / examen
alter table assignments add column if not exists chapters text;
alter table assignments add column if not exists term int check (term between 1 and 3);

-- Rejoindre une classe qui existe déjà avec ses matières
create or replace function public.join_class(p_class_id uuid, p_subject_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare v_subject uuid;
begin
  if my_role() is distinct from 'teacher' then raise exception 'Non autorisé'; end if;
  if not class_in_my_school(p_class_id) then raise exception 'Classe introuvable'; end if;
  if p_subject_ids is null or array_length(p_subject_ids, 1) is null then
    raise exception 'Choisis au moins une matière';
  end if;
  foreach v_subject in array p_subject_ids loop
    if exists (select 1 from subjects where id = v_subject and school_id = my_school_id()) then
      insert into teaching (teacher_id, class_id, subject_id)
      values (auth.uid(), p_class_id, v_subject) on conflict do nothing;
    end if;
  end loop;
end $$;

-- Supprimer une matière (seulement si elle est à moi et qu'aucune note / autre prof ne l'utilise)
create or replace function public.delete_subject(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_creator uuid;
begin
  select created_by into v_creator from subjects where id = p_id and school_id = my_school_id();
  if not found then raise exception 'Matière introuvable'; end if;
  if not (my_role() = 'admin' or v_creator = auth.uid()) then
    raise exception 'Tu peux seulement supprimer les matières que tu as créées';
  end if;
  if exists (select 1 from grades where subject_id = p_id) then
    raise exception 'Cette matière a déjà des notes : retire-la seulement de ta classe';
  end if;
  if exists (select 1 from teaching where subject_id = p_id and teacher_id <> auth.uid()) then
    raise exception 'Un autre professeur enseigne cette matière : retire-la seulement de ta classe';
  end if;
  delete from subjects where id = p_id;
end $$;

-- Un message clair si la classe existe déjà
create or replace function public.create_class(
  p_name text, p_year text, p_subject_ids uuid[], p_students text[]
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_class uuid;
  v_subject uuid;
  v_line text; v_last text; v_first text;
begin
  if my_role() not in ('teacher', 'admin') then raise exception 'Non autorisé'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'Donne un nom à la classe'; end if;
  begin
    insert into classes (school_id, name, school_year, created_by)
    values (v_school, regexp_replace(trim(p_name), '\s+', ' ', 'g'), coalesce(nullif(trim(p_year), ''), '2026-2027'), auth.uid())
    returning id into v_class;
  exception when unique_violation then
    raise exception 'Cette classe existe déjà dans l''école : rejoins-la au lieu de la recréer';
  end;
  if p_subject_ids is not null then
    foreach v_subject in array p_subject_ids loop
      if exists (select 1 from subjects where id = v_subject and school_id = v_school) then
        insert into teaching (teacher_id, class_id, subject_id)
        values (auth.uid(), v_class, v_subject) on conflict do nothing;
      end if;
    end loop;
  end if;
  if p_students is not null then
    foreach v_line in array p_students loop
      v_line := trim(v_line);
      if v_line <> '' then
        v_last := split_part(v_line, ' ', 1);
        v_first := trim(substr(v_line, length(v_last) + 1));
        insert into students (school_id, class_id, last_name, first_name)
        values (v_school, v_class, v_last, v_first);
      end if;
    end loop;
  end if;
  return v_class;
end $$;

-- ---------- 4. FRAIS : GÉNÉRAUX (class_id vide = toutes les classes) + SPÉCIFIQUES ----------
-- Un frais général s'applique automatiquement à toute classe, même créée plus tard.
drop policy if exists "fees_parent" on fees;
create policy "fees_parent" on fees
  for select using (
    my_role() = 'parent' and school_id = my_school_id()
    and (class_id is null or parent_has_child_in_class(class_id))
  );

-- Soldes et tableau de bord : ajoutent les frais généraux
-- Situation de scolarité de chaque élève (dû, payé)
create or replace function public.student_balances()
returns table (
  student_id uuid, first_name text, last_name text,
  class_id uuid, class_name text, due bigint, paid bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  return query
  select s.id, s.first_name, s.last_name, s.class_id, c.name,
    coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0)::bigint,
    coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0)::bigint
  from students s
  left join classes c on c.id = s.class_id
  where s.school_id = my_school_id()
  order by s.last_name, s.first_name;
end $$;

-- Vue d'ensemble de l'école. p_term = 1, 2, 3 ou null (tous les trimestres).
-- Moyenne d'une matière = (moyenne des devoirs + composition) / 2, puis
-- moyenne générale pondérée par les coefficients (comme le bulletin).
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;

  with subj as (
    select g.student_id, g.subject_id, sb.coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then (avg(g.score) filter (where g.kind = 'devoir')
               + avg(g.score) filter (where g.kind = 'composition')) / 2
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, sb.coefficient
  ),
  stu as (
    select student_id,
      sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < 10) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles
                 where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce(
      (select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5
      ) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school
        order by p.paid_at desc limit 6
      ) y), '[]'::jsonb)
  ) into v_result;

  return v_result;
end $$;


-- ================= lakol_migration_4.sql =================
-- =====================================================
-- LAKOL : migration 4
-- Messagerie, annonces de l'école, notifications (email / SMS).
-- Prérequis : migrations 1, 2 et 3 déjà lancées.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. TÉLÉPHONE ET PRÉFÉRENCES DE NOTIFICATION ----------
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists notify_email boolean not null default true;
alter table profiles add column if not exists notify_sms boolean not null default false;

create or replace function public.update_my_contact(p_phone text, p_email_on boolean, p_sms_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if p_sms_on and v_phone is null then
    raise exception 'Ajoute ton numéro de téléphone pour recevoir des SMS';
  end if;
  update profiles set phone = v_phone, notify_email = coalesce(p_email_on, true), notify_sms = coalesce(p_sms_on, false)
  where id = auth.uid();
end $$;

-- ---------- 2. FILE D'ENVOI DES NOTIFICATIONS ----------
create table if not exists notification_queue (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references schools(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  channel text not null check (channel in ('email', 'sms')),
  subject text not null,
  body text not null,
  dedupe_key text not null,
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  error text,
  created_at timestamptz default now(),
  sent_at timestamptz,
  unique (user_id, channel, dedupe_key)
);
create index if not exists notification_queue_pending on notification_queue (status, created_at);
-- Aucune règle d'accès : personne ne la lit depuis le site, seul le serveur d'envoi y accède.
alter table notification_queue enable row level security;

-- Ajoute une notification pour une personne (selon ses préférences)
create or replace function public.enqueue_notification(p_user uuid, p_subject text, p_body text, p_key text)
returns void language plpgsql security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  select * into p from profiles where id = p_user and active;
  if not found then return; end if;
  if p.notify_email and p.email is not null then
    insert into notification_queue (school_id, user_id, channel, subject, body, dedupe_key)
    values (p.school_id, p.id, 'email', p_subject, p_body, p_key) on conflict do nothing;
  end if;
  if p.notify_sms and p.phone is not null then
    insert into notification_queue (school_id, user_id, channel, subject, body, dedupe_key)
    values (p.school_id, p.id, 'sms', p_subject, p_body, p_key) on conflict do nothing;
  end if;
end $$;

-- ---------- 3. ANNONCES DE L'ÉCOLE ----------
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null default auth.uid(),
  title text not null,
  body text not null,
  audience text not null default 'all' check (audience in ('all', 'parents', 'teachers')),
  kind text not null default 'info' check (kind in ('info', 'urgent', 'closure')),
  pinned boolean not null default false,
  created_at timestamptz default now()
);
create index if not exists announcements_school on announcements (school_id, created_at desc);
alter table announcements enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'announcements'
  loop execute format('drop policy %I on public.announcements', r.policyname); end loop;
end $$;

create policy "announcements_read" on announcements
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or audience = 'all'
      or (audience = 'parents' and my_role() = 'parent')
      or (audience = 'teachers' and my_role() = 'teacher')
    )
  );
create policy "announcements_admin" on announcements
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create or replace function public.trg_announcement_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_prefix text;
begin
  v_prefix := case new.kind when 'urgent' then '🔴 Urgent : ' when 'closure' then '🏫 Pas de cours : ' else '📢 ' end;
  for r in
    select id from profiles
    where school_id = new.school_id and active and id <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000')
      and (new.audience = 'all'
           or (new.audience = 'parents' and role = 'parent')
           or (new.audience = 'teachers' and role = 'teacher'))
  loop
    perform enqueue_notification(r.id, v_prefix || new.title, left(new.body, 600), 'ann:' || new.id);
  end loop;
  return new;
end $$;
drop trigger if exists announcement_notify on announcements;
create trigger announcement_notify after insert on announcements
  for each row execute function public.trg_announcement_notify();

-- ---------- 4. MESSAGERIE ----------
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  student_id uuid references students(id) on delete set null,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz default now(),
  read_at timestamptz
);
create index if not exists messages_recipient on messages (recipient_id, read_at);
create index if not exists messages_pair on messages (sender_id, recipient_id, created_at);
alter table messages enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'messages'
  loop execute format('drop policy %I on public.messages', r.policyname); end loop;
end $$;

-- On lit seulement ses propres messages ; l'envoi passe par les fonctions ci-dessous.
create policy "messages_mine" on messages
  for select using (sender_id = auth.uid() or recipient_id = auth.uid());

-- Qui peut écrire à qui
create or replace function public.can_message(p_recipient uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); my_r text := my_role(); rec profiles%rowtype;
begin
  if me is null or p_recipient = me then return false; end if;
  select * into rec from profiles where id = p_recipient and active and school_id = my_school_id();
  if not found then return false; end if;
  if my_r = 'admin' then return true; end if;
  if my_r = 'teacher' then
    if rec.role = 'admin' then return true; end if;
    return rec.role = 'parent' and exists (
      select 1 from parents_students ps where ps.parent_id = p_recipient and teaches_student(ps.student_id));
  end if;
  if my_r = 'parent' then
    if rec.role = 'admin' then return true; end if;
    return rec.role = 'teacher' and exists (
      select 1 from parents_students ps join students s on s.id = ps.student_id
      join teaching t on t.class_id = s.class_id
      where ps.parent_id = me and t.teacher_id = p_recipient);
  end if;
  return false;
end $$;

-- Personnes que je peux contacter
create or replace function public.my_contacts()
returns table (id uuid, full_name text, role text, context text)
language plpgsql stable security definer set search_path = public as $$
declare my_r text := my_role();
begin
  if my_r is null then return; end if;
  return query
  select p.id, p.full_name, p.role,
    case p.role
      when 'parent' then (select string_agg(s.first_name || ' ' || s.last_name || coalesce(' (' || c.name || ')', ''), ', ')
                          from parents_students ps join students s on s.id = ps.student_id left join classes c on c.id = s.class_id
                          where ps.parent_id = p.id)
      when 'teacher' then (select string_agg(distinct sb.name, ', ') from teaching t join subjects sb on sb.id = t.subject_id where t.teacher_id = p.id)
      else 'Direction'
    end
  from profiles p
  where p.school_id = my_school_id() and p.active and p.id <> auth.uid() and can_message(p.id)
  order by p.role, p.full_name;
end $$;

create or replace function public.notify_new_message(p_msg uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m messages%rowtype; v_name text;
begin
  select * into m from messages where id = p_msg;
  select full_name into v_name from profiles where id = m.sender_id;
  perform enqueue_notification(m.recipient_id, '💬 Nouveau message de ' || coalesce(v_name, 'l''école'), left(m.body, 400), 'msg:' || m.id);
end $$;

create or replace function public.send_message(p_recipient uuid, p_student uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'Écris ton message'; end if;
  if not can_message(p_recipient) then raise exception 'Tu ne peux pas écrire à cette personne'; end if;
  insert into messages (school_id, sender_id, recipient_id, student_id, body)
  values (my_school_id(), auth.uid(), p_recipient, p_student, trim(p_body)) returning id into v_id;
  perform notify_new_message(v_id);
  return v_id;
end $$;

-- Message groupé : 'parents' | 'teachers' | 'class' (parents d'une classe)
create or replace function public.send_bulk(p_target text, p_class_id uuid, p_body text)
returns int language plpgsql security definer set search_path = public as $$
declare v_role text := my_role(); v_count int := 0; r record; v_id uuid;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'Écris ton message'; end if;
  if v_role not in ('admin', 'teacher') then raise exception 'Non autorisé'; end if;
  if v_role = 'teacher' and p_target <> 'class' then raise exception 'Un professeur écrit aux parents d''une de ses classes'; end if;
  if p_target = 'class' then
    if p_class_id is null or not class_in_my_school(p_class_id) then raise exception 'Choisis une classe'; end if;
    if v_role = 'teacher' and not teaches_class(p_class_id) then raise exception 'Tu n''enseignes pas dans cette classe'; end if;
  end if;
  for r in
    select distinct p.id from profiles p
    where p.school_id = my_school_id() and p.active and p.id <> auth.uid()
      and ((p_target = 'parents' and p.role = 'parent')
        or (p_target = 'teachers' and p.role = 'teacher')
        or (p_target = 'class' and p.role = 'parent' and exists (
              select 1 from parents_students ps join students s on s.id = ps.student_id
              where ps.parent_id = p.id and s.class_id = p_class_id)))
  loop
    insert into messages (school_id, sender_id, recipient_id, body)
    values (my_school_id(), auth.uid(), r.id, trim(p_body)) returning id into v_id;
    perform notify_new_message(v_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- Mes conversations (une ligne par personne)
create or replace function public.my_conversations()
returns table (other_id uuid, other_name text, other_role text, last_body text, last_at timestamptz, last_from_me boolean, unread int)
language sql stable security definer set search_path = public as $$
  with m as (
    select case when sender_id = auth.uid() then recipient_id else sender_id end as other,
           body, created_at, sender_id = auth.uid() as mine, (recipient_id = auth.uid() and read_at is null) as is_unread
    from messages where sender_id = auth.uid() or recipient_id = auth.uid()
  ),
  last as (select distinct on (other) other, body, created_at, mine from m order by other, created_at desc)
  select l.other, p.full_name, p.role, l.body, l.created_at, l.mine,
         (select count(*) from m where m.other = l.other and m.is_unread)::int
  from last l join profiles p on p.id = l.other
  order by l.created_at desc;
$$;

create or replace function public.unread_messages()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from messages where recipient_id = auth.uid() and read_at is null;
$$;

create or replace function public.mark_thread_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now() where recipient_id = auth.uid() and sender_id = p_other and read_at is null;
$$;

-- ---------- 5. NOTIFICATIONS AUTOMATIQUES AUX PARENTS ----------
-- Nouvelle note
create or replace function public.trg_grade_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_stu students%rowtype; v_label text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  select * into v_stu from students where id = new.student_id;
  v_label := case new.kind when 'composition' then 'composition' else 'devoir' end;
  for r in select parent_id from parents_students where student_id = new.student_id loop
    perform enqueue_notification(r.parent_id,
      '📝 Nouvelle note : ' || coalesce(v_sub, 'matière') || ' (' || v_label || ')',
      v_stu.first_name || ' a une nouvelle note en ' || coalesce(v_sub, 'matière') || ' (trimestre ' || new.term || ') : ' || new.score || '/20.',
      'grade:' || new.student_id || ':' || new.subject_id || ':' || new.term || ':' || new.kind || ':' || current_date);
  end loop;
  return new;
end $$;
drop trigger if exists grade_notify on grades;
create trigger grade_notify after insert on grades for each row execute function public.trg_grade_notify();

-- Nouveau devoir / examen annoncé pour la classe
create or replace function public.trg_assignment_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_kind text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  v_kind := case new.kind when 'examen' then 'Examen' when 'composition' then 'Composition' else 'Devoir' end;
  for r in
    select distinct ps.parent_id from parents_students ps join students s on s.id = ps.student_id where s.class_id = new.class_id
  loop
    perform enqueue_notification(r.parent_id,
      '📅 ' || v_kind || ' prévu : ' || new.title,
      v_kind || coalesce(' en ' || v_sub, '') || ' le ' || to_char(new.due_date, 'DD/MM/YYYY') || '. ' || new.title ||
        coalesce(' (chapitres : ' || new.chapters || ')', ''),
      'asg:' || new.id);
  end loop;
  return new;
end $$;
drop trigger if exists assignment_notify on assignments;
create trigger assignment_notify after insert on assignments for each row execute function public.trg_assignment_notify();

-- ================= lakol_migration_5.sql =================
-- Lakol migration 5 : noms de notes + paramètres de l'école (périodes, barème, poids, note de passage, coefficients par classe)
-- À lancer UNE fois dans Supabase > SQL Editor. Peut être relancée sans danger.

-- ---------- 1. Chaque note a un nom ----------
alter table public.grades add column if not exists title text;
alter table public.grades drop constraint if exists grades_title_len;
alter table public.grades add constraint grades_title_len check (title is null or char_length(title) <= 60);

-- ---------- 2. Paramètres de l'école ----------
alter table public.schools add column if not exists settings jsonb not null default
  '{"period_name":"trimestre","periods":3,"scale":20,"weight_devoir":50,"pass_mark":10,"show_rank":true,"language":"fr","bulletin_header":"République du Niger\nFraternité · Travail · Progrès"}'::jsonb;

-- Périodes jusqu'à 4, barème jusqu'à 100 (les contrôles précis sont faits par update_school_settings)
do $$ declare c record; begin
  for c in select conrelid::regclass as t, conname from pg_constraint
           where contype = 'c' and conrelid in ('public.grades'::regclass, 'public.assignments'::regclass)
             and (pg_get_constraintdef(oid) ilike '%term%' or pg_get_constraintdef(oid) ilike '%score%')
  loop execute format('alter table %s drop constraint %I', c.t, c.conname); end loop;
end $$;
-- Ancienne vue du premier schéma, jamais utilisée par l'application (elle bloquerait le changement de type)
drop view if exists public.student_subject_averages;
alter table public.grades alter column score type numeric(5,2);
alter table public.grades add constraint grades_term_ok check (term between 1 and 4);
alter table public.grades add constraint grades_score_ok check (score >= 0 and score <= 100);
alter table public.assignments add constraint assignments_term_ok check (term is null or term between 1 and 4);

create or replace function public.update_school_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v jsonb; v_clean jsonb;
  v_periods int; v_scale int; v_weight numeric; v_pass numeric; v_name text; v_lang text; v_head text; v_rank boolean;
begin
  if my_role() is distinct from 'admin' then raise exception 'Seul le directeur peut modifier les paramètres.'; end if;
  select settings into v from schools where id = v_school;
  v := coalesce(v, '{}'::jsonb) || coalesce(p_settings, '{}'::jsonb);

  v_name := v->>'period_name'; v_lang := v->>'language'; v_head := coalesce(v->>'bulletin_header', '');
  v_periods := (v->>'periods')::int; v_scale := (v->>'scale')::int;
  v_weight := (v->>'weight_devoir')::numeric; v_pass := (v->>'pass_mark')::numeric; v_rank := coalesce((v->>'show_rank')::boolean, true);

  if v_name not in ('trimestre', 'semestre') then raise exception 'Type de période invalide.'; end if;
  if v_periods < 2 or v_periods > 4 then raise exception 'Le nombre de périodes doit être entre 2 et 4.'; end if;
  if v_scale not in (10, 20, 100) then raise exception 'Le barème doit être /10, /20 ou /100.'; end if;
  if v_weight < 0 or v_weight > 100 then raise exception 'Le poids des devoirs doit être entre 0 et 100 %%.'; end if;
  if v_pass < 0 or v_pass > v_scale then raise exception 'La note de passage doit être entre 0 et %.', v_scale; end if;
  if v_lang not in ('fr', 'en') then raise exception 'Langue invalide.'; end if;
  if char_length(v_head) > 160 then raise exception 'En-tête trop long (160 caractères maximum).'; end if;

  -- Sécurité : on ne casse pas les notes déjà saisies
  if exists (select 1 from grades where school_id = v_school and term > v_periods) then
    raise exception 'Des notes existent déjà après la période % : impossible de réduire le nombre de périodes.', v_periods;
  end if;
  if exists (select 1 from grades where school_id = v_school and score > v_scale) then
    raise exception 'Des notes existent déjà au-dessus de % : impossible de réduire le barème. Les notes ne sont pas converties automatiquement.', v_scale;
  end if;

  v_clean := jsonb_build_object('period_name', v_name, 'periods', v_periods, 'scale', v_scale, 'weight_devoir', v_weight,
    'pass_mark', v_pass, 'show_rank', v_rank, 'language', v_lang, 'bulletin_header', v_head);
  update schools set settings = v_clean where id = v_school;
  return v_clean;
end $$;

-- ---------- 3. Coefficients par classe (6e et terminale n'ont pas les mêmes) ----------
create table if not exists public.class_coefficients (
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  coefficient numeric(4,2) not null check (coefficient > 0 and coefficient <= 20),
  primary key (class_id, subject_id)
);
alter table public.class_coefficients enable row level security;
drop policy if exists cc_select on public.class_coefficients;
drop policy if exists cc_write on public.class_coefficients;
create policy cc_select on public.class_coefficients for select using (class_in_my_school(class_id));
create policy cc_write on public.class_coefficients for all
  using (class_in_my_school(class_id) and (my_role() = 'admin' or teaches_class(class_id)))
  with check (class_in_my_school(class_id) and (my_role() = 'admin' or teaches_class(class_id)));

-- ---------- 4. Email aux parents : nom de la note, période et barème de l'école ----------
create or replace function public.trg_grade_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_stu students%rowtype; v_label text; v_set jsonb; v_pn text; v_scale text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  select * into v_stu from students where id = new.student_id;
  select settings into v_set from schools where id = new.school_id;
  v_pn := coalesce(v_set->>'period_name', 'trimestre'); v_scale := coalesce(v_set->>'scale', '20');
  v_label := coalesce(nullif(trim(new.title), ''), case new.kind when 'composition' then 'Composition' else 'Devoir' end);
  for r in select parent_id from parents_students where student_id = new.student_id loop
    perform enqueue_notification(r.parent_id,
      '📝 Nouvelle note : ' || coalesce(v_sub, 'matière') || ' (' || v_label || ')',
      v_stu.first_name || ' a une nouvelle note en ' || coalesce(v_sub, 'matière') || ' (' || v_label || ', ' || v_pn || ' ' || new.term || ') : ' || trim(trailing '.' from trim(trailing '0' from new.score::text)) || '/' || v_scale || '.',
      'grade:' || new.id);
  end loop;
  return new;
end $$;

-- ---------- 5. Tableau de bord : lit les paramètres de l'école ----------
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
  v_set jsonb;
  v_wd numeric; v_pass numeric;
begin
  if my_role() is distinct from 'admin' then raise exception 'Non autorisé'; end if;
  select settings into v_set from schools where id = v_school;
  v_wd := coalesce((v_set->>'weight_devoir')::numeric, 50) / 100;
  v_pass := coalesce((v_set->>'pass_mark')::numeric, 10);

  with subj as (
    select g.student_id, g.subject_id, coalesce(cc.coefficient, sb.coefficient) as coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then v_wd * (avg(g.score) filter (where g.kind = 'devoir'))
              + (1 - v_wd) * (avg(g.score) filter (where g.kind = 'composition'))
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    join students st on st.id = g.student_id
    left join class_coefficients cc on cc.class_id = st.class_id and cc.subject_id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, coalesce(cc.coefficient, sb.coefficient)
  ),
  stu as (
    select student_id, sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < v_pass) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce((select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school order by p.paid_at desc limit 6) y), '[]'::jsonb)
  ) into v_result;
  return v_result;
end $$;

-- ================= lakol_migration_6.sql =================
-- Lakol migration 6 : sécurité
--   A. Double authentification (MFA) appliquée par la base de données
--   B. Journal d'audit (qui a changé quoi, et quand)
-- À lancer UNE fois dans Supabase > SQL Editor. Peut être relancée sans danger.

-- =====================================================================
-- A. DOUBLE AUTHENTIFICATION
-- Règle : si un compte a activé la double authentification, il n'a accès à rien tant que
-- la session n'a pas été confirmée avec le code à 6 chiffres (niveau "aal2").
-- Un compte sans double authentification fonctionne comme avant.
-- =====================================================================
create or replace function public.mfa_ok()
returns boolean language sql stable security definer set search_path = public, auth as $$
  select coalesce(nullif(auth.jwt() ->> 'aal', ''), 'aal1') = 'aal2'
      or not exists (select 1 from auth.mfa_factors where user_id = auth.uid() and status::text = 'verified')
$$;

-- Presque toutes les règles d'accès passent par ces deux fonctions : sans code, elles ne répondent plus.
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid() and active and mfa_ok()
$$;
create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active and mfa_ok()
$$;

-- Tables qui s'appuient directement sur l'identité (sans passer par les fonctions ci-dessus)
drop policy if exists mfa_guard on public.messages;
create policy mfa_guard on public.messages as restrictive for all using (mfa_ok()) with check (mfa_ok());
drop policy if exists mfa_guard on public.parents_students;
create policy mfa_guard on public.parents_students as restrictive for all using (mfa_ok()) with check (mfa_ok());

-- Fonctions de messagerie : même verrou
create or replace function public.unread_messages()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from messages where recipient_id = auth.uid() and read_at is null and mfa_ok()
$$;
create or replace function public.mark_thread_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now() where recipient_id = auth.uid() and sender_id = p_other and read_at is null and mfa_ok();
$$;

create or replace function public.my_conversations()
returns table (other_id uuid, other_name text, other_role text, last_body text, last_at timestamptz, last_from_me boolean, unread int)
language sql stable security definer set search_path = public as $$
  with m as (
    select case when sender_id = auth.uid() then recipient_id else sender_id end as other,
           body, created_at, sender_id = auth.uid() as mine, (recipient_id = auth.uid() and read_at is null) as is_unread
    from messages where (sender_id = auth.uid() or recipient_id = auth.uid()) and mfa_ok()
  ),
  last as (select distinct on (other) other, body, created_at, mine from m order by other, created_at desc)
  select l.other, p.full_name, p.role, l.body, l.created_at, l.mine,
         (select count(*) from m where m.other = l.other and m.is_unread)::int
  from last l join profiles p on p.id = l.other
  order by l.created_at desc;
$$;

-- =====================================================================
-- B. JOURNAL D'AUDIT
-- =====================================================================
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  school_id uuid not null references schools(id) on delete cascade,
  actor_id uuid,
  actor_name text,
  actor_role text,
  action text not null check (action in ('create', 'update', 'delete')),
  entity text not null,           -- note, paiement, frais, eleve, compte, salaire, classe, parametres
  record_id text,
  summary text not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_school_date on public.audit_log (school_id, created_at desc);
create index if not exists audit_school_entity on public.audit_log (school_id, entity, created_at desc);
alter table public.audit_log enable row level security;
drop policy if exists audit_admin_read on public.audit_log;
create policy audit_admin_read on public.audit_log for select using (school_id = my_school_id() and my_role() = 'admin');
-- Aucune règle d'écriture : personne ne peut ajouter, modifier ou effacer une ligne depuis l'application.
-- Seuls les déclencheurs ci-dessous écrivent.

create or replace function public.audit_money(n numeric)
returns text language sql immutable as $$ select replace(to_char(n, 'FM999,999,999,999'), ',', ' ') || ' F' $$;
create or replace function public.audit_num(n numeric)
returns text language sql immutable as $$ select trim(trailing '.' from trim(trailing '0' from n::numeric(8,2)::text)) $$;

create or replace function public.trg_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb; v_new jsonb; v_row jsonb;
  v_school uuid; v_entity text; v_sum text; v_act text; v_rid text;
  v_actor uuid := auth.uid(); v_name text; v_role text;
  v_stu text; v_sub text; v_lbl text; v_cls text; v_tch text; v_m text;
begin
  v_old := case when TG_OP in ('UPDATE', 'DELETE') then to_jsonb(OLD) end;
  v_new := case when TG_OP in ('INSERT', 'UPDATE') then to_jsonb(NEW) end;
  v_row := coalesce(v_new, v_old);
  v_act := case TG_OP when 'INSERT' then 'create' when 'UPDATE' then 'update' else 'delete' end;
  v_rid := v_row ->> 'id';
  if v_actor is not null then select full_name, role into v_name, v_role from profiles where id = v_actor; end if;

  if TG_TABLE_NAME = 'grades' then
    v_entity := 'note'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from students where id = (v_row ->> 'student_id')::uuid) then return OLD; end if;
    if TG_OP = 'UPDATE' and v_old ->> 'score' = v_new ->> 'score' and coalesce(v_old ->> 'title', '') = coalesce(v_new ->> 'title', '')
       and v_old ->> 'term' = v_new ->> 'term' and v_old ->> 'kind' = v_new ->> 'kind' then return NEW; end if;
    select first_name || ' ' || last_name into v_stu from students where id = (v_row ->> 'student_id')::uuid;
    select name into v_sub from subjects where id = (v_row ->> 'subject_id')::uuid;
    v_lbl := coalesce(nullif(v_row ->> 'title', ''), case v_row ->> 'kind' when 'composition' then 'Composition' else 'Devoir' end);
    if TG_OP = 'INSERT' then v_sum := format('Note ajoutée : %s, %s (%s) = %s', v_stu, v_sub, v_lbl, audit_num((v_new ->> 'score')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Note modifiée : %s, %s (%s) : %s → %s', v_stu, v_sub, v_lbl, audit_num((v_old ->> 'score')::numeric), audit_num((v_new ->> 'score')::numeric));
    else v_sum := format('Note supprimée : %s, %s (%s), elle valait %s', v_stu, v_sub, v_lbl, audit_num((v_old ->> 'score')::numeric)); end if;

  elsif TG_TABLE_NAME = 'payments' then
    v_entity := 'paiement'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from students where id = (v_row ->> 'student_id')::uuid) then return OLD; end if;
    select first_name || ' ' || last_name into v_stu from students where id = (v_row ->> 'student_id')::uuid;
    if TG_OP = 'INSERT' then v_sum := format('Paiement enregistré : %s pour %s (%s)', audit_money((v_new ->> 'amount')::numeric), v_stu, v_new ->> 'method');
    elsif TG_OP = 'UPDATE' then v_sum := format('Paiement modifié pour %s : %s → %s', v_stu, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Paiement supprimé pour %s : %s', v_stu, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'fees' then
    v_entity := 'frais'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    select name into v_cls from classes where id = (v_row ->> 'class_id')::uuid;
    v_lbl := format('« %s » (%s)', v_row ->> 'label', coalesce(v_cls, 'toute l''école'));
    if TG_OP = 'INSERT' then v_sum := format('Frais créés : %s = %s', v_lbl, audit_money((v_new ->> 'amount')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Frais modifiés : %s : %s → %s', v_lbl, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Frais supprimés : %s (%s)', v_lbl, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'students' then
    v_entity := 'eleve'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'INSERT' then return NEW; end if;  -- les ajouts en série ne sont pas journalisés
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    v_stu := (v_row ->> 'first_name') || ' ' || (v_row ->> 'last_name');
    if TG_OP = 'UPDATE' then
      if v_old ->> 'class_id' is not distinct from v_new ->> 'class_id' and v_old ->> 'first_name' = v_new ->> 'first_name' and v_old ->> 'last_name' = v_new ->> 'last_name' then return NEW; end if;
      select name into v_cls from classes where id = (v_old ->> 'class_id')::uuid;
      select name into v_lbl from classes where id = (v_new ->> 'class_id')::uuid;
      v_sum := format('Élève modifié : %s (classe %s → %s)', v_stu, coalesce(v_cls, '–'), coalesce(v_lbl, '–'));
    else v_sum := format('Élève supprimé : %s', v_stu); end if;
    v_old := case when v_old is null then null else jsonb_build_object('first_name', v_old -> 'first_name', 'last_name', v_old -> 'last_name', 'class_id', v_old -> 'class_id') end;
    v_new := case when v_new is null then null else jsonb_build_object('first_name', v_new -> 'first_name', 'last_name', v_new -> 'last_name', 'class_id', v_new -> 'class_id') end;

  elsif TG_TABLE_NAME = 'classes' then
    v_entity := 'classe'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'INSERT' then return NEW; end if;
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    if TG_OP = 'UPDATE' then
      if v_old ->> 'name' = v_new ->> 'name' and v_old ->> 'school_year' = v_new ->> 'school_year' then return NEW; end if;
      v_sum := format('Classe renommée : %s → %s', v_old ->> 'name', v_new ->> 'name');
    else v_sum := format('Classe supprimée : %s', v_old ->> 'name'); end if;
    v_old := case when v_old is null then null else jsonb_build_object('name', v_old -> 'name', 'school_year', v_old -> 'school_year') end;
    v_new := case when v_new is null then null else jsonb_build_object('name', v_new -> 'name', 'school_year', v_new -> 'school_year') end;

  elsif TG_TABLE_NAME = 'staff_pay' then
    v_entity := 'salaire'; v_school := (v_row ->> 'school_id')::uuid; v_rid := v_row ->> 'teacher_id';
    select full_name into v_tch from profiles where id = (v_row ->> 'teacher_id')::uuid;
    if TG_OP = 'INSERT' then v_sum := format('Salaire mensuel fixé pour %s : %s', v_tch, audit_money((v_new ->> 'monthly_salary')::numeric));
    elsif TG_OP = 'UPDATE' then
      if v_old ->> 'monthly_salary' = v_new ->> 'monthly_salary' then return NEW; end if;
      v_sum := format('Salaire mensuel de %s : %s → %s', v_tch, audit_money((v_old ->> 'monthly_salary')::numeric), audit_money((v_new ->> 'monthly_salary')::numeric));
    else
      if not exists (select 1 from profiles where id = (v_row ->> 'teacher_id')::uuid) then return OLD; end if;
      v_sum := format('Salaire mensuel supprimé pour %s', v_tch); end if;

  elsif TG_TABLE_NAME = 'salary_payments' then
    v_entity := 'salaire'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from profiles where id = (v_row ->> 'teacher_id')::uuid) then return OLD; end if;
    select full_name into v_tch from profiles where id = (v_row ->> 'teacher_id')::uuid;
    v_m := v_row ->> 'month';
    if TG_OP = 'INSERT' then v_sum := format('Salaire versé à %s (%s) : %s', v_tch, v_m, audit_money((v_new ->> 'amount')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Versement de salaire modifié pour %s (%s) : %s → %s', v_tch, v_m, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Versement de salaire supprimé pour %s (%s) : %s', v_tch, v_m, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'profiles' then
    v_entity := 'compte'; v_school := (v_row ->> 'school_id')::uuid;
    if v_school is null then return coalesce(NEW, OLD); end if;
    if TG_OP = 'INSERT' then return NEW; end if;
    if TG_OP = 'UPDATE' then
      if v_old ->> 'active' = v_new ->> 'active' and v_old ->> 'role' = v_new ->> 'role' then return NEW; end if;
      if v_old ->> 'active' <> v_new ->> 'active' then
        v_sum := format('Compte %s : %s', case when (v_new ->> 'active')::boolean then 'réactivé' else 'désactivé' end, v_new ->> 'full_name');
      else v_sum := format('Rôle modifié pour %s : %s → %s', v_new ->> 'full_name', v_old ->> 'role', v_new ->> 'role'); end if;
    else
      if not exists (select 1 from schools where id = v_school) then return OLD; end if;
      v_sum := format('Compte supprimé : %s', v_old ->> 'full_name'); end if;
    v_old := case when v_old is null then null else jsonb_build_object('full_name', v_old -> 'full_name', 'role', v_old -> 'role', 'active', v_old -> 'active') end;
    v_new := case when v_new is null then null else jsonb_build_object('full_name', v_new -> 'full_name', 'role', v_new -> 'role', 'active', v_new -> 'active') end;

  elsif TG_TABLE_NAME = 'schools' then
    v_entity := 'parametres'; v_school := (v_row ->> 'id')::uuid;
    if TG_OP <> 'UPDATE' then return coalesce(NEW, OLD); end if;
    if v_old -> 'settings' is not distinct from v_new -> 'settings' and v_old ->> 'name' = v_new ->> 'name' then return NEW; end if;
    v_sum := case when v_old -> 'settings' is distinct from v_new -> 'settings' then 'Paramètres de l''école modifiés' else format('Nom de l''école : %s → %s', v_old ->> 'name', v_new ->> 'name') end;
    v_old := jsonb_build_object('name', v_old -> 'name', 'settings', v_old -> 'settings');
    v_new := jsonb_build_object('name', v_new -> 'name', 'settings', v_new -> 'settings');

  elsif TG_TABLE_NAME = 'school_secrets' then
    v_entity := 'parametres'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP <> 'UPDATE' or v_old ->> 'join_code' = v_new ->> 'join_code' then return coalesce(NEW, OLD); end if;
    v_sum := 'Code de l''école régénéré (les anciens codes ne marchent plus)';
    v_old := null; v_new := null;  -- le code est secret : jamais écrit dans le journal
  else
    return coalesce(NEW, OLD);
  end if;

  insert into audit_log (school_id, actor_id, actor_name, actor_role, action, entity, record_id, summary, old_data, new_data)
  values (v_school, v_actor, coalesce(v_name, 'Système'), v_role, v_act, v_entity, v_rid, v_sum, v_old, v_new);
  return coalesce(NEW, OLD);
end $$;

do $$ declare t text; begin
  foreach t in array array['grades', 'payments', 'fees', 'students', 'classes', 'staff_pay', 'salary_payments', 'profiles', 'schools', 'school_secrets'] loop
    execute format('drop trigger if exists audit_%1$s on public.%1$s', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$s for each row execute function public.trg_audit()', t);
  end loop;
end $$;
LAKOL_EOF

chmod +x scripts/*.sh
touch .gitignore
for l in "*.dump" "*.dump.gpg" "sauvegardes/" "_sauvegarde_avant_*/"; do grep -qxF "$l" .gitignore || echo "$l" >> .gitignore; done
npm install jspdf jspdf-autotable docx --no-audit --no-fund
echo ""
echo "Lakol v8d installé. Anciennes versions dans $B"
echo "Étape suivante : npm run build (doit finir sans erreur), puis git add -A, git commit -m v8d, git push."
