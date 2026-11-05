"use client";
import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";

const emptyForm = { first_name: "", last_name: "", matricule: "", class_id: "" };

export default function Home() {
  const [session, setSession] = useState(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [schoolId, setSchoolId] = useState(null);
  const [error, setError] = useState("");
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) =>
      setSession(s)
    );
    return () => sub.subscription.unsubscribe();
  }, []);

  async function loadData() {
    const { data: profile } = await supabase
      .from("profiles")
      .select("school_id")
      .eq("id", session.user.id)
      .single();
    setSchoolId(profile?.school_id);

    const { data: cls } = await supabase
      .from("classes")
      .select("id, name")
      .order("name");
    setClasses(cls || []);

    const { data, error } = await supabase
      .from("students")
      .select("id, first_name, last_name, matricule, class_id, classes(name)")
      .order("last_name");
    if (error) setError(error.message);
    else setStudents(data);
  }

  useEffect(() => {
    if (session) loadData();
  }, [session]);

  function friendly(err) {
    if (err.code === "23505") return "Ce matricule existe déjà dans votre école.";
    return err.message;
  }

  async function login(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setError(error.message);
  }

  function cancelEdit() {
    setEditingId(null);
    setForm(emptyForm);
  }

  function startEdit(s) {
    setEditingId(s.id);
    setForm({
      first_name: s.first_name,
      last_name: s.last_name,
      matricule: s.matricule || "",
      class_id: s.class_id || "",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function saveStudent(e) {
    e.preventDefault();
    setError("");
    const values = {
      first_name: form.first_name,
      last_name: form.last_name,
      matricule: form.matricule || null,
      class_id: form.class_id || null,
    };
    const { error } = editingId
      ? await supabase.from("students").update(values).eq("id", editingId)
      : await supabase.from("students").insert({ ...values, school_id: schoolId });
    if (error) {
      setError(friendly(error));
      return;
    }
    cancelEdit();
    loadData();
  }

  async function deleteStudent(s) {
    if (
      !confirm(
        `Supprimer ${s.first_name} ${s.last_name} ? Ses notes et ses paiements seront aussi supprimés.`
      )
    )
      return;
    const { error } = await supabase.from("students").delete().eq("id", s.id);
    if (error) {
      setError(friendly(error));
      return;
    }
    if (editingId === s.id) cancelEdit();
    loadData();
  }

  if (!session) {
    return (
      <main style={{ maxWidth: 400, margin: "60px auto" }}>
        <h1>Bienvenue sur Lakol</h1>
        <p className="subtitle">Connectez-vous pour gérer votre école.</p>
        <form onSubmit={login} style={{ display: "grid", gap: 10 }}>
          <input placeholder="Email" value={email}
            onChange={(e) => setEmail(e.target.value)} />
          <input placeholder="Mot de passe" type="password" value={password}
            onChange={(e) => setPassword(e.target.value)} />
          <button type="submit">Se connecter</button>
        </form>
        {error && <p style={{ color: "red" }}>{error}</p>}
      </main>
    );
  }

  return (
    <main style={{ maxWidth: 680, margin: "40px auto" }}>
      <div className="topbar">
        <h1>Élèves</h1>
        <button className="btn-ghost btn-small" onClick={() => supabase.auth.signOut()}>
          Déconnexion
        </button>
      </div>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <h2>{editingId ? "Modifier l'élève" : "Ajouter un élève"}</h2>
      {editingId && (
        <div className="notice">Modification en cours. Enregistre ou annule.</div>
      )}
      <form onSubmit={saveStudent} style={{ display: "grid", gap: 10, maxWidth: 400 }}>
        <input placeholder="Prénom" required value={form.first_name}
          onChange={(e) => setForm({ ...form, first_name: e.target.value })} />
        <input placeholder="Nom" required value={form.last_name}
          onChange={(e) => setForm({ ...form, last_name: e.target.value })} />
        <input placeholder="Matricule" value={form.matricule}
          onChange={(e) => setForm({ ...form, matricule: e.target.value })} />
        <select value={form.class_id}
          onChange={(e) => setForm({ ...form, class_id: e.target.value })}>
          <option value="">Choisir une classe</option>
          {classes.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
        <div className="actions">
          <button type="submit">
            {editingId ? "Enregistrer les modifications" : "Ajouter"}
          </button>
          {editingId && (
            <button type="button" className="btn-ghost" onClick={cancelEdit}>
              Annuler
            </button>
          )}
        </div>
      </form>

      <h2>Liste ({students.length})</h2>
      {students.length === 0 && <p className="empty">Aucun élève pour le moment.</p>}
      <ul>
        {students.map((s) => (
          <li key={s.id} className="row">
            <div className="person">
              <span className="avatar">
                {`${s.first_name?.[0] ?? ""}${s.last_name?.[0] ?? ""}`.toUpperCase()}
              </span>
              <div>
                <strong>{s.last_name} {s.first_name}</strong>
                <div className="meta">
                  {s.matricule || "sans matricule"} · {s.classes?.name || "sans classe"}
                </div>
              </div>
            </div>
            <div className="actions">
              <button className="btn-ghost btn-small" onClick={() => startEdit(s)}>
                Modifier
              </button>
              <button className="btn-danger btn-small" onClick={() => deleteStudent(s)}>
                Supprimer
              </button>
            </div>
          </li>
        ))}
      </ul>
    </main>
  );
}