"use client";
import { useEffect, useState, useMemo } from "react";
import {
  Clock,
  UtensilsCrossed,
  Package,
  CheckCircle2,
  XCircle,
  Search,
  Calendar,
  Sparkles,
  Plus,
  Trophy,
  ChevronRight,
  User,
  Phone,
  MoveRight,
  TrendingUp
} from "lucide-react";
import MenuModal from "@/app/components/MenuModal";
import toast, { Toaster } from 'react-hot-toast';
import Swal from 'sweetalert2';
import { useAuth } from "@/app/context/AuthContext";
import { apiFetch } from "../../../utils/apiClient";
import apiConfig from "@/utils/apiConfig";

import { getSocket } from "@/app/lib/socket";

export const cancelOrder = async (orderId) => {
  try {
    return await apiFetch(`/api/admin/orders/${orderId}/cancel`, {
      method: "PATCH"
    });

  } catch (err) {
    console.error("Cancel Error:", err.message);
    throw err;
  }
};

export const collectPayment = async ({ orderId, paymentMethod }) => {

  const res = await fetch(`${apiConfig?.BASE_URL}/api/admin/orders/collect-payment`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      orderId,
      paymentMethod
    })
  });

  const data = await res.json();

  if (!res.ok) {
    throw new Error(data.message || "Payment update failed");
  }

  return data;

};
export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [servedOrders, setServedOrders] = useState([]);
  const [payLaterOrders, setPayLaterOrders] = useState([]);
  const [activeFilter, setActiveFilter] = useState("All");
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [openMenuModel, setOpenMenuModel] = useState(false);
  // New States for Shifting and Details
  const [shiftingOrder, setShiftingOrder] = useState(null);
  const [newTableValue, setNewTableValue] = useState("");
  const [viewDetails, setViewDetails] = useState(null);
  const [businessType, setBusinessType] = useState(false);
  const [statusUpdating, setStatusUpdating] = useState(null);


  const [paymentModal, setPaymentModal] = useState(false);
  const [paymentOrder, setPaymentOrder] = useState(null);

  const { user } = useAuth();
  console.log(user, "User");
  useEffect(() => {
    console.log(user, "user", user?.restaurantId);
    if (user?.restaurantId) {
      fetch(`${apiConfig?.BASE_URL}/api/restaurants/${user?.restaurantId}/context`)
        .then(res => res.json())
        .then(data => {
          if (data.businessType === "FOOD_TRUCK") setBusinessType(true);
        });
    }
    else {
      console.log("loading...")
    }
  }, [user]);


  useEffect(() => {
    console.log(businessType, "businessType");
    if (businessType && !["LIVE", "SERVED", "PAY_LATER"].includes(activeFilter)) {
      setActiveFilter("LIVE");
    } else if (!businessType && !["All", "NEW", "ACCEPTED", "PREPARING", "READY", "SERVED", "PAY_LATER"].includes(activeFilter)) {
      setActiveFilter("All");
    }
  }, [businessType]);



  useEffect(() => {
    const handleCreated = (e) => {
      setOrders(prev => [e.detail, ...prev]);
    };

    const handleUpdated = (e) => {
      setOrders(prev =>
        prev.map(o =>
          o._id === e.detail._id ? e.detail : o
        )
      );
    };

    window.addEventListener("order_created", handleCreated);
    window.addEventListener("order_updated_local", handleUpdated);

    return () => {
      window.removeEventListener("order_created", handleCreated);
      window.removeEventListener("order_updated_local", handleUpdated);
    };
  }, []);

  useEffect(() => {
    if (!user?.restaurantId) return;

    const socket = getSocket(user.restaurantId);

    socket.on("new_order", (order) => {
      setOrders(prev => [order, ...prev]);
    });

    socket.on("order_updated", (updatedOrder) => {
      setOrders(prev =>
        prev.map(o =>
          o._id === updatedOrder._id ? updatedOrder : o
        )
      );
    });

    return () => {
      socket.off("new_order");
      socket.off("order_updated");
    };

  }, [user?.restaurantId]);


  const topSellingItems = useMemo(() => {
    const counts = {};

    // 1. Loop through all orders
    servedOrders.forEach(order => {
      // 2. Loop through items in each order
      order.items?.forEach(item => {
        const name = item.item?.branchName || item.name;
        const qty = item.quantity || 0;

        if (counts[name]) {
          counts[name].totalQty += qty;
          counts[name].revenue += (item.basePrice * qty);
        } else {
          counts[name] = {
            name: name,
            totalQty: qty,
            revenue: (item.basePrice * qty)
          };
        }
      });
    });

    // 3. Convert to array and sort by quantity descending
    return Object.values(counts)
      .sort((a, b) => b.totalQty - a.totalQty)
      .slice(0, 5); // Take top 5
  }, [servedOrders]);

  const fetchServedOrders = async () => {
    setLoading(true);

    try {
      const data = await apiFetch("/api/orders/served");

      setServedOrders(data?.orders || []);

    } catch (err) {
      console.error("Served Orders Error:", err.message);
      toast.error("Failed to fetch served orders");
    }

    setLoading(false);
  };

  useEffect(() => {
    console.log(orders, "orders")
  }, [orders])


  const fetchOrders = async () => {
    try {
      const data = await apiFetch("/api/admin/orders/live");

      if (Array.isArray(data)) {
        setOrders(data);
      }

    } catch (err) {
      console.error("Live Orders Error:", err.message);
    }
  };
const handlePayment = async (method) => {

  try {

    await collectPayment({
      orderId: paymentOrder._id,
      paymentMethod: method
    });

    setPaymentModal(false);
    setPaymentOrder(null);

    fetchOrders(); // refresh orders

  } catch (err) {

    console.error(err);

  }

};


  const confirmTableShift = async () => {
    if (!newTableValue ||
      (shiftingOrder && newTableValue === shiftingOrder.tableNumber)) {
      setShiftingOrder(null);
      return;
    }

    try {
      await apiFetch(`/api/admin/orders/${shiftingOrder._id}/shift`, {
        method: "PATCH",
        body: JSON.stringify({
          newTableNumber: newTableValue
        })
      });

      setShiftingOrder(null);
      setNewTableValue("");
      fetchOrders();

    } catch (err) {
      console.error("Shift Error:", err.message);
      toast.error(err.message || "Shift failed");
    }
  };
  const fetchPayLaterOrders = async () => {
    try {
      const data = await apiFetch("/api/admin/orders/pay-later");
      setPayLaterOrders(data?.orders || []);
    } catch (err) {
      console.error("Pay Later Error:", err.message);
      toast.error("Failed to fetch pay later orders");
    }
  };

  const clearPayLaterPayment = async (orderId, method) => {
    try {
      await apiFetch(`/api/admin/orders/${orderId}/clear-pay-later`, {
        method: "PATCH",
        body: JSON.stringify({ paymentMethod: method })
      });
      toast.success(`Payment collected via ${method}`);
      fetchOrders();
      if (activeFilter === "PAY_LATER") fetchPayLaterOrders();
    } catch (err) {
      toast.error(err.message || "Failed to collect payment");
    }
  };

  const handlePayLater = async (order, customerName, paidNow) => {
    try {
      const totalPrice = order.items?.reduce((sum, i) => sum + ((i.item?.branchPrice || i.basePrice || 0) * i.quantity), 0) || 0;
      const remaining = totalPrice - paidNow;
      await apiFetch(`/api/admin/orders/${order._id}/pay-later`, {
        method: "PATCH",
        body: JSON.stringify({
          customerName,
          paidNow,
          remaining
        })
      });
      toast.success("Order marked as Pay Later");
      fetchOrders();
      if (activeFilter === "PAY_LATER") fetchPayLaterOrders();
    } catch (err) {
      toast.error(err.message || "Failed to mark pay later");
    }
  };

  const promptPayLater = async (order) => {
    const totalPrice = order.items?.reduce((sum, i) => sum + ((i.item?.branchPrice || i.basePrice || 0) * i.quantity), 0) || 0;
    const { value: formValues } = await Swal.fire({
      title: 'Pay Later Setup',
      html:
        `<div class="flex flex-col gap-3 text-left">
          <label class="text-xs font-bold text-slate-500 uppercase">Customer Name</label>
          <input id="swal-input-name" class="swal2-input !m-0 !w-full" placeholder="Customer Name" value="${order.customerName || ''}">
          <label class="text-xs font-bold text-slate-500 uppercase mt-2">Paid Now (₹)</label>
          <input id="swal-input-paid" type="number" class="swal2-input !m-0 !w-full" placeholder="Amount Paid Now" value="0">
          <div class="text-xs text-slate-400 mt-1">Total Bill: ₹${totalPrice}</div>
        </div>`,
      focusConfirm: false,
      showCancelButton: true,
      confirmButtonColor: '#0F172A',
      cancelButtonColor: '#f1f5f9',
      confirmButtonText: 'Confirm Pay Later',
      preConfirm: () => {
        const name = document.getElementById('swal-input-name').value;
        const paid = parseFloat(document.getElementById('swal-input-paid').value) || 0;
        if (!name) {
          Swal.showValidationMessage('Customer Name is required');
          return false;
        }
        if (paid > totalPrice) {
          Swal.showValidationMessage('Paid amount cannot exceed total bill');
          return false;
        }
        return { name, paid };
      }
    });

    if (formValues) {
      await handlePayLater(order, formValues.name, formValues.paid);
    }
  };

  const promptSplitPayment = async (order) => {
    const totalPrice = order.items?.reduce((sum, i) => sum + ((i.item?.branchPrice || i.basePrice || 0) * i.quantity), 0) || 0;
    const { value: formValues } = await Swal.fire({
      title: 'Split Payment',
      html:
        `<div class="flex flex-col gap-3 text-left">
          <div class="text-sm font-bold text-slate-700">Total Bill: ₹${totalPrice}</div>
          <label class="text-xs font-bold text-slate-500 uppercase">Cash Amount (₹)</label>
          <input id="swal-input-cash" type="number" class="swal2-input !m-0 !w-full" placeholder="Cash Amount" value="0">
          <label class="text-xs font-bold text-slate-500 uppercase mt-2">UPI Amount (₹)</label>
          <input id="swal-input-upi" type="number" class="swal2-input !m-0 !w-full" placeholder="UPI Amount" value="0">
          <label class="text-xs font-bold text-slate-500 uppercase mt-2">Card Amount (₹)</label>
          <input id="swal-input-card" type="number" class="swal2-input !m-0 !w-full" placeholder="Card Amount" value="0">
        </div>`,
      focusConfirm: false,
      showCancelButton: true,
      confirmButtonColor: '#0F172A',
      cancelButtonColor: '#f1f5f9',
      confirmButtonText: 'Collect Payment',
      preConfirm: () => {
        const cash = parseFloat(document.getElementById('swal-input-cash').value) || 0;
        const upi = parseFloat(document.getElementById('swal-input-upi').value) || 0;
        const card = parseFloat(document.getElementById('swal-input-card').value) || 0;
        const sum = cash + upi + card;
        if (Math.abs(sum - totalPrice) > 0.01) {
          Swal.showValidationMessage(`Total split must equal the total bill of ₹${totalPrice} (current: ₹${sum})`);
          return false;
        }
        const payments = [];
        if (cash > 0) payments.push({ method: "CASH", amount: cash });
        if (upi > 0) payments.push({ method: "UPI", amount: upi });
        if (card > 0) payments.push({ method: "CARD", amount: card });
        return payments;
      }
    });

    if (formValues) {
      try {
        await apiFetch('/api/orders/split-payment', {
          method: "POST",
          body: JSON.stringify({
            orderId: order._id,
            payments: formValues
          })
        });
        toast.success("Split payment collected");
        fetchOrders();
      } catch (err) {
        toast.error(err.message || "Failed to split payment");
      }
    }
  };

  useEffect(() => {
    fetchOrders();
    if (activeFilter === "SERVED") fetchServedOrders();
    if (activeFilter === "PAY_LATER") fetchPayLaterOrders();
  }, [activeFilter]);



  const printOrderBill = async (orderId) => {
    try {
      const res = await fetch(
        `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/print-bill`,
        {
          method: "PATCH",
          credentials: "include",
        }
      );

      const data = await res.json();
      if (!res.ok) {
        toast.error(data.message);
        return;
      }

      const bill = data.bill;

      const printWindow = window.open("", "_blank", "width=400,height=600");

      printWindow.document.write(`
      <html>
        <head>
          <title>Receipt</title>
          <style>

            body{
              font-family: monospace;
              width:300px;
              margin:0 auto;
              padding:10px;
              color:#000;
            }

            .center{
              text-align:center;
            }

            .bold{
              font-weight:bold;
            }

            .line{
              border-bottom:1px dashed #000;
              margin:10px 0;
            }

            table{
              width:100%;
              border-collapse:collapse;
            }

            td{
              padding:4px 0;
              font-size:14px;
            }

            .right{
              text-align:right;
            }

            .qty{
              text-align:center;
            }

            .total{
              font-size:16px;
              font-weight:bold;
            }

            @media print {

              body{
                width:300px;
                margin:0;
              }

              @page{
                margin:0;
              }

            }

          </style>
        </head>

        <body>

          <div class="center">
            <h2 style="margin:0">${bill.restaurantName || "RESTAURANT"}</h2>
            <div>Table: ${bill.tableNumber || "-"}</div>
            <div style="font-size:12px">
              ${new Date().toLocaleString()}
            </div>
          </div>

          <div class="line"></div>

          <table>
            <thead>
              <tr class="bold">
                <td>Item</td>
                <td class="qty">Qty</td>
                <td class="right">Price</td>
              </tr>
            </thead>

            <tbody>
              ${bill.items
          .map(
            (i) => `
                <tr>
                  <td>${i.name}</td>
                  <td class="qty">${i.quantity}</td>
                  <td class="right">₹${(i.basePrice * i.quantity).toFixed(2)}</td>
                </tr>
              `
          )
          .join("")}
            </tbody>
          </table>

          <div class="line"></div>

          <div class="right">
            <div>Subtotal: ₹${bill.subTotal.toFixed(2)}</div>
            <div>GST (${bill.gstRate}%): ₹${bill.gstAmount.toFixed(2)}</div>
            <div class="total">TOTAL: ₹${bill.total.toFixed(2)}</div>
          </div>

          <div class="line"></div>

          <div class="center" style="font-size:12px">
            Thank You! Visit Again
          </div>

        </body>
      </html>
    `);

      printWindow.document.close();

      setTimeout(() => {
        printWindow.focus();
        printWindow.print();
        printWindow.close();
      }, 800);

    } catch (err) {
      console.error("PRINT ERROR:", err);
    }
  };
  const updateStatus = async (order, nextStatus) => {
    try {
      setStatusUpdating(order._id);

      console.log(order._id, nextStatus, "status");

      await apiFetch(`/api/admin/orders/${order._id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ status: nextStatus })
      });

      // 🔥 IF SERVED → PRINT BILL
      if (nextStatus === "SERVED") {
        await printOrderBill(order._id);
      }

      await fetchOrders();

    } catch (err) {
      console.error("Status Error:", err.message);
      toast.error(err.message || "Status update failed");
    } finally {
      setStatusUpdating(null);
    }
  };




  const statusConfig = {
    NEW: { label: "NEW", color: "text-blue-500", borderColor: "border-blue-100", bgColor: "bg-blue-50" },
    ACCEPTED: { label: "ACCEPTED", color: "text-blue-600", borderColor: "border-blue-200", bgColor: "bg-blue-50" },
    PREPARING: { label: "COOKING", color: "text-orange-500", borderColor: "border-orange-100", bgColor: "bg-orange-50" },
    READY: { label: "READY", color: "text-purple-600", borderColor: "border-purple-100", bgColor: "bg-purple-50" },
    SERVED: { label: "SERVED", color: "text-green-600", borderColor: "border-green-100", bgColor: "bg-green-50" },
  };

  const displayOrders = useMemo(() => {
    if (activeFilter === "SERVED") {
      return servedOrders;
    } else if (activeFilter === "PAY_LATER") {
      return payLaterOrders;
    } else if (activeFilter === "LIVE") {
      return orders.filter(o => o.status !== "SERVED" && o.paymentStatus !== "PAY_LATER");
    } else if (activeFilter === "All" || activeFilter === "ALL") {
      return orders;
    } else {
      return orders.filter(o => o.status === activeFilter);
    }
  }, [activeFilter, orders, servedOrders, payLaterOrders]);

  return (


    <div className="min-h-screen bg-[#FDFCF8] p-4 md:p-8 font-sans">

      <div className="max-w-7xl mx-auto">

        {/* HEADER */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-orange-500"></span>
              </span>
              <h1 className="text-2xl md:text-3xl font-black text-[#0F172A]">LIVE <span className="text-orange-600">ORDERS</span></h1>
            </div>
            <p className="text-slate-500 text-xs font-bold uppercase tracking-widest">Kitchen Command Center</p>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3">
            <div className="relative w-full sm:w-64">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input
                type="text"
                placeholder="Search name or table..."
                className="w-full pl-10 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-orange-500/20 transition-all"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            {businessType && (
              <button
                onClick={() => setOpenMenuModel(true)}
                className="flex items-center gap-2 px-5 py-2.5 bg-[#0F172A] text-white rounded-xl shadow-lg hover:bg-slate-800 transition-all"
              >
                <Plus size={18} />
                <span className="text-sm font-bold uppercase">Create Order</span>
              </button>
            )}
          </div>
        </div>
        {/* TOP SELLING SECTION */}




        {/* FILTERS */}
        <div className="flex items-center gap-2 overflow-x-auto pb-6 no-scrollbar">
          {(businessType
            ? ["LIVE", "SERVED", "PAY_LATER"]
            : ["All", "NEW", "ACCEPTED", "PREPARING", "READY", "SERVED", "PAY_LATER"]
          ).map((filter) => {
            let label = filter;
            if (filter === "PREPARING") label = "COOKING";
            else if (filter === "PAY_LATER") label = "PAY LATER";
            else if (filter === "All") label = "ALL";

            let count = 0;
            if (filter === "LIVE") {
              count = orders.filter(o => o.status !== "SERVED" && o.paymentStatus !== "PAY_LATER").length;
            } else if (filter === "All") {
              count = orders.length;
            } else if (filter === "SERVED") {
              count = servedOrders.length;
            } else if (filter === "PAY_LATER") {
              count = payLaterOrders.length;
            } else {
              count = orders.filter(o => o.status === filter).length;
            }

            return (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`flex-shrink-0 px-5 py-2 rounded-full text-[11px] font-black uppercase tracking-widest border transition-all ${activeFilter === filter
                  ? "bg-[#0F172A] text-white border-[#0F172A]"
                  : "bg-white text-slate-400 border-slate-200 hover:border-slate-300"
                  }`}
              >
                {label}
                <span className={`ml-2 px-1.5 py-0.5 rounded-md text-[9px] ${activeFilter === filter ? "bg-orange-500 text-white" : "bg-slate-100 text-slate-500"}`}>
                  {count}
                </span>
              </button>
            );
          })}
        </div>
        {activeFilter === "SERVED" && topSellingItems.length > 0 && (
          <div className="mb-10 bg-[#0F172A] rounded-[2.5rem] p-8 text-white shadow-2xl overflow-hidden relative">
            <div className="absolute top-0 right-0 p-10 opacity-10">
              <Trophy size={120} />
            </div>

            <div className="relative z-10">
              <h2 className="text-sm font-black uppercase tracking-[0.3em] text-slate-400 mb-6 flex items-center gap-2">
                <TrendingUp size={16} className="text-emerald-400" />
                Top Selling Items
              </h2>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {topSellingItems.map((item, index) => (
                  <div key={index} className="bg-white/5 border border-white/10 rounded-3xl p-5 flex items-center justify-between group hover:bg-white/10 transition-all">
                    <div>
                      <p className="text-[10px] font-black text-emerald-400 uppercase mb-1">Rank #{index + 1}</p>
                      <h4 className="text-sm font-black uppercase truncate max-w-[120px]">{item.name}</h4>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-black">{item.totalQty}</p>
                      <p className="text-[9px] font-bold text-slate-500 uppercase tracking-tighter">Sold</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
        {/* ORDER GRID */}
        {/* ORDER GRID */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {displayOrders.filter(order => order.status !== "CANCELLED").length > 0 ? (
            displayOrders
              .filter(order => order.status !== "CANCELLED")
              .map((order) => {
                const config = statusConfig[order.status?.toUpperCase()] || statusConfig.NEW;
                const totalPrice = order.items?.reduce((sum, i) => sum + ((i.item?.branchPrice || i.basePrice || 0) * i.quantity), 0) || 0;

                return (
                  <div key={order._id} className="bg-white rounded-[2.5rem] border border-slate-100 shadow-sm flex flex-col overflow-hidden hover:shadow-xl transition-all relative">
                    {/* ... [Rest of your existing Order Card JSX remains exactly same] ... */}
                    <div className="absolute right-6 top-6 flex gap-2">
                      <button onClick={() => setViewDetails(order)} className="p-1 hover:bg-slate-50 rounded-lg text-slate-300 transition-colors">
                        <User size={16} />
                      </button>
                      {!businessType && activeFilter !== "SERVED" && (
                        <button
                          onClick={() => { setShiftingOrder(order); setNewTableValue(order.tableNumber); }}
                          className="p-1 hover:bg-slate-50 rounded-lg text-slate-300 transition-colors"
                        >
                          <MoveRight size={16} />
                        </button>
                      )}
                    </div>

                    <div className="p-6">
                      <div className="flex justify-between items-start mb-4">
                        <div className={`flex items-center gap-1.5 px-3 py-1 rounded-full border ${config.bgColor} ${config.color} ${config.borderColor}`}>
                          <CheckCircle2 size={12} strokeWidth={3} />
                          <span className="text-[10px] font-black uppercase">{config.label}</span>
                        </div>
                        <span className="text-[10px] font-bold text-slate-300">#{order._id.slice(-4).toUpperCase()}</span>
                      </div>

                      {businessType ? (
                        <h3 className="text-xl font-black text-[#0F172A] truncate uppercase pr-14">{order.customerName || "NA"}</h3>
                      ) : (
                        <h3 className="text-xl font-black text-[#0F172A] truncate uppercase pr-14">{`Table ${order.tableNumber || "NA"}`}</h3>
                      )}

                      <div className="flex items-center gap-1.5 text-slate-400 mt-1">
                        <Clock size={12} />
                        <span className="text-[10px] font-bold">{new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                      </div>
                    </div>

                    <div className="px-6 py-5 bg-slate-50/50 flex-grow space-y-4 border-y border-slate-50">
                      {order.items?.map((item, idx) => (
                        <div key={idx} className="flex justify-between items-center">
                          <div className="flex items-center gap-3">
                            <div className="px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px] font-black text-[#0F172A]">{item.quantity}x</div>
                            <span className="text-[11px] font-bold text-slate-700 uppercase tracking-tight">{item.item?.branchName || item.name}</span>
                          </div>
                          <span className="text-[11px] font-bold text-slate-400">₹{(item.item?.branchPrice || item.basePrice || 0) * item.quantity}</span>
                        </div>
                      ))}
                    </div>

                    <div className="p-6">
                      {order?.paymentStatus === "PENDING" && businessType && (
                        <span className="text-[8px] font-black text-orange-400 uppercase">Payment Pending</span>
                      )}
                      {order?.paymentStatus === "PAY_LATER" && (
                        <span className="text-[8px] font-black text-amber-500 uppercase">Pay Later</span>
                      )}
                      <div className="flex justify-between items-center mb-5">
                        <span className="text-[10px] font-black text-slate-300 uppercase tracking-[0.2em]">Total Bill</span>
                        <span className="text-2xl font-black text-[#0F172A]">₹{totalPrice}</span>
                      </div>

                      {activeFilter !== "SERVED" && order.status !== "SERVED" && (
                        <div className="flex flex-col gap-3 w-full">
                          {order.paymentStatus === "PAY_LATER" ? (
                            <div className="flex flex-col gap-2 w-full">
                              <span className="text-[10px] font-black text-orange-600 uppercase tracking-widest mb-1">Collect Payment</span>
                              <div className="flex gap-2">
                                {["CASH", "UPI", "CARD"].map((method) => (
                                  <button
                                    key={method}
                                    onClick={() => clearPayLaterPayment(order._id, method)}
                                    className="flex-1 py-2.5 rounded-xl border border-amber-200 bg-amber-50 text-amber-700 text-xs font-black uppercase hover:bg-amber-100 transition-all"
                                  >
                                    {method}
                                  </button>
                                ))}
                              </div>
                            </div>
                          ) : businessType ? (
                            /* FOOD TRUCK Live orders */
                            <div className="flex flex-col gap-3 w-full">
                              <span className="text-[10px] font-black text-orange-600 uppercase tracking-widest">Collect Payment</span>
                              {/* Row 1: CASH, UPI, CARD */}
                              <div className="flex gap-2">
                                {["CASH", "UPI", "CARD"].map((method) => (
                                  <button
                                    key={method}
                                    onClick={() => collectPayment({ orderId: order._id, paymentMethod: method }).then(() => { toast.success(`Payment collected via ${method}`); printOrderBill(order._id); fetchOrders(); }).catch(err => toast.error(err.message))}
                                    className="flex-1 py-2 border border-slate-200 bg-slate-50 text-slate-700 text-xs font-black rounded-xl hover:bg-slate-100 transition-all"
                                  >
                                    {method}
                                  </button>
                                ))}
                              </div>
                              {/* Row 2: SPLIT */}
                              <button
                                onClick={() => promptSplitPayment(order)}
                                className="w-full py-2.5 border border-purple-200 bg-purple-50 text-purple-700 text-xs font-black rounded-xl hover:bg-purple-100 transition-all"
                              >
                                ✂ SPLIT
                              </button>
                              {/* Row 3: PAY LATER and CANCEL */}
                              <div className="flex gap-2">
                                <button
                                  onClick={() => promptPayLater(order)}
                                  className="flex-1 py-2.5 border border-amber-200 bg-amber-50 text-amber-700 text-xs font-black rounded-xl hover:bg-amber-100 transition-all"
                                >
                                  PAY LATER
                                </button>
                                <button
                                  onClick={async () => {
                                    const result = await Swal.fire({
                                      title: 'Are you sure?',
                                      text: "You won't be able to revert this!",
                                      icon: 'warning',
                                      showCancelButton: true,
                                      confirmButtonColor: '#0F172A',
                                      cancelButtonColor: '#f1f5f9',
                                      confirmButtonText: 'Yes, cancel it!',
                                      cancelButtonText: 'No, keep it',
                                    });

                                    if (result.isConfirmed) {
                                      try {
                                        await cancelOrder(order._id);
                                        toast.success("Order Cancelled!");
                                        fetchOrders();
                                      } catch (err) {
                                        toast.error("Failed to cancel order");
                                      }
                                    }
                                  }}
                                  className="flex-1 py-2.5 border border-red-200 bg-red-50 text-red-700 text-xs font-black rounded-xl hover:bg-red-100 transition-all"
                                >
                                  CANCEL
                                </button>
                              </div>
                            </div>
                          ) : (
                            /* RESTAURANT Live orders flow */
                            <div className="w-full">
                              {order.status === "NEW" && (
                                <div className="flex gap-3 w-full">
                                  <button
                                    onClick={async () => {
                                      const result = await Swal.fire({
                                        title: 'Are you sure?',
                                        text: "You won't be able to revert this!",
                                        icon: 'warning',
                                        showCancelButton: true,
                                        confirmButtonColor: '#0F172A',
                                        cancelButtonColor: '#f1f5f9',
                                        confirmButtonText: 'Yes, cancel it!',
                                        cancelButtonText: 'No, keep it',
                                      });

                                      if (result.isConfirmed) {
                                        try {
                                          await cancelOrder(order._id);
                                          toast.success("Order Cancelled!");
                                          fetchOrders();
                                        } catch (err) {
                                          toast.error("Failed to cancel order");
                                        }
                                      }
                                    }}
                                    className="flex-1 py-4 rounded-[1.25rem] font-black text-xs uppercase tracking-widest transition-all bg-slate-100 text-slate-400 hover:bg-red-50 hover:text-red-500 border border-slate-200/50"
                                  >
                                    Cancel
                                  </button>
                                  <button
                                    disabled={statusUpdating === order._id}
                                    onClick={() => updateStatus(order, "ACCEPTED")}
                                    className="flex-[2] py-4 bg-[#0F172A] text-white rounded-[1.25rem] font-black text-xs uppercase tracking-widest transition-all shadow-md active:scale-95 hover:bg-slate-800"
                                  >
                                    {statusUpdating === order._id ? "Updating..." : "ACCEPT"}
                                  </button>
                                </div>
                              )}

                              {order.status === "ACCEPTED" && (
                                <button
                                  disabled={statusUpdating === order._id}
                                  onClick={() => updateStatus(order, "PREPARING")}
                                  className="w-full py-4 bg-orange-500 text-white rounded-[1.25rem] font-black text-xs uppercase tracking-widest transition-all shadow-md active:scale-95 hover:bg-orange-600"
                                >
                                  {statusUpdating === order._id ? "Updating..." : "COOKING"}
                                </button>
                              )}

                              {order.status === "PREPARING" && (
                                <button
                                  disabled={statusUpdating === order._id}
                                  onClick={() => updateStatus(order, "READY")}
                                  className="w-full py-4 bg-[#0F172A] text-white rounded-[1.25rem] font-black text-xs uppercase tracking-widest transition-all shadow-md active:scale-95 hover:bg-slate-800"
                                >
                                  {statusUpdating === order._id ? "Updating..." : "READY"}
                                </button>
                              )}

                              {order.status === "READY" && (
                                <div className="flex flex-col gap-3 w-full">
                                  <span className="text-[10px] font-black text-orange-600 uppercase tracking-widest">Collect Payment</span>
                                  {/* Row 1: CASH, UPI, CARD */}
                                  <div className="flex gap-2">
                                    {["CASH", "UPI", "CARD"].map((method) => (
                                      <button
                                        key={method}
                                        onClick={() => collectPayment({ orderId: order._id, paymentMethod: method }).then(() => { toast.success(`Payment collected via ${method}`); printOrderBill(order._id); fetchOrders(); }).catch(err => toast.error(err.message))}
                                        className="flex-1 py-2 border border-emerald-200 bg-emerald-50 text-emerald-700 text-xs font-black rounded-xl hover:bg-emerald-100 transition-all"
                                      >
                                        {method}
                                      </button>
                                    ))}
                                  </div>
                                  {/* Row 2: PAY LATER and SPLIT */}
                                  <div className="flex gap-2">
                                    <button
                                      onClick={() => promptPayLater(order)}
                                      className="flex-1 py-2.5 border border-amber-200 bg-amber-50 text-amber-700 text-xs font-black rounded-xl hover:bg-amber-100 transition-all"
                                    >
                                      PAY LATER
                                    </button>
                                    <button
                                      onClick={() => promptSplitPayment(order)}
                                      className="flex-1 py-2.5 border border-purple-200 bg-purple-50 text-purple-700 text-xs font-black rounded-xl hover:bg-purple-100 transition-all"
                                    >
                                      ✂ SPLIT
                                    </button>
                                  </div>
                                </div>
                              )}
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                );
              })
          ) : (
            /* 🔥 EMPTY STATE - Only shows when not on "SERVED" filter */
            activeFilter !== "SERVED" && (
              <div className="col-span-full flex flex-col items-center justify-center py-20 animate-in fade-in duration-700">
                <div className="w-24 h-24 bg-orange-50 rounded-full flex items-center justify-center mb-6">
                  <UtensilsCrossed size={40} className="text-orange-200" />
                </div>
                <h3 className="text-xl font-black text-[#0F172A] uppercase tracking-tighter">No Active Orders</h3>
                <p className="text-slate-400 text-sm font-bold mt-2 max-w-xs text-center leading-relaxed">
                  {activeFilter === "All"
                    ? "Kitchen is quiet... Maybe the chef is taking a nap? 💤"
                    : `No orders currently in ${activeFilter} stage. 👨‍🍳`}
                </p>
              </div>
            )
          )}
        </div>
      </div>

      {/* SHIFT TABLE MODAL */}
      {shiftingOrder && (
        <div className="fixed inset-0 bg-[#0F172A]/40 backdrop-blur-md z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[3rem] p-10 w-full max-w-sm shadow-2xl scale-in-center">
            <h3 className="text-xl font-black text-[#0F172A] uppercase mb-1">Shift Table</h3>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-8">From Table {shiftingOrder.tableNumber} to:</p>
            <input
              type="text"
              autoFocus
              value={newTableValue}
              onChange={(e) => setNewTableValue(e.target.value)}
              className="w-full p-6 bg-slate-50 border-2 border-slate-100 rounded-3xl text-3xl font-black text-center focus:border-orange-500 outline-none transition-all mb-8"
              placeholder="00"
            />
            <div className="flex gap-4">
              <button onClick={() => setShiftingOrder(null)} className="flex-1 py-4 text-[11px] font-black uppercase text-slate-400">Cancel</button>
              <button onClick={confirmTableShift} className="flex-1 py-4 bg-[#0F172A] text-white rounded-2xl text-[11px] font-black uppercase tracking-widest">Confirm</button>
            </div>
          </div>
        </div>
      )}

      {/* CUSTOMER DETAILS MODAL */}
      {viewDetails && (
        <div className="fixed inset-0 bg-[#0F172A]/40 backdrop-blur-md z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-[3rem] p-10 w-full max-w-sm shadow-2xl relative">
            <button onClick={() => setViewDetails(null)} className="absolute right-8 top-8 text-slate-300 hover:text-slate-600 transition-colors"><XCircle size={28} /></button>
            <h3 className="text-xl font-black text-[#0F172A] uppercase mb-10">Customer Info</h3>
            <div className="space-y-6">
              <div className="flex items-center gap-5 p-5 bg-slate-50 rounded-[2rem]">
                <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center text-orange-500 shadow-sm"><User size={24} /></div>
                <div>
                  <p className="text-[10px] font-black text-slate-400 uppercase tracking-tighter">Name</p>
                  <p className="text-md font-black text-[#0F172A] uppercase">{viewDetails.customerName || "Walk-in Guest"}</p>
                </div>
              </div>
              <div className="flex items-center gap-5 p-5 bg-slate-50 rounded-[2rem]">
                <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center text-blue-500 shadow-sm"><Phone size={24} /></div>
                <div>
                  <p className="text-[10px] font-black text-slate-400 uppercase tracking-tighter">Phone</p>
                  <p className="text-md font-black text-[#0F172A]">{viewDetails.customerPhone || "Not Provided"}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {paymentModal && (
  <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">

    <div className="bg-white rounded-2xl p-6 w-80 space-y-4">

      <h3 className="font-black text-lg text-center">
        Collect Payment
      </h3>

      <button
        onClick={() => handlePayment("CASH")}
        className="w-full py-3 bg-slate-900 text-white rounded-xl font-bold"
      >
        CASH
      </button>

      <button
        onClick={() => handlePayment("UPI")}
        className="w-full py-3 bg-green-600 text-white rounded-xl font-bold"
      >
        UPI
      </button>

      <button
        onClick={() => handlePayment("CARD")}
        className="w-full py-3 bg-blue-600 text-white rounded-xl font-bold"
      >
        CARD
      </button>

      <button
        onClick={() => setPaymentModal(false)}
        className="w-full py-2 text-sm text-gray-500"
      >
        Cancel
      </button>

    </div>

  </div>
)}

      {openMenuModel && <MenuModal close={() => setOpenMenuModel(false)} />}
    </div>
  );
}