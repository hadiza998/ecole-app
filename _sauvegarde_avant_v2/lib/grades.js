export const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);

// Moyenne d'une matière = (moyenne des devoirs + composition) / 2
export function subjectAvg(grades) {
  const d = grades.filter((g) => g.kind === 'devoir').map((g) => Number(g.score));
  const c = grades.filter((g) => g.kind === 'composition').map((g) => Number(g.score));
  if (d.length && c.length) return (mean(d) + mean(c)) / 2;
  return mean([...d, ...c].map(Number));
}

// rows : [{ avg, coef }]  -> moyenne générale pondérée
export function generalAvg(rows) {
  const ok = rows.filter((r) => r.avg != null);
  const total = ok.reduce((s, r) => s + Number(r.coef), 0);
  if (!total) return null;
  return ok.reduce((s, r) => s + r.avg * Number(r.coef), 0) / total;
}

export function appreciation(avg) {
  if (avg == null) return '';
  if (avg >= 16) return 'Très bien';
  if (avg >= 14) return 'Bien';
  if (avg >= 12) return 'Assez bien';
  if (avg >= 10) return 'Passable';
  return 'Insuffisant';
}

export const fmt = (n) => (n == null ? '–' : Number(n).toFixed(2).replace('.', ','));
export const fcfa = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} F`;
export const METHODS = { moov: 'Moov Money', airtel: 'Airtel Money', orange: 'Orange Money', nita: 'NITA', cash: 'Espèces', virement: 'Virement' };
