// "use client";
// import { useState, useEffect } from "react";
// import { useRouter } from "next/navigation";
// import { Building2, Mail, Lock, Phone, ArrowRight, Loader2, ChevronDown } from "lucide-react";
// import apiConfig from "@/utils/apiConfig";
// const ONBOARDING_DATA = [
//   {
//     image: "https://images.unsplash.com/photo-1595079676339-1534801ad6cf?auto=format&fit=crop&q=80&w=1200",
//     title: "Simple QR Access",
//     description: "Customers scan a unique QR code at their table to instantly access your digital storefront."
//   },
//   {
//     image: "https://images.unsplash.com/photo-1556742044-3c52d6e88c62?auto=format&fit=crop&q=80&w=1200",
//     title: "Browse the Menu",
//     description: "A beautiful, interactive menu on their own device. No more waiting for physical menus."
//   },
//   {
//     image: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=1200",
//     title: "Instant Ordering",
//     description: "Orders go directly from the customer's phone to your kitchen. Speed up service and reduce errors."
//   },
//   {
//     image: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&q=80&w=1200",
//     title: "Manage with Ease",
//     description: "Watch orders arrive in real-time on your dashboard. Track sales and manage inventory effortlessly."
//   }
// ];

// export default function SignupPage() {
//   const router = useRouter();
//   const [loading, setLoading] = useState(false);
//   const [activeSlide, setActiveSlide] = useState(0);
//   const [form, setForm] = useState({
//     organizationName: "",
//     businessType: "",
//     email: "",
//     password: "",
//     phone: "",
//     gstEnabled: false,
//     gstRate: 5
//   });

//   useEffect(() => {
//     const timer = setInterval(() => setActiveSlide((prev) => (prev + 1) % ONBOARDING_DATA.length), 5000);
//     return () => clearInterval(timer);
//   }, []);
//   const isFormValid = form.businessType && form.organizationName && form.email.includes("@") && form.phone && form.password.length >= 6; 4


//   useEffect(() => {
//     console.log(form)
//   }, [form])


//   // const submit = async () => {
//   //   if (!form.businessType) {
//   //     alert("Select business type");
//   //     return;
//   //   }

//   //   // console.log(form?.businessType)

//   //   setLoading(true);

//   //   try {
//   //     const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/signup`, {
//   //       method: "POST",
//   //       headers: { "Content-Type": "application/json" },
//   //       credentials: "include",
//   //       body: JSON.stringify(form),
//   //     });

//   //     const data = await res.json();

//   //     if (!res.ok) {
//   //       alert(data.message);
//   //       return;
//   //     }
//   //     if (form.businessType == "RESTAURANT") {
//   //       router.push("/dashboard/pos");  // ← session decides routing
//   //       console.log(form.businessType,"form.businessType");
//   //     }
//   //     else {
//   //       router.push("/dashboard/orders");  // ← session decides routing
//   //       console.log(`Navigate /dashboard/orders  , ${form?.businessType}`);
//   //     }
//   //   } finally {
//   //     setLoading(false);
//   //   }
//   // };

//   // Add 'e' as a parameter to the function
//   const submit = async (e) => {
//     // Prevent the default browser form submission behavior
//     if (e) e.preventDefault();

//     if (!form.businessType) {
//       alert("Select business type");
//       return;
//     }

//     setLoading(true);

//     try {
//       const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/signup`, {
//         method: "POST",
//         headers: { "Content-Type": "application/json" },
//         credentials: "include",
//         body: JSON.stringify(form),
//       });

//       const data = await res.json();

//       if (!res.ok) {
//         alert(data.message);
//         return;
//       }

//       if (form.businessType == "RESTAURANT") {
//         // console.log(form?.)
//         router.push("/dashboard/pos");
//         console.log(form.businessType, "form.businessType");
//       }
//       else {
//         router.push("/dashboard/orders");
//         console.log(`Maps /dashboard/orders, ${form?.businessType}`);
//       }
//     } finally {
//       setLoading(false);
//     }
//   };
//   return (
//     <div className="min-h-screen bg-white flex flex-col lg:flex-row font-sans">
//       {/* Carousel Section */}
//       <section className="relative hidden lg:flex lg:w-1/2 h-screen sticky top-0 overflow-hidden">
//         {ONBOARDING_DATA.map((slide, index) => (
//           <div key={index} className={`absolute inset-0 transition-opacity duration-1000 ${activeSlide === index ? "opacity-100" : "opacity-0"}`}>
//             <img src={slide.image} className="w-full h-full object-cover" alt="" />
//             <div className="absolute inset-0 bg-black/40" />
//             <div className="absolute bottom-0 left-0 p-16 w-full z-10">
//               <h2 className="text-5xl font-extrabold text-white mb-4">{slide.title}</h2>
//               <p className="text-xl text-white font-medium opacity-90">{slide.description}</p>
//               <div className="flex gap-2 mt-8">
//                 {ONBOARDING_DATA.map((_, i) => (
//                   <div key={i} className={`h-1.5 rounded-full transition-all ${activeSlide === i ? "w-8 bg-[#FF5C00]" : "w-2 bg-white/40"}`} />
//                 ))}
//               </div>
//             </div>
//           </div>
//         ))}
//       </section>

//       {/* Form Section */}
//       <section className="flex-1 flex items-center justify-center p-6 sm:p-12 bg-white">
//         <div className="max-w-[420px] w-full">
//           <div className="mb-8 flex items-center gap-2">
//             <div className="w-10 h-10 bg-[#FF5C00] rounded-xl flex items-center justify-center">
//               <span className="text-white font-black text-xl">Q</span>
//             </div>
//             <h1 className="text-2xl font-black text-slate-900 tracking-tighter">QRserve</h1>
//           </div>

//           <h2 className="text-3xl font-extrabold text-slate-900 mb-2">Create Partner Account</h2>
//           <p className="text-slate-500 font-medium mb-10">Join the network of modern food businesses.</p>

//           <form className="space-y-6">
//             <div className="flex flex-col gap-[6px]">
//               <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Business Nature</label>
//               <div className="relative">
//                 <Building2 className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
//                 <select
//                   className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 pr-10 appearance-none focus:border-[#FF5C00] outline-none font-semibold text-slate-700"
//                   onChange={e => setForm({ ...form, businessType: e.target.value })}
//                 >
//                   <option value="">Select Business Type</option>
//                   <option value="RESTAURANT">Cafe / Restaurant</option>
//                   <option value="FOOD_TRUCK">Food Truck</option>
//                 </select>
//                 <ChevronDown size={20} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400" />
//               </div>
//             </div>

//             <div className="flex flex-col gap-[6px]">
//               <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Brand Name</label>
//               <input
//                 placeholder="e.g. Scan Serve"
//                 className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 px-6 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400"
//                 onChange={e => setForm({ ...form, organizationName: e.target.value })}
//               />
//             </div>

//             <div className="space-y-4">
//               <div className="flex flex-col gap-[6px]"><label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Email</label>
//                 <div className="relative"><Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} /><input placeholder="admin@example.com" className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" onChange={e => setForm({ ...form, email: e.target.value })} /></div>
//               </div>
//               <div className="flex flex-col gap-[6px]"><label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Phone</label>
//                 <div className="relative"><Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} /><input placeholder="9876543210" className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" onChange={e => setForm({ ...form, phone: e.target.value })} /></div>
//               </div>
//               <div className="flex flex-col gap-[6px]"><label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Password</label>
//                 <div className="relative"><Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} /><input type="password" placeholder="••••••••" className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" onChange={e => setForm({ ...form, password: e.target.value })} /></div>
//               </div>
//             </div>

//             {/* GST SECTION */}
//             <div className="flex flex-col gap-[6px] mt-2">
//               <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">
//                 GST Settings
//               </label>

//               <div className="flex items-center gap-3">
//                 <input
//                   type="checkbox"
//                   checked={form.gstEnabled}
//                   onChange={(e) =>
//                     setForm({ ...form, gstEnabled: e.target.checked })
//                   }
//                   className="w-4 h-4 accent-[#FF5C00]"
//                 />
//                 <span className="text-sm font-semibold text-slate-700">
//                   Enable GST
//                 </span>
//               </div>

//               {form.gstEnabled && (
//                 <select
//                   value={form.gstRate}
//                   onChange={(e) =>
//                     setForm({ ...form, gstRate: Number(e.target.value) })
//                   }
//                   className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 px-6 focus:border-[#FF5C00] outline-none font-semibold text-slate-700"
//                 >
//                   <option value={5}>5% GST</option>
//                   <option value={18}>18% GST</option>
//                 </select>
//               )}
//             </div>

