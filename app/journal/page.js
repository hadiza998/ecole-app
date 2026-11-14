'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const ENT = {
  '': ['Tout', '📋'], note: ['Notes', '📝'], paiement: ['Paiements', '💰'], frais: ['Frais', '🏷️'], eleve: ['Élèves', '🎓'],
  classe: ['Classes', '🏫'], compte: ['Comptes', '👤'], salaire: ['Salaires', '💵'], parametres: ['Paramètres', '⚙️'],
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
          <div className="tabs" style={{ flexWrap: 'wrap' }}>{Object.entries(ENT).map(([k, [l, ic]]) => <button key={k} className={entity === k ? 'on' : ''} onClick={() => setEntity(k)}>{ic} {l}</button>)}</div>
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
                <span style={{ fontSize: '1.3rem' }}>{(ENT[r.entity] || ['', '📋'])[1]}</span>
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
