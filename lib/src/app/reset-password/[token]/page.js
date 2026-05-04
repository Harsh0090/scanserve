"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import apiConfig from "@/utils/apiConfig";

export default function ResetPasswordPage() {
  const { token } = useParams();
  const router = useRouter();

  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleReset = async () => {
    if (!password) {
      alert("Enter new password");
      return;
    }

    try {
      setLoading(true);

      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/auth/reset-password/${token}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ password }),
        }
      );

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || "Reset failed");
      }

      alert("Password reset successful");

      router.push("/login"); // redirect to login

    } catch (err) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#FDFCF8]">
      <div className="bg-white p-10 rounded-3xl shadow-xl w-full max-w-md border border-slate-100">

        <h1 className="text-2xl font-black text-slate-900 mb-6">
          Reset Password
        </h1>

        <input
          type="password"
          placeholder="Enter new password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full border-2 border-slate-200 rounded-xl px-4 py-3 mb-6 outline-none focus:border-orange-500"
        />

        <button
          onClick={handleReset}
          disabled={loading}
          className="w-full bg-slate-900 hover:bg-orange-600 text-white py-3 rounded-xl font-black transition-all"
        >
          {loading ? "Resetting..." : "Reset Password"}
        </button>

      </div>
    </div>
  );
}
