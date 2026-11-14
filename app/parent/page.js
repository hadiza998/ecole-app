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
      <div className="topbar"><h1>Bonjour {profile.full_name}</h1></div>
      {kids.length > 1 && (
        <div className="tabs">
          {kids.map((k) => (
            <button key={k.id} className={current === k.id ? 'on' : ''} onClick={() => setCurrent(k.id)}>
              {k.first_name} <small>{k.classes?.name}</small>
            </button>
          ))}
        </div>
      )}
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
