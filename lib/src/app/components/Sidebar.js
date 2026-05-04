


"use client";
import { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

import apiConfig from "@/utils/apiConfig";

import {
  ClipboardList, BarChart3, Sparkles, UtensilsCrossed,
  UserPlus, GitBranch, LogOut, ChevronRight,
  QrCode, Menu, X, ChevronLeft, Podcast, LayoutDashboard, Receipt
} from "lucide-react";
import { useAuth } from "../context/AuthContext";

export default function Sidebar() {
  const pathname = usePathname();
  const { user } = useAuth();
  const [isExpanded, setIsExpanded] = useState(true);
  const [isMobileOpen, setIsMobileOpen] = useState(false);
  const router = useRouter();
  // Close mobile sidebar on route change
  useEffect(() => {
    setIsMobileOpen(false);
  }, [pathname]);


  const handleLogout = async () => {
    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/auth/logout`, {
        method: "POST",
        credentials: "include", // required for cookies
      });
      if (res.ok) {
        const data = await res.json();
        console.log(data);

        // clear frontend storage if used
        localStorage.clear();

        // redirect to landing page
        router.push("/");
      }
      else{

      }



    } catch (error) {
      console.error("Logout failed:", error);
    }
  };

  // Master list of all possible navigation items
  const allNavItems = [
    { name: "Live Orders", href: "/dashboard/orders", icon: ClipboardList },
    { name: "Table Management", href: "/dashboard/OwnerSetup", icon: LayoutDashboard },
    { name: "Analytics", href: "/dashboard/analytics", icon: BarChart3 },
    { name: "Expense Tracker", href: "/dashboard/profit", icon: Receipt },
    { name: "Upsell Logic", href: "/dashboard/upsell", icon: Sparkles },
    { name: "Menu Manager", href: "/dashboard/menu", icon: UtensilsCrossed },
    { name: "QR Print", href: "/dashboard/tablegenerator", icon: QrCode },
    { name: "Staff Manager", href: "/dashboard/createmanager", icon: UserPlus },
    { name: "Branch Control", href: "/dashboard/createbranch", icon: GitBranch },
    { name: "Buy Subscription", href: "/dashboard/IncreaseBranchLimit", icon: Podcast },
  ];

  // Logic to filter items based on Role, Permission, and Business Type
  const navItems = useMemo(() => {
    if (!user) return [];

    let filteredItems = [];

    // 1. Role-based filtering
    if (user.role === "owner") {
      // Owners see everything by default
      filteredItems = [...allNavItems];
    } else if (user.role === "manager") {
      if (user.permissionLevel === "LIMITED") {
        // Limited Manager: Specific restricted list
        filteredItems = allNavItems.filter(item =>
          ["Live Orders", "Table Management", "Expense Tracker", "Menu Manager"].includes(item.name)
        );
      } else {
        // Standard Manager: Full operational list
        filteredItems = allNavItems.filter(item =>
          ["Live Orders", "Table Management", "Analytics", "Expense Tracker", "Menu Manager", "QR Print"].includes(item.name)
        );
      }
    }


    // 2. Business Type Filtering (Apply to ALL roles)
    // If it's a Food Truck, remove Table Management regardless of role
    console.log(user?.businessType);
    if (user?.businessType === "FOOD_TRUCK") {
      filteredItems = filteredItems.filter(item => item.name !== "Table Management");
    }

    return filteredItems;
  }, [user]);

  return (
    <>
      {/* 📱 MOBILE TOP BAR */}
      <div className="lg:hidden flex items-center justify-between px-6 py-4 bg-white border-b border-gray-100 sticky top-0 z-40 w-full">
        {/* <div className="flex items-center gap-3">
         
          <span className="font-black text-lg text-[#0F172A]">Scan Serve</span>
        </div> */}

        <div
          onClick={() => router.push("/")}
          className="flex items-center gap-3 cursor-pointer hover:opacity-80 transition-all"
        >
          {/* Assuming you want the icon here too */}
          <div className="bg-[#FF5C00] p-1.5 rounded-lg shadow-lg shadow-orange-100">
            <QrCode className="text-white w-6 h-6" />
          </div>
          <span className="font-black text-lg text-[#0F172A] tracking-tighter uppercase">
            Scan <span className="text-[#FF5C00]">Serve</span>
          </span>
        </div>
        <button
          onClick={() => setIsMobileOpen(true)}
          className="p-2 bg-gray-50 rounded-xl text-[#0F172A] active:scale-95 transition-transform"
        >
          <Menu size={24} />
        </button>
      </div>

      {/* 🖥️ SIDEBAR CONTAINER */}
      <aside
        className={`
          fixed inset-y-0 left-0 z-50 bg-white border-r border-[#EFF2F4] flex flex-col transition-all duration-300 ease-in-out
          lg:relative lg:translate-x-0
          ${isMobileOpen ? "translate-x-0 w-[280px]" : "-translate-x-full lg:translate-x-0"}
          ${isExpanded ? "lg:w-72" : "lg:w-24"}
        `}
      >
        {/* LOGO SECTION */}
        <div className="p-6 flex items-center justify-between h-24">
          <div className={`flex items-center gap-3 transition-opacity duration-300 ${!isExpanded && "lg:opacity-0 lg:pointer-events-none"}`}>
            {/* <div className="w-10 h-10 bg-[#FF5C00] rounded-xl flex items-center justify-center text-white font-black italic shadow-lg shadow-orange-100 shrink-0">P</div> */}
            {/* <div className="whitespace-nowrap">
              <h3 className="text-xl font-black text-[#0F172A] leading-none">Scan <span className="text-[#FF5C00]">Serve</span></h3>
              <p className="text-[9px] font-bold text-gray-400 uppercase tracking-widest mt-1">Admin Portal</p>
            </div> */}

            <div
              onClick={() => router.push("/")}
              className="flex items-center gap-3 cursor-pointer group hover:opacity-80 transition-all"
            >
              {/* Optional: Add your QR Icon here if it's missing from this specific div */}
              <div className="bg-[#FF5C00] p-1.5 rounded-lg shadow-lg shadow-orange-100 group-hover:rotate-12 transition-transform">
                <QrCode className="text-white w-5 h-5" />
              </div>

              <div className="whitespace-nowrap">
                <h3 className="text-xl font-black text-[#0F172A] leading-none">
                  Scan <span className="text-[#FF5C00]">Serve</span>
                </h3>
                <p className="text-[9px] font-bold text-gray-400 uppercase tracking-widest mt-1">
                  Admin Portal
                </p>
              </div>
            </div>
          </div>

          {/* Desktop Toggle Button */}
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="hidden lg:flex absolute -right-3 top-9 bg-white border border-gray-100 rounded-full p-1 shadow-md z-[60] hover:text-[#FF5C00] transition-colors"
          >
            {isExpanded ? <ChevronLeft size={16} /> : <ChevronRight size={16} />}
          </button>

          {/* Mobile Close Button */}
          <button onClick={() => setIsMobileOpen(false)} className="lg:hidden p-2 text-gray-400">
            <X size={24} />
          </button>
        </div>

        {/* NAVIGATION */}
        <nav className="flex-1 px-4 space-y-2 mt-4 overflow-y-auto no-scrollbar">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            const Icon = item.icon;
            return (
              <Link
                key={item.name}
                href={item.href}
                className={`flex items-center rounded-2xl transition-all duration-200 group ${isExpanded || isMobileOpen ? "px-5 py-4" : "p-4 justify-center"
                  } ${isActive
                    ? "bg-[#FF5C00] text-white shadow-lg shadow-orange-200"
                    : "text-[#475569] hover:bg-orange-50 hover:text-[#FF5C00]"
                  }`}
              >
                <Icon size={22} className={`shrink-0 ${isActive ? "animate-pulse" : ""}`} />
                {(isExpanded || isMobileOpen) && (
                  <span className="ml-4 text-[15px] font-bold whitespace-nowrap">{item.name}</span>
                )}
                {!isExpanded && !isMobileOpen && (
                  <div className="absolute left-20 bg-[#0F172A] text-white px-3 py-1 rounded text-xs opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity z-50">
                    {item.name}
                  </div>
                )}
              </Link>
            );
          })}
        </nav>

        {/* FOOTER */}
        <div className="p-6 border-t border-gray-50">
          <button className={`w-full flex cursor-pointer items-center gap-4 text-gray-400 font-bold hover:text-red-500 transition-colors ${(!isExpanded && !isMobileOpen) && "justify-center"}`} onClick={handleLogout}  >
            <LogOut size={22} className="shrink-0" />
            {(isExpanded || isMobileOpen) && <span>Sign Out</span>}
          </button>
        </div>
      </aside>

      {/* 🌫️ MOBILE OVERLAY */}
      {isMobileOpen && (
        <div
          className="fixed inset-0 bg-[#0F172A]/40 backdrop-blur-sm z-40 lg:hidden transition-opacity"
          onClick={() => setIsMobileOpen(false)}
        />
      )}
    </>
  );
}