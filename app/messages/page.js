'use client';
import { useEffect, useRef, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useProfile, Blocked } from '../../lib/useProfile';
import { pingNotify, refreshBadges } from '../../lib/notify';
import Icon from '../components/Icon';

const ROLE = { admin: 'Direction', teacher: 'Professeur', parent: 'Parent' };
const initials = (n) => (n || '?').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
const when = (d) => { const x = new Date(d); const same = x.toDateString() === new Date().toDateString(); return same ? x.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : x.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }); };

export default function Messages() {
  const { profile, status } = useProfile(['admin', 'teacher', 'parent']);
  const [convs, setConvs] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [classes, setClasses] = useState([]);
  const [other, setOther] = useState(null);       // { id, name, role }
  const [thread, setThread] = useState([]);
  const [body, setBody] = useState('');
  const [panel, setPanel] = useState(null);       // 'new' | 'bulk'
  const [q, setQ] = useState('');
  const [bulk, setBulk] = useState({ target: 'class', class_id: '', body: '' });
  const [info, setInfo] = useState('');
  const [err, setErr] = useState('');
  const endRef = useRef(null);
  const isParent = profile?.role === 'parent';

  async function loadConvs() {
    const { data } = await supabase.rpc('my_conversations');
    setConvs(data || []);
  }
  async function loadThread(o) {
    if (!o) return;
    const me = profile.id;
    const { data } = await supabase.from('messages').select('id, sender_id, body, created_at')
      .or(`and(sender_id.eq.${me},recipient_id.eq.${o.id}),and(sender_id.eq.${o.id},recipient_id.eq.${me})`).order('created_at');
    setThread(data || []);
    await supabase.rpc('mark_thread_read', { p_other: o.id });
    refreshBadges(); loadConvs();
  }

  useEffect(() => {
    if (status !== 'ok') return;
    loadConvs();
    supabase.rpc('my_contacts').then(({ data }) => setContacts(data || []));
    (async () => {
      if (profile.role === 'parent') return;
      let list;
      if (profile.role === 'teacher') {
        const { data: t } = await supabase.from('teaching').select('class_id').eq('teacher_id', profile.id);
        const ids = [...new Set((t || []).map((x) => x.class_id))];
        list = ids.length ? (await supabase.from('classes').select('id, name').in('id', ids).order('name')).data : [];
      } else list = (await supabase.from('classes').select('id, name').order('name')).data;
      setClasses(list || []); setBulk((b) => ({ ...b, class_id: list?.[0]?.id || '' }));
    })();
  }, [status]);

  useEffect(() => { loadThread(other); }, [other?.id]);
  useEffect(() => { endRef.current?.scrollIntoView({ block: 'end' }); }, [thread.length]);
  // rafraîchit toutes les 20 s
  useEffect(() => {
    if (status !== 'ok') return;
    const t = setInterval(() => { loadConvs(); if (other) loadThread(other); }, 20000);
    return () => clearInterval(t);
  }, [status, other?.id]);

  async function send(e) {
    e.preventDefault(); setErr('');
    if (!body.trim() || !other) return;
    const { error } = await supabase.rpc('send_message', { p_recipient: other.id, p_student: null, p_body: body });
    if (error) return setErr(error.message);
    setBody(''); pingNotify(); loadThread(other);
  }
  async function sendBulk(e) {
    e.preventDefault(); setErr(''); setInfo('');
    const { data, error } = await supabase.rpc('send_bulk', { p_target: bulk.target, p_class_id: bulk.target === 'class' ? bulk.class_id : null, p_body: bulk.body });
    if (error) return setErr(error.message);
    setInfo(`Message envoyé à ${data} personne(s).`); setBulk({ ...bulk, body: '' }); pingNotify(); loadConvs();
  }

  if (status === 'blocked') return <Blocked />;
  if (status !== 'ok') return <div className="lk-page"><p className="meta">Chargement…</p></div>;

  const filtered = contacts.filter((c) => c.full_name.toLowerCase().includes(q.toLowerCase()));
  const open = (id, name, role) => { setOther({ id, name, role }); setPanel(null); };

  return (
    <div className="lk-page">
      <div className="topbar">
        <div><h1>Messages</h1><div className="sub">{isParent ? 'Écris aux professeurs et à la direction.' : 'Écris aux parents (un par un ou en groupe).'}</div></div>
        <div className="actions">
          <button onClick={() => { setPanel(panel === 'new' ? null : 'new'); setOther(null); }}><Icon name="mail" /> Écrire</button>
          {!isParent && <button className="btn-ghost" onClick={() => { setPanel(panel === 'bulk' ? null : 'bulk'); setOther(null); setInfo(''); }}><Icon name="megaphone" /> Message groupé</button>}
        </div>
      </div>
      {err && <div className="notice">{err}</div>}

      <div className={'msg-layout' + (other ? ' has-thread' : '')}>
        <div className="lk-card msg-list">
          {convs.length === 0 && <span className="meta">Aucune conversation pour le moment.</span>}
          {convs.map((c) => (
            <div key={c.other_id} className={'conv' + (other?.id === c.other_id ? ' on' : '')} onClick={() => open(c.other_id, c.other_name, c.other_role)}>
              <span className="avatar">{initials(c.other_name)}</span>
              <div className="conv-main">
                <div className="conv-top"><b>{c.other_name}</b><span className="meta">{when(c.last_at)}</span></div>
                <div className="conv-last meta">{c.last_from_me ? 'Toi : ' : ''}{c.last_body}</div>
              </div>
              {c.unread > 0 && <em className="nbadge">{c.unread}</em>}
            </div>
          ))}
        </div>

        <div className="lk-card msg-pane">
          {panel === 'new' && (
            <>
              <h3>À qui veux-tu écrire ?</h3>
              <input placeholder="Rechercher un nom…" value={q} onChange={(e) => setQ(e.target.value)} />
              {filtered.length === 0 && <span className="meta">Personne à contacter pour le moment.</span>}
              <div className="msg-contacts">
                {filtered.map((c) => (
                  <div className="conv" key={c.id} onClick={() => open(c.id, c.full_name, c.role)}>
                    <span className="avatar">{initials(c.full_name)}</span>
                    <div className="conv-main"><b>{c.full_name} <span className="tag">{ROLE[c.role]}</span></b><div className="meta">{c.context}</div></div>
                  </div>
                ))}
              </div>
            </>
          )}

          {panel === 'bulk' && (
            <form className="lk-stack" onSubmit={sendBulk}>
              <h3><Icon name="megaphone" /> Message groupé</h3>
              <div className="chips">
                {profile.role === 'admin' && <button type="button" className={bulk.target === 'parents' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'parents' })}>Tous les parents</button>}
                {profile.role === 'admin' && <button type="button" className={bulk.target === 'teachers' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'teachers' })}>Tous les professeurs</button>}
                <button type="button" className={bulk.target === 'class' ? 'on' : ''} onClick={() => setBulk({ ...bulk, target: 'class' })}>Parents d'une classe</button>
              </div>
              {bulk.target === 'class' && (
                <select value={bulk.class_id} onChange={(e) => setBulk({ ...bulk, class_id: e.target.value })}>
                  {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              )}
              <textarea rows={4} placeholder="Ton message…" value={bulk.body} onChange={(e) => setBulk({ ...bulk, body: e.target.value })} />
              <div className="lk-inline"><button disabled={!bulk.body.trim()}>Envoyer</button>{info && <span className="meta">{info}</span>}</div>
              <span className="meta">Chaque personne reçoit le message en privé et peut te répondre.</span>
            </form>
          )}

          {!panel && other && (
            <>
              <div className="lk-inline">
                <button className="btn-small btn-ghost back" onClick={() => setOther(null)} aria-label="Retour"><Icon name="back" size={16} /></button>
                <span className="avatar">{initials(other.name)}</span>
                <div><b>{other.name}</b> <span className="tag">{ROLE[other.role]}</span></div>
              </div>
              <div className="thread">
                {thread.map((m) => (
                  <div key={m.id} className={'bubble ' + (m.sender_id === profile.id ? 'me' : 'them')}>
                    {m.body}<small>{when(m.created_at)}</small>
                  </div>
                ))}
                <div ref={endRef} />
              </div>
              <form className="lk-inline" onSubmit={send}>
                <input placeholder="Écris ton message…" value={body} onChange={(e) => setBody(e.target.value)} />
                <button disabled={!body.trim()} style={{ flex: '0 0 auto' }}>Envoyer</button>
              </form>
            </>
          )}

          {!panel && !other && <div className="empty" style={{ margin: 'auto' }}>Choisis une conversation ou écris un nouveau message.</div>}
        </div>
      </div>
    </div>
  );
}
