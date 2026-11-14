'use client';
import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { supabase } from './supabase';

// Charge le profil connecté. allowed = liste des rôles autorisés sur la page.
export function useProfile(allowed) {
  const router = useRouter();
  const pathname = usePathname();
  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState('loading');

  useEffect(() => {
    let alive = true;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) { router.replace('/login'); return; }
      // Double authentification : si le compte l'a activée, la session doit être confirmée avec le code
      const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal && aal.nextLevel === 'aal2' && aal.currentLevel !== 'aal2') { router.replace('/login'); return; }
      const { data: p } = await supabase
        .from('profiles')
        .select('id, full_name, role, school_id, active, email')
        .eq('id', data.session.user.id)
        .maybeSingle();
      if (!alive) return;
      if (!p || p.active === false) { setStatus('blocked'); return; }
      if (allowed && !allowed.includes(p.role)) { router.replace('/'); return; }
      // Le directeur doit avoir activé la double authentification
      if (p.role === 'admin' && pathname !== '/securite') {
        let ok = false;
        try { ok = sessionStorage.getItem('lk_mfa_' + p.id) === '1'; } catch {}
        if (!ok) {
          const { data: f } = await supabase.auth.mfa.listFactors();
          ok = (f?.totp || []).length > 0;
          if (ok) { try { sessionStorage.setItem('lk_mfa_' + p.id, '1'); } catch {} }
        }
        if (!ok) { router.replace('/securite?requis=1'); return; }
      }
      if (!alive) return;
      setProfile(p);
      setStatus('ok');
    })();
    return () => { alive = false; };
  }, []);

  return { profile, status };
}

export function Blocked() {
  return (
    <div className="lk-page"><div className="lk-card">
      <h2>Compte inactif</h2>
      <p className="meta">Ton compte est introuvable ou a été désactivé par le directeur de l'école.</p>
      <button className="btn-ghost" onClick={async () => { await supabase.auth.signOut(); window.location.href = '/login'; }}>Se déconnecter</button>
    </div></div>
  );
}
