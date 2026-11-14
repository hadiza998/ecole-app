'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { mean, subjectAvg, generalAvg, appreciation, fmt } from '../../lib/grades';

export default function Bulletin() {
  const { profile, status } = useProfile(['admin']);
  const [school, setSchool] = useState(null);
  const [classes, setClasses] = useState([]);
  const [classId, setClassId] = useState('');
  const [term, setTerm] = useState(1);
  const [studentId, setStudentId] = useState('all');
  const [students, setStudents] = useState([]);
  const [grades, setGrades] = useState([]);

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
    })();
  }, [classId]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const termKey = term === 0 ? null : term;
  function compute(sid) {
    const mine = grades.filter((g) => g.student_id === sid && (termKey == null || g.term === termKey));
    const bySub = {};
    mine.forEach((g) => { (bySub[g.subject_id] ||= { name: g.subjects?.name, coef: Number(g.subjects?.coefficient || 1), list: [] }).list.push(g); });
    const lines = Object.values(bySub).sort((a, b) => a.name.localeCompare(b.name)).map((s) => ({
      name: s.name, coef: s.coef,
      dev: mean(s.list.filter((g) => g.kind === 'devoir').map((g) => Number(g.score))),
      comp: mean(s.list.filter((g) => g.kind === 'composition').map((g) => Number(g.score))),
      avg: subjectAvg(s.list),
    }));
    return { lines, gen: generalAvg(lines.map((l) => ({ avg: l.avg, coef: l.coef }))) };
  }
  const data = students.map((s) => ({ s, ...compute(s.id) }));
  const ranked = [...data].filter((d) => d.gen != null).sort((a, b) => b.gen - a.gen);
  const rankOf = (id) => { const i = ranked.findIndex((d) => d.s.id === id); return i < 0 ? '–' : `${i + 1}${i === 0 ? 'er' : 'e'} / ${ranked.length}`; };
  const cls = classes.find((c) => c.id === classId);
  const shown = studentId === 'all' ? data : data.filter((d) => d.s.id === studentId);

  return (
    <div className="lk-page">
      <div className="topbar no-print"><div><h1>Bulletins</h1><div className="sub">Imprime ou enregistre en PDF (bouton « Imprimer »).</div></div><button onClick={() => window.print()}>🖨 Imprimer / PDF</button></div>
      <div className="lk-card no-print lk-inline">
        <select value={classId} onChange={(e) => setClassId(e.target.value)}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
        <select value={studentId} onChange={(e) => setStudentId(e.target.value)}>
          <option value="all">Toute la classe ({students.length})</option>
          {students.map((s) => <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>)}
        </select>
        <select value={term} onChange={(e) => setTerm(Number(e.target.value))}>
          <option value={1}>1er trimestre</option><option value={2}>2e trimestre</option><option value={3}>3e trimestre</option><option value={0}>Année complète</option>
        </select>
      </div>
      {shown.length === 0 && <div className="empty">Aucun élève dans cette classe.</div>}
      {shown.map(({ s, lines, gen }) => (
        <div className="bul" key={s.id}>
          <div className="head">
            <div>République du Niger<br /><small>Fraternité · Travail · Progrès</small></div>
            <div><b>{school?.name}</b><br /><small>{school?.city}</small></div>
          </div>
          <h2>BULLETIN DE NOTES — {term === 0 ? 'ANNÉE' : `${term}${term === 1 ? 'er' : 'e'} TRIMESTRE`}</h2>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '.95rem' }}>
            <span>Élève : <b>{s.last_name} {s.first_name}</b></span><span>Classe : <b>{cls?.name}</b> · {cls?.school_year}</span>
          </div>
          <table>
            <thead><tr><th>Matière</th><th>Coef</th><th>Devoirs</th><th>Composition</th><th>Moyenne</th><th>Points</th><th>Appréciation</th></tr></thead>
            <tbody>
              {lines.map((l) => (
                <tr key={l.name}><td>{l.name}</td><td>{l.coef}</td><td>{fmt(l.dev)}</td><td>{fmt(l.comp)}</td><td><b>{fmt(l.avg)}</b></td><td>{fmt(l.avg * l.coef)}</td><td>{appreciation(l.avg)}</td></tr>
              ))}
              {lines.length === 0 && <tr><td colSpan={7}>Aucune note</td></tr>}
            </tbody>
          </table>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '1rem' }}>
            <span>Moyenne générale : <b>{fmt(gen)}/20</b> — {appreciation(gen)}</span><span>Rang : <b>{rankOf(s.id)}</b></span>
          </div>
          <div className="sign"><span>Le professeur principal</span><span>Le Directeur</span><span>Les parents</span></div>
        </div>
      ))}
    </div>
  );
}
