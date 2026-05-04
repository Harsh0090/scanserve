
"use client";
import { useState, useEffect } from "react";
import { Mail, Lock, ArrowRight, Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";

import apiConfig from "@/utils/apiConfig";

const ONBOARDING_DATA = [
  {
    image: "https://images.unsplash.com/photo-1595079676339-1534801ad6cf?auto=format&fit=crop&q=80&w=1200",
    title: "Simple QR Access",
    description: "Customers scan a unique QR code at their table to instantly access your digital storefront."
  },
  {
    image: "https://images.unsplash.com/photo-1556742044-3c52d6e88c62?auto=format&fit=crop&q=80&w=1200",
    title: "Browse the Menu",
    description: "A beautiful, interactive menu on their own device. No more waiting for physical menus."
  },
  {
    image: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=1200",
    title: "Instant Ordering",
    description: "Orders go directly from the customer's phone to your kitchen. Speed up service and reduce errors."
  },
  {
    image: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&q=80&w=1200",
    title: "Manage with Ease",
    description: "Watch orders arrive in real-time on your dashboard. Track sales and manage inventory effortlessly."
  }
];

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [activeSlide, setActiveSlide] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setActiveSlide((prev) => (prev + 1) % ONBOARDING_DATA.length);
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  // Designer Tip: Button lights up only if email has @ and password is typed
  const isFormValid = email.includes("@") && password.length > 0;

  const router = useRouter();

  const handleLogin = async (e) => {
    e.preventDefault();
    if (loading) return;

    setLoading(true);

    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (!res.ok)
        throw new Error(data.message || "Login failed");

      // 🔥 SAVE SESSION (for both middleware and client-side libs)
      if (data.token) {
        document.cookie = `token=${data.token}; path=/; max-age=${24 * 60 * 60}; SameSite=Lax`;
        
        // Use existing utility if available
        import("@/app/lib/auth").then(({ saveAuthSession }) => {
          saveAuthSession(data);
        }).catch(() => {
          // Fallback if import fails
          localStorage.setItem("qr_serve_session", JSON.stringify({
            token: data.token,
            role: data.role,
            restaurantId: data.restaurantId || data.restaurants?.[0]?._id,
            userName: data.name || "Admin"
          }));
        });
      }

      window.location.href = "/dashboard/orders";
    } catch (err) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  };


  return (
    <div className="min-h-screen bg-white flex flex-col lg:flex-row font-['Inter',sans-serif]">
      <section className="relative hidden lg:flex lg:w-1/2 h-screen sticky top-0 overflow-hidden">
        {ONBOARDING_DATA.map((slide, index) => (
          <div key={index} className={`absolute inset-0 transition-opacity duration-1000 ${activeSlide === index ? "opacity-100" : "opacity-0"}`}>
            <img src={slide.image} className="w-full h-full object-cover" alt="" />
            <div className="absolute inset-0 bg-black/40" />
            <div className="absolute bottom-0 left-0 p-16 w-full z-10">
              <h2 className="text-5xl font-extrabold text-white-force mb-4">{slide.title}</h2>
              <p className="text-xl text-white-force font-medium opacity-90">{slide.description}</p>
            </div>
          </div>
        ))}
      </section>

      <section className="flex-1 flex items-center justify-center p-6 sm:p-12 bg-white overflow-y-auto">
        <div className="max-w-[420px] w-full py-10">
          <div className="mb-8 flex items-center gap-2">
            <div className="w-10 h-10 bg-[#FF5C00] rounded-xl flex items-center justify-center">
              <span className="text-white-force font-black text-xl">Q</span>
            </div>
            <span className="text-2xl font-black text-slate-900 tracking-tighter">QRserve</span>
          </div>

          <h2 className="text-3xl font-extrabold text-slate-900 mb-2">Welcome Back</h2>
          <p className="text-slate-500 font-medium mb-10">Access your admin control center.</p>

          <form className="space-y-6" onSubmit={handleLogin}>
            <div className="flex flex-col gap-[6px]">
              <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Email Address</label>
              <div className="relative group">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input
                  placeholder="admin@qrserve.com"
                  className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400"
                  onChange={e => setEmail(e.target.value)}
                />
              </div>
            </div>

            <div className="flex flex-col gap-[6px]">
              <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Secret Password</label>
              <div className="relative group">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input
                  type="password" placeholder="••••••••"
                  className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400"
                  onChange={e => setPassword(e.target.value)}
                />
              </div>
            </div>

            <button
              disabled={!isFormValid || loading}
              className={`w-full py-5 rounded-2xl transition-all flex items-center justify-center gap-3 mt-4 font-bold uppercase tracking-tight
                ${!isFormValid ? "bg-slate-100 text-slate-400 cursor-not-allowed" : "bg-[#FF5C00] text-white-force hover:bg-[#E65200] active:scale-[0.98]"}`}
            >
              {loading ? <Loader2 className="animate-spin" /> : <>Enter Dashboard <ArrowRight size={20} /></>}
            </button>
          </form>
          {/* ADD THIS BLOCK BELOW */}
          <div className="mt-10 pt-8 border-t border-slate-100 text-center">
            <p className="text-slate-400 font-medium text-sm">
              Don't have an account?{" "}
              <a href="/signup" className="text-[#FF5C00] font-bold hover:underline underline-offset-4">
                Sign Up
              </a>
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}