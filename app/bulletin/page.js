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
