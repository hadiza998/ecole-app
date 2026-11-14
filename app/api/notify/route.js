import { createClient } from '@supabase/supabase-js';


const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

function emailHtml(subject, body, siteUrl) {
  return `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px">
<div style="font-size:22px;font-weight:800;color:#6D4AFF;margin-bottom:14px">Lakol</div>
<h2 style="margin:0 0 10px;color:#1B1740">${esc(subject)}</h2>
<p style="white-space:pre-line;color:#333;line-height:1.55">${esc(body)}</p>
<p style="margin-top:22px"><a href="${siteUrl}" style="background:#6D4AFF;color:#fff;padding:10px 22px;border-radius:99px;text-decoration:none;font-weight:700">Ouvrir Lakol</a></p>
<p style="color:#999;font-size:12px;margin-top:26px">Tu reçois cet email car les notifications sont activées dans ton profil Lakol.</p></div>`;
}

export async function POST(request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const secret = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const mailKey = process.env.BREVO_API_KEY;
  const from = process.env.MAIL_FROM;
  if (!secret) return Response.json({ ok: false, error: 'SUPABASE_SERVICE_ROLE_KEY manquant' });

  // Seul un utilisateur connecté peut déclencher l'envoi
  const token = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) return Response.json({ ok: false, error: 'Non connecté' }, { status: 401 });
  const { data: u } = await createClient(url, anon).auth.getUser(token);
  if (!u?.user) return Response.json({ ok: false, error: 'Non connecté' }, { status: 401 });

  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const channels = [];
  if (mailKey && from) channels.push('email');
  if (!channels.length) return Response.json({ ok: true, sent: 0, note: 'Envoi non configuré' });

  // Les notifications de plus de 3 jours ne sont plus envoyées
  await admin.from('notification_queue').update({ status: 'skipped', error: 'trop ancienne' })
    .eq('status', 'pending').lt('created_at', new Date(Date.now() - 3 * 864e5).toISOString());

  const { data: todo } = await admin.from('notification_queue').select('id').eq('status', 'pending').in('channel', channels).order('created_at').limit(40);
  if (!todo?.length) return Response.json({ ok: true, sent: 0 });
  // « Je prends ces lignes » pour éviter les doubles envois
  const { data: rows } = await admin.from('notification_queue').update({ status: 'sending' })
    .in('id', todo.map((r) => r.id)).eq('status', 'pending').select('id, user_id, channel, subject, body');
  if (!rows?.length) return Response.json({ ok: true, sent: 0 });

  const { data: profs } = await admin.from('profiles').select('id, email, phone').in('id', [...new Set(rows.map((r) => r.user_id))]);
  const byId = Object.fromEntries((profs || []).map((p) => [p.id, p]));
  const site = process.env.SITE_URL || new URL(request.url).origin;
  let sent = 0, failed = 0;

  for (const r of rows) {
    const p = byId[r.user_id];
    let error = null;
    try {
      if (r.channel === 'email') {
        if (!p?.email) throw new Error('Pas d\'email');
        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST', headers: { 'api-key': mailKey, 'content-type': 'application/json', accept: 'application/json' },
          body: JSON.stringify({ sender: { name: 'Lakol', email: from }, to: [{ email: p.email }], subject: r.subject, htmlContent: emailHtml(r.subject, r.body, site) }),
        });
        if (!res.ok) throw new Error((await res.text()).slice(0, 300));
      } else {
        throw new Error('Canal non pris en charge');
      }
    } catch (e) { error = String(e.message || e); }
    await admin.from('notification_queue').update(error ? { status: 'failed', error } : { status: 'sent', sent_at: new Date().toISOString() }).eq('id', r.id);
    error ? failed++ : sent++;
  }
  return Response.json({ ok: true, sent, failed });
}
