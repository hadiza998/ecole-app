'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentGrid, { filledRows } from '../components/StudentGrid';
import { useSettings } from '../../lib/useSettings';
import { periodWord } from '../../lib/settings';

const DAYS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const norm = (s) => s.trim().replace(/\s+/g, ' ');
const year = () => { const d = new Date(); const y = d.getMonth() >= 8 ? d.getFullYear() : d.getFullYear() - 1; return `${y}-${y + 1}`; };
const nice = (m) => (/duplicate key|unique/i.test(m) ? 'Cette classe existe déjà dans l\'école.' : m);

// Choix des matières + combien de devoirs / compositions par trimestre
function SubjectPicker({ subjects, value, onToggle, onPlan, me, reload, setErr, allowManage }) {
  const st = useSettings();
  const [nw, setNw] = useState({ name: '', coef: '1' });
  async function add() {
    if (!nw.name.trim()) return;
    const { data, error } = await supabase.from('subjects').insert({ school_id: me.school_id, name: norm(nw.name), coefficient: Number(nw.coef) || 1 }).select().single();
    if (error) return setErr(error.message);
    setNw({ name: '', coef: '1' }); await reload(); onToggle(data.id);
  }
  async function rename(s) {
    const v = prompt('Nouveau nom de la matière', s.name);
    if (!v || !v.trim()) return;
    const c = prompt('Coefficient', s.coefficient);
    const { error } = await supabase.from('subjects').update({ name: norm(v), coefficient: Number(c) || s.coefficient }).eq('id', s.id);
    if (error) setErr(error.message); else reload();
  }
  async function del(s) {
    if (!confirm(`Supprimer définitivement la matière « ${s.name} » ?`)) return;
    const { error } = await supabase.rpc('delete_subject', { p_id: s.id });
    if (error) setErr(error.message); else reload();
  }
  const chosenIds = Object.keys(value);
  return (
    <div className="lk-stack">
      <div className="chips">
        {subjects.map((s) => (
          <button type="button" key={s.id} className={value[s.id] ? 'on' : ''} onClick={() => onToggle(s.id)}>
            {s.name} <small style={{ color: 'inherit', opacity: .7 }}>coef {s.coefficient}</small>
          </button>
        ))}
        {subjects.length === 0 && <span className="meta">Aucune matière : ajoute-en une ci-dessous.</span>}
      </div>
      {allowManage && subjects.some((s) => s.created_by === me.id) && (
        <div className="meta">Tes matières :{' '}
          {subjects.filter((s) => s.created_by === me.id).map((s) => (
            <span key={s.id} className="tag" style={{ marginRight: 6 }}>{s.name}{' '}
              <a style={{ cursor: 'pointer' }} onClick={() => rename(s)} title="Modifier">✎</a>{' '}
              <a style={{ cursor: 'pointer', color: 'var(--red)' }} onClick={() => del(s)} title="Supprimer">✕</a></span>
          ))}
        </div>
      )}
      <div className="lk-inline">
        <input placeholder="Nouvelle matière (ex. Maths)" value={nw.name} onChange={(e) => setNw({ ...nw, name: e.target.value })} />
        <input type="number" min="0.5" step="0.5" value={nw.coef} onChange={(e) => setNw({ ...nw, coef: e.target.value })} style={{ maxWidth: 90 }} title="Coefficient" />
        <button type="button" className="btn-ghost" onClick={add}>+ Ajouter la matière</button>
      </div>
      {chosenIds.length > 0 && (
        <div className="lk-grid-box">
          <b>Ton programme par {periodWord(st)}</b>
          {chosenIds.map((id) => {
            const s = subjects.find((x) => x.id === id); if (!s) return null;
            return (
              <div className="lk-inline" key={id}>
                <span className="person" style={{ minWidth: 110 }}>{s.name}</span>
                <label className="meta">Devoirs</label>
                <input type="number" min="0" max="10" value={value[id].d} onChange={(e) => onPlan(id, 'd', e.target.value)} style={{ maxWidth: 80 }} />
                <label className="meta">Compositions</label>
                <input type="number" min="0" max="5" value={value[id].c} onChange={(e) => onPlan(id, 'c', e.target.value)} style={{ maxWidth: 80 }} />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function Classes() {
  const { profile, status } = useProfile(['admin', 'teacher']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [mine, setMine] = useState([]);       // mes lignes de teaching
  const [counts, setCounts] = useState({});
  const [subs, setSubs] = useState({});
  const [err, setErr] = useState('');
  const [mode, setMode] = useState(null);      // 'create' | classId (rejoindre)
  const [manage, setManage] = useState(null);
  const isTeacher = profile?.role === 'teacher';

  // formulaire de création
  const [name, setName] = useState(''); const [yr, setYr] = useState('');
  useEffect(() => { setYr(year()); }, []);  // la date du jour se lit après l'affichage (exigé par Next.js)
  const [plan, setPlan] = useState({});        // subjectId -> {d,c}
  const [slots, setSlots] = useState([]);
  const [rows, setRows] = useState([]);
  const [busy, setBusy] = useState(false);

  async function load() {
    const [c, s, t, st] = await Promise.all([
      supabase.from('classes').select('id, name, school_year, created_by').order('name'),
      supabase.from('subjects').select('id, name, coefficient, created_by').order('name'),
      supabase.from('teaching').select('class_id, subject_id, devoirs_per_term, compositions_per_term, teacher_id, subjects(name)'),
      supabase.from('students').select('id, class_id'),
    ]);
    setClasses(c.data || []); setSubjects(s.data || []);
    const all = t.data || [];
    setMine(all.filter((x) => x.teacher_id === profile.id));
    const sb = {}; all.forEach((x) => { (sb[x.class_id] ||= new Set()).add(x.subjects?.name); });
    setSubs(Object.fromEntries(Object.entries(sb).map(([k, v]) => [k, [...v]])));
    const cnt = {}; (st.data || []).forEach((x) => { cnt[x.class_id] = (cnt[x.class_id] || 0) + 1; });
    setCounts(cnt);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);
  const reloadSubjects = async () => setSubjects((await supabase.from('subjects').select('id, name, coefficient, created_by').order('name')).data || []);

  const toggleDraft = (id) => setPlan((p) => { const n = { ...p }; if (n[id]) delete n[id]; else n[id] = { d: 2, c: 1 }; return n; });
  const planDraft = (id, k, v) => setPlan((p) => ({ ...p, [id]: { ...p[id], [k]: v } }));

  const duplicate = name.trim() && classes.find((c) => norm(c.name).toLowerCase() === norm(name).toLowerCase() && c.school_year === yr.trim());

  async function create(e) {
    e.preventDefault(); setErr('');
    if (!name.trim()) return setErr('Donne un nom à la classe (ex. 6e A).');
    if (duplicate) return setErr('Cette classe existe déjà : rejoins-la plutôt que de la recréer.');
    const ids = Object.keys(plan);
    if (isTeacher && ids.length === 0) return setErr('Choisis au moins une matière que tu enseignes.');
    for (const s of slots) if (s.end <= s.start) return setErr("Dans les horaires, l'heure de fin doit être après le début.");
    setBusy(true);
    const { data: id, error } = await supabase.rpc('create_class', { p_name: name, p_year: yr, p_subject_ids: ids, p_students: [] });
    if (error) { setBusy(false); return setErr(nice(error.message)); }
    for (const sid of ids) await supabase.from('teaching').update({ devoirs_per_term: Number(plan[sid].d) || 0, compositions_per_term: Number(plan[sid].c) || 0 }).eq('class_id', id).eq('subject_id', sid).eq('teacher_id', profile.id);
    if (slots.length) await supabase.from('timetable').insert(slots.map((s) => ({ school_id: profile.school_id, class_id: id, day: Number(s.day), start_time: s.start, end_time: s.end, subject_id: s.subject_id || null, teacher_id: isTeacher ? profile.id : null })));
    const list = filledRows(rows);
    if (list.length) await supabase.from('students').insert(list.map((r) => ({ school_id: profile.school_id, class_id: id, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—' })));
    setBusy(false); setMode(null); setName(''); setPlan({}); setSlots([]); setRows([]); load();
  }

  async function join(classId) {
    setErr('');
    const ids = Object.keys(plan);
    if (!ids.length) return setErr('Choisis au moins une matière.');
    const { error } = await supabase.rpc('join_class', { p_class_id: classId, p_subject_ids: ids });
    if (error) return setErr(error.message);
    for (const sid of ids) await supabase.from('teaching').update({ devoirs_per_term: Number(plan[sid].d) || 0, compositions_per_term: Number(plan[sid].c) || 0 }).eq('class_id', classId).eq('subject_id', sid).eq('teacher_id', profile.id);
    setMode(null); setPlan({}); load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const myIds = new Set([...mine.map((x) => x.class_id), ...classes.filter((c) => c.created_by === profile.id).map((c) => c.id)]);
  const myClasses = isTeacher ? classes.filter((c) => myIds.has(c.id)) : classes;
  const others = isTeacher ? classes.filter((c) => !myIds.has(c.id)) : [];

  const card = (c, joinable) => (
    <div className="lk-card lift" key={c.id}>
      <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
        <div>
          <h3>{c.name} <small>{c.school_year}</small></h3>
          <span className="meta">{counts[c.id] || 0} élève(s){subs[c.id]?.length ? ' · ' + subs[c.id].join(', ') : ''}</span>
        </div>
        <div className="actions">
          {joinable ? (
            <button className="btn-small" onClick={() => { setMode(mode === c.id ? null : c.id); setPlan({}); }}>Rejoindre</button>
          ) : (
            <>
              <Link className="btn-small" href={`/eleves?classe=${c.id}`}>Élèves</Link>
              <Link className="btn-small" href="/planning">Planning</Link>
              <button className="btn-small btn-ghost" onClick={() => setManage(manage === c.id ? null : c.id)}>{manage === c.id ? 'Fermer' : '✎ Gérer'}</button>
            </>
          )}
        </div>
      </div>
      {joinable && mode === c.id && (
        <div className="lk-stack">
          <b>Avec quelle(s) matière(s) rejoins-tu {c.name} ?</b>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggleDraft} onPlan={planDraft} me={profile} reload={reloadSubjects} setErr={setErr} allowManage />
          <div><button onClick={() => join(c.id)}>Rejoindre la classe</button></div>
        </div>
      )}
      {!joinable && manage === c.id && <Manage c={c} me={profile} isTeacher={isTeacher} subjects={subjects} mine={mine} reload={load} reloadSubjects={reloadSubjects} setErr={setErr} canEdit={!isTeacher || c.created_by === profile.id} />}
    </div>
  );

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>{isTeacher ? 'Mes classes' : 'Classes'}</h1><div className="sub">Chaque classe est unique dans l'école.</div></div>
        <button onClick={() => { setMode(mode === 'create' ? null : 'create'); setPlan({}); }}>{mode === 'create' ? 'Fermer' : '+ Nouvelle classe'}</button>
      </div>
      {err && <div className="notice">{err}</div>}

      {mode === 'create' && (
        <form className="lk-card lk-stack" onSubmit={create}>
          <div className="lk-step"><b>1</b><h3>La classe</h3></div>
          <div className="lk-inline">
            <input placeholder="Nom (ex. 3e B)" value={name} onChange={(e) => setName(e.target.value)} />
            <input placeholder="Année scolaire" value={yr} onChange={(e) => setYr(e.target.value)} style={{ maxWidth: 160 }} />
          </div>
          {duplicate && (
            <div className="notice">La classe « {duplicate.name} » existe déjà. {isTeacher && <a style={{ cursor: 'pointer', fontWeight: 700 }} onClick={() => { setMode(duplicate.id); setPlan({}); }}>Rejoins-la avec ta matière →</a>}</div>
          )}
          <div className="lk-step"><b>2</b><h3>{isTeacher ? 'Tes matières et ton programme' : 'Les matières'}</h3></div>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggleDraft} onPlan={planDraft} me={profile} reload={reloadSubjects} setErr={setErr} allowManage />
          <div className="lk-step"><b>3</b><h3>Jours et horaires de cours <small>(facultatif)</small></h3></div>
          {slots.map((s, i) => (
            <div className="lk-inline" key={i}>
              <select value={s.day} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, day: e.target.value } : x))}>{DAYS.map((d, k) => <option key={d} value={k + 1}>{d}</option>)}</select>
              <input type="time" value={s.start} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, start: e.target.value } : x))} />
              <input type="time" value={s.end} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, end: e.target.value } : x))} />
              <select value={s.subject_id} onChange={(e) => setSlots(slots.map((x, j) => j === i ? { ...x, subject_id: e.target.value } : x))}>
                <option value="">Matière</option>{subjects.filter((x) => plan[x.id]).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
              </select>
              <button type="button" className="btn-small btn-danger" onClick={() => setSlots(slots.filter((_, j) => j !== i))}>✕</button>
            </div>
          ))}
          <div><button type="button" className="btn-ghost btn-small" onClick={() => setSlots([...slots, { day: '1', start: '08:00', end: '09:00', subject_id: Object.keys(plan)[0] || '' }])}>+ Ajouter un créneau</button></div>
          <div className="lk-step"><b>4</b><h3>Les élèves</h3></div>
          <StudentGrid rows={rows} setRows={setRows} />
          <button disabled={busy || !!duplicate}>{busy ? 'Création…' : 'Créer la classe'}</button>
        </form>
      )}

      {myClasses.length === 0 && mode !== 'create' && <div className="empty">{isTeacher ? "Tu n'as pas encore de classe. Crée-en une ou rejoins une classe existante." : 'Aucune classe pour le moment.'}</div>}
      {myClasses.map((c) => card(c, false))}

      {others.length > 0 && (
        <>
          <h3 style={{ marginTop: 10 }}>Autres classes de l'école</h3>
          <div className="meta" style={{ marginTop: -12 }}>Tu enseignes dans une de ces classes ? Rejoins-la avec ta matière.</div>
          {others.map((c) => card(c, true))}
        </>
      )}
    </div>
  );
}

