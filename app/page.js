"use client";
import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";

export default function Home() {
  const [session, setSession] = useState(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [schoolId, setSchoolId] = useState(null);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    matricule: "",
    class_id: "",
  });

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
      .select("id, first_name, last_name, matricule, classes(name)")
      .order("last_name");
    if (error) setError(error.message);
    else setStudents(data);
  }

  useEffect(() => {
    if (session) loadData();
  }, [session]);

  async function login(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setError(error.message);
  }

  async function addStudent(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.from("students").insert({
      school_id: schoolId,
      first_name: form.first_name,
      last_name: form.last_name,
      matricule: form.matricule || null,
      class_id: form.class_id || null,
    });
    if (error) {
      setError(error.message);
    } else {
      setForm({ first_name: "", last_name: "", matricule: "", class_id: "" });
      loadData();
    }
  }

  if (!session) {
    return (
      <main style={{ maxWidth: 360, margin: "60px auto", padding: 16 }}>
        <h1>Connexion</h1>
        <form onSubmit={login} style={{ display: "grid", gap: 8 }}>
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
    <main style={{ maxWidth: 600, margin: "40px auto", padding: 16 }}>
      <h1>Élèves</h1>
      <button onClick={() => supabase.auth.signOut()}>Déconnexion</button>
      {" "}<a href="/notes">Saisir des notes</a>
      {" "}<a href="/bulletin">Bulletins</a>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <h2>Ajouter un élève</h2>
      <form onSubmit={addStudent} style={{ display: "grid", gap: 8, maxWidth: 360 }}>
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
        <button type="submit">Ajouter</button>
      </form>

      <h2>Liste</h2>
      <ul>
        {students.map((s) => (
          <li key={s.id}>
            {s.last_name} {s.first_name} ({s.matricule}) : {s.classes?.name}
          </li>
        ))}
      </ul>
    </main>
  );
}