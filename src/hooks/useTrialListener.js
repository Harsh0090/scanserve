// ✅ FILE 6 — useTrialListener.js (ONE-TIME LISTENER)

// 📁 src/hooks/useTrialListener.js

"use client";
import { useEffect } from "react";
import { useTrial } from "../app/context/TrialContext";

export default function useTrialListener() {
  const { triggerTrialExpired } = useTrial();

  useEffect(() => {
    const handler = (e) => {
      triggerTrialExpired(e.detail);
    };

    window.addEventListener("trial-expired", handler);
    return () => window.removeEventListener("trial-expired", handler);
  }, []);
}