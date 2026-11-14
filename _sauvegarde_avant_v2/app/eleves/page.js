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
