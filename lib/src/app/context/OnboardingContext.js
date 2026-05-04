"use client";
import { createContext, useContext, useState, useEffect } from "react";

const OnboardingContext = createContext();

export function OnboardingProvider({ children }) {
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [newRestaurantId, setNewRestaurantId] = useState(null);

  // context/OnboardingContext.js
  // ... inside your Provider state
  const [trialDaysLeft, setTrialDaysLeft] = useState(7);

  useEffect(() => {
    // Logic to calculate days: 7 - (Current Date - Created Date)
    // For now, let's assume it's stored in localStorage or comes from your User API
    const signupDate = localStorage.getItem("signupDate");
    if (signupDate) {
      const diff = Math.floor((new Date() - new Date(signupDate)) / (1000 * 60 * 60 * 24));
      setTrialDaysLeft(Math.max(0, 7 - diff));
    }
  }, []);

  // Trigger the popup
  const triggerSuccess = (id) => {
    setNewRestaurantId(id);
    setShowSuccessModal(true);
  };

  const closeSuccess = () => {
    setShowSuccessModal(false);
  };

  return (
    <OnboardingContext.Provider value={{ showSuccessModal, newRestaurantId, triggerSuccess, closeSuccess,trialDaysLeft, setTrialDaysLeft }}>
      {children}
    </OnboardingContext.Provider>
  );
}

export const useOnboarding = () => useContext(OnboardingContext);