'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { useSettings } from '../../lib/useSettings';
import { PRESETS, DEFAULTS, periodWord } from '../../lib/settings';
import { appreciation, fmt } from '../../lib/grades';

const Row = ({ label, hint, children }) => (
  <div style={{ display: 'grid', gap: 4, padding: '10px 0', borderBottom: '1px solid var(--line)' }}>
    <b>{label}</b>
    {hint && <span className="meta">{hint}</span>}
    <div className="lk-inline" style={{ flexWrap: 'wrap' }}>{children}</div>
  </div>
);

export default function Parametres() {
  const { profile, status } = useProfile(['admin']);
  const saved = useSettings(status === 'ok');
  const [f, setF] = useState(DEFAULTS);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const [classes, setClasses] = useState([]);
  const [cid, setCid] = useState('');
  const [subs, setSubs] = useState([]);
  const [cm, setCm] = useState('');

  useEffect(() => { setF(saved); }, [saved]);
  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('classes').select('id, name').order('name').then(({ data }) => { setClasses(data || []); if (data?.length) setCid(data[0].id); });
  }, [status]);

  async function loadSubs() {
    if (!cid) return setSubs([]);
    const [t, c] = await Promise.all([
      supabase.from('teaching').select('subject_id, subjects(id, name, coefficient)').eq('class_id', cid),
      supabase.from('class_coefficients').select('subject_id, coefficient').eq('class_id', cid),
    ]);
    const over = Object.fromEntries((c.data || []).map((x) => [x.subject_id, Number(x.coefficient)]));
    const seen = new Set(), list = [];
    (t.data || []).forEach((x) => { if (x.subjects && !seen.has(x.subject_id)) { seen.add(x.subject_id); list.push({ ...x.subjects, custom: over[x.subject_id] }); } });
    setSubs(list.sort((a, b) => a.name.localeCompare(b.name)));
  }
  useEffect(() => { loadSubs(); setCm(''); }, [cid]);

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const set = (k, v) => setF((p) => ({ ...p, [k]: v }));
  const applyPreset = (p) => { setF((x) => ({ ...x, ...p.values })); setMsg({ ok: true, t: `Modèle « ${p.label} » appliqué. Vérifie puis clique sur Enregistrer.` }); };

  async function save() {
    setBusy(true); setMsg(null);
    const { error } = await supabase.rpc('update_school_settings', { p_settings: {
      period_name: f.period_name, periods: Number(f.periods), scale: Number(f.scale), weight_devoir: Number(f.weight_devoir),
      pass_mark: Number(String(f.pass_mark).replace(',', '.')), show_rank: !!f.show_rank, language: f.language, bulletin_header: f.bulletin_header || '',
    } });
    setBusy(false);
    setMsg(error ? { ok: false, t: error.message } : { ok: true, t: 'Paramètres enregistrés. Ils s\'appliquent partout (notes, bulletins, tableau de bord).' });
  }

  async function saveCoef(s, value) {
    const v = value.trim().replace(',', '.');
    if (v === '' && s.custom == null) return;
    if (v === '') await supabase.from('class_coefficients').delete().eq('class_id', cid).eq('subject_id', s.id);
    else {
      const n = Number(v);
      if (!(n > 0 && n <= 20)) return setCm('Le coefficient doit être entre 0,5 et 20.');
      if (n === s.custom) return;
      const { error } = await supabase.from('class_coefficients').upsert({ class_id: cid, subject_id: s.id, coefficient: n });
      if (error) return setCm(error.message);
    }
    setCm('Enregistré'); loadSubs();
  }

  // Exemple en direct : devoirs à 60 % du barème, composition à 75 %
  const wD = Number(f.weight_devoir) / 100, scale = Number(f.scale) || 20;
  const exD = scale * 0.6, exC = scale * 0.75, exAvg = wD * exD + (1 - wD) * exC;
  const pw = periodWord(f);

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Paramètres de l'école</h1><div className="sub">Adapte Lakol à la façon de travailler de ton école. Seul le directeur voit cette page.</div></div></div>

      <div className="lk-card">
        <h3>Modèle de départ</h3>
        <div className="lk-inline" style={{ flexWrap: 'wrap' }}>
          {PRESETS.map((p) => <button key={p.id} type="button" className="btn-ghost" onClick={() => applyPreset(p)}>{p.label}<br /><small style={{ opacity: .7 }}>{p.hint}</small></button>)}
        </div>
      </div>

      <div className="lk-card">
        <h3>Notes et bulletins</h3>
        <Row label="Découpage de l'année">
          <div className="tabs">{[['trimestre', 'Trimestres'], ['semestre', 'Semestres']].map(([k, l]) => <button key={k} type="button" className={f.period_name === k ? 'on' : ''} onClick={() => set('period_name', k)}>{l}</button>)}</div>
          <select value={f.periods} onChange={(e) => set('periods', Number(e.target.value))} style={{ maxWidth: 160 }}>{[2, 3, 4].map((n) => <option key={n} value={n}>{n} périodes</option>)}</select>
        </Row>
        <Row label="Barème des notes" hint="Les notes déjà saisies ne sont pas converties : change le barème avant la saisie.">
          <div className="tabs">{[10, 20, 100].map((n) => <button key={n} type="button" className={Number(f.scale) === n ? 'on' : ''} onClick={() => set('scale', n)}>/{n}</button>)}</div>
        </Row>
        <Row label="Poids des devoirs dans la moyenne" hint={`Le reste va aux compositions. Si une matière n'a que des devoirs (ou que des compositions), la moyenne est simple.`}>
          <input type="range" min="0" max="100" step="5" value={f.weight_devoir} onChange={(e) => set('weight_devoir', Number(e.target.value))} style={{ maxWidth: 260 }} />
          <b>Devoirs {f.weight_devoir} % · Compositions {100 - f.weight_devoir} %</b>
        </Row>
        <Row label={`Note de passage (sur ${scale})`} hint="Sert aux mentions et aux couleurs (rouge en dessous).">
          <input inputMode="decimal" value={f.pass_mark} onChange={(e) => set('pass_mark', e.target.value)} style={{ maxWidth: 110 }} />
        </Row>
        <Row label="Rang dans la classe sur le bulletin">
          <label className="lk-inline"><input type="checkbox" checked={!!f.show_rank} onChange={(e) => set('show_rank', e.target.checked)} /> Afficher le rang</label>
        </Row>
        <Row label="Langue du bulletin" hint="Titres et mentions du document (PDF, Word, impression). L'arabe viendra plus tard.">
          <select value={f.language} onChange={(e) => set('language', e.target.value)} style={{ maxWidth: 200 }}><option value="fr">Français</option><option value="en">English</option></select>
        </Row>
        <Row label="En-tête du bulletin (en haut à gauche)" hint="Ex. nom du pays et devise, ou « Ministère de l'Éducation ». Une ligne par retour à la ligne.">
          <textarea rows={2} maxLength={160} value={f.bulletin_header} onChange={(e) => set('bulletin_header', e.target.value)} style={{ width: '100%' }} />
        </Row>

        <div className="lk-grid-box" style={{ marginTop: 14 }}>
          <b>Exemple avec ces réglages</b>
          <div className="meta">Un élève a {fmt(exD)}/{scale} en devoirs et {fmt(exC)}/{scale} en composition. Moyenne de la matière : <b>{fmt(exAvg)}/{scale}</b> — {appreciation(exAvg, { scale, pass_mark: Number(String(f.pass_mark).replace(',', '.')) || 0 }, f.language)}.</div>
        </div>

        <div className="lk-inline" style={{ marginTop: 14 }}>
          <button onClick={save} disabled={busy}>{busy ? 'Enregistrement…' : 'Enregistrer les paramètres'}</button>
          {msg && <span className={msg.ok ? 'lk-ok' : 'lk-low'}>{msg.t}</span>}
        </div>
      </div>

      <div className="lk-card">
        <h3>Coefficients par classe</h3>
        <p className="meta">La 6e et la terminale n'ont pas les mêmes coefficients. Laisse vide pour garder le coefficient normal de la matière.</p>
        <div className="lk-inline">
          <select value={cid} onChange={(e) => setCid(e.target.value)}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
          {cm && <span className="meta">{cm}</span>}
        </div>
        {subs.length === 0 && <div className="empty">Aucune matière pour cette classe (un professeur doit d'abord la choisir).</div>}
        {subs.map((s) => (
          <div className="row" key={cid + s.id}>
            <div className="person">{s.name} <span className="tag">normal : {s.coefficient}</span></div>
            <input inputMode="decimal" defaultValue={s.custom ?? ''} placeholder={String(s.coefficient)} style={{ maxWidth: 90 }}
              onBlur={(e) => saveCoef(s, e.target.value)} onKeyDown={(e) => e.key === 'Enter' && e.target.blur()} />
          </div>
        ))}
      </div>
    </div>
  );
}
