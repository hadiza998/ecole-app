'use client';
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';

const ROLE = { admin: 'Directeur', teacher: 'Professeur', parent: 'Parent' };

export default function Profil() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [emailOn, setEmailOn] = useState(true);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (status !== 'ok') return;
    supabase.from('profiles').select('notify_email').eq('id', profile.id).maybeSingle().then(({ data }) => {
      if (data) setEmailOn(data.notify_email);
    });
  }, [status]);

  async function save(e) {
    e.preventDefault(); setMsg('');
    const { error } = await supabase.rpc('update_my_contact', { p_phone: null, p_email_on: emailOn, p_sms_on: false });
    setMsg(error ? error.message : 'Enregistré ✓');
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  return (
    <div className="lk-page">
      <div className="topbar"><div><h1>Mon profil</h1><div className="sub">Choisis comment être prévenu(e) des annonces, messages et nouvelles notes.</div></div></div>
      <div className="lk-card lk-hero">
        <div className="avatar">{profile.full_name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase()}</div>
        <div><h2>{profile.full_name}</h2><div className="meta">{ROLE[profile.role]} · {profile.email}</div></div>
      </div>
      <form className="lk-card" onSubmit={save}>
        <h3>🔔 Notifications</h3>
        <label className="lk-inline"><input type="checkbox" checked={emailOn} onChange={(e) => setEmailOn(e.target.checked)} /> <span>Recevoir un <b>email</b> ({profile.email})</span></label>
        <span className="meta">Tu reçois un email pour chaque annonce, nouveau message, nouvelle note et nouveau devoir ou examen. Les SMS arriveront plus tard.</span>
        <div className="lk-inline"><button>Enregistrer</button>{msg && <span className="meta">{msg}</span>}</div>
      </form>
    </div>
  );
}
