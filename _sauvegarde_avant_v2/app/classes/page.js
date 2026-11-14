'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentGrid, { filledRows } from '../components/StudentGrid';

const year = () => { const d = new Date(); const y = d.getMonth() >= 8 ? d.getFullYear() : d.getFullYear() - 1; return `${y}-${y + 1}`; };

export default function Classes() {
  const { profile, status } = useProfile(['admin', 'teacher']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [yr, setYr] = useState(year());
  const [chosen, setChosen] = useState([]);
  const [rows, setRows] = useState([]);
  const [newSub, setNewSub] = useState({ name: '', coef: '1' });
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const isTeacher = profile?.role === 'teacher';

  async function load() {
    const [c, s, t, st] = await Promise.all([
      supabase.from('classes').select('id, name, school_year').order('name'),
      supabase.from('subjects').select('id, name, coefficient').order('name'),
      supabase.from('teaching').select('class_id, subjects(name)'),
      supabase.from('students').select('id, class_id'),
    ]);
    const subs = {}; (t.data || []).forEach((x) => { (subs[x.class_id] ||= new Set()).add(x.subjects?.name); });
    const cnt = {}; (st.data || []).forEach((x) => { cnt[x.class_id] = (cnt[x.class_id] || 0) + 1; });
    setClasses((c.data || []).map((x) => ({ ...x, subs: [...(subs[x.id] || [])], n: cnt[x.id] || 0 })));
    setSubjects(s.data || []);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function addSubject() {
    if (!newSub.name.trim()) return;
    const { data, error } = await supabase.from('subjects').insert({
      school_id: profile.school_id, name: newSub.name.trim(), coefficient: Number(newSub.coef) || 1,
    }).select().single();
    if (error) return setErr(error.message);
    setNewSub({ name: '', coef: '1' }); setChosen([...chosen, data.id]); load();
  }
  async function create(e) {
    e.preventDefault(); setErr('');
    if (!name.trim()) return setErr('Donne un nom à la classe (ex. 6e A).');
    if (isTeacher && chosen.length === 0) return setErr('Choisis au moins une matière que tu enseignes.');
    setBusy(true);
    const { data: id, error } = await supabase.rpc('create_class', { p_name: name, p_year: yr, p_subject_ids: chosen, p_students: [] });
    if (error) { setBusy(false); return setErr(error.message); }
    const list = filledRows(rows);
    if (list.length) {
      const { error: e2 } = await supabase.from('students').insert(list.map((r) => ({
        school_id: profile.school_id, class_id: id, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—',
      })));
      if (e2) setErr(e2.message);
    }
    setBusy(false); setOpen(false); setName(''); setChosen([]); setRows([]); load();
  }
  async function del(c) {
    if (!confirm(`Supprimer la classe ${c.name} avec ses élèves et leurs notes ?`)) return;
    const { error } = await supabase.from('classes').delete().eq('id', c.id);
    if (error) setErr(error.message); else load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>{isTeacher ? 'Mes classes' : 'Classes'}</h1>
        <button onClick={() => setOpen(!open)}>{open ? 'Fermer' : '+ Nouvelle classe'}</button>
      </div>
      {err && <div className="notice">{err}</div>}

      {open && (
        <form className="lk-card lk-stack" onSubmit={create}>
          <h3>1. La classe</h3>
          <div className="lk-inline">
            <input placeholder="Nom (ex. 6e A)" value={name} onChange={(e) => setName(e.target.value)} />
            <input placeholder="Année scolaire" value={yr} onChange={(e) => setYr(e.target.value)} style={{ maxWidth: 160 }} />
          </div>
          <h3>2. {isTeacher ? 'Tes matières' : 'Les matières enseignées'}</h3>
          <div className="chips">
            {subjects.map((s) => (
              <button type="button" key={s.id} className={chosen.includes(s.id) ? 'on' : ''}
                onClick={() => setChosen(chosen.includes(s.id) ? chosen.filter((x) => x !== s.id) : [...chosen, s.id])}>
                {s.name} <small>coef {s.coefficient}</small>
              </button>
            ))}
            {subjects.length === 0 && <span className="meta">Aucune matière : ajoutes-en une ci-dessous.</span>}
          </div>
          <div className="lk-inline">
            <input placeholder="Nouvelle matière (ex. Maths)" value={newSub.name} onChange={(e) => setNewSub({ ...newSub, name: e.target.value })} />
            <input type="number" min="0.5" step="0.5" value={newSub.coef} onChange={(e) => setNewSub({ ...newSub, coef: e.target.value })} style={{ maxWidth: 90 }} title="Coefficient" />
            <button type="button" className="btn-ghost" onClick={addSubject}>Ajouter la matière</button>
          </div>
          <h3>3. Les élèves</h3>
          <StudentGrid rows={rows} setRows={setRows} />
          <button disabled={busy}>{busy ? 'Création…' : 'Créer la classe'}</button>
        </form>
      )}

      {classes.length === 0 && !open && <div className="empty">Aucune classe. Clique sur « Nouvelle classe » pour commencer.</div>}
      {classes.map((c) => (
        <div className="lk-card" key={c.id}>
          <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
            <div>
              <h3 style={{ margin: 0 }}>{c.name} <small className="meta">{c.school_year}</small></h3>
              <span className="meta">{c.n} élève(s){c.subs.length ? ' · ' + c.subs.join(', ') : ''}</span>
            </div>
            <div className="actions">
              <Link className="btn-small btn-ghost" href={`/eleves?classe=${c.id}`}>Élèves</Link>
              <Link className="btn-small btn-ghost" href="/notes">Notes</Link>
              <Link className="btn-small btn-ghost" href="/planning">Planning</Link>
              <button className="btn-small btn-danger" onClick={() => del(c)}>Supprimer</button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
