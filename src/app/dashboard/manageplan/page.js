
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { 
  Building2, 
  MapPin, 
  Plus, 
  ShieldCheck, 
  ArrowRight,
  Info,
  Gift,
  LayoutGrid
} from "lucide-react";
import apiConfig from "@/utils/apiConfig";
export default function CreateBranchPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;

  const createBranch = async () => {
    if (!name) return alert("Branch name is required");
    setIsSubmitting(true);

    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/restaurants`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ name, city }),
      });

      const data = await res.json();

      if (res.ok) {
        alert("Branch created successfully!");
        setName("");
        setCity("");
        return;
      }

      // 🔥 Handle specific limits from your logic
      if (data.message === "TRIAL_BRANCH_LIMIT_REACHED") {
        alert("Your trial branch limit is reached. Add more branches after trial ends.");
      } else if (data.message === "BRANCH_LIMIT_EXCEEDED") {
        alert("Branch limit exceeded. Upgrade to add more branches.");
      } else {
        alert(data.message || "Unable to create branch");
      }
    } catch (error) {
      alert("Something went wrong. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#FAFAFA] p-6 md:p-12 flex items-center justify-center">
      <div className="max-w-2xl w-full">
        
        {/* Header Section */}
        <div className="mb-10 text-center md:text-left">
          <div className="inline-flex items-center gap-2 bg-orange-100 text-orange-600 px-4 py-1.5 rounded-full mb-4">
            <LayoutGrid size={14} />
            <span className="text-[10px] font-black uppercase tracking-widest">Multi-Outlet Management</span>
          </div>
          <h1 className="text-4xl font-black text-gray-900 tracking-tight mb-2">Expand Your Business</h1>
          <p className="text-gray-500 font-medium">Create a new branch and start generating QR menus in minutes.</p>
        </div>

        <div className="bg-white rounded-[2.5rem] border border-gray-100 shadow-xl shadow-orange-100/20 overflow-hidden">
          <div className="p-8 md:p-12">
            
            <div className="space-y-6">
              
              {/* Branch Name Input */}
              <div>
                <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3 block ml-1">Restaurant / Branch Name</label>
                <div className="relative group">
                  <div className="absolute left-6 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-orange-600 transition-colors">
                    <Building2 size={20} />
                  </div>
                  <input 
                    className="w-full pl-14 pr-6 py-5 rounded-2xl bg-gray-50 border-2 border-transparent focus:border-orange-500 focus:bg-white transition-all outline-none font-bold text-gray-800 placeholder:text-gray-300" 
                    placeholder="e.g. Downtown Bistro" 
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>
              </div>

              {/* City Input */}
              <div>
                <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3 block ml-1">City (Location)</label>
                <div className="relative group">
                  <div className="absolute left-6 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-orange-600 transition-colors">
                    <MapPin size={20} />
                  </div>
                  <input 
                    className="w-full pl-14 pr-6 py-5 rounded-2xl bg-gray-50 border-2 border-transparent focus:border-orange-500 focus:bg-white transition-all outline-none font-bold text-gray-800 placeholder:text-gray-300" 
                    placeholder="e.g. Mumbai"
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                  />
                </div>
              </div>

              {/* Free Trial/Pricing Context Box */}
              <div className="bg-green-50 border border-green-100 p-6 rounded-3xl flex gap-4">
                <Gift className="text-green-600 shrink-0" size={24} />
                <div className="space-y-1">
                    <p className="text-[11px] font-black text-green-700 uppercase tracking-widest">Trial Expansion</p>
                    <p className="text-sm font-medium text-green-600 leading-snug">
                        Setting up new branches is <span className="font-bold underline">completely free</span> during your trial phase. Explore our full multi-outlet dashboard at no cost.
                    </p>
                </div>
              </div>

              {/* Action Button */}
              <button 
                onClick={createBranch}
                disabled={isSubmitting}
                className="w-full bg-gray-900 text-white py-6 rounded-[2rem] font-black text-xs uppercase tracking-[0.2em] hover:bg-orange-600 disabled:bg-gray-400 transition-all shadow-xl shadow-gray-200 flex items-center justify-center gap-3 active:scale-[0.98]"
              >
                {isSubmitting ? (
                    <div className="animate-spin h-5 w-5 border-2 border-white border-t-transparent rounded-full" />
                ) : (
                    <>
                        <Plus size={18} /> Create Branch
                    </>
                )}
              </button>

              <p className="text-center text-[10px] font-bold text-gray-400 uppercase tracking-widest flex items-center justify-center gap-2">
                <ShieldCheck size={12} className="text-green-500" /> Instant Menu Generation Enabled
              </p>

            </div>
          </div>
          
          {/* Footer Informational Bar */}
          <div className="bg-gray-50 py-4 px-8 border-t border-gray-100 flex justify-between items-center">
            <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-orange-500 animate-pulse" />
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">System Ready</span>
            </div>
            <div className="flex items-center gap-1 group cursor-pointer" onClick={() => router.push("/manageplan")}>
                <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest group-hover:text-orange-600 transition-colors">View Pricing</span>
                <ArrowRight size={10} className="text-gray-400 group-hover:text-orange-600" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}