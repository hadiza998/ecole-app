'use client';
import { useEffect, useState } from 'react';
import { supabase } from './supabase';
import { DEFAULTS, normalize } from './settings';

// Paramètres de l'école de l'utilisateur connecté (valeurs par défaut tant que ça charge)
export function useSettings(enabled = true) {
  const [st, setSt] = useState(DEFAULTS);
  useEffect(() => {
    if (!enabled) return;
    supabase.from('schools').select('settings').maybeSingle().then(({ data }) => { if (data?.settings) setSt(normalize(data.settings)); });
  }, [enabled]);
  return st;
}
