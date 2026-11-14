'use client';
import { useState } from 'react';
import { supabase } from '../../lib/supabase';

// Demande le code à 6 chiffres de l'application d'authentification (Google Authenticator, etc.)
export default function MfaCode({ onDone, onCancel }) {
  const [code, setCode] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault(); setErr(''); setBusy(true);
    const { data: f } = await supabase.auth.mfa.listFactors();
    const factors = f?.totp || [];
    if (!factors.length) { setBusy(false); return setErr('Aucun appareil enregistré sur ce compte.'); }
    let ok = false;
    for (const fac of factors) {
      const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: fac.id, code: code.trim() });
      if (!error) { ok = true; break; }
    }
    setBusy(false);
    if (!ok) return setErr('Code incorrect ou expiré. Utilise le code actuel affiché dans ton application.');
    onDone();
  }

  return (
    <form className="auth-box" onSubmit={submit}>
      <h1>Vérification en 2 étapes</h1>
      <p className="meta" style={{ margin: 0 }}>Ouvre ton application d'authentification et écris le code à 6 chiffres de Lakol.</p>
      <input inputMode="numeric" autoComplete="one-time-code" autoFocus maxLength={6} placeholder="000000" value={code}
        onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} style={{ textAlign: 'center', fontSize: '1.5rem', letterSpacing: '.4em' }} />
      {err && <div className="notice">{err}</div>}
      <button disabled={busy || code.length !== 6}>{busy ? '…' : 'Valider'}</button>
      {onCancel && <button type="button" className="btn-ghost" onClick={onCancel}>Annuler</button>}
    </form>
  );
}
