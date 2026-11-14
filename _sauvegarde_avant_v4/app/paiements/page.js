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
