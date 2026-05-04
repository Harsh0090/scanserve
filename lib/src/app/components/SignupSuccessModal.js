"use client";
import { useOnboarding } from "../context/OnboardingContext";
import { useRouter } from "next/navigation";

export default function SignupSuccessModal() {
  const { showSuccessModal, newRestaurantId, closeSuccess } = useOnboarding();
  // console.log(showSuccessModal, newRestaurantId, closeSuccess,"showSuccessModal, newRestaurantId, closeSuccess");
  const router = useRouter();

  if (!showSuccessModal) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-[#0F172A]/80 backdrop-blur-md" onClick={closeSuccess} />
      
      <div className="relative bg-white rounded-[3.5rem] max-w-lg w-full shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-300">
        <div className="bg-[#FFF9F5] p-10 text-center">
          <div className="w-20 h-20 bg-[#FF4C00] rounded-[1.5rem] flex items-center justify-center text-4xl shadow-lg mx-auto mb-4 transform -rotate-3">
            🎉
          </div>
          <h2 className="text-3xl font-black text-[#0F172A]">Your restaurant is live!</h2>
          <p className="text-gray-500 font-bold mt-2">Scan Serve is ready for your first order.</p>
        </div>

        <div className="p-8 space-y-3">
          <button 
            onClick={() => { closeSuccess(); router.push("/admin/orders"); }}
            className="cursor-pointer w-full flex items-center gap-4 p-5 rounded-3xl bg-gray-50 hover:bg-orange-50 border-2 border-transparent hover:border-[#FF4C00] transition-all text-left"
          >
            <span className="text-2xl">📊</span>
            <div>
              <p className="font-black text-[#0F172A]">Go to Dashboard</p>
              <p className="text-xs text-gray-400 font-bold">Manage orders & menu</p>
            </div>
          </button>

          <button 
            onClick={() => { closeSuccess(); router.push(`/menu/${newRestaurantId}`); }}
            className="cursor-pointer w-full flex items-center gap-4 p-5 rounded-3xl bg-gray-50 hover:bg-orange-50 border-2 border-transparent hover:border-[#FF4C00] transition-all text-left"
          >
            <span className="text-2xl">🍽️</span>
            <div>
              <p className="font-black text-[#0F172A]">Preview QR Menu</p>
              <p className="text-xs text-gray-400 font-bold">See the customer view</p>
            </div>
          </button>
        </div>
      </div>
    </div>
  );
}