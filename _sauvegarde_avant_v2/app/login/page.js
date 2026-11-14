"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "../../lib/supabase";

const ROLES = [
  { id: "admin", label: "Directeur" },
  { id: "teacher", label: "Professeur" },
  { id: "parent", label: "Élève / Parent" },
];

export default function Login() {
  const router = useRouter();
  const [mode, setMode] = useState("login");
  const [role, setRole] = useState("teacher");
  const [form, setForm] = useState({
    full_name: "",
    email: "",
    password: "",
    school_name: "",
    city: "",
    school_code: "",
    student_code: "",
  });
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [busy, setBusy] = useState(false);

  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setError("");
    setInfo("");
    setBusy(true);

    if (mode === "login") {
      const { error } = await supabase.auth.signInWithPassword({
        email: form.email,
        password: form.password,
      });
      setBusy(false);
      if (error) {
        setError("Email ou mot de passe incorrect.");
        return;
      }
      router.replace("/");
      return;
    }

    const { data, error } = await supabase.auth.signUp({
      email: form.email,
      password: form.password,
      options: {
        data: {
          role,
          full_name: form.full_name,
          school_name: form.school_name,
          city: form.city,
          school_code: form.school_code,
          student_code: form.student_code,
        },
      },
    });
    setBusy(false);
    if (error) {
      if (error.message.toLowerCase().includes("database error")) {
        setError("Code invalide. Vérifie le code donné par l'école.");
      } else {
        setError(error.message);
      }
      return;
    }
    if (data.session) {
      router.replace("/");
    } else {
      setInfo("Compte créé. Vérifie ton email pour confirmer, puis connecte-toi.");
      setMode("login");
    }
  }

  return (
    <main style={{ maxWidth: 440, margin: "50px auto" }}>
      <h1>{mode === "login" ? "Bienvenue sur Lakol" : "Créer un compte"}</h1>
      <p className="subtitle">
        {mode === "login"
          ? "Connectez-vous pour accéder à votre espace."
          : "Choisissez votre profil pour commencer."}
      </p>

      {mode === "signup" && (
        <div className="actions" style={{ marginBottom: 16, flexWrap: "wrap" }}>
          {ROLES.map((r) => (
            <button
              key={r.id}
              type="button"
              className={role === r.id ? "" : "btn-ghost"}
              onClick={() => setRole(r.id)}
            >
              {r.label}
            </button>
          ))}
        </div>
      )}

      <form onSubmit={submit} style={{ display: "grid", gap: 10 }}>
        {mode === "signup" && (
          <input placeholder="Nom complet" required value={form.full_name}
            onChange={set("full_name")} />
        )}
        {mode === "signup" && role === "admin" && (
          <>
            <input placeholder="Nom de l'école" required value={form.school_name}
              onChange={set("school_name")} />
            <input placeholder="Ville" value={form.city} onChange={set("city")} />
          </>
        )}
        {mode === "signup" && role === "teacher" && (
          <input placeholder="Code de l'école (donné par le directeur)" required
            value={form.school_code} onChange={set("school_code")} />
        )}
        {mode === "signup" && role === "parent" && (
          <input placeholder="Code de l'élève (donné par l'école)" required
            value={form.student_code} onChange={set("student_code")} />
        )}
        <input placeholder="Email" type="email" required value={form.email}
          onChange={set("email")} />
        <input placeholder="Mot de passe (6 caractères minimum)" type="password"
          required minLength={6} value={form.password} onChange={set("password")} />
        <button type="submit" disabled={busy}>
          {busy ? "Un instant..." : mode === "login" ? "Se connecter" : "Créer mon compte"}
        </button>
      </form>

      {error && <p style={{ color: "red" }}>{error}</p>}
      {info && <div className="notice">{info}</div>}

      <p style={{ marginTop: 18 }}>
        {mode === "login" ? "Pas encore de compte ? " : "Déjà un compte ? "}
        <a href="#" onClick={(e) => {
          e.preventDefault();
          setError("");
          setInfo("");
          setMode(mode === "login" ? "signup" : "login");
        }}>
          {mode === "login" ? "Créer un compte" : "Se connecter"}
        </a>
      </p>
    </main>
  );
}