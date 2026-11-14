#!/bin/bash
# Lakol v3 : nouveau design + classes + vie scolaire + frais. À lancer depuis le dossier ecole-app.
set -e
if [ ! -f package.json ] || [ ! -d app ]; then echo "❌ Lance ce script depuis le dossier ecole-app (celui qui contient package.json et app)."; exit 1; fi
B="_sauvegarde_avant_v3"; mkdir -p "$B"
save(){ if [ -f "$1" ] && [ ! -f "$B/$1" ]; then mkdir -p "$B/$(dirname "$1")"; cp "$1" "$B/$1"; fi; }

save "app/NavMenu.tsx"
mkdir -p "$(dirname "app/NavMenu.tsx")"
cat > 'app/NavMenu.tsx' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '../lib/supabase';
import Logo from './components/Logo';

type Item = [string, string, string];
const MENUS: Record<string, Item[]> = {
  admin: [
    ['/dashboard', 'Tableau de bord', 'grid'], ['/classes', 'Classes', 'book'], ['/eleves', 'Élèves', 'user'],
    ['/professeurs', 'Professeurs', 'users'], ['/planning', 'Planning', 'calendar'],
    ['/bulletin', 'Bulletins', 'file'], ['/paiements', 'Scolarité', 'card'],
  ],
  teacher: [['/classes', 'Mes classes', 'book'], ['/eleves', 'Élèves', 'user'], ['/notes', 'Notes', 'edit'], ['/vie-scolaire', 'Vie scolaire', 'heart'], ['/planning', 'Planning', 'calendar']],
  parent: [['/parent', 'Mon enfant', 'user'], ['/planning', 'Planning', 'calendar']],
};
const LABEL: Record<string, string> = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

function Icon({ name }: { name: string }) {
  const p: Record<string, React.ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" /><rect x="3" y="14" width="7" height="7" rx="1.5" /></>,
    users: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></>,
    book: <><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" /><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" /></>,
    user: <><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" /></>,
    calendar: <><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></>,
    edit: <><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" /></>,
    file: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6M16 13H8M16 17H8" /></>,
    heart: <><path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z" /></>,
    card: <><rect x="1" y="4" width="22" height="16" rx="2" /><path d="M1 10h22" /></>,
  };
  return <svg viewBox="0 0 24 24">{p[name]}</svg>;
}

export default function NavMenu() {
  const path = usePathname();
  const [me, setMe] = useState<{ role: string; name: string } | null>(null);

  useEffect(() => {
    let alive = true;
    async function load() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { if (alive) setMe(null); return; }
      const { data: p } = await supabase.from('profiles').select('role, active, full_name').eq('id', data.session.user.id).maybeSingle();
      if (alive) setMe(p && p.active !== false ? { role: p.role, name: p.full_name } : null);
    }
    load();
    const { data: sub } = supabase.auth.onAuthStateChange(() => load());
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, []);

  if (path === '/login' || !me) return null;
  const initials = me.name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
  return (
    <aside className="lk-side no-print">
      <Link href="/" className="lk-brand"><Logo id="lgn" />Lakol</Link>
      <div className="lk-navlabel">Menu</div>
      <nav className="lk-links">
        {(MENUS[me.role] || []).map(([href, label, icon]) => (
          <Link key={href} href={href} className={path === href || path.startsWith(href + '/') ? 'on' : ''}>
            <Icon name={icon} />{label}
          </Link>
        ))}
      </nav>
      <div className="lk-user">
        <span className="avatar">{initials}</span>
        <div className="who"><b>{me.name}</b><span>{LABEL[me.role]}</span></div>
        <button className="nav-logout" title="Déconnexion" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>
          <svg viewBox="0 0 24 24"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" /></svg>
        </button>
      </div>
    </aside>
  );
}
LAKOL_EOF

save "app/bulletin/page.js"
mkdir -p "$(dirname "app/bulletin/page.js")"
cat > 'app/bulletin/page.js' <<'LAKOL_EOF'
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
LAKOL_EOF

save "app/classes/page.js"
mkdir -p "$(dirname "app/classes/page.js")"
cat > 'app/classes/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import StudentGrid, { filledRows } from '../components/StudentGrid';

const DAYS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const norm = (s) => s.trim().replace(/\s+/g, ' ');
const year = () => { const d = new Date(); const y = d.getMonth() >= 8 ? d.getFullYear() : d.getFullYear() - 1; return `${y}-${y + 1}`; };
const nice = (m) => (/duplicate key|unique/i.test(m) ? 'Cette classe existe déjà dans l\'école.' : m);

