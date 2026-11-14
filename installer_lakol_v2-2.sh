#!/bin/bash
# Lakol v2 (design moderne + rôles). À lancer depuis le dossier ecole-app.
set -e
if [ ! -f package.json ] || [ ! -d app ]; then echo "❌ Lance ce script depuis le dossier ecole-app (celui qui contient package.json et app)."; exit 1; fi
B="_sauvegarde_avant_v2"; mkdir -p "$B"
save(){ if [ -f "$1" ] && [ ! -f "$B/$1" ]; then mkdir -p "$B/$(dirname "$1")"; cp "$1" "$B/$1"; fi; }

save "app/NavMenu.tsx"
mkdir -p "$(dirname "app/NavMenu.tsx")"
cat > 'app/NavMenu.tsx' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { supabase } from '../lib/supabase';

type Item = [string, string, string];
const MENUS: Record<string, Item[]> = {
  admin: [
    ['/dashboard', 'Tableau de bord', 'grid'], ['/classes', 'Classes', 'book'], ['/eleves', 'Élèves', 'user'],
    ['/professeurs', 'Professeurs', 'users'], ['/planning', 'Planning', 'calendar'], ['/notes', 'Notes', 'edit'],
    ['/bulletin', 'Bulletins', 'file'], ['/paiements', 'Scolarité', 'card'],
  ],
  teacher: [['/classes', 'Mes classes', 'book'], ['/eleves', 'Élèves', 'user'], ['/notes', 'Notes', 'edit'], ['/planning', 'Planning', 'calendar']],
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
      <Link href="/" className="lk-brand"><span className="lk-logo" />Lakol</Link>
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
LAKOL_EOF

save "app/components/StudentFile.js"
mkdir -p "$(dirname "app/components/StudentFile.js")"
cat > 'app/components/StudentFile.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { subjectAvg, generalAvg, appreciation, fmt, fcfa, METHODS } from '../../lib/grades';

// Fiche élève. role = 'admin' | 'teacher' | 'parent'.
// La scolarité (frais, paiements) n'est affichée qu'au directeur et aux parents.
export default function StudentFile({ studentId, role }) {
  const [student, setStudent] = useState(null);
  const [grades, setGrades] = useState([]);
  const [fees, setFees] = useState([]);
  const [payments, setPayments] = useState([]);
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
      if (showMoney && s) {
        const [f, p] = await Promise.all([
          s.class_id ? supabase.from('fees').select('id, label, amount').eq('class_id', s.class_id) : { data: [] },
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
      <div className="topbar">
        <div><h1>Bonjour {profile.full_name.split(' ')[0]} 👋</h1><div className="sub">{new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })} · vue d'ensemble de l'école</div></div>
        <div className="tabs">
          {[[null, 'Année'], [1, 'T1'], [2, 'T2'], [3, 'T3']].map(([v, l]) => (
            <button key={l} className={term === v ? 'on' : ''} onClick={() => setTerm(v)}>{l}</button>
          ))}
        </div>
      </div>
      {err && <div className="notice">{err}</div>}
      {!d ? <p className="meta">Chargement…</p> : (
        <>
          <div className="stats">
            <div className="stat"><i className="b">🎓</i><small>Élèves</small><strong>{d.students}</strong></div>
            <div className="stat"><i>📚</i><small>Classes</small><strong>{d.classes}</strong></div>
            <div className="stat"><i className="a">👩‍🏫</i><small>Professeurs</small><strong>{d.teachers}</strong></div>
            <div className="stat"><i className="g">💰</i><small>Scolarité encaissée</small><strong className="lk-ok">{fcfa(d.total_paid)}</strong><small>sur {fcfa(d.total_due)}</small></div>
          </div>
          <div className="grid2">
            <div className="lk-card lk-inline" style={{ flexWrap: 'nowrap' }}>
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
/* ===== LAKOL — design moderne (clair) ===== */
:root{
  --bg:#F4F5F9; --surface:#fff; --line:#E6E8F0; --text:#0F172A; --muted:#64748B;
  --brand:#E05206; --brand-soft:#FFF1E8; --green:#0A9F2B; --green-soft:#E7F8EC;
  --red:#DC2626; --red-soft:#FEECEC; --amber:#D97706; --amber-soft:#FEF3E2; --blue:#2563EB; --blue-soft:#EAF1FF;
  --radius:14px; --shadow:0 1px 2px rgba(15,23,42,.05),0 4px 14px rgba(15,23,42,.05);
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{font-family:Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--text);font-size:15px;line-height:1.45;-webkit-font-smoothing:antialiased}
a{color:var(--brand);text-decoration:none}
h1{font-size:1.55rem;margin:0;letter-spacing:-.02em}
h2{font-size:1.25rem;margin:0}
h3{font-size:1rem;margin:0}
h4{font-size:.9rem;margin:0}
code{font-family:ui-monospace,Menlo,monospace;background:#F1F3F9;border:1px solid var(--line);border-radius:7px;padding:1px 7px;font-size:.82rem;color:#334155}
small{color:var(--muted)}
.meta{color:var(--muted);font-size:.86rem}

/* ----- structure ----- */
.lk-shell{display:flex;min-height:100vh}
.lk-main{flex:1;min-width:0}
.lk-page{max-width:1120px;margin:0 auto;padding:28px 28px 90px;display:flex;flex-direction:column;gap:18px}
.lk-stack{display:flex;flex-direction:column;gap:16px}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
.topbar .sub{color:var(--muted);font-size:.9rem;margin-top:2px}

/* ----- sidebar ----- */
.lk-side{width:248px;flex-shrink:0;background:var(--surface);border-right:1px solid var(--line);padding:20px 14px;display:flex;flex-direction:column;gap:6px;position:sticky;top:0;height:100vh}
.lk-brand{display:flex;align-items:center;gap:10px;padding:4px 10px 18px;font-weight:800;font-size:1.3rem;letter-spacing:-.03em;color:var(--text)}
.lk-logo{width:34px;height:34px;border-radius:10px;background:linear-gradient(135deg,#E05206 0%,#E05206 45%,#fff 45%,#fff 55%,#0A9F2B 55%);box-shadow:inset 0 0 0 2px rgba(255,255,255,.35),0 2px 8px rgba(224,82,6,.25)}
.lk-navlabel{font-size:.7rem;text-transform:uppercase;letter-spacing:.08em;color:#94A3B8;padding:12px 12px 4px}
.lk-links{display:flex;flex-direction:column;gap:2px;flex:1;overflow-y:auto}
.lk-links a{display:flex;align-items:center;gap:11px;padding:10px 12px;border-radius:11px;color:#475569;font-weight:500;font-size:.93rem}
.lk-links a svg{width:19px;height:19px;flex-shrink:0;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.lk-links a:hover{background:#F4F5F9;color:var(--text)}
.lk-links a.on{background:var(--brand-soft);color:var(--brand);font-weight:600}
.lk-user{display:flex;align-items:center;gap:10px;padding:12px;border:1px solid var(--line);border-radius:13px}
.lk-user .who{flex:1;min-width:0}
.lk-user b{display:block;font-size:.88rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lk-user span{font-size:.76rem;color:var(--muted)}
.nav-logout{background:none;border:0;color:var(--muted);cursor:pointer;padding:6px;border-radius:8px;display:flex}
.nav-logout:hover{background:var(--red-soft);color:var(--red)}
.nav-logout svg{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}

/* ----- cartes & composants ----- */
.lk-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:18px;display:flex;flex-direction:column;gap:12px;box-shadow:var(--shadow)}
.lk-card h3{font-size:1rem}
.lk-off{opacity:.55}
.lk-inline{display:flex;flex-wrap:wrap;gap:10px;align-items:center}
.lk-inline input,.lk-inline select{flex:1;min-width:120px}
.lk-label{font-size:.85rem;color:var(--muted);font-weight:500}
.lk-scroll{overflow-x:auto}
.lk-ok{color:var(--green)}.lk-warn{color:var(--amber)}.lk-low{color:var(--red)}
.lk-past{opacity:.5}
.lk-code{font-family:ui-monospace,Menlo,monospace;font-size:1.25rem;letter-spacing:.22em;padding:8px 16px;border-radius:12px;background:var(--brand-soft);border:1.5px dashed var(--brand);color:var(--brand);font-weight:700}
.lk-details summary{cursor:pointer;color:var(--muted);font-size:.9rem;margin:6px 0}
.lk-hero{flex-direction:row;align-items:center;flex-wrap:wrap;gap:18px}
.lk-hero .avatar{width:58px;height:58px;font-size:1.2rem}
.lk-bigscore{text-align:center;padding:10px 20px;border-radius:14px;background:var(--green-soft)}
.lk-bigscore span{display:block;font-size:2rem;font-weight:800;color:var(--green);line-height:1.1}
.lk-bigscore small{color:#217a37}
.lk-grid-box{display:flex;flex-direction:column;gap:12px;padding:14px;border-radius:12px;background:#F8F9FC;border:1px dashed #CBD5E1}
.lk-rows{display:flex;flex-direction:column;gap:8px;max-height:440px;overflow-y:auto;padding-right:4px}
.lk-rowline{display:flex;gap:8px;align-items:center}.lk-rowline input{flex:1;min-width:0}
.lk-num{width:28px;text-align:right;color:#94A3B8;font-size:.82rem}

input,select,textarea{font:inherit;color:var(--text);background:#fff;border:1.5px solid var(--line);border-radius:10px;padding:9px 12px;min-height:40px;outline:none;transition:border .15s,box-shadow .15s;width:100%}
input[type=checkbox]{width:auto;min-height:0}
input:focus,select:focus,textarea:focus{border-color:var(--brand);box-shadow:0 0 0 3px rgba(224,82,6,.14)}
button{font:inherit;font-weight:600;cursor:pointer;border:0;border-radius:10px;padding:9px 18px;min-height:40px;background:var(--brand);color:#fff;transition:filter .15s,transform .05s}
button:hover{filter:brightness(1.06)}button:active{transform:translateY(1px)}
button:disabled{opacity:.5;cursor:not-allowed}
.btn-ghost{background:#fff;color:var(--text);border:1.5px solid var(--line)}
.btn-ghost:hover{background:#F8F9FC;filter:none}
.btn-danger{background:var(--red-soft);color:var(--red)}
.btn-small{padding:5px 11px;min-height:0;font-size:.82rem;border-radius:8px}
a.btn-small{display:inline-flex;align-items:center;font-weight:600;background:#fff;color:var(--text);border:1.5px solid var(--line)}

.row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 4px;border-bottom:1px solid var(--line);color:var(--text)}
.row:last-child{border-bottom:0}
a.row:hover{background:#F8F9FC;border-radius:10px}
.person{display:flex;align-items:center;gap:10px;font-weight:500;color:var(--text);flex-wrap:wrap}
.actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.avatar{width:38px;height:38px;border-radius:50%;background:linear-gradient(135deg,#FDBA74,#E05206);color:#fff;font-weight:700;display:inline-flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0}
.score{font-weight:700}
.notice{background:var(--amber-soft);color:#92400E;border:1px solid #FCD9A8;padding:10px 14px;border-radius:10px}
.empty{padding:26px;text-align:center;color:var(--muted);background:#fff;border:1.5px dashed #CBD5E1;border-radius:var(--radius)}
.tag{display:inline-block;padding:2px 9px;border-radius:99px;font-size:.74rem;font-weight:600;background:#EEF1F8;color:#475569}
.badge{display:inline-block;padding:3px 11px;border-radius:99px;font-size:.76rem;font-weight:600;background:#EEF1F8;color:#475569}
.badge.ok{background:var(--green-soft);color:var(--green)}.badge.mid{background:var(--amber-soft);color:var(--amber)}.badge.bad{background:var(--red-soft);color:var(--red)}

/* stats */
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:14px}
.stat{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:16px;display:flex;flex-direction:column;gap:3px;box-shadow:var(--shadow);position:relative}
.stat small{font-size:.8rem}.stat strong{font-size:1.55rem;letter-spacing:-.02em}
.stat i{font-style:normal;width:38px;height:38px;border-radius:11px;display:flex;align-items:center;justify-content:center;font-size:1.15rem;margin-bottom:8px;background:var(--brand-soft)}
.stat i.g{background:var(--green-soft)}.stat i.b{background:var(--blue-soft)}.stat i.a{background:var(--amber-soft)}
.bar{height:9px;border-radius:99px;background:#EAECF3;overflow:hidden}
.bar div{height:100%;background:linear-gradient(90deg,#E05206,#0A9F2B);border-radius:99px}

/* graphiques */
.donut{--p:0;width:130px;height:130px;border-radius:50%;background:conic-gradient(var(--green) calc(var(--p)*1%),#EAECF3 0);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.donut span{width:92px;height:92px;border-radius:50%;background:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;font-weight:800;font-size:1.4rem}
.donut small{font-weight:500;font-size:.7rem}
.hbar{display:grid;grid-template-columns:90px 1fr 46px;gap:10px;align-items:center;font-size:.88rem}
.hbar .track{height:12px;background:#EAECF3;border-radius:99px;overflow:hidden}
.hbar .fill{height:100%;border-radius:99px;background:var(--green)}.hbar .fill.low{background:var(--red)}
.hbar b{text-align:right}

table.data{width:100%;border-collapse:collapse}
table.data th,table.data td{padding:11px 12px;text-align:left;border-bottom:1px solid var(--line)}
table.data th{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;color:#94A3B8;font-weight:600}
table.data tbody tr:hover{background:#FAFBFD}
.lk-total td{background:#F8F9FC;font-weight:600}

.tabs,.chips{display:flex;gap:6px;flex-wrap:wrap}
.tabs{background:#EAECF3;padding:4px;border-radius:12px;width:fit-content}
.tabs button{background:transparent;color:#475569;padding:6px 14px;min-height:0;border-radius:9px}
.tabs button.on{background:#fff;color:var(--text);box-shadow:0 1px 3px rgba(0,0,0,.1)}
.chips button{background:#fff;color:#475569;border:1.5px solid var(--line);border-radius:99px;padding:6px 14px;min-height:0;font-weight:500}
.chips button.on{background:var(--brand-soft);color:var(--brand);border-color:var(--brand)}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px}
.week{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.day h4{color:var(--muted);text-transform:uppercase;letter-spacing:.06em;font-size:.72rem}
.slot{display:flex;flex-direction:column;gap:2px;padding:10px 12px;border-radius:11px;background:var(--green-soft);border-left:4px solid var(--green);position:relative;font-size:.88rem}
.slot:nth-of-type(3n+2){background:var(--blue-soft);border-left-color:var(--blue)}
.slot:nth-of-type(3n){background:var(--amber-soft);border-left-color:var(--amber)}
.slot button{position:absolute;top:6px;right:6px}

/* notes */
.chip-score{display:inline-block;padding:2px 9px;border-radius:8px;background:#EEF1F8;font-weight:600;font-size:.82rem;cursor:pointer;border:0;min-height:0;color:#334155}
.chip-score:hover{background:var(--brand-soft);color:var(--brand)}
.score-in{max-width:90px;text-align:center;font-weight:700}

/* connexion */
.auth{display:grid;grid-template-columns:1.05fr 1fr;min-height:100vh}
.auth-hero{background:linear-gradient(150deg,#E05206 0%,#C2410C 40%,#065F2A 100%);color:#fff;padding:56px;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden}
.auth-hero:before{content:"";position:absolute;width:420px;height:420px;border-radius:50%;background:rgba(255,255,255,.08);right:-120px;top:-100px}
.auth-hero:after{content:"";position:absolute;width:300px;height:300px;border-radius:50%;background:rgba(255,255,255,.07);left:-90px;bottom:-80px}
.auth-hero h1{font-size:2.3rem;line-height:1.15;max-width:420px;position:relative}
.auth-hero p{opacity:.9;max-width:420px;position:relative}
.auth-hero .lk-brand{color:#fff;padding:0;position:relative}
.auth-feats{display:flex;flex-direction:column;gap:10px;position:relative}
.auth-feats span{background:rgba(255,255,255,.14);padding:8px 14px;border-radius:99px;width:fit-content;font-size:.9rem}
.auth-form{display:flex;align-items:center;justify-content:center;padding:32px;background:#fff}
.auth-box{width:100%;max-width:400px;display:flex;flex-direction:column;gap:14px}
.roles{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.roles button{background:#fff;color:var(--text);border:1.5px solid var(--line);flex-direction:column;display:flex;align-items:center;gap:2px;padding:12px 6px;font-size:.84rem}
.roles button span{font-size:1.4rem}
.roles button.on{border-color:var(--brand);background:var(--brand-soft);color:var(--brand)}

/* bulletin imprimable */
.bul{background:#fff;color:#111;padding:28px 34px;border:1px solid var(--line);border-radius:6px;font-family:Georgia,"Times New Roman",serif;display:flex;flex-direction:column;gap:12px;page-break-after:always;break-after:page}
.bul .head{display:flex;justify-content:space-between;text-align:center;font-size:.8rem;text-transform:uppercase;gap:10px}
.bul h2{text-align:center;font-size:1.3rem;letter-spacing:.1em;margin:6px 0}
.bul table{width:100%;border-collapse:collapse;font-size:.9rem}
.bul th,.bul td{border:1px solid #333;padding:5px 8px;text-align:center}
.bul td:first-child,.bul th:first-child{text-align:left}
.bul .sign{display:flex;justify-content:space-between;margin-top:26px;font-size:.85rem}

@media(max-width:900px){
  .lk-shell{flex-direction:column}
  .lk-side{position:fixed;bottom:0;left:0;right:0;top:auto;width:auto;height:auto;flex-direction:row;padding:6px 8px;z-index:30;border-right:0;border-top:1px solid var(--line);box-shadow:0 -4px 16px rgba(0,0,0,.06)}
  .lk-brand,.lk-navlabel,.lk-user .who{display:none}
  .lk-links{flex-direction:row;overflow-x:auto;gap:2px}
  .lk-links a{flex-direction:column;gap:2px;font-size:.66rem;padding:6px 10px;white-space:nowrap}
  .lk-user{border:0;padding:0}.lk-user .avatar{display:none}
  .lk-page{padding:18px 14px 100px}
  .auth{grid-template-columns:1fr}.auth-hero{display:none}
}
@media print{
  .lk-side,.no-print{display:none!important}
  body{background:#fff}.lk-page{padding:0;max-width:none}
  .bul{border:0;padding:10mm 8mm}
}
LAKOL_EOF

save "app/layout.tsx"
mkdir -p "$(dirname "app/layout.tsx")"
cat > 'app/layout.tsx' <<'LAKOL_EOF'
import './globals.css';
import NavMenu from './NavMenu';

export const metadata = { title: 'Lakol — gestion d\'école', description: 'Gestion d\'école privée pour le Niger et l\'Afrique' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
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
        <div className="lk-brand"><span className="lk-logo" />Lakol</div>
        <div className="lk-stack">
          <h1>La gestion de ton école, simple et moderne.</h1>
          <p>Notes, bulletins, scolarité, emplois du temps : tout au même endroit, pour le directeur, les professeurs et les parents.</p>
          <div className="auth-feats"><span>✓ Notes et bulletins en quelques clics</span><span>✓ Suivi de la scolarité en FCFA</span><span>✓ Moov, Airtel, Orange, NITA</span></div>
        </div>
        <small style={{ color: 'rgba(255,255,255,.7)' }}>Fait au Niger 🇳🇪</small>
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
  const [fee, setFee] = useState({ label: '', amount: '', all: false });
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
    const targets = fee.all ? classes.map((c) => c.id) : [classId];
    const { error } = await supabase.from('fees').insert(targets.map((id) => ({ school_id: profile.school_id, class_id: id, label: fee.label.trim(), amount })));
    if (error) return setErr(error.message);
    setFee({ label: '', amount: '', all: false }); load();
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
                        {fees.filter((f) => f.class_id === r.class_id).map((f) => <option key={f.id} value={f.id}>{f.label}</option>)}
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
          <select value={classId === 'all' ? '' : classId} onChange={(e) => setClassId(e.target.value)}>
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          {fees.filter((f) => f.class_id === classId).length === 0 && <div className="empty">Aucun frais pour cette classe.</div>}
          {fees.filter((f) => f.class_id === classId).map((f) => (
            <div className="row" key={f.id}>
              <div className="person">{f.label}</div>
              <span>{fcfa(f.amount)} <button className="btn-small btn-ghost" onClick={() => editFee(f)}>Modifier</button> <button className="btn-small btn-danger" onClick={() => delFee(f)}>✕</button></span>
            </div>
          ))}
          <form className="lk-card lk-inline" onSubmit={addFee}>
            <input placeholder="Nom (ex. Scolarité)" value={fee.label} onChange={(e) => setFee({ ...fee, label: e.target.value })} />
            <input type="number" min="1" placeholder="Montant FCFA" value={fee.amount} onChange={(e) => setFee({ ...fee, amount: e.target.value })} style={{ maxWidth: 160 }} />
            <label className="meta"><input type="checkbox" checked={fee.all} onChange={(e) => setFee({ ...fee, all: e.target.checked })} style={{ width: 'auto' }} /> Toutes les classes</label>
            <button>Ajouter le frais</button>
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
  const [a, setA] = useState({ kind: 'devoir', subject_id: '', title: '', due_date: today() });
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
    const [t, d] = await Promise.all([
      supabase.from('timetable').select('id, day, start_time, end_time, room, subjects(name)').eq('class_id', classId).order('start_time'),
      supabase.from('assignments').select('id, kind, title, due_date, subjects(name)').eq('class_id', classId).order('due_date'),
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
      title: a.title.trim(), due_date: a.due_date, created_by: profile.id,
    });
    if (error) setErr(error.message); else { setA({ ...a, title: '' }); load(); }
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
                  <input type="date" value={a.due_date} onChange={(e) => setA({ ...a, due_date: e.target.value })} />
                  <button>Publier</button>
                </form>
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

echo "✅ Lakol installé. Anciennes versions dans $B"
echo "Lance maintenant : npm run dev"
