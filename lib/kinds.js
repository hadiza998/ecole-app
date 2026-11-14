import Icon from '../app/components/Icon';

// [libellé, nom d'icône]
export const KINDS = {
  bavardage: ['Bavardage', 'chat'], perturbation: ['Perturbation', 'bolt'], retard: ['Retard', 'clock'],
  oubli_materiel: ['Oubli de matériel', 'bag'], insolence: ['Insolence', 'frown'], positif: ['Félicitations', 'star'], autre: ['Autre', 'edit'],
};

export function KindIcon({ k }) {
  return <Icon name={(KINDS[k] || [])[1] || 'edit'} size={15} />;
}
