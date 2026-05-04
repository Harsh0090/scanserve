"use client";
import { useEffect } from "react";
import { useTrial } from "./context/TrialContext";

export default function TrialEventListener() {
  const trial = useTrial();

  useEffect(() => {
    if (!trial) return;

    const handler = (e) => {
      trial.triggerTrialExpired(e.detail);
    };

    window.addEventListener("trial-expired", handler);
    return () => window.removeEventListener("trial-expired", handler);
  }, [trial]);

  return null;
}
