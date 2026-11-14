#!/bin/bash
# Mise à jour de la page Planning. À lancer depuis le dossier ecole-app.
set -e
if [ ! -f package.json ] || [ ! -d app ]; then echo "❌ Lance ce script depuis le dossier ecole-app."; exit 1; fi
B="_sauvegarde_avant_planning"; mkdir -p "$B"
save(){ if [ -f "$1" ] && [ ! -f "$B/$1" ]; then mkdir -p "$B/$(dirname "$1")"; cp "$1" "$B/$1"; fi; }

save "app/planning/page.js"
mkdir -p "$(dirname "app/planning/page.js")"
cat > 'app/planning/page.js' <<'LAKOL_EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const DAYS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const KINDS = { devoir: ['Devoir', 'mid'], examen: ['Examen', 'bad'], composition: ['Composition', ''] };
const PALETTE = [
  'linear-gradient(135deg,#6D4AFF,#9B6BFF)', 'linear-gradient(135deg,#0EA5A4,#22D3EE)', 'linear-gradient(135deg,#FF6B6B,#FF9A5B)',
  'linear-gradient(135deg,#F59E0B,#FBBF24)', 'linear-gradient(135deg,#EC4899,#F472B6)', 'linear-gradient(135deg,#3B82F6,#60A5FA)',
];
const HOUR_H = 56;
const hm = (t) => (t || '').slice(0, 5);
const mins = (t) => { const [h, m] = hm(t).split(':').map(Number); return h * 60 + m; };
const ymd = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const termOf = (date) => { const m = Number(date.slice(5, 7)); return m >= 9 ? 1 : m <= 3 ? 2 : 3; };
const daysUntil = (d) => Math.round((new Date(d + 'T00:00') - new Date(ymd() + 'T00:00')) / 864e5);
const colorOf = (name, list) => PALETTE[Math.max(0, list.indexOf(name || '')) % PALETTE.length];

