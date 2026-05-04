

// "use client";
// import { useEffect, useState, useMemo } from "react";
// import { X, Plus, Minus, ArrowLeft, UtensilsCrossed } from "lucide-react";
// import { placeOrder } from "@/utils/api";
// import { useAuth } from "../context/AuthContext";

// export default function MenuModal({ table, close }) {
//   console.log("MenuModal opened for table:", table); // Debug log
//   const [categories, setCategories] = useState([]);
//   const [allItems, setAllItems] = useState([])  ;
//   const [selectedCategory, setSelectedCategory] = useState("All");
//   const [loading, setLoading] = useState(true);
//   const [cart, setCart] = useState({});
//   const [businessType, setBusinessType] = useState(null);
//   const [restaurantId, setRestaurantId] = useState(null);
//   const { user, loading2 } = useAuth();

//   // 🔴 FOOD TRUCK STATES
//   const [customerName, setCustomerName] = useState("");
//   const [customerPhone, setCustomerPhone] = useState("");
//   const [paymentMode, setPaymentMode] = useState(null);

//   // useEffect(() => {
//   //   if (typeof window !== "undefined") {
//   //     setBusinessType(localStorage.getItem("businessType"));
//   //     setRestaurantId(localStorage.getItem("restaurantId"));
//   //   }
//   // }, []);

//   useEffect(() => {
//     if (!user) return;

//     setRestaurantId(user.restaurantId);

//     const activeRestaurant = user.restaurants?.find(
//       r => r._id === user.restaurantId
//     );

//     if (activeRestaurant?.businessType) {
//       setBusinessType(activeRestaurant.businessType);
//     }
//   }, [user]);

//   const isRestaurant = businessType === "RESTAURANT";
//   const isFoodTruck = businessType === "FOOD_TRUCK";

//   useEffect(() => {
//     console.log("Restaurant ID for menu fetch:", restaurantId); // Debug log
//     if (restaurantId) fetchMenu();
//   }, [restaurantId]);

//   const fetchMenu = async () => {
//     console.log('fetchMenu request send');

//     try {
//       setLoading(true);
//       const res = await fetch(`http://localhost:5000/api/public/menu/${restaurantId}`);
//       const data = await res.json();
//       setCategories(data.categories || []);
//       setAllItems(data.items || []);
//     } catch (err) {
//       console.error("Menu fetch failed", err);
//     } finally {
//       setTimeout(() => setLoading(false), 600);
//     }
//   };

//   const updateQuantity = (item, delta) => {
//     setCart((prev) => {
//       const currentQty = prev[item._id]?.quantity || 0;
//       const nextQty = Math.max(0, currentQty + delta);
//       const newCart = { ...prev };
//       if (nextQty === 0) delete newCart[item._id];
//       else newCart[item._id] = { ...item, quantity: nextQty, isUpsell: false };
//       return newCart;
//     });
//   };

//   const cartItemsArray = useMemo(() => Object.values(cart), [cart]);
//   const totalPrice = useMemo(() => cartItemsArray.reduce((sum, item) => sum + item.basePrice * item.quantity, 0), [cartItemsArray]);

//   const filteredItems = selectedCategory === "All"
//     ? allItems
//     : allItems.filter((item) => item.category === selectedCategory);

//   console.log("Cart State:", filteredItems);
//   useEffect(() => {
//     console.log("Selected Category:", selectedCategory);

//   }, [selectedCategory]);

//   const handleSendOrder = async () => {
//     if (!cartItemsArray.length) return alert("Cart is empty");

//     if (isFoodTruck) {
//       if (!customerName || !customerPhone) return alert("Customer name and phone required");
//       if (!paymentMode) return alert("Select payment status");
//     }

//     const payload = {
//       items: cartItemsArray.map((i) => ({ itemId: i._id, quantity: i.quantity, isUpsell: false })),
//     };

//     if (isRestaurant || isFoodTruck) payload.placedBy = "STAFF";
//     if (isRestaurant) {
//       payload.tableNumber = table?.tableName;
//       payload.customerPhone = "NA";
//       payload.paymentMode = "POSTPAID";
//     }
//     if (isFoodTruck) {
//       payload.customerName = customerName;
//       payload.customerPhone = customerPhone;
//       payload.paymentMode = paymentMode;
//     }

//     try {

//       await placeOrder(payload);
//       setCart({});
//       setCustomerName("");
//       setCustomerPhone("");
//       setPaymentMode(null);
//       alert("Order placed successfully");
//       close();
//     } catch (err) { alert(err.message || "Order failed"); }
//   };

//   return (
//     // Backdrop for desktop
//     <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[200] flex items-center justify-center p-0 md:p-6">

//       {/* MAIN POPUP CONTAINER */}
//       <div className="bg-white w-full h-full md:h-[90vh] md:max-w-4xl md:rounded-[3rem] flex flex-col overflow-hidden shadow-2xl relative">

//         {/* 1. HEADER */}
//         <div className="shrink-0 bg-white p-4 md:p-6 border-b">
//           <div className="flex items-center justify-between mb-4">
//             <div className="flex items-center gap-3">
//               <button onClick={close} className="p-2 bg-slate-100 rounded-full hover:bg-slate-200"><ArrowLeft size={20} /></button>
//               <h2 className="text-xl font-black text-slate-900 uppercase tracking-tight">
//                 {isRestaurant ? `TABLE ${table?.tableName}` : "QUICK ORDER"}
//               </h2>
//             </div>
//             <button onClick={close} className="p-2 text-slate-400 hover:text-red-500"><X size={28} /></button>
//           </div>

//           {/* Categories Scroll */}
//           <div className="flex gap-2 overflow-x-auto no-scrollbar pb-2">
//             {["All", ...categories].map((cat, idx) => (
//               <button
//                 key={`cat-pill-${idx}`}
//                 onClick={() => setSelectedCategory(cat)}
//                 className={`px-6 py-2 rounded-full text-[10px] font-black uppercase transition-all whitespace-nowrap ${selectedCategory === cat ? "bg-slate-900 text-white shadow-lg" : "bg-slate-100 text-slate-500"
//                   }`}
//               >
//                 {typeof cat === 'object' ? cat.name : cat}
//               </button>
//             ))}
//           </div>
//         </div>

//         {/* 2. FOOD TRUCK INPUTS (Pinned top of scroll) */}
//         {isFoodTruck && (
//           <div className="shrink-0 px-6 py-4 space-y-3 border-b bg-slate-50/50">
//             <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
//               <input
//                 placeholder="Customer Name"
//                 value={customerName}
//                 onChange={(e) => setCustomerName(e.target.value)}
//                 className="w-full border p-3 rounded-2xl text-sm font-bold bg-white"
//               />
//               <input
//                 placeholder="Customer Phone"
//                 value={customerPhone}
//                 onChange={(e) => setCustomerPhone(e.target.value)}
//                 className="w-full border p-3 rounded-2xl text-sm font-bold bg-white"
//               />
//             </div>
//             <div className="flex gap-2">
//               <button
//                 onClick={() => setPaymentMode("PREPAID")}
//                 className={`flex-1 py-3 rounded-2xl text-xs font-black uppercase transition-all ${paymentMode === "PREPAID" ? "bg-green-600 text-white" : "bg-white text-slate-400 border"
//                   }`}
//               >
//                 Paid
//               </button>
//               <button
//                 onClick={() => setPaymentMode("POSTPAID")}
//                 className={`flex-1 py-3 rounded-2xl text-xs font-black uppercase transition-all ${paymentMode === "POSTPAID" ? "bg-orange-600 text-white" : "bg-white text-slate-400 border"
//                   }`}
//               >
//                 Pay Later
//               </button>
//             </div>
//           </div>
//         )}

//         {/* 3. SCROLLABLE MENU AREA */}
//         <div className="flex-1 overflow-y-auto bg-slate-50 p-4 md:p-8 pb-48 custom-scrollbar">
//           {loading ? (
//             <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
//               {[1, 2, 3, 4].map(i => <div key={`skel-${i}`} className="h-28 bg-white rounded-3xl animate-pulse" />)}
//             </div>
//           ) : (
//             <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
//               {filteredItems.map((item) => {
//                 const qty = cart[item._id]?.quantity || 0;
//                 return (
//                   <div key={item._id} className={`p-5 rounded-[2.5rem] border-2 transition-all flex items-center justify-between ${qty > 0 ? "border-orange-500 bg-white shadow-xl scale-[1.02]" : "border-white bg-white shadow-sm hover:shadow-md"}`}>
//                     <div className="flex items-center gap-4">
//                       <div className={`p-4 rounded-3xl ${qty > 0 ? "bg-orange-100 text-orange-500" : "bg-slate-50 text-slate-300"}`}><UtensilsCrossed size={24} /></div>
//                       <div>
//                         <h4 className="font-black text-slate-900 text-xs uppercase mb-1">{item.name}</h4>
//                         <p className="text-2xl font-black text-slate-900 leading-none">₹{item.basePrice}</p>
//                       </div>
//                     </div>
//                     <div className="flex items-center gap-3">
//                       {qty > 0 ? (
//                         <div className="flex items-center bg-slate-900 rounded-3xl p-1.5 gap-4">
//                           <button onClick={() => updateQuantity(item, -1)} className="p-2 text-white hover:text-orange-400"><Minus size={18} /></button>
//                           <span className="text-white font-black text-lg px-1">{qty}</span>
//                           <button onClick={() => updateQuantity(item, 1)} className="p-2 text-white hover:text-orange-400"><Plus size={18} /></button>
//                         </div>
//                       ) : (
//                         <button onClick={() => updateQuantity(item, 1)} className="px-8 py-4 bg-slate-100 text-slate-600 rounded-3xl font-black text-[11px] uppercase hover:bg-orange-500 hover:text-white transition-all shadow-sm">Add +</button>
//                       )}
//                     </div>
//                   </div>
//                 );
//               })}
//             </div>
//           )}
//         </div>

//         {/* 4. FIXED BOTTOM SUMMARY (Desktop Friendly) */}
//         {cartItemsArray.length > 0 && (
//           <div className="absolute bottom-0 left-0 right-0 bg-white rounded-t-[3.5rem] shadow-[0_-25px_60px_rgba(0,0,0,0.12)] p-6 md:p-8 z-[210] border-t border-slate-50 animate-in slide-in-from-bottom duration-500">
//             <div className="max-w-3xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">

//               {/* Order List preview for Desktop (horizontal scroll on wide screens) */}
//               <div className="hidden md:flex flex-1 gap-4 overflow-x-auto no-scrollbar max-w-lg">
//                 {cartItemsArray.map((item) => (
//                   <div key={`sum-${item._id}`} className="bg-slate-50 px-4 py-2 rounded-2xl whitespace-nowrap shrink-0">
//                     <p className="text-[10px] font-black text-slate-900 uppercase">{item.quantity} x {item.name}</p>
//                   </div>
//                 ))}
//               </div>

//               {/* Totals & Action */}
//               <div className="flex items-center justify-between w-full md:w-auto gap-8">
//                 <div>
//                   <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] mb-1">Grand Total</p>
//                   <p className="text-4xl font-black text-slate-900 tracking-tighter">₹{totalPrice}</p>
//                 </div>
//                 <button
//                   onClick={handleSendOrder}
//                   className="bg-orange-500 text-white px-12 py-6 rounded-[2rem] font-black text-sm uppercase tracking-widest shadow-2xl shadow-orange-200 hover:bg-orange-600 active:scale-95 transition-all"
//                 >
//                   Place Order
//                 </button>
//               </div>
//             </div>
//           </div>
//         )}
//       </div>
//     </div>
//   );
// }

"use client";
import { useEffect, useState, useMemo, use } from "react";
import { X, Plus, Minus, ArrowLeft, UtensilsCrossed, Loader2 } from "lucide-react";
import { placeOrder } from "@/utils/api";
import { useAuth } from "../context/AuthContext";
import toast, { Toaster } from "react-hot-toast";
import apiConfig from "@/utils/apiConfig";

export default function MenuModal({ table, close, sendAppendOrder }) {
  const [categories, setCategories] = useState([]);


  const [allItems, setAllItems] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [loading, setLoading] = useState(true);
  const [cart, setCart] = useState({});
  const [businessType, setBusinessType] = useState(null);
  const [restaurantId, setRestaurantId] = useState(null);
  const { user } = useAuth();

  // FOOD TRUCK STATES
  const [customerName, setCustomerName] = useState("");
  const [customerPhone, setCustomerPhone] = useState("");
  const [paymentMode, setPaymentMode] = useState(null);
  const [isRestaurant, setIsRestaurant] = useState(false);
  const [isFoodTruck, setIsFoodTruck] = useState(false)
  const [paymentMethod, setPaymentMethod] = useState(null);
  console.log(sendAppendOrder, "sendAppendOrder")
  useEffect(() => {
    if (!user) return;
    setRestaurantId(user.restaurantId);
    const activeRestaurant = user.restaurants?.find(
      (r) => r._id === user.restaurantId
    );
    if (activeRestaurant?.businessType) {
      setBusinessType(activeRestaurant.businessType);
    }
  }, [user]);


  const appendOrder = async (data) => {
    // const res = await fetch("/api/orders/append-items"
    const res = await fetch(`${apiConfig?.BASE_URL}/api/orders/append-items`, {
      method: "PUT",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data)
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.message);
    }

    return res.json();
  };


  // onst { user } = useAuth()
  useEffect(() => {
    // const type = localStorage.getItem("businessType") === "businessType";
    // setBusinessType(type);
    console.log(user, "user", user?.restaurantId);

    if (user?.restaurantId) {

      fetch(`${apiConfig?.BASE_URL}/api/restaurants/${user?.restaurantId}/context`)
        .then(res => res.json())
        .then(data => {
          if (data.businessType === "FOOD_TRUCK") {
            console.log(data.businessType, "data");
            setIsFoodTruck(true)
          }
          else {
            console.log(data.businessType, "data2");

            setIsRestaurant(true);
          }
        });
    }
    else {
      console.log("loading...")
    }
  }, [user]);

  // const isRestaurant = businessType === "RESTAURANT";
  // const isFoodTruck = businessType === "FOOD_TRUCK";

  useEffect(() => {
    if (restaurantId) fetchMenu();
  }, [restaurantId]);

  const fetchMenu = async () => {
    try {
      setLoading(true);
      const res = await fetch(`${apiConfig?.BASE_URL}/api/public/menu/${restaurantId}`);
      const data = await res.json();
      setCategories(data.categories || []);
      setAllItems(data.items || []);
    } catch (err) {
      toast.error("Failed to load menu");
      console.error("Menu fetch failed", err);
    } finally {
      setTimeout(() => setLoading(false), 600);
    }
  };

  const updateQuantity = (item, delta) => {
    setCart((prev) => {
      const currentQty = prev[item._id]?.quantity || 0;
      const nextQty = Math.max(0, currentQty + delta);
      const newCart = { ...prev };
      if (nextQty === 0) delete newCart[item._id];
      else newCart[item._id] = { ...item, quantity: nextQty };
      return newCart;
    });
  };

  const cartItemsArray = useMemo(() => Object.values(cart), [cart]);
  const totalPrice = useMemo(
    () => cartItemsArray.reduce((sum, item) => sum + item.basePrice * item.quantity, 0),
    [cartItemsArray]
  );

  // FIXED FILTER LOGIC: Comparing ID to ID
  const filteredItems = useMemo(() => {
    if (selectedCategory === "All") return allItems;
    return allItems.filter((item) => item.category === selectedCategory);
  }, [selectedCategory, allItems]);

  const handleSendOrder = async () => {

  if (!cartItemsArray.length)
    return toast.error("Your cart is empty");

  /*
  -----------------------------------------
  FOOD TRUCK VALIDATION
  -----------------------------------------
  */

  if (isFoodTruck) {

    if (!customerName)
      return toast.error("Customer details required");

    if (!paymentMode)
      return toast.error("Please select payment status");

    if (paymentMode === "PREPAID" && !paymentMethod)
      return toast.error("Select payment method");

  }

  const orderLoading = toast.loading("Processing order...");

  const payload = {
    items: cartItemsArray.map((i) => ({
      itemId: i._id,
      quantity: i.quantity,
      isUpsell: false
    })),
  };

  try {

    /*
    -----------------------------------------
    APPEND ORDER (TABLE RUNNING)
    -----------------------------------------
    */

    if (sendAppendOrder) {

      const appendPayload = {
        orderId: sendAppendOrder.currentOrderId,
        items: payload.items
      };

      const updatedOrder = await appendOrder(appendPayload);

      window.dispatchEvent(
        new CustomEvent("order_updated_local", { detail: updatedOrder })
      );

      toast.success("Items added to existing order!", { id: orderLoading });

      setCart({});
      setTimeout(() => close(), 1000);
      return;
    }

    /*
    -----------------------------------------
    STAFF ORDERS
    -----------------------------------------
    */

    if (isRestaurant || isFoodTruck)
      payload.placedBy = "STAFF";

    /*
    -----------------------------------------
    RESTAURANT ORDER
    -----------------------------------------
    */

    if (isRestaurant) {

      payload.tableNumber = table?.tableName;
      payload.customerPhone = "NA";
      payload.paymentMode = "POSTPAID";

    }

    /*
    -----------------------------------------
    FOOD TRUCK ORDER
    -----------------------------------------
    */

    if (isFoodTruck) {

      payload.customerName = customerName;
      payload.customerPhone = customerPhone || null;
      payload.paymentMode = paymentMode;

      if (paymentMode === "PREPAID") {
        payload.paymentMethod = paymentMethod;
      }

    }

    /*
    -----------------------------------------
    PLACE ORDER
    -----------------------------------------
    */

    const createdOrder = await placeOrder(payload);

    /*
    -----------------------------------------
    LOCAL UI UPDATE
    -----------------------------------------
    */

    if (window.dispatchEvent) {
      window.dispatchEvent(
        new CustomEvent("order_created", { detail: createdOrder })
      );
    }

    toast.success("Order placed successfully!", { id: orderLoading });

    /*
    -----------------------------------------
    RESET STATES
    -----------------------------------------
    */

    setCart({});
    setCustomerName("");
    setCustomerPhone("");
    setPaymentMode(null);
    setPaymentMethod(null);

    setTimeout(() => close(), 1000);

  } catch (err) {

    toast.error(err.message || "Order failed", { id: orderLoading });

  }

};
  return (
    <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[200] flex items-center justify-center p-0 md:p-6">
      <Toaster position="top-center" />

      <div className="bg-white w-full h-full md:h-[90vh] md:max-w-4xl md:rounded-[3rem] flex flex-col overflow-hidden shadow-2xl relative">

        {/* 1. HEADER */}
        <div className="shrink-0 bg-white p-4 md:p-6 border-b">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <button onClick={close} className="p-2 bg-slate-100 rounded-full hover:bg-slate-200">
                <ArrowLeft size={20} />
              </button>
              <h2 className="text-xl font-black text-slate-900 uppercase tracking-tight">
                {isRestaurant ? `TABLE ${table?.tableName}` : "QUICK ORDER"}
              </h2>
            </div>
            <button onClick={close} className="p-2 text-slate-400 hover:text-red-500">
              <X size={28} />
            </button>
          </div>

          {/* Categories Scroll - FIXED: Accessing _id correctly */}
          <div className="flex gap-2 overflow-x-auto no-scrollbar pb-2">
            <button
              onClick={() => setSelectedCategory("All")}
              className={`px-6 py-2 rounded-full text-[10px] font-black uppercase transition-all whitespace-nowrap ${selectedCategory === "All" ? "bg-slate-900 text-white shadow-lg" : "bg-slate-100 text-slate-500"
                }`}
            >
              All
            </button>
            {categories.map((cat) => (
              <button
                key={cat._id}
                onClick={() => setSelectedCategory(cat._id)}
                className={`px-6 py-2 rounded-full text-[10px] font-black uppercase transition-all whitespace-nowrap ${selectedCategory === cat._id ? "bg-slate-900 text-white shadow-lg" : "bg-slate-100 text-slate-500"
                  }`}
              >
                {cat.name}
              </button>
            ))}
          </div>
        </div>

        {/* 2. FOOD TRUCK INPUTS */}
        {isFoodTruck && (
          <div className="shrink-0 px-6 py-4 space-y-3 border-b bg-slate-50/50">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <input
                placeholder="Customer Name"
                value={customerName}
                onChange={(e) => setCustomerName(e.target.value)}
                className="w-full border p-3 rounded-2xl text-sm font-bold bg-white outline-orange-500"
              />
              <input
                placeholder="Customer Phone"
                value={customerPhone}
                onChange={(e) => setCustomerPhone(e.target.value)}
                className="w-full border p-3 rounded-2xl text-sm font-bold bg-white outline-orange-500"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setPaymentMode("PREPAID")}
                className={`flex-1 py-3 rounded-2xl text-xs font-black uppercase transition-all ${paymentMode === "PREPAID" ? "bg-green-600 text-white shadow-lg shadow-green-100" : "bg-white text-slate-400 border"
                  }`}
              >
                Paid
              </button>
              <button
                onClick={() => setPaymentMode("POSTPAID")}
                className={`flex-1 py-3 rounded-2xl text-xs font-black uppercase transition-all ${paymentMode === "POSTPAID" ? "bg-orange-600 text-white shadow-lg shadow-orange-100" : "bg-white text-slate-400 border"
                  }`}
              >
                Pay Later
              </button>
            </div>
            {paymentMode === "PREPAID" && (

              <div className="flex gap-2">

                <button
                  onClick={() => setPaymentMethod("CASH")}
                  className={`flex-1 py-2 rounded-xl ${paymentMethod === "CASH"
                      ? "bg-blue-600 text-white"
                      : "bg-white border"
                    }`}
                >
                  Cash
                </button>

                <button
                  onClick={() => setPaymentMethod("UPI")}
                  className={`flex-1 py-2 rounded-xl ${paymentMethod === "UPI"
                      ? "bg-blue-600 text-white"
                      : "bg-white border"
                    }`}
                >
                  UPI
                </button>

                <button
                  onClick={() => setPaymentMethod("CARD")}
                  className={`flex-1 py-2 rounded-xl ${paymentMethod === "CARD"
                      ? "bg-blue-600 text-white"
                      : "bg-white border"
                    }`}
                >
                  Card
                </button>

              </div>

            )}
          </div>
        )}

        {/* 3. MENU ITEMS */}
        <div className="flex-1 overflow-y-auto bg-slate-50 p-4 md:p-8 pb-48 custom-scrollbar">
          {loading ? (
            <div className="flex flex-col items-center justify-center h-full text-slate-400 gap-4">
              <Loader2 className="animate-spin" size={40} />
              <p className="font-bold uppercase text-[10px] tracking-widest">Loading Deliciousness...</p>
            </div>
          ) : filteredItems.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-slate-400">
              <UtensilsCrossed size={48} className="mb-4 opacity-20" />
              <p className="font-bold">No items found in this category</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {filteredItems.map((item) => {
                const qty = cart[item._id]?.quantity || 0;
                return (
                  <div key={item._id} className={`p-5 rounded-[2.5rem] border-2 transition-all flex items-center justify-between ${qty > 0 ? "border-orange-500 bg-white shadow-xl scale-[1.02]" : "border-white bg-white shadow-sm hover:shadow-md"}`}>
                    <div className="flex items-center gap-4">
                      <div className={`p-4 rounded-3xl ${qty > 0 ? "bg-orange-100 text-orange-500" : "bg-slate-50 text-slate-300"}`}>
                        <UtensilsCrossed size={24} />
                      </div>
                      <div>
                        <h4 className="font-black text-slate-900 text-xs uppercase mb-1">{item.name}</h4>
                        <p className="text-2xl font-black text-slate-900 leading-none">₹{item.basePrice}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      {qty > 0 ? (
                        <div className="flex items-center bg-slate-900 rounded-3xl p-1.5 gap-4">
                          <button onClick={() => updateQuantity(item, -1)} className="p-2 text-white hover:text-orange-400"><Minus size={18} /></button>
                          <span className="text-white font-black text-lg px-1">{qty}</span>
                          <button onClick={() => updateQuantity(item, 1)} className="p-2 text-white hover:text-orange-400"><Plus size={18} /></button>
                        </div>
                      ) : (
                        <button onClick={() => updateQuantity(item, 1)} className="px-8 py-4 bg-slate-100 text-slate-600 rounded-3xl font-black text-[11px] uppercase hover:bg-orange-500 hover:text-white transition-all shadow-sm">
                          Add +
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* 4. BOTTOM BAR */}
        {cartItemsArray.length > 0 && (
          <div className="absolute bottom-0 left-0 right-0 bg-white rounded-t-[3.5rem] shadow-[0_-25px_60px_rgba(0,0,0,0.12)] p-6 md:p-8 z-[210] border-t border-slate-50">
            <div className="max-w-3xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
              <div className="hidden md:flex flex-1 gap-4 overflow-x-auto no-scrollbar max-w-lg">
                {cartItemsArray.map((item) => (
                  <div key={item._id} className="bg-slate-50 px-4 py-2 rounded-2xl whitespace-nowrap shrink-0">
                    <p className="text-[10px] font-black text-slate-900 uppercase">{item.quantity} x {item.name}</p>
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between w-full md:w-auto gap-8">
                <div>
                  <p className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] mb-1">Grand Total</p>
                  <p className="text-4xl font-black text-slate-900 tracking-tighter">₹{totalPrice}</p>
                </div>
                <button
                  onClick={handleSendOrder}
                  className="bg-orange-500 text-white px-12 py-6 rounded-[2rem] font-black text-sm uppercase tracking-widest shadow-2xl shadow-orange-200 hover:bg-orange-600 active:scale-95 transition-all"
                >
                  Place Order
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}