"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabase";

const fcfa = (n) => `${Number(n || 0).toLocaleString("fr-FR")} FCFA`;

export default function Paiements() {
  const [session, setSession] = useState(null);
  const [schoolId, setSchoolId] = useState(null);
  const [students, setStudents] = useState([]);
  const [fees, setFees] = useState([]);
  const [payments, setPayments] = useState([]);
  const [studentId, setStudentId] = useState("");
  const [error, setError] = useState("");
  const [form, setForm] = useState({
    fee_id: "",
    amount: "",
    method: "moov",
    reference: "",
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
      .select("id, first_name, last_name, class_id")
      .order("last_name");
    setStudents(st || []);

    const { data: fe } = await supabase
      .from("fees")
      .select("id, class_id, label, amount");
    setFees(fe || []);

    const { data: pa, error } = await supabase
      .from("payments")
      .select("id, student_id, fee_id, amount, method, reference, paid_at")
      .order("paid_at", { ascending: false });
    if (error) setError(error.message);
    else setPayments(pa || []);
  }

  useEffect(() => {
    if (session) loadData();
  }, [session]);

  const student = students.find((s) => s.id === studentId);
  const studentFees = fees.filter((f) => f.class_id === student?.class_id);
  const studentPayments = payments.filter((p) => p.student_id === studentId);
  const totalDue = studentFees.reduce((a, f) => a + f.amount, 0);
  const totalPaid = studentPayments.reduce((a, p) => a + p.amount, 0);

  async function addPayment(e) {
    e.preventDefault();
    setError("");
    const { error } = await supabase.from("payments").insert({
      school_id: schoolId,
      student_id: studentId,
      fee_id: form.fee_id || null,
      amount: Number(form.amount),
      method: form.method,
      reference: form.reference || null,
    });
    if (error) {
      setError(error.message);
    } else {
      setForm({ ...form, amount: "", reference: "" });
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
      <a href="/">← Retour</a>
      <h1>Paiements</h1>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <select value={studentId} onChange={(e) => setStudentId(e.target.value)}>
        <option value="">Choisir un élève</option>
        {students.map((s) => (
          <option key={s.id} value={s.id}>{s.last_name} {s.first_name}</option>
        ))}
      </select>

      {student && (
        <>
          <h2>Situation</h2>
          <p>
            Total à payer : <strong>{fcfa(totalDue)}</strong><br />
            Déjà payé : <strong>{fcfa(totalPaid)}</strong><br />
            Reste : <strong style={{ color: totalDue - totalPaid > 0 ? "red" : "green" }}>
              {fcfa(totalDue - totalPaid)}
            </strong>
          </p>

          <h2>Enregistrer un paiement</h2>
          <form onSubmit={addPayment} style={{ display: "grid", gap: 8, maxWidth: 360 }}>
            <select value={form.fee_id}
              onChange={(e) => setForm({ ...form, fee_id: e.target.value })}>
              <option value="">Type de frais</option>
              {studentFees.map((f) => (
                <option key={f.id} value={f.id}>{f.label} ({fcfa(f.amount)})</option>
              ))}
            </select>
            <input type="number" min="1" required placeholder="Montant (FCFA)"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })} />
            <select value={form.method}
              onChange={(e) => setForm({ ...form, method: e.target.value })}>
              <option value="moov">Moov Money</option>
              <option value="airtel">Airtel Money</option>
              <option value="orange">Orange Money</option>
              <option value="nita">NITA</option>
              <option value="cash">Espèces</option>
            </select>
            <input placeholder="Référence de transaction (facultatif)"
              value={form.reference}
              onChange={(e) => setForm({ ...form, reference: e.target.value })} />
            <button type="submit">Enregistrer</button>
          </form>

          <h2>Historique</h2>
          <ul>
            {studentPayments.map((p) => (
              <li key={p.id}>
                {new Date(p.paid_at).toLocaleDateString("fr-FR")} : {fcfa(p.amount)} ({p.method})
                {p.reference ? `, réf. ${p.reference}` : ""}
              </li>
            ))}
          </ul>
        </>
      )}
    </main>
  );
}