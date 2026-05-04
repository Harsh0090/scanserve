


"use client";
import { useState, useEffect } from "react";
import {
  Users, Mail, Lock, Building2, ShieldCheck, ArrowRight,
  Info, Loader2, Trash2, Search, UserPlus, Menu, X
} from "lucide-react";
import { toast } from "react-hot-toast";
import { apiFetch } from "../../../utils/apiClient";
import apiConfig from "../../../utils/apiConfig";
export default function ManagerCreatePage() {
  const [branches, setBranches] = useState([]);
  const [branchId, setBranchId] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [permissionLevel, setPermissionLevel] = useState("LIMITED");

  // Mobile Sidebar Toggle
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  const getToken = () => typeof window !== "undefined" ? localStorage.getItem("token") : null;




  const loadBranches = async () => {
    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/restaurants`, {
        credentials: "include"   // 🔥 CRITICAL
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || "Failed to load branches");
      }

      setBranches(data);

    } catch (err) {
      toast.error(err.message || "Network error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBranches();
  }, []);



  const submit = async () => {
    if (!branchId || !email || !password || !permissionLevel)
      return toast.error("Please fill all fields");

    setSubmitting(true);

    console.log(email,
      password,
      permissionLevel, "Email , Password", "permissionLevel");

    try {
      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/restaurants/${branchId}/assign-manager`,
        {
          method: "POST",
          credentials: "include",   // 🔥 CRITICAL
          headers: {
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            email,
            password,
            permissionLevel
          })
        }
      );

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || "Assignment failed");
      }

      toast.success("Manager assigned successfully!");
      setEmail("");
      setPassword("");
      setIsSidebarOpen(false);

    } catch (err) {
      toast.error(err.message || "Connection failed");
    } finally {
      setSubmitting(false);
    }
  };


  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
      </div>
    );
  }
  return (
    <div className="h-screen bg-[#F8FAFC] flex flex-col overflow-hidden">
      {/* 🚀 Header Action Bar */}
      <div className="bg-white border-b border-slate-200 px-4 md:px-8 py-4 md:py-5 flex items-center justify-between shrink-0">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-slate-900 tracking-tight">Staff</h1>
          <p className="hidden md:block text-slate-500 text-xs font-medium uppercase tracking-wider">Access Control</p>
        </div>

        <div className="flex items-center gap-2 md:gap-4">
          <div className="relative hidden sm:block">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input
              type="text"
              placeholder="Search..."
              className="pl-10 pr-4 py-2 bg-slate-100 rounded-lg text-sm outline-none w-40 md:w-64 focus:ring-2 focus:ring-orange-500/20 transition-all"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          {/* Mobile Toggle Button */}
          <button
            onClick={() => setIsSidebarOpen(true)}
            className="lg:hidden bg-orange-500 text-white p-2 rounded-lg flex items-center gap-2 px-3 text-xs font-bold"
          >
            <UserPlus size={16} /> <span className="hidden xs:block">New</span>
          </button>
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden relative">
        {/* 📝 Left Pane: Overlay & Registration Form */}
        {/* Mobile Backdrop */}
        {isSidebarOpen && (
          <div
            className="fixed inset-0 bg-slate-900/40 z-40 lg:hidden backdrop-blur-sm"
            onClick={() => setIsSidebarOpen(false)}
          />
        )}

        <aside className={`
          fixed inset-y-0 left-0 z-50 w-[85%] sm:w-[400px] bg-white p-6 md:p-8 overflow-y-auto shadow-2xl transition-transform duration-300 transform
          lg:static lg:translate-x-0 lg:w-[450px] lg:shadow-none lg:border-r lg:border-slate-200
          ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}
        `}>
          <div className="flex items-center justify-between mb-6 lg:mb-8">
            <div className="inline-flex items-center gap-2 bg-orange-50 text-orange-600 px-3 py-1 rounded-full">
              <UserPlus size={14} />
              <span className="text-[10px] font-black uppercase tracking-widest">New Assignment</span>
            </div>
            <button onClick={() => setIsSidebarOpen(false)} className="lg:hidden p-2 text-slate-400">
              <X size={20} />
            </button>
          </div>

          <div className="space-y-5 md:space-y-6">
            <div>
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2 block">Target Branch</label>
              <div className="relative group">
                <Building2 className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <select
                  disabled={loading}
                  value={branchId}
                  onChange={e => setBranchId(e.target.value)}
                  className="w-full pl-12 pr-4 py-3 md:py-4 rounded-xl bg-slate-50 border border-slate-200 focus:border-orange-500 outline-none font-bold text-slate-700 appearance-none"
                >
                  <option value="">{loading ? "Loading..." : "Select Outlet"}</option>
                  {branches.map(b => <option key={b._id} value={b._id}>{b.name}</option>)}
                </select>
              </div>
            </div>

            <div>
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2 block">Login Email</label>
              <div className="relative group">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input
                  value={email}
                  placeholder="manager@email.com"
                  className="w-full pl-12 pr-4 py-3 md:py-4 rounded-xl bg-slate-50 border border-slate-200 focus:border-orange-500 outline-none font-bold text-slate-700"
                  onChange={e => setEmail(e.target.value)}
                />
              </div>
            </div>

            <div>
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2 block">Access Password</label>
              <div className="relative group">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input
                  type="password"
                  value={password}
                  placeholder="••••••••"
                  className="w-full pl-12 pr-4 py-3 md:py-4 rounded-xl bg-slate-50 border border-slate-200 focus:border-orange-500 outline-none font-bold text-slate-700"
                  onChange={e => setPassword(e.target.value)}
                />
              </div>
            </div>

            <div>
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2 block">
                Manager Access Level
              </label>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setPermissionLevel("LIMITED")}
                  className={`flex-1 py-3 rounded-xl border font-bold text-xs uppercase tracking-wider transition-all ${permissionLevel === "LIMITED"
                    ? "bg-slate-900 text-white border-slate-900"
                    : "bg-slate-50 text-slate-600 border-slate-200"
                    }`}
                >
                  Operations Only
                </button>

                <button
                  type="button"
                  onClick={() => setPermissionLevel("FULL")}
                  className={`flex-1 py-3 rounded-xl border font-bold text-xs uppercase tracking-wider transition-all ${permissionLevel === "FULL"
                    ? "bg-orange-600 text-white border-orange-600"
                    : "bg-slate-50 text-slate-600 border-slate-200"
                    }`}
                >
                  Full Financial Access
                </button>
              </div>
            </div>



            <button
              disabled={submitting}
              onClick={submit}
              className="w-full bg-slate-900 text-white py-4 md:py-5 rounded-2xl font-black text-[11px] uppercase tracking-[0.2em] hover:bg-orange-600 transition-all flex items-center justify-center gap-3 active:scale-95 shadow-lg"
            >
              {submitting ? <Loader2 className="animate-spin" size={18} /> : <>Deploy Manager <ArrowRight size={16} /></>}
            </button>
          </div>
        </aside>

        {/* 📋 Right Pane: Live Staff Ledger */}
        <main className="flex-1 p-4 md:p-8 overflow-y-auto bg-[#F8FAFC]">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-6 md:mb-8 gap-4">
            <h2 className="text-sm font-black text-slate-800 uppercase tracking-widest flex items-center gap-2">
              <Users size={18} className="text-slate-400" /> Management Team
            </h2>
            <div className="flex items-center gap-2 text-[10px] font-bold text-slate-400 uppercase">
              <ShieldCheck size={14} className="text-green-500" /> Secure Cloud Sync
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-1 xl:grid-cols-2 gap-4">
            {branches.map(branch => (
              <div key={branch._id} className="bg-white p-5 md:p-6 rounded-[1.5rem] md:rounded-[2rem] border border-slate-200 hover:border-orange-200 transition-all">
                <div className="flex justify-between items-start mb-4">
                  <div className="w-10 h-10 md:w-12 md:h-12 bg-slate-100 rounded-xl md:rounded-2xl flex items-center justify-center text-slate-500">
                    <Building2 size={20} md={24} />
                  </div>
                  <button className="p-2 text-slate-300 hover:text-red-500 transition-colors">
                    <Trash2 size={16} />
                  </button>
                </div>
                <div>
                  <h3 className="font-black text-slate-900 text-base md:text-lg mb-1">{branch.name}</h3>
                  <div className="flex items-center gap-2 text-slate-500 mb-4">
                    <Mail size={12} />
                    <span className="text-xs font-bold truncate max-w-[200px]">{branch?.manager?.email || "No manager assigned"}</span>
                  </div>
                  <div className="flex items-center justify-between pt-4 border-t border-slate-50">
                    <span className="text-[9px] font-black uppercase tracking-widest text-slate-400">Status</span>
                    <span className={`px-2 py-0.5 rounded text-[9px] font-black uppercase ${branch?.manager ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}`}>
                      {branch?.manager ? 'Active' : 'Vacant'}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </main>
      </div>
    </div>
  );
}