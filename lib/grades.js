export const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);

import { BULLETIN } from './settings';

// Moyenne d'une matière = poids devoirs × moyenne des devoirs + poids compositions × moyenne des compositions
// wD = part des devoirs (0.5 par défaut = moitié-moitié)
export function subjectAvg(grades, wD = 0.5) {
  const d = grades.filter((g) => g.kind === 'devoir').map((g) => Number(g.score));
  const c = grades.filter((g) => g.kind === 'composition').map((g) => Number(g.score));
  if (d.length && c.length) return wD * mean(d) + (1 - wD) * mean(c);
  return mean([...d, ...c].map(Number));
}
export const wDOf = (st) => (st?.weight_devoir ?? 50) / 100;

// rows : [{ avg, coef }]  -> moyenne générale pondérée
export function generalAvg(rows) {
  const ok = rows.filter((r) => r.avg != null);
  const total = ok.reduce((s, r) => s + Number(r.coef), 0);
  if (!total) return null;
  return ok.reduce((s, r) => s + r.avg * Number(r.coef), 0) / total;
}

// Mention : seuils en % du barème (80 / 70 / 60), « Passable » à partir de la note de passage
export function appreciation(avg, st, lang = 'fr') {
  if (avg == null) return '';
  const scale = st?.scale ?? 20, pass = st?.pass_mark ?? 10;
  const m = (BULLETIN[lang] || BULLETIN.fr).marks;
  const pct = (avg / scale) * 100, passPct = (pass / scale) * 100;
  if (pct >= 80 && 80 > passPct) return m[0];
  if (pct >= 70 && 70 > passPct) return m[1];
  if (pct >= 60 && 60 > passPct) return m[2];
  return avg >= pass ? m[3] : m[4];
}

export const fmt = (n) => (n == null ? '–' : Number(n).toFixed(2).replace('.', ','));
export const fcfa = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} F`;
export const METHODS = { moov: 'Moov Money', airtel: 'Airtel Money', orange: 'Orange Money', nita: 'NITA', cash: 'Espèces', virement: 'Virement' };
