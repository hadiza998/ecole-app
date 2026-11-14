'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fmt } from '../../lib/grades';

export default function Notes() {
  const { profile, status } = useProfile(['admin', 'teacher']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [classId, setClassId] = useState('');
  const [subjectId, setSubjectId] = useState('');
  const [term, setTerm] = useState(1);
  const [kind, setKind] = useState('devoir');
  const [students, setStudents] = useState([]);
  const [grades, setGrades] = useState([]);
  const [vals, setVals] = useState({});
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
        const { data } = await supabase.from('teaching').select('subject_id, subjects(id, name)').eq('class_id', classId).eq('teacher_id', profile.id);
        list = (data || []).map((x) => x.subjects).filter(Boolean);
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
      const { data: g } = await supabase.from('grades').select('id, student_id, score, kind, term').in('student_id', ids).eq('subject_id', subjectId).eq('term', term).eq('kind', kind).order('created_at');
      setGrades(g || []);
    } else setGrades([]);
    setVals({});
  }
  useEffect(() => { load(); }, [classId, subjectId, term, kind]);

  async function saveAll() {
    setMsg('');
    const bad = Object.values(vals).some((v) => v !== '' && (isNaN(Number(v.replace(',', '.'))) || Number(v.replace(',', '.')) < 0 || Number(v.replace(',', '.')) > 20));
    if (bad) return setMsg('Les notes doivent être entre 0 et 20.');
    const rows = Object.entries(vals).filter(([, v]) => v !== '').map(([sid, v]) => ({
      school_id: profile.school_id, student_id: sid, subject_id: subjectId, term, kind, score: Number(v.replace(',', '.')), created_by: profile.id,
    }));
    if (!rows.length) return setMsg('Écris au moins une note.');
    const { error } = await supabase.from('grades').insert(rows);
    if (error) return setMsg(error.message);
    setMsg(`${rows.length} note(s) enregistrée(s) ✓`); load();
  }
  async function editGrade(g) {
    const v = prompt('Nouvelle note sur 20 (laisse vide pour supprimer)', g.score);
    if (v === null) return;
    if (v.trim() === '') { await supabase.from('grades').delete().eq('id', g.id); return load(); }
    const n = Number(v.replace(',', '.'));
    if (isNaN(n) || n < 0 || n > 20) return alert('Note entre 0 et 20');
    await supabase.from('grades').update({ score: n }).eq('id', g.id); load();
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
          <div className="tabs">{[1, 2, 3].map((t) => <button key={t} className={term === t ? 'on' : ''} onClick={() => setTerm(t)}>Trimestre {t}</button>)}</div>
          <div className="tabs">{[['devoir', 'Devoir'], ['composition', 'Composition']].map(([k, l]) => <button key={k} className={kind === k ? 'on' : ''} onClick={() => setKind(k)}>{l}</button>)}</div>
        </div>
      </div>

      {subjects.length === 0 && classId && <div className="empty">{profile.role === 'teacher' ? "Tu n'enseignes aucune matière dans cette classe." : 'Aucune matière. Ajoute-en dans « Classes ».'}</div>}
      {students.length > 0 && subjectId && (
        <div className="lk-card">
          {students.map((s) => {
            const mine = grades.filter((g) => g.student_id === s.id);
            return (
              <div className="row" key={s.id}>
                <div className="person"><span className="avatar">{(s.first_name[0] || '') + (s.last_name[0] || '')}</span>{s.last_name} {s.first_name}</div>
                <div className="actions">
                  {mine.map((g) => <button key={g.id} className="chip-score" title="Cliquer pour modifier ou supprimer" onClick={() => editGrade(g)}>{fmt(g.score)}</button>)}
                  <input className="score-in" inputMode="decimal" placeholder="/20" value={vals[s.id] || ''} onKeyDown={next}
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
