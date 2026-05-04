'use client'
import { useState, useEffect, useRef } from "react";
import PlanDetailPopup from "./components/PlanDetailPopup";
import { useRouter } from "next/navigation";
import { TrialFloatingBadge } from "./components/TrialFloatingBadge";
import { useTrial } from "./context/TrialContext";
import { useAuth } from "./context/AuthContext";
import apiConfig from "@/utils/apiConfig";

import {
    ArrowRight, CheckCircle2, QrCode, Sparkles,
    Smartphone, Plus, ShoppingBag, MousePointer2,
    Utensils, ScanLine, LayoutGrid, TrendingUp, Zap,
    HelpCircle, Check, Phone, User, Globe
} from "lucide-react";
import toast, { Toaster } from "react-hot-toast";

export default function Home() {
    const { triggerTrialExpired } = useTrial();
    const [isPopupOpen, setIsPopupOpen] = useState(false);
    const [isLoggedIn, setIsLoggedIn] = useState(false);
    const [daysLeft, setDaysLeft] = useState(null);
    const [contactForm, setContactForm] = useState({ name: "", phone: "", restaurant: "" });
    const router = useRouter();
    const { user, loading2 } = useAuth();
    console.log(user, "user")

    const expRef = useRef(null);
    const [expLocked, setExpLocked] = useState(true);
    const [activeLevel, setActiveLevel] = useState(1);
    const [isDropdownOpen, setIsDropdownOpen] = useState(false);
    const dropdownRef = useRef(null);

    const handleLogout = async () => {
        try {
            // 1. Hit the backend logout endpoint
            const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/logout`, {
                method: "POST",
                credentials: "include", // 🔥 REQUIRED to send/clear HTTP-only cookies
            });

            if (res.ok) {
                // 2. Clear local states
                setIsLoggedIn(false);

                // 3. Optional: Clear any non-sensitive localStorage items 
                // (Only if you still use them for UI flags)
                localStorage.clear();

                // 4. Feedback to user
                toast.success("Logged out successfully");

                // 5. Redirect to home/login
                router.push("/");

                // 6. Force a window reload (Optional but recommended)
                // This ensures all AuthContext states are completely wiped clean
                window.location.reload();
            }
        } catch (err) {
            console.error("LOGOUT_ERROR:", err);
            toast.error("Logout failed. Please try again.");
        }
    };
    useEffect(() => {
        // 1. Check login status based on whether user object exists
        setIsLoggedIn(!!user);

        // 2. Calculate trial days from the user object data
        if (user?.trialEnd) {
            const end = new Date(user.trialEnd);
            const now = new Date();
            const diffTime = end - now;
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            // Set days; if negative or zero, trial is over
            setDaysLeft(diffDays > 0 ? diffDays : 0);
        }

        // 3. Keep your existing scroll logic
        const handleExpScroll = (e) => {
            if (!expLocked) return;
            const section = expRef.current;
            if (!section) return;
            const rect = section.getBoundingClientRect();
            const isCentered = rect.top <= 20 && rect.top >= -20;

            if (isCentered) {
                if (e.deltaY > 0 && activeLevel < 4) {
                    e.preventDefault();
                    setActiveLevel(prev => prev + 1);
                } else if (e.deltaY < 0 && activeLevel > 1) {
                    e.preventDefault();
                    setActiveLevel(prev => prev - 1);
                } else if (e.deltaY > 0 && activeLevel === 4) {
                    setExpLocked(false);
                }
            }
        };

        window.addEventListener("wheel", handleExpScroll, { passive: false });
        return () => window.removeEventListener("wheel", handleExpScroll);

        // ✅ Added user and loading2 as dependencies so it updates when auth loads
    }, [user, loading2, expLocked, activeLevel]);
    const handleContactSubmit = (e) => {
        e.preventDefault();
        if (!contactForm.phone || !contactForm.name) return toast.error("Please fill all details");
        toast.success("Request sent! Our team will call you shortly.");
        setContactForm({ name: "", phone: "", restaurant: "" });
    };


    // Close dropdown if user clicks anywhere outside of it
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
                setIsDropdownOpen(false);
            }
        };
        document.addEventListener("mousedown", handleClickOutside);
        return () => document.removeEventListener("mousedown", handleClickOutside);
    }, []);

    return (
        <div className="min-h-screen bg-[#F8FAFC] font-sans text-[#0F172A] selection:bg-[#FF5C00]/10">
            <Toaster position="top-center" />
            <nav className="fixed top-0 w-full z-[100] bg-white/70 backdrop-blur-xl border-b border-slate-100 px-6 py-4">
                <div className="max-w-7xl mx-auto flex justify-between items-center">
                    {/* Logo Section */}
                    <div className="flex items-center gap-2">
                        <div className="bg-[#FF5C00] p-1.5 rounded-lg shadow-lg shadow-orange-100">
                            <QrCode className="text-white w-6 h-6" />
                        </div>
                        <span className="text-2xl font-black tracking-tighter uppercase text-[#0F172A]">
                            Scan<span className="text-[#FF5C00]">Serve</span>
                        </span>
                    </div>

                    <div className="flex items-center gap-4">
                        {!isLoggedIn ? (
                            <a href="/signup" className="bg-[#0F172A] text-white px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-[#FF5C00] transition-all">
                                Get Started
                            </a>
                        ) : (
                            <div className="relative" ref={dropdownRef}>
                                {/* Main Profile Circle - Use onClick for all devices */}
                                <div
                                    onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                                    className="w-12 h-12 bg-orange-50 border-2 border-[#FF5C00] rounded-full flex items-center justify-center text-[#FF5C00] font-black text-lg shadow-md hover:scale-105 transition-all cursor-pointer active:scale-95"
                                >
                                    {user?.data?.restaurants?.[0]?.name?.charAt(0).toUpperCase() || "N"}
                                </div>

                                {/* Navigation Dropdown - Visibility controlled by state */}
                                <div className={`absolute right-0 mt-2 w-56 bg-white rounded-[2rem] shadow-2xl border border-slate-100 py-4 transition-all duration-300 transform origin-top-right z-[110] ${isDropdownOpen
                                        ? "opacity-100 visible translate-y-0"
                                        : "opacity-0 invisible translate-y-2"
                                    }`}>
                                    <div className="px-6 pb-3 border-b border-slate-50 mb-2">
                                        <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest leading-none">Admin Panel</p>
                                        <p className="text-xs font-bold text-[#0F172A] truncate mt-1">
                                            {user?.data?.restaurants?.[0]?.name}
                                        </p>
                                    </div>

                                    {/* Dashboard Link */}
                                    <button
                                        onClick={() => {
                                            setIsDropdownOpen(false);
                                            router.push('/dashboard/orders');
                                        }}
                                        className="w-full flex items-center gap-3 px-6 py-3 hover:bg-orange-50 text-slate-600 hover:text-[#FF5C00] transition-colors"
                                    >
                                        <LayoutGrid size={18} />
                                        <span className="text-xs font-black uppercase tracking-widest">Dashboard</span>
                                    </button>

                                    {/* Public Menu Link */}
                                    <button
                                        onClick={() => {
                                            console.log(user?.restaurantId, "user?.data?.restaurantId")
                                            setIsDropdownOpen(false);
                                            router.push(`/${user?.restaurantId}`);
                                        }}
                                        className="w-full flex items-center gap-3 px-6 py-3 hover:bg-orange-50 text-slate-600 hover:text-[#FF5C00] transition-colors"
                                    >
                                        <Globe size={18} />
                                        <span className="text-xs font-black uppercase tracking-widest">Live Menu</span>
                                    </button>

                                    <div className="mt-2 pt-2 border-t border-slate-50">
                                        <button
                                            onClick={handleLogout}
                                            className="w-full text-left px-6 py-2 text-[10px] font-black text-red-400 hover:text-red-600 uppercase tracking-[0.2em]"
                                        >
                                            Log Out
                                        </button>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            </nav>

            <main className="overflow-x-hidden">
                {/* 1. HERO */}
                <section className="min-h-screen flex items-center pt-20 px-6 bg-white relative overflow-hidden">
                    <div className="absolute inset-0 bg-[radial-gradient(#e5e7eb_1px,transparent_1px)] [background-size:24px_24px] opacity-30 z-0" />
                    <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-16 items-center relative z-10">
                        <div>
                            <div className="inline-flex items-center gap-2 bg-orange-50 text-[#FF5C00] px-4 py-2 rounded-full text-[10px] font-black uppercase tracking-widest mb-8 border border-orange-100">
                                <Sparkles size={14} fill="currentColor" /> Smarter Growth Logic
                            </div>
                            <h1 className="text-5xl md:text-7xl font-black mb-8 tracking-tighter uppercase leading-[1.1]">Your Menu, <br />But <span className="text-[#FF5C00]">Profitable.</span></h1>
                            <p className="text-lg text-slate-500 mb-10 leading-relaxed max-w-lg font-medium">The average menu ignores upselling. Scan Serve automates it, suggesting the perfect pairings for every dish.</p>
                            <button onClick={() => setIsPopupOpen(true)} className="bg-[#FF5C00] text-white px-12 py-7 rounded-full font-black text-sm uppercase tracking-widest shadow-2xl shadow-orange-100 hover:scale-105 transition-all flex items-center gap-3">Start Free Trial <ArrowRight size={20} /></button>
                        </div>
                        <div className="relative group">
                            <div className="absolute -inset-4 bg-orange-100/50 rounded-[4rem] blur-3xl opacity-30" />
                            <img src="https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&q=80&w=800" alt="Hero" className="rounded-[3rem] shadow-2xl border-[12px] border-white relative z-10" />
                        </div>
                    </div>
                </section>

                {/* 2. THE FLOW */}
                <section className="min-h-screen flex items-center py-24 px-6 bg-[#F8FAFC]">
                    <div className="max-w-7xl mx-auto w-full text-center">
                        <h2 className="text-xs font-black uppercase tracking-[0.3em] text-[#FF5C00] mb-4">Operations</h2>
                        <h3 className="text-4xl font-black tracking-tight uppercase mb-16 text-[#0F172A]">From Scan to <span className="text-orange-500">Served</span></h3>
                        <div className="grid md:grid-cols-3 gap-12">
                            {[
                                { icon: ScanLine, title: "QR Scan", desc: "Customers scan a custom table QR. No app required to access your Catalog." },
                                { icon: TrendingUp, title: "Smart Upsell", desc: "Automated pairings appear instantly to boost your ticket size." },
                                { icon: Utensils, title: "Kitchen Sync", desc: "Orders fly directly to your Kitchen Command Center for real-time prep." }
                            ].map((item, i) => (
                                <div key={i} className="bg-white p-12 rounded-[3.5rem] border border-slate-100 shadow-sm relative group hover:border-[#FF5C00] transition-all duration-500">
                                    <div className="bg-slate-50 w-20 h-20 rounded-3xl flex items-center justify-center mb-8 mx-auto"><item.icon className="text-[#FF5C00]" size={32} /></div>
                                    <h4 className="text-2xl font-black mb-4 uppercase text-[#0F172A]">{item.title}</h4>
                                    <p className="text-slate-400 font-medium text-sm">{item.desc}</p>
                                </div>
                            ))}
                        </div>
                    </div>
                </section>

                {/* 3. JOURNEY - 100vh Scroll Lock */}
                <section ref={expRef} className="h-screen flex items-center py-24 px-6 bg-[#0F172A] text-white overflow-hidden relative">
                    <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-20 items-center w-full relative z-10">
                        <div className="animate-in slide-in-from-left duration-1000">
                            <h3 className="text-4xl md:text-5xl font-black tracking-tighter uppercase mb-12 leading-none">The Customer <br /><span className="text-[#FF5C00]">Lifecycle.</span></h3>
                            <div className="space-y-4">
                                {[
                                    { id: 1, label: "01. Scan Table QR", detail: "Fastest entry into your digital world. No login needed." },
                                    { id: 2, label: "02. Browse Digital Menu", detail: "High-density catalog with 3D icons for easy browsing." },
                                    { id: 3, label: "03. Smart Add & Upsell", detail: "Selecting an item triggers automated pairing suggestions." },
                                    { id: 4, label: "04. Order Confirmed", detail: "Instant confirmation with real-time kitchen sync." }
                                ].map((s) => (
                                    <div key={s.id} className={`p-6 rounded-3xl border-2 transition-all duration-500 ${activeLevel === s.id ? 'bg-white/5 border-[#FF5C00]' : 'border-transparent opacity-50'}`}>
                                        <h4 className="text-sm font-black uppercase text-[#FF5C00] mb-1">{s.label}</h4>
                                        <p className="text-xs font-bold text-slate-300 leading-relaxed">{s.detail}</p>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="relative flex justify-center">
                            <div className="bg-white p-4 rounded-[3.5rem] shadow-[0_0_120px_rgba(255,92,0,0.15)] max-w-[340px] w-full transform -rotate-2">
                                <div className="bg-[#F8FAFC] rounded-[2.8rem] h-[580px] overflow-hidden flex flex-col text-[#0F172A] transition-all">
                                    <div className="flex-1 p-6 flex flex-col">
                                        <div className="flex justify-between items-center mb-6"><div className="w-20 h-2 bg-slate-200 rounded-full" /><div className="w-8 h-8 rounded-full bg-slate-100" /></div>
                                        {activeLevel === 1 && <div className="flex-1 flex flex-col items-center justify-center animate-in zoom-in"><div className="bg-white p-6 rounded-3xl shadow-xl border border-slate-100 mb-6"><QrCode size={120} className="text-[#0F172A]" /></div><p className="text-[10px] font-black uppercase tracking-widest text-[#FF5C00]">Scan to Start</p></div>}
                                        {activeLevel === 2 && <div className="animate-in fade-in slide-in-from-bottom-4"><img src="https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=400" className="w-full h-40 object-cover rounded-3xl" alt="Pizza" /><div className="mt-4 flex justify-between"><div><span className="text-sm font-black uppercase">Margherita</span><p className="text-[10px] text-slate-400 font-bold uppercase tracking-tighter">Highly Ordered</p></div><div className="bg-slate-100 p-2 rounded-xl"><Plus size={16} /></div></div></div>}
                                        {activeLevel === 3 && <div className="animate-in zoom-in"><div className="flex justify-between items-center mb-4"><span className="text-sm font-black uppercase">Added to Cart</span><div className="bg-[#FF5C00] text-white p-2 rounded-xl shadow-lg"><Plus size={16} /></div></div><div className="bg-orange-50 p-5 rounded-3xl border border-orange-100"><p className="text-[10px] font-black text-orange-400 uppercase tracking-widest mb-3">You will love pairing it with</p><div className="flex gap-3"><div className="w-14 h-14 bg-white rounded-2xl shadow-sm border border-orange-50 animate-pulse" /><div className="w-14 h-14 bg-white rounded-2xl shadow-sm border border-orange-50 animate-pulse delay-200" /></div></div></div>}
                                        {activeLevel === 4 && <div className="flex-1 flex flex-col items-center justify-center animate-in zoom-in"><div className="w-20 h-20 bg-emerald-100 rounded-full flex items-center justify-center mb-6"><Check size={40} className="text-emerald-500" strokeWidth={4} /></div><p className="text-lg font-black uppercase text-[#0F172A]">Order Placed</p><p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-2">Check live tracking</p></div>}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>

                {/* 4. PRICING */}
                <section id="pricing" className="min-h-screen flex items-center py-24 px-6 bg-white relative overflow-hidden">
                    <div className="max-w-6xl mx-auto w-full relative z-10">
                        <div className="text-center mb-20">
                            <div className="inline-flex items-center gap-2 bg-orange-50 text-[#FF5C00] px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-[0.2em] mb-6 border border-orange-100"><Zap size={14} fill="currentColor" /> No Commissions. No Hidden Fees.</div>
                            <h2 className="text-5xl md:text-6xl font-black tracking-tighter uppercase text-[#0F172A] mb-4">Invest in <span className="text-[#FF5C00]">Growth.</span></h2>
                            <p className="text-slate-400 font-bold uppercase tracking-widest text-xs">Keep 100% of your earnings.</p>
                        </div>
                        <div className="grid md:grid-cols-2 gap-8 items-stretch max-w-5xl mx-auto">
                            <div className="bg-[#F8FAFC] p-10 rounded-[4rem] border border-slate-100 flex flex-col relative group transition-all duration-500 hover:border-slate-200">
                                <div className="mb-10 flex items-baseline gap-1"><span className="text-2xl font-black text-[#0F172A]">₹</span><span className="text-7xl font-black text-[#0F172A] tracking-tighter leading-none">1,999</span><span className="text-sm font-bold text-slate-400 uppercase tracking-widest">/mo</span></div>
                                <div className="space-y-6 mb-12 flex-1"><p className="text-[11px] font-black text-[#0F172A] uppercase tracking-widest border-b border-slate-100 pb-3 mb-6">Essential Plan</p>
                                    {["Zomato & Swiggy Sync", "WhatsApp Notifications", "Payment Gateway"].map((l, i) => (<li key={i} className="flex gap-4 items-center text-xs font-black uppercase tracking-widest text-slate-500 list-none"><CheckCircle2 className="text-slate-300" size={16} />{l}</li>))}</div>
                                <button onClick={() => setIsPopupOpen(true)} className="w-full py-6 rounded-[2.5rem] bg-[#0F172A] text-white font-black uppercase tracking-widest text-xs hover:bg-[#FF5C00] transition-all">Select Essential</button>
                            </div>
                            <div className="bg-[#0F172A] p-10 rounded-[4rem] text-white relative shadow-2xl scale-105 border-4 border-[#FF5C00]/20 flex flex-col group overflow-hidden">
                                <div className="absolute top-0 left-1/2 -translate-x-1/2 bg-[#FF5C00] text-[#0F172A] px-8 py-2 font-black text-[10px] uppercase tracking-[0.3em] rounded-b-2xl z-20 shadow-xl">Most Popular</div>
                                <div className="mb-10 mt-6 flex items-baseline gap-1 relative z-10"><span className="text-2xl font-black text-[#FF5C00]">₹</span><span className="text-7xl font-black text-white tracking-tighter leading-none">3,999</span><span className="text-sm font-bold opacity-40 uppercase tracking-widest">/mo</span></div>
                                <div className="space-y-6 mb-12 flex-1 relative z-10"><p className="text-[11px] font-black text-white uppercase tracking-widest border-b border-white/10 pb-3 mb-6">Professional Plan</p>
                                    {["Automated Upsell Logic", "Global Menu Manager", "Inventory Management Sync"].map((l, i) => (<li key={i} className="flex gap-4 items-center text-xs font-black uppercase tracking-widest opacity-80 list-none"><CheckCircle2 className="text-[#FF5C00]" size={16} />{l}</li>))}</div>
                                <button onClick={() => setIsPopupOpen(true)} className="w-full py-6 rounded-[2.5rem] bg-white text-[#0F172A] font-black uppercase tracking-widest text-xs hover:bg-[#FF5C00] hover:text-white transition-all shadow-2xl relative z-10">Go Pro Now</button>
                            </div>
                        </div>
                    </div>
                </section>

                {/* 5. FULL-WIDTH "SCALE YOUR KITCHEN" SECTION */}
                <section id="contact" className="min-h-screen w-full flex flex-col lg:flex-row bg-[#F8FAFC] overflow-hidden">
                    {/* Visual Social Proof Side */}
                    <div className="lg:w-[45%] h-full bg-[#0F172A] p-12 lg:p-24 flex flex-col justify-center relative overflow-hidden shrink-0">
                        <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_top_right,rgba(255,92,0,0.1),transparent)] pointer-events-none" />

                        <div className="relative z-10">
                            <div className="inline-flex items-center gap-2 bg-[#FF5C00] text-white px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-[0.2em] mb-10 shadow-lg">
                                <Globe size={14} /> Powering 100+ Kitchens
                            </div>
                            <h2 className="text-5xl md:text-7xl font-black text-white uppercase tracking-tighter leading-[0.9] mb-8">
                                Reclaim <br />Your <span className="text-[#FF5C00]">Time.</span>
                            </h2>
                            <p className="text-slate-400 text-lg font-medium leading-relaxed max-w-md mb-12">
                                Every manual order is a lost opportunity for efficiency. Join the elite network of restaurateurs using Scan Serve to automate their kitchen flow.
                            </p>

                            <div className="grid grid-cols-2 gap-8 border-t border-slate-800 pt-12">
                                <div>
                                    <p className="text-4xl font-black text-white leading-none mb-2 tracking-tight">15m</p>
                                    <p className="text-[10px] font-black uppercase tracking-widest text-slate-500">Saved per order</p>
                                </div>
                                <div>
                                    <p className="text-4xl font-black text-[#FF5C00] leading-none mb-2 tracking-tight">3x</p>
                                    <p className="text-[10px] font-black uppercase tracking-widest text-slate-500">Upsell Conversion</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Conversion Form Side */}
                    <div className="flex-1 bg-white p-12 lg:p-24 flex flex-col justify-center">
                        <div className="max-w-xl mx-auto w-full">
                            <div className="mb-12">
                                <h3 className="text-xs font-black uppercase tracking-[0.4em] text-slate-300 mb-2">Lead the Market</h3>
                                <p className="text-3xl font-black text-[#0F172A] uppercase tracking-tighter">Request Your Demo</p>
                            </div>

                            <form onSubmit={handleContactSubmit} className="space-y-6">
                                <div className="group relative">
                                    <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1 mb-2 block group-focus-within:text-[#FF5C00] transition-colors">Owner / Manager Name</label>
                                    <div className="relative">
                                        <User className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                                        <input
                                            value={contactForm.name}
                                            onChange={e => setContactForm({ ...contactForm, name: e.target.value })}
                                            placeholder="e.g. Arpit Shrivas"
                                            className="w-full pl-16 pr-8 py-5 bg-slate-50 border-2 border-transparent rounded-[2rem] font-bold text-[#0F172A] focus:bg-white focus:border-[#FF5C00] outline-none transition-all placeholder:text-slate-300"
                                        />
                                    </div>
                                </div>

                                <div className="group relative">
                                    <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1 mb-2 block group-focus-within:text-[#FF5C00] transition-colors">Restaurant / Business Name</label>
                                    <div className="relative">
                                        <Utensils className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                                        <input
                                            value={contactForm.restaurant}
                                            onChange={e => setContactForm({ ...contactForm, restaurant: e.target.value })}
                                            placeholder="e.g. Scan Serve Bistro"
                                            className="w-full pl-16 pr-8 py-5 bg-slate-50 border-2 border-transparent rounded-[2rem] font-bold text-[#0F172A] focus:bg-white focus:border-[#FF5C00] outline-none transition-all placeholder:text-slate-300"
                                        />
                                    </div>
                                </div>

                                <div className="group relative">
                                    <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1 mb-2 block group-focus-within:text-[#FF5C00] transition-colors">WhatsApp Contact</label>
                                    <div className="relative">
                                        <Phone className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                                        <input
                                            value={contactForm.phone}
                                            onChange={e => setContactForm({ ...contactForm, phone: e.target.value })}
                                            placeholder="+91 XXXXX XXXXX"
                                            className="w-full pl-16 pr-8 py-5 bg-slate-50 border-2 border-transparent rounded-[2rem] font-bold text-[#0F172A] focus:bg-white focus:border-[#FF5C00] outline-none transition-all placeholder:text-slate-300"
                                        />
                                    </div>
                                </div>

                                <button
                                    type="submit"
                                    className="w-full bg-[#FF5C00] text-white py-6 rounded-[2.5rem] font-black uppercase tracking-widest text-xs shadow-2xl shadow-orange-100 hover:bg-[#0F172A] hover:shadow-slate-200 transition-all active:scale-95 flex items-center justify-center gap-3 mt-4"
                                >
                                    Scale My Kitchen Now <ArrowRight size={18} />
                                </button>

                                <p className="text-center text-[9px] font-bold text-slate-400 uppercase tracking-widest mt-6">
                                    Trusted by establishments worldwide.
                                </p>
                            </form>
                        </div>
                    </div>
                </section>
            </main>

            <footer className="bg-[#0F172A] text-white py-12 px-6 text-center border-t border-slate-800">
                <p className="opacity-30 text-[10px] font-black uppercase tracking-widest">© 2026 Scan Serve Technologies • Designed for food entrepreneurs</p>
            </footer>

            <PlanDetailPopup isOpen={isPopupOpen} onClose={() => setIsPopupOpen(false)} />
            <TrialFloatingBadge daysLeft={daysLeft} />
        </div>
    );
}