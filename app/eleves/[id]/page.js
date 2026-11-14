'use client';
import { useParams, useRouter } from 'next/navigation';
import StudentFile from '../../components/StudentFile';
import { useProfile, Blocked } from '../../../lib/useProfile';
import Icon from '../../components/Icon';

export default function FicheEleve() {
  const { id } = useParams();
  const router = useRouter();
  const { profile, status } = useProfile(['admin', 'teacher']);
  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;
  return (
    <div className="lk-page">
      <button className="btn-ghost btn-small" onClick={() => router.back()}><Icon name="back" size={16} /> Retour</button>
      <StudentFile studentId={id} role={profile.role} />
    </div>
  );
}
