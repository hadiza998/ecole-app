'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const today = () => new Date().toISOString().slice(0, 10);
import { KINDS } from '../../lib/kinds';

export default function VieScolaire() {
  const { profile, status } = useProfile(['teacher']);
  const [tab, setTab] = useState('presence');
  const [classes, setClasses] = useState([]);
  const [classId, setClassId] = useState('');
  const [students, setStudents] = useState([]);
  const [date, setDate] = useState(today());
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
    if (!classId) return;
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
    if (error) setErr(error.message); else setSaved(`Présence du ${new Date(date).toLocaleDateString('fr-FR')} enregistrée ✓`);
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
                  {Object.entries(KINDS).map(([k, [l, ic]]) => (
                    <button type="button" key={k} className={(k === 'positif' ? 'teal ' : 'coral ') + (f.kind === k ? 'on' : '')} onClick={() => setF({ ...f, kind: k })}>{ic} {l}</button>
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
                    <div className="person">{KINDS[n.kind]?.[1]} <b>{n.students?.last_name} {n.students?.first_name}</b> <span className={'badge ' + (n.kind === 'positif' ? 'ok' : 'bad')}>{KINDS[n.kind]?.[0]}</span> {n.comment && <span className="meta">{n.comment}</span>}</div>
                    <span className="meta">{new Date(n.date).toLocaleDateString('fr-FR')} {!n.visible_to_parent && '🔒'} <button className="btn-small btn-danger" onClick={() => delNote(n.id)}>✕</button></span>
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
