

"use client";
import { useEffect, useState } from "react";
import Script from "next/script";
import {
  ShieldCheck,
  Clock,
  CreditCard,
  Plus,
  Minus,
  Sparkles,
  Store,
  Truck,
  ArrowRight,
  X,
  AlertCircle
} from "lucide-react";
import apiConfig from "../../../utils/apiConfig";

import { useAuth } from "../../context/AuthContext";

// --- Simple Toast Component ---
const Toast = ({ message, type, onClose }) => (
  <div className={`fixed bottom-5 right-5 z-[100] flex items-center gap-3 px-6 py-4 rounded-2xl shadow-2xl border animate-in slide-in-from-right ${type === 'error' ? 'bg-red-50 border-red-200 text-red-800' : 'bg-slate-900 border-slate-800 text-white'
    }`}>
    <span className="text-xs font-black uppercase tracking-widest">{message}</span>
    <button onClick={onClose} className="p-1 hover:opacity-70"><X size={14} /></button>
  </div>
);

export default function ManagePlan() {
  const [info, setInfo] = useState({
    plan: "ACTIVE",
    isTrialActive: true,
    branchLimits: {
      restaurant: 1,
      foodTruck: 0
    }
  });

  const [loading, setLoading] = useState(false);
  const [restaurantCount, setRestaurantCount] = useState(1);
  const [foodTruckCount, setFoodTruckCount] = useState(0);

  // Modal & Toast States
  const [showTrialModal, setShowTrialModal] = useState(false);
  const [toast, setToast] = useState(null);

  const { user, loading2 } = useAuth();


  const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;

  const RESTAURANT_UNIT_PRICE = 3999;
  const FOOD_TRUCK_UNIT_PRICE = 1999;
  const currentTotal = (restaurantCount * RESTAURANT_UNIT_PRICE) + (foodTruckCount * FOOD_TRUCK_UNIT_PRICE);

  const ApiLink = 'https://restaurant-model-backend.onrender.com'

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 4000);
  };



  const fetchSubscriptionInfo = async () => {
    try {
      setLoading(true)
      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/subscription/info`,
        {
          credentials: "include",   // 🔥 REQUIRED
          cache: "no-store",
        }
      );

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || "Failed to load subscription");
      }

      setInfo(data);
      setRestaurantCount(data.branchLimits?.restaurant ?? 0);
      setFoodTruckCount(data.branchLimits?.foodTruck ?? 0);

    } catch (err) {
      showToast(err.message || "Failed to sync subscription data", "error");
    }
    finally {
      setLoading(false)
    }
  };

  useEffect(() => {
    fetchSubscriptionInfo();
  }, []);







  // const handleConfirm = async () => {


  //   console.log(user.plan, "user.plan")



  //   if (!info?.branchLimits) {
  //     showToast("Subscription data not loaded", "error");
  //     return;
  //   }

  //   if (!user) {
  //     showToast("User session missing", "error");
  //     return;
  //   }



  //   const trialExpired =
  //     user.subscriptionStatus === "EXPIRED" &&
  //     user.plan === "TRIAL";

  //   const subscriptionActive =
  //     user.subscriptionStatus === "ACTIVE";

  //   /*
  //   |--------------------------------------------------------------------------
  //   | CASE 1 → TRIAL EXPIRED → ACTIVATE SUBSCRIPTION
  //   |--------------------------------------------------------------------------
  //   */
  //   if (trialExpired) {
  //     console.log("trialExpired")
  //     await processSubscriptionActivation();
  //     return;
  //   }

  //   /*
  //   |--------------------------------------------------------------------------
  //   | CASE 2 → SUBSCRIPTION ACTIVE → CHECK UPGRADE
  //   |--------------------------------------------------------------------------
  //   */
  //   if (subscriptionActive) {
  //     console.log("subscriptionActive:", subscriptionActive)
  //     const isRestaurantIncreased =
  //       restaurantCount > info.branchLimits.restaurant;

  //     const isFoodTruckIncreased =
  //       foodTruckCount > info.branchLimits.foodTruck;

  //     if (!isRestaurantIncreased && !isFoodTruckIncreased) {
  //       showToast("No changes detected", "error");
  //       console.log("outside");
  //       console.log(user?.plan, "user?.plan/////////////")
  //       if (user?.plan == "TRIAL") {
  //         console.log("inside")
  //         setShowTrialModal(true);
  //         return
  //       }
  //       console.log("outside222");

  //       return;
  //     }

  //     setLoading(true);

  //     try {
  //       console.log(isRestaurantIncreased, isFoodTruckIncreased)
  //       if (isRestaurantIncreased) {
  //         await processUpgrade("RESTAURANT", restaurantCount);
  //       }

  //       if (isFoodTruckIncreased) {
  //         await processUpgrade("FOOD_TRUCK", foodTruckCount);
  //       }

  //     } catch (err) {
  //       showToast("Expansion action failed", "error");
  //     } finally {
  //       setLoading(false);
  //     }

  //     return;
  //   }

  //   /*
  //   |--------------------------------------------------------------------------
  //   | CASE 3 → TRIAL ACTIVE (FREE MODE)
  //   |--------------------------------------------------------------------------
  //   */

  //   const isRestaurantIncreased =
  //     restaurantCount > info.branchLimits.restaurant;

  //   const isFoodTruckIncreased =
  //     foodTruckCount > info.branchLimits.foodTruck;

  //   if (!isRestaurantIncreased && !isFoodTruckIncreased) {
  //     showToast("No changes detected", "error");
  //     return;
  //   }
  //   console.log(isRestaurantIncreased, "isRestaurantIncreased")
  //   if (isRestaurantIncreased) {
  //     await processUpgrade("RESTAURANT", restaurantCount);
  //   }
  //   console.log("isFoodTruckIncreased:", isFoodTruckIncreased)
  //   if (isFoodTruckIncreased) {
  //     await processUpgrade("FOOD_TRUCK", foodTruckCount);
  //   }
  // };

const handleConfirm = async () => {

  if (!info?.branchLimits) {
    showToast("Subscription data not loaded", "error");
    return;
  }

  if (!user) {
    showToast("User session missing", "error");
    return;
  }

  const isRestaurantIncreased =
    restaurantCount > info.branchLimits.restaurant;

  const isFoodTruckIncreased =
    foodTruckCount > info.branchLimits.foodTruck;

  const trialActive =
    user.subscriptionStatus === "TRIAL_ACTIVE";

  const trialExpired =
    user.subscriptionStatus === "EXPIRED" &&
    user.plan === "TRIAL";

  const subscriptionActive =
    user.subscriptionStatus === "ACTIVE";

  /*
  |--------------------------------------------------
  | TRIAL ACTIVE + NO CHANGE → SHOW MODAL
  |--------------------------------------------------
  */
  if (trialActive && !isRestaurantIncreased && !isFoodTruckIncreased) {
    setShowTrialModal(true);
    return;
  }

  /*
  |--------------------------------------------------
  | TRIAL EXPIRED → ACTIVATE SUBSCRIPTION
  |--------------------------------------------------
  */
  if (trialExpired) {
    await processSubscriptionActivation();
    return;
  }

  /*
  |--------------------------------------------------
  | SUBSCRIPTION ACTIVE → CHECK UPGRADE
  |--------------------------------------------------
  */
  if (subscriptionActive) {

    if (!isRestaurantIncreased && !isFoodTruckIncreased) {
      showToast("No changes detected", "error");
      return;
    }

    setLoading(true);

    try {

      if (isRestaurantIncreased) {
        await processUpgrade("RESTAURANT", restaurantCount);
      }

      if (isFoodTruckIncreased) {
        await processUpgrade("FOOD_TRUCK", foodTruckCount);
      }

    } catch (err) {
      showToast("Expansion action failed", "error");
    } finally {
      setLoading(false);
    }

    return;
  }

  /*
  |--------------------------------------------------
  | TRIAL ACTIVE + BRANCH INCREASE
  |--------------------------------------------------
  */

  if (isRestaurantIncreased) {
    await processUpgrade("RESTAURANT", restaurantCount);
  }

  if (isFoodTruckIncreased) {
    await processUpgrade("FOOD_TRUCK", foodTruckCount);
  }
};
  const processSubscriptionActivation = async () => {

    try {

      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/payment/activate-subscription`,
        {
          method: "POST",
          credentials: "include",
        }
      );

      const data = await res.json();

      if (!res.ok) {
        showToast(data.message || "Activation failed", "error");
        return;
      }

      const options = {
        key: data.key,
        amount: data.amount,
        currency: "INR",
        order_id: data.orderId,
        name: "QrServe",
        description: "Subscription Activation",

        handler: async function (response) {
          await verifySubscriptionPayment(response);
        },
      };

      const razorpay = new window.Razorpay(options);
      razorpay.open();

    } catch (err) {
      showToast("Activation failed", "error");
    }
  };




  const verifySubscriptionPayment = async (response) => {

    const res = await fetch(
      `${apiConfig?.BASE_URL}/api/payment/verify-subscription`,
      {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          razorpay_order_id: response.razorpay_order_id,
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_signature: response.razorpay_signature,
        }),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      showToast(data.message || "Verification failed", "error");
      return;
    }

    showToast("Subscription activated successfully 🎉");

    fetchSubscriptionInfo();
  };


  const processUpgrade = async (type, count) => {

    const res = await fetch(
      `${apiConfig?.BASE_URL}/api/payment/increase-branches`,
      {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type, newLimit: count }),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      showToast(data.message || "Upgrade failed", "error");
      return;
    }

    /*
    | Trial flow
    */
    if (data.trial === true) {

      showToast(`${type} updated during trial`);

      setInfo(prev => ({
        ...prev,
        branchLimits: data.branchLimits
      }));

      return;
    }

    /*
    | Paid flow → open Razorpay
    */
    const options = {
      key: data.key,
      amount: data.amount,
      currency: "INR",
      order_id: data.orderId,
      name: "QrServe",
      description: `${type} Branch Upgrade`,

      handler: async function (response) {
        await verifyUpgradePayment(response, type, count);
      },
    };

    const razorpay = new window.Razorpay(options);
    razorpay.open();
  };
  const verifyUpgradePayment = async (response, type, newLimit) => {

    const res = await fetch(
      `${apiConfig?.BASE_URL}/api/payment/verify-upgrade`,
      {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          razorpay_order_id: response.razorpay_order_id,
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_signature: response.razorpay_signature,
          type,
          newLimit,
        }),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      showToast(data.message || "Verification failed", "error");
      return;
    }

    showToast("Branches upgraded successfully 🎉");

    fetchSubscriptionInfo();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAFC] p-4 md:p-8 font-sans flex flex-col relative">
      <Script src="https://checkout.razorpay.com/v1/checkout.js" strategy="lazyOnload" />

      {/* TOAST NOTIFICATION */}
      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}

      {/* TRIAL PHASE MODAL */}
      {showTrialModal && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="bg-white rounded-[2rem] p-8 max-w-md w-full shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
            <div className="w-16 h-16 bg-orange-100 rounded-2xl flex items-center justify-center mb-6">
              <AlertCircle className="text-orange-500" size={32} />
            </div>
            <h3 className="text-2xl font-black text-slate-900 uppercase italic leading-tight mb-4">
              Trial Policy <span className="text-orange-500">Notice</span>
            </h3>
            <p className="text-slate-500 font-bold text-sm leading-relaxed mb-6 uppercase tracking-tight">
              Payment cannot be made during the trial phase. Official payments are only available after your trial period is completed.
            </p>
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-100 mb-8">
              <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Requirement</p>
              <p className="text-xs font-bold text-slate-700 uppercase">To expand during trial, you must select a number higher than your current branch count.</p>
            </div>
            <button
              onClick={() => setShowTrialModal(false)}
              className="w-full bg-slate-900 text-white py-4 rounded-xl font-black uppercase tracking-widest text-xs hover:bg-slate-800 transition-all"
            >
              Understand & Continue
            </button>
          </div>
        </div>
      )}

      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8 shrink-0">
        <div>
          <span className="bg-orange-500 text-white text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-widest">
            Subscription Manager
          </span>
          <h1 className="text-3xl font-black text-slate-900 tracking-tight">
            Manage Your <span className="text-orange-500">Outlets</span>
          </h1>
        </div>

        <div className="bg-white border border-slate-200 px-6 py-2 rounded-full shadow-sm flex items-center gap-4 w-fit">
          <div className={`w-8 h-8 rounded-full flex items-center justify-center ${info.isTrialActive ? 'bg-orange-100 text-orange-600' : 'bg-emerald-100 text-emerald-600'}`}>
            {info.isTrialActive ? <Clock size={16} /> : <ShieldCheck size={16} />}
          </div>
          <div>
            <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest leading-none">Status</p>
            <p className="text-sm font-black text-slate-900 uppercase leading-none">{info.isTrialActive ? 'Trial Period' : 'Subscription Active'}</p>
          </div>
        </div>
      </div>

      <div className="flex flex-col lg:flex-row gap-6 max-w-6xl mx-auto w-full pb-10">
        {/* BRANCH SELECTION PANEL */}
        <div className="flex-1 bg-white rounded-[2.5rem] border border-slate-200 shadow-xl p-6 md:p-8 flex flex-col relative">
          <div className="mb-8 flex justify-between items-end">
            <div>
              <h2 className="text-xl font-black text-slate-900 uppercase tracking-tight italic">Select Branches</h2>
              <p className="text-slate-400 text-xs font-bold uppercase tracking-wider">Add or remove your business locations</p>
            </div>
            <div className="text-right">
              <p className="text-[10px] font-black text-orange-500 uppercase tracking-widest">Current Limits</p>
              <p className="text-xs font-black text-slate-400 uppercase">{info.branchLimits?.restaurant} Res | {info.branchLimits?.foodTruck} Trk</p>
            </div>
          </div>

          <div className="space-y-4 md:space-y-6">
            {/* RESTAURANT CARD */}
            <div className="flex flex-wrap justify-between items-center bg-slate-50 p-4 md:p-6 rounded-2xl border border-slate-100 gap-4">
              <div className="flex items-center gap-4">
                <div className="bg-white p-3 rounded-xl shadow-sm border border-slate-100">
                  <Store className="text-orange-500" />
                </div>
                <div>
                  <h3 className="font-black text-slate-800 uppercase text-sm italic">Restaurant / Cafe</h3>
                  <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">₹3,999 / Monthly</p>
                </div>
              </div>

              <div className="flex items-center gap-4 bg-slate-900 text-white p-2 rounded-xl shadow-inner ml-auto">
                <button
                  onClick={() => setRestaurantCount(Math.max(0, restaurantCount - 1))}
                  className="p-1 hover:text-orange-500 transition-colors"
                >
                  <Minus size={20} />
                </button>
                <span className="w-8 text-center text-lg font-black">{restaurantCount}</span>
                <button
                  onClick={() => setRestaurantCount(restaurantCount + 1)}
                  className="p-1 hover:text-orange-500 transition-colors"
                >
                  <Plus size={20} />
                </button>
              </div>
            </div>

            {/* FOOD TRUCK CARD */}
            <div className="flex flex-wrap justify-between items-center bg-slate-50 p-4 md:p-6 rounded-2xl border border-slate-100 gap-4">
              <div className="flex items-center gap-4">
                <div className="bg-white p-3 rounded-xl shadow-sm border border-slate-100">
                  <Truck className="text-blue-500" />
                </div>
                <div>
                  <h3 className="font-black text-slate-800 uppercase text-sm italic">Food Truck</h3>
                  <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">₹1,999 / Monthly</p>
                </div>
              </div>

              <div className="flex items-center gap-4 bg-slate-900 text-white p-2 rounded-xl shadow-inner ml-auto">
                <button
                  onClick={() => setFoodTruckCount(Math.max(0, foodTruckCount - 1))}
                  className="p-1 hover:text-orange-500 transition-colors"
                >
                  <Minus size={20} />
                </button>
                <span className="w-8 text-center text-lg font-black">{foodTruckCount}</span>
                <button
                  onClick={() => setFoodTruckCount(foodTruckCount + 1)}
                  className="p-1 hover:text-orange-500 transition-colors"
                >
                  <Plus size={20} />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* SUMMARY PANEL */}
        <div className="lg:w-96 flex flex-col gap-6">
          <div className="bg-slate-900 rounded-[2.5rem] p-8 text-white shadow-2xl flex flex-col relative overflow-hidden">
            <div className="absolute -top-24 -right-24 w-48 h-48 bg-orange-500 rounded-full blur-[80px] opacity-20"></div>

            <div className="relative z-10 flex flex-col">
              <h2 className="text-[10px] font-black text-orange-400 uppercase tracking-[0.3em] mb-4">Final Billing Summary</h2>

              <div className="space-y-4 mb-6 border-b border-slate-800 pb-6">
                <div className="flex justify-between items-center text-xs">
                  <span className="text-slate-400 font-bold uppercase tracking-tight">
                    {restaurantCount} × Restaurant
                  </span>
                  <span className="font-black text-slate-200">
                    ₹{(restaurantCount * 3999).toLocaleString()}
                  </span>
                </div>

                <div className="flex justify-between items-center text-xs">
                  <span className="text-slate-400 font-bold uppercase tracking-tight">
                    {foodTruckCount} × Food Truck
                  </span>
                  <span className="font-black text-slate-200">
                    ₹{(foodTruckCount * 1999).toLocaleString()}
                  </span>
                </div>
              </div>

              <div className="mb-8">
                <p className="text-[10px] text-slate-500 font-black uppercase tracking-widest mb-1">Total Monthly Bill</p>
                <div className="flex items-baseline gap-1">
                  <span className="text-5xl font-black tracking-tighter text-white">
                    ₹{currentTotal.toLocaleString()}
                  </span>
                  <span className="text-slate-500 text-[10px] font-black uppercase">/ month</span>
                </div>
              </div>

              <button
                onClick={handleConfirm}
                disabled={loading}
                className="w-full bg-orange-500 hover:bg-orange-600 disabled:bg-slate-800 disabled:text-slate-600 text-white py-5 rounded-2xl font-black uppercase tracking-widest text-[11px] flex items-center justify-center gap-3 transition-all transform active:scale-95 shadow-xl shadow-orange-900/20"
              >
                {loading ? "Verifying..." : (
                  <>
                    <CreditCard size={18} />
                    Confirm Expansion
                    <ArrowRight size={16} />
                  </>
                )}
              </button>

              <p className="text-center mt-6 text-[8px] text-slate-500 font-bold uppercase tracking-widest">
                Payment secured via Razorpay
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
