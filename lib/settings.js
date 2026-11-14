// Paramètres de l'école : valeurs par défaut, modèles de départ, libellés
export const DEFAULTS = {
  period_name: 'trimestre', periods: 3, scale: 20, weight_devoir: 50, pass_mark: 10, show_rank: true, language: 'fr',
  bulletin_header: 'République du Niger\nFraternité · Travail · Progrès',
};

export const PRESETS = [
  { id: 'niger', label: 'Standard Niger', hint: '3 trimestres · /20 · passage 10', values: { period_name: 'trimestre', periods: 3, scale: 20, weight_devoir: 50, pass_mark: 10, language: 'fr' } },
  { id: 'semestres', label: 'Semestres', hint: '2 semestres · /20 · passage 10', values: { period_name: 'semestre', periods: 2, scale: 20, weight_devoir: 50, pass_mark: 10, language: 'fr' } },
  { id: 'anglophone', label: 'Anglophone', hint: '3 terms · /100 · passage 50 · bulletin en anglais', values: { period_name: 'trimestre', periods: 3, scale: 100, weight_devoir: 40, pass_mark: 50, language: 'en' } },
];

export const normalize = (s) => ({ ...DEFAULTS, ...(s || {}) });

const WORDS = {
  fr: { trimestre: 'trimestre', semestre: 'semestre', ord: (n) => (n === 1 ? '1er' : `${n}e`), year: 'ANNÉE', yearLong: 'Année complète' },
  en: { trimestre: 'term', semestre: 'semester', ord: (n) => ({ 1: '1st', 2: '2nd', 3: '3rd' }[n] || `${n}th`), year: 'FULL YEAR', yearLong: 'Full year' },
};
const W = (lang) => WORDS[lang] || WORDS.fr;

export const periodWord = (st, lang = 'fr') => W(lang)[st.period_name] || 'trimestre'; // « trimestre » / « term »
export const periodTitle = (n, st, lang = 'fr') => `${W(lang).ord(n)} ${periodWord(st, lang)}`; // « 2e trimestre »
export const periodShort = (n, st) => `${st.period_name === 'semestre' ? 'S' : 'T'}${n}`; // « T2 »
export const periodTab = (n, st) => { const w = periodWord(st); return `${w[0].toUpperCase()}${w.slice(1)} ${n}`; }; // « Trimestre 2 »
export const periodList = (st) => Array.from({ length: st.periods }, (_, i) => i + 1);
export const yearLabel = (lang = 'fr') => W(lang).yearLong;
export const yearUpper = (lang = 'fr') => W(lang).year;

// Période correspondant à une date (année scolaire septembre → août)
export function termOfDate(date, st) {
  const m = Number(String(date).slice(5, 7));
  if (st.periods === 2) return m >= 9 || m === 1 ? 1 : 2;
  if (st.periods === 4) return m >= 9 && m <= 11 ? 1 : m === 12 || m <= 2 ? 2 : m <= 5 ? 3 : 4;
  return m >= 9 ? 1 : m <= 3 ? 2 : 3;
}

// Mots du bulletin
export const BULLETIN = {
  fr: { title: 'BULLETIN DE NOTES', student: 'Élève', cls: 'Classe', subject: 'Matière', coef: 'Coef', dev: 'Devoirs', comp: 'Composition', avg: 'Moyenne', points: 'Points', remark: 'Appréciation',
    general: 'Moyenne générale', rank: 'Rang', none: 'Aucune note', teacher: 'Le professeur principal', director: 'Le Directeur', parents: 'Les parents', of: 'sur',
    marks: ['Très bien', 'Bien', 'Assez bien', 'Passable', 'Insuffisant'] },
  en: { title: 'REPORT CARD', student: 'Student', cls: 'Class', subject: 'Subject', coef: 'Coef.', dev: 'Tests', comp: 'Exams', avg: 'Average', points: 'Points', remark: 'Remark',
    general: 'Overall average', rank: 'Rank', none: 'No grades', teacher: 'Class teacher', director: 'Principal', parents: 'Parents', of: 'of',
    marks: ['Excellent', 'Very good', 'Good', 'Pass', 'Fail'] },
};

export const ordinal = (n, lang = 'fr') => W(lang).ord(n);
