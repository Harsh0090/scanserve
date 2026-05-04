// "use client";
// import { useEffect, useState } from "react";
// import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";
// import toast from "react-hot-toast";
// import { Trash2, ReceiptText, Filter, Calendar, LayoutDashboard, PlusCircle, IndianRupee, ShieldCheck, Info } from "lucide-react";
// import { useAuth } from "../../context/AuthContext";
// import apiConfig from "@/utils/apiConfig";

// export default function ProfitDashboard() {
//     const { user, loading2 } = useAuth();

//     console.log(user, "User");

//     const [data, setData] = useState(null);
//     const [expenses, setExpenses] = useState([]);
//     const [gstData, setGstData] = useState(null);
//     const [branches, setBranches] = useState([]);
//     const [selectedBranch, setSelectedBranch] = useState("");
//     const [loading, setLoading] = useState(false);

//     // GST State Management
//     const [isGstEnabled, setIsGstEnabled] = useState(user?.gstEnabled || false);
//     const [selectedGstRate, setSelectedGstRate] = useState(user?.gstRate || 5);
//     const [showGstPopup, setShowGstPopup] = useState(false);

//     const [showSelectPopup, setShowSelectPopup] = useState(false);

//     const today = new Date().toISOString().split("T")[0];

//     // Owners see everything. Others are limited based on permissionLevel.
//     const isLimited = user?.role !== "owner" && user?.permissionLevel === "LIMITED";

//     const [tempDates, setTempDates] = useState({ from: "2026-01-01", to: today });
//     const [activeFilter, setActiveFilter] = useState({ from: "2026-01-01", to: today });

//     const [form, setForm] = useState({
//         title: "",
//         category: "RENT",
//         amount: "",
//         expenseDate: today
//     });

//     const categories = [
//         "RENT", "SALARY", "RAW_MATERIAL", "ELECTRICITY", "WATER", "GAS",
//         "INTERNET", "STAFF_BENEFITS", "MAINTENANCE", "REPAIRS", "EQUIPMENT",
//         "MARKETING", "ADVERTISING", "DISCOUNTS_GIVEN", "PAYMENT_FEES",
//         "DELIVERY", "PACKAGING", "TAXES", "LICENSES", "OTHER"
//     ];

//     useEffect(() => {
//         if (!loading2 && user) {
//             if (user.role === "owner") {
//                 // Using the restaurants array directly from the user data provided
//                 const fetchedBranches = user.restaurants || [];
//                 const branchesWithAll = [
//                     { _id: "ALL", name: "All Branches" },
//                     ...fetchedBranches
//                 ];
//                 setBranches(branchesWithAll);
//                 setSelectedBranch("ALL");
//             } else {
//                 setSelectedBranch(user.restaurantId);
//             }
//             setIsGstEnabled(user.gstEnabled);
//         }
//     }, [user, loading2]);

//     useEffect(() => {
//         if (selectedBranch) fetchAllData();
//     }, [activeFilter, selectedBranch]);

//     const fetchAllData = async () => {
//         try {
//             setLoading(true);
//             const promises = [fetchExpenses()];
//             if (!isLimited) promises.push(fetchProfit(), fetchGSTReport());
//             await Promise.all(promises);
//         } finally {
//             setLoading(false);
//         }
//     };

//     const fetchProfit = async () => {
//         try {
//             let url = user.role === "owner" && selectedBranch === "ALL"
//                 ? `${apiConfig.BASE_URL}/api/expenses/org-profit?from=${activeFilter.from}&to=${activeFilter.to}`
//                 : `${apiConfig.BASE_URL}/api/expenses/profit?from=${activeFilter.from}&to=${activeFilter.to}&branchId=${selectedBranch}`;

//             const res = await fetch(url, { credentials: "include", cache: "no-store" });
//             const json = await res.json();
//             setData({ totalSales: json.totalSales ?? 0, totalExpenses: json.totalExpenses ?? 0, netProfit: json.profit ?? 0 });
//         } catch (err) { console.error(err); }
//     };

//     const fetchExpenses = async () => {
//         try {
//             const query = new URLSearchParams({ branchId: selectedBranch, from: activeFilter.from, to: activeFilter.to }).toString();
//             const res = await fetch(`${apiConfig.BASE_URL}/api/expenses/?${query}`, { credentials: "include" });
//             const json = await res.json();
//             if (Array.isArray(json)) setExpenses(json.reverse());
//         } catch (err) { console.error(err); }
//     };

//     const fetchGSTReport = async () => {
//         try {
//             const query = new URLSearchParams({ from: activeFilter.from, to: activeFilter.to, restaurantId: selectedBranch }).toString();
//             const res = await fetch(`${apiConfig.BASE_URL}/api/analytics/gst-report?${query}`, { credentials: "include" });
//             const json = await res.json();
//             if (res.ok) setGstData(json);
//         } catch (err) { console.error(err); }
//     };

//     const handleAddExpense = async (e) => {
//         e.preventDefault();

//         console.log(selectedBranch, "SelectBranch");
//         if (selectedBranch == "ALL") {
//             setShowSelectPopup(true);
//             return
//         }
//         if (!form.amount) return toast.error("Enter amount");
//         try {
//             setLoading(true);
//             const res = await fetch(`${apiConfig.BASE_URL}/api/expenses`, {
//                 method: "POST",
//                 credentials: "include",
//                 headers: { "Content-Type": "application/json" },
//                 body: JSON.stringify({ ...form, restaurant: selectedBranch })
//             });
//             if (res.ok) {
//                 toast.success("Expense added");
//                 setForm({ title: "", category: "RENT", amount: "", expenseDate: today });
//                 fetchAllData();
//             }
//         } catch { toast.error("Failed"); } finally { setLoading(false); }
//     };

//     const handleDeleteExpense = async (id) => {
//         if (!confirm("Are you sure?")) return;
//         try {
//             setLoading(true);
//             await fetch(`${apiConfig.BASE_URL}/api/expenses/${id}`, { method: "DELETE", credentials: "include" });
//             toast.success("Deleted");
//             fetchAllData();
//         } catch { toast.error("Delete failed"); } finally { setLoading(false); }
//     };

//     if (loading2 || (!data && !isLimited)) {
//         return (
//             <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
//                 <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
//             </div>
//         );
//     }

//     const chartData = !isLimited ? [
//         { name: "Expenses", value: Number(data?.totalExpenses || 0), color: "#EF4444" },
//         { name: "Profit", value: Math.max(data?.netProfit || 0, 0), color: "#10B981" }
//     ] : [];

//     return (
//         <div className="p-4 md:p-8 bg-[#F9FAFB] min-h-screen space-y-8">

//             {/* REDESIGNED HEADER */}
//             <header className="bg-white p-6 rounded-[2.5rem] shadow-sm border border-slate-100">
//                 <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-6">
//                     <div className="flex items-center gap-5">
//                         <div className="p-4 bg-slate-900 rounded-[1.5rem] shadow-xl shadow-slate-200">
//                             <LayoutDashboard className="text-orange-500" size={24} />
//                         </div>
//                         <div>
//                             <h1 className="text-2xl font-black text-slate-800 tracking-tight leading-none uppercase">
//                                 {isLimited ? "Expense Tracker" : "Finance Analytics"}
//                             </h1>
//                             <div className="flex items-center gap-2 mt-2">
//                                 <span className="bg-orange-500 text-white px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-tighter">
//                                     {user?.role}
//                                 </span>
//                                 <span className="text-slate-300">|</span>
//                                 <span className="text-slate-400 text-[10px] font-bold uppercase tracking-widest">{activeFilter.from} — {activeFilter.to}</span>
//                             </div>
//                         </div>
//                     </div>

//                     <div className="flex flex-wrap items-center gap-3 w-full lg:w-auto">
//                         {user.role === "owner" && (
//                             <select
//                                 value={selectedBranch}
//                                 onChange={(e) => setSelectedBranch(e.target.value)}
//                                 className="p-3.5 px-5 rounded-2xl border-2 border-slate-50 bg-slate-50 font-bold text-xs text-slate-700 outline-none cursor-pointer transition-all focus:border-orange-500"
//                             >
//                                 {branches.map(b => <option key={b._id} value={b._id}>{b.name}</option>)}
//                             </select>
//                         )}

//                         <div className="flex items-center bg-slate-50 p-1.5 rounded-2xl border-2 border-slate-50">
//                             <Calendar size={14} className="text-orange-500 ml-3" />
//                             <input type="date" className="bg-transparent text-[11px] font-black outline-none p-2 uppercase" value={tempDates.from} onChange={(e) => setTempDates({ ...tempDates, from: e.target.value })} />
//                             <div className="h-4 w-[1px] bg-slate-200 mx-1" />
//                             <input type="date" className="bg-transparent text-[11px] font-black outline-none p-2 uppercase" value={tempDates.to} onChange={(e) => setTempDates({ ...tempDates, to: e.target.value })} />
//                         </div>

//                         <button onClick={() => setActiveFilter({ ...tempDates })} className="bg-slate-900 text-white p-3.5 px-8 rounded-2xl font-black text-xs hover:bg-orange-600 transition-all active:scale-95 flex items-center gap-2">
//                             <Filter size={14} /> APPLY
//                         </button>
//                     </div>
//                 </div>
//             </header>

//             <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
//                 <div className="lg:col-span-2 space-y-6">
//                     {!isLimited && (
//                         <>
//                             <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
//                                 <Card title="Gross Sales" value={`₹${data.totalSales}`} icon={<IndianRupee size={16} />} />
//                                 <Card title="Expenses" value={`₹${data.totalExpenses}`} color="text-red-500" />
//                                 <Card title="Net Profit" value={`₹${data.netProfit}`} color={data.netProfit >= 0 ? "text-emerald-600" : "text-red-600"} />
//                             </div>

//                             {/* TRACKING GST WITH gstEnabled Flag */}
//                             {isGstEnabled ? (
//                                 <div className="bg-white p-8 rounded-[2.5rem] border border-slate-100 shadow-sm relative overflow-hidden">
//                                     <div className="flex justify-between items-center mb-8">
//                                         <div className="flex items-center gap-3">
//                                             <div className="p-2 bg-emerald-50 rounded-lg"><ReceiptText className="text-emerald-600" size={20} /></div>
//                                             <h3 className="text-sm font-black uppercase tracking-widest text-slate-700">GST Breakdown ({selectedGstRate}%)</h3>
//                                         </div>
//                                         <div className="flex gap-2">
//                                             <span className="bg-slate-900 text-white px-3 py-1 rounded-full text-[9px] font-black uppercase">Tax Compliant</span>
//                                         </div>
//                                     </div>
//                                     <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
//                                         <div className="p-5 bg-slate-50 rounded-[1.5rem]">
//                                             <p className="text-[9px] font-black text-slate-400 uppercase">Taxable</p>
//                                             <p className="text-xl font-black text-slate-800">₹{gstData?.totalSales?.toLocaleString()}</p>
//                                         </div>
//                                         <div className="p-5 bg-slate-50 rounded-[1.5rem]">
//                                             <p className="text-[9px] font-black text-slate-400 uppercase">CGST ({(selectedGstRate / 2).toFixed(1)}%)</p>
//                                             <p className="text-xl font-black text-emerald-600">₹{(gstData?.totalGST / 2).toFixed(2)}</p>
//                                         </div>
//                                         <div className="p-5 bg-slate-50 rounded-[1.5rem]">
//                                             <p className="text-[9px] font-black text-slate-400 uppercase">SGST ({(selectedGstRate / 2).toFixed(1)}%)</p>
//                                             <p className="text-xl font-black text-emerald-600">₹{(gstData?.totalGST / 2).toFixed(2)}</p>
//                                         </div>
//                                         <div className="p-5 bg-orange-500 rounded-[1.5rem] shadow-lg shadow-orange-100">
//                                             <p className="text-[9px] font-black text-orange-100 uppercase">Total GST</p>
//                                             <p className="text-xl font-black text-white">₹{gstData?.totalGST.toLocaleString()}</p>
//                                         </div>
//                                     </div>
//                                 </div>
//                             ) : (
//                                 ''
//                                 // <div className="bg-orange-50 p-6 rounded-[2rem] border border-orange-100 flex items-center justify-between">
//                                 //     <div className="flex items-center gap-4">

//                                 //         <div className="p-3 bg-white rounded-2xl"><Info className="text-orange-500" size={24} /></div>
//                                 //         {/* <div>
//                                 //             <p className="font-black text-slate-800 text-sm uppercase">GST Tracking is Disabled</p>
//                                 //             <p className="text-slate-500 text-xs">Enable GST in settings to view tax breakdowns.</p>
//                                 //         </div> */}
//                                 //     </div>
//                                 //     <button onClick={() => setShowGstPopup(true)} className="bg-white px-4 py-2 rounded-xl text-[10px] font-black text-orange-600 shadow-sm border border-orange-100 hover:bg-orange-500 hover:text-white transition-all">ENABLE GST</button>
//                                 // </div>
//                             )}

//                             <div className="bg-white p-8 rounded-[2.5rem] shadow-sm border border-slate-100 flex flex-col md:flex-row items-center gap-10">
//                                 <div className="w-full h-64 md:w-1/2">
//                                     <ResponsiveContainer width="100%" height="100%">
//                                         <PieChart>
//                                             <Pie data={chartData} dataKey="value" innerRadius={75} outerRadius={95} paddingAngle={10}>
//                                                 {chartData.map((entry, index) => <Cell key={index} fill={entry.color} stroke="none" />)}
//                                             </Pie>
//                                             <Tooltip />
//                                         </PieChart>
//                                     </ResponsiveContainer>
//                                 </div>
//                                 <div className="space-y-4">
//                                     <h3 className="text-2xl font-black text-slate-800 uppercase tracking-tighter leading-tight">Margin Analysis</h3>
//                                     <p className="text-slate-400 text-xs font-medium max-w-xs">Visual comparison of revenue vs. operational costs for the selected period.</p>
//                                     <div className="flex gap-6 pt-2">
//                                         <span className="flex items-center gap-2 text-xs font-black uppercase"><div className="w-3 h-3 rounded-full bg-emerald-500" /> Profit</span>
//                                         <span className="flex items-center gap-2 text-xs font-black uppercase"><div className="w-3 h-3 rounded-full bg-red-500" /> Expenses</span>
//                                     </div>
//                                 </div>
//                             </div>
//                         </>
//                     )}

//                     <div className="bg-white rounded-[2.5rem] shadow-sm border border-slate-100 overflow-hidden">
//                         <div className="p-8 border-b border-slate-50 bg-white flex justify-between items-center">
//                             <h3 className="text-sm font-black uppercase tracking-widest text-slate-800">Transaction History</h3>
//                             <span className="text-[10px] font-bold text-slate-400">{expenses.length} Records Found</span>
//                         </div>
//                         <div className="max-h-[500px] overflow-y-auto">
//                             <table className="w-full text-left">
//                                 <thead className="bg-slate-50/50 text-slate-400 text-[10px] uppercase font-black sticky top-0 z-10">
//                                     <tr>
//                                         <th className="px-8 py-5">Details</th>
//                                         <th className="px-8 py-5">Date</th>
//                                         <th className="px-8 py-5 text-right">Value</th>
//                                         <th className="px-8 py-5 text-center">Action</th>
//                                     </tr>
//                                 </thead>
//                                 <tbody className="divide-y divide-slate-50">
//                                     {expenses.map((exp, i) => (
//                                         <tr key={exp._id || i} className="hover:bg-slate-50 transition-all">
//                                             <td className="px-8 py-5">
//                                                 <p className="font-black text-xs text-slate-800 uppercase tracking-tight">{exp.title || exp.category}</p>
//                                                 <p className="text-[10px] text-slate-400 font-bold">{exp.category.replace('_', ' ')}</p>
//                                             </td>
//                                             <td className="px-8 py-5 text-[11px] font-bold text-slate-500">
//                                                 {new Date(exp.expenseDate).toLocaleDateString('en-GB')}
//                                             </td>
//                                             <td className="px-8 py-5 text-right font-black text-red-500 text-xs">-₹{exp.amount.toLocaleString()}</td>
//                                             <td className="px-8 py-5 text-center">
//                                                 <button onClick={() => handleDeleteExpense(exp._id)} className="p-2.5 text-slate-300 hover:text-red-500 rounded-xl transition-all"><Trash2 size={16} /></button>
//                                             </td>
//                                         </tr>
//                                     ))}
//                                 </tbody>
//                             </table>
//                         </div>
//                     </div>
//                 </div>

//                 {/* SIDEBAR */}

//                 <div className="h-fit lg:sticky lg:top-8 space-y-6">
//                     {/* GST CONTROL BOX */}


//                     {/* {!isLimited && (
//                         <div className="bg-slate-900 p-6 rounded-[2rem] shadow-xl text-white">
//                             <div className="flex justify-between items-center mb-4">
//                                 <h3 className="text-xs font-black uppercase tracking-widest flex items-center gap-2 text-orange-500">
//                                     <ShieldCheck size={16} /> GST Status
//                                 </h3>
//                                 <div
//                                     className={`w-12 h-6 rounded-full p-1 cursor-pointer transition-all ${isGstEnabled ? 'bg-orange-500' : 'bg-slate-700'}`}
//                                     onClick={() => isGstEnabled ? setIsGstEnabled(false) : setShowGstPopup(true)}
//                                 >
//                                     <div className={`bg-white w-4 h-4 rounded-full transition-all ${isGstEnabled ? 'ml-6' : 'ml-0'}`} />
//                                 </div>
//                             </div>
//                             <p className="text-[10px] text-slate-400 leading-relaxed font-bold">
//                                 {isGstEnabled
//                                     ? `GST Tracking is currently active at ${selectedGstRate}%. All tax calculations are visible.`
//                                     : "Toggle switch to activate GST reporting for your analytics."}
//                             </p>
//                         </div>
//                     )} */}

//                     {/* 🔥 Change: Render this div ONLY if isGstEnabled is FALSE */}
//                     {!isGstEnabled ? (
//                         <div>
//                             {!isLimited && (
//                                 <div className="bg-slate-900 p-6 rounded-[2rem] shadow-xl text-white">
//                                     <div className="flex justify-between items-center mb-4">
//                                         <h3 className="text-xs font-black uppercase tracking-widest flex items-center gap-2 text-orange-500">
//                                             <ShieldCheck size={16} /> GST Status
//                                         </h3>
//                                         <div
//                                             className={`w-12 h-6 rounded-full p-1 cursor-pointer transition-all ${isGstEnabled ? 'bg-orange-500' : 'bg-slate-700'}`}
//                                             onClick={() => isGstEnabled ? setIsGstEnabled(false) : setShowGstPopup(true)}
//                                         >
//                                             <div className={`bg-white w-4 h-4 rounded-full transition-all ${isGstEnabled ? 'ml-6' : 'ml-0'}`} />
//                                         </div>
//                                     </div>
//                                     <p className="text-[10px] text-slate-400 leading-relaxed font-bold">
//                                         {/* This branch will technically only show the "Toggle switch..." text now */}
//                                         Toggle switch to activate GST reporting for your analytics.
//                                     </p>
//                                 </div>
//                             )}
//                         </div>
//                     ) : ""}

//                     {/* ADD EXPENSE FORM */}
//                     <div className="bg-white p-8 rounded-[2.5rem] shadow-2xl shadow-slate-200 border border-slate-100">
//                         <div className="flex items-center gap-3 mb-8">
//                             <div className="p-2 bg-orange-500 rounded-xl shadow-lg shadow-orange-100"><PlusCircle className="text-white" size={20} /></div>
//                             <h2 className="text-xl font-black text-slate-800 uppercase tracking-tighter">Add Expense</h2>
//                         </div>
//                         <form onSubmit={handleAddExpense} className="space-y-6">
//                             <div>
//                                 <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Category</label>
//                                 <select value={form.category} className="w-full mt-2 p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, category: e.target.value, title: "" })}>
//                                     {categories.map(cat => <option key={cat} value={cat}>{cat.replace('_', ' ')}</option>)}
//                                 </select>
//                             </div>
//                             {form.category === "OTHER" && (
//                                 <input type="text" placeholder="Specify Title" value={form.title} className="w-full p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, title: e.target.value })} required />
//                             )}
//                             <div>
//                                 <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Amount (₹)</label>
//                                 <div className="relative mt-2">
//                                     <input type="number" placeholder="0" value={form.amount} className="w-full p-4 pl-10 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-black text-xl" onChange={e => setForm({ ...form, amount: e.target.value })} />
//                                     <IndianRupee className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
//                                 </div>
//                             </div>
//                             <div>
//                                 <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Date</label>
//                                 <input type="date" value={form.expenseDate} className="w-full mt-2 p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, expenseDate: e.target.value })} />
//                             </div>
//                             <button disabled={loading} className={`w-full py-5 rounded-[1.25rem] font-black text-white shadow-xl flex items-center justify-center gap-3 tracking-widest text-xs transition-all active:scale-95 ${loading ? 'bg-slate-300' : 'bg-slate-900 hover:bg-orange-500'}`}>
//                                 {loading ? "SAVING..." : "SAVE TRANSACTION"}
//                             </button>
//                         </form>
//                     </div>
//                 </div>
//             </div>

//             {/* GST SELECTION POPUP */}
//             {showGstPopup && (
//                 <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
//                     <div className="bg-white rounded-[2.5rem] p-10 max-w-sm w-full shadow-2xl animate-in zoom-in-95 duration-200">
//                         <div className="p-4 bg-orange-50 rounded-2xl w-fit mb-6"><ReceiptText className="text-orange-500" size={32} /></div>
//                         <h2 className="text-2xl font-black text-slate-800 uppercase tracking-tighter">Enable GST</h2>
//                         <p className="text-slate-500 text-sm mt-2 font-medium">Please select the applicable GST rate for your business analytics.</p>

//                         <div className="grid grid-cols-2 gap-4 mt-8">
//                             {[5, 18].map(rate => (
//                                 <button
//                                     key={rate}
//                                     // onClick={() => {
//                                     //     setSelectedGstRate(rate);
//                                     //     setIsGstEnabled(true);
//                                     //     setShowGstPopup(false);
//                                     //     toast.success(`GST tracking enabled at ${rate}%`);
//                                     // }}

//                                     onClick={async () => {
//                                         try {
//                                             const res = await fetch(
//                                                 `${apiConfig.BASE_URL}/api/organization/gstTwo`,
//                                                 {
//                                                     method: "PUT",
//                                                     credentials: "include",
//                                                     headers: { "Content-Type": "application/json" },
//                                                     body: JSON.stringify({
//                                                         gstEnabled: true,
//                                                         gstRate: rate
//                                                     })
//                                                 }
//                                             );

//                                             const data = await res.json();

//                                             if (!res.ok) {
//                                                 toast.error(data.message);
//                                                 return;
//                                             }

//                                             setSelectedGstRate(data.gstRate);
//                                             setIsGstEnabled(data.gstEnabled);
//                                             setShowGstPopup(false);

//                                             toast.success(`GST enabled at ${rate}%`);

//                                         } catch {
//                                             toast.error("Failed to enable GST");
//                                         }
//                                     }}
//                                     className={`p-6 rounded-3xl border-2 font-black transition-all text-lg ${selectedGstRate === rate ? 'border-orange-500 bg-orange-50 text-orange-600' : 'border-slate-50 bg-slate-50 text-slate-400 hover:border-slate-200'}`}
//                                 >
//                                     {rate}%
//                                 </button>
//                             ))}
//                         </div>

//                         <button onClick={() => setShowGstPopup(false)} className="w-full mt-6 text-slate-400 font-bold text-[10px] uppercase tracking-widest hover:text-slate-600 transition-all">Cancel and stay disabled</button>
//                     </div>
//                 </div>
//             )}

//             {showSelectPopup && <div> </div>}
//         </div>
//     );
// }

// function Card({ title, value, color, icon }) {
//     return (
//         <div className="bg-white rounded-[2.5rem] shadow-sm border border-slate-100 p-8 flex justify-between items-start transition-all hover:shadow-md">
//             <div>
//                 <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">{title}</p>
//                 <p className={`text-3xl font-black mt-2 ${color || "text-slate-800"} tracking-tight`}>{value}</p>
//             </div>
//             {icon && <div className="p-2 bg-slate-50 rounded-lg text-slate-200">{icon}</div>}
//         </div>
//     );
// }

"use client";
import { useEffect, useState } from "react";
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";
import toast from "react-hot-toast";
import { Trash2, ReceiptText, Filter, Calendar, LayoutDashboard, PlusCircle, IndianRupee, ShieldCheck, Info, Store, X, ChevronRight, CheckCircle2 } from "lucide-react";
import { useAuth } from "../../context/AuthContext";
import apiConfig from "@/utils/apiConfig";