//             <button
//               onClick={submit}
//               disabled={!isFormValid || loading}
//               className={`w-full py-5 rounded-2xl transition-all flex items-center justify-center gap-3 mt-4 font-bold uppercase tracking-tight 
//                   ${!isFormValid ? "bg-slate-100 text-slate-400 cursor-not-allowed" : "bg-[#FF5C00] text-white hover:bg-[#E65200] active:scale-[0.98]"}`}
//             >
//               {loading ? <Loader2 className="animate-spin text-white" /> : <><span className={!isFormValid ? "text-slate-400" : "text-white"}>Get Started</span> <ArrowRight size={20} className={!isFormValid ? "text-slate-400" : "text-white"} /></>}
//             </button>
//           </form>

//           <div className="mt-10 pt-8 border-t border-slate-100 text-center">
//             <p className="text-slate-400 font-medium text-sm">Already have an account? <a href="/login" className="text-[#FF5C00] font-bold hover:underline">Log In</a></p>
//           </div>
//         </div>
//       </section>
//     </div>
//   );
// }


"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Building2, Mail, Lock, Phone, ArrowRight, Loader2, ChevronDown } from "lucide-react";
import apiConfig from "@/utils/apiConfig";
import toast, { Toaster } from "react-hot-toast";

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

export default function SignupPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [activeSlide, setActiveSlide] = useState(0);
  const [form, setForm] = useState({
    organizationName: "",
    businessType: "",
    email: "",
    password: "",
    phone: "",
    gstEnabled: false,
    gstRate: 5
  });

  // ✅ Validation Logic
  const validateEmail = (email) => {
    return String(email)
      .toLowerCase()
      .match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/);
  };

  const isFormValid = 
    form.businessType && 
    form.organizationName && 
    validateEmail(form.email) && 
    form.phone.length >= 10 && 
    form.password.length >= 6;

  useEffect(() => {
    const timer = setInterval(() => setActiveSlide((prev) => (prev + 1) % ONBOARDING_DATA.length), 5000);
    return () => clearInterval(timer);
  }, []);

  const submit = async (e) => {
    if (e) e.preventDefault();

    if (!isFormValid) return;
    
    setLoading(true);

    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/signup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify(form),
      });

      const result = await res.json();

      if (!res.ok) {
        toast.error(result.message || "Signup failed");
        setLoading(false);
        return;
      }

      // ✅ Use 'result' from the API response to decide redirection
      // This ensures we use the confirmed server-side data
      const type = result.data?.businessType || result.businessType;

      if (type === "RESTAURANT") {
        router.push("/dashboard/pos");
      } else {
        router.push("/dashboard/orders");
      }
      
      toast.success("Account created successfully!");
    } catch (err) {
      toast.error("Network error. Please try again.");
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col lg:flex-row font-sans">
      <Toaster position="top-right" />
      
      {/* Carousel Section */}
      <section className="relative hidden lg:flex lg:w-1/2 h-screen sticky top-0 overflow-hidden">
        {ONBOARDING_DATA.map((slide, index) => (
          <div key={index} className={`absolute inset-0 transition-opacity duration-1000 ${activeSlide === index ? "opacity-100" : "opacity-0"}`}>
            <img src={slide.image} className="w-full h-full object-cover" alt="" />
            <div className="absolute inset-0 bg-black/40" />
            <div className="absolute bottom-0 left-0 p-16 w-full z-10">
              <h2 className="text-5xl font-extrabold text-white mb-4">{slide.title}</h2>
              <p className="text-xl text-white font-medium opacity-90">{slide.description}</p>
              <div className="flex gap-2 mt-8">
                {ONBOARDING_DATA.map((_, i) => (
                  <div key={i} className={`h-1.5 rounded-full transition-all ${activeSlide === i ? "w-8 bg-[#FF5C00]" : "w-2 bg-white/40"}`} />
                ))}
              </div>
            </div>
          </div>
        ))}
      </section>

      {/* Form Section */}
      <section className="flex-1 flex items-center justify-center p-6 sm:p-12 bg-white">
        <div className="max-w-[420px] w-full">
          <div className="mb-8 flex items-center gap-2">
            <div className="w-10 h-10 bg-[#FF5C00] rounded-xl flex items-center justify-center">
              <span className="text-white font-black text-xl">Q</span>
            </div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tighter">QRserve</h1>
          </div>

          <h2 className="text-3xl font-extrabold text-slate-900 mb-2">Create Partner Account</h2>
          <p className="text-slate-500 font-medium mb-10">Join the network of modern food businesses.</p>

          <form onSubmit={submit} className="space-y-6">
            <div className="flex flex-col gap-[6px]">
              <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Business Nature</label>
              <div className="relative">
                <Building2 className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                <select
                  required
                  className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 pr-10 appearance-none focus:border-[#FF5C00] outline-none font-semibold text-slate-700"
                  onChange={e => setForm({ ...form, businessType: e.target.value })}
                >
                  <option value="">Select Business Type</option>
                  <option value="RESTAURANT">Cafe / Restaurant</option>
                  <option value="FOOD_TRUCK">Food Truck</option>
                </select>
                <ChevronDown size={20} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400" />
              </div>
            </div>

            <div className="flex flex-col gap-[6px]">
              <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Brand Name</label>
              <input
                required
                placeholder="e.g. Scan Serve"
                className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 px-6 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400"
                onChange={e => setForm({ ...form, organizationName: e.target.value })}
              />
            </div>

            <div className="space-y-4">
              <div className="flex flex-col gap-[6px]">
                <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Email</label>
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input 
                    type="email"
                    required
                    placeholder="admin@example.com" 
                    className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" 
                    onChange={e => setForm({ ...form, email: e.target.value })} 
                  />
                </div>
              </div>
              <div className="flex flex-col gap-[6px]">
                <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Phone</label>
                <div className="relative">
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input 
                    type="tel"
                    required
                    placeholder="9876543210" 
                    className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" 
                    onChange={e => setForm({ ...form, phone: e.target.value })} 
                  />
                </div>
              </div>
              <div className="flex flex-col gap-[6px]">
                <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">Password</label>
                <div className="relative">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input 
                    type="password" 
                    required
                    placeholder="••••••••" 
                    className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 pl-12 focus:border-[#FF5C00] outline-none font-semibold text-slate-800 placeholder:text-slate-400" 
                    onChange={e => setForm({ ...form, password: e.target.value })} 
                  />
                </div>
              </div>
            </div>

            {/* GST SECTION */}
            <div className="flex flex-col gap-[6px] mt-2">
              <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-widest ml-1">
                GST Settings
              </label>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="gstToggle"
                  checked={form.gstEnabled}
                  onChange={(e) => setForm({ ...form, gstEnabled: e.target.checked })}
                  className="w-4 h-4 accent-[#FF5C00]"
                />
                <label htmlFor="gstToggle" className="text-sm font-semibold text-slate-700 cursor-pointer">
                  Enable GST
                </label>
              </div>

              {form.gstEnabled && (
                <select
                  value={form.gstRate}
                  onChange={(e) => setForm({ ...form, gstRate: Number(e.target.value) })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-2xl py-4 px-6 focus:border-[#FF5C00] outline-none font-semibold text-slate-700"
                >
                  <option value={5}>5% GST</option>
                  <option value={18}>18% GST</option>
                </select>
              )}
            </div>

            <button
              type="submit"
              disabled={!isFormValid || loading}
              className={`w-full py-5 rounded-2xl transition-all flex items-center justify-center gap-3 mt-4 font-bold uppercase tracking-tight 
                  ${!isFormValid || loading ? "bg-slate-100 text-slate-400 cursor-not-allowed" : "bg-[#FF5C00] text-white hover:bg-[#E65200] active:scale-[0.98]"}`}
            >
              {loading ? (
                <Loader2 className="animate-spin text-[#FF5C00]" />
              ) : (
                <>Get Started <ArrowRight size={20} /></>
              )}
            </button>
          </form>

          <div className="mt-10 pt-8 border-t border-slate-100 text-center">
            <p className="text-slate-400 font-medium text-sm">Already have an account? <a href="/login" className="text-[#FF5C00] font-bold hover:underline">Log In</a></p>
          </div>
        </div>
      </section>
    </div>
  );
}