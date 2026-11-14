import { supabase } from './supabase';

// Demande au serveur d'envoyer les emails / SMS en attente (sans bloquer l'écran).
export function pingNotify() {
  supabase.auth.getSession().then(({ data }) => {
    if (!data.session) return;
    fetch('/api/notify', { method: 'POST', headers: { Authorization: `Bearer ${data.session.access_token}` } }).catch(() => {});
  });
}

// Demande au menu de rafraîchir ses pastilles (messages non lus, annonces)
export const refreshBadges = () => { if (typeof window !== 'undefined') window.dispatchEvent(new Event('lakol:refresh')); };
