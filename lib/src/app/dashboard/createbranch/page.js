

"use client";
import { useState, useEffect } from "react";
import {
  Store,
  MapPin,
  Plus,
  Loader2,
  Building2,
  Globe,
  TrendingUp,
  ShieldCheck,
  ChevronRight,
  Menu,
  X
} from "lucide-react";
import { toast } from "react-hot-toast";
import Link from "next/link";
import { apiFetch } from "../../../utils/apiClient";
export default function CreateBranchPage() {
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [loading, setLoading] = useState(true);
  const [branches, setBranches] = useState([]);
  const [businessType, setBusinessType] = useState("RESTAURANT");

  // Mobile Sidebar Toggle State
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  const getToken = () => typeof window !== "undefined" ? localStorage.getItem("token") : null;

 
  const loadBranches = async () => {
    setLoading(true)
    try {
      const data = await apiFetch("/api/restaurants");

      if (data) {
        setBranches(data);
      }

    } catch (err) {
      console.error("LOAD_BRANCH_ERROR:", err.message);
    }
    finally{
      setLoading(false)
    }
  };

  useEffect(() => {
    loadBranches();
  }, []);
  useEffect(() => { loadBranches(); }, []);

  // const createBranch = async (e) => {
  //   e.preventDefault();
  //   if (!name || !city || !businessType) {
  //     return toast.error("Branch details are incomplete");
  //   }

  //   setLoading(true);
  //   try {
  //     const res = await fetch("http://localhost:5000/api/restaurants", {
  //       method: "POST",
  //       headers: {
  //         "Content-Type": "application/json",
  //         Authorization: `Bearer ${getToken()}`
  //       },
  //       body: JSON.stringify({ name, city, businessType }),
  //     });

  //     const data = await res.json();
  //     if (!res.ok) throw new Error(data.message || "Branch registration failed");

  //     toast.success("Empire Expanded! 🎉");
  //     setName("");
  //     setCity("");
  //     setBusinessType("RESTAURANT");
  //     setIsSidebarOpen(false); // Close drawer on success
  //     loadBranches();
  //   } catch (err) {
  //     toast.error(err.message);
  //   } finally {
  //     setLoading(false);
  //   }
  // };


  const createBranch = async (e) => {
    e.preventDefault();

    if (!name || !city || !businessType) {
      return toast.error("Branch details are incomplete");
    }

    setLoading(true);

    try {
      await apiFetch("/api/restaurants", {
        method: "POST",
        body: JSON.stringify({ name, city, businessType }),
      });

      toast.success("Empire Expanded! 🎉");

      setName("");
      setCity("");
      setBusinessType("RESTAURANT");
      setIsSidebarOpen(false);

      loadBranches(); // Refresh UI

    } catch (err) {
      toast.error(err.message);
    } finally {
      setLoading(false);
    }
  };
  if(loading){
    return (
      <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
      </div>
    );
  }
  return (
    <div className="h-screen bg-[#F8FAFC] flex flex-col overflow-hidden">
      {/* 🏙️ Top Navigation Bar */}
      <div className="bg-white border-b border-slate-200 px-4 md:px-8 py-4 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-4">
          {/* Mobile Menu Trigger */}
          <button
            onClick={() => setIsSidebarOpen(true)}
            className="lg:hidden p-2 bg-slate-100 rounded-lg text-slate-600"
          >
            <Menu size={20} />
          </button>
          <div>
            <h1 className="text-lg md:text-2xl font-black text-slate-900 tracking-tight">Expand Empire</h1>
            <p className="hidden md:block text-slate-500 text-[10px] font-black uppercase tracking-[0.2em]">Infrastructure / Branch Registry</p>
          </div>
        </div>

        <div className="bg-orange-50 px-3 py-1.5 md:px-4 md:py-2 rounded-xl border border-orange-100 flex items-center gap-2 md:gap-3">
          <TrendingUp size={14} className="text-orange-600 md:w-4 md:h-4" />
          <span className="text-[10px] md:text-xs font-black text-orange-700 uppercase tracking-tighter">Outlets: {branches.length}</span>
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden relative">
        {/* 🛠️ Left Side Overlay (Backdrop) */}
        {isSidebarOpen && (
          <div
            className="fixed inset-0 bg-slate-900/40 z-40 lg:hidden backdrop-blur-sm transition-opacity"
            onClick={() => setIsSidebarOpen(false)}
          />
        )}

        {/* 🛠️ Registry Form Aside */}
        <aside className={`
          fixed inset-y-0 left-0 z-50 w-[85%] sm:w-[400px] bg-white p-6 md:p-10 overflow-y-auto transition-transform duration-300 ease-in-out shadow-2xl
          lg:static lg:translate-x-0 lg:w-[450px] lg:shadow-none lg:border-r lg:border-slate-200
          ${isSidebarOpen ? "translate-x-0" : "-translate-x-full"}
        `}>
          <div className="flex items-center justify-between mb-8 lg:block">
            <div className="w-12 h-12 lg:w-14 lg:h-14 bg-slate-900 rounded-2xl flex items-center justify-center lg:mb-6 shadow-xl shadow-slate-200">
              <Plus className="text-orange-400" size={24} />
            </div>
            <button onClick={() => setIsSidebarOpen(false)} className="lg:hidden p-2 text-slate-400">
              <X size={24} />
            </button>
          </div>

          <div className="mb-8">
            <h2 className="text-2xl lg:text-3xl font-black text-slate-900 leading-tight">Branch<br />Registration</h2>
            <p className="text-slate-400 text-sm font-medium mt-2">Deploy a new point of sale to your network.</p>
          </div>

          <form onSubmit={createBranch} className="space-y-6 lg:space-y-8">
            <div className="space-y-2 lg:space-y-3">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Establishment Name</label>
              <div className="relative group">
                <Store className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-orange-500" size={20} />
                <input
                  type="text"
                  placeholder="e.g. Malviya Nagar Bistro"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  className="w-full bg-slate-50 border-2 border-transparent focus:border-orange-500/20 focus:bg-white rounded-2xl lg:rounded-[1.5rem] py-4 lg:py-5 pl-14 pr-6 font-bold text-slate-700 outline-none transition-all"
                />
              </div>
            </div>

            <div className="space-y-2 lg:space-y-3">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Operating City</label>
              <div className="relative group">
                <MapPin className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-orange-500" size={20} />
                <input
                  type="text"
                  placeholder="e.g. Mumbai"
                  value={city}
                  onChange={e => setCity(e.target.value)}
                  className="w-full bg-slate-50 border-2 border-transparent focus:border-orange-500/20 focus:bg-white rounded-2xl lg:rounded-[1.5rem] py-4 lg:py-5 pl-14 pr-6 font-bold text-slate-700 outline-none transition-all"
                />
              </div>
            </div>

            <div className="space-y-3">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Business Type</label>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2 gap-3 lg:gap-4">
                <button
                  type="button"
                  onClick={() => setBusinessType("RESTAURANT")}
                  className={`p-4 lg:p-5 rounded-2xl border-2 transition-all text-left ${businessType === "RESTAURANT" ? "border-orange-500 bg-orange-50" : "border-slate-200 bg-white"}`}
                >
                  <p className="font-black text-sm text-slate-800">Cafe / Restaurant</p>
                  <p className="text-[10px] text-slate-400 mt-1">Tables, dine-in, POS</p>
                </button>
                <button
                  type="button"
                  onClick={() => setBusinessType("FOOD_TRUCK")}
                  className={`p-4 lg:p-5 rounded-2xl border-2 transition-all text-left ${businessType === "FOOD_TRUCK" ? "border-orange-500 bg-orange-50" : "border-slate-200 bg-white"}`}
                >
                  <p className="font-black text-sm text-slate-800">Food Truck</p>
                  <p className="text-[10px] text-slate-400 mt-1">Walk-in orders only</p>
                </button>
              </div>
            </div>

            <div className="p-4 bg-slate-50 border border-slate-100 rounded-2xl hidden sm:block">
              <div className="flex items-center gap-3 mb-2">
                <ShieldCheck size={16} className="text-emerald-500" />
                <span className="text-[10px] font-black text-slate-700 uppercase tracking-wider">Cloud Deployment</span>
              </div>
              <p className="text-[10px] text-slate-400 leading-relaxed font-medium">
                Provisioned with Menu Master Template and live sync.
              </p>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-slate-900 hover:bg-orange-600 disabled:bg-slate-200 text-white font-black py-5 lg:py-6 rounded-2xl lg:rounded-[2rem] shadow-xl transition-all active:scale-[0.98] flex items-center justify-center gap-3 uppercase tracking-[0.2em] text-[10px] lg:text-xs"
            >
              {loading ? <Loader2 className="animate-spin" size={20} /> : "Initialize Branch"}
            </button>
          </form>
        </aside>

        {/* 🗺️ Right Side: Live Network Preview */}
        <main className="flex-1 p-4 md:p-8 lg:p-12 overflow-y-auto bg-[#F8FAFC]">
          <div className="max-w-4xl mx-auto">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-8 lg:mb-10 gap-4">
              <h3 className="text-[10px] md:text-sm font-black text-slate-400 uppercase tracking-[0.3em] flex items-center gap-3">
                <Globe size={18} /> Active Network Ledger
              </h3>
              <span className="self-start sm:self-auto text-[10px] font-black bg-white px-3 py-1 border border-slate-200 rounded-full text-slate-400 uppercase">Live Sync</span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
              {branches.length === 0 ? (
                <div className="col-span-full border-2 border-dashed border-slate-200 rounded-[2rem] md:rounded-[3rem] p-12 md:p-20 flex flex-col items-center justify-center text-center opacity-50">
                  <Building2 size={48} className="text-slate-300 mb-4" />
                  <p className="font-black text-slate-400 uppercase tracking-widest text-sm">No branches deployed yet</p>
                </div>
              ) : (
                branches.map((b) => (
                  <div key={b._id} className="bg-white p-6 lg:p-8 rounded-[2rem] lg:rounded-[2.5rem] border border-slate-200 shadow-sm hover:shadow-xl hover:shadow-orange-500/5 transition-all group">
                    <div className="flex items-center justify-between mb-4 lg:mb-6">
                      <div className="p-3 bg-slate-50 rounded-xl group-hover:bg-orange-50 transition-colors">
                        <Store className="text-slate-400 group-hover:text-orange-500" size={24} />
                      </div>
                      <span className="bg-emerald-50 text-emerald-600 px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-tighter border border-emerald-100">Online</span>
                    </div>
                    <h4 className="text-lg lg:text-xl font-black text-slate-900 mb-1">{b.name}</h4>
                    <p className="text-slate-400 text-xs lg:text-sm font-bold flex items-center gap-2 mb-6">
                      <MapPin size={14} className="text-slate-300" /> {b.city}
                    </p>
                    <div className="pt-4 lg:pt-6 border-t border-slate-50">
                      <Link
                        className="flex items-center justify-between group/link"
                        href={`/dashboard/createmanager?branchId=${b._id}`}
                      >
                        <span className="text-[10px] font-black text-slate-400 group-hover/link:text-orange-600 uppercase tracking-widest transition-colors">Create Manager</span>
                        <ChevronRight size={16} className="text-slate-300 group-hover/link:text-orange-500 group-hover/link:translate-x-1 transition-all" />
                      </Link>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}