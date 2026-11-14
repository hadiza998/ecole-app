export default function Logo({ size = 36, id = 'lg' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-label="Lakol" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#8B5CF6" /><stop offset="1" stopColor="#22D3EE" />
        </linearGradient>
      </defs>
      <rect width="40" height="40" rx="13" fill={`url(#${id})`} />
      <path d="M8 14c4.2-1.7 8.2-1 12 1.6V30c-3.8-2.6-7.8-3.3-12-1.6z" fill="#fff" />
      <path d="M32 14c-4.2-1.7-8.2-1-12 1.6V30c3.8-2.6 7.8-3.3 12-1.6z" fill="#fff" opacity=".78" />
      <circle cx="31" cy="9" r="3.2" fill="#FF8A5B" />
      <circle cx="9.5" cy="9.5" r="1.6" fill="#fff" opacity=".7" />
    </svg>
  );
}
