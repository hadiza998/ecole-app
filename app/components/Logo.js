// Logo Lakol : une arche (la porte de l'école) avec un L dedans, et un point corail.
// Logo = la tuile sombre seule. Wordmark = le nom « lakol. » dessiné en traits.
export default function Logo({ size = 36, id = 'lg', tile = 'dark' }) {
  const bg = tile === 'violet' ? '#6D4AFF' : '#14102E';
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-label="Lakol" role="img" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={tile === 'violet' ? '#FFFFFF' : '#8B5CF6'} />
          <stop offset="1" stopColor={tile === 'violet' ? '#BAF3FA' : '#22D3EE'} />
        </linearGradient>
      </defs>
      <rect width="48" height="48" rx="15" fill={bg} />
      {tile === 'dark' && <rect x=".5" y=".5" width="47" height="47" rx="14.5" fill="none" stroke="#fff" strokeOpacity=".14" />}
      <path d="M11 39V22a13 13 0 0 1 26 0v17z" fill="none" stroke="#fff" strokeWidth="3.6" strokeLinejoin="round" />
      <path d="M20 17v15h9" fill="none" stroke={`url(#${id})`} strokeWidth="4.6" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="31.5" cy="18.5" r="2.7" fill="#FF7A59" />
    </svg>
  );
}

export function Wordmark({ height = 22, color = 'currentColor' }) {
  return (
    <svg height={height} viewBox="-2 0 86 30" role="img" aria-label="lakol" style={{ flexShrink: 0, overflow: 'visible' }}>
      <g fill="none" stroke={color} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 4v22" /><circle cx="17" cy="19" r="7" /><path d="M24 12v14" />
        <path d="M31 4v22M41 12L31 20.5M34.5 18.2L42 26" /><circle cx="55" cy="19" r="7" /><path d="M69 4v22" />
      </g>
      <circle cx="77.5" cy="24.5" r="2.7" fill="#FF7A59" />
    </svg>
  );
}