// Choix des matières + combien de devoirs / compositions par trimestre
function SubjectPicker({ subjects, value, onToggle, onPlan, me, reload, setErr, allowManage }) {
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
          <b>Ton programme par trimestre</b>
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
  const [name, setName] = useState(''); const [yr, setYr] = useState(year());
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
LAKOL_EOF

save "app/components/Logo.js"
mkdir -p "$(dirname "app/components/Logo.js")"
cat > 'app/components/Logo.js' <<'LAKOL_EOF'
export default function Logo({ size = 36, id = 'lg' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-label="Lakol" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#8B5CF6" /><stop offset="1" stopColor="#22D3EE" />
        </linearGradient>
      </defs>
      <rect width="40" height="40" rx="13" fill={`url(#${id})`} />
      <path d="M8 14c4.2-1.7 8.2-1 12 1.6V30c-3.8-2.6-7.8-3.3-12-1.6z" fill="#fff" />
      <path d="M32 14c-4.2-1.7-8.2-1-12 1.6V30c3.8-2.6 7.8-3.3 12-1.6z" fill="#fff" opacity=".78" />
      <circle cx="31" cy="9" r="3.2" fill="#FF8A5B" />
      <circle cx="9.5" cy="9.5" r="1.6" fill="#fff" opacity=".7" />
    </svg>
  );
}
LAKOL_EOF

save "app/components/StudentFile.js"
mkdir -p "$(dirname "app/components/StudentFile.js")"
cat > 'app/components/StudentFile.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { KINDS } from '../../lib/kinds';
import { subjectAvg, generalAvg, appreciation, fmt, fcfa, METHODS } from '../../lib/grades';

// Fiche élève. role = 'admin' | 'teacher' | 'parent'.
// La scolarité (frais, paiements) n'est affichée qu'au directeur et aux parents.
export default function StudentFile({ studentId, role }) {
  const [student, setStudent] = useState(null);
  const [grades, setGrades] = useState([]);
  const [fees, setFees] = useState([]);
  const [payments, setPayments] = useState([]);
  const [att, setAtt] = useState([]);
  const [behav, setBehav] = useState([]);
  const [todo, setTodo] = useState([]);
  const [loading, setLoading] = useState(true);
  const showMoney = role === 'admin' || role === 'parent';

  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data: s } = await supabase.from('students')
        .select('id, first_name, last_name, class_id, matricule, access_code, classes(name, school_year)')
        .eq('id', studentId).maybeSingle();
      setStudent(s);
      const { data: g } = await supabase.from('grades')
        .select('id, term, kind, score, subject_id, created_at, subjects(name, coefficient)')
        .eq('student_id', studentId).order('created_at', { ascending: false });
      setGrades(g || []);
      const [a, b, t] = await Promise.all([
        supabase.from('attendance').select('id, date, status').eq('student_id', studentId).neq('status', 'present').order('date', { ascending: false }),
        supabase.from('behavior_notes').select('id, date, kind, comment').eq('student_id', studentId).order('date', { ascending: false }),
        s?.class_id ? supabase.from('assignments').select('id, kind, title, due_date, chapters, subjects(name)').eq('class_id', s.class_id).gte('due_date', new Date().toISOString().slice(0, 10)).order('due_date') : { data: [] },
      ]);
      setAtt(a.data || []); setBehav(b.data || []); setTodo(t.data || []);
      if (showMoney && s) {
        const [f, p] = await Promise.all([
          s.class_id ? supabase.from('fees').select('id, label, amount').or(`class_id.eq.${s.class_id},class_id.is.null`) : supabase.from('fees').select('id, label, amount').is('class_id', null),
          supabase.from('payments').select('id, amount, method, paid_at, fee_id').eq('student_id', studentId).order('paid_at', { ascending: false }),
        ]);
        setFees(f.data || []);
        setPayments(p.data || []);
      }
      setLoading(false);
    })();
  }, [studentId, showMoney]);

  if (loading) return <p className="meta">Chargement…</p>;
  if (!student) return <div className="empty">Élève introuvable.</div>;

  // matières
  const bySubject = {};
  grades.forEach((g) => {
    const id = g.subject_id;
    if (!bySubject[id]) bySubject[id] = { name: g.subjects?.name || '?', coef: g.subjects?.coefficient || 1, list: [] };
    bySubject[id].list.push(g);
  });
  const subjects = Object.values(bySubject).sort((a, b) => a.name.localeCompare(b.name));
  const termAvgs = [1, 2, 3].map((t) =>
    generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list.filter((g) => g.term === t)), coef: s.coef })))
  );
  const yearAvg = generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list), coef: s.coef })));

  const due = fees.reduce((s, f) => s + f.amount, 0);
  const paid = payments.reduce((s, p) => s + p.amount, 0);
  const left = Math.max(0, due - paid);
  const pct = due ? Math.min(100, Math.round((paid / due) * 100)) : 0;

  return (
    <div className="lk-stack">
      <div className="lk-card lk-hero">
        <div className="avatar">{(student.first_name[0] || '') + (student.last_name[0] || '')}</div>
        <div style={{ flex: 1 }}>
          <h2 style={{ margin: 0 }}>{student.first_name} {student.last_name}</h2>
          <div className="meta">{student.classes?.name || 'Sans classe'} · {student.classes?.school_year || ''}</div>
          {role !== 'parent' && student.access_code && (
            <div className="meta">Code parent : <code>{student.access_code}</code></div>
          )}
        </div>
        <div className="lk-bigscore">
          <span>{fmt(yearAvg)}</span>
          <small>{yearAvg != null ? `Moyenne · ${appreciation(yearAvg)}` : 'Pas encore de notes'}</small>
        </div>
      </div>

      {todo.length > 0 && (
        <div className="lk-card">
          <h3>📅 À venir pour la classe</h3>
          {todo.map((x) => {
            const n = Math.round((new Date(x.due_date) - new Date(new Date().toISOString().slice(0, 10))) / 864e5);
            return (
              <div className="row" key={x.id}>
                <div className="person">
                  <span className={'badge ' + (x.kind === 'devoir' ? 'mid' : 'bad')}>{x.kind === 'devoir' ? 'Devoir' : x.kind === 'examen' ? 'Examen' : 'Composition'}</span>
                  {x.title} {x.subjects?.name && <span className="tag">{x.subjects.name}</span>}
                  {x.chapters && <span className="meta">Chapitres : {x.chapters}</span>}
                </div>
                <span className="meta">{new Date(x.due_date).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })} · <b>{n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} jours`}</b></span>
              </div>
            );
          })}
        </div>
      )}

      <div className="lk-card">
        <h3>Notes par matière</h3>
        {subjects.length === 0 ? <div className="empty">Aucune note pour le moment.</div> : (
          <div className="lk-scroll">
            <table className="data">
              <thead><tr><th>Matière</th><th>Coef</th><th>T1</th><th>T2</th><th>T3</th><th>Moyenne</th></tr></thead>
              <tbody>
                {subjects.map((s) => (
                  <tr key={s.name}>
                    <td>{s.name}</td><td>{s.coef}</td>
                    {[1, 2, 3].map((t) => {
                      const v = subjectAvg(s.list.filter((g) => g.term === t));
                      return <td key={t} className={v != null && v < 10 ? 'lk-low' : ''}>{fmt(v)}</td>;
                    })}
                    <td><strong>{fmt(subjectAvg(s.list))}</strong></td>
                  </tr>
                ))}
                <tr className="lk-total">
                  <td colSpan={2}>Moyenne générale</td>
                  {termAvgs.map((v, i) => <td key={i}>{fmt(v)}</td>)}
                  <td><strong>{fmt(yearAvg)}</strong></td>
                </tr>
              </tbody>
            </table>
          </div>
        )}
        {grades.length > 0 && (
          <details className="lk-details">
            <summary>Voir toutes les notes ({grades.length})</summary>
            {grades.map((g) => (
              <div className="row" key={g.id}>
                <div className="person">{g.subjects?.name} <span className="tag">{g.kind === 'devoir' ? 'Devoir' : 'Composition'} · T{g.term}</span></div>
                <span className="score">{fmt(g.score)}/20</span>
              </div>
            ))}
          </details>
        )}
      </div>

      <div className="lk-card">
        <h3>Vie scolaire</h3>
        <div className="lk-inline">
          <span className="badge bad">{att.filter((a) => a.status === 'absent').length} absence(s)</span>
          <span className="badge mid">{att.filter((a) => a.status === 'late').length} retard(s)</span>
          <span className="badge">{behav.length} remarque(s)</span>
        </div>
        {behav.length === 0 && att.length === 0 && <span className="meta">Rien à signaler pour le moment 🎉</span>}
        {behav.map((b) => (
          <div className="row" key={b.id}>
            <div className="person">{KINDS[b.kind]?.[1]} <span className={'badge ' + (b.kind === 'positif' ? 'ok' : 'bad')}>{KINDS[b.kind]?.[0]}</span> {b.comment && <span className="meta">{b.comment}</span>}</div>
            <span className="meta">{new Date(b.date).toLocaleDateString('fr-FR')}</span>
          </div>
        ))}
        {att.length > 0 && (
          <details className="lk-details"><summary>Absences et retards</summary>
            {att.map((a) => <div className="row" key={a.id}><div className="person">{new Date(a.date).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</div><span className={'badge ' + (a.status === 'absent' ? 'bad' : 'mid')}>{a.status === 'absent' ? 'Absent' : 'En retard'}</span></div>)}
          </details>
        )}
      </div>

      {showMoney && (
        <div className="lk-card">
          <h3>Scolarité</h3>
          {fees.length === 0 ? <div className="empty">Aucun frais défini pour cette classe.</div> : (
            <>
              <div className="stats">
                <div className="stat"><small>À payer au total</small><strong>{fcfa(due)}</strong></div>
                <div className="stat"><small>Déjà payé</small><strong className="lk-ok">{fcfa(paid)}</strong></div>
                <div className="stat"><small>Reste à payer</small><strong className={left ? 'lk-warn' : 'lk-ok'}>{left ? fcfa(left) : 'Soldé ✓'}</strong></div>
              </div>
              <div className="bar"><div style={{ width: pct + '%' }} /></div>
              <div className="meta">{pct}% réglé</div>
              {fees.map((f) => <div className="row" key={f.id}><div className="person">{f.label}</div><span>{fcfa(f.amount)}</span></div>)}
            </>
          )}
          {payments.length > 0 && (
            <details className="lk-details" open>
              <summary>Historique des paiements</summary>
              {payments.map((p) => (
                <div className="row" key={p.id}>
                  <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                  <span>{fcfa(p.amount)}</span>
                </div>
              ))}
            </details>
          )}
        </div>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/components/StudentGrid.js"
mkdir -p "$(dirname "app/components/StudentGrid.js")"
cat > 'app/components/StudentGrid.js' <<'LAKOL_EOF'
'use client';
import { useState } from 'react';

// "Combien d'élèves ?" -> des cases vides apparaissent pour écrire les noms.
export default function StudentGrid({ rows, setRows }) {
  const [count, setCount] = useState('');

  function generate() {
    const n = Math.max(0, Math.min(200, parseInt(count, 10) || 0));
    if (!n) return;
    const next = rows.slice(0, n);
    while (next.length < n) next.push({ last: '', first: '' });
    setRows(next);
  }
  const update = (i, k, v) => setRows(rows.map((r, j) => (j === i ? { ...r, [k]: v } : r)));
  const remove = (i) => setRows(rows.filter((_, j) => j !== i));

  return (
    <div className="lk-grid-box">
      <div className="lk-inline">
        <label className="lk-label">Combien d'élèves dans la classe ?</label>
        <input type="number" min="1" max="200" placeholder="ex. 35" value={count}
          onChange={(e) => setCount(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); generate(); } }}
          style={{ maxWidth: 120 }} />
        <button type="button" className="btn-ghost" onClick={generate}>Créer les cases</button>
      </div>

      {rows.length > 0 && (
        <>
          <div className="lk-rows">
            {rows.map((r, i) => (
              <div className="lk-rowline" key={i}>
                <span className="lk-num">{i + 1}</span>
                <input placeholder="Nom" value={r.last} onChange={(e) => update(i, 'last', e.target.value)} />
                <input placeholder="Prénom" value={r.first} onChange={(e) => update(i, 'first', e.target.value)} />
                <button type="button" className="btn-small btn-danger" title="Retirer" onClick={() => remove(i)}>✕</button>
              </div>
            ))}
          </div>
          <div className="lk-inline">
            <button type="button" className="btn-ghost btn-small"
              onClick={() => setRows([...rows, { last: '', first: '' }])}>+ Ajouter une case</button>
            <span className="meta">{rows.filter((r) => r.last.trim() || r.first.trim()).length} / {rows.length} remplie(s)</span>
          </div>
        </>
      )}
    </div>
  );
}

export const filledRows = (rows) => rows.filter((r) => r.last.trim() || r.first.trim());
LAKOL_EOF

save "app/dashboard/page.js"
mkdir -p "$(dirname "app/dashboard/page.js")"
cat > 'app/dashboard/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, fmt, METHODS } from '../../lib/grades';

export default function Dashboard() {
  const { profile, status } = useProfile(['admin']);
  const [term, setTerm] = useState(null);
  const [d, setD] = useState(null);
  const [code, setCode] = useState('');
  const [err, setErr] = useState('');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.rpc('dashboard_overview', { p_term: term }).then(({ data, error }) => {
      if (error) setErr(error.message); else setD(data);
    });
  }, [status, term]);
  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('school_secrets').select('join_code').maybeSingle().then(({ data }) => setCode(data?.join_code || ''));
  }, [status]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const rate = d && d.total_due ? Math.round((d.total_paid / d.total_due) * 100) : 0;
  return (
    <div className="lk-page">
      <div className="hero">
      <div className="topbar">
        <div><h1>Bonjour {profile.full_name.split(' ')[0]} 👋</h1><div className="sub">{new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })} · vue d'ensemble de l'école</div></div>
        <div className="tabs" style={{ background: 'rgba(255,255,255,.2)' }}>
          {[[null, 'Année'], [1, 'T1'], [2, 'T2'], [3, 'T3']].map(([v, l]) => (
            <button key={l} className={term === v ? 'on' : ''} onClick={() => setTerm(v)}>{l}</button>
          ))}
        </div>
      </div>
      </div>
      {err && <div className="notice">{err}</div>}
      {!d ? <p className="meta">Chargement…</p> : (
        <>
          <div className="stats">
            <div className="stat"><i>🎓</i><small>Élèves</small><strong>{d.students}</strong></div>
            <div className="stat c2"><i>📚</i><small>Classes</small><strong>{d.classes}</strong></div>
            <div className="stat c3"><i>👩‍🏫</i><small>Professeurs</small><strong>{d.teachers}</strong></div>
            <div className="stat c4"><i>💰</i><small>Scolarité encaissée</small><strong className="lk-ok">{fcfa(d.total_paid)}</strong><small>sur {fcfa(d.total_due)}</small></div>
          </div>
          <div className="grid2">
            <div className="lk-card lk-inline" style={{ flexWrap: 'nowrap', flexDirection: 'row' }}>
              <div className="donut" style={{ '--p': Math.min(100, rate) }}><span>{rate}%<small>réglé</small></span></div>
              <div><h3>Recouvrement</h3><p className="meta" style={{ margin: '4px 0' }}>Reste à encaisser</p><strong className="lk-warn" style={{ fontSize: '1.4rem' }}>{fcfa(Math.max(0, d.total_due - d.total_paid))}</strong></div>
            </div>
            <div className="lk-card">
              <h3>Moyenne par classe</h3>
              {d.class_stats.filter((c) => c.average != null).length === 0 ? <span className="meta">Pas encore de notes.</span> :
                d.class_stats.filter((c) => c.average != null).map((c) => (
                  <div className="hbar" key={c.id}><span>{c.name}</span><div className="track"><div className={'fill' + (c.average < 10 ? ' low' : '')} style={{ width: (c.average / 20) * 100 + '%' }} /></div><b>{fmt(c.average)}</b></div>
                ))}
            </div>
          </div>
          

          <div className="lk-card">
            <h3>Classes</h3>
            {d.class_stats.length === 0 ? <div className="empty">Aucune classe pour l'instant. Un professeur ou toi peut en créer une dans « Classes ».</div> : (
              <div className="lk-scroll"><table className="data">
                <thead><tr><th>Classe</th><th>Élèves</th><th>Moyenne</th><th>En difficulté (&lt;10)</th><th></th></tr></thead>
                <tbody>{d.class_stats.map((c) => (
                  <tr key={c.id}>
                    <td>{c.name} <small className="meta">{c.school_year}</small></td>
                    <td>{c.students}</td>
                    <td className={c.average != null && c.average < 10 ? 'lk-low' : ''}>{fmt(c.average)}</td>
                    <td>{c.struggling > 0 ? <span className="badge bad">{c.struggling}</span> : '–'}</td>
                    <td><Link href={`/eleves?classe=${c.id}`}>Voir les élèves →</Link></td>
                  </tr>
                ))}</tbody>
              </table></div>
            )}
          </div>

          <div className="grid2">
            <div className="lk-card">
              <h3>Impayés les plus élevés</h3>
              {d.top_unpaid.length === 0 ? <div className="empty">Tout est à jour 🎉</div> : d.top_unpaid.map((s) => (
                <Link className="row" href={`/eleves/${s.id}`} key={s.id}>
                  <div className="person">{s.first_name} {s.last_name} <span className="tag">{s.class_name}</span></div>
                  <strong className="lk-warn">{fcfa(s.remaining)}</strong>
                </Link>
              ))}
              <Link href="/paiements">Gérer la scolarité →</Link>
            </div>
            <div className="lk-card">
              <h3>Derniers paiements</h3>
              {d.recent_payments.length === 0 ? <div className="empty">Aucun paiement enregistré.</div> : d.recent_payments.map((p) => (
                <div className="row" key={p.id}>
                  <div className="person">{p.first_name} {p.last_name} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                  <strong className="lk-ok">{fcfa(p.amount)}</strong>
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      <div className="lk-card lk-inline">
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0 }}>Code de l'école (pour inviter les professeurs)</h3>
          <span className="meta">Donne ce code à chaque professeur : il le saisit à son inscription.</span>
        </div>
        <code className="lk-code">{code || '…'}</code>
        <button className="btn-ghost" onClick={() => { navigator.clipboard?.writeText(code); setCopied(true); setTimeout(() => setCopied(false), 1500); }}>{copied ? 'Copié ✓' : 'Copier'}</button>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/eleves/[id]/page.js"
mkdir -p "$(dirname "app/eleves/[id]/page.js")"
cat > 'app/eleves/[id]/page.js' <<'LAKOL_EOF'
'use client';
import { useParams, useRouter } from 'next/navigation';
import StudentFile from '../../components/StudentFile';
import { useProfile, Blocked } from '../../../lib/useProfile';

export default function FicheEleve() {
  const { id } = useParams();
  const router = useRouter();
  const { profile, status } = useProfile(['admin', 'teacher']);
  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  return (
    <div className="lk-page">
      <button className="btn-ghost btn-small" onClick={() => router.back()}>← Retour</button>
      <StudentFile studentId={id} role={profile.role} />
    </div>
  );
}
LAKOL_EOF

save "app/eleves/page.js"
mkdir -p "$(dirname "app/eleves/page.js")"
cat > 'app/eleves/page.js' <<'LAKOL_EOF'
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
LAKOL_EOF

save "app/globals.css"
mkdir -p "$(dirname "app/globals.css")"
cat > 'app/globals.css' <<'LAKOL_EOF'
/* ===== LAKOL — design vivant : indigo, turquoise, corail ===== */
:root{
  --bg:#F2F0FF; --surface:#fff; --line:#E8E5F7; --text:#1B1740; --muted:#6B6890;
  --brand:#6D4AFF; --brand2:#8B5CF6; --brand-soft:#EEEAFF;
  --teal:#14B8A6; --teal-soft:#DDF7F3; --coral:#FF6B6B; --coral-soft:#FFE9E6; --amber:#F59E0B; --amber-soft:#FEF1D6;
  --green:#12A150; --green-soft:#DDF6E7; --red:#E5484D; --red-soft:#FFE6E6; --blue:#3B82F6; --blue-soft:#E3EEFF;
  --radius:22px; --shadow:0 2px 4px rgba(76,52,200,.04),0 10px 28px rgba(76,52,200,.08);
  --grad:linear-gradient(135deg,#6D4AFF 0%,#9B6BFF 100%);
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{font-family:"Plus Jakarta Sans",system-ui,-apple-system,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);font-size:15px;line-height:1.5;-webkit-font-smoothing:antialiased;position:relative;overflow-x:hidden}
body:before,body:after{content:"";position:fixed;border-radius:50%;filter:blur(70px);z-index:0;pointer-events:none}
body:before{width:420px;height:420px;background:rgba(139,92,246,.22);top:-120px;right:-80px}
body:after{width:380px;height:380px;background:rgba(34,211,238,.20);bottom:-140px;left:260px}
a{color:var(--brand);text-decoration:none}
h1{font-size:1.7rem;margin:0;letter-spacing:-.03em;font-weight:800}
h2{font-size:1.25rem;margin:0;font-weight:700}
h3{font-size:1.02rem;margin:0;font-weight:700}
h4{font-size:.9rem;margin:0}
code{font-family:ui-monospace,Menlo,monospace;background:var(--brand-soft);border-radius:8px;padding:2px 8px;font-size:.82rem;color:var(--brand);font-weight:600}
small{color:var(--muted)}
.meta{color:var(--muted);font-size:.86rem}

.lk-shell{display:flex;min-height:100vh;position:relative;z-index:1}
.lk-main{flex:1;min-width:0}
.lk-page{max-width:1120px;margin:0 auto;padding:28px 28px 90px;display:flex;flex-direction:column;gap:20px}
.lk-stack{display:flex;flex-direction:column;gap:16px}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
.topbar .sub{color:var(--muted);font-size:.92rem;margin-top:3px}

/* bandeau d'accueil */
.hero{position:relative;overflow:hidden;border-radius:28px;padding:28px 30px;color:#fff;background:linear-gradient(120deg,#5B3DF5 0%,#8B5CF6 55%,#22D3EE 130%);box-shadow:0 18px 40px rgba(91,61,245,.28)}
.hero h1{color:#fff;font-size:1.75rem}
.hero .sub{color:rgba(255,255,255,.85);margin-top:4px}
.hero:before,.hero:after{content:"";position:absolute;border-radius:50%;background:rgba(255,255,255,.14)}
.hero:before{width:220px;height:220px;right:-50px;top:-80px}
.hero:after{width:120px;height:120px;right:150px;bottom:-60px;background:rgba(255,138,91,.35)}
.hero>*{position:relative;z-index:1}

/* menu latéral */
.lk-side{width:256px;flex-shrink:0;background:linear-gradient(180deg,#241B66 0%,#3B2BA8 100%);padding:20px 14px;display:flex;flex-direction:column;gap:6px;position:sticky;top:0;height:100vh;color:#fff;border-radius:0 28px 28px 0}
.lk-brand{display:flex;align-items:center;gap:11px;padding:4px 10px 18px;font-weight:800;font-size:1.4rem;letter-spacing:-.03em;color:#fff}
.lk-navlabel{font-size:.7rem;text-transform:uppercase;letter-spacing:.1em;color:rgba(255,255,255,.45);padding:12px 12px 4px}
.lk-links{display:flex;flex-direction:column;gap:3px;flex:1;overflow-y:auto}
.lk-links a{display:flex;align-items:center;gap:12px;padding:11px 14px;border-radius:99px;color:rgba(255,255,255,.75);font-weight:600;font-size:.92rem;transition:all .18s}
.lk-links a svg{width:19px;height:19px;flex-shrink:0;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.lk-links a:hover{background:rgba(255,255,255,.12);color:#fff;transform:translateX(3px)}
.lk-links a.on{background:#fff;color:var(--brand);box-shadow:0 8px 20px rgba(0,0,0,.22)}
.lk-user{display:flex;align-items:center;gap:10px;padding:10px 12px;background:rgba(255,255,255,.1);border-radius:20px}
.lk-user .who{flex:1;min-width:0}
.lk-user b{display:block;font-size:.88rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lk-user span{font-size:.76rem;color:rgba(255,255,255,.65)}
.nav-logout{background:rgba(255,255,255,.12);border:0;color:#fff;cursor:pointer;padding:8px;min-height:0;border-radius:12px;display:flex}
.nav-logout:hover{background:var(--coral);filter:none}
.nav-logout svg{width:17px;height:17px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}

/* cartes */
.lk-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:20px;display:flex;flex-direction:column;gap:12px;box-shadow:var(--shadow);transition:transform .18s,box-shadow .18s}
.lk-card.lift:hover,a.lk-card:hover{transform:translateY(-3px);box-shadow:0 14px 34px rgba(76,52,200,.14)}
.lk-off{opacity:.55}
.lk-inline{display:flex;flex-wrap:wrap;gap:10px;align-items:center}
.lk-inline input,.lk-inline select{flex:1;min-width:120px}
.lk-label{font-size:.85rem;color:var(--muted);font-weight:600}
.lk-scroll{overflow-x:auto}
.lk-ok{color:var(--green)}.lk-warn{color:var(--amber)}.lk-low{color:var(--red)}
.lk-past{opacity:.5}
.lk-code{font-family:ui-monospace,Menlo,monospace;font-size:1.25rem;letter-spacing:.22em;padding:8px 18px;border-radius:99px;background:var(--brand-soft);border:2px dashed var(--brand);color:var(--brand);font-weight:700}
.lk-details summary{cursor:pointer;color:var(--muted);font-size:.9rem;margin:6px 0;font-weight:600}
.lk-hero{flex-direction:row;align-items:center;flex-wrap:wrap;gap:18px}
.lk-hero .avatar{width:64px;height:64px;font-size:1.3rem}
.lk-bigscore{text-align:center;padding:12px 22px;border-radius:20px;background:var(--teal-soft)}
.lk-bigscore span{display:block;font-size:2.1rem;font-weight:800;color:#0E8F80;line-height:1.1}
.lk-bigscore small{color:#0E8F80}
.lk-grid-box{display:flex;flex-direction:column;gap:12px;padding:14px;border-radius:18px;background:#FAF9FF;border:2px dashed #D4CCFF}
.lk-rows{display:flex;flex-direction:column;gap:8px;max-height:440px;overflow-y:auto;padding-right:4px}
.lk-rowline{display:flex;gap:8px;align-items:center}.lk-rowline input{flex:1;min-width:0}
.lk-num{width:28px;text-align:right;color:#A39FCB;font-size:.82rem;font-weight:600}
.lk-step{display:flex;align-items:center;gap:10px}
.lk-step b{width:28px;height:28px;border-radius:50%;background:var(--grad);color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:.85rem}

input,select,textarea{font:inherit;color:var(--text);background:#fff;border:2px solid var(--line);border-radius:14px;padding:9px 14px;min-height:42px;outline:none;transition:border .15s,box-shadow .15s;width:100%}
input[type=checkbox]{width:auto;min-height:0}
input:focus,select:focus,textarea:focus{border-color:var(--brand);box-shadow:0 0 0 4px rgba(109,74,255,.15)}
button{font:inherit;font-weight:700;cursor:pointer;border:0;border-radius:99px;padding:9px 20px;min-height:42px;background:var(--grad);color:#fff;box-shadow:0 6px 16px rgba(109,74,255,.32);transition:transform .15s,box-shadow .15s,filter .15s}
button:hover{transform:translateY(-2px);box-shadow:0 10px 22px rgba(109,74,255,.4)}
button:active{transform:translateY(0)}
button:disabled{opacity:.5;cursor:not-allowed;transform:none}
.btn-ghost{background:#fff;color:var(--brand);border:2px solid var(--line);box-shadow:none}
.btn-ghost:hover{background:var(--brand-soft);box-shadow:none}
.btn-danger{background:var(--coral-soft);color:var(--red);box-shadow:none}
.btn-danger:hover{background:var(--coral);color:#fff;box-shadow:none}
.btn-small{padding:5px 13px;min-height:0;font-size:.8rem;box-shadow:none}
a.btn-small{display:inline-flex;align-items:center;font-weight:700;background:#fff;color:var(--brand);border:2px solid var(--line);border-radius:99px}
a.btn-small:hover{background:var(--brand-soft)}

.row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 8px;border-bottom:1px solid var(--line);color:var(--text);border-radius:14px;transition:background .15s}
.row:last-child{border-bottom:0}
.row:hover{background:#FAF9FF}
.person{display:flex;align-items:center;gap:10px;font-weight:600;color:var(--text);flex-wrap:wrap}
.actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.avatar{width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,#FF8A5B,#FF5C8A);color:#fff;font-weight:800;display:inline-flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0;box-shadow:0 4px 10px rgba(255,107,107,.35)}
.score{font-weight:800}
.notice{background:var(--amber-soft);color:#8A5A00;border-radius:16px;padding:11px 16px;font-weight:500}
.empty{padding:28px;text-align:center;color:var(--muted);background:rgba(255,255,255,.7);border:2px dashed #CFC6FF;border-radius:var(--radius)}
.tag{display:inline-block;padding:2px 10px;border-radius:99px;font-size:.74rem;font-weight:700;background:var(--brand-soft);color:var(--brand)}
.badge{display:inline-block;padding:3px 12px;border-radius:99px;font-size:.76rem;font-weight:700;background:var(--brand-soft);color:var(--brand)}
.badge.ok{background:var(--green-soft);color:var(--green)}.badge.mid{background:var(--amber-soft);color:#B45309}.badge.bad{background:var(--red-soft);color:var(--red)}

/* cartes statistiques en couleurs */
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px}
.stat{border-radius:24px;padding:18px;display:flex;flex-direction:column;gap:3px;position:relative;overflow:hidden;color:#fff;background:var(--grad);box-shadow:0 14px 28px rgba(109,74,255,.25);transition:transform .2s}
.stat:hover{transform:translateY(-4px) rotate(-.4deg)}
.stat:after{content:"";position:absolute;width:110px;height:110px;border-radius:50%;background:rgba(255,255,255,.16);right:-30px;top:-34px}
.stat small{color:rgba(255,255,255,.85);font-size:.8rem;font-weight:600}
.stat strong{font-size:1.6rem;letter-spacing:-.02em;font-weight:800}
.stat i{font-style:normal;width:42px;height:42px;border-radius:15px;display:flex;align-items:center;justify-content:center;font-size:1.2rem;margin-bottom:8px;background:rgba(255,255,255,.22)}
.stat.c2{background:linear-gradient(135deg,#0EA5A4,#22D3EE);box-shadow:0 14px 28px rgba(14,165,164,.25)}
.stat.c3{background:linear-gradient(135deg,#FF6B6B,#FF9A5B);box-shadow:0 14px 28px rgba(255,107,107,.28)}
.stat.c4{background:linear-gradient(135deg,#F59E0B,#FBBF24);box-shadow:0 14px 28px rgba(245,158,11,.28)}
.stat .lk-ok,.stat .lk-warn,.stat .lk-low{color:#fff}
.bar{height:11px;border-radius:99px;background:#E5E0FF;overflow:hidden}
.bar div{height:100%;background:linear-gradient(90deg,#6D4AFF,#22D3EE);border-radius:99px;transition:width .6s}

.donut{--p:0;width:132px;height:132px;border-radius:50%;background:conic-gradient(#14B8A6 calc(var(--p)*1%),#E5E0FF 0);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.donut span{width:94px;height:94px;border-radius:50%;background:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;font-weight:800;font-size:1.4rem}
.donut small{font-weight:600;font-size:.7rem}
.hbar{display:grid;grid-template-columns:90px 1fr 46px;gap:10px;align-items:center;font-size:.88rem;font-weight:600}
.hbar .track{height:14px;background:#EDE9FF;border-radius:99px;overflow:hidden}
.hbar .fill{height:100%;border-radius:99px;background:linear-gradient(90deg,#14B8A6,#22D3EE)}.hbar .fill.low{background:linear-gradient(90deg,#FF6B6B,#FF9A5B)}
.hbar b{text-align:right}

table.data{width:100%;border-collapse:collapse}
table.data th,table.data td{padding:12px;text-align:left;border-bottom:1px solid var(--line)}
table.data th{font-size:.72rem;text-transform:uppercase;letter-spacing:.07em;color:#A39FCB;font-weight:700}
table.data tbody tr:hover{background:#FAF9FF}
.lk-total td{background:var(--brand-soft);font-weight:700}

.tabs,.chips{display:flex;gap:8px;flex-wrap:wrap}
.tabs{background:rgba(109,74,255,.1);padding:5px;border-radius:99px;width:fit-content}
.tabs button{background:transparent;color:var(--brand);padding:7px 16px;min-height:0;box-shadow:none}
.tabs button:hover{transform:none;box-shadow:none;background:rgba(255,255,255,.6)}
.tabs button.on{background:#fff;box-shadow:0 4px 12px rgba(109,74,255,.2)}
.chips button{background:#fff;color:var(--text);border:2px solid var(--line);padding:7px 15px;min-height:0;font-weight:600;box-shadow:none}
.chips button:hover{border-color:var(--brand);box-shadow:none;transform:translateY(-2px)}
.chips button.on{background:var(--grad);color:#fff;border-color:transparent;box-shadow:0 6px 14px rgba(109,74,255,.3)}
.chips button.coral.on{background:linear-gradient(135deg,#FF6B6B,#FF9A5B);box-shadow:0 6px 14px rgba(255,107,107,.3)}
.chips button.teal.on{background:linear-gradient(135deg,#0EA5A4,#22D3EE);box-shadow:0 6px 14px rgba(14,165,164,.3)}
.chips button.amber.on{background:linear-gradient(135deg,#F59E0B,#FBBF24);box-shadow:0 6px 14px rgba(245,158,11,.3)}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px}
.week{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.day h4{color:var(--muted);text-transform:uppercase;letter-spacing:.07em;font-size:.72rem}
.slot{display:flex;flex-direction:column;gap:2px;padding:10px 14px;border-radius:16px;background:var(--teal-soft);border-left:5px solid var(--teal);position:relative;font-size:.88rem;transition:transform .15s}
.slot:hover{transform:scale(1.02)}
.slot:nth-of-type(3n+2){background:var(--brand-soft);border-left-color:var(--brand)}
.slot:nth-of-type(3n){background:var(--coral-soft);border-left-color:var(--coral)}
.slot button{position:absolute;top:6px;right:6px}

.chip-score{display:inline-block;padding:3px 11px;border-radius:99px;background:var(--brand-soft);font-weight:700;font-size:.82rem;cursor:pointer;border:0;min-height:0;color:var(--brand);box-shadow:none}
.chip-score:hover{background:var(--brand);color:#fff;transform:none;box-shadow:none}
.score-in{max-width:90px;text-align:center;font-weight:800}
.stt{display:flex;gap:6px}
.stt button{background:#fff;color:var(--text);border:2px solid var(--line);box-shadow:none;padding:5px 12px;min-height:0;font-size:.8rem}
.stt button.present.on{background:var(--green);color:#fff;border-color:var(--green)}
.stt button.late.on{background:var(--amber);color:#fff;border-color:var(--amber)}
.stt button.absent.on{background:var(--red);color:#fff;border-color:var(--red)}

/* connexion */
.auth{display:grid;grid-template-columns:1.05fr 1fr;min-height:100vh;position:relative;z-index:1}
.auth-hero{background:linear-gradient(150deg,#3B2BA8 0%,#6D4AFF 55%,#22D3EE 140%);color:#fff;padding:56px;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden}
.auth-hero:before{content:"";position:absolute;width:440px;height:440px;border-radius:50%;background:rgba(255,255,255,.09);right:-140px;top:-110px}
.auth-hero:after{content:"";position:absolute;width:260px;height:260px;border-radius:50%;background:rgba(255,138,91,.35);left:-80px;bottom:-60px}
.auth-hero h1{font-size:2.4rem;line-height:1.12;max-width:440px;position:relative;color:#fff}
.auth-hero p{opacity:.92;max-width:440px;position:relative}
.auth-hero .lk-brand{padding:0;position:relative}
.auth-feats{display:flex;flex-direction:column;gap:10px;position:relative}
.auth-feats span{background:rgba(255,255,255,.16);backdrop-filter:blur(6px);padding:9px 16px;border-radius:99px;width:fit-content;font-size:.9rem;font-weight:600}
.auth-form{display:flex;align-items:center;justify-content:center;padding:32px;background:#fff}
.auth-box{width:100%;max-width:400px;display:flex;flex-direction:column;gap:14px}
.roles{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.roles button{background:#fff;color:var(--text);border:2px solid var(--line);box-shadow:none;border-radius:20px;flex-direction:column;display:flex;align-items:center;gap:2px;padding:12px 6px;font-size:.84rem}
.roles button span{font-size:1.5rem}
.roles button.on{border-color:var(--brand);background:var(--brand-soft);color:var(--brand)}

/* bulletin imprimable */
.bul{background:#fff;color:#111;padding:28px 34px;border:1px solid #ccc;border-radius:6px;font-family:Georgia,"Times New Roman",serif;display:flex;flex-direction:column;gap:12px;page-break-after:always;break-after:page}
.bul .head{display:flex;justify-content:space-between;text-align:center;font-size:.8rem;text-transform:uppercase;gap:10px}
.bul h2{text-align:center;font-size:1.3rem;letter-spacing:.1em;margin:6px 0}
.bul small{color:#444}
.bul table{width:100%;border-collapse:collapse;font-size:.9rem}
.bul th,.bul td{border:1px solid #333;padding:5px 8px;text-align:center}
.bul td:first-child,.bul th:first-child{text-align:left}
.bul .sign{display:flex;justify-content:space-between;margin-top:26px;font-size:.85rem}

@media(max-width:900px){
  .lk-shell{flex-direction:column}
  .lk-side{position:fixed;bottom:0;left:0;right:0;top:auto;width:auto;height:auto;flex-direction:row;padding:6px 8px;z-index:30;border-radius:24px 24px 0 0;box-shadow:0 -6px 20px rgba(36,27,102,.3)}
  .lk-brand,.lk-navlabel,.lk-user .who{display:none}
  .lk-links{flex-direction:row;overflow-x:auto;gap:2px}
  .lk-links a{flex-direction:column;gap:2px;font-size:.64rem;padding:6px 11px;white-space:nowrap;border-radius:16px}
  .lk-user{background:none;padding:0}.lk-user .avatar{display:none}
  .lk-page{padding:18px 14px 100px}
  .auth{grid-template-columns:1fr}.auth-hero{display:none}
}
@media print{
  .lk-side,.no-print{display:none!important}
  body{background:#fff}body:before,body:after{display:none}.lk-page{padding:0;max-width:none}
  .bul{border:0;padding:10mm 8mm}
}

.hero .tabs button{color:#fff}.hero .tabs button.on{color:var(--brand)}
.hero .topbar{align-items:flex-start}
LAKOL_EOF

save "app/layout.tsx"
mkdir -p "$(dirname "app/layout.tsx")"
cat > 'app/layout.tsx' <<'LAKOL_EOF'
import './globals.css';
import NavMenu from './NavMenu';

export const metadata = { title: "Lakol — gestion d'école", description: "Gestion d'école privée" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
      </head>
      <body>
        <div className="lk-shell">
          <NavMenu />
          <main className="lk-main">{children}</main>
        </div>
      </body>
    </html>
  );
}
LAKOL_EOF

save "app/login/page.js"
mkdir -p "$(dirname "app/login/page.js")"
cat > 'app/login/page.js' <<'LAKOL_EOF'
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';
import Logo from '../components/Logo';

const ROLES = [['admin', '🏫', 'Directeur'], ['teacher', '👩‍🏫', 'Professeur'], ['parent', '👨‍👩‍👧', 'Parent']];

export default function Login() {
  const router = useRouter();
  const [mode, setMode] = useState('in');
  const [role, setRole] = useState('admin');
  const [f, setF] = useState({ email: '', password: '', full_name: '', school_name: '', city: '', school_code: '', student_code: '' });
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault(); setErr(''); setBusy(true);
    let res;
    if (mode === 'in') {
      res = await supabase.auth.signInWithPassword({ email: f.email.trim(), password: f.password });
    } else {
      res = await supabase.auth.signUp({
        email: f.email.trim(), password: f.password,
        options: { data: { role, full_name: f.full_name, school_name: f.school_name, city: f.city, school_code: f.school_code, student_code: f.student_code } },
      });
    }
    setBusy(false);
    if (res.error) {
      const m = res.error.message || '';
      if (/already registered/i.test(m)) setErr('Cet email a déjà un compte. Clique sur « Se connecter ».');
      else if (/Invalid login/i.test(m)) setErr('Email ou mot de passe incorrect.');
      else if (/Database error/i.test(m)) setErr("Code invalide. Vérifie le code de l'école (professeur) ou le code de l'élève (parent).");
      else if (/at least 6/i.test(m)) setErr('Le mot de passe doit avoir au moins 6 caractères.');
      else setErr(m);
      return;
    }
    if (!res.data.session) { setErr('Compte créé. Confirme ton email puis connecte-toi.'); setMode('in'); return; }
    router.replace('/');
  }

  return (
    <div className="auth">
      <div className="auth-hero">
        <div className="lk-brand"><Logo size={42} id="lgl" />Lakol</div>
        <div className="lk-stack">
          <h1>La gestion de ton école, simple et moderne.</h1>
          <p>Notes, bulletins, scolarité, emplois du temps : tout au même endroit, pour le directeur, les professeurs et les parents.</p>
          <div className="auth-feats"><span>✓ Notes et bulletins en quelques clics</span><span>✓ Suivi de la scolarité en FCFA</span><span>✓ Devoirs, présence et comportement</span></div>
        </div>
        <span />
      </div>
      <div className="auth-form">
        <form className="auth-box" onSubmit={submit}>
          <h1>{mode === 'in' ? 'Bon retour 👋' : 'Créer un compte'}</h1>
          <p className="meta" style={{ margin: 0 }}>{mode === 'in' ? 'Connecte-toi pour continuer.' : 'Choisis ton profil.'}</p>
          {mode === 'up' && (
            <>
              <div className="roles">
                {ROLES.map(([k, ic, l]) => <button type="button" key={k} className={role === k ? 'on' : ''} onClick={() => setRole(k)}><span>{ic}</span>{l}</button>)}
              </div>
              <input placeholder="Ton nom complet" value={f.full_name} onChange={set('full_name')} required />
              {role === 'admin' && <><input placeholder="Nom de l'école" value={f.school_name} onChange={set('school_name')} required /><input placeholder="Ville" value={f.city} onChange={set('city')} /></>}
              {role === 'teacher' && <input placeholder="Code de l'école (donné par le directeur)" value={f.school_code} onChange={set('school_code')} required />}
              {role === 'parent' && <input placeholder="Code de l'élève (donné par l'école)" value={f.student_code} onChange={set('student_code')} required />}
            </>
          )}
          <input type="email" placeholder="Email" value={f.email} onChange={set('email')} required />
          <input type="password" placeholder="Mot de passe (6 caractères min.)" value={f.password} onChange={set('password')} required />
          {err && <div className="notice">{err}</div>}
          <button disabled={busy}>{busy ? '…' : mode === 'in' ? 'Se connecter' : 'Créer mon compte'}</button>
          <button type="button" className="btn-ghost" onClick={() => { setMode(mode === 'in' ? 'up' : 'in'); setErr(''); }}>
            {mode === 'in' ? 'Pas encore de compte ? Créer un compte' : "J'ai déjà un compte"}
          </button>
        </form>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/notes/page.js"
mkdir -p "$(dirname "app/notes/page.js")"
cat > 'app/notes/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fmt } from '../../lib/grades';

export default function Notes() {
  const { profile, status } = useProfile(['teacher']);
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
LAKOL_EOF

save "app/page.js"
mkdir -p "$(dirname "app/page.js")"
cat > 'app/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../lib/supabase';
import { Blocked } from '../lib/useProfile';

export default function Home() {
  const router = useRouter();
  const [blocked, setBlocked] = useState(false);
  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) return router.replace('/login');
      const { data: p } = await supabase.from('profiles').select('role, active').eq('id', data.session.user.id).maybeSingle();
      if (!p || p.active === false) return setBlocked(true);
      router.replace(p.role === 'admin' ? '/dashboard' : p.role === 'teacher' ? '/classes' : '/parent');
    })();
  }, []);
  if (blocked) return <Blocked />;
  return <div className="lk-page"><p className="meta">Chargement…</p></div>;
}
LAKOL_EOF

save "app/paiements/page.js"
mkdir -p "$(dirname "app/paiements/page.js")"
cat > 'app/paiements/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, METHODS } from '../../lib/grades';

export default function Paiements() {
  const { profile, status } = useProfile(['admin']);
  const [tab, setTab] = useState('eleves');
  const [rows, setRows] = useState([]);
  const [classes, setClasses] = useState([]);
  const [fees, setFees] = useState([]);
  const [filter, setFilter] = useState('tous');
  const [classId, setClassId] = useState('');
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(null);
  const [hist, setHist] = useState([]);
  const [form, setForm] = useState({ amount: '', method: 'cash', fee_id: '' });
  const [fee, setFee] = useState({ label: '', amount: '', all: true, targets: [] });
  const [err, setErr] = useState('');

  async function load() {
    const [b, c, f] = await Promise.all([
      supabase.rpc('student_balances'),
      supabase.from('classes').select('id, name').order('name'),
      supabase.from('fees').select('id, class_id, label, amount').order('label'),
    ]);
    if (b.error) setErr(b.error.message);
    setRows(b.data || []); setClasses(c.data || []); setFees(f.data || []);
    if (!classId && c.data?.length) setClassId(c.data[0].id);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function openStudent(s) {
    if (open?.student_id === s.student_id) { setOpen(null); return; }
    setOpen(s);
    setForm({ amount: String(Math.max(0, s.due - s.paid) || ''), method: 'cash', fee_id: '' });
    const { data } = await supabase.from('payments').select('id, amount, method, paid_at').eq('student_id', s.student_id).order('paid_at', { ascending: false });
    setHist(data || []);
  }
  async function addPayment(e) {
    e.preventDefault(); setErr('');
    const amount = parseInt(form.amount, 10);
    if (!amount) return;
    const { error } = await supabase.from('payments').insert({
      school_id: profile.school_id, student_id: open.student_id, amount, method: form.method, fee_id: form.fee_id || null,
    });
    if (error) return setErr(error.message);
    const s = open; setOpen(null); await load(); openStudent({ ...s, paid: s.paid + amount });
  }
  async function delPayment(id) {
    if (!confirm('Supprimer ce paiement ?')) return;
    await supabase.from('payments').delete().eq('id', id);
    const s = open; setOpen(null); await load();
    const r = (await supabase.rpc('student_balances')).data?.find((x) => x.student_id === s.student_id);
    if (r) openStudent(r);
  }

  async function addFee(e) {
    e.preventDefault(); setErr('');
    const amount = parseInt(fee.amount, 10);
    if (!fee.label.trim() || !amount) return;
    if (!fee.all && fee.targets.length === 0) return setErr('Choisis au moins une classe.');
    const targets = fee.all ? [null] : fee.targets;
    const { error } = await supabase.from('fees').insert(targets.map((id) => ({ school_id: profile.school_id, class_id: id, label: fee.label.trim(), amount })));
    if (error) return setErr(error.message);
    setFee({ label: '', amount: '', all: true, targets: [] }); load();
  }
  async function editFee(f) {
    const v = prompt(`Nouveau montant pour « ${f.label} » (FCFA)`, f.amount);
    const n = parseInt(v, 10);
    if (!n) return;
    await supabase.from('fees').update({ amount: n }).eq('id', f.id); load();
  }
  async function delFee(f) {
    if (!confirm(`Supprimer le frais « ${f.label} » ?`)) return;
    await supabase.from('fees').delete().eq('id', f.id); load();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const state = (r) => (r.due === 0 ? ['Aucun frais', ''] : r.paid >= r.due ? ['Soldé', 'ok'] : r.paid > 0 ? ['Partiel', 'mid'] : ['Impayé', 'bad']);
  const shown = rows.filter((r) => {
    const s = state(r)[0];
    if (filter === 'impayes' && s !== 'Impayé') return false;
    if (filter === 'partiels' && s !== 'Partiel') return false;
    if (filter === 'soldes' && s !== 'Soldé') return false;
    if (classId && tab === 'eleves' && classId !== 'all' && r.class_id !== classId) return false;
    return `${r.first_name} ${r.last_name}`.toLowerCase().includes(q.toLowerCase());
  });
  const totDue = shown.reduce((s, r) => s + Number(r.due), 0);
  const totPaid = shown.reduce((s, r) => s + Number(r.paid), 0);

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Scolarité</h1>
        <div className="tabs">
          <button className={tab === 'eleves' ? 'on' : ''} onClick={() => setTab('eleves')}>Élèves</button>
          <button className={tab === 'frais' ? 'on' : ''} onClick={() => setTab('frais')}>Frais par classe</button>
        </div>
      </div>
      {err && <div className="notice">{err}</div>}

      {tab === 'eleves' && (
        <>
          <div className="lk-inline">
            <input placeholder="Rechercher un élève…" value={q} onChange={(e) => setQ(e.target.value)} />
            <select value={classId} onChange={(e) => setClassId(e.target.value)}>
              <option value="all">Toutes les classes</option>
              {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div className="chips">
            {[['tous', 'Tous'], ['impayes', 'Impayés'], ['partiels', 'Partiels'], ['soldes', 'Soldés']].map(([k, l]) => (
              <button key={k} className={filter === k ? 'on' : ''} onClick={() => setFilter(k)}>{l}</button>
            ))}
          </div>
          <div className="meta">Encaissé : <strong>{fcfa(totPaid)}</strong> sur {fcfa(totDue)} · reste {fcfa(Math.max(0, totDue - totPaid))}</div>
          {shown.length === 0 && <div className="empty">Aucun élève ne correspond.</div>}
          {shown.map((r) => {
            const [label, cls] = state(r);
            return (
              <div className="lk-card" key={r.student_id}>
                <div className="lk-inline" style={{ justifyContent: 'space-between', cursor: 'pointer' }} onClick={() => openStudent(r)}>
                  <div className="person">{r.first_name} {r.last_name} <span className="tag">{r.class_name}</span></div>
                  <div><span className="meta">{fcfa(r.paid)} / {fcfa(r.due)}</span> <span className={'badge ' + cls}>{label}</span></div>
                </div>
                {open?.student_id === r.student_id && (
                  <>
                    <form className="lk-inline" onSubmit={addPayment}>
                      <input type="number" min="1" placeholder="Montant" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} style={{ maxWidth: 140 }} />
                      <select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
                        {Object.entries(METHODS).filter(([k]) => k !== 'virement').map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </select>
                      <select value={form.fee_id} onChange={(e) => setForm({ ...form, fee_id: e.target.value })}>
                        <option value="">Frais (facultatif)</option>
                        {fees.filter((f) => f.class_id === r.class_id || f.class_id === null).map((f) => <option key={f.id} value={f.id}>{f.label}</option>)}
                      </select>
                      <button>Encaisser</button>
                    </form>
                    {hist.map((p) => (
                      <div className="row" key={p.id}>
                        <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span></div>
                        <span>{fcfa(p.amount)} <button className="btn-small btn-danger" onClick={() => delPayment(p.id)}>✕</button></span>
                      </div>
                    ))}
                  </>
                )}
              </div>
            );
          })}
        </>
      )}

      {tab === 'frais' && (
        <>
          <div className="lk-card">
            <h3>🏫 Frais pour toute l'école</h3>
            <span className="meta">S'appliquent automatiquement à chaque élève, même dans les classes créées plus tard.</span>
            {fees.filter((f) => f.class_id === null).length === 0 && <span className="meta">Aucun frais général pour le moment.</span>}
            {fees.filter((f) => f.class_id === null).map((f) => (
              <div className="row" key={f.id}>
                <div className="person">{f.label}</div>
                <span>{fcfa(f.amount)} <button className="btn-small btn-ghost" onClick={() => editFee(f)}>Modifier</button> <button className="btn-small btn-danger" onClick={() => delFee(f)}>✕</button></span>
              </div>
            ))}
          </div>

          <div className="lk-card">
            <h3>🎯 Frais spécifiques à une classe</h3>
            {classes.filter((c) => fees.some((f) => f.class_id === c.id)).length === 0 && <span className="meta">Aucun frais spécifique pour le moment.</span>}
            {classes.filter((c) => fees.some((f) => f.class_id === c.id)).map((c) => (
              <div key={c.id}>
                <span className="tag">{c.name}</span>
                {fees.filter((f) => f.class_id === c.id).map((f) => (
                  <div className="row" key={f.id}>
                    <div className="person">{f.label}</div>
                    <span>{fcfa(f.amount)} <button className="btn-small btn-ghost" onClick={() => editFee(f)}>Modifier</button> <button className="btn-small btn-danger" onClick={() => delFee(f)}>✕</button></span>
                  </div>
                ))}
              </div>
            ))}
          </div>

          <form className="lk-card" onSubmit={addFee}>
            <h3>Ajouter un frais</h3>
            <div className="lk-inline">
              <input placeholder="Nom (ex. Scolarité, Inscription, Uniforme)" value={fee.label} onChange={(e) => setFee({ ...fee, label: e.target.value })} />
              <input type="number" min="1" placeholder="Montant FCFA" value={fee.amount} onChange={(e) => setFee({ ...fee, amount: e.target.value })} style={{ maxWidth: 170 }} />
            </div>
            <div className="chips">
              <button type="button" className={fee.all ? 'on' : ''} onClick={() => setFee({ ...fee, all: true })}>🏫 Toute l'école</button>
              {classes.map((c) => (
                <button type="button" key={c.id} className={!fee.all && fee.targets.includes(c.id) ? 'on' : ''}
                  onClick={() => setFee({ ...fee, all: false, targets: fee.targets.includes(c.id) ? fee.targets.filter((x) => x !== c.id) : [...fee.targets, c.id] })}>{c.name}</button>
              ))}
            </div>
            <div><button>Ajouter le frais</button></div>
          </form>
        </>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/parent/page.js"
mkdir -p "$(dirname "app/parent/page.js")"
cat > 'app/parent/page.js' <<'LAKOL_EOF'
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
    if (error) setMsg(error.message); else { setCode(''); setMsg('Enfant ajouté ✓'); load(); }
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
LAKOL_EOF

save "app/planning/page.js"
mkdir -p "$(dirname "app/planning/page.js")"
cat > 'app/planning/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const DAYS = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const KINDS = { devoir: 'Devoir', examen: 'Examen', composition: 'Composition' };
const hm = (t) => (t || '').slice(0, 5);
const today = () => new Date().toISOString().slice(0, 10);

export default function Planning() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [classId, setClassId] = useState('');
  const [tab, setTab] = useState('edt');
  const [slots, setSlots] = useState([]);
  const [todo, setTodo] = useState([]);
  const [slot, setSlot] = useState({ day: '1', start: '08:00', end: '09:00', subject_id: '', room: '' });
  const [a, setA] = useState({ kind: 'devoir', subject_id: '', title: '', due_date: today(), chapters: '' });
  const [plans, setPlans] = useState([]);
  const [err, setErr] = useState('');
  const canEdit = profile?.role !== 'parent';

  useEffect(() => {
    if (status !== 'ok') return;
    (async () => {
      const [c, s] = await Promise.all([
        supabase.from('classes').select('id, name').order('name'),
        supabase.from('subjects').select('id, name').order('name'),
      ]);
      setClasses(c.data || []); setSubjects(s.data || []);
      if (c.data?.length) setClassId(c.data[0].id);
    })();
  }, [status]);

  async function load() {
    if (!classId) return;
    if (profile.role !== 'parent') {
      const { data: pl } = await supabase.from('teaching').select('devoirs_per_term, compositions_per_term, subjects(name)').eq('class_id', classId);
      setPlans(pl || []);
    }
    const [t, d] = await Promise.all([
      supabase.from('timetable').select('id, day, start_time, end_time, room, subjects(name)').eq('class_id', classId).order('start_time'),
      supabase.from('assignments').select('id, kind, title, due_date, chapters, subjects(name)').eq('class_id', classId).order('due_date'),
    ]);
    setSlots(t.data || []); setTodo(d.data || []);
    const e = t.error || d.error;
    setErr(e ? (/assignments|schema cache|does not exist/i.test(e.message) ? "La migration 2 n'est pas encore lancée dans Supabase (table des devoirs manquante)." : e.message) : '');
  }
  useEffect(() => { load(); }, [classId]);

  async function addSlot(e) {
    e.preventDefault(); setErr('');
    if (slot.end <= slot.start) return setErr("L'heure de fin doit être après le début.");
    const day = Number(slot.day);
    const clash = slots.find((s) => s.day === day && hm(s.start_time) < slot.end && hm(s.end_time) > slot.start);
    if (clash) return setErr(`Ce créneau chevauche ${clash.subjects?.name || 'un autre cours'} (${hm(clash.start_time)}–${hm(clash.end_time)}).`);
    const { error } = await supabase.from('timetable').insert({
      school_id: profile.school_id, class_id: classId, day, start_time: slot.start, end_time: slot.end,
      subject_id: slot.subject_id || null, teacher_id: profile.role === 'teacher' ? profile.id : null, room: slot.room || null,
    });
    if (error) setErr(error.message); else { setSlot({ ...slot, start: slot.end, end: slot.end, room: '' }); load(); }
  }
  async function addAssignment(e) {
    e.preventDefault(); setErr('');
    if (!a.title.trim()) return;
    const { error } = await supabase.from('assignments').insert({
      school_id: profile.school_id, class_id: classId, kind: a.kind, subject_id: a.subject_id || null,
      title: a.title.trim(), due_date: a.due_date, chapters: a.chapters.trim() || null, created_by: profile.id,
    });
    if (error) setErr(error.message); else { setA({ ...a, title: '', chapters: '' }); load(); }
  }
  const del = async (table, id) => { await supabase.from(table).delete().eq('id', id); load(); };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const upcoming = todo.filter((x) => x.due_date >= today());
  const past = todo.filter((x) => x.due_date < today()).reverse();
  const inDays = (d) => { const n = Math.round((new Date(d) - new Date(today())) / 864e5); return n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} jours`; };
  const item = (x, isPast) => (
    <div className={'row' + (isPast ? ' lk-past' : '')} key={x.id}>
      <div className="person">
        <span className={'badge ' + (x.kind === 'devoir' ? 'mid' : 'bad')}>{KINDS[x.kind]}</span> {x.title}
        {x.subjects?.name && <span className="tag">{x.subjects.name}</span>}
        {x.chapters && <span className="meta">Chapitres : {x.chapters}</span>}
      </div>
      <span>{new Date(x.due_date).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })}{!isPast && <small className="meta"> · {inDays(x.due_date)}</small>}
        {canEdit && <> <button className="btn-small btn-danger" onClick={() => del('assignments', x.id)}>✕</button></>}</span>
    </div>
  );

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Planning</h1>
        <select value={classId} onChange={(e) => setClassId(e.target.value)} style={{ maxWidth: 220 }}>
          {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>
      {classes.length === 0 && <div className="empty">Aucune classe pour le moment. {profile.role !== 'parent' && <a href="/classes">Crée une classe →</a>}</div>}
      {err && <div className="notice">{err}</div>}
      {classId && (
        <>
          <div className="tabs">
            <button className={tab === 'edt' ? 'on' : ''} onClick={() => setTab('edt')}>Emploi du temps</button>
            <button className={tab === 'dev' ? 'on' : ''} onClick={() => setTab('dev')}>Devoirs &amp; examens {upcoming.length > 0 && <small>({upcoming.length})</small>}</button>
          </div>

          {tab === 'edt' && (
            <>
              {canEdit && (
                <form className="lk-card lk-inline" onSubmit={addSlot}>
                  <select value={slot.day} onChange={(e) => setSlot({ ...slot, day: e.target.value })}>
                    {DAYS.slice(1).map((d, i) => <option key={d} value={i + 1}>{d}</option>)}
                  </select>
                  <input type="time" value={slot.start} onChange={(e) => setSlot({ ...slot, start: e.target.value })} />
                  <span className="meta">à</span>
                  <input type="time" value={slot.end} onChange={(e) => setSlot({ ...slot, end: e.target.value })} />
                  <select value={slot.subject_id} onChange={(e) => setSlot({ ...slot, subject_id: e.target.value })}>
                    <option value="">Matière</option>
                    {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                  <input placeholder="Salle" value={slot.room} onChange={(e) => setSlot({ ...slot, room: e.target.value })} style={{ maxWidth: 100 }} />
                  <button>Ajouter</button>
                </form>
              )}
              <div className="week">
                {DAYS.slice(1).map((d, i) => {
                  const list = slots.filter((s) => s.day === i + 1);
                  return (
                    <div className="lk-card day" key={d}>
                      <h4>{d}</h4>
                      {list.length === 0 && <span className="meta">—</span>}
                      {list.map((s) => (
                        <div className="slot" key={s.id}>
                          <strong>{hm(s.start_time)}–{hm(s.end_time)}</strong>
                          <span>{s.subjects?.name || 'Cours'}{s.room ? ` · ${s.room}` : ''}</span>
                          {canEdit && <button className="btn-small btn-danger" onClick={() => del('timetable', s.id)}>✕</button>}
                        </div>
                      ))}
                    </div>
                  );
                })}
              </div>
            </>
          )}

          {tab === 'dev' && (
            <>
              {canEdit && (
                <form className="lk-card lk-inline" onSubmit={addAssignment}>
                  <select value={a.kind} onChange={(e) => setA({ ...a, kind: e.target.value })}>
                    {Object.entries(KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                  <select value={a.subject_id} onChange={(e) => setA({ ...a, subject_id: e.target.value })}>
                    <option value="">Matière</option>
                    {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                  <input placeholder="Sujet (ex. Exercices p.42)" value={a.title} onChange={(e) => setA({ ...a, title: e.target.value })} />
                  <input placeholder="Chapitres (facultatif, ex. 1, 2 et 3)" value={a.chapters} onChange={(e) => setA({ ...a, chapters: e.target.value })} />
                  <input type="date" value={a.due_date} onChange={(e) => setA({ ...a, due_date: e.target.value })} />
                  <button>Publier</button>
                </form>
              )}
              {plans.length > 0 && (
                <div className="lk-card">
                  <h4>Programme prévu par trimestre</h4>
                  {plans.map((p, i) => <div className="row" key={i}><div className="person">{p.subjects?.name}</div><span className="meta">{p.devoirs_per_term} devoir(s) · {p.compositions_per_term} composition(s)</span></div>)}
                </div>
              )}
              <h3>À venir</h3>
              {upcoming.length === 0 ? <div className="empty">Rien de prévu.</div> : upcoming.map((x) => item(x, false))}
              {past.length > 0 && <details className="lk-details"><summary>Passés ({past.length})</summary>{past.map((x) => item(x, true))}</details>}
            </>
          )}
        </>
      )}
    </div>
  );
}
LAKOL_EOF

save "app/professeurs/page.js"
mkdir -p "$(dirname "app/professeurs/page.js")"
cat > 'app/professeurs/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, METHODS } from '../../lib/grades';

const thisMonth = () => new Date().toISOString().slice(0, 7);

export default function Professeurs() {
  const { profile, status } = useProfile(['admin']);
  const [month, setMonth] = useState(thisMonth());
  const [teachers, setTeachers] = useState([]);
  const [teaching, setTeaching] = useState([]);
  const [pay, setPay] = useState({});       // teacher_id -> salaire mensuel
  const [paid, setPaid] = useState([]);     // paiements du mois
  const [code, setCode] = useState('');
  const [open, setOpen] = useState(null);   // prof dont le formulaire de paiement est ouvert
  const [form, setForm] = useState({ amount: '', method: 'cash', note: '' });
  const [err, setErr] = useState('');

  async function load() {
    const [t, tc, sp, sal, sc] = await Promise.all([
      supabase.from('profiles').select('id, full_name, email, active').eq('role', 'teacher').order('full_name'),
      supabase.from('teaching').select('teacher_id, classes(name), subjects(name)'),
      supabase.from('staff_pay').select('teacher_id, monthly_salary'),
      supabase.from('salary_payments').select('id, teacher_id, amount, method, note, paid_at').eq('month', month).order('paid_at', { ascending: false }),
      supabase.from('school_secrets').select('join_code').maybeSingle(),
    ]);
    setTeachers(t.data || []);
    setTeaching(tc.data || []);
    setPay(Object.fromEntries((sp.data || []).map((x) => [x.teacher_id, x.monthly_salary])));
    setPaid(sal.data || []);
    setCode(sc.data?.join_code || '');
  }
  useEffect(() => { if (status === 'ok') load(); }, [status, month]);

  async function saveSalary(id, value) {
    setErr('');
    const n = Math.max(0, parseInt(value, 10) || 0);
    const { error } = await supabase.from('staff_pay').upsert({ teacher_id: id, school_id: profile.school_id, monthly_salary: n });
    if (error) setErr(error.message); else load();
  }
  async function submitPay(e, t) {
    e.preventDefault(); setErr('');
    const amount = parseInt(form.amount, 10);
    if (!amount) return;
    const { error } = await supabase.from('salary_payments').insert({
      school_id: profile.school_id, teacher_id: t.id, month, amount, method: form.method,
      note: form.note || null, created_by: profile.id,
    });
    if (error) return setErr(error.message);
    setOpen(null); setForm({ amount: '', method: 'cash', note: '' }); load();
  }
  async function delPay(id) {
    if (!confirm('Supprimer ce paiement de salaire ?')) return;
    await supabase.from('salary_payments').delete().eq('id', id); load();
  }
  async function toggle(t) {
    if (t.active && !confirm(`Désactiver ${t.full_name} ? Il/elle ne pourra plus se connecter aux données de l'école.`)) return;
    await supabase.from('profiles').update({ active: !t.active }).eq('id', t.id); load();
  }
  async function regen() {
    if (!confirm('Générer un nouveau code ? L\'ancien ne fonctionnera plus pour les nouvelles inscriptions.')) return;
    const { data, error } = await supabase.rpc('regenerate_join_code');
    if (error) setErr(error.message); else setCode(data);
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const totalSalaries = teachers.filter((t) => t.active).reduce((s, t) => s + (pay[t.id] || 0), 0);
  const totalPaid = paid.reduce((s, p) => s + p.amount, 0);

  return (
    <div className="lk-page">
      <div className="topbar">
        <h1>Professeurs</h1>
        <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} style={{ maxWidth: 170 }} />
      </div>
      {err && <div className="notice">{err}</div>}
      <div className="stats">
        <div className="stat"><small>Professeurs actifs</small><strong>{teachers.filter((t) => t.active).length}</strong></div>
        <div className="stat"><small>Masse salariale / mois</small><strong>{fcfa(totalSalaries)}</strong></div>
        <div className="stat"><small>Versé en {month}</small><strong className="lk-ok">{fcfa(totalPaid)}</strong></div>
        <div className="stat"><small>Reste à verser</small><strong className="lk-warn">{fcfa(Math.max(0, totalSalaries - totalPaid))}</strong></div>
      </div>

      {teachers.length === 0 && (
        <div className="empty">Aucun professeur pour l'instant. Donne-leur le code de l'école ci-dessous : ils s'inscrivent eux-mêmes.</div>
      )}

      {teachers.map((t) => {
        const mine = teaching.filter((x) => x.teacher_id === t.id);
        const classes = [...new Set(mine.map((x) => x.classes?.name).filter(Boolean))];
        const subjects = [...new Set(mine.map((x) => x.subjects?.name).filter(Boolean))];
        const myPaid = paid.filter((p) => p.teacher_id === t.id);
        const sum = myPaid.reduce((s, p) => s + p.amount, 0);
        const salary = pay[t.id] || 0;
        const st = !salary ? null : sum >= salary ? ['Payé', 'ok'] : sum > 0 ? ['Partiel', 'mid'] : ['À payer', 'bad'];
        return (
          <div className={'lk-card' + (t.active ? '' : ' lk-off')} key={t.id}>
            <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
              <div>
                <h3 style={{ margin: 0 }}>{t.full_name} {!t.active && <span className="badge bad">Désactivé</span>}</h3>
                <span className="meta">{t.email}</span>
              </div>
              {st && <span className={'badge ' + st[1]}>{st[0]}</span>}
            </div>
            <div className="meta">
              {classes.length ? <>Classes : {classes.join(', ')} · Matières : {subjects.join(', ')}</> : 'Aucune classe pour le moment'}
            </div>
            <div className="lk-inline">
              <label className="lk-label">Salaire mensuel (FCFA)</label>
              <input type="number" min="0" defaultValue={salary} key={salary} style={{ maxWidth: 160 }}
                onBlur={(e) => { if (Number(e.target.value) !== salary) saveSalary(t.id, e.target.value); }} />
              <span className="meta">Versé : {fcfa(sum)}</span>
              <button className="btn-small" onClick={() => { setOpen(open === t.id ? null : t.id); setForm({ amount: String(Math.max(0, salary - sum) || ''), method: 'cash', note: '' }); }}>Payer le salaire</button>
              <button className="btn-ghost btn-small" onClick={() => toggle(t)}>{t.active ? 'Désactiver' : 'Réactiver'}</button>
            </div>
            {open === t.id && (
              <form className="lk-inline" onSubmit={(e) => submitPay(e, t)}>
                <input type="number" min="1" placeholder="Montant" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} style={{ maxWidth: 140 }} />
                <select value={form.method} onChange={(e) => setForm({ ...form, method: e.target.value })}>
                  {Object.entries(METHODS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
                <input placeholder="Note (facultatif)" value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
                <button>Enregistrer</button>
              </form>
            )}
            {myPaid.map((p) => (
              <div className="row" key={p.id}>
                <div className="person">{new Date(p.paid_at).toLocaleDateString('fr-FR')} <span className="tag">{METHODS[p.method] || p.method}</span> {p.note && <span className="meta">{p.note}</span>}</div>
                <span>{fcfa(p.amount)} <button className="btn-small btn-danger" onClick={() => delPay(p.id)}>✕</button></span>
              </div>
            ))}
          </div>
        );
      })}

      <div className="lk-card lk-inline">
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0 }}>Code de l'école</h3>
          <span className="meta">À donner aux nouveaux professeurs.</span>
        </div>
        <code className="lk-code">{code}</code>
        <button className="btn-ghost" onClick={regen}>Nouveau code</button>
      </div>
    </div>
  );
}
LAKOL_EOF

save "app/vie-scolaire/page.js"
mkdir -p "$(dirname "app/vie-scolaire/page.js")"
cat > 'app/vie-scolaire/page.js' <<'LAKOL_EOF'
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
LAKOL_EOF

save "lib/grades.js"
mkdir -p "$(dirname "lib/grades.js")"
cat > 'lib/grades.js' <<'LAKOL_EOF'
export const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);

// Moyenne d'une matière = (moyenne des devoirs + composition) / 2
export function subjectAvg(grades) {
  const d = grades.filter((g) => g.kind === 'devoir').map((g) => Number(g.score));
  const c = grades.filter((g) => g.kind === 'composition').map((g) => Number(g.score));
  if (d.length && c.length) return (mean(d) + mean(c)) / 2;
  return mean([...d, ...c].map(Number));
}

// rows : [{ avg, coef }]  -> moyenne générale pondérée
export function generalAvg(rows) {
  const ok = rows.filter((r) => r.avg != null);
  const total = ok.reduce((s, r) => s + Number(r.coef), 0);
  if (!total) return null;
  return ok.reduce((s, r) => s + r.avg * Number(r.coef), 0) / total;
}

export function appreciation(avg) {
  if (avg == null) return '';
  if (avg >= 16) return 'Très bien';
  if (avg >= 14) return 'Bien';
  if (avg >= 12) return 'Assez bien';
  if (avg >= 10) return 'Passable';
  return 'Insuffisant';
}

export const fmt = (n) => (n == null ? '–' : Number(n).toFixed(2).replace('.', ','));
export const fcfa = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} F`;
export const METHODS = { moov: 'Moov Money', airtel: 'Airtel Money', orange: 'Orange Money', nita: 'NITA', cash: 'Espèces', virement: 'Virement' };
LAKOL_EOF

save "lib/kinds.js"
mkdir -p "$(dirname "lib/kinds.js")"
cat > 'lib/kinds.js' <<'LAKOL_EOF'
export const KINDS = {
  bavardage: ['Bavardage', '💬'], perturbation: ['Perturbation', '⚡'], retard: ['Retard', '⏰'],
  oubli_materiel: ['Oubli de matériel', '🎒'], insolence: ['Insolence', '😤'], positif: ['Félicitations', '🌟'], autre: ['Autre', '📝'],
};
LAKOL_EOF

save "lib/supabase.js"
mkdir -p "$(dirname "lib/supabase.js")"
cat > 'lib/supabase.js' <<'LAKOL_EOF'
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
);
export default supabase;
LAKOL_EOF

save "lib/useProfile.js"
mkdir -p "$(dirname "lib/useProfile.js")"
cat > 'lib/useProfile.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from './supabase';

// Charge le profil connecté. allowed = liste des rôles autorisés sur la page.
export function useProfile(allowed) {
  const router = useRouter();
  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState('loading');

  useEffect(() => {
    let alive = true;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { router.replace('/login'); return; }
      const { data: p } = await supabase
        .from('profiles')
        .select('id, full_name, role, school_id, active, email')
        .eq('id', data.session.user.id)
        .maybeSingle();
      if (!alive) return;
      if (!p || p.active === false) { setStatus('blocked'); return; }
      if (allowed && !allowed.includes(p.role)) { router.replace('/'); return; }
      setProfile(p);
      setStatus('ok');
    })();
    return () => { alive = false; };
  }, []);

  return { profile, status };
}

export function Blocked() {
  return (
    <div className="lk-page"><div className="lk-card">
      <h2>Compte inactif</h2>
      <p className="meta">Ton compte est introuvable ou a été désactivé par le directeur de l'école.</p>
      <button className="btn-ghost" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>Se déconnecter</button>
    </div></div>
  );
}
LAKOL_EOF

echo "✅ Lakol v3 installé ($(ls app | wc -l | tr -d " ") éléments dans app). Anciennes versions dans $B"
echo "Maintenant : arrête le serveur (Ctrl+C) puis lance : npm run dev"