export default function ProfitDashboard() {
    const { user, loading2 } = useAuth();

    const [data, setData] = useState(null);
    const [expenses, setExpenses] = useState([]);
    const [gstData, setGstData] = useState(null);
    const [branches, setBranches] = useState([]);
    const [selectedBranch, setSelectedBranch] = useState("");
    const [loading, setLoading] = useState(false);

    // GST State Management
    const [isGstEnabled, setIsGstEnabled] = useState(user?.gstEnabled || false);
    const [selectedGstRate, setSelectedGstRate] = useState(user?.gstRate || 5);
    const [showGstPopup, setShowGstPopup] = useState(false);

    const [showSelectPopup, setShowSelectPopup] = useState(false);

    const today = new Date().toISOString().split("T")[0];

    // Owners see everything. Others are limited based on permissionLevel.
    const isLimited = user?.role !== "owner" && user?.permissionLevel === "LIMITED";

    const [tempDates, setTempDates] = useState({ from: "2026-01-01", to: today });
    const [activeFilter, setActiveFilter] = useState({ from: "2026-01-01", to: today });

    const [form, setForm] = useState({
        title: "",
        category: "RENT",
        amount: "",
        expenseDate: today
    });

    const categories = [
        "RENT", "SALARY", "RAW_MATERIAL", "ELECTRICITY", "WATER", "GAS",
        "INTERNET", "STAFF_BENEFITS", "MAINTENANCE", "REPAIRS", "EQUIPMENT",
        "MARKETING", "ADVERTISING", "DISCOUNTS_GIVEN", "PAYMENT_FEES",
        "DELIVERY", "PACKAGING", "TAXES", "LICENSES", "OTHER"
    ];

    useEffect(() => {
        if (!loading2 && user) {
            if (user.role === "owner") {
                const fetchedBranches = user.restaurants || [];
                const branchesWithAll = [
                    { _id: "ALL", name: "All Branches" },
                    ...fetchedBranches
                ];
                setBranches(branchesWithAll);
                setSelectedBranch("ALL");
            } else {
                setSelectedBranch(user.restaurantId);
            }
            setIsGstEnabled(user.gstEnabled);
        }
    }, [user, loading2]);

    useEffect(() => {
        if (selectedBranch) fetchAllData();
    }, [activeFilter, selectedBranch]);

    const fetchAllData = async () => {
        try {
            setLoading(true);
            const promises = [fetchExpenses()];
            if (!isLimited) promises.push(fetchProfit(), fetchGSTReport());
            await Promise.all(promises);
        } finally {
            setLoading(false);
        }
    };

    const fetchProfit = async () => {
        try {
            let url = user.role === "owner" && selectedBranch === "ALL"
                ? `${apiConfig.BASE_URL}/api/expenses/org-profit?from=${activeFilter.from}&to=${activeFilter.to}`
                : `${apiConfig.BASE_URL}/api/expenses/profit?from=${activeFilter.from}&to=${activeFilter.to}&branchId=${selectedBranch}`;

            const res = await fetch(url, { credentials: "include", cache: "no-store" });
            const json = await res.json();
            setData({ totalSales: json.totalSales ?? 0, totalExpenses: json.totalExpenses ?? 0, netProfit: json.profit ?? 0 });
        } catch (err) { console.error(err); }
    };

    const fetchExpenses = async () => {
        try {
            const query = new URLSearchParams({ branchId: selectedBranch, from: activeFilter.from, to: activeFilter.to }).toString();
            const res = await fetch(`${apiConfig.BASE_URL}/api/expenses/?${query}`, { credentials: "include" });
            const json = await res.json();
            if (Array.isArray(json)) setExpenses(json.reverse());
        } catch (err) { console.error(err); }
    };

    const fetchGSTReport = async () => {
        try {
            const query = new URLSearchParams({ from: activeFilter.from, to: activeFilter.to, restaurantId: selectedBranch }).toString();
            const res = await fetch(`${apiConfig.BASE_URL}/api/analytics/gst-report?${query}`, { credentials: "include" });
            const json = await res.json();
            if (res.ok) setGstData(json);
        } catch (err) { console.error(err); }
    };

    const handleAddExpense = async (e) => {
        e.preventDefault();

        if (selectedBranch == "ALL") {
            setShowSelectPopup(true);
            return;
        }
        if (!form.amount) return toast.error("Enter amount");
        try {
            setLoading(true);
            const res = await fetch(`${apiConfig.BASE_URL}/api/expenses`, {
                method: "POST",
                credentials: "include",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ ...form, restaurant: selectedBranch })
            });
            if (res.ok) {
                toast.success("Expense added");
                setForm({ title: "", category: "RENT", amount: "", expenseDate: today });
                fetchAllData();
            }
        } catch { toast.error("Failed"); } finally { setLoading(false); }
    };

    const handleDeleteExpense = async (id) => {
        if (!confirm("Are you sure?")) return;
        try {
            setLoading(true);
            await fetch(`${apiConfig.BASE_URL}/api/expenses/${id}`, { method: "DELETE", credentials: "include" });
            toast.success("Deleted");
            fetchAllData();
        } catch { toast.error("Delete failed"); } finally { setLoading(false); }
    };

    if (loading2 || (!data && !isLimited)) {
        return (
            <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
                <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
            </div>
        );
    }

    const chartData = !isLimited ? [
        { name: "Expenses", value: Number(data?.totalExpenses || 0), color: "#EF4444" },
        { name: "Profit", value: Math.max(data?.netProfit || 0, 0), color: "#10B981" }
    ] : [];

    return (
        <div className="p-4 md:p-8 bg-[#F9FAFB] min-h-screen space-y-8">

            {/* REDESIGNED HEADER */}
            <header className="bg-white p-6 rounded-[2.5rem] shadow-sm border border-slate-100">
                <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-6">
                    <div className="flex items-center gap-5">
                        <div className="p-4 bg-slate-900 rounded-[1.5rem] shadow-xl shadow-slate-200">
                            <LayoutDashboard className="text-orange-500" size={24} />
                        </div>
                        <div>
                            <h1 className="text-2xl font-black text-slate-800 tracking-tight leading-none uppercase">
                                {isLimited ? "Expense Tracker" : "Finance Analytics"}
                            </h1>
                            <div className="flex items-center gap-2 mt-2">
                                <span className="bg-orange-500 text-white px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-tighter">
                                    {user?.role}
                                </span>
                                <span className="text-slate-300">|</span>
                                <span className="text-slate-400 text-[10px] font-bold uppercase tracking-widest">{activeFilter.from} — {activeFilter.to}</span>
                            </div>
                        </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-3 w-full lg:w-auto">
                        {user.role === "owner" && (
                            <select
                                value={selectedBranch}
                                onChange={(e) => setSelectedBranch(e.target.value)}
                                className="p-3.5 px-5 rounded-2xl border-2 border-slate-50 bg-slate-50 font-bold text-xs text-slate-700 outline-none cursor-pointer transition-all focus:border-orange-500"
                            >
                                {branches.map(b => <option key={b._id} value={b._id}>{b.name}</option>)}
                            </select>
                        )}

                        <div className="flex items-center bg-slate-50 p-1.5 rounded-2xl border-2 border-slate-50">
                            <Calendar size={14} className="text-orange-500 ml-3" />
                            <input type="date" className="bg-transparent text-[11px] font-black outline-none p-2 uppercase" value={tempDates.from} onChange={(e) => setTempDates({ ...tempDates, from: e.target.value })} />
                            <div className="h-4 w-[1px] bg-slate-200 mx-1" />
                            <input type="date" className="bg-transparent text-[11px] font-black outline-none p-2 uppercase" value={tempDates.to} onChange={(e) => setTempDates({ ...tempDates, to: e.target.value })} />
                        </div>

                        <button onClick={() => setActiveFilter({ ...tempDates })} className="bg-slate-900 text-white p-3.5 px-8 rounded-2xl font-black text-xs hover:bg-orange-600 transition-all active:scale-95 flex items-center gap-2">
                            <Filter size={14} /> APPLY
                        </button>
                    </div>
                </div>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div className="lg:col-span-2 space-y-6">
                    {!isLimited && (
                        <>
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                                <Card title="Gross Sales" value={`₹${data.totalSales}`} icon={<IndianRupee size={16} />} />
                                <Card title="Expenses" value={`₹${data.totalExpenses}`} color="text-red-500" />
                                <Card title="Net Profit" value={`₹${data.netProfit}`} color={data.netProfit >= 0 ? "text-emerald-600" : "text-red-600"} />
                            </div>

                            {isGstEnabled ? (
                                <div className="bg-white p-8 rounded-[2.5rem] border border-slate-100 shadow-sm relative overflow-hidden">
                                    <div className="flex justify-between items-center mb-8">
                                        <div className="flex items-center gap-3">
                                            <div className="p-2 bg-emerald-50 rounded-lg"><ReceiptText className="text-emerald-600" size={20} /></div>
                                            <h3 className="text-sm font-black uppercase tracking-widest text-slate-700">GST Breakdown ({selectedGstRate}%)</h3>
                                        </div>
                                        <div className="flex gap-2">
                                            <span className="bg-slate-900 text-white px-3 py-1 rounded-full text-[9px] font-black uppercase">Tax Compliant</span>
                                        </div>
                                    </div>
                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                                        <div className="p-5 bg-slate-50 rounded-[1.5rem]">
                                            <p className="text-[9px] font-black text-slate-400 uppercase">Taxable</p>
                                            <p className="text-xl font-black text-slate-800">₹{gstData?.totalSales?.toLocaleString()}</p>
                                        </div>
                                        <div className="p-5 bg-slate-50 rounded-[1.5rem]">
                                            <p className="text-[9px] font-black text-slate-400 uppercase">CGST ({(selectedGstRate / 2).toFixed(1)}%)</p>
                                            <p className="text-xl font-black text-emerald-600">₹{(gstData?.totalGST / 2).toFixed(2)}</p>
                                        </div>
                                        <div className="p-5 bg-slate-50 rounded-[1.5rem]">
                                            <p className="text-[9px] font-black text-slate-400 uppercase">SGST ({(selectedGstRate / 2).toFixed(1)}%)</p>
                                            <p className="text-xl font-black text-emerald-600">₹{(gstData?.totalGST / 2).toFixed(2)}</p>
                                        </div>
                                        <div className="p-5 bg-orange-500 rounded-[1.5rem] shadow-lg shadow-orange-100">
                                            <p className="text-[9px] font-black text-orange-100 uppercase">Total GST</p>
                                            <p className="text-xl font-black text-white">₹{gstData?.totalGST.toLocaleString()}</p>
                                        </div>
                                    </div>
                                </div>
                            ) : ""}

                            <div className="bg-white p-8 rounded-[2.5rem] shadow-sm border border-slate-100 flex flex-col md:flex-row items-center gap-10">
                                <div className="w-full h-64 md:w-1/2">
                                    <ResponsiveContainer width="100%" height="100%">
                                        <PieChart>
                                            <Pie data={chartData} dataKey="value" innerRadius={75} outerRadius={95} paddingAngle={10}>
                                                {chartData.map((entry, index) => <Cell key={index} fill={entry.color} stroke="none" />)}
                                            </Pie>
                                            <Tooltip />
                                        </PieChart>
                                    </ResponsiveContainer>
                                </div>
                                <div className="space-y-4">
                                    <h3 className="text-2xl font-black text-slate-800 uppercase tracking-tighter leading-tight">Margin Analysis</h3>
                                    <p className="text-slate-400 text-xs font-medium max-w-xs">Visual comparison of revenue vs. operational costs for the selected period.</p>
                                    <div className="flex gap-6 pt-2">
                                        <span className="flex items-center gap-2 text-xs font-black uppercase"><div className="w-3 h-3 rounded-full bg-emerald-500" /> Profit</span>
                                        <span className="flex items-center gap-2 text-xs font-black uppercase"><div className="w-3 h-3 rounded-full bg-red-500" /> Expenses</span>
                                    </div>
                                </div>
                            </div>
                        </>
                    )}

                    <div className="bg-white rounded-[2.5rem] shadow-sm border border-slate-100 overflow-hidden">
                        <div className="p-8 border-b border-slate-50 bg-white flex justify-between items-center">
                            <h3 className="text-sm font-black uppercase tracking-widest text-slate-800">Transaction History</h3>
                            <span className="text-[10px] font-bold text-slate-400">{expenses.length} Records Found</span>
                        </div>
                        <div className="max-h-[500px] overflow-y-auto">
                            <table className="w-full text-left">
                                <thead className="bg-slate-50/50 text-slate-400 text-[10px] uppercase font-black sticky top-0 z-10">
                                    <tr>
                                        <th className="px-8 py-5">Details</th>
                                        <th className="px-8 py-5">Date</th>
                                        <th className="px-8 py-5 text-right">Value</th>
                                        <th className="px-8 py-5 text-center">Action</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-50">
                                    {expenses.map((exp, i) => (
                                        <tr key={exp._id || i} className="hover:bg-slate-50 transition-all">
                                            <td className="px-8 py-5">
                                                <p className="font-black text-xs text-slate-800 uppercase tracking-tight">{exp.title || exp.category}</p>
                                                <p className="text-[10px] text-slate-400 font-bold">{exp.category.replace('_', ' ')}</p>
                                            </td>
                                            <td className="px-8 py-5 text-[11px] font-bold text-slate-500">
                                                {new Date(exp.expenseDate).toLocaleDateString('en-GB')}
                                            </td>
                                            <td className="px-8 py-5 text-right font-black text-red-500 text-xs">-₹{exp.amount.toLocaleString()}</td>
                                            <td className="px-8 py-5 text-center">
                                                <button onClick={() => handleDeleteExpense(exp._id)} className="p-2.5 text-slate-300 hover:text-red-500 rounded-xl transition-all"><Trash2 size={16} /></button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                {/* SIDEBAR */}
                <div className="h-fit lg:sticky lg:top-8 space-y-6">
                    {!isGstEnabled ? (
                        <div>
                            {!isLimited && (
                                <div className="bg-slate-900 p-6 rounded-[2rem] shadow-xl text-white">
                                    <div className="flex justify-between items-center mb-4">
                                        <h3 className="text-xs font-black uppercase tracking-widest flex items-center gap-2 text-orange-500">
                                            <ShieldCheck size={16} /> GST Status
                                        </h3>
                                        <div
                                            className={`w-12 h-6 rounded-full p-1 cursor-pointer transition-all ${isGstEnabled ? 'bg-orange-500' : 'bg-slate-700'}`}
                                            onClick={() => isGstEnabled ? setIsGstEnabled(false) : setShowGstPopup(true)}
                                        >
                                            <div className={`bg-white w-4 h-4 rounded-full transition-all ${isGstEnabled ? 'ml-6' : 'ml-0'}`} />
                                        </div>
                                    </div>
                                    <p className="text-[10px] text-slate-400 leading-relaxed font-bold">
                                        Toggle switch to activate GST reporting for your analytics.
                                    </p>
                                </div>
                            )}
                        </div>
                    ) : ""}

                    <div className="bg-white p-8 rounded-[2.5rem] shadow-2xl shadow-slate-200 border border-slate-100">
                        <div className="flex items-center gap-3 mb-8">
                            <div className="p-2 bg-orange-500 rounded-xl shadow-lg shadow-orange-100"><PlusCircle className="text-white" size={20} /></div>
                            <h2 className="text-xl font-black text-slate-800 uppercase tracking-tighter">Add Expense</h2>
                        </div>
                        <form onSubmit={handleAddExpense} className="space-y-6">
                            <div>
                                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Category</label>
                                <select value={form.category} className="w-full mt-2 p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, category: e.target.value, title: "" })}>
                                    {categories.map(cat => <option key={cat} value={cat}>{cat.replace('_', ' ')}</option>)}
                                </select>
                            </div>
                            {form.category === "OTHER" && (
                                <input type="text" placeholder="Specify Title" value={form.title} className="w-full p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, title: e.target.value })} required />
                            )}
                            <div>
                                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Amount (₹)</label>
                                <div className="relative mt-2">
                                    <input type="number" placeholder="0" value={form.amount} className="w-full p-4 pl-10 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-black text-xl" onChange={e => setForm({ ...form, amount: e.target.value })} />
                                    <IndianRupee className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                                </div>
                            </div>
                            <div>
                                <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Date</label>
                                <input type="date" value={form.expenseDate} className="w-full mt-2 p-4 bg-slate-50 border-2 border-transparent focus:border-orange-500 rounded-[1.25rem] outline-none font-bold text-xs" onChange={e => setForm({ ...form, expenseDate: e.target.value })} />
                            </div>
                            <button disabled={loading} className={`w-full py-5 rounded-[1.25rem] font-black text-white shadow-xl flex items-center justify-center gap-3 tracking-widest text-xs transition-all active:scale-95 ${loading ? 'bg-slate-300' : 'bg-slate-900 hover:bg-orange-500'}`}>
                                {loading ? "SAVING..." : "SAVE TRANSACTION"}
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            {/* GST SELECTION POPUP */}
            {showGstPopup && (
                <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
                    <div className="bg-white rounded-[2.5rem] p-10 max-w-sm w-full shadow-2xl animate-in zoom-in-95 duration-200">
                        <div className="p-4 bg-orange-50 rounded-2xl w-fit mb-6"><ReceiptText className="text-orange-500" size={32} /></div>
                        <h2 className="text-2xl font-black text-slate-800 uppercase tracking-tighter">Enable GST</h2>
                        <p className="text-slate-500 text-sm mt-2 font-medium">Please select the applicable GST rate for your business analytics.</p>

                        <div className="grid grid-cols-2 gap-4 mt-8">
                            {[5, 18].map(rate => (
                                <button
                                    key={rate}
                                    onClick={async () => {
                                        try {
                                            const res = await fetch(
                                                `${apiConfig.BASE_URL}/api/organization/gstTwo`,
                                                {
                                                    method: "PUT",
                                                    credentials: "include",
                                                    headers: { "Content-Type": "application/json" },
                                                    body: JSON.stringify({
                                                        gstEnabled: true,
                                                        gstRate: rate
                                                    })
                                                }
                                            );

                                            const data = await res.json();

                                            if (!res.ok) {
                                                toast.error(data.message);
                                                return;
                                            }

                                            setSelectedGstRate(data.gstRate);
                                            setIsGstEnabled(data.gstEnabled);
                                            setShowGstPopup(false);

                                            toast.success(`GST enabled at ${rate}%`);

                                        } catch {
                                            toast.error("Failed to enable GST");
                                        }
                                    }}
                                    className={`p-6 rounded-3xl border-2 font-black transition-all text-lg ${selectedGstRate === rate ? 'border-orange-500 bg-orange-50 text-orange-600' : 'border-slate-50 bg-slate-50 text-slate-400 hover:border-slate-200'}`}
                                >
                                    {rate}%
                                </button>
                            ))}
                        </div>

                        <button onClick={() => setShowGstPopup(false)} className="w-full mt-6 text-slate-400 font-bold text-[10px] uppercase tracking-widest hover:text-slate-600 transition-all">Cancel and stay disabled</button>
                    </div>
                </div>
            )}

            {/* 🔥 BRANCH SELECTION POPUP */}
            {showSelectPopup && (
                <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-md z-[100] flex items-center justify-center p-4 animate-in fade-in duration-300">
                    <div className="bg-white w-full max-w-md rounded-[3rem] shadow-2xl overflow-hidden relative animate-in zoom-in-95 duration-300">
                        
                        {/* Header */}
                        <div className="p-8 pb-4 flex justify-between items-start">
                            <div>
                                <div className="p-3 bg-orange-50 rounded-2xl w-fit mb-4">
                                    <Store className="text-orange-500" size={24} />
                                </div>
                                <h2 className="text-2xl font-black text-slate-800 uppercase tracking-tighter">Select Branch</h2>
                                <p className="text-slate-400 text-xs font-bold mt-1 uppercase tracking-widest">Where should we record this expense?</p>
                            </div>
                            <button 
                                onClick={() => setShowSelectPopup(false)}
                                className="p-2 hover:bg-slate-100 rounded-full text-slate-300 transition-colors"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* Branch List */}
                        <div className="px-4 pb-8 max-h-[400px] overflow-y-auto no-scrollbar">
                            <div className="grid gap-3">
                                {branches
                                    .filter(b => b._id !== "ALL") 
                                    .map((branch) => (
                                        <button
                                            key={branch._id}
                                            onClick={() => {
                                                setSelectedBranch(branch._id);
                                                setShowSelectPopup(false);
                                                toast.success(`Branch set to ${branch.name}`);
                                            }}
                                            className="flex items-center justify-between p-5 rounded-[1.5rem] border-2 border-slate-50 bg-slate-50 hover:border-orange-500 hover:bg-orange-50 transition-all group text-left"
                                        >
                                            <div className="flex items-center gap-4">
                                                <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center shadow-sm group-hover:scale-110 transition-transform">
                                                    <Store size={18} className="text-slate-400 group-hover:text-orange-500" />
                                                </div>
                                                <span className="font-black text-slate-700 uppercase text-sm tracking-tight">{branch.name}</span>
                                            </div>
                                            <ChevronRight size={18} className="text-slate-300 group-hover:text-orange-500 group-hover:translate-x-1 transition-all" />
                                        </button>
                                    ))}
                            </div>
                        </div>

                        {/* Footer Info */}
                        <div className="bg-slate-50 p-6 flex items-center gap-3">
                            <div className="p-1.5 bg-white rounded-lg">
                                <CheckCircle2 size={14} className="text-emerald-500" />
                            </div>
                            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest leading-tight">
                                picking a branch ensures accurate profit margin data
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function Card({ title, value, color, icon }) {
    return (
        <div className="bg-white rounded-[2.5rem] shadow-sm border border-slate-100 p-8 flex justify-between items-start transition-all hover:shadow-md">
            <div>
                <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">{title}</p>
                <p className={`text-3xl font-black mt-2 ${color || "text-slate-800"} tracking-tight`}>{value}</p>
            </div>
            {icon && <div className="p-2 bg-slate-50 rounded-lg text-slate-300">{icon}</div>}
        </div>
    );
}