"use client";
import { useEffect, useState } from "react";
import {
  Plus,
  Image as ImageIcon,
  Trash2,
  Search,
  PackagePlus,
  Edit3,
  ChevronRight,
  Layers,
  FolderPlus,
  Filter,
  X,
  Check
} from "lucide-react";
import toast from "react-hot-toast";
import { apiFetch } from "../../../utils/apiClient";
import { useAuth } from "../../context/AuthContext";
export default function MenuPage() {
  const [categories, setCategories] = useState([]);
  const [items, setItems] = useState([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [activeCategory, setActiveCategory] = useState("all");
  const [newCategory, setNewCategory] = useState("");
  const [itemName, setItemName] = useState("");
  const [price, setPrice] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [descrition, setDescrition] = useState("");
  const [loading, setLoading] = useState(false);

  // --- NEW STATES FOR EDITING ---
  const [editingItemId, setEditingItemId] = useState(null);
  const [editName, setEditName] = useState("");
  const [editPrice, setEditPrice] = useState("");

  // Mobile State Handlers
  const [isCatOpen, setIsCatOpen] = useState(false);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const { user, loading2 } = useAuth();
  const [baseUrl, setBaseUrl] = useState(null);

  const [menuLoading, setMenuLoading] = useState(true)

  const [role, setRole] = useState(null);

  const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;

  // const restaurantId = typeof window !== "undefined" ? localStorage.getItem("restaurantId") : null;
  useEffect(() => {
    if (!user) return;

    const role = user.role;
    setRole(role);

    console.log("User Role:", role);

    setBaseUrl(
      role === "owner"
        ? "global-menu"
        : "branch-menu"
    );
  }, [user]);

  const getBaseUrl = () => role === "owner" ? "global-menu" : "branch-menu";

  const API_BASE = "http://localhost:5000/api";




  const loadMenu = async () => {
    const type = baseUrl;
    setMenuLoading(true); // Start loading

    try {
      const [catRes, itemRes] = await Promise.all([
        apiFetch(`/api/${type}/categories`),
        apiFetch(`/api/${type}/items`)
      ]);

      const categoriesData = Array.isArray(catRes) ? catRes : catRes?.data;
      const itemsData = Array.isArray(itemRes) ? itemRes : itemRes?.data;

      setCategories(categoriesData || []);
      setItems(itemsData || []);
    } catch (err) {
      console.error("Menu Load Failed:", err.message);
      toast.error("Failed to load menu");
    } finally {
      setMenuLoading(false);  // End loading
    }
  };
  useEffect(() => {
    if (baseUrl) {

      loadMenu();
    }
  }, [baseUrl])
  // if (loading2) return <div>Loading Data</div>;
  const saveEdit = async (itemId) => {
    const type = getBaseUrl();

    try {
      await apiFetch(`/api/${type}/item/${itemId}`, {
        method: "PATCH",
        body: JSON.stringify({
          name: editName,
          basePrice: Number(editPrice)
        })
      });

      setEditingItemId(null);
      loadMenu();
      toast.success("Item updated");

    } catch (err) {
      toast.error(err.message || "Update failed");
    }
  };




//   const toggleItem = async (itemId) => {
//   try {
//     const endpoint =
//       role === "owner"
//         ? `/api/global-menu/item/${itemId}/toggle`
//         : `/api/branch-menu/item/${itemId}/toggle`;

//     const res = await apiFetch(endpoint, {
//       method: "PATCH"
//     });

//     const updatedItem = res.item;

//     // 🔥 Update local state immediately
//     setItems(prev =>
//   prev.map(item =>
//     item._id === itemId
//       ? { ...item, isAvailable: updatedItem.isAvailable }
//       : item
//   )
// );

//     toast.success("Item updated successfully");

//   } catch (err) {
//     toast.error(err.message || "Toggle failed");
//   }
// };


const toggleItem = async (itemId) => {
  try {
    const endpoint =
      role === "owner"
        ? `/api/global-menu/item/${itemId}/toggle`
        : `/api/branch-menu/item/${itemId}/toggle`;

    const res = await apiFetch(endpoint, {
      method: "PATCH"
    });

    const updatedItem = res.item;

    setItems(prev =>
      prev.map(item =>
        item._id === itemId
          ? { ...item, isAvailable: updatedItem.isAvailable }
          : item
      )
    );

    toast.success("Item updated successfully");

  } catch (err) {
    toast.error(err.message || "Toggle failed");
  }
};



  const deleteItem = async (itemId) => {
    if (!window.confirm("Delete this item?")) return;

    const type = getBaseUrl();

    try {
      await apiFetch(`/api/${type}/item/${itemId}`, {
        method: "DELETE"
      });

      loadMenu();
      toast.success("Item deleted");

    } catch (err) {
      toast.error(err.message || "Delete failed");
    }
  };

  const uploadImage = async (itemId, file) => {
    if (!file) return;

    const type = getBaseUrl();

    const formData = new FormData();
    formData.append("image", file);

    try {
      await apiFetch(`/api/${type}/item/${itemId}/image`, {
        method: "POST",
        body: formData
      });

      loadMenu();
      toast.success("Image uploaded");

    } catch (err) {
      toast.error(err.message || "Upload failed");
    }
  };



  const addCategory = async () => {
    if (!newCategory.trim()) {
      toast.error("Enter category name");
      return;
    }

    const type = getBaseUrl();

    try {
      await apiFetch(`/api/${type}/category`, {
        method: "POST",
        body: JSON.stringify({ name: newCategory })
      });

      setNewCategory("");
      loadMenu();
      toast.success("Category added");

    } catch (err) {
      toast.error(err.message || "Failed to add category");
    }
  };




  const addItem = async () => {
    if (!itemName || !price || !categoryId) {
      toast.error("Fill all required fields");
      return;
    }

    setLoading(true);

    const type = getBaseUrl();

    try {
      await apiFetch(`/api/${type}/item`, {
        method: "POST",
        body: JSON.stringify({
          name: itemName,
          basePrice: Number(price),
          category: categoryId,
          description: descrition
        })
      });

      setItemName("");
      setPrice("");
      setCategoryId("");
      setDescrition("");

      loadMenu();
      toast.success("Dish registered successfully");
      setIsFormOpen(false);

    } catch (err) {
      toast.error(err.message || "Registration failed");
    }

    setLoading(false);
  };




  const filteredItems = items.filter(i => {
    const name = (i.name || i.globalItem?.name || "").toLowerCase();
    const matchesSearch = name.includes(searchTerm.toLowerCase());
    if (activeCategory === "all") return matchesSearch;
    const itemCatId = i.category?._id || i.category || i.globalItem?.category?._id || i.globalItem?.category;
    return matchesSearch && (itemCatId === activeCategory);
  });


  if (menuLoading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
      </div>
    );
  }

  return (
    <div className="flex-1 min-h-screen bg-[#F8FAFC] flex flex-col font-sans overflow-hidden">

      {/* 🔍 TOP NAV */}
      <header className="bg-white border-b border-slate-100 px-4 lg:px-8 py-5 flex items-center justify-between shrink-0 shadow-sm z-40">
        <div className="flex items-center gap-4 lg:gap-8 flex-1">
          <div className="flex flex-col shrink-0">
            <h1 className="text-lg lg:text-xl font-black text-[#0F172A] leading-none uppercase tracking-tighter">
              Scan <span className="text-[#FF4D00]">Serve</span>
            </h1>
            <span className="text-[9px] font-bold text-slate-400 tracking-widest mt-1 uppercase">Menu Manager</span>
          </div>

          <div className="relative w-full max-w-lg hidden md:block">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={18} />
            <input
              type="text"
              placeholder="Search catalog dishes..."
              className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-100 rounded-2xl text-sm font-bold outline-none focus:border-[#FF4D00] transition-all"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        <div className="flex gap-2 lg:hidden">
          <button onClick={() => setIsCatOpen(true)} className="p-2 bg-slate-50 rounded-xl text-slate-600"><Filter size={20} /></button>
          <button onClick={() => setIsFormOpen(true)} className="p-2 bg-[#FF4D00] text-white rounded-xl shadow-lg shadow-orange-100"><Plus size={20} /></button>
        </div>
      </header>

      {/* Mobile Search */}
      <div className="p-4 md:hidden bg-white border-b border-slate-50">
        <div className="relative w-full">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-300" size={16} />
          <input
            type="text"
            placeholder="Search dishes..."
            className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-100 rounded-xl text-sm font-bold outline-none"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden relative">

        {/* 🏷️ LEFT: CATEGORY SIDEBAR */}
        <aside className={`
          fixed inset-y-0 left-0 z-50 w-72 bg-white border-r border-slate-100 flex flex-col shrink-0 transition-transform duration-300 ease-in-out
          lg:relative lg:translate-x-0 
          ${isCatOpen ? "translate-x-0" : "-translate-x-full"}
        `}>
          <div className="p-6 space-y-8">
            <div className="flex items-center justify-between lg:hidden">
              <span className="font-black text-[10px] uppercase text-slate-400">Filters</span>
              <button onClick={() => setIsCatOpen(false)}><X size={20} /></button>
            </div>

            <div>
              <h2 className="text-[10px] font-black text-[#FF4D00] uppercase tracking-widest mb-4 flex items-center gap-2">
                <FolderPlus size={14} /> Create Section
              </h2>
              <div className="flex items-center bg-slate-50 border border-slate-100 rounded-xl p-1.5 focus-within:border-[#FF4D00] transition-all">
                <input
                  value={newCategory}
                  onChange={e => setNewCategory(e.target.value)}
                  placeholder="e.g. Desserts"
                  className="px-3 py-2 text-xs font-bold bg-transparent outline-none w-full"
                />
                <button onClick={addCategory} className="bg-[#0F172A] text-white p-2 rounded-lg hover:bg-[#FF4D00] transition-all shadow-md">
                  <Plus size={16} />
                </button>
              </div>
            </div>

            <div>
              <h2 className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-4 flex items-center gap-2">
                <Layers size={14} /> Menu Sections
              </h2>
              <nav className="space-y-2 overflow-y-auto max-h-[50vh] no-scrollbar">
                <button
                  onClick={() => { setActiveCategory("all"); setIsCatOpen(false); }}
                  className={`w-full flex items-center justify-between px-5 py-4 rounded-2xl text-xs font-black transition-all ${activeCategory === "all" ? 'bg-[#0F172A] text-white shadow-lg' : 'text-slate-500 hover:bg-slate-50'
                    }`}
                >
                  All Items
                  <span className={`px-2 py-0.5 rounded-lg text-[9px] ${activeCategory === 'all' ? 'bg-[#FF4D00] text-white' : 'bg-slate-100'}`}>
                    {items.length}
                  </span>
                </button>

                {categories.map(cat => (
                  <button
                    key={cat._id}
                    onClick={() => { setActiveCategory(cat._id); setIsCatOpen(false); }}
                    className={`w-full flex items-center justify-between px-5 py-4 rounded-2xl text-xs font-black transition-all ${activeCategory === cat._id ? 'bg-[#FF4D00] text-white shadow-lg shadow-orange-100' : 'text-slate-500 hover:bg-slate-50'
                      }`}
                  >
                    <span className="truncate pr-2">{cat.name}</span>
                    <ChevronRight size={14} className={activeCategory === cat._id ? 'opacity-100' : 'opacity-0'} />
                  </button>
                ))}
              </nav>
            </div>
          </div>
        </aside>
        {/* 🍔 CENTER: MAIN GRID */}
        <main className="flex-1 overflow-y-auto p-4 lg:p-10 no-scrollbar">
          <div className="max-w-5xl mx-auto">
            <div className="flex items-end justify-between mb-6 lg:mb-10">
              <h2 className="text-2xl lg:text-3xl font-black text-[#0F172A] tracking-tighter uppercase leading-none">
                Live <span className="text-[#FF4D00]">Menu</span>
              </h2>
              <p className="text-xl lg:text-2xl font-black text-[#0F172A] leading-none">
                {filteredItems.length} <span className="text-[10px] text-slate-400 uppercase tracking-widest ml-1 font-bold">Items</span>
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-1 xl:grid-cols-2 gap-4 lg:gap-6 animate-in fade-in duration-500">
              {filteredItems.map((i) => {
                const isEditing = editingItemId === i._id;
                // const isAvailable = i.isAvailable !== false;
                const isAvailable = i.isAvailable;

                return (
                  <div key={i._id} className={`bg-white rounded-[1.5rem] lg:rounded-[2rem] border border-slate-100 shadow-sm hover:shadow-xl transition-all duration-300 flex overflow-hidden h-36 lg:h-44 group ${(!isAvailable) ? 'bg-slate-50/50' : ''}`}>

                    {/* Image Section */}
                    <div className="w-28 lg:w-1/3 bg-slate-50 flex items-center justify-center border-r border-slate-50 relative shrink-0 group/img">
                      {i.imageUrl ? (
                        <img src={i.imageUrl} className={`w-full h-full object-cover ${!isAvailable ? 'grayscale opacity-50' : ''}`} />
                      ) : (
                        <ImageIcon size={24} className="text-slate-200 lg:w-8 lg:h-8" />
                      )}

                      {/* Availability Badge Overlay */}
                      {!isAvailable && (
                        <div className="absolute inset-0 bg-black/20 flex items-center justify-center">
                          <span className="bg-white/90 text-[8px] font-black px-2 py-1 rounded shadow-sm uppercase tracking-tighter text-slate-500">Disabled</span>
                        </div>
                      )}

                      <label className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover/img:opacity-100 cursor-pointer transition-opacity">
                        <Plus size={20} className="text-white" />
                        <input type="file" className="hidden" accept="image/*" onChange={(e) => uploadImage(i._id, e.target.files[0])} />
                      </label>
                    </div>

                    <div className="flex-1 p-4 lg:p-5 flex flex-col justify-between overflow-hidden">
                      <div className="overflow-hidden">
                        <div className="flex justify-between items-start">
                          <span className={`px-2 py-0.5 rounded-lg text-[7px] lg:text-[8px] font-black uppercase tracking-widest mb-1 lg:mb-2 inline-block ${isAvailable ? 'bg-orange-50 text-[#FF4D00]' : 'bg-slate-200 text-slate-500'}`}>
                            {i.category?.name || "Standard"}
                          </span>
                        </div>

                        {isEditing ? (
                          <input
                            className="w-full text-xs lg:text-sm font-black text-[#0F172A] uppercase border-b border-[#FF4D00] outline-none bg-transparent"
                            value={editName}
                            onChange={(e) => setEditName(e.target.value)}
                            autoFocus
                          />
                        ) : (
                          <h3 className={`text-xs lg:text-sm font-black uppercase leading-tight truncate ${isAvailable ? 'text-[#0F172A]' : 'text-slate-400'}`}>
                            {i.name}
                          </h3>
                        )}

                        <p className="text-[9px] lg:text-[10px] text-slate-400 font-bold mt-1 line-clamp-1 lg:line-clamp-2 leading-relaxed">
                          {i.description || "Authentic ingredients prepared fresh for your table."}
                        </p>
                      </div>

                      <div className="flex items-center justify-between mt-auto pt-2 lg:pt-3 border-t border-slate-50">
                        {isEditing ? (
                          <div className="flex items-center">
                            <span className="text-lg lg:text-xl font-black text-[#0F172A]">₹</span>
                            <input
                              type="number"
                              className="w-16 ml-1 text-lg lg:text-xl font-black text-[#0F172A] border-b border-[#FF4D00] outline-none bg-transparent"
                              value={editPrice}
                              onChange={(e) => setEditPrice(e.target.value)}
                            />
                          </div>
                        ) : (
                          <p className={`text-lg lg:text-xl font-black ${isAvailable ? 'text-[#0F172A]' : 'text-slate-300'}`}>₹{i.price || i.basePrice}</p>
                        )}

                        <div className="flex gap-1 lg:gap-2 items-center">
                          {/* Toggle Button: Visible to non-owners */}
                          {/* {role !== "owner" && (
                            <button
                              onClick={() => toggleItem(i._id)}
                              className={`px-2 py-1 rounded-md text-[8px] font-black uppercase tracking-tighter transition-all active:scale-95 ${isAvailable ? 'bg-green-100 text-green-600' : 'bg-slate-100 text-slate-400'}`}
                            >
                              {isAvailable ? 'Enabled' : 'Disabled'}
                            </button>
                          )} */}

                          <button
                            onClick={() => toggleItem(i._id)}
                            className={`px-2 py-1 rounded-md text-[8px] font-black uppercase tracking-tighter transition-all active:scale-95 ${i.isAvailable
                                ? "bg-green-100 text-green-600"
                                : "bg-slate-100 text-slate-400"
                              }`}
                          >
                           {i.isAvailable ?  "Disabled" : "Enabled" }
                          </button>

                          {isEditing ? (
                            <button onClick={() => saveEdit(i._id)} className="p-2 bg-green-500 text-white rounded-lg lg:rounded-xl active:scale-90">
                              <Check size={12} />
                            </button>
                          ) : (
                            <button
                              onClick={() => {
                                setEditingItemId(i._id);
                                setEditName(i.name);
                                setEditPrice(i.price || i.basePrice);
                              }}
                              className="p-2 bg-[#0F172A] text-white rounded-lg lg:rounded-xl active:scale-90 transition-all"
                            >
                              <Edit3 size={12} />
                            </button>
                          )}
                          <button onClick={() => deleteItem(i._id)} className="p-2 text-slate-300 hover:text-red-500 active:scale-90 transition-all">
                            <Trash2 size={12} />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </main>

        {/* ➕ RIGHT: REGISTER PANEL */}
        <aside className={`
          fixed inset-y-0 right-0 z-50 w-80 bg-white border-l border-slate-100 p-8 overflow-y-auto shrink-0 transition-transform duration-300 ease-in-out
          lg:relative lg:translate-x-0
          ${isFormOpen ? "translate-x-0" : "translate-x-full"}
        `}>
          <div className="flex items-center justify-between mb-10">
            <div className="flex items-center gap-3">
              <div className="bg-[#FF4D00] p-2 rounded-xl shadow-lg shadow-orange-100">
                <PackagePlus className="text-white" size={18} />
              </div>
              <h2 className="text-[11px] font-black text-[#0F172A] uppercase tracking-widest">New Entry</h2>
            </div>
            <button className="lg:hidden" onClick={() => setIsFormOpen(false)}><X size={20} /></button>
          </div>

          <div className="space-y-6">
            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Title</label>
              <input value={itemName} onChange={e => setItemName(e.target.value)} className="w-full px-5 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-xs font-bold outline-none focus:border-[#FF4D00] transition-all" placeholder="Dish name..." />
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Description</label>
              <textarea value={descrition} onChange={e => setDescrition(e.target.value)} className="w-full px-5 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-xs font-medium outline-none focus:border-[#FF4D00] h-24 resize-none" placeholder="Optional details..." />
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Market Price (₹)</label>
              <input type="number" value={price} onChange={e => setPrice(e.target.value)} className="w-full px-5 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-sm font-black outline-none focus:border-[#FF4D00]" placeholder="0.00" />
            </div>

            <div className="space-y-1.5 pb-4">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Set Category</label>
              <select value={categoryId} onChange={e => setCategoryId(e.target.value)} className="w-full px-5 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-xs font-bold outline-none focus:border-[#FF4D00] appearance-none">
                <option value="">Select category...</option>
                {categories.map(c => <option key={c._id} value={c._id}>{c.name}</option>)}
              </select>
            </div>

            <button
              onClick={addItem}
              disabled={loading}
              className="w-full bg-[#0F172A] text-white py-5 rounded-[2rem] font-black text-[10px] uppercase tracking-widest hover:bg-[#FF4D00] shadow-xl shadow-slate-100 transition-all active:scale-95 disabled:opacity-50"
            >
              {loading ? "Registering..." : "Add to Catalog"}
            </button>
          </div>
        </aside>

        {/* OVERLAYS */}
        {(isCatOpen || isFormOpen) && (
          <div
            className="fixed inset-0 bg-black/20 backdrop-blur-sm z-40 lg:hidden"
            onClick={() => { setIsCatOpen(false); setIsFormOpen(false); }}
          />
        )}
      </div>
    </div>
  );
}