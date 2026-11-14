'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { KINDS, KindIcon } from '../../lib/kinds';
import { subjectAvg, generalAvg, appreciation, wDOf, fmt, fcfa, METHODS } from '../../lib/grades';
import { useSettings } from '../../lib/useSettings';
import { periodList, periodShort } from '../../lib/settings';
import Icon from './Icon';

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
  const [coefs, setCoefs] = useState({});
  const st = useSettings();
  const showMoney = role === 'admin' || role === 'parent';

  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data: s } = await supabase.from('students')
        .select('id, first_name, last_name, class_id, matricule, access_code, classes(name, school_year)')
        .eq('id', studentId).maybeSingle();
      setStudent(s);
      const { data: cc } = s?.class_id ? await supabase.from('class_coefficients').select('subject_id, coefficient').eq('class_id', s.class_id) : { data: [] };
      setCoefs(Object.fromEntries((cc || []).map((x) => [x.subject_id, Number(x.coefficient)])));
      const { data: g } = await supabase.from('grades')
        .select('id, term, kind, score, title, subject_id, created_at, subjects(name, coefficient)')
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
    if (!bySubject[id]) bySubject[id] = { name: g.subjects?.name || '?', coef: coefs[id] ?? g.subjects?.coefficient ?? 1, list: [] };
    bySubject[id].list.push(g);
  });
  const subjects = Object.values(bySubject).sort((a, b) => a.name.localeCompare(b.name));
  const wD = wDOf(st), periods = periodList(st);
  const termAvgs = periods.map((t) =>
    generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list.filter((g) => g.term === t), wD), coef: s.coef })))
  );
  const yearAvg = generalAvg(subjects.map((s) => ({ avg: subjectAvg(s.list, wD), coef: s.coef })));

  const due = fees.reduce((s, f) => s + f.amount, 0);
  const paid = payments.reduce((s, p) => s + p.amount, 0);
  const left = Math.max(0, due - paid);
  const pct = due ? Math.min(100, Math.round((paid / due) * 100)) : 0;

  return (
    <div className="lk-stack">
      <div className="lk-card sf-head">
        <div className="sf-avatar">{(student.first_name[0] || '') + (student.last_name[0] || '')}</div>
        <div className="sf-id">
          <h2>{student.first_name} {student.last_name}</h2>
          <div className="meta">{student.classes?.name || 'Sans classe'} · {student.classes?.school_year || ''}</div>
          {role !== 'parent' && student.access_code && (
            <div className="meta">Code parent : <code>{student.access_code}</code></div>
          )}
        </div>
        <div className="sf-score">
          <span>{fmt(yearAvg)}</span>
          <small>{yearAvg != null ? appreciation(yearAvg, st) : 'Pas de notes'}</small>
        </div>
      </div>

      {todo.length > 0 && (
        <div className="lk-card">
          <h3><Icon name="calendar" /> À venir pour la classe</h3>
          <div className="sf-todo">
          {todo.map((x) => {
            const n = Math.round((new Date(x.due_date) - new Date(new Date().toISOString().slice(0, 10))) / 864e5);
            const d = new Date(x.due_date);
            const k = x.kind === 'devoir' ? 'mid' : 'bad';
            return (
              <div className="sf-item" key={x.id}>
                <div className={'sf-date ' + k}><b>{d.getDate()}</b><small>{d.toLocaleDateString('fr-FR', { month: 'short' }).replace('.', '')}</small></div>
                <div className="sf-info">
                  <strong>{x.title}</strong>
                  <div className="sf-sub">
                    <span className={'badge ' + k}>{x.kind === 'devoir' ? 'Devoir' : x.kind === 'examen' ? 'Examen' : 'Composition'}</span>
                    {x.subjects?.name && <span className="tag">{x.subjects.name}</span>}
                  </div>
                  {x.chapters && <span className="meta">Chapitres : {x.chapters}</span>}
                </div>
                <span className={'sf-when' + (n <= 2 ? ' soon' : '')}>{n === 0 ? "Aujourd'hui" : n === 1 ? 'Demain' : `Dans ${n} j`}</span>
              </div>
            );
          })}
          </div>
        </div>
      )}

      <div className="lk-card">
        <h3>Notes par matière</h3>
        {subjects.length === 0 ? <div className="empty">Aucune note pour le moment.</div> : (
          <div className="sf-subjects">
            {subjects.map((s) => {
              const v = subjectAvg(s.list, wD);
              const low = v != null && v < st.pass_mark;
              return (
                <div className="sf-subj" key={s.name}>
                  <div className="sf-subj-top">
                    <div><strong>{s.name}</strong><small>coef {s.coef}</small></div>
                    <span className={'sf-val' + (low ? ' low' : '')}>{fmt(v)}</span>
                  </div>
                  <div className="sf-track"><i className={low ? 'low' : ''} style={{ width: (v != null ? Math.min(100, (v / st.scale) * 100) : 0) + '%' }} /></div>
                  <div className="sf-terms">
                    {periods.map((t) => {
                      const tv = subjectAvg(s.list.filter((g) => g.term === t), wD);
                      return <span key={t} className={tv != null && tv < st.pass_mark ? 'low' : ''}>{periodShort(t, st)} <b>{fmt(tv)}</b></span>;
                    })}
                  </div>
                </div>
              );
            })}
            <div className="sf-general">
              <span>Moyenne générale</span>
              <div>{termAvgs.map((v, i) => <small key={i}>{periodShort(periods[i], st)} <b>{fmt(v)}</b></small>)}<strong>{fmt(yearAvg)}</strong></div>
            </div>
          </div>
        )}
        {grades.length > 0 && (
          <details className="lk-details">
            <summary>Voir toutes les notes ({grades.length})</summary>
            {grades.map((g) => (
              <div className="row" key={g.id}>
                <div className="person">{g.subjects?.name} <span className="tag">{g.title || (g.kind === 'devoir' ? 'Devoir' : 'Composition')} · {g.kind === 'devoir' ? 'Devoir' : 'Composition'} · {periodShort(g.term, st)}</span></div>
                <span className="score">{fmt(g.score)}/{st.scale}</span>
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
        {behav.length === 0 && att.length === 0 && <span className="meta">Rien à signaler pour le moment</span>}
        {behav.map((b) => (
          <div className="row" key={b.id}>
            <div className="person"><KindIcon k={b.kind} /> <span className={'badge ' + (b.kind === 'positif' ? 'ok' : 'bad')}>{KINDS[b.kind]?.[0]}</span> {b.comment && <span className="meta">{b.comment}</span>}</div>
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
                <div className="stat"><small>Reste à payer</small><strong className={left ? 'lk-warn' : 'lk-ok'}>{left ? fcfa(left) : 'Soldé'}</strong></div>
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
