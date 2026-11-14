'use client';
import { useState } from 'react';

// "Combien d'élèves ?" -> des cases vides apparaissent pour écrire les noms.
export default function StudentGrid({ rows, setRows }) {
  const [count, setCount] = useState('');

  function generate() {
    const n = Math.max(0, Math.min(200, parseInt(count, 10) || 0));
    if (!n) return;
    const next = rows.slice(0, n);
    while (next.length < n) next.push({ last: '', first: '' });
    setRows(next);
  }
  const update = (i, k, v) => setRows(rows.map((r, j) => (j === i ? { ...r, [k]: v } : r)));
  const remove = (i) => setRows(rows.filter((_, j) => j !== i));

  return (
    <div className="lk-grid-box">
      <div className="lk-inline">
        <label className="lk-label">Combien d'élèves dans la classe ?</label>
        <input type="number" min="1" max="200" placeholder="ex. 35" value={count}
          onChange={(e) => setCount(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); generate(); } }}
          style={{ maxWidth: 120 }} />
        <button type="button" className="btn-ghost" onClick={generate}>Créer les cases</button>
      </div>

      {rows.length > 0 && (
        <>
          <div className="lk-rows">
            {rows.map((r, i) => (
              <div className="lk-rowline" key={i}>
                <span className="lk-num">{i + 1}</span>
                <input placeholder="Nom" value={r.last} onChange={(e) => update(i, 'last', e.target.value)} />
                <input placeholder="Prénom" value={r.first} onChange={(e) => update(i, 'first', e.target.value)} />
                <button type="button" className="btn-small btn-danger" title="Retirer" onClick={() => remove(i)}>✕</button>
              </div>
            ))}
          </div>
          <div className="lk-inline">
            <button type="button" className="btn-ghost btn-small"
              onClick={() => setRows([...rows, { last: '', first: '' }])}>+ Ajouter une case</button>
            <span className="meta">{rows.filter((r) => r.last.trim() || r.first.trim()).length} / {rows.length} remplie(s)</span>
          </div>
        </>
      )}
    </div>
  );
}

export const filledRows = (rows) => rows.filter((r) => r.last.trim() || r.first.trim());
