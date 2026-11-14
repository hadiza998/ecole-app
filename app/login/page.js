'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';
import Logo, { Wordmark } from '../components/Logo';
import MfaCode from '../components/MfaCode';
import Icon from '../components/Icon';

const ROLES = [['admin', 'school', 'Directeur'], ['teacher', 'book', 'Professeur'], ['parent', 'users', 'Parent']];

export default function Login() {
  const router = useRouter();
  const [mode, setMode] = useState('in');
  const [role, setRole] = useState('admin');
  const [f, setF] = useState({ email: '', password: '', full_name: '', school_name: '', city: '', school_code: '', student_code: '' });
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [info, setInfo] = useState('');
  const [needCode, setNeedCode] = useState(false);
  const [show, setShow] = useState(false);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  // Déjà connecté (ou retour du lien de confirmation par email) : on continue, ou on demande le code à 6 chiffres
  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) return;
      const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') setNeedCode(true); else router.replace('/');
    })();
  }, []);

  async function afterLogin() {
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') return setNeedCode(true);
    router.replace('/');
  }

  async function forgot(e) {
    e.preventDefault(); setErr(''); setInfo('');
    if (!f.email.trim()) return setErr('Écris ton email.');
    setBusy(true);
    await supabase.auth.resetPasswordForEmail(f.email.trim(), { redirectTo: window.location.origin + '/reinitialiser' });
    setBusy(false);
    setInfo('Si un compte existe avec cet email, un message vient de partir avec un lien pour choisir un nouveau mot de passe.');
  }

  async function submit(e) {
    e.preventDefault(); setErr(''); setInfo('');
    if (mode === 'forgot') return forgot(e);
    if (mode === 'up' && (f.password.length < 10 || !/[A-Za-z]/.test(f.password) || !/[0-9]/.test(f.password))) {
      return setErr('Choisis un mot de passe d\'au moins 10 caractères, avec des lettres et des chiffres.');
    }
    setBusy(true);
    let res;
    if (mode === 'in') {
      res = await supabase.auth.signInWithPassword({ email: f.email.trim(), password: f.password });
    } else {
      res = await supabase.auth.signUp({
        email: f.email.trim(), password: f.password,
        options: { emailRedirectTo: window.location.origin + '/login', data: { role, full_name: f.full_name, school_name: f.school_name, city: f.city, school_code: f.school_code, student_code: f.student_code } },
      });
    }
    setBusy(false);
    if (res.error) {
      const m = res.error.message || '';
      if (/already registered/i.test(m)) setErr('Cet email a déjà un compte. Clique sur « Se connecter ».');
      else if (/Invalid login/i.test(m)) setErr('Email ou mot de passe incorrect.');
      else if (/Database error/i.test(m)) setErr("Code invalide. Vérifie le code de l'école (professeur) ou le code de l'élève (parent).");
      else if (/at least|weak|password/i.test(m)) setErr('Mot de passe refusé : choisis-en un plus long (10 caractères minimum, lettres et chiffres).');
      else if (/not confirmed/i.test(m)) setErr('Ton email n\'est pas encore confirmé. Ouvre le message que nous t\'avons envoyé et clique sur le lien.');
      else if (/rate limit|too many/i.test(m)) setErr('Trop d\'essais. Attends quelques minutes puis réessaie.');
      else setErr(m);
      return;
    }
    if (!res.data.session) { setInfo('Compte créé. Nous t\'avons envoyé un email : clique sur le lien pour confirmer ton adresse, puis connecte-toi ici.'); setMode('in'); return; }
    afterLogin();
  }

  return (
    <div className="auth">
      <div className="auth-hero">
        <div className="lk-brand"><Logo size={42} id="lgl" /><Wordmark height={26} /></div>
        <div className="lk-stack">
          <h1>La gestion de ton école, simple et moderne.</h1>
          <p>Notes, bulletins, scolarité, emplois du temps : tout au même endroit, pour le directeur, les professeurs et les parents.</p>
          <div className="auth-feats"><span><Icon name="check" size={15} /> Notes et bulletins en quelques clics</span><span><Icon name="check" size={15} /> Suivi de la scolarité en FCFA</span><span><Icon name="check" size={15} /> Devoirs, présence et comportement</span></div>
        </div>
        <span />
      </div>
      <div className="auth-form">
        {/* en-tête affiché seulement sur téléphone */}
        <div className="auth-mobile"><Wordmark height={24} /></div>
        <div className="auth-sheet">
        <div className="auth-card">
        <div className="auth-arch-logo"><Logo size={66} id="lgm" /></div>
        {needCode ? <MfaCode onDone={() => router.replace('/')} onCancel={async () => { await supabase.auth.signOut(); setNeedCode(false); }} /> :
        <form className="auth-box" onSubmit={submit}>
          <h1>{mode === 'in' ? 'Bon retour' : mode === 'forgot' ? 'Mot de passe oublié' : 'Créer un compte'}</h1>
          <p className="meta" style={{ margin: 0 }}>{mode === 'in' ? 'Connecte-toi pour continuer.' : mode === 'forgot' ? 'Écris ton email : nous t\'envoyons un lien pour en choisir un nouveau.' : 'Choisis ton profil.'}</p>
          {mode === 'up' && (
            <>
              <div className="roles">
                {ROLES.map(([k, ic, l]) => <button type="button" key={k} className={role === k ? 'on' : ''} onClick={() => setRole(k)}><Icon name={ic} size={24} />{l}</button>)}
              </div>
              <input placeholder="Ton nom complet" value={f.full_name} onChange={set('full_name')} required autoComplete="name" />
              {role === 'admin' && <><input placeholder="Nom de l'école" value={f.school_name} onChange={set('school_name')} required /><input placeholder="Ville" value={f.city} onChange={set('city')} autoComplete="address-level2" /></>}
              {role === 'teacher' && <input placeholder="Code de l'école (donné par le directeur)" value={f.school_code} onChange={set('school_code')} required autoCapitalize="characters" autoCorrect="off" />}
              {role === 'parent' && <input placeholder="Code de l'élève (donné par l'école)" value={f.student_code} onChange={set('student_code')} required autoCapitalize="characters" autoCorrect="off" />}
            </>
          )}
          <input type="email" inputMode="email" placeholder="Email" value={f.email} onChange={set('email')} required autoComplete="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} />
          {mode !== 'forgot' && (
            <div className="pw">
              <input type={show ? 'text' : 'password'} placeholder="Mot de passe" value={f.password} onChange={set('password')} required autoComplete={mode === 'up' ? 'new-password' : 'current-password'} autoCapitalize="none" />
              <button type="button" className="pw-eye" onClick={() => setShow(!show)} aria-label={show ? 'Cacher le mot de passe' : 'Voir le mot de passe'}><Icon name={show ? 'eyeoff' : 'eye'} /></button>
            </div>
          )}
          {mode === 'up' && <span className="meta" style={{ marginTop: -6 }}>Au moins 10 caractères, avec des lettres et des chiffres.</span>}
          {err && <div className="notice">{err}</div>}
          {info && <div className="notice ok">{info}</div>}
          <button disabled={busy}>{busy ? 'Un instant…' : mode === 'in' ? 'Se connecter' : mode === 'forgot' ? 'Envoyer le lien' : 'Créer mon compte'}</button>
          {mode === 'in' && <button type="button" className="btn-link" onClick={() => { setMode('forgot'); setErr(''); setInfo(''); }}>Mot de passe oublié ?</button>}
        </form>}
        </div>
        {!needCode && (
          <div className="auth-switch">
            {mode === 'in' ? 'Nouveau sur Lakol ?' : mode === 'forgot' ? 'Tu t\'en souviens ?' : 'Tu as déjà un compte ?'}{' '}
            <button type="button" className="btn-link" onClick={() => { setMode(mode === 'in' ? 'up' : 'in'); setErr(''); setInfo(''); }}>
              {mode === 'in' ? 'Créer un compte' : 'Se connecter'}
            </button>
          </div>
        )}
        </div>
      </div>
    </div>
  );
}
