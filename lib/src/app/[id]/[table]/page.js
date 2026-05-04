
"use client";
import { useState, useEffect, useMemo } from "react";
import {
  Search, ShoppingBag, Plus, Minus, X, ArrowRight,
  Image as ImageIcon, User, Phone, CheckCircle2,
  Sparkles, Utensils, ChevronRight, ReceiptText, Loader2, QrCode
} from "lucide-react";
import { placeOrder } from "@/utils/api";
import { useParams } from "next/navigation";
import apiConfig from "@/utils/apiConfig";

export default function MenuPage() {
  // const CATEGORY_ICONS = {
  //   PIZZA: "🍕",
  //   COFFEE: "☕",
  //   PASTA: "🍝",
  //   DRINKS: "🥤",
  //   MOMOS: "🥟",
  //   BURGER: "🍔",
  //   CHINESE: "🥢",
  //   CHICKEN: "🍗",
  //   DESSERT: "🍰",
  //   ICE_CREAM: "🍦",
  //   BREAD: "🍞",
  //   SANDWICH: "🥪",
  //   DEFAULT: "🍽️"
  // };

const CATEGORY_ICONS = {
  // New Categories from your Screenshots
  BESTSELLER: "⭐",
  BUN: "🥯",
  BURGER: "🍔",
  CHAI: "☕",
  CHILLERS_MOCKTAILS: "🍹",
  COLD_COFFEE: "🧋",
  FRIES: "🍟",
  GARLIC_BREAD: "🧄",
  HEALTHY_TEA: "🍵",
  HOT_COFFEE: "☕",
  HOT_SELLING: "🔥",
  MAGGI: "🍜",
  MOMO: "🥟",
  NACHOS: "🌮",
  PIZZA: "🍕",
  SANDWICH: "🥪",
  SHAKES: "🥤",
  WRAPS: "🌯",

  // Previous & Additional Categories
  PASTA: "🍝",
  CHINESE: "🥢",
  CHICKEN: "🍗",
  DESSERT: "🍰",
  ICE_CREAM: "🍦",
  BREAD: "🍞",
  DEFAULT: "🍽️"
};
  
  const getCategoryIcon = (name) => {
    const key = name.toUpperCase().replace(/\s+/g, '_');
    return CATEGORY_ICONS[key] || CATEGORY_ICONS.DEFAULT;
  };
  const [menu, setMenu] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeCategory, setActiveCategory] = useState(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [cart, setCart] = useState({});
  const [businessType, setBusinessType] = useState(false);
  const [isReviewModalOpen, setIsReviewModalOpen] = useState(false);
  const [isCheckingOut, setIsCheckingOut] = useState(false);
  const [customerData, setCustomerData] = useState({ name: "", phone: "" });
  const [upsellData, setUpsellData] = useState({});
  const [activeUpsellId, setActiveUpsellId] = useState(null);
  const [orderProcessing, setOrderProcessing] = useState(false);
  const [orderSuccess, setOrderSuccess] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [orderId, setOrderId] = useState(null);
  const [isDownloading, setIsDownloading] = useState(false);
  const params = useParams();

  const [timeLeft, setTimeLeft] = useState(20 * 60); // 20 minutes in seconds

  useEffect(() => {
    if (orderSuccess && timeLeft > 0) {
      const timer = setInterval(() => {
        setTimeLeft((prev) => prev - 1);
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [orderSuccess, timeLeft]);

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const restaurantId = params.id;
  const tableNumber = params.table;

  console.log("Restaurant:", restaurantId);
  console.log("Table:", tableNumber);

  const waitingMessages = [
    "Our chef is currently negotiating with the ingredients...",
    "The pizza is doing its final stretches in the oven!",
    "Searching for the perfect garnish. This might take a second.",
    "Making sure your food is 100% delicious and 0% burnt.",
    "Your order is currently being treated like royalty.",
    "Adding a pinch of magic and a dash of 'Ooh-la-la'!"
  ];

  const randomMessage = useMemo(() => {
    return waitingMessages[Math.floor(Math.random() * waitingMessages.length)];
  }, [orderSuccess]);

  useEffect(() => {
    if (!restaurantId) return;
    const savedData = localStorage.getItem("customer_info");
    if (savedData) {
      const parsed = JSON.parse(savedData);
      setCustomerData({ name: parsed.name, phone: parsed.phone });
      setRememberMe(true);
    }

    fetch(`${apiConfig?.BASE_URL}/api/restaurants/${restaurantId}/context`)
      .then(res => res.json())
      .then(data => {
        if (data.businessType === "FOOD_TRUCK") setBusinessType(true);
      });

    const fetchMenu = async () => {
      try {
        const res = await fetch(`${apiConfig?.BASE_URL}/api/public/menu/${restaurantId}`);
        const data = await res.json();
        if (Array.isArray(data.items)) {
          data.items = data.items.map((i) => ({
            ...i,
            name: i.globalItem?.name || i.name || "Unnamed Item",
            basePrice: i.globalItem?.basePrice || i.basePrice || 0,
            imageUrl: i.globalItem?.imageUrl || i.imageUrl || null,
          }));
        }
        setMenu(data);
        if (data.categories?.length > 0) setActiveCategory(data.categories[0]._id);
      } catch (err) {
        console.error("Menu fetch failed", err);
      } finally {
        setTimeout(() => setLoading(false), 800);
      }
    };
    fetchMenu();
  }, [restaurantId]);

  const fetchUpsell = async (branchItemId) => {
    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/public/upsell?branchItemId=${branchItemId}`);
      const data = await res.json();
      if (data?.suggestions?.length) {
        setUpsellData(prev => ({ ...prev, [branchItemId]: data }));
        setActiveUpsellId(branchItemId);
      }
    } catch (err) {
      console.error("Upsell fetch failed", err);
    }
  };

  // const downloadBill = async () => {
  //   try {
  //     const response = await fetch(`${apiConfig.BASE_URL}/api/orders/${orderId}/invoice`, {
  //       method: "GET",
  //       credentials: "include"
  //     });
  //     const blob = await response.blob();
  //     const url = window.URL.createObjectURL(blob);
  //     const a = document.createElement("a");
  //     a.href = url;
  //     a.download = "invoice.pdf";
  //     document.body.appendChild(a);
  //     a.click();
  //     a.remove();
  //   } catch (err) {
  //     console.error(err);
  //   }
  // };

  // const downloadBill = async () => {
  //   try {

  //     const response = await fetch(
  //       `${apiConfig.BASE_URL}/api/orders/${orderId}/invoice`,
  //       { credentials: "include" }
  //     );

  //     if (!response.ok) {
  //       const err = await response.json();
  //       alert(err.message);
  //       return;
  //     }

  //     const blob = await response.blob();

  //     const url = window.URL.createObjectURL(blob);

  //     const a = document.createElement("a");
  //     a.href = url;
  //     a.download = "invoice.pdf";

  //     document.body.appendChild(a);
  //     a.click();
  //     a.remove();

  //   } catch (err) {
  //     console.error(err);
  //   }
  // };

  const downloadBill = async () => {
    try {
      setIsDownloading(true); // Start loading

      const response = await fetch(
        `${apiConfig.BASE_URL}/api/orders/${orderId}/invoice`,
        { credentials: "include" }
      );

      if (!response.ok) {
        const err = await response.json();
        alert(err.message);
        return;
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `Invoice_${orderId}.pdf`;

      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url); // Clean up memory

    } catch (err) {
      console.error(err);
      alert("Failed to download invoice");
    } finally {
      setIsDownloading(false); // Stop loading
    }
  };

  const updateQuantity = (item, delta) => {
    setCart(prev => {
      const existingItem = prev[item._id];
      const currentQty = existingItem?.quantity || 0;
      const nextQty = Math.max(0, currentQty + delta);

      // Trigger upsell logic on first add only if it's not an upsell item itself
      if (currentQty === 0 && nextQty === 1 && !item.isUpsell) {
        fetchUpsell(item._id);
      }

      const newCart = { ...prev };
      if (nextQty === 0) {
        delete newCart[item._id];
      } else {
        newCart[item._id] = {
          ...item,
          quantity: nextQty,
          isUpsell: existingItem?.isUpsell ?? item.isUpsell ?? false,
        };
      }
      return newCart;
    });
  };

  const cartItemsArray = useMemo(() => Object.values(cart), [cart]);
  const totalPrice = cartItemsArray.reduce((sum, item) => sum + (item.basePrice * item.quantity), 0);

  // ✅ FILTERED SUGGESTIONS: Don't suggest what's already in the cart
  const currentSuggestions = useMemo(() => {
    const rawSuggestions = upsellData[activeUpsellId]?.suggestions || [];
    return rawSuggestions.filter(sug => !cart[sug._id]);
  }, [upsellData, activeUpsellId, cart]);

  const finalOrderPlacement = async () => {
    if (!customerData.phone || customerData.phone.length < 10) {
      alert("Please enter a valid phone number");
      return;
    }
    setOrderProcessing(true);
    try {
      if (rememberMe) {
        localStorage.setItem("customer_info", JSON.stringify({
          name: customerData.name,
          phone: customerData.phone
        }));
      } else {
        localStorage.removeItem("customer_info");
      }
      const payload = {
        placedBy: "CUSTOMER",
        tableNumber: businessType ? null : (tableNumber || 1),
        customerName: customerData.name || "Guest",
        customerPhone: customerData.phone,
        items: cartItemsArray.map((i) => ({
          itemId: i._id,
          quantity: i.quantity,
          isUpsell: Boolean(i.isUpsell),
        })),
      };
      const order = await placeOrder(payload);
      setOrderId(order._id);
      setCart({});
      setOrderSuccess(true);
    } catch (err) {
      alert(err.message || "Failed to place order");
    } finally {
      setOrderProcessing(false);
    }
  };

  if (loading) return <MenuSkeleton />;

  // if (orderSuccess) {
  //   return (
  //     <div className="fixed inset-0 z-[200] bg-white flex flex-col items-center justify-center p-8 text-center animate-in fade-in duration-500">
  //       <div className="w-24 h-24 bg-emerald-100 rounded-full flex items-center justify-center mb-6 animate-bounce">
  //         <CheckCircle2 size={48} className="text-emerald-500" />
  //       </div>
  //       <h2 className="text-3xl font-black text-slate-900 uppercase tracking-tighter">Order Sent!</h2>
  //       <p className="text-slate-500 font-bold mt-4 max-w-xs">{randomMessage}</p>
  //       <div className="mt-10 p-6 bg-orange-50 rounded-[2rem] border border-orange-100 flex items-center gap-4">
  //         <Utensils className="text-orange-500" />
  //         <p className="text-xs font-black text-orange-700 uppercase tracking-tight">Wait for good food!</p>
  //       </div>
  //       <button
  //         onClick={() => { setOrderSuccess(false); setIsReviewModalOpen(false); setIsCheckingOut(false); }}
  //         className="mt-12 text-slate-400 font-black text-[10px] uppercase tracking-[0.2em] border-b-2 border-slate-100 pb-1"
  //       >
  //         Back to Menu
  //       </button>
  //       <button
  //         onClick={downloadBill}
  //         className="mt-6 px-6 py-3 bg-slate-900 text-white text-xs font-black uppercase tracking-widest rounded-xl"
  //       >
  //         Download Invoice
  //       </button>
  //     </div>
  //   );
  // }

  // if (orderSuccess) {
  //   return (
  //     <div className="fixed inset-0 z-[200] bg-white flex flex-col items-center justify-center p-8 text-center animate-in fade-in duration-500">
  //       <div className="w-24 h-24 bg-emerald-100 rounded-full flex items-center justify-center mb-6 animate-bounce">
  //         <CheckCircle2 size={48} className="text-emerald-500" />
  //       </div>

  //       <h2 className="text-3xl font-black text-slate-900 uppercase tracking-tighter">Order Sent!</h2>
  //       <p className="text-slate-500 font-bold mt-4 max-w-xs">{randomMessage}</p>

  //       <div className="mt-10 p-6 bg-orange-50 rounded-[2rem] border border-orange-100 flex items-center gap-4">
  //         <Utensils className="text-orange-500" />
  //         <p className="text-xs font-black text-orange-700 uppercase tracking-tight">Wait for good food!</p>
  //       </div>

  //       <button
  //         onClick={() => { setOrderSuccess(false); setIsReviewModalOpen(false); setIsCheckingOut(false); }}
  //         className="mt-12 text-slate-400 font-black text-[10px] uppercase tracking-[0.2em] border-b-2 border-slate-100 pb-1"
  //       >
  //         Back to Menu
  //       </button>

  //       <button
  //         onClick={downloadBill}
  //         disabled={isDownloading}
  //         className={`mt-6 px-8 py-4 rounded-2xl flex items-center gap-3 transition-all active:scale-95 ${
  //           isDownloading 
  //           ? "bg-slate-100 text-slate-400 cursor-not-allowed" 
  //           : "bg-slate-900 text-white shadow-xl hover:bg-slate-800"
  //         }`}
  //       >
  //         {isDownloading ? (
  //           <>
  //             <Loader2 className="animate-spin" size={18} />
  //             <span className="text-xs font-black uppercase tracking-widest">Generating PDF...</span>
  //           </>
  //         ) : (
  //           <>
  //             <ReceiptText size={18} />
  //             <span className="text-xs font-black uppercase tracking-widest">Download Invoice</span>
  //           </>
  //         )}
  //       </button>
  //     </div>
  //   );
  // }


  //   if (orderSuccess) {
  //   return (
  //     <div className="fixed inset-0 z-[200] bg-white flex flex-col items-center justify-center p-8 text-center animate-in fade-in duration-500">
  //       <div className="w-24 h-24 bg-emerald-100 rounded-full flex items-center justify-center mb-6 animate-bounce">
  //         <CheckCircle2 size={48} className="text-emerald-500" />
  //       </div>

  //       {/* Dynamic Cafe Branding */}
  //       <p className="text-[10px] font-black text-orange-500 uppercase tracking-[0.2em] mb-2">
  //         Thanks for ordering from
  //       </p>
  //       <h2 className="text-3xl font-black text-slate-900 uppercase tracking-tighter mb-4">
  //         {menu?.restaurant?.name || "Our Cafe"}
  //       </h2>

  //       <p className="text-slate-500 font-bold mb-8 max-w-xs">{randomMessage}</p>

  //       {/* 20 Minute Timer Card */}
  //       <div className="bg-slate-50 p-8 rounded-[3rem] border border-slate-100 w-full max-w-xs mb-8">
  //         <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Estimated Prep Time</p>
  //         <div className="text-5xl font-black text-slate-900 tracking-tighter mb-2">
  //           {formatTime(timeLeft)}
  //         </div>
  //         <div className="flex items-center justify-center gap-2">
  //           <div className="w-2 h-2 bg-orange-500 rounded-full animate-pulse" />
  //           <p className="text-[10px] font-bold text-orange-500 uppercase">Live Tracking</p>
  //         </div>
  //       </div>

  //       <div className="p-6 bg-orange-50 rounded-[2rem] border border-orange-100 flex items-center gap-4 mb-10">
  //         <Utensils className="text-orange-500" />
  //         <p className="text-xs font-black text-orange-700 uppercase tracking-tight">Wait for good food!</p>
  //       </div>

  //       <div className="flex flex-col gap-4 w-full max-w-xs">
  //         <button
  //           onClick={downloadBill}
  //           disabled={isDownloading}
  //           className={`w-full py-5 rounded-2xl flex items-center justify-center gap-3 transition-all active:scale-95 font-black uppercase text-xs tracking-widest ${
  //             isDownloading 
  //             ? "bg-slate-100 text-slate-400" 
  //             : "bg-slate-900 text-white shadow-xl"
  //           }`}
  //         >
  //           {isDownloading ? <Loader2 className="animate-spin" size={18} /> : <ReceiptText size={18} />}
  //           {isDownloading ? "Generating..." : "Download Invoice"}
  //         </button>

  //         <button
  //           onClick={() => { setOrderSuccess(false); setIsReviewModalOpen(false); setIsCheckingOut(false); }}
  //           className="text-slate-400 font-black text-[10px] uppercase tracking-[0.2em] py-2"
  //         >
  //           Back to Menu
  //         </button>
  //       </div>

  //       {/* ScanServe POS Branding Footer */}
  //       <div className="absolute bottom-10 flex flex-col items-center opacity-40">
  //         <p className="text-[9px] font-black text-slate-400 uppercase tracking-[0.3em] mb-2">Powered By</p>
  //         <div className="flex items-center gap-2">
  //           <div className="bg-[#FF5C00] p-1 rounded-md">
  //             <QrCode className="text-white" size={14} />
  //           </div>
  //           <span className="text-sm font-black tracking-tighter uppercase text-[#0F172A]">
  //             Scan<span className="text-[#FF5C00]">Serve</span> POS
  //           </span>
  //         </div>
  //       </div>
  //     </div>
  //   );
  // }


  if (orderSuccess) {
    return (
      <div className="fixed inset-0 z-[200] bg-white flex flex-col items-center p-8 text-center overflow-y-auto">
        {/* 1. Status Icon */}
        <div className="w-20 h-20 bg-emerald-100 rounded-full flex items-center justify-center mb-6 mt-10 shrink-0">
          <CheckCircle2 size={40} className="text-emerald-500" />
        </div>

        {/* 2. Branding & Message */}
        <p className="text-[10px] font-black text-orange-500 uppercase tracking-[0.2em] mb-2">
          Thanks for ordering from
        </p>
        <h2 className="text-3xl font-black text-slate-900 uppercase tracking-tighter mb-4">
          {menu?.restaurant?.name || "RASAMOMW"}
        </h2>
        <p className="text-slate-500 font-bold mb-8 max-w-xs">{randomMessage}</p>

        {/* 3. Live Timer Card */}
        <div className="bg-slate-50 p-8 rounded-[3rem] border border-slate-100 w-full max-w-xs mb-8 shrink-0">
          <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Estimated Prep Time</p>
          <div className="text-5xl font-black text-slate-900 tracking-tighter mb-2">
            {formatTime(timeLeft)}
          </div>
          <div className="flex items-center justify-center gap-2">
            <div className="w-2 h-2 bg-orange-500 rounded-full animate-pulse" />
            <p className="text-[10px] font-bold text-orange-500 uppercase">Live Tracking</p>
          </div>
        </div>

        {/* 4. Action Buttons */}
        <div className="flex flex-col gap-4 w-full max-w-xs mb-10 shrink-0">
          <button
            onClick={downloadBill}
            disabled={isDownloading}
            className="w-full bg-[#0F172A] text-white py-5 rounded-2xl flex items-center justify-center gap-3 font-black uppercase text-xs tracking-widest shadow-xl active:scale-95 transition-all"
          >
            {isDownloading ? <Loader2 className="animate-spin" size={18} /> : <ReceiptText size={18} />}
            {isDownloading ? "Generating..." : "Download Invoice"}
          </button>

          {/* ✅ FIXED: Now properly spaced and visible */}
          <button
            onClick={() => { setOrderSuccess(false); setIsReviewModalOpen(false); setIsCheckingOut(false); }}
            className="w-full py-4 text-slate-400 font-black text-[10px] uppercase tracking-[0.2em] border-b border-slate-100 active:text-orange-500 transition-colors"
          >
            Back to Menu
          </button>

          {/* <button
  onClick={() => { setOrderSuccess(false); setIsReviewModalOpen(false); setIsCheckingOut(false); }}
  className="w-full py-4 text-[#0F172A] font-black text-[12px] uppercase tracking-[0.2em] border-b border-slate-100 flex items-center justify-center gap-2 active:text-[#FF5C00] transition-all"
>
  <ChevronLeft size={16} /> Back to Menu
</button> */}
        </div>

        {/* 5. Powered By Footer (Static, Not Absolute) */}
        <div className="mt-auto pt-6 pb-4 flex flex-col items-center opacity-40 shrink-0">
          <p className="text-[9px] font-black text-slate-400 uppercase tracking-[0.3em] mb-2">Powered By</p>
          <div className="flex items-center gap-2">
            <div className="bg-[#FF5C00] p-1 rounded-md">
              <QrCode className="text-white" size={14} />
            </div>
            <span className="text-sm font-black tracking-tighter uppercase text-[#0F172A]">
              Scan<span className="text-[#FF5C00]">Serve</span> POS
            </span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans">
      <header className="sticky top-0 z-50 bg-white/90 backdrop-blur-md px-6 py-6 border-b border-slate-100">
        <div className="max-w-2xl mx-auto flex items-center justify-between">
          <div>
            <p className="text-[10px] font-black text-orange-500 uppercase tracking-widest mb-1">Ordering from</p>
            <h1 className="text-2xl font-black text-slate-900 leading-tight">{menu?.restaurant?.name}</h1>
          </div>
          <div className="relative p-3 bg-slate-900 rounded-2xl text-white shadow-xl">
            <ShoppingBag size={20} />
            {cartItemsArray.length > 0 && (
              <span className="absolute -top-1 -right-1 bg-orange-500 text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center border-2 border-white">
                {cartItemsArray.length}
              </span>
            )}
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto pb-32 px-6 mt-6">
        {/* <div className="relative mb-6">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
          <input
            type="text"
            placeholder="Search dishes..."
            className="w-full bg-slate-100/50 border-none rounded-2xl py-4 pl-12 pr-4 text-sm font-bold text-slate-700 outline-none focus:ring-2 focus:ring-orange-100 transition-all"
            onChange={(e) => setSearchQuery(e.target.value.toLowerCase())}
          />
        </div> */}

        <div className="relative mb-6">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
          <input
            type="text"
            value={searchQuery} // Add value control
            placeholder="Search across all categories..."
            className="w-full bg-slate-100/50 border-none rounded-2xl py-4 pl-12 pr-10 text-sm font-bold text-slate-700 outline-none focus:ring-2 focus:ring-orange-100 transition-all"
            onChange={(e) => setSearchQuery(e.target.value.toLowerCase())}
          />
          {searchQuery && (
            <X
              className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-300 cursor-pointer hover:text-slate-500"
              size={18}
              onClick={() => setSearchQuery("")}
            />
          )}
        </div>

        <div className="flex overflow-x-auto gap-3 py-4 no-scrollbar">
          {menu?.categories?.map((cat) => (
            <button
              key={cat._id}
              onClick={() => setActiveCategory(cat._id)}
              className={`px-6 py-3 rounded-full whitespace-nowrap text-sm font-black transition-all flex items-center gap-2 ${activeCategory === cat._id
                ? "bg-[#FF5C00] text-white shadow-lg shadow-orange-100"
                : "bg-white text-slate-400 border border-slate-100"
                }`}
            >
              {/* Icon appears here */}
              <span className={activeCategory === cat._id ? "text-white" : "text-orange-400"}>
                {getCategoryIcon(cat.name)}
              </span>
              {cat.name}
            </button>
          ))}
        </div>


        {/* <div className="mt-4 space-y-4">
          {menu?.items
            ?.filter((item) => item.category === activeCategory && item.name.toLowerCase().includes(searchQuery))
            .map((item) => {
              const isInCart = cart[item._id]?.quantity > 0;
              // Logic to check if this specific item has active suggestions to show
              const itemSuggestions = activeUpsellId === item._id ? currentSuggestions : [];

              return (
                <div key={item._id} className="space-y-3 mb-6">
                
                  <div className="bg-white px-6 py-8 border-b border-slate-50 rounded-[2rem] shadow-sm relative">
                    <div className="flex gap-4">
                      <div className="flex-1">
                        <div className="w-4 h-4 border-2 border-green-600 rounded-sm flex items-center justify-center mb-2">
                          <div className="w-1.5 h-1.5 rounded-full bg-green-600" />
                        </div>
                        <h3 className="text-xl font-black text-[#0F172A] uppercase leading-tight">{item.name}</h3>
                        <p className="text-xl font-black text-[#0F172A] tracking-tighter mt-1">₹{item.basePrice}</p>
                        <p className="text-[11px] text-slate-400 font-medium leading-relaxed mt-2 line-clamp-2">
                          {item.description || "Authentic ingredients prepared fresh for your table."}
                        </p>
                      </div>

                      <div className="w-32 flex flex-col items-center">
                        <div className="w-32 h-32 bg-slate-50 rounded-[2rem] overflow-hidden mb-[-20px] relative z-0 border border-slate-100">
                          {item.imageUrl ? <img src={item.imageUrl} className="w-full h-full object-cover" alt={item.name} /> : <ImageIcon className="w-full h-full p-8 text-slate-200" />}
                        </div>
                        <div className="z-10 w-full px-2">
                          {isInCart ? (
                            <div className="bg-[#FF5C00] text-white flex items-center justify-between rounded-xl shadow-lg h-10 overflow-hidden">
                              <button onClick={() => updateQuantity(item, -1)} className="px-3 hover:bg-orange-600 transition-all"><Minus size={14} strokeWidth={3} /></button>
                              <span className="font-black text-sm">{cart[item._id].quantity}</span>
                              <button onClick={() => updateQuantity(item, 1)} className="px-3 hover:bg-orange-600 transition-all"><Plus size={14} strokeWidth={3} /></button>
                            </div>
                          ) : (
                            <button onClick={() => updateQuantity(item, 1)} className="w-full bg-white border border-slate-100 text-[#FF5C00] py-2.5 rounded-xl font-black text-xs shadow-md active:scale-95 transition-all">ADD +</button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                 
                  {isInCart && itemSuggestions.length > 0 && (
                    <div className="mx-4 mt-[-10px] mb-8 animate-in fade-in slide-in-from-top-6 duration-700">
                      <div className="relative p-5 bg-gradient-to-br from-orange-50/90 via-white to-white rounded-[2.5rem] border border-orange-100 shadow-2xl shadow-orange-200/20 overflow-hidden group">

                        
                        <div className="absolute -right-6 -top-6 w-24 h-24 bg-orange-200/20 rounded-full blur-3xl group-hover:bg-orange-300/30 transition-colors duration-1000" />

                       
                        <div className="flex items-center gap-2.5 mb-5 px-1">
                          <div className="p-2 bg-orange-500 rounded-xl text-white shadow-lg shadow-orange-200">
                            <Sparkles size={12} strokeWidth={3} className="animate-pulse" />
                          </div>
                          <div>
                            <p className="text-[10px] font-black text-slate-800 uppercase tracking-[0.12em] leading-none">
                              Make it a perfect meal
                            </p>
                            <p className="text-[8px] font-bold text-orange-400 uppercase mt-1">
                              Handpicked for you
                            </p>
                          </div>
                        </div>

                       
                        <div className={`grid ${itemSuggestions.length === 1 ? 'grid-cols-1' : 'grid-cols-2'} gap-3 px-1`}>
                          {itemSuggestions.slice(0, 2).map((sug) => (
                            <div
                              key={sug._id}
                              className="bg-white p-3 rounded-[1.8rem] border border-slate-50 shadow-sm flex flex-col items-center hover:shadow-md hover:border-orange-200 transition-all duration-300 group/card relative"
                            >
                              
                              <div className="w-full h-20 bg-slate-50 rounded-2xl mb-3 overflow-hidden relative flex items-center justify-center">
                                {sug.imageUrl ? (
                                  <img
                                    src={sug.imageUrl}
                                    className="w-full h-full object-cover group-hover/card:scale-110 transition-transform duration-500"
                                    alt={sug.name}
                                  />
                                ) : (
                                  <Utensils size={24} className="text-orange-200" />
                                )}

                               
                                <div className="absolute bottom-1.5 right-1.5 bg-[#0F172A] px-2 py-0.5 rounded-lg shadow-md border border-white/10">
                                  <p className="text-[9px] font-black text-white">₹{sug.price}</p>
                                </div>
                              </div>

                              <h4 className="text-[10px] font-black uppercase text-slate-800 text-center line-clamp-1 mb-3 tracking-tight w-full">
                                {sug.name}
                              </h4>

                              <button
                                onClick={() => updateQuantity({ ...sug, _id: sug._id, basePrice: sug.price, isUpsell: true }, 1)}
                                className="w-full py-2.5 bg-white border-[1.5px] border-slate-900 text-slate-900 text-[9px] font-black uppercase rounded-2xl active:scale-95 hover:bg-slate-900 hover:text-white transition-all flex items-center justify-center gap-1.5 group/btn"
                              >
                                <Plus size={12} strokeWidth={4} />
                                Add
                              </button>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}


                </div>
              );
            })}
        </div> */}


        <div className="mt-4 space-y-4">
          {menu?.items
            ?.filter((item) => {
              const matchesSearch = item.name.toLowerCase().includes(searchQuery);

              // ✅ UNIVERSAL SEARCH LOGIC: 
              // If there is a search query, show all matching items regardless of category.
              // If search is empty, only show items for the active category.
              if (searchQuery.length > 0) return matchesSearch;
              return item.category === activeCategory;
            })
            .map((item) => {
              const isInCart = cart[item._id]?.quantity > 0;
              // Logic to check if this specific item has active suggestions to show
              const itemSuggestions = activeUpsellId === item._id ? currentSuggestions : [];

              return (
                <div key={item._id} className="space-y-3 mb-6 animate-in fade-in duration-300">
                  {/* MAIN ITEM CARD */}
                  <div className="bg-white px-6 py-8 border-b border-slate-50 rounded-[2rem] shadow-sm relative">
                    <div className="flex gap-4">
                      <div className="flex-1">
                        <div className="w-4 h-4 border-2 border-green-600 rounded-sm flex items-center justify-center mb-2">
                          <div className="w-1.5 h-1.5 rounded-full bg-green-600" />
                        </div>
                        <h3 className="text-xl font-black text-[#0F172A] uppercase leading-tight">{item.name}</h3>
                        <p className="text-xl font-black text-[#0F172A] tracking-tighter mt-1">₹{item.basePrice}</p>
                        <p className="text-[11px] text-slate-400 font-medium leading-relaxed mt-2 line-clamp-2">
                          {item.description || "Authentic ingredients prepared fresh for your table."}
                        </p>
                      </div>

                      <div className="w-32 flex flex-col items-center">
                        <div className="w-32 h-32 bg-slate-50 rounded-[2rem] overflow-hidden mb-[-20px] relative z-0 border border-slate-100">
                          {item.imageUrl ? (
                            <img src={item.imageUrl} className="w-full h-full object-cover" alt={item.name} />
                          ) : (
                            <ImageIcon className="w-full h-full p-8 text-slate-200" />
                          )}
                        </div>
                        <div className="z-10 w-full px-2">
                          {isInCart ? (
                            <div className="bg-[#FF5C00] text-white flex items-center justify-between rounded-xl shadow-lg h-10 overflow-hidden">
                              <button
                                onClick={() => updateQuantity(item, -1)}
                                className="px-3 hover:bg-orange-600 transition-all"
                              >
                                <Minus size={14} strokeWidth={3} />
                              </button>
                              <span className="font-black text-sm">{cart[item._id].quantity}</span>
                              <button
                                onClick={() => updateQuantity(item, 1)}
                                className="px-3 hover:bg-orange-600 transition-all"
                              >
                                <Plus size={14} strokeWidth={3} />
                              </button>
                            </div>
                          ) : (
                            <button
                              onClick={() => updateQuantity(item, 1)}
                              className="w-full bg-white border border-slate-100 text-[#FF5C00] py-2.5 rounded-xl font-black text-xs shadow-md active:scale-95 transition-all"
                            >
                              ADD +
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* PREMIUM MULTI-SUGGESTION AREA - TWO ITEMS PER FRAME */}
                  {isInCart && itemSuggestions.length > 0 && (
                    <div className="mx-4 mt-[-10px] mb-8 animate-in fade-in slide-in-from-top-6 duration-700">
                      <div className="relative p-5 bg-gradient-to-br from-orange-50/90 via-white to-white rounded-[2.5rem] border border-orange-100 shadow-2xl shadow-orange-200/20 overflow-hidden group">
                        {/* Background Decorative Element */}
                        <div className="absolute -right-6 -top-6 w-24 h-24 bg-orange-200/20 rounded-full blur-3xl group-hover:bg-orange-300/30 transition-colors duration-1000" />

                        {/* Header Section */}
                        <div className="flex items-center gap-2.5 mb-5 px-1">
                          <div className="p-2 bg-orange-500 rounded-xl text-white shadow-lg shadow-orange-200">
                            <Sparkles size={12} strokeWidth={3} className="animate-pulse" />
                          </div>
                          <div>
                            <p className="text-[10px] font-black text-slate-800 uppercase tracking-[0.12em] leading-none">
                              Make it a perfect meal
                            </p>
                            <p className="text-[8px] font-bold text-orange-400 uppercase mt-1">
                              Handpicked for you
                            </p>
                          </div>
                        </div>

                        {/* Grid Container - Forces 2 items per row */}
                        <div className={`grid ${itemSuggestions.length === 1 ? "grid-cols-1" : "grid-cols-2"} gap-3 px-1`}>
                          {itemSuggestions.slice(0, 2).map((sug) => (
                            <div
                              key={sug._id}
                              className="bg-white p-3 rounded-[1.8rem] border border-slate-50 shadow-sm flex flex-col items-center hover:shadow-md hover:border-orange-200 transition-all duration-300 group/card relative"
                            >
                              {/* Visual Item Container (Smaller for Grid) */}
                              <div className="w-full h-20 bg-slate-50 rounded-2xl mb-3 overflow-hidden relative flex items-center justify-center">
                                {sug.imageUrl ? (
                                  <img
                                    src={sug.imageUrl}
                                    className="w-full h-full object-cover group-hover/card:scale-110 transition-transform duration-500"
                                    alt={sug.name}
                                  />
                                ) : (
                                  <Utensils size={24} className="text-orange-200" />
                                )}

                                {/* Small Price Tag Overlay */}
                                <div className="absolute bottom-1.5 right-1.5 bg-[#0F172A] px-2 py-0.5 rounded-lg shadow-md border border-white/10">
                                  <p className="text-[9px] font-black text-white">₹{sug.price}</p>
                                </div>
                              </div>

                              <h4 className="text-[10px] font-black uppercase text-slate-800 text-center line-clamp-1 mb-3 tracking-tight w-full">
                                {sug.name}
                              </h4>

                              <button
                                onClick={() =>
                                  updateQuantity({ ...sug, _id: sug._id, basePrice: sug.price, isUpsell: true }, 1)
                                }
                                className="w-full py-2.5 bg-white border-[1.5px] border-slate-900 text-slate-900 text-[9px] font-black uppercase rounded-2xl active:scale-95 hover:bg-slate-900 hover:text-white transition-all flex items-center justify-center gap-1.5 group/btn"
                              >
                                <Plus size={12} strokeWidth={4} />
                                Add
                              </button>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}

          {/* ✅ EMPTY STATE: Show if no results match the search */}
          {searchQuery && menu?.items?.filter((i) => i.name.toLowerCase().includes(searchQuery)).length === 0 && (
            <div className="py-20 text-center animate-in fade-in duration-500">
              <Utensils className="mx-auto text-slate-200 mb-4" size={48} />
              <p className="text-slate-400 font-black uppercase text-[10px] tracking-[0.2em]">No dishes found matching "{searchQuery}"</p>
            </div>
          )}
        </div>
      </main>

      {/* Floating Cart Bar */}
      {cartItemsArray.length > 0 && (
        <div className="fixed bottom-8 left-6 right-6 z-50">
          <button onClick={() => setIsReviewModalOpen(true)} className="w-full max-w-2xl mx-auto bg-slate-900 text-white p-2 pl-6 rounded-[2rem] flex items-center justify-between shadow-2xl active:scale-95 transition-all">
            <div className="text-left">
              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Review Basket</p>
              <p className="text-lg font-black tracking-tighter">{cartItemsArray.length} Items • ₹{totalPrice}</p>
            </div>
            <div className="bg-orange-500 h-14 px-8 rounded-3xl flex items-center gap-2 shadow-lg">
              <span className="font-black text-sm uppercase">Order Now</span>
              <ArrowRight size={18} />
            </div>
          </button>
        </div>
      )}

      {isReviewModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-[#0F172A]/40 backdrop-blur-sm transition-opacity" onClick={() => { setIsReviewModalOpen(false); setIsCheckingOut(false); }} />
          <div className="relative bg-white w-full max-w-lg rounded-t-[3rem] p-8 max-h-[90vh] overflow-y-auto animate-in slide-in-from-bottom duration-500 shadow-2xl no-scrollbar">

            <div className="w-12 h-1.5 bg-slate-100 mx-auto rounded-full mb-8" />

            {!isCheckingOut ? (
              <>
                <div className="flex justify-between items-center mb-8">
                  <h2 className="text-2xl font-black text-[#0F172A] uppercase tracking-tighter">Your Basket</h2>
                  <X size={24} className="text-slate-300 cursor-pointer" onClick={() => setIsReviewModalOpen(false)} />
                </div>

                <div className="space-y-6 mb-10">
                  {cartItemsArray.map(i => (
                    <div key={i._id} className="flex justify-between items-center">
                      <div className="flex-1 pr-4">
                        <p className="font-black text-sm uppercase text-[#0F172A] line-clamp-1">{i.name}</p>
                        <p className="text-xs font-bold text-slate-400">₹{i.basePrice} x {i.quantity}</p>
                      </div>
                      <div className="flex items-center gap-4 bg-slate-50 border border-slate-100 px-4 py-2 rounded-2xl">
                        <button onClick={() => updateQuantity(i, -1)} className="text-slate-400 hover:text-orange-500 transition-all"><Minus size={14} strokeWidth={3} /></button>
                        <span className="font-black text-sm text-[#0F172A] w-4 text-center">{i.quantity}</span>
                        <button onClick={() => updateQuantity(i, 1)} className="text-slate-400 hover:text-orange-500 transition-all"><Plus size={14} strokeWidth={3} /></button>
                      </div>
                    </div>
                  ))}
                </div>

                {/* 🔥 INTEGRATED UPSELL INSIDE BASKET */}
                {currentSuggestions.length > 0 && (
                  <div className="mb-10 p-6 bg-orange-50/50 rounded-[2.5rem] border border-orange-100">
                    <p className="text-[10px] font-black text-orange-500 uppercase tracking-widest mb-4 flex items-center gap-2">
                      <Sparkles size={12} /> Pairs well with...
                    </p>
                    <div className="flex gap-4 overflow-x-auto no-scrollbar pb-2">
                      {currentSuggestions.map((item) => (
                        <div key={item._id} className="min-w-[140px] bg-white p-4 rounded-3xl shadow-sm flex flex-col items-center border border-slate-50 group transition-all">
                          <div className="w-full h-16 bg-slate-50 rounded-2xl mb-3 overflow-hidden flex items-center justify-center">
                            {item.imageUrl ? <img src={item.imageUrl} className="w-full h-full object-cover" /> : <ImageIcon className="text-slate-200" size={18} />}
                          </div>
                          <p className="text-[10px] font-black uppercase text-center line-clamp-1 mb-1">{item.name}</p>
                          <p className="text-xs font-black text-[#0F172A] mb-3">₹{item.price}</p>
                          <button
                            onClick={() => updateQuantity({ ...item, _id: item._id, basePrice: item.price, isUpsell: true }, 1)}
                            className="w-full py-2 bg-[#0F172A] text-white text-[9px] font-black uppercase rounded-xl active:scale-95 shadow-md"
                          >
                            Add +
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="pt-6 border-t border-slate-100 flex justify-between items-center">
                  <div>
                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Payable Total</p>
                    <p className="text-3xl font-black text-[#0F172A]">₹{totalPrice}</p>
                  </div>
                  <button onClick={() => setIsCheckingOut(true)} className="bg-[#FF5C00] text-white px-10 py-5 rounded-[2rem] font-black uppercase text-xs shadow-xl shadow-orange-200 active:scale-95 transition-all flex items-center gap-2">
                    Next <ArrowRight size={18} />
                  </button>
                </div>
              </>
            ) : (
              <div className="animate-in fade-in slide-in-from-right-4 duration-300">
                {/* ... Confirm details UI remains same ... */}
                <div className="flex justify-between items-center mb-8">
                  <h2 className="text-2xl font-black text-[#0F172A] uppercase tracking-tighter">Confirm Details</h2>
                  <button onClick={() => setIsCheckingOut(false)} className="text-[10px] font-black text-slate-400 uppercase tracking-widest hover:text-orange-500 transition-colors">Back</button>
                </div>

                <div className="space-y-6 mb-8">
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Customer Name</label>
                    <div className="relative">
                      <User className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                      <input
                        value={customerData.name}
                        onChange={(e) => setCustomerData({ ...customerData, name: e.target.value })}
                        placeholder="e.g. Gaurav Sharma"
                        className="w-full pl-14 pr-6 py-5 bg-slate-50 border-none rounded-[2rem] font-bold text-[#0F172A] focus:ring-2 focus:ring-orange-100 transition-all outline-none"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Mobile Number *</label>
                    <div className="relative">
                      <Phone className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
                      <input
                        type="tel"
                        value={customerData.phone}
                        onChange={(e) => setCustomerData({ ...customerData, phone: e.target.value })}
                        placeholder="+91 XXXXX XXXXX"
                        className="w-full pl-14 pr-6 py-5 bg-slate-50 border-none rounded-[2rem] font-bold text-[#0F172A] focus:ring-2 focus:ring-orange-100 transition-all outline-none"
                      />
                    </div>
                  </div>
                </div>

                <div
                  className="flex items-center gap-3 px-2 mb-8 group cursor-pointer"
                  onClick={() => setRememberMe(!rememberMe)}
                >
                  <div className={`w-6 h-6 rounded-lg border-2 flex items-center justify-center transition-all ${rememberMe ? "bg-orange-500 border-orange-500 shadow-lg shadow-orange-100" : "border-slate-200 bg-white"}`}>
                    {rememberMe && <CheckCircle2 size={14} className="text-white" />}
                  </div>
                  <div>
                    <p className="text-[11px] font-black text-slate-700 uppercase tracking-tight leading-none">Save my details</p>
                    <p className="text-[9px] font-bold text-slate-400 uppercase mt-1">For a faster checkout next time</p>
                  </div>
                </div>

                <div className="bg-emerald-50 p-6 rounded-[2rem] border border-emerald-100 mb-10 flex items-center gap-4">
                  <div className="bg-emerald-500 p-2 rounded-xl text-white shadow-lg"><CheckCircle2 size={24} /></div>
                  <div>
                    <p className="text-xs font-black text-emerald-900 uppercase tracking-widest leading-none">Almost There</p>
                    <p className="text-[9px] font-bold text-emerald-700 mt-1">Kitchen will start once you confirm.</p>
                  </div>
                </div>

                <button
                  onClick={finalOrderPlacement}
                  disabled={orderProcessing}
                  className="w-full bg-[#0F172A] text-white py-6 rounded-[2.5rem] font-black uppercase tracking-widest text-xs shadow-xl disabled:opacity-50 transition-all active:scale-95"
                >
                  {orderProcessing ? "Sending Order..." : "Confirm & Place Order"}
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function MenuSkeleton() {
  return (
    <div className="min-h-screen bg-white p-6 animate-pulse">
      <div className="h-20 bg-slate-100 rounded-3xl mb-8" />
      <div className="space-y-4">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="h-40 bg-slate-50 rounded-[2.5rem]" />
        ))}
      </div>
    </div>
  );
}