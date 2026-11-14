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