// Panneau « Gérer » d'une classe
function Manage({ c, me, isTeacher, subjects, mine, reload, reloadSubjects, setErr, canEdit }) {
  const [name, setName] = useState(c.name);
  const [yr, setYr] = useState(c.school_year);
  const [students, setStudents] = useState([]);
  const [edit, setEdit] = useState(null);
  const [rows, setRows] = useState([]);
  const myRows = mine.filter((x) => x.class_id === c.id);
  const value = Object.fromEntries(myRows.map((x) => [x.subject_id, { d: x.devoirs_per_term, c: x.compositions_per_term }]));
  const [plan, setPlan] = useState(value);
  useEffect(() => setPlan(value), [mine]);

  const loadStudents = async () => setStudents((await supabase.from('students').select('id, first_name, last_name, access_code').eq('class_id', c.id).order('last_name')).data || []);
  useEffect(() => { loadStudents(); }, [c.id]);

  async function saveClass() {
    setErr('');
    const { error } = await supabase.from('classes').update({ name: norm(name), school_year: yr.trim() }).eq('id', c.id);
    if (error) setErr(nice(error.message)); else reload();
  }
  async function toggle(id) {
    setErr('');
    if (plan[id]) {
      if (!confirm('Retirer cette matière de ta classe ? (Les notes déjà saisies sont conservées.)')) return;
      const { error } = await supabase.from('teaching').delete().eq('class_id', c.id).eq('subject_id', id).eq('teacher_id', me.id);
      if (error) return setErr(error.message);
    } else {
      const { error } = await supabase.rpc('join_class', { p_class_id: c.id, p_subject_ids: [id] });
      if (error) return setErr(error.message);
    }
    reload();
  }
  async function savePlan(id, k, v) {
    setPlan((p) => ({ ...p, [id]: { ...p[id], [k]: v } }));
    await supabase.from('teaching').update(k === 'd' ? { devoirs_per_term: Number(v) || 0 } : { compositions_per_term: Number(v) || 0 }).eq('class_id', c.id).eq('subject_id', id).eq('teacher_id', me.id);
  }
  async function addStudents() {
    const list = filledRows(rows); if (!list.length) return;
    const { error } = await supabase.from('students').insert(list.map((r) => ({ school_id: me.school_id, class_id: c.id, last_name: r.last.trim() || '—', first_name: r.first.trim() || '—' })));
    if (error) setErr(error.message); else { setRows([]); loadStudents(); reload(); }
  }
  async function saveStudent() {
    const { error } = await supabase.from('students').update({ first_name: edit.first_name.trim(), last_name: edit.last_name.trim() }).eq('id', edit.id);
    if (error) setErr(error.message); else { setEdit(null); loadStudents(); }
  }
  async function delStudent(s) {
    if (!confirm(`Retirer ${s.first_name} ${s.last_name} (et ses notes) ?`)) return;
    await supabase.from('students').delete().eq('id', s.id); loadStudents(); reload();
  }
  async function delClass() {
    if (!confirm(`Supprimer la classe ${c.name} avec ses élèves et leurs notes ?`)) return;
    const { error } = await supabase.from('classes').delete().eq('id', c.id);
    if (error) setErr(error.message); else reload();
  }

  return (
    <div className="lk-stack" style={{ borderTop: '1px solid var(--line)', paddingTop: 14 }}>
      {canEdit && (
        <div className="lk-inline">
          <input value={name} onChange={(e) => setName(e.target.value)} />
          <input value={yr} onChange={(e) => setYr(e.target.value)} style={{ maxWidth: 150 }} />
          <button className="btn-small" onClick={saveClass}>Enregistrer</button>
        </div>
      )}
      {isTeacher && (
        <>
          <h4>Mes matières dans cette classe</h4>
          <SubjectPicker subjects={subjects} value={plan} onToggle={toggle} onPlan={savePlan} me={me} reload={reloadSubjects} setErr={setErr} allowManage />
        </>
      )}
      <h4>Élèves ({students.length})</h4>
      {students.map((s) => (
        <div className="row" key={s.id}>
          {edit?.id === s.id ? (
            <div className="lk-inline" style={{ flex: 1 }}>
              <input value={edit.last_name} onChange={(e) => setEdit({ ...edit, last_name: e.target.value })} />
              <input value={edit.first_name} onChange={(e) => setEdit({ ...edit, first_name: e.target.value })} />
              <button className="btn-small" onClick={saveStudent}>OK</button>
              <button className="btn-small btn-ghost" onClick={() => setEdit(null)}>Annuler</button>
            </div>
          ) : (
            <>
              <div className="person">{s.last_name} {s.first_name} <code>{s.access_code}</code></div>
              <div className="actions"><button className="btn-small btn-ghost" onClick={() => setEdit(s)}>Modifier</button><button className="btn-small btn-danger" onClick={() => delStudent(s)}>Retirer</button></div>
            </>
          )}
        </div>
      ))}
      <StudentGrid rows={rows} setRows={setRows} />
      {rows.length > 0 && <div><button onClick={addStudents}>Ajouter ces élèves</button></div>}
      {canEdit && <div><button className="btn-small btn-danger" onClick={delClass}>Supprimer cette classe</button></div>}
    </div>
  );
}
