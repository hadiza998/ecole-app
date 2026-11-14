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
