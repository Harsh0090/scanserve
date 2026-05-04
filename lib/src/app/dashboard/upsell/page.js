





"use client";
import { useEffect, useState } from "react";
import toast from "react-hot-toast";
import {
  PlusIcon,
  TrashIcon,
  PencilSquareIcon,
  SparklesIcon,
  ShoppingBagIcon,
  ArrowRightIcon,
  CheckCircleIcon,
  ArrowPathIcon
} from "@heroicons/react/24/outline";
import apiConfig from "@/utils/apiConfig";
import { useAuth } from "../../context/AuthContext";
import { apiFetch } from '../../../utils/apiClient';

export default function UpsellPage() {
  const { user, loading2 } = useAuth();

  const [menuItems, setMenuItems] = useState([]);
  const [triggerItem, setTriggerItem] = useState("");
  const [suggestedItem, setSuggestedItem] = useState("");
  const [title, setTitle] = useState("");
  const [loading, setLoading] = useState(false);
  const [rules, setRules] = useState([]);
  const [editMode, setEditMode] = useState(false);
  const [editingId, setEditingId] = useState(null);


  // const { user } = useAuth();
  // console.log("Authenticated user in UpsellPage:", user);
  // const role = typeof window !== "undefined" ? localStorage.getItem("role") : null;
  // const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
  // const restaurantId = typeof window !== "undefined" ? localStorage.getItem("restaurantId") : null;
  useEffect(() => {
    if (!user) return;

    loadMenu();
    fetchRules();
  }, [user]);

  if (loading2) return null;

  const role = user?.role;

  // const UPSellBase = role === "owner"
  //   ? "http://localhost:5000/api/upsell/global"
  //   : "http://localhost:5000/api/upsell/branch";

  // const MenuBase = role === "owner"
  //   ? "http://localhost:5000/api/global-menu"
  //   : "http://localhost:5000/api/branch-menu";

  const UPSellBase =
    role === "owner"
      ? "/api/upsell/global"
      : "/api/upsell/branch";

  const MenuBase =
    role === "owner"
      ? "/api/global-menu"
      : "/api/branch-menu";

  // const fetchRules = async () => {
  //   if (!token) return;
  //   const url = role === "owner" ? UPSellBase : `${UPSellBase}?restaurantId=${restaurantId}`;
  //   const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  //   const data = await res.json();
  //   if (!Array.isArray(data)) return;

  //   const normalized = data.map((r) => ({
  //     _id: r._id,
  //     title: r.title,
  //     triggerItem: r.globalTriggerItem,
  //     suggestedItem: r.globalSuggestedItem,
  //   }));
  //   setRules(normalized);
  // };


  const fetchRules = async () => {
    console.log("Fetching rules from:", UPSellBase);
    const res = await apiFetch(UPSellBase);
    const data = await res;
    if (!Array.isArray(data)) return;

    const normalized = data.map((r) => ({
      _id: r._id,
      title: r.title,
      triggerItem: r.globalTriggerItem,
      suggestedItem: r.globalSuggestedItem,
    }));
    setRules(normalized);
  };



  const loadMenu = async () => {
    try {
      console.log("Loading menu items from:", MenuBase);
      const res = await apiFetch(`${MenuBase}/items`);
      console.log("Menu API response:", res.success);
      if (!res.success || !Array.isArray(res.data)) {
        console.log("Unexpected menu response format", res);
        return;
      }

      const normalized = res.data.map((i) => ({
        _id: i._id,
        name: i.name || i.globalItem?.name,
      }));

      console.log("Loaded menu items:", normalized);

      setMenuItems(normalized);
    } catch (err) {
      console.error("Menu load failed", err);
    }
  };
  const resetForm = () => {
    setTriggerItem(""); setSuggestedItem(""); setTitle(""); setEditingId(null); setEditMode(false);
  };

  


  const createOrUpdateRule = async () => {
    if (!triggerItem || !suggestedItem)
      return toast.error("Select both dishes");

    setLoading(true);

    try {
      const method = editMode ? "PATCH" : "POST";
      const url = editMode
        ? `${UPSellBase}/${editingId}`
        : UPSellBase;

      const res = await apiFetch(url, {
        method,
        body: JSON.stringify({
          triggerItemId: triggerItem,
          suggestedItemId: suggestedItem,
          title: title || "Would you like to add this?",
        }),
      });

      console.log("Create/Update API response:", res);

      if (res.organization.length > 0) {
        toast.success(editMode ? "Pairing updated" : "Strategy deployed");
        resetForm();
        fetchRules();
      } else {
        toast.error(res.message || "Operation failed");
      }
    } finally {
      setLoading(false);
    }
  };


  return (
    <div className="min-h-screen bg-[#F8FAFC] pb-20 font-sans">
      {/* 1. REFINED HEADER */}
      <header className="max-w-6xl mx-auto px-6 pt-16 pb-10">
        <div className="flex items-center gap-3 mb-4">
          <div className="bg-[#FF5C00] p-2 rounded-xl shadow-lg shadow-orange-100">
            <SparklesIcon className="text-white w-5 h-5" />
          </div>
          <span className="text-[10px] font-black tracking-[0.2em] text-slate-400 uppercase">Revenue Strategy</span>
        </div>
        <h1 className="text-4xl font-black text-[#0F172A] tracking-tighter uppercase">
          Upsell <span className="text-[#FF5C00]">Logic</span>
        </h1>
        <p className="text-slate-500 mt-2 font-medium">Design automated pairings to boost your average order value.</p>
      </header>

      <main className="max-w-6xl mx-auto px-6 space-y-12">
        {/* 2. CREATION ZONE */}
        {role === "owner" && (
          <section className="bg-white rounded-[2.5rem] p-10 border border-slate-100 shadow-sm">
            <div className="flex items-center justify-between mb-10">
              <h2 className="text-xs font-black uppercase tracking-widest text-[#FF5C00]">
                {editMode ? "Modify Pairing" : "Create New Pairing"}
              </h2>
              {editMode && (
                <button onClick={resetForm} className="text-[10px] font-black text-slate-300 hover:text-red-500 uppercase flex items-center gap-2">
                  <ArrowPathIcon className="w-3 h-3" /> Reset Form
                </button>
              )}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-[1fr_auto_1fr_auto] items-center gap-8">
              {/* Trigger Input */}
              <div className="space-y-3">
                <label className="text-[11px] font-black text-slate-400 uppercase ml-1">If a customer buys...</label>
                <select
                  value={triggerItem}
                  onChange={(e) => setTriggerItem(e.target.value)}
                  className="w-full h-16 px-6 rounded-2xl bg-slate-50 border-none text-sm font-bold text-[#0F172A] focus:ring-2 focus:ring-[#FF5C00] transition-all appearance-none cursor-pointer"
                >
                  <option value="">Select Primary Item</option>
                  {menuItems.map((i) => <option key={i._id} value={i._id}>{i.name}</option>)}
                </select>
              </div>

              <div className="hidden lg:flex pt-6">
                <ArrowRightIcon className="w-6 h-6 text-slate-200" strokeWidth={3} />
              </div>

              {/* Suggestion Input */}
              <div className="space-y-3">
                <label className="text-[11px] font-black text-slate-400 uppercase ml-1">Offer them this...</label>
                <select
                  value={suggestedItem}
                  onChange={(e) => setSuggestedItem(e.target.value)}
                  className="w-full h-16 px-6 rounded-2xl bg-slate-50 border-none text-sm font-bold text-[#0F172A] focus:ring-2 focus:ring-[#FF5C00] transition-all appearance-none cursor-pointer"
                >
                  <option value="">Select Suggestion</option>
                  {menuItems.map((i) => <option key={i._id} value={i._id}>{i.name}</option>)}
                </select>
              </div>

              {/* Action Button */}
              <button
                onClick={createOrUpdateRule}
                disabled={loading}
                className="w-full lg:w-auto h-16 px-10 bg-[#0F172A] text-white rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-[#FF5C00] shadow-xl shadow-slate-100 transition-all disabled:opacity-50 flex items-center justify-center gap-3 lg:mt-6"
              >
                {editMode ? <CheckCircleIcon className="w-5 h-5" /> : <PlusIcon className="w-5 h-5" />}
                {editMode ? "Update" : "Deploy"}
              </button>
            </div>

            <div className="mt-8 pt-8 border-t border-slate-50">
              <label className="text-[11px] font-black text-slate-400 uppercase ml-1 block mb-3">Pitch Message</label>
              <input
                className="w-full bg-transparent border-b-2 border-slate-100 py-3 text-sm font-bold focus:border-[#FF5C00] outline-none transition-colors text-[#0F172A] placeholder:text-slate-300"
                placeholder="e.g. 'Complete your meal with our special bun maska!'"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>
          </section>
        )}

        {/* 3. ACTIVE LOGIC GRID */}
        <section>
          <div className="flex items-center justify-between mb-8 px-2">
            <h3 className="text-xl font-black text-[#0F172A]">Current Pairings</h3>
            <div className="flex items-center gap-2">
              <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Active rules</span>
              <div className="bg-[#0F172A] text-white px-3 py-1 rounded-lg text-xs font-black">{rules.length}</div>
            </div>
          </div>

          {rules.length === 0 ? (
            <div className="bg-white rounded-[2.5rem] py-32 text-center border-2 border-dashed border-slate-100">
              <div className="bg-slate-50 w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6">
                <SparklesIcon className="w-10 h-10 text-slate-200" />
              </div>
              <p className="text-slate-400 font-bold italic">No automated rules currently live.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {rules.map((rule) => (
                <div key={rule._id} className="group relative bg-white rounded-[2rem] p-8 border border-slate-100 shadow-sm hover:shadow-xl hover:translate-y-[-4px] transition-all">
                  <div className="flex items-center justify-between mb-6">
                    <span className="text-[10px] font-black text-slate-300 uppercase tracking-widest leading-none">
                      ID: {rule._id.slice(-6).toUpperCase()}
                    </span>
                    {role === "owner" && (
                      <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button
                          onClick={() => {
                            setEditMode(true);
                            setEditingId(rule._id);
                            setTriggerItem(rule.triggerItem?._id);
                            setSuggestedItem(rule.suggestedItem?._id);
                            setTitle(rule.title);
                            window.scrollTo({ top: 0, behavior: 'smooth' });
                          }}
                          className="p-2 bg-slate-50 text-slate-400 hover:text-[#FF5C00] rounded-xl transition-all"
                        >
                          <PencilSquareIcon className="w-4 h-4" />
                        </button>
                        <button
                          // onClick={() => {
                          //   if (confirm("Permanently remove this pairing?")) {
                          //     fetch(`${UPSellBase}/${rule._id}`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
                          //     setRules(rules.filter((r) => r._id !== rule._id));
                          //     toast.success("Rule removed");
                          //   }
                          // }}

                          onClick={async () => {
                            if (!confirm("Permanently remove this pairing?")) return;

                            try {
                              const res = await apiFetch(`/api/upsell/${rule._id}`, {
                                method: "DELETE",
                              });

                              if (res.message === "Upsell rule deleted") {
                                setRules(prev => prev.filter(r => r._id !== rule._id));
                                toast.success("Rule removed");
                              } else {
                                toast.error(res.message || "Delete failed");
                              }
                            } catch (err) {
                              toast.error("Network error");
                            }
                          }}
                          className="p-2 bg-slate-50 text-slate-400 hover:text-red-500 rounded-xl transition-all"
                        >
                          <TrashIcon className="w-4 h-4" />
                        </button>
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-4">
                    {/* Trigger Card */}
                    <div className="flex-1 bg-slate-50 rounded-2xl p-4 border border-slate-100">
                      <p className="text-[9px] font-black text-slate-400 uppercase mb-2">If Customer Buys</p>
                      <h4 className="font-bold text-[#0F172A] text-sm uppercase truncate">{rule.triggerItem?.name}</h4>
                    </div>

                    <div className="shrink-0 bg-[#FF5C00] w-8 h-8 rounded-full flex items-center justify-center shadow-lg shadow-orange-100">
                      <ArrowRightIcon className="w-4 h-4 text-white" strokeWidth={3} />
                    </div>

                    {/* Result Card */}
                    <div className="flex-1 bg-orange-50 rounded-2xl p-4 border border-orange-100">
                      <p className="text-[9px] font-black text-[#FF5C00] uppercase mb-2">Show Suggestion</p>
                      <h4 className="font-bold text-[#0F172A] text-sm uppercase truncate">{rule.suggestedItem?.name}</h4>
                    </div>
                  </div>

                  <div className="mt-6 flex items-center gap-3">
                    <div className="w-2 h-2 rounded-full bg-emerald-500" />
                    <p className="text-xs font-bold text-slate-500 italic">"{rule.title}"</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}