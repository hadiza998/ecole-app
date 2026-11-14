'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import Icon from '../components/Icon';

export default function Securite() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [factors, setFactors] = useState([]);
  const [enroll, setEnroll] = useState(null);
  const [code, setCode] = useState('');
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const isAdmin = profile?.role === 'admin';

  async function load() {
    const { data } = await supabase.auth.mfa.listFactors();
    setFactors(data?.totp || []);
  }
  useEffect(() => { if (status === 'ok') load(); }, [status]);

  async function start() {
    setMsg(null); setBusy(true);
    const { data: all } = await supabase.auth.mfa.listFactors();
    for (const f of (all?.all || []).filter((x) => x.status === 'unverified')) await supabase.auth.mfa.unenroll({ factorId: f.id });
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'Lakol ' + new Date().toISOString().slice(0, 16).replace('T', ' ') });
    setBusy(false);
    if (error) return setMsg({ ok: false, t: error.message });
    setEnroll({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
    setCode('');
  }

  async function verify(e) {
    e.preventDefault(); setMsg(null); setBusy(true);
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: enroll.id, code: code.trim() });
    setBusy(false);
    if (error) return setMsg({ ok: false, t: 'Code incorrect. Vérifie l\'heure de ton téléphone et réessaie avec le code actuel.' });
    setEnroll(null); setCode('');
    await load();
    setMsg({ ok: true, t: 'Double authentification activée.' });
  }

  async function remove(f) {
    if (!window.confirm('Retirer cet appareil ? Tu ne pourras plus l\'utiliser pour te connecter.')) return;
    const { error } = await supabase.auth.mfa.unenroll({ factorId: f.id });
    if (error) return setMsg({ ok: false, t: error.message });
    await load(); setMsg({ ok: true, t: 'Appareil retiré.' });
  }

  async function cancel() {
    if (enroll) await supabase.auth.mfa.unenroll({ factorId: enroll.id });
    setEnroll(null); setMsg(null);
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  const active = factors.length > 0;

  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Sécurité du compte</h1><div className="sub">Protège ton compte avec un code à 6 chiffres en plus du mot de passe.</div></div></div>

      {isAdmin && !active && (
        <div className="notice"><Icon name="shield" /> Conseil : en tant que directeur, tu gères les données de tous les élèves. Activer la double authentification est fortement recommandé, mais ce n'est pas obligatoire. Ça prend 2 minutes.</div>
      )}

      <div className="lk-card">
        <h3>Double authentification {active ? <span className="badge ok">Activée</span> : <span className="badge bad">Désactivée</span>}</h3>
        {!active && !enroll && (
          <>
            <p className="meta">Même si quelqu'un trouve ton mot de passe, il ne pourra pas entrer sans le code de ton téléphone. Il te faut une application d'authentification (Google Authenticator, Microsoft Authenticator, Authy…).</p>
            <div className="lk-inline"><button onClick={start} disabled={busy}>{busy ? '…' : 'Activer la double authentification'}</button></div>
          </>
        )}

        {enroll && (
          <form onSubmit={verify} className="lk-grid-box" style={{ display: 'grid', gap: 12 }}>
            <b>1. Scanne ce QR code avec ton application d'authentification</b>
            <img src={enroll.qr} alt="QR code" width={190} height={190} style={{ background: '#fff', padding: 8, borderRadius: 12 }} />
            <span className="meta">Tu ne peux pas scanner ? Écris cette clé dans l'application : <code style={{ wordBreak: 'break-all' }}>{enroll.secret}</code></span>
            <b>2. Écris le code à 6 chiffres affiché</b>
            <input inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="000000" value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
              style={{ maxWidth: 200, textAlign: 'center', fontSize: '1.4rem', letterSpacing: '.35em' }} />
            <div className="lk-inline"><button disabled={busy || code.length !== 6}>{busy ? '…' : 'Confirmer'}</button><button type="button" className="btn-ghost" onClick={cancel}>Annuler</button></div>
          </form>
        )}

        {active && !enroll && (
          <>
            <p className="meta">À chaque connexion, Lakol te demandera le code de ton application.</p>
            {factors.map((f) => (
              <div className="row" key={f.id}>
                <div className="person"><Icon name="phone" /> {f.friendly_name || 'Appareil'} <span className="meta">ajouté le {new Date(f.created_at).toLocaleDateString('fr-FR')}</span></div>
                <button className="btn-ghost" onClick={() => remove(f)}>Retirer</button>
              </div>
            ))}
            {factors.length === 1 && <p className="meta">Conseil : ajoute un 2e appareil pour ne pas être bloqué si tu perds ton téléphone.</p>}
            <div className="lk-inline"><button className="btn-ghost" onClick={start} disabled={busy}><Icon name="plus" /> Ajouter un autre appareil</button></div>
          </>
        )}
        {msg && <div className={msg.ok ? 'lk-ok' : 'lk-low'} style={{ marginTop: 10 }}>{msg.t}</div>}
      </div>
    </div>
  );
}