export default function Planning() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [classes, setClasses] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [classId, setClassId] = useState('');
  const [tab, setTab] = useState('edt');
  const [slots, setSlots] = useState([]);
  const [todo, setTodo] = useState([]);
  const [plans, setPlans] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [slot, setSlot] = useState({ day: '1', start: '08:00', end: '09:00', subject_id: '', room: '' });
  const [a, setA] = useState({ kind: 'devoir', subject_id: '', title: '', due_date: ymd(), chapters: '' });
  const [err, setErr] = useState('');
  const formRef = useRef(null);
  const canEdit = profile?.role !== 'parent';

  useEffect(() => {
    if (status !== 'ok') return;
    (async () => {
      let list;
      if (profile.role === 'teacher') {
        const { data: t } = await supabase.from('teaching').select('class_id').eq('teacher_id', profile.id);
        const { data: cr } = await supabase.from('classes').select('id').eq('created_by', profile.id);
        const ids = [...new Set([...(t || []).map((x) => x.class_id), ...(cr || []).map((x) => x.id)])];
        list = ids.length ? (await supabase.from('classes').select('id, name').in('id', ids).order('name')).data : [];
      } else list = (await supabase.from('classes').select('id, name').order('name')).data;
      setClasses(list || []); if (list?.length) setClassId(list[0].id);
      setSubjects((await supabase.from('subjects').select('id, name').order('name')).data || []);
    })();
  }, [status]);

  async function load() {
    if (!classId) return;
    const [t, d, pl] = await Promise.all([
      supabase.from('timetable').select('id, day, start_time, end_time, room, subject_id, subjects(name)').eq('class_id', classId).order('start_time'),
      supabase.from('assignments').select('id, kind, title, due_date, chapters, term, subject_id, subjects(name)').eq('class_id', classId).order('due_date'),
      profile.role !== 'parent' ? supabase.from('teaching').select('subject_id, devoirs_per_term, compositions_per_term, subjects(name)').eq('class_id', classId) : { data: [] },
    ]);
    setSlots(t.data || []); setTodo(d.data || []); setPlans(pl.data || []);
    const e = t.error || d.error;
    setErr(e ? (/assignments|schema cache|does not exist|chapters/i.test(e.message) ? "La migration SQL n'est pas à jour dans Supabase." : e.message) : '');
  }
  useEffect(() => { load(); }, [classId]);

  async function addSlot(e) {
    e?.preventDefault(); setErr('');
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
      title: a.title.trim(), due_date: a.due_date, term: termOf(a.due_date), chapters: a.chapters.trim() || null, created_by: profile.id,
    });
    if (error) setErr(error.message); else { setA({ ...a, title: '', chapters: '' }); load(); }
  }
  const del = async (table, id) => { await supabase.from(table).delete().eq('id', id); load(); };
  const pick = (day, start) => {
    if (!canEdit) return;
    const [h, m] = start.split(':').map(Number);
    const end = `${String(Math.min(h + 1, 23)).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    setSlot({ ...slot, day: String(day), start, end }); setShowForm(true);
    setTimeout(() => formRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 50);
  };

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const names = [...new Set(subjects.map((s) => s.name))];
  // plage horaire affichée
  const lo = Math.min(7, ...slots.map((s) => Math.floor(mins(s.start_time) / 60)));
  const hi = Math.max(16, ...slots.map((s) => Math.ceil(mins(s.end_time) / 60)));
  const hours = Array.from({ length: hi - lo + 1 }, (_, i) => lo + i);
  const todayIdx = (new Date().getDay() + 6) % 7 + 1; // 1 = lundi
  const todaySlots = slots.filter((s) => s.day === todayIdx).sort((x, y) => mins(x.start_time) - mins(y.start_time));
  const nowMin = new Date().getHours() * 60 + new Date().getMinutes();
  const nextCourse = todaySlots.find((s) => mins(s.end_time) > nowMin);

  const upcoming = todo.filter((x) => x.due_date >= ymd());
  const past = todo.filter((x) => x.due_date < ymd()).reverse();
  const groups = [
    ['Cette semaine', upcoming.filter((x) => daysUntil(x.due_date) <= 7)],
    ['Semaine prochaine', upcoming.filter((x) => daysUntil(x.due_date) > 7 && daysUntil(x.due_date) <= 14)],
    ['Plus tard', upcoming.filter((x) => daysUntil(x.due_date) > 14)],
  ].filter(([, l]) => l.length);
  const curTerm = termOf(ymd());
  const countOf = (sid, kinds) => todo.filter((x) => x.subject_id === sid && kinds.includes(x.kind) && (x.term || termOf(x.due_date)) === curTerm).length;

  const card = (x, isPast) => {
    const n = daysUntil(x.due_date);
    const [label, cls] = KINDS[x.kind];
    return (
      <div className={'lk-card lift asg' + (isPast ? ' lk-past' : '')} key={x.id}>
        <div className="lk-inline" style={{ justifyContent: 'space-between' }}>
          <span className={'badge ' + cls}>{label}</span>
          {!isPast && <span className={'badge ' + (n <= 1 ? 'bad' : n <= 7 ? 'mid' : '')}>{n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} jours`}</span>}
        </div>
        <h3>{x.title}</h3>
        <div className="meta">{x.subjects?.name && <b>{x.subjects.name} · </b>}{new Date(x.due_date + 'T00:00').toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}</div>
        {x.chapters && <div className="tag" style={{ width: 'fit-content' }}>📖 Chapitres : {x.chapters}</div>}
        {canEdit && <div><button className="btn-small btn-danger" onClick={() => del('assignments', x.id)}>Supprimer</button></div>}
      </div>
    );
  };

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>Planning</h1><div className="sub">Emploi du temps, devoirs et examens de la classe.</div></div>
        <div className="tabs">
          <button className={tab === 'edt' ? 'on' : ''} onClick={() => setTab('edt')}>📅 Emploi du temps</button>
          <button className={tab === 'dev' ? 'on' : ''} onClick={() => setTab('dev')}>📝 Devoirs &amp; examens {upcoming.length > 0 && <small style={{ color: 'inherit' }}>({upcoming.length})</small>}</button>
        </div>
      </div>
      {err && <div className="notice">{err}</div>}
      {classes.length === 0 && <div className="empty">{profile.role === 'parent' ? "Aucune classe liée à ton enfant pour le moment." : <>Aucune classe pour le moment. <a href="/classes">Crée ou rejoins une classe →</a></>}</div>}

      {classes.length > 0 && (
        <div className="chips">
          {classes.map((c) => <button key={c.id} className={classId === c.id ? 'on' : ''} onClick={() => setClassId(c.id)}>{c.name}</button>)}
        </div>
      )}

      {classId && tab === 'edt' && (
        <>
          <div className="lk-card today">
            <h3>☀️ Aujourd'hui · {DAYS[todayIdx - 1] || 'Dimanche'}</h3>
            {todaySlots.length === 0 ? <span className="meta">Pas de cours aujourd'hui pour cette classe.</span> : (
              <div className="lk-inline" style={{ gap: 10 }}>
                {todaySlots.map((s) => {
                  const live = mins(s.start_time) <= nowMin && nowMin < mins(s.end_time);
                  return (
                    <div className={'pill-course' + (live ? ' live' : '')} key={s.id} style={{ background: colorOf(s.subjects?.name, names) }}>
                      <b>{s.subjects?.name || 'Cours'}</b><span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span>
                      {live && <em>En cours</em>}{!live && nextCourse?.id === s.id && <em>Prochain</em>}
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {canEdit && (
            <div ref={formRef}>
              {!showForm ? <button onClick={() => setShowForm(true)}>+ Ajouter un cours</button> : (
                <form className="lk-card lk-inline" onSubmit={addSlot}>
                  <select value={slot.day} onChange={(e) => setSlot({ ...slot, day: e.target.value })}>{DAYS.map((d, i) => <option key={d} value={i + 1}>{d}</option>)}</select>
                  <input type="time" value={slot.start} onChange={(e) => setSlot({ ...slot, start: e.target.value })} />
                  <span className="meta">à</span>
                  <input type="time" value={slot.end} onChange={(e) => setSlot({ ...slot, end: e.target.value })} />
                  <select value={slot.subject_id} onChange={(e) => setSlot({ ...slot, subject_id: e.target.value })}>
                    <option value="">Matière</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                  <input placeholder="Salle" value={slot.room} onChange={(e) => setSlot({ ...slot, room: e.target.value })} style={{ maxWidth: 100 }} />
                  <button>Ajouter</button>
                  <button type="button" className="btn-ghost" onClick={() => setShowForm(false)}>Fermer</button>
                </form>
              )}
              {canEdit && <div className="meta" style={{ marginTop: 6 }}>Astuce : clique sur une case vide de la grille pour préremplir le jour et l'heure.</div>}
            </div>
          )}

          <div className="lk-card tt-wrap">
            <div className="tt" style={{ '--hh': HOUR_H + 'px' }}>
              <div className="tt-head" />
              {DAYS.map((d, i) => <div key={d} className={'tt-head' + (i + 1 === todayIdx ? ' today' : '')}>{d}</div>)}
              <div className="tt-hours" style={{ height: hours.length * HOUR_H }}>
                {hours.map((h, i) => <span key={h} style={{ top: i * HOUR_H }}>{String(h).padStart(2, '0')}:00</span>)}
              </div>
              {DAYS.map((d, i) => (
                <div key={d} className={'tt-col' + (i + 1 === todayIdx ? ' today' : '')} style={{ height: hours.length * HOUR_H }}
                  onClick={(e) => {
                    if (e.target !== e.currentTarget) return;
                    const y = e.nativeEvent.offsetY; const m = Math.floor((y / HOUR_H) * 2) * 30 + lo * 60;
                    pick(i + 1, `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
                  }}>
                  {slots.filter((s) => s.day === i + 1).map((s) => (
                    <div className="tt-block" key={s.id} style={{ top: ((mins(s.start_time) - lo * 60) / 60) * HOUR_H, height: ((mins(s.end_time) - mins(s.start_time)) / 60) * HOUR_H - 3, background: colorOf(s.subjects?.name, names) }}>
                      <b>{s.subjects?.name || 'Cours'}</b>
                      <span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span>
                      {canEdit && <button title="Supprimer" onClick={(e) => { e.stopPropagation(); del('timetable', s.id); }}>✕</button>}
                    </div>
                  ))}
                </div>
              ))}
            </div>
            {/* version téléphone : liste par jour */}
            <div className="tt-list">
              {DAYS.map((d, i) => {
                const list = slots.filter((s) => s.day === i + 1).sort((x, y) => mins(x.start_time) - mins(y.start_time));
                return (
                  <div key={d}>
                    <h4 className={i + 1 === todayIdx ? 'lk-ok' : ''}>{d}</h4>
                    {list.length === 0 && <span className="meta">—</span>}
                    {list.map((s) => <div className="pill-course" key={s.id} style={{ background: colorOf(s.subjects?.name, names), margin: '4px 0' }}><b>{s.subjects?.name || 'Cours'}</b><span>{hm(s.start_time)}–{hm(s.end_time)}{s.room ? ` · ${s.room}` : ''}</span></div>)}
                  </div>
                );
              })}
            </div>
            {slots.length === 0 && <div className="empty">Aucun cours pour le moment.</div>}
          </div>
        </>
      )}

      {classId && tab === 'dev' && (
        <>
          {canEdit && (
            <form className="lk-card" onSubmit={addAssignment}>
              <h3>Publier un devoir ou un examen</h3>
              <div className="chips">
                {Object.entries(KINDS).map(([k, [l]]) => <button type="button" key={k} className={(k === 'devoir' ? 'amber ' : k === 'examen' ? 'coral ' : '') + (a.kind === k ? 'on' : '')} onClick={() => setA({ ...a, kind: k })}>{l}</button>)}
              </div>
              <div className="lk-inline">
                <select value={a.subject_id} onChange={(e) => setA({ ...a, subject_id: e.target.value })}>
                  <option value="">Matière</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
                <input type="date" value={a.due_date} onChange={(e) => setA({ ...a, due_date: e.target.value })} style={{ maxWidth: 190 }} />
              </div>
              <input placeholder="Sujet (ex. Exercices p.42)" value={a.title} onChange={(e) => setA({ ...a, title: e.target.value })} />
              <input placeholder="Chapitres (facultatif, ex. 1, 2 et 3)" value={a.chapters} onChange={(e) => setA({ ...a, chapters: e.target.value })} />
              <div><button>Publier</button></div>
            </form>
          )}

          {plans.length > 0 && (
            <div className="lk-card">
              <h3>🎯 Programme du trimestre {curTerm}</h3>
              {plans.map((p, i) => {
                const d = countOf(p.subject_id, ['devoir']); const c = countOf(p.subject_id, ['composition', 'examen']);
                return (
                  <div className="row" key={i}>
                    <div className="person">{p.subjects?.name}</div>
                    <div className="actions">
                      <span className={'badge ' + (d >= p.devoirs_per_term ? 'ok' : 'mid')}>Devoirs {d}/{p.devoirs_per_term}</span>
                      <span className={'badge ' + (c >= p.compositions_per_term ? 'ok' : 'mid')}>Compositions {c}/{p.compositions_per_term}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {groups.length === 0 && <div className="empty">Rien de prévu pour le moment 🎉</div>}
          {groups.map(([title, list]) => (
            <div className="lk-stack" key={title}>
              <h3>{title}</h3>
              <div className="grid2">{list.map((x) => card(x, false))}</div>
            </div>
          ))}
          {past.length > 0 && <details className="lk-details"><summary>Passés ({past.length})</summary><div className="grid2">{past.map((x) => card(x, true))}</div></details>}
        </>
      )}
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

/* planning : grille horaire */
.tt-wrap{padding:14px;overflow-x:auto}
.tt{display:grid;grid-template-columns:54px repeat(6,minmax(120px,1fr));min-width:820px}
.tt-head{text-align:center;font-weight:700;font-size:.82rem;color:var(--muted);padding:8px 4px 10px;text-transform:uppercase;letter-spacing:.06em}
.tt-head.today{color:var(--brand)}
.tt-hours{position:relative}
.tt-hours span{position:absolute;right:8px;transform:translateY(-50%);font-size:.72rem;color:#A39FCB;font-weight:600}
.tt-col{position:relative;border-left:1px dashed var(--line);background-image:repeating-linear-gradient(to bottom,transparent 0,transparent calc(var(--hh) - 1px),var(--line) calc(var(--hh) - 1px),var(--line) var(--hh));cursor:cell}
.tt-col.today{background-color:rgba(109,74,255,.05)}
.tt-block{position:absolute;left:4px;right:4px;border-radius:14px;padding:6px 10px;color:#fff;display:flex;flex-direction:column;gap:1px;overflow:hidden;box-shadow:0 8px 18px rgba(76,52,200,.22);transition:transform .15s,box-shadow .15s;cursor:default;font-size:.82rem}
.tt-block:hover{transform:scale(1.03);z-index:3;box-shadow:0 14px 28px rgba(76,52,200,.35)}
.tt-block b{font-size:.86rem;line-height:1.2}.tt-block span{opacity:.92;font-size:.74rem}
.tt-block button{position:absolute;top:4px;right:4px;padding:0;width:20px;height:20px;min-height:0;font-size:.65rem;background:rgba(255,255,255,.25);box-shadow:none;opacity:0}
.tt-block:hover button{opacity:1}
.tt-list{display:none}
.pill-course{display:flex;flex-direction:column;gap:1px;padding:9px 16px;border-radius:16px;color:#fff;min-width:150px;position:relative;box-shadow:0 8px 18px rgba(76,52,200,.2)}
.pill-course span{font-size:.8rem;opacity:.92}
.pill-course em{position:absolute;top:8px;right:10px;font-style:normal;font-size:.68rem;font-weight:700;background:rgba(255,255,255,.28);border-radius:99px;padding:1px 8px}
.pill-course.live{outline:3px solid #fff;box-shadow:0 0 0 5px rgba(109,74,255,.35),0 10px 24px rgba(76,52,200,.35)}
.asg h3{font-size:1.05rem}
@media(max-width:700px){.tt{display:none}.tt-list{display:block}}
LAKOL_EOF

echo "✅ Page Planning mise à jour. Recharge la page dans ton navigateur (le serveur n'a pas besoin d'être relancé)."
