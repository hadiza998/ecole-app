'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { fcfa, METHODS } from '../../lib/grades';
import Icon from '../components/Icon';

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
                <span>{fcfa(p.amount)} <button className="btn-small btn-danger" onClick={() => delPay(p.id)} aria-label="Supprimer"><Icon name="x" size={14} /></button></span>
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
