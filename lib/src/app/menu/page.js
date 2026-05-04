


"use client";
import { useState, useEffect, useMemo } from "react";
import { Search, ShoppingBag, Plus, Minus, Star, ChevronRight, X, ArrowRight, Image as ImageIcon } from "lucide-react";
import { placeOrder } from "@/utils/api";
import apiConfig from "@/utils/apiConfig";
export default function MenuPage() {
  const [menu, setMenu] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeCategory, setActiveCategory] = useState(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [cart, setCart] = useState({});
  const [businessType, setBusinessType] = useState(false);
  const [isReviewModalOpen, setIsReviewModalOpen] = useState(false);
  const [upsellData, setUpsellData] = useState({});
  const [activeUpsellId, setActiveUpsellId] = useState(null);

  const restaurantId = typeof window !== "undefined" ? localStorage.getItem("restaurantId") : null;

  useEffect(() => {
    if (!restaurantId) return;

    // 1. Fetch Business Type Context
    fetch(`${apiConfig?.BASE_URL}/api/restaurants/${restaurantId}/context`)
      .then(res => res.json())
      .then(data => {
        if (data.businessType === "FOOD_TRUCK") setBusinessType(true);
      });

    // 2. Fetch Menu
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


  const updateQuantity = (item, delta) => {

    setCart(prev => {

      const existingItem = prev[item._id];

      const currentQty = existingItem?.quantity || 0;
      const nextQty = Math.max(0, currentQty + delta);

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

          // ✅ CRITICAL FIX 🔥🔥🔥
          isUpsell: existingItem?.isUpsell ?? item.isUpsell ?? false,
        };
      }

      return newCart;
    });
  };

  const cartItemsArray = useMemo(() => Object.values(cart), [cart]);
  const totalPrice = cartItemsArray.reduce((sum, item) => sum + (item.basePrice * item.quantity), 0);

  const handleCheckout = async () => {
    const name = prompt("Enter customer name") || "Guest";
    const phone = prompt("Enter phone number");
    if (!phone) return;

    try {
      const payload = {
        placedBy: "CUSTOMER",
        tableNumber: businessType ? null : 7,
        customerName: name,
        customerPhone: phone,
        items: cartItemsArray.map((i) => ({
          itemId: i._id,
          quantity: i.quantity,
          isUpsell: Boolean(i.isUpsell),
        })),
      };
      console.log(payload, "payload")
      await placeOrder(payload);
      alert("Order placed successfully");
      setCart({});
      setIsReviewModalOpen(false);
    } catch (err) {
      alert(err.message || "Failed to place order");
    }
  };
  useEffect(() => {
    console.log(isReviewModalOpen,"isReviewModalOpen")
    if (isReviewModalOpen && cartItemsArray.length > 0) {
      console.log(isReviewModalOpen,"hit isReviewModalOpen")
      // Fetch upsell based on the most recent or most expensive item in cart
      const leadItem = cartItemsArray[0];
      fetchUpsell(leadItem._id);
    }
  }, [isReviewModalOpen]);

  const currentSuggestions = upsellData[activeUpsellId]?.suggestions || [];
  console.log(currentSuggestions,"currentSuggestions");
  if (loading) return <MenuSkeleton />;

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

      <main className="max-w-2xl mx-auto pb-32">
        {/* Search */}
        <div className="px-6 py-4">
          <div className="relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
            <input
              type="text"
              placeholder="Search dishes..."
              className="w-full bg-slate-100/50 border-none rounded-2xl py-4 pl-12 pr-4 text-sm font-bold text-slate-700 outline-none"
              onChange={(e) => setSearchQuery(e.target.value.toLowerCase())}
            />
          </div>
        </div>

        {/* Categories */}
        <div className="flex overflow-x-auto gap-3 px-6 py-4 no-scrollbar">
          {menu?.categories?.map((cat) => (
            <button
              key={cat._id}
              onClick={() => setActiveCategory(cat._id)}
              className={`px-6 py-3 rounded-full whitespace-nowrap text-sm font-black transition-all ${activeCategory === cat._id ? "bg-[#FF5C00] text-white shadow-lg shadow-orange-100" : "bg-white text-slate-400 border border-slate-100"
                }`}
            >
              {cat.name}
            </button>
          ))}
        </div>

        {/* Item List */}
        <div className="mt-4 space-y-2">
          {menu?.items
            ?.filter((item) => item.category === activeCategory && item.name.toLowerCase().includes(searchQuery))
            .map((item) => (
              <div key={item._id} className="bg-white px-6 py-8 border-b border-slate-50 last:border-none">
                <div className="flex gap-4">
                  {/* Left Side: Info */}
                  <div className="flex-1">
                    {/* Veg Indicator */}
                    <div className="w-4 h-4 border-2 border-green-600 rounded-sm flex items-center justify-center mb-2">
                      <div className="w-1.5 h-1.5 rounded-full bg-green-600" />
                    </div>
                    <h3 className="text-xl font-black text-[#0F172A] uppercase leading-tight">{item.name}</h3>
                    {/* <div className="flex items-center gap-2 mb-2">
                        <div className="h-1 w-8 bg-green-500 rounded-full" />
                        <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Highly reordered</span>
                    </div> */}
                    <p className="text-xl font-black text-[#0F172A] tracking-tighter">₹{item.basePrice}</p>
                    <p className="text-[11px] text-slate-400 font-medium leading-relaxed mt-2 line-clamp-2">
                      {item.description || "Authentic ingredients prepared fresh for your table."}
                    </p>
                  </div>

                  {/* Right Side: Image & Logic */}
                  <div className="w-32 flex flex-col items-center">
                    <div className="w-32 h-32 bg-slate-50 rounded-[2rem] overflow-hidden mb-[-20px] relative z-0 border border-slate-100">
                      {item.imageUrl ? (
                        <img src={item.imageUrl} className="w-full h-full object-cover" alt={item.name} />
                      ) : (
                        <ImageIcon className="w-full h-full p-8 text-slate-200" />
                      )}
                    </div>
                    <div className="z-10 w-full px-2">
                      {cart[item._id]?.quantity ? (
                        <div className="bg-[#FF5C00] text-white flex items-center justify-between rounded-xl shadow-lg h-10 overflow-hidden">
                          <button onClick={() => updateQuantity(item, -1)} className="px-3 hover:bg-orange-600 transition-all"><Minus size={14} strokeWidth={3} /></button>
                          <span className="font-black text-sm">{cart[item._id].quantity}</span>
                          <button onClick={() => updateQuantity(item, 1)} className="px-3 hover:bg-orange-600 transition-all"><Plus size={14} strokeWidth={3} /></button>
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

                {/* Restored Pairing/Upsell Section */}
                {cart[item._id]?.quantity > 0 && upsellData[item._id] && activeUpsellId === item._id && (
                  <div className="mt-10 p-6 bg-[#F8FAFC] rounded-[2.5rem] border border-slate-100 animate-in slide-in-from-top-4 duration-300">
                    <div className="flex items-center justify-between mb-4">
                      <h4 className="text-[11px] font-black text-slate-400 uppercase tracking-widest">You will love pairing it with</h4>
                      <X size={16} className="text-slate-300 cursor-pointer" onClick={() => setActiveUpsellId(null)} />
                    </div>
                    <div className="flex gap-4 overflow-x-auto no-scrollbar pb-1">
                      {upsellData[item._id].suggestions.map((sug) => (
                        <div key={sug._id} className="min-w-[140px] bg-white border border-slate-100 rounded-3xl p-3 shadow-sm flex flex-col">
                          <div className="w-full h-20 bg-slate-50 rounded-2xl mb-3 overflow-hidden flex items-center justify-center">
                            {sug.imageUrl ? <img src={sug.imageUrl} className="w-full h-full object-cover" /> : <ImageIcon className="text-slate-200" size={24} />}
                          </div>
                          <p className="text-[11px] font-black text-[#0F172A] uppercase truncate mb-1">{sug.name}</p>
                          <div className="flex justify-between items-center mt-auto">
                            <span className="text-[10px] font-bold text-slate-400">₹{sug.price}</span>
                            <button
                              onClick={() => updateQuantity({ ...sug, _id: sug._id, basePrice: sug.price, isUpsell: true }, 1)}
                              className="text-[#FF5C00] bg-white border border-orange-100 px-3 py-1.5 rounded-lg font-black text-[10px] active:scale-90 transition-all"
                            >
                              Add +
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ))}
        </div>
      </main>

      {/* Cart Bar */}
      {cartItemsArray.length > 0 && (
        <div className="fixed bottom-8 left-6 right-6 z-50">
          <button
            onClick={() => setIsReviewModalOpen(true)}
            className="w-full max-w-2xl mx-auto bg-slate-900 text-white p-2 pl-6 rounded-[2rem] flex items-center justify-between shadow-2xl"
          >
            <div className="text-left">
              <p className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Your Order</p>
              <p className="text-lg font-black tracking-tighter">{cartItemsArray.length} Items • ₹{totalPrice}</p>
            </div>
            <div className="bg-orange-500 h-14 px-8 rounded-3xl flex items-center gap-2">
              <span className="font-black text-sm uppercase">Review Order</span>
              <ChevronRight size={18} />
            </div>
          </button>
        </div>
      )}

      {/* Basic Review Modal */}
      {/* {isReviewModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm" onClick={() => setIsReviewModalOpen(false)} />
          <div className="relative bg-white w-full max-w-lg rounded-t-[2.5rem] p-6 max-h-[85vh] overflow-y-auto animate-in slide-in-from-bottom duration-300">
            <h2 className="text-xl font-black mb-6">Review Items</h2>
            <div className="space-y-4">
              {cartItemsArray.map(i => (
                <div key={i._id} className="flex justify-between items-center py-2">
                  <div>
                    <p className="font-bold text-sm uppercase">{i.name}</p>
                    <p className="text-xs text-slate-400">₹{i.basePrice} x {i.quantity}</p>
                  </div>
                  <div className="flex items-center gap-3 bg-slate-100 px-3 py-1 rounded-xl">
                    <button onClick={() => updateQuantity(i, -1)}><Minus size={14} /></button>
                    <span className="font-black text-sm">{i.quantity}</span>
                    <button onClick={() => updateQuantity(i, 1)}><Plus size={14} /></button>
                  </div>
                </div>
              ))}
            </div>
            <div className="mt-8 pt-6 border-t border-slate-100 flex justify-between items-center">
              <div>
                <p className="text-[10px] font-black text-slate-400 uppercase">Total Amount</p>
                <p className="text-2xl font-black">₹{totalPrice}</p>
              </div>
              <button onClick={handleCheckout} className="bg-orange-500 text-white px-8 py-4 rounded-3xl font-black uppercase text-xs shadow-xl">
                Place Order
              </button>
            </div>
          </div>
        </div>
      )} */}


      {/* Basic Review Modal */}
      {isReviewModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center">
          <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm" onClick={() => setIsReviewModalOpen(false)} />
          <div className="relative bg-white w-full max-w-lg rounded-t-[2.5rem] p-6 max-h-[85vh] overflow-y-auto animate-in slide-in-from-bottom duration-300">

            <h2 className="text-xl font-black mb-6">Review Items</h2>

            {/* Cart Items List */}
            <div className="space-y-4 mb-6">
              {cartItemsArray.map(i => (
                <div key={i._id} className="flex justify-between items-center py-2">
                  <div>
                    <p className="font-bold text-sm uppercase">{i.name}</p>
                    <p className="text-xs text-slate-400">₹{i.basePrice} x {i.quantity}</p>
                  </div>
                  <div className="flex items-center gap-3 bg-slate-100 px-3 py-1 rounded-xl">
                    <button onClick={() => updateQuantity(i, -1)}><Minus size={14} /></button>
                    <span className="font-black text-sm">{i.quantity}</span>
                    <button onClick={() => updateQuantity(i, 1)}><Plus size={14} /></button>
                  </div>
                </div>
              ))}
            </div>

            {/* --- UPSELL SECTION --- */}
            {currentSuggestions.length > 0 && (
              <div className="mb-8 p-4 bg-orange-50/50 rounded-[2rem] border border-orange-100/50">
                <p className="text-[10px] font-black text-orange-500 uppercase tracking-widest mb-3 px-2">
                  Pairs well with...
                </p>
                <div className="flex gap-3 overflow-x-auto pb-2 no-scrollbar">
                  {currentSuggestions.map((item) => (
                    <div key={item._id} className="min-w-[130px] bg-white p-3 rounded-2xl shadow-sm flex flex-col items-center">
                      <div className="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center text-orange-600 mb-2">
                        <Plus size={16} />
                      </div>
                      <p className="text-[10px] font-bold uppercase text-center line-clamp-1">{item.name}</p>
                      <p className="text-xs font-black mb-2">₹{item.basePrice}</p>
                      <button
                        onClick={() => addToCart(item)} // Re-use your main addToCart function
                        className="w-full py-2 bg-[#0F172A] text-white text-[9px] font-black uppercase rounded-xl active:scale-95 transition-all"
                      >
                        Add +
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Total and Checkout */}
            <div className="mt-4 pt-6 border-t border-slate-100 flex justify-between items-center">
              <div>
                <p className="text-[10px] font-black text-slate-400 uppercase">Total Amount</p>
                <p className="text-2xl font-black">₹{totalPrice}</p>
              </div>
              <button onClick={handleCheckout} className="bg-orange-500 text-white px-8 py-4 rounded-3xl font-black uppercase text-xs shadow-xl active:scale-95">
                Place Order
              </button>
            </div>
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