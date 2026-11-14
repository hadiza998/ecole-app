'use client';
import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { pingNotify } from '../../lib/notify';

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
    if (error) setErr(error.message); else { setA({ ...a, title: '', chapters: '' }); pingNotify(); load(); }
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
