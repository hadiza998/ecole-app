"use client";
import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";

export default function Home() {
  const [session, setSession] = useState(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [students, setStudents] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) =>
      setSession(s)
    );
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return;
    supabase
      .from("students")
      .select("id, first_name, last_name, matricule, classes(name)")
      .order("last_name")
      .then(({ data, error }) => {
        if (error) setError(error.message);
        else setStudents(data);
      });
  }, [session]);

  async function login(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setError(error.message);
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
      {error && <p style={{ color: "red" }}>{error}</p>}
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