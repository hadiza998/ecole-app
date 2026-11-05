"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabase";

const emptyForm = { student_id: "", subject_id: "", term: "1", kind: "devoir", score: "" };

export default function Notes() {
  const [session, setSession] = useState(null);
  const [schoolId, setSchoolId] = useState(null);
  const [students, setStudents] = useState([]);
  const [subjects, setSubjects] = useState([]);
  const [grades, setGrades] = useState([]);
  const [error, setError] = useState("");
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);

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
      .select("id, student_id, subject_id, term, kind, score, students(first_name, last_name), subjects(name)")
      .order("created_at", { ascending: false })
      .limit(30);
    if (error) setError(error.message);
    else setGrades(gr || []);
  }

  useEffect(() => {
    if (session) loadData();
  }, [session]);

  function cancelEdit() {
    setEditingId(null);
    setForm(emptyForm);
  }

  function startEdit(g) {
    setEditingId(g.id);
    setForm({
      student_id: g.student_id,
      subject_id: g.subject_id,
      term: String(g.term),
      kind: g.kind,
      score: String(g.score),
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function saveGrade(e) {
    e.preventDefault();
    setError("");
    const values = {
      student_id: form.student_id,
      subject_id: form.subject_id,
      term: Number(form.term),
      kind: form.kind,
      score: Number(form.score),
    };
    const { error } = editingId
      ? await supabase.from("grades").update(values).eq("id", editingId)
      : await supabase.from("grades").insert({
          ...values,
          school_id: schoolId,
          created_by: session.user.id,
        });
    if (error) {
      setError(error.message);
      return;
    }
    if (editingId) cancelEdit();
    else setForm({ ...form, score: "" });
    loadData();
  }

  async function deleteGrade(g) {
    if (!confirm("Supprimer cette note ?")) return;
    const { error } = await supabase.from("grades").delete().eq("id", g.id);
    if (error) {
      setError(error.message);
      return;
    }
    if (editingId === g.id) cancelEdit();
    loadData();
  }

  if (!session) {
    return (
      <main style={{ maxWidth: 680, margin: "40px auto" }}>
        <p>Connecte-toi d'abord sur la <a href="/">page d'accueil</a>.</p>
      </main>
    );
  }

  return (
    <main style={{ maxWidth: 680, margin: "40px auto" }}>
      <h1>Notes</h1>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <h2>{editingId ? "Modifier la note" : "Ajouter une note"}</h2>
      {editingId && (
        <div className="notice">Modification en cours. Enregistre ou annule.</div>
      )}
      <form onSubmit={saveGrade} style={{ display: "grid", gap: 10, maxWidth: 400 }}>
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
        <div className="actions">
          <button type="submit">
            {editingId ? "Enregistrer les modifications" : "Enregistrer la note"}
          </button>
          {editingId && (
            <button type="button" className="btn-ghost" onClick={cancelEdit}>
              Annuler
            </button>
          )}
        </div>
      </form>

      <h2>Dernières notes</h2>
      {grades.length === 0 && <p className="empty">Aucune note pour le moment.</p>}
      <ul>
        {grades.map((g) => (
          <li key={g.id} className="row">
            <div className="person">
              <span className={`score ${Number(g.score) < 10 ? "low" : ""}`}>
                {g.score}/20
              </span>
              <div>
                <strong>{g.students?.last_name} {g.students?.first_name}</strong>
                <div className="meta">
                  {g.subjects?.name} · T{g.term} · {g.kind}
                </div>
              </div>
            </div>
            <div className="actions">
              <button className="btn-ghost btn-small" onClick={() => startEdit(g)}>
                Modifier
              </button>
              <button className="btn-danger btn-small" onClick={() => deleteGrade(g)}>
                Supprimer
              </button>
            </div>
          </li>
        ))}
      </ul>
    </main>
  );
}