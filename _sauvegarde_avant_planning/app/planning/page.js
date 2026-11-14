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
