import { useOnboarding } from "../context/OnboardingContext";

export function TrialBanner() {
  const { trialDaysLeft } = useOnboarding();

  if (trialDaysLeft <= 0) return null;

  return (
    <div className="bg-gradient-to-r from-[#FF4C00] to-[#ff7a45] text-white py-2 px-6 text-center text-sm font-bold flex items-center justify-center gap-4 shadow-lg">
      <span className="flex items-center gap-2">
        ⏳ <span className="uppercase tracking-widest">Free Trial:</span> 
        {trialDaysLeft} days remaining
      </span>
      <button className="bg-white text-[#FF4C00] px-4 py-1 rounded-full text-xs font-black hover:bg-orange-50 transition-colors">
        UPGRADE NOW
      </button>
    </div>
  );
}