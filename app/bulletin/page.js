"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabase";

function mean(arr) {
  return arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : null;
}

// Moyenne d'une matière = (moyenne des devoirs + composition) / 2
function subjectAvg(list) {
  const d = mean(list.filter((g) => g.kind === "devoir").map((g) => Number(g.score)));
  const c = mean(list.filter((g) => g.kind === "composition").map((g) => Number(g.score)));
  if (d !== null && c !== null) return (d + c) / 2;
  return d !== null ? d : c;
}

// Moyenne générale pondérée par les coefficients
function generalAvg(gradesOfStudent) {
  const bySubject = {};
  gradesOfStudent.forEach((g) => {
    (bySubject[g.subject_id] = bySubject[g.subject_id] || []).push(g);
  });
  let total = 0, coefs = 0;
  Object.values(bySubject).forEach((list) => {
    const avg = subjectAvg(list);
    const coef = Number(list[0].subjects.coefficient);
    if (avg !== null) {
      total += avg * coef;
      coefs += coef;
    }
  });
  return coefs ? total / coefs : null;
}

function appreciation(avg) {
  if (avg === null) return "";
  if (avg >= 16) return "Excellent";
  if (avg >= 14) return "Très bien";
  if (avg >= 12) return "Bien";
  if (avg >= 10) return "Passable";
  return "Insuffisant";
}

export default function Bulletin() {
  const [session, setSession] = useState(null);
  const [students, setStudents] = useState([]);
  const [studentId, setStudentId] = useState("");
  const [term, setTerm] = useState("1");
  const [school, setSchool] = useState(null);
  const [result, setResult] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
  }, []);

  useEffect(() => {
    if (!session) return;
    supabase
      .from("students")
      .select("id, first_name, last_name, matricule, class_id, classes(name, school_year)")
      .order("last_name")
      .then(({ data }) => setStudents(data || []));
    supabase.from("schools").select("name, city").limit(1).single()
      .then(({ data }) => setSchool(data));
  }, [session]);

  async function generate() {
    setError("");
    setResult(null);
    const student = students.find((s) => s.id === studentId);
    if (!student) return;

    // Tous les élèves de la même classe (pour le rang)
    const classmates = students.filter((s) => s.class_id === student.class_id);
    const ids = classmates.map((s) => s.id);

    const { data: grades, error } = await supabase
      .from("grades")
      .select("student_id, subject_id, kind, score, subjects(name, coefficient)")
      .eq("term", Number(term))
      .in("student_id", ids);
    if (error) return setError(error.message);

    // Lignes du bulletin pour l'élève choisi
    const mine = grades.filter((g) => g.student_id === studentId);
    const bySubject = {};
    mine.forEach((g) => {
      (bySubject[g.subject_id] = bySubject[g.subject_id] || []).push(g);
    });
    const rows = Object.values(bySubject).map((list) => {
      const devoirs = list.filter((g) => g.kind === "devoir").map((g) => Number(g.score));
      const compo = list.filter((g) => g.kind === "composition").map((g) => Number(g.score));
      const avg = subjectAvg(list);
      const coef = Number(list[0].subjects.coefficient);
      return {
        name: list[0].subjects.name,
        coef,
        devoirs: mean(devoirs),
        compo: mean(compo),
        avg,
        points: avg !== null ? avg * coef : null,
      };
    });

    // Rang dans la classe
    const averages = classmates
      .map((s) => ({
        id: s.id,
        avg: generalAvg(grades.filter((g) => g.student_id === s.id)),
      }))
      .filter((x) => x.avg !== null)
      .sort((a, b) => b.avg - a.avg);
    const myAvg = generalAvg(mine);
    const rank = averages.findIndex((x) => x.id === studentId) + 1;

    setResult({ student, rows, myAvg, rank: rank || null, total: averages.length });
  }

  const fmt = (n) => (n === null || n === undefined ? "-" : n.toFixed(2));

  if (!session) {
    return (
      <main style={{ maxWidth: 700, margin: "40px auto", padding: 16 }}>
        <p>Connecte-toi d'abord sur la <a href="/">page d'accueil</a>.</p>
      </main>
    );
  }

  return (
    <main style={{ maxWidth: 700, margin: "40px auto", padding: 16 }}>
      <style>{`
        @media print {
          .no-print { display: none !important; }
          main { margin: 0 !important; max-width: 100% !important; }
        }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #333; padding: 6px; text-align: left; }
      `}</style>

      <div className="no-print">
        <a href="/">← Retour</a>
        <h1>Bulletin</h1>
        {error && <p style={{ color: "red" }}>{error}</p>}
        <div style={{ display: "grid", gap: 8, maxWidth: 360 }}>
          <select value={studentId} onChange={(e) => setStudentId(e.target.value)}>
            <option value="">Élève</option>
            {students.map((s) => (
              <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>
            ))}
          </select>
          <select value={term} onChange={(e) => setTerm(e.target.value)}>
            <option value="1">Trimestre 1</option>
            <option value="2">Trimestre 2</option>
            <option value="3">Trimestre 3</option>
          </select>
          <button onClick={generate}>Générer le bulletin</button>
        </div>
      </div>

      {result && (
        <section style={{ marginTop: 32 }}>
          <h2 style={{ textAlign: "center" }}>{school?.name}</h2>
          <p style={{ textAlign: "center" }}>
            {school?.city} : Bulletin du trimestre {term}
          </p>
          <p>
            <strong>Élève :</strong> {result.student.last_name} {result.student.first_name}
            {" "}({result.student.matricule || "sans matricule"})<br />
            <strong>Classe :</strong> {result.student.classes?.name}
            {" "}({result.student.classes?.school_year})
          </p>

          <table>
            <thead>
              <tr>
                <th>Matière</th><th>Coef</th><th>Devoirs</th>
                <th>Composition</th><th>Moyenne</th><th>Points</th>
              </tr>
            </thead>
            <tbody>
              {result.rows.map((r) => (
                <tr key={r.name}>
                  <td>{r.name}</td>
                  <td>{r.coef}</td>
                  <td>{fmt(r.devoirs)}</td>
                  <td>{fmt(r.compo)}</td>
                  <td>{fmt(r.avg)}</td>
                  <td>{fmt(r.points)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p style={{ marginTop: 16 }}>
            <strong>Moyenne générale :</strong> {fmt(result.myAvg)} / 20<br />
            <strong>Rang :</strong> {result.rank ? `${result.rank} / ${result.total}` : "-"}<br />
            <strong>Appréciation :</strong> {appreciation(result.myAvg)}
          </p>

          <button className="no-print" onClick={() => window.print()}>
            Imprimer / Enregistrer en PDF
          </button>
        </section>
      )}
    </main>
  );
}