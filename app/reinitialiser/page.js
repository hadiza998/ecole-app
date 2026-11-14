'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../lib/supabase';
import Logo from '../components/Logo';
import MfaCode from '../components/MfaCode';

// Page ouverte depuis le lien « mot de passe oublié » reçu par email
export default function Reinitialiser() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [needCode, setNeedCode] = useState(false);
  const [pw, setPw] = useState(''); const [pw2, setPw2] = useState('');
  const [err, setErr] = useState(''); const [ok, setOk] = useState(false); const [busy, setBusy] = useState(false);

  async function check() {
    const { data } = await supabase.auth.getSession();
    if (!data.session) return false;
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    setNeedCode(!!(aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2'));
    setReady(true);
    return true;
  }
  useEffect(() => {
    check();
    const { data: sub } = supabase.auth.onAuthStateChange((ev) => { if (ev === 'PASSWORD_RECOVERY' || ev === 'SIGNED_IN') check(); });
    const t = setTimeout(async () => { if (!(await check())) setErr('Ce lien est expiré ou déjà utilisé. Retourne à la connexion et demande un nouveau lien.'); }, 4000);
    return () => { sub.subscription.unsubscribe(); clearTimeout(t); };
  }, []);

  async function submit(e) {
    e.preventDefault(); setErr('');
    if (pw.length < 10 || !/[A-Za-z]/.test(pw) || !/[0-9]/.test(pw)) return setErr('Au moins 10 caractères, avec des lettres et des chiffres.');
    if (pw !== pw2) return setErr('Les deux mots de passe ne sont pas identiques.');
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) return setErr(error.message);
    setOk(true); setTimeout(() => router.replace('/'), 1500);
  }

  return (
    <div className="auth">
      <div className="auth-hero"><div className="lk-brand"><Logo size={42} id="lgr" />Lakol</div><span /><span /></div>
      <div className="auth-form">
        {ready && needCode ? <MfaCode onDone={() => setNeedCode(false)} /> : (
          <form className="auth-box" onSubmit={submit}>
            <h1>Nouveau mot de passe</h1>
            {!ready && !err && <p className="meta">Vérification du lien…</p>}
            {ready && !ok && (<>
              <input type="password" placeholder="Nouveau mot de passe (10 caractères min.)" value={pw} onChange={(e) => setPw(e.target.value)} autoComplete="new-password" required />
              <input type="password" placeholder="Répète le mot de passe" value={pw2} onChange={(e) => setPw2(e.target.value)} autoComplete="new-password" required />
              <button disabled={busy}>{busy ? '…' : 'Enregistrer'}</button>
            </>)}
            {ok && <div className="notice" style={{ background: '#E8FBF3', color: '#0B6B4B' }}>Mot de passe changé ✓ Redirection…</div>}
            {err && <div className="notice">{err}</div>}
            <button type="button" className="btn-ghost" onClick={() => router.replace('/login')}>Retour à la connexion</button>
          </form>
        )}
      </div>
    </div>
  );
}
