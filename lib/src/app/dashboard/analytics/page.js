

"use client";

import { useEffect, useState } from "react";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
} from "recharts";

import {
  Store,
  TrendingUp,
  Package,
  Sparkles,
  IndianRupee,
  ChevronDown,
  BarChart3,
  Calendar,
} from "lucide-react";

import { apiFetch } from "../../../utils/apiClient";
import { useAuth } from "../../context/AuthContext";

export default function AnalyticsPage() {
  const { user } = useAuth();

  console.log(user, "user", user?.gstEnabled, user?.data?.gstEnabled);

  const [loadingBranches, setLoadingBranches] = useState(true);
  const [branches, setBranches] = useState([]);
  const [selectedBranch, setSelectedBranch] = useState("");
  const [summary, setSummary] = useState(null);
  const [graphData, setGraphData] = useState([]);
  const [mounted, setMounted] = useState(false);

  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");

  useEffect(() => {
    const today = new Date();
    const past = new Date();
    past.setDate(today.getDate() - 6);

    setEndDate(today.toISOString().split("T")[0]);
    setStartDate(past.toISOString().split("T")[0]);
    setMounted(true);
  }, []);

  useEffect(() => {
    apiFetch("/api/restaurants/list-for-analytics")
      .then((res) => {
        setBranches(res.branches || []);
        if (res.mode === "single" && res.branches.length === 1) {
          setSelectedBranch(res.branches[0]._id);
        }
        setLoadingBranches(false);
      })
      .catch(console.error);
  }, [user]);

  useEffect(() => {
    if (!selectedBranch || !startDate || !endDate) return;
    const url = selectedBranch === "ALL"
      ? `/api/analytics/org-summary?startDate=${startDate}&endDate=${endDate}`
      : `/api/analytics/summary?restaurantId=${selectedBranch}&startDate=${startDate}&endDate=${endDate}`;

    apiFetch(url).then(setSummary).catch(console.error);
  }, [selectedBranch, startDate, endDate]);

  useEffect(() => {
    if (!selectedBranch || !startDate || !endDate) return;
    const url = selectedBranch === "ALL"
      ? `/api/analytics/org-revenue-graph?startDate=${startDate}&endDate=${endDate}`
      : `/api/analytics/revenue-graph?restaurantId=${selectedBranch}&startDate=${startDate}&endDate=${endDate}`;

    apiFetch(url).then(setGraphData).catch(console.error);
  }, [selectedBranch, startDate, endDate]);



  // const PaymentBreakdownCard = ({ data }) => {

  //   if (!data) return null;

  //   const methods = [
  //     { label: "Cash", value: data.CASH || 0 },
  //     { label: "UPI", value: data.UPI || 0 },
  //     { label: "Card", value: data.CARD || 0 }
  //   ];

  //   return (
  //     <div className="bg-white rounded-2xl shadow-sm p-5 border">

  //       <h3 className="text-sm font-semibold text-gray-500 mb-4">
  //         Payment Methods
  //       </h3>

  //       <div className="space-y-3">
  //         {methods.map((m) => (
  //           <div key={m.label} className="flex justify-between items-center">

  //             <span className="text-sm text-gray-600">
  //               {m.label}
  //             </span>

  //             <span className="font-semibold">
  //               ₹{m.value.toLocaleString()}
  //             </span>

  //           </div>
  //         ))}
  //       </div>

  //     </div>
  //   );
  // };

  const PaymentBreakdownCard = ({ data }) => {
    if (!data) return null;

    const total = (data.CASH || 0) + (data.UPI || 0) + (data.CARD || 0) || 1;
    const methods = [
      { label: "Cash", value: data.CASH || 0, color: "bg-emerald-500" },
      { label: "UPI", value: data.UPI || 0, color: "bg-[#FF5C00]" },
      { label: "Card", value: data.CARD || 0, color: "bg-blue-500" }
    ];

    return (
      <div className="bg-white rounded-[2.5rem] shadow-sm p-6 border border-slate-100">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-[11px] font-black text-slate-400 uppercase tracking-widest">
            Payment Dynamics
          </h3>
          <div className="bg-slate-50 p-2 rounded-xl">
            <TrendingUp size={14} className="text-slate-400" />
          </div>
        </div>

        <div className="space-y-5">
          {methods.map((m) => {
            const percentage = (m.value / total) * 100;
            return (
              <div key={m.label} className="space-y-2">
                <div className="flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <div className={`w-1.5 h-1.5 rounded-full ${m.color}`} />
                    <span className="text-xs font-black uppercase tracking-tight text-slate-600">
                      {m.label}
                    </span>
                  </div>
                  <span className="font-black text-slate-900">
                    ₹{m.value.toLocaleString()}
                  </span>
                </div>
                {/* Progress Bar */}
                <div className="h-1.5 w-full bg-slate-50 rounded-full overflow-hidden">
                  <div
                    className={`h-full ${m.color} rounded-full transition-all duration-1000`}
                    style={{ width: `${percentage}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  if (loadingBranches) {
    return (
      <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]" />
      </div>
    );
  }

  return (
    <div className="p-6 md:p-10 bg-gray-50 min-h-screen space-y-8">
      <div className="max-w-7xl mx-auto space-y-8">

        {/* HEADER SECTION */}
        <header className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-6">
          <div>
            <h1 className="text-3xl md:text-4xl font-black text-slate-800 tracking-tight">
              Scan <span className="text-orange-600">Serve</span>
            </h1>
            <p className="text-gray-500 text-sm font-bold uppercase tracking-wider mt-1">
              Performance Insights & Revenue Dynamics
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-4">
            {/* Branch Selector */}
            <div className="relative group">
              <Store className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 group-hover:text-orange-500 transition-colors" size={18} />
              <select
                value={selectedBranch}
                onChange={(e) => setSelectedBranch(e.target.value)}
                className="pl-12 pr-10 py-4 bg-white border border-slate-100 shadow-sm rounded-2xl text-sm font-black text-slate-700 outline-none appearance-none min-w-[220px] focus:ring-2 ring-orange-100 transition-all"
              >
                <option value="">Select Branch...</option>
                <option value="ALL">All Branches</option>
                {branches.map((b) => (
                  <option key={b._id} value={b._id}>{b.name}</option>
                ))}
              </select>
              <ChevronDown className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" size={14} />
            </div>

            {/* Date Range Glassmorphism Style */}
            <div className="flex items-center gap-2 bg-white p-2 rounded-2xl shadow-sm border border-slate-100">
              <div className="flex flex-col px-3 border-r border-slate-100">
                <label className="text-[9px] font-black text-slate-400 uppercase">Start Date</label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="text-xs font-bold outline-none bg-transparent"
                />
              </div>
              <div className="flex flex-col px-3">
                <label className="text-[9px] font-black text-slate-400 uppercase">End Date</label>
                <input
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="text-xs font-bold outline-none bg-transparent"
                />
              </div>
            </div>
          </div>
        </header>

        {!selectedBranch ? (
          <div className="flex flex-col items-center justify-center py-32 bg-white rounded-[3rem] border-2 border-dashed border-slate-200 shadow-inner">
            <div className="bg-orange-50 p-6 rounded-full mb-4">
              <BarChart3 size={48} className="text-orange-500" />
            </div>
            <p className="text-slate-500 font-black uppercase tracking-widest text-sm">
              Waiting for branch selection
            </p>
          </div>
        ) : !summary ? (
          <div className="flex items-center justify-center py-40">
            <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-orange-500" />
          </div>
        ) : (
          <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">

            {/* STAT CARDS - Balanced & Clean */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              <StatCard title="Total Orders" value={summary.totalOrders} icon={<Package size={20} />} />
              <StatCard title="Net Revenue" value={`₹${Number(summary.netRevenue).toLocaleString()}`} icon={<TrendingUp size={20} />} />
              {user?.gstEnabled && <StatCard title="GST Collected" value={`₹${Number(summary.gstCollected).toFixed(2)}`} icon={<IndianRupee size={20} />} />}
              <StatCard
                title="Upsell Revenue"
                value={`₹${Number(summary.upsellRevenue).toLocaleString()}`}
                icon={<Sparkles size={20} />}
                primary
              />
            </div>

            {(user?.businessType === 'FOOD_TRUCK' || user?.data?.businessType === 'FOOD_TRUCK' || user?.type === 'foodtruck' || user?.data?.type === 'foodtruck') && summary.paymentBreakdown && (
              <div className="mt-6 max-w-sm">
                <PaymentBreakdownCard data={summary.paymentBreakdown} />
              </div>
            )}

            {/* CHART SECTION - Modern & Wide */}
            <div className="bg-white p-8 rounded-[2.5rem] shadow-sm border border-slate-100">
              <div className="flex justify-between items-center mb-8">
                <div>
                  <h3 className="text-xl font-black text-slate-800 uppercase tracking-tight">Revenue Dynamics</h3>
                  <p className="text-xs font-bold text-slate-400 uppercase">Sales vs Upsell Trends</p>
                </div>
                <div className="flex gap-4">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full bg-orange-500" />
                    <span className="text-[10px] font-black uppercase text-slate-500">Sales</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full bg-emerald-500" />
                    <span className="text-[10px] font-black uppercase text-slate-500">Upsell</span>
                  </div>
                </div>
              </div>

              <div className="h-[450px] w-full">
                {mounted && (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={graphData}>
                      <defs>
                        <linearGradient id="colorSales" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#FF4D00" stopOpacity={0.1} />
                          <stop offset="95%" stopColor="#FF4D00" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="colorUpsell" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#10B981" stopOpacity={0.1} />
                          <stop offset="95%" stopColor="#10B981" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F1F5F9" />
                      <XAxis
                        dataKey="date"
                        axisLine={false}
                        tickLine={false}
                        tick={{ fontSize: 10, fontWeight: 700, fill: '#94A3B8' }}
                        dy={10}
                      />
                      <YAxis
                        axisLine={false}
                        tickLine={false}
                        tick={{ fontSize: 10, fontWeight: 700, fill: '#94A3B8' }}
                      />
                      <Tooltip
                        contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)', fontWeight: 'bold' }}
                      />
                      <Area
                        type="monotone"
                        dataKey="sales"
                        stroke="#FF4D00"
                        strokeWidth={4}
                        fillOpacity={1}
                        fill="url(#colorSales)"
                      />
                      <Area
                        type="monotone"
                        dataKey="upsell"
                        stroke="#10B981"
                        strokeWidth={4}
                        fillOpacity={1}
                        fill="url(#colorUpsell)"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// function StatCard({ title, value, icon, primary }) {
//   return (
//     <div className={`p-8 rounded-[2rem] border transition-all hover:scale-[1.02] ${primary ? "bg-slate-900 text-white shadow-xl shadow-slate-200 border-slate-800" : "bg-white border-slate-50 shadow-sm shadow-slate-100"}`}>
//       <div className="flex justify-between items-start">
//         <div className="space-y-2">
//           <p className={`text-[10px] font-black uppercase tracking-[0.15em] ${primary ? "text-slate-400" : "text-slate-400"}`}>{title}</p>
//           <h2 className="text-3xl font-black tracking-tight leading-none">{value}</h2>
//         </div>
//         <div className={`p-4 rounded-2xl ${primary ? "bg-slate-800 text-orange-400" : "bg-orange-50 text-orange-600"}`}>
//           {icon}
//         </div>
//       </div>
//     </div>
//   );
// }

const StatCard = ({ title, value, icon, primary }) => {
  return (
    <div className={`relative overflow-hidden p-6 rounded-[2rem] transition-all duration-300 hover:-translate-y-1 
      ${primary
        ? "bg-[#0F172A] text-white shadow-2xl shadow-slate-200"
        : "bg-white border border-slate-100 shadow-sm hover:shadow-md"
      }`}>

      {/* Decorative background glow for primary card */}
      {primary && (
        <div className="absolute -right-4 -top-4 w-24 h-24 bg-[#FF5C00]/10 rounded-full blur-2xl" />
      )}

      <div className="flex items-start justify-between">
        <div className="space-y-1">
          <p className={`text-[11px] font-black uppercase tracking-widest ${primary ? "text-slate-400" : "text-slate-400"}`}>
            {title}
          </p>
          <h3 className="text-3xl font-black tracking-tighter">
            {value}
          </h3>
        </div>

        <div className={`p-3 rounded-2xl flex items-center justify-center shadow-lg 
          ${primary
            ? "bg-[#FF5C00] text-white shadow-orange-500/20"
            : "bg-orange-50 text-[#FF5C00] shadow-orange-100"
          }`}>
          {icon}
        </div>
      </div>
    </div>
  );
};