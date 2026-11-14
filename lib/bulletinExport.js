// Téléchargement des bulletins en PDF et en Word (.docx modifiable). Tout se fait dans le navigateur.
import { fmt, appreciation } from './grades';
import { BULLETIN } from './settings';

const plain = (s) => String(s ?? '').replace(/[–—]/g, '-');
export const safeName = (s) => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w-]+/g, '_').replace(/^_+|_+$/g, '');

function save(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// items : [{ name, className, year, lines:[{name,coef,dev,comp,avg}], gen, rank }]
// meta  : { school, city, st, periodTitle }
function rowsOf(it, meta) {
  const { st } = meta;
  return it.lines.map((l) => [l.name, String(l.coef), fmt(l.dev), fmt(l.comp), fmt(l.avg), fmt(l.avg * l.coef), appreciation(l.avg, st, st.language)]);
}

export async function exportPdf(items, meta, filename) {
  const { jsPDF } = await import('jspdf');
  const autoTable = (await import('jspdf-autotable')).default;
  const B = BULLETIN[meta.st.language] || BULLETIN.fr;
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  items.forEach((it, i) => {
    if (i) doc.addPage();
    const W = doc.internal.pageSize.getWidth();
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(60);
    doc.text(plain(meta.st.bulletin_header || '').split('\n'), 15, 16);
    doc.setFont('helvetica', 'bold'); doc.text(plain(meta.school || ''), W - 15, 16, { align: 'right' });
    doc.setFont('helvetica', 'normal'); doc.text(plain(meta.city || ''), W - 15, 21, { align: 'right' });
    doc.setDrawColor(109, 74, 255); doc.setLineWidth(0.6); doc.line(15, 32, W - 15, 32);

    doc.setTextColor(27, 23, 64); doc.setFont('helvetica', 'bold'); doc.setFontSize(15);
    doc.text(plain(`${B.title} - ${meta.periodTitle}`), W / 2, 43, { align: 'center' });
    doc.setFontSize(10.5); doc.setFont('helvetica', 'normal'); doc.setTextColor(30);
    doc.text(plain(`${B.student} : ${it.name}`), 15, 54);
    doc.text(plain(`${B.cls} : ${it.className}  ${it.year ? '(' + it.year + ')' : ''}`), W - 15, 54, { align: 'right' });

    autoTable(doc, {
      startY: 60, theme: 'grid',
      head: [[B.subject, B.coef, B.dev, B.comp, B.avg, B.points, B.remark]],
      body: it.lines.length ? rowsOf(it, meta).map((r) => r.map(plain)) : [[{ content: B.none, colSpan: 7, styles: { halign: 'center' } }]],
      styles: { font: 'helvetica', fontSize: 9.5, cellPadding: 2.2, lineColor: [210, 205, 235], textColor: 40 },
      headStyles: { fillColor: [109, 74, 255], textColor: 255, halign: 'center' },
      alternateRowStyles: { fillColor: [247, 245, 255] },
      columnStyles: { 0: { halign: 'left' }, 1: { halign: 'center', cellWidth: 13 }, 2: { halign: 'center', cellWidth: 21 }, 3: { halign: 'center', cellWidth: 29 }, 4: { halign: 'center', cellWidth: 22, fontStyle: 'bold' }, 5: { halign: 'center', cellWidth: 18 }, 6: { halign: 'left', cellWidth: 30 } },
      margin: { left: 15, right: 15 },
    });
    let y = doc.lastAutoTable.finalY + 10;
    doc.setFont('helvetica', 'bold'); doc.setFontSize(11.5); doc.setTextColor(27, 23, 64);
    doc.text(plain(`${B.general} : ${fmt(it.gen)}/${meta.st.scale}  -  ${appreciation(it.gen, meta.st, meta.st.language)}`), 15, y);
    if (meta.st.show_rank) doc.text(plain(`${B.rank} : ${it.rank}`), W - 15, y, { align: 'right' });
    y += 34; if (y > 270) { doc.addPage(); y = 40; }
    doc.setFont('helvetica', 'normal'); doc.setFontSize(10); doc.setTextColor(60);
    [B.teacher, B.director, B.parents].forEach((t, k) => doc.text(t, 15 + k * ((W - 30) / 3) + (W - 30) / 6, y, { align: 'center' }));
  });
  doc.save(filename);
}

export async function exportDocx(items, meta, filename) {
  const d = await import('docx');
  const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType, BorderStyle, ShadingType, TabStopType } = d;
  const B = BULLETIN[meta.st.language] || BULLETIN.fr;
  const USABLE = 10206; // A4 avec marges de 1,5 cm, en twips
  const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
  const noBorders = { top: none, bottom: none, left: none, right: none };
  const line = { style: BorderStyle.SINGLE, size: 4, color: 'D2CDEB' };
  const cellBorders = { top: line, bottom: line, left: line, right: line };
  const P = (text, o = {}) => new Paragraph({ alignment: o.align, spacing: { after: o.after ?? 60 }, pageBreakBefore: o.pageBreak, children: [new TextRun({ text: String(text), bold: o.bold, size: o.size ?? 21, color: o.color })] });
  const cell = (text, w, o = {}) => new TableCell({
    width: { size: w, type: WidthType.DXA }, borders: o.borders || cellBorders,
    shading: o.fill ? { type: ShadingType.CLEAR, fill: o.fill, color: 'auto' } : undefined,
    margins: { top: 60, bottom: 60, left: 90, right: 90 },
    children: [new Paragraph({ alignment: o.align ?? AlignmentType.CENTER, children: [new TextRun({ text: String(text), bold: o.bold, color: o.color, size: o.size ?? 19 })] })],
  });
  const COLS = [2600, 700, 1000, 1500, 1100, 1000, 2306];

  const children = [];
  items.forEach((it, i) => {
    const hdr = (meta.st.bulletin_header || '').split('\n');
    children.push(new Table({
      width: { size: USABLE, type: WidthType.DXA }, columnWidths: [USABLE / 2, USABLE / 2], borders: { ...noBorders, insideHorizontal: none, insideVertical: none },
      rows: [new TableRow({ children: [
        new TableCell({ width: { size: USABLE / 2, type: WidthType.DXA }, borders: noBorders, children: hdr.map((t, k) => new Paragraph({ children: [new TextRun({ text: t, size: k ? 17 : 19, bold: k === 0 })] })) }),
        new TableCell({ width: { size: USABLE / 2, type: WidthType.DXA }, borders: noBorders, children: [
          new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: meta.school || '', bold: true, size: 21 })] }),
          new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: meta.city || '', size: 17 })] }),
        ] }),
      ] })],
    }));
    // l'élément précédent est un tableau : saut de page porté par le paragraphe suivant
    children.push(P('', { after: 120, pageBreak: false }));
    children.push(P(`${B.title} - ${meta.periodTitle}`, { align: AlignmentType.CENTER, bold: true, size: 30, color: '1B1740', after: 160 }));
    children.push(new Paragraph({ spacing: { after: 160 }, tabStops: [{ type: TabStopType.RIGHT, position: USABLE }], children: [
      new TextRun({ text: `${B.student} : `, size: 21 }), new TextRun({ text: it.name, bold: true, size: 21 }),
      new TextRun({ text: `\t${B.cls} : `, size: 21 }), new TextRun({ text: `${it.className}${it.year ? ' (' + it.year + ')' : ''}`, bold: true, size: 21 }),
    ] }));
    const head = new TableRow({ tableHeader: true, children: [B.subject, B.coef, B.dev, B.comp, B.avg, B.points, B.remark].map((t, k) => cell(t, COLS[k], { bold: true, color: 'FFFFFF', fill: '6D4AFF' })) });
    const body = it.lines.length
      ? rowsOf(it, meta).map((r) => new TableRow({ children: r.map((t, k) => cell(t, COLS[k], { align: k === 0 || k === 6 ? AlignmentType.LEFT : AlignmentType.CENTER, bold: k === 4 })) }))
      : [new TableRow({ children: [new TableCell({ columnSpan: 7, width: { size: USABLE, type: WidthType.DXA }, borders: cellBorders, children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: B.none, size: 19 })] })] })] })];
    children.push(new Table({ width: { size: USABLE, type: WidthType.DXA }, columnWidths: COLS, rows: [head, ...body] }));
    children.push(new Paragraph({ spacing: { before: 240, after: 120 }, tabStops: [{ type: TabStopType.RIGHT, position: USABLE }], children: [
      new TextRun({ text: `${B.general} : ${fmt(it.gen)}/${meta.st.scale}  -  ${appreciation(it.gen, meta.st, meta.st.language)}`, bold: true, size: 23 }),
      ...(meta.st.show_rank ? [new TextRun({ text: `\t${B.rank} : ${it.rank}`, bold: true, size: 23 })] : []),
    ] }));
    children.push(P('', { after: 600 }));
    children.push(new Table({
      width: { size: USABLE, type: WidthType.DXA }, columnWidths: [USABLE / 3, USABLE / 3, USABLE / 3], borders: { ...noBorders, insideHorizontal: none, insideVertical: none },
      rows: [new TableRow({ children: [B.teacher, B.director, B.parents].map((t) => cell(t, USABLE / 3, { borders: noBorders, size: 20 })) })],
    }));
    if (i < items.length - 1) children.push(new Paragraph({ pageBreakBefore: true, children: [] }));
  });

  const doc = new Document({
    creator: 'Lakol', title: `${B.title} - ${meta.periodTitle}`,
    styles: { default: { document: { run: { font: 'Arial' } } } },
    sections: [{ properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 850, bottom: 850, left: 850, right: 850 } } }, children }],
  });
  save(await Packer.toBlob(doc), filename);
}
