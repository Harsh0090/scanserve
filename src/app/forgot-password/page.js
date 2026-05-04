"use client";
import { useState } from "react";
import apiConfig from "@/utils/apiConfig";
export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");

  const submit = async () => {
    if (!email) return alert("Enter email");

    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/forgot-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      const data = await res.json();

      if (!res.ok) throw new Error(data.message);

      alert("Reset link sent (check backend console)");

    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="bg-white p-10 rounded-3xl shadow-xl">
        <h2 className="text-2xl font-black mb-6">Forgot Password</h2>

        <input
          placeholder="Enter your email"
          className="border p-4 rounded-xl w-full mb-4"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <button
          onClick={submit}
          className="w-full bg-black text-white py-4 rounded-xl font-bold"
        >
          Send Reset Link
        </button>
      </div>
    </div>
  );
}
