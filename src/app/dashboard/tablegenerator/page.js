"use client";
import { useState } from "react";
import QRCard from '../../components/QRCard';
import {
  QrCode,
  Plus,
  ShieldCheck,
  Info,
  LayoutGrid,
  Zap
} from "lucide-react";
import apiConfig from "@/utils/apiConfig";
export default function TableGenerator() {
  const [count, setCount] = useState("");
  const [tables, setTables] = useState([]);
  const [loading, setLoading] = useState(false);

  
  const generate = async () => {
    if (!count || count <= 0) {
      return alert("Please enter a valid number of tables");
    }

    setLoading(true);

    try {
      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/tables/generate`,
        {
          method: "POST",

          credentials: "include",   // 🔥 CRITICAL

          headers: {
            "Content-Type": "application/json",
          },

          body: JSON.stringify({
            tableCount: Number(count),

            // ❌ REMOVE THIS if backend uses req.user.restaurantId
            // restaurantId
          })
        }
      );

      const data = await res.json();

      if (!res.ok) {
        alert(data.message || "Failed to generate QR codes");
        return;
      }

      setTables(data.tables);

    } catch (err) {
      console.error("QR_GENERATE_ERROR:", err);
      alert("Network error");
    } finally {
      setLoading(false);
    }
  };
  return (
    <div className="min-h-screen bg-[#FAFAFA] p-6 md:p-12">
      <div className="max-w-6xl mx-auto">

        {/* Header */}
        <div className="mb-10 text-center md:text-left">
          <div className="inline-flex items-center gap-2 bg-orange-100 text-orange-600 px-4 py-1.5 rounded-full mb-4">
            <QrCode size={14} />
            <span className="text-[10px] font-black uppercase tracking-widest text-orange-600">Smart QR Generation</span>
          </div>
          <h1 className="text-4xl font-black text-gray-900 tracking-tight mb-2">Generate Table QRs</h1>
          <p className="text-gray-500 font-medium">Create instant digital menu access for every table in your restaurant.</p>
        </div>

        {/* Input Card */}
        <div className="bg-white rounded-[2.5rem] border border-gray-100 shadow-xl shadow-orange-100/20 p-8 md:p-10 mb-10">
          <div className="flex flex-col md:flex-row gap-6 items-end">
            <div className="flex-1 w-full">
              <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3 block ml-1">How many tables?</label>
              <div className="relative group">
                <div className="absolute left-6 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-orange-600 transition-colors">
                  <LayoutGrid size={20} />
                </div>
                <input
                  type="number"
                  placeholder="e.g. 15"
                  value={count}
                  onChange={(e) => setCount(e.target.value)}
                  className="w-full pl-14 pr-6 py-5 rounded-2xl bg-gray-50 border-2 border-transparent focus:border-orange-500 focus:bg-white transition-all outline-none font-bold text-xl text-gray-800"
                />
              </div>
            </div>

            <button
              onClick={generate}
              disabled={loading}
              className="w-full md:w-auto bg-gray-900 text-white px-10 py-5 rounded-2xl font-black text-xs uppercase tracking-[0.2em] hover:bg-orange-600 transition-all shadow-xl shadow-gray-200 flex items-center justify-center gap-3 active:scale-[0.95] whitespace-nowrap"
            >
              {loading ? "Generating..." : <><Zap size={18} /> Generate QRs</>}
            </button>
          </div>

          <div className="mt-8 bg-blue-50 border border-blue-100 p-5 rounded-2xl flex gap-4">
            <Info className="text-blue-600 shrink-0 mt-1" size={18} />
            <p className="text-[11px] font-medium text-blue-700 leading-relaxed uppercase tracking-tight">
              <span className="font-black block mb-0.5">Trial Phase Benefit</span>
              Generating QR codes is <span className="font-bold underline">Free</span> in your trial. These codes will link directly to your digital menu.
            </p>
          </div>
        </div>

        {/* QR Grid */}
        {tables.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
            {tables.map(t => (
              <QRCard key={t._id} table={t} />
            ))}
          </div>
        )}

        {/* Footer info */}
        <div className="mt-12 text-center text-[10px] font-bold text-gray-400 uppercase tracking-[0.2em] flex items-center justify-center gap-2">
          <ShieldCheck size={14} className="text-green-500" /> Powered by QRServe Secure Systems
        </div>
      </div>
    </div>
  );
}