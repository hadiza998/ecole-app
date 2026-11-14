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
