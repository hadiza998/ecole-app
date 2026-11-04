"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabase";

export default function Notes() {
  const [session, setSession] = useState(null);
  const [schoolId, setSchoolId] = useState(null);
  const [students, setStudents] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [grades, setGrades] = useState([]);
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    student_id: "",
    subject_id: "",
    term: "1",
    kind: "devoir",
    score: "",
  });

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
  }, []);

  async function loadData() {
    const { data: profile } = await supabase
      .from("profiles")
      .select("school_id")
      .eq("id", session.user.id)
      .single();
    setSchoolId(profile?.school_id);

    const { data: st } = await supabase
      .from("students")
      .select("id, first_name, last_name")
      .order("last_name");
    setStudents(st || []);

    const { data: sj } = await supabase
      .from("subjects")
      .select("id, name")
      .order("name");
    setSubjects(sj || []);

    const { data: gr, error } = await supabase
      .from("grades")
      .select("id, term, kind, score, students(first_name, last_name), subjects(name)")
      .order("created_at", { ascending: false })
      .limit(20);
    if (error) setError(error.message);
    else setGrades(gr || []);
  }

  useEffect(() => {
    if (session) loadData();
  }, [session]);

  async function addGrade(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.from("grades").insert({
      school_id: schoolId,
      student_id: form.student_id,
      subject_id: form.subject_id,
      term: Number(form.term),
      kind: form.kind,
      score: Number(form.score),
      created_by: session.user.id,
    });
    if (error) {
      setError(error.message);
    } else {
      setForm({ ...form, score: "" });
      loadData();
    }
  }

  if (!session) {
    return (
      <main style={{ maxWidth: 600, margin: "40px auto", padding: 16 }}>
        <p>Connecte-toi d'abord sur la <a href="/">page d'accueil</a>.</p>
      </main>
    );
  }

  return (
    <main style={{ maxWidth: 600, margin: "40px auto", padding: 16 }}>
      <a href="/">← Retour aux élèves</a>
      <h1>Notes</h1>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <form onSubmit={addGrade} style={{ display: "grid", gap: 8, maxWidth: 360 }}>
        <select required value={form.student_id}
          onChange={(e) => setForm({ ...form, student_id: e.target.value })}>
          <option value="">Élève</option>
          {students.map((s) => (
            <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>
          ))}
        </select>
        <select required value={form.subject_id}
          onChange={(e) => setForm({ ...form, subject_id: e.target.value })}>
          <option value="">Matière</option>
          {subjects.map((s) => (
            <option key={s.id} value={s.id}>{s.name}</option>
          ))}
        </select>
        <select value={form.term}
          onChange={(e) => setForm({ ...form, term: e.target.value })}>
          <option value="1">Trimestre 1</option>
          <option value="2">Trimestre 2</option>
          <option value="3">Trimestre 3</option>
        </select>
        <select value={form.kind}
          onChange={(e) => setForm({ ...form, kind: e.target.value })}>
          <option value="devoir">Devoir</option>
          <option value="composition">Composition</option>
        </select>
        <input type="number" step="0.25" min="0" max="20" required
          placeholder="Note sur 20" value={form.score}
          onChange={(e) => setForm({ ...form, score: e.target.value })} />
        <button type="submit">Enregistrer la note</button>
      </form>

      <h2>Dernières notes</h2>
      <ul>
        {grades.map((g) => (
          <li key={g.id}>
            {g.students?.last_name} {g.students?.first_name} : {g.subjects?.name}, T{g.term}, {g.kind}, {g.score}/20
          </li>
        ))}
      </ul>
    </main>
  );
}