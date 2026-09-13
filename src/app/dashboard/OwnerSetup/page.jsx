"use client";
import { useEffect, useState } from "react";
import {
    Trash2,
    X,
    Armchair,
    Settings2,
    LayoutGrid,
    Printer,
    Plus,
    MoveHorizontal,
    Receipt,
    Clock,
    Zap,
} from "lucide-react";
import MenuModal from "../../components/MenuModal";
import SittingEditorModal from "../../components/EditTableModal";
import { useRouter } from "next/navigation";
import toast, { Toaster } from "react-hot-toast";
import { useAuth } from "@/app/context/AuthContext";
import apiConfig from "@/utils/apiConfig";

export const shiftOrderTable = async (orderId, newTableNumber) => {
    const res = await fetch(
        `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/shift`,
        {
            method: "PATCH",
            credentials: "include",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ newTableNumber }),
        },
    );
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Shift failed");
    return data;
};

// ── Skeleton card — mirrors the aspect-square table card ─────────────────────
const TableCardSkeleton = () => (
    <div className="aspect-square rounded-[1.5rem] bg-slate-100 animate-pulse" />
);

// ── One skeleton area row (header + 6 cards) ─────────────────────────────────
const AreaSkeleton = () => (
    <div>
        <div className="flex justify-between items-center mb-4 lg:mb-6">
            <div className="flex items-center gap-2 lg:gap-3">
                <div className="w-8 h-8 bg-slate-100 rounded-xl animate-pulse" />
                <div className="w-28 h-4 bg-slate-100 rounded-lg animate-pulse" />
            </div>
            <div className="w-20 h-8 bg-slate-100 rounded-xl animate-pulse" />
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 gap-3 lg:gap-6">
            {Array.from({ length: 6 }).map((_, i) => (
                <TableCardSkeleton key={i} />
            ))}
        </div>
    </div>
);

const SplitPaymentQuickModal = ({ total, onConfirm, onCancel, isLoading }) => {
    const [method1, setMethod1] = useState("CASH");
    const [method2, setMethod2] = useState("UPI");
    const [amount1, setAmount1] = useState("");
    const amount2 = amount1 !== "" ? Math.max(0, total - Number(amount1)) : "";
    const isValid = method1 !== method2 && amount1 !== "" && Number(amount1) > 0 && Number(amount1) < total;
    const METHODS = ["CASH", "UPI", "CARD"];

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[120] flex items-center justify-center p-4">
            <div className="bg-white rounded-[2rem] p-8 w-full max-w-sm shadow-2xl">
                <h3 className="text-xl font-black text-slate-900 mb-1">Split Payment</h3>
                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest mb-6">Total: ₹{total.toFixed(2)}</p>

                <p className="text-[10px] font-black text-slate-400 uppercase mb-2">First Method</p>
                <div className="flex gap-2 mb-4">
                    {METHODS.map(m => (
                        <button key={m} onClick={() => { setMethod1(m); if (m === method2) setMethod2(METHODS.find(x => x !== m)); }}
                            className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase border-2 ${method1 === m ? "bg-orange-50 border-orange-400 text-orange-600" : "bg-slate-50 border-slate-200 text-slate-400"}`}>
                            {m}
                        </button>
                    ))}
                </div>
                <input type="number" value={amount1} onChange={e => setAmount1(e.target.value)}
                    placeholder={`Amount by ${method1}...`} max={total - 1}
                    className="w-full p-4 bg-slate-50 border-2 border-slate-100 rounded-2xl text-lg font-black mb-4 focus:border-orange-400 outline-none" />

                <p className="text-[10px] font-black text-slate-400 uppercase mb-2">Second Method</p>
                <div className="flex gap-2 mb-4">
                    {METHODS.filter(m => m !== method1).map(m => (
                        <button key={m} onClick={() => setMethod2(m)}
                            className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase border-2 ${method2 === m ? "bg-orange-50 border-orange-400 text-orange-600" : "bg-slate-50 border-slate-200 text-slate-400"}`}>
                            {m}
                        </button>
                    ))}
                </div>

                {isValid && (
                    <div className="bg-slate-50 rounded-xl p-3 mb-4 text-xs font-bold text-slate-600 flex justify-between">
                        <span>{method1}: ₹{amount1}</span><span>{method2}: ₹{amount2}</span>
                    </div>
                )}

                <div className="flex gap-3">
                    <button onClick={onCancel} className="flex-1 py-3 text-slate-400 font-black text-[11px] uppercase">Cancel</button>
                    <button
                        onClick={() => onConfirm([{ method: method1, amount: Number(amount1) }, { method: method2, amount: Number(amount2) }])}
                        disabled={!isValid || isLoading}
                        className="flex-1 py-3 bg-violet-500 text-white rounded-xl font-black text-[11px] uppercase disabled:opacity-40"
                    >
                        {isLoading ? "Processing..." : "Confirm"}
                    </button>
                </div>
            </div>
        </div>
    );
};

const PayLaterFullModal = ({ onConfirm, onCancel, orderTotal = 0, isLoading }) => {
    const [name, setName] = useState("");
    const [partialMode, setPartialMode] = useState(false);
    const [paidNow, setPaidNow] = useState("");

    const remaining = orderTotal > 0 && paidNow
        ? Math.max(0, orderTotal - Number(paidNow))
        : null;

    const handleConfirm = () => {
        if (!name.trim()) return;
        onConfirm({
            customerName: name.trim(),
            paidNow: partialMode && paidNow ? Number(paidNow) : 0,
            remaining: partialMode && paidNow ? remaining : orderTotal,
        });
    };

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[120] flex items-center justify-center p-4">
            <div className="bg-white rounded-[2rem] p-8 w-full max-w-sm shadow-2xl">
                <div className="flex items-center gap-3 mb-2">
                    <div className="w-10 h-10 bg-amber-50 rounded-2xl flex items-center justify-center">
                        <span className="text-amber-500 text-lg">⚠</span>
                    </div>
                    <h3 className="text-xl font-black text-slate-900 uppercase">Pay Later</h3>
                </div>
                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest mb-6">
                    Enter customer name to track this order
                </p>

                {/* Name input */}
                <input
                    autoFocus
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && name.trim() && !partialMode && handleConfirm()}
                    placeholder="Customer name..."
                    className="w-full p-4 bg-slate-50 border-2 border-slate-100 rounded-2xl text-lg font-black text-center focus:border-amber-400 outline-none transition-all mb-4"
                />

                {/* Partial payment toggle */}
                {orderTotal > 0 && (
                    <button
                        onClick={() => { setPartialMode((v) => !v); setPaidNow(""); }}
                        className={`w-full py-3 rounded-2xl text-[10px] font-black uppercase tracking-widest transition-all mb-4 ${partialMode
                            ? "bg-amber-50 border-2 border-amber-300 text-amber-600"
                            : "bg-slate-50 border-2 border-slate-100 text-slate-400 hover:border-amber-200 hover:text-amber-500"
                            }`}
                    >
                        {partialMode ? "Partial payment ON" : "Paid something now? (optional)"}
                    </button>
                )}

                {/* Partial amount input */}
                {partialMode && (
                    <div className="mb-4 space-y-3">
                        <div className="relative">
                            <span className="absolute left-5 top-1/2 -translate-y-1/2 text-xl font-black text-slate-400">₹</span>
                            <input
                                type="number"
                                value={paidNow}
                                onChange={(e) => setPaidNow(e.target.value)}
                                placeholder="Amount paid now..."
                                max={orderTotal}
                                className="w-full pl-10 pr-5 py-4 bg-slate-50 border-2 border-slate-100 rounded-2xl text-xl font-black text-center focus:border-amber-400 outline-none transition-all"
                            />
                        </div>

                        {paidNow && Number(paidNow) > 0 && (
                            <div className="bg-amber-50 border border-amber-100 rounded-2xl p-4 space-y-2">
                                <div className="flex justify-between items-center">
                                    <span className="text-[10px] font-black text-slate-500 uppercase">Total bill</span>
                                    <span className="text-sm font-black text-slate-700">₹{orderTotal}</span>
                                </div>
                                <div className="flex justify-between items-center">
                                    <span className="text-[10px] font-black text-green-600 uppercase">Paid now</span>
                                    <span className="text-sm font-black text-green-600">- ₹{paidNow}</span>
                                </div>
                                <div className="border-t border-amber-200 pt-2 flex justify-between items-center">
                                    <span className="text-[10px] font-black text-amber-600 uppercase">Remaining</span>
                                    <span className="text-base font-black text-amber-600">₹{remaining}</span>
                                </div>
                            </div>
                        )}
                    </div>
                )}

                <div className="flex gap-4 mt-2">
                    <button onClick={onCancel} className="flex-1 py-3 text-[11px] font-black uppercase text-slate-400 hover:text-slate-600 transition-colors">
                        Cancel
                    </button>
                    <button
                        onClick={handleConfirm}
                        disabled={!name.trim() || isLoading || (partialMode && paidNow && Number(paidNow) >= orderTotal)}
                        className="flex-1 py-3 bg-amber-400 text-slate-900 rounded-2xl text-[11px] font-black uppercase tracking-widest disabled:opacity-40 hover:bg-amber-500 transition-all"
                    >
                        {isLoading ? "Saving..." : "Confirm"}
                    </button>
                </div>
            </div>
        </div>
    );
};

const formatTableLabel = (table) => {
    const areaName = (table.areaName || "").toString();
    const tableName = (table.tableName || "").toString();
    const displayLabel = (table.displayLabel || "").toString();
    
    let label = displayLabel || tableName;
    
    let cleanArea = areaName.trim().replace(/\s+/g, '');
    if (cleanArea.endsWith('-')) {
        cleanArea = cleanArea.slice(0, -1).trim();
    }
    
    let cleanLabel = label.trim().replace(/\s+/g, '');
    
    if (cleanLabel.toLowerCase().startsWith(cleanArea.toLowerCase())) {
        if (cleanLabel.includes('-') || cleanLabel.toLowerCase() === cleanArea.toLowerCase()) {
            return cleanLabel.toLowerCase();
        } else {
            const suffix = cleanLabel.slice(cleanArea.length);
            return `${cleanArea}-${suffix}`.toLowerCase();
        }
    }
    
    return `${cleanArea}-${cleanLabel}`.toLowerCase();
};

export default function PosPage() {
    const [areas, setAreas] = useState({});
    const [selectedTable, setSelectedTable] = useState(null);
    const [editSittingArea, setEditSittingArea] = useState(null);
    const [loading, setLoading] = useState(true);
    const { user } = useAuth();

    // ── Printer settings ──────────────────────────────────────────────────
    const [autoPrintKOT, setAutoPrintKOT] = useState(false);
    const [autoPrintBill, setAutoPrintBill] = useState(false);
    const [printerSaving, setPrinterSaving] = useState(false);
    const [printerModalOpen, setPrinterModalOpen] = useState(false);

    // ── Shift States ──────────────────────────────────────────────────────
    const [shiftData, setShiftData] = useState(null);
    const [newTableNumInput, setNewTableNumInput] = useState("");
    const [sendAppendOrder, setSendAppendOrder] = useState(null);
    const [showMergeConfirm, setShowMergeConfirm] = useState(false);
    // ── Pay Later / Split States ──────────────────────────────────────────
    const [payLaterOpen, setPayLaterOpen] = useState(false);
    const [splitOpen, setSplitOpen] = useState(false);
    const [payLaterLoading, setPayLaterLoading] = useState(false);
    const [splitLoading, setSplitLoading] = useState(false);
    // ── Bill Preview States ───────────────────────────────────────────────
    const [billPreview, setBillPreview] = useState(null);
    const [billLoading, setBillLoading] = useState(false);
    const [selectedPaymentMethod, setSelectedPaymentMethod] = useState(null);
    const [finalizingBill, setFinalizingBill] = useState(false);

    // ── Discount States ──────────────────────────────────────────────────
    const [discountType, setDiscountType] = useState("NONE");   // "NONE" | "PERCENTAGE" | "FIXED"
    const [discountValue, setDiscountValue] = useState("");

    // ── Live orders ───────────────────────────────────────────────────────
    const [orderByTable, setOrderByTable] = useState({});

    const router = useRouter();

    // ── Seed printer toggles from user context ────────────────────────────
    useEffect(() => {
        if (!user) return;
        setAutoPrintKOT(user.autoPrintKOT || false);
        setAutoPrintBill(user.autoPrintBill || false);
    }, [user]);

    useEffect(() => {
        fetchTables();
        fetchLiveOrders();
    }, []);

    // ── Toggle a printer setting and auto-save immediately ────────────────
    const handleTogglePrinter = async (setting) => {
        const nextKOT = setting === "autoPrintKOT" ? !autoPrintKOT : autoPrintKOT;
        const nextBill = setting === "autoPrintBill" ? !autoPrintBill : autoPrintBill;

        // Optimistic UI
        if (setting === "autoPrintKOT") setAutoPrintKOT(nextKOT);
        else setAutoPrintBill(nextBill);

        try {
            setPrinterSaving(true);
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/auth/update-printer-settings`,
                {
                    method: "PATCH",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        autoPrintKOT: nextKOT,
                        autoPrintBill: nextBill,
                    }),
                },
            );
            if (!res.ok) throw new Error("Save failed");
            toast.success(
                `${setting === "autoPrintKOT" ? "Auto KOT" : "Auto Bill"} ${setting === "autoPrintKOT" ? (nextKOT ? "on" : "off") : (nextBill ? "on" : "off")}`,
                { duration: 1500 },
            );
        } catch {
            // Revert on error
            if (setting === "autoPrintKOT") setAutoPrintKOT(!nextKOT);
            else setAutoPrintBill(!nextBill);
            toast.error("Could not save printer settings");
        } finally {
            setPrinterSaving(false);
        }
    };

    const handlePayLater = async ({ customerName, paidNow, remaining }) => {
        const orderId = billPreview?.table?.currentOrderId;
        if (!orderId) return;
        try {
            setPayLaterLoading(true);
            const res = await fetch(`${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/pay-later`, {
                method: "PATCH",
                credentials: "include",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ customerName, paidNow, remaining }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.message || "Failed");
            toast.success(
                paidNow > 0
                    ? `₹${paidNow} collected · ₹${remaining} pending for ${customerName}`
                    : `Pay Later saved for ${customerName}`
            );
            setPayLaterOpen(false);
            setBillPreview(null);
            fetchTables();
        } catch (err) {
            toast.error(err.message || "Failed to save");
        } finally {
            setPayLaterLoading(false);
        }
    };

    const handleSplitPayment = async (payments) => {
        const orderId = billPreview?.table?.currentOrderId;
        if (!orderId) return;
        try {
            setSplitLoading(true);
            const res = await fetch(`${apiConfig?.BASE_URL}/api/orders/split-payment`, {
                method: "POST",
                credentials: "include",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ orderId, payments }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.message || "Split payment failed");
            toast.success("Split payment collected ✓");
            setSplitOpen(false);
            setBillPreview(null);
            fetchTables();
        } catch (err) {
            toast.error(err.message || "Failed");
        } finally {
            setSplitLoading(false);
        }
    };

    const fetchLiveOrders = async () => {
        try {
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/admin/orders/live?t=${Date.now()}`,
                { credentials: "include", cache: "no-cache" },
            );
            const data = await res.json();
            if (Array.isArray(data)) {
                const map = {};
                data.forEach((order) => {
                    if (order.tableNumber) map[String(order.tableNumber)] = order;
                });
                setOrderByTable(map);
            }
        } catch (err) {
            console.error("Failed to fetch live orders", err);
        }
    };

    const getTableTotal = (table) => {
        const order = orderByTable[String(table.tableName)];
        if (!order?.items?.length) return 0;
        return order.items.reduce(
            (sum, i) => sum + ((i.item?.branchPrice || i.basePrice || 0) * i.quantity),
            0,
        );
    };

    const getMinutesAgo = (table) => {
        const order = orderByTable[String(table.tableName)];
        if (!order?.createdAt) return null;
        const diffMs = Date.now() - new Date(order.createdAt).getTime();
        return Math.max(0, Math.floor(diffMs / 60000));
    };

    const fetchTables = async () => {
        try {
            setLoading(true);
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/pos/tables?t=${Date.now()}`,
                { credentials: "include", cache: "no-cache" },
            );
            const data = await res.json();

            if (Array.isArray(data)) {
                const grouped = data.reduce((acc, table) => {
                    const area = table.areaName ? table.areaName.trim() : "Unassigned";
                    acc[area] = acc[area] || [];
                    acc[area].push(table);
                    return acc;
                }, {});
                Object.keys(grouped).forEach((area) => {
                    grouped[area].sort((a, b) => Number(a.tableName) - Number(b.tableName));
                });
                setAreas(grouped);
            }
            fetchLiveOrders();
        } catch (err) {
            console.error("Failed to fetch tables", err);
        } finally {
            setLoading(false);
        }
    };

    const handleShiftConfirm = async (mergeConfirmed = false) => {
        if (!newTableNumInput) return alert("Please enter a new table number");
        try {
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/admin/orders/${shiftData.orderId}/shift`,
                {
                    method: "PATCH",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ newTableNumber: newTableNumInput, mergeConfirmed }),
                },
            );
            const data = await res.json();
            if (res.status === 409 && data.requiresMerge) { setShowMergeConfirm(true); return; }
            if (!res.ok) { alert(data.message || "Shift failed"); return; }
            setShiftData(null);
            setNewTableNumInput("");
            setShowMergeConfirm(false);
            fetchTables();
            alert(data.merged ? "Tables merged successfully!" : "Table shifted successfully");
        } catch (err) {
            alert(err.message);
        }
    };

    const getDiscountedBill = () => {
        const total = billPreview?.bill?.total || 0;
        const value = Number(discountValue) || 0;

        if (discountType === "NONE" || value <= 0) {
            return { discountAmount: 0, finalAmount: +total.toFixed(2), error: null };
        }

        if (discountType === "PERCENTAGE") {
            if (value > 100) {
                return { discountAmount: 0, finalAmount: +total.toFixed(2), error: "Cannot exceed 100%" };
            }
            const amount = +((total * value) / 100).toFixed(2);
            return { discountAmount: amount, finalAmount: +(total - amount).toFixed(2), error: null };
        }

        if (discountType === "FIXED") {
            if (value > total) {
                return { discountAmount: 0, finalAmount: +total.toFixed(2), error: "Cannot exceed bill amount" };
            }
            return { discountAmount: +value.toFixed(2), finalAmount: +(total - value).toFixed(2), error: null };
        }

        return { discountAmount: 0, finalAmount: +total.toFixed(2), error: null };
    };

    const handleShowBillPreview = async (e, table) => {
        e.stopPropagation();
        const orderId = table?.currentOrderId;
        if (!orderId) { alert("No active order found"); return; }
        try {
            setBillLoading(true);
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/bill-preview`,
                { method: "GET", credentials: "include" },
            );
            const data = await res.json();
            if (!res.ok) { alert(data.message); return; }
            setSelectedPaymentMethod(null);
            setDiscountType("NONE");
            setDiscountValue("");
            setBillPreview({ bill: data.bill, table });
        } catch (err) {
            console.error("BILL FETCH ERROR:", err);
            alert("Failed to load bill");
        } finally {
            setBillLoading(false);
        }
    };

    const handlePrintBill = (bill) => {
        if (!bill) return;
        const html = `
        <html><head><style>
            body{font-family:monospace;width:300px;margin:0 auto;padding:10px}
            .center{text-align:center}.line{border-bottom:1px dashed #000;margin:10px 0}
            table{width:100%;border-collapse:collapse}td{padding:4px 0;font-size:14px}
            .right{text-align:right}.qty{text-align:center}.total{font-weight:bold;font-size:16px}
            @media print{@page{margin:0}}
        </style></head><body>
            <div class="center"><h2>${bill.restaurantName || "RESTAURANT"}</h2>
            ${bill.gstNumber ? `<div>GSTIN: ${bill.gstNumber}</div>` : ""}
            <div>Table: ${bill.tableNumber}</div><div>${new Date().toLocaleString()}</div>
            </div><div class="line"></div>
            <table><tr><td><b>Item</b></td><td class="qty"><b>Qty</b></td><td class="right"><b>Price</b></td></tr>
            ${bill.items.map(i => `<tr><td>${i.name}</td><td class="qty">${i.quantity}</td><td class="right">₹${(i.basePrice * i.quantity).toFixed(2)}</td></tr>`).join("")}
            </table><div class="line"></div>
            <div class="right">
          <div>GST (${bill.gstRate}%): ₹${bill.gstAmount.toFixed(2)}</div>
${bill.discountAmount > 0 ? `<div>Discount: - ₹${bill.discountAmount.toFixed(2)}</div>` : ""}
<div class="total">TOTAL: ₹${(bill.finalAmount ?? bill.total).toFixed(2)}</div>
</div>
            </div><div class="line"></div>
            <div class="center">Thank You! Visit Again</div>
        </body></html>`;
        const iframe = document.createElement("iframe");
        iframe.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0";
        document.body.appendChild(iframe);
        const doc = iframe.contentWindow.document;
        doc.open(); doc.write(html); doc.close();
        iframe.onload = () => {
            iframe.contentWindow.focus();
            iframe.contentWindow.print();
            setTimeout(() => document.body.removeChild(iframe), 1000);
        };
        setBillPreview(null);
        fetchTables();
    };

    const finalizeBillWithPayment = async () => {
        const orderId = billPreview?.table?.currentOrderId;
        if (!orderId) { toast.error("No active order found"); return; }
        if (!selectedPaymentMethod) { toast.error("Please select a payment method first"); return; }

        const { error } = getDiscountedBill();
        if (error) { toast.error(error); return; }

        try {
            setFinalizingBill(true);
            const paymentRes = await fetch(
                `${apiConfig?.BASE_URL}/api/admin/orders/collect-payment`,
                {
                    method: "PATCH", credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        orderId,
                        paymentMethod: selectedPaymentMethod,
                        discountType,
                        discountValue: Number(discountValue) || 0,
                    }),
                },
            );
            const paymentData = await paymentRes.json();
            if (!paymentRes.ok) throw new Error(paymentData.message || "Payment update failed");

            const printRes = await fetch(
                `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/print-bill`,
                { method: "PATCH", credentials: "include" },
            );
            const printData = await printRes.json();
            if (!printRes.ok) throw new Error(printData.message || "Failed to print bill");

            if (user?.autoPrintBill) {
                handlePrintBill(printData.bill);
            } else {
                setBillPreview(null);
                fetchTables();
            }
            toast.success(`Served & paid via ${selectedPaymentMethod}`);
            setSelectedPaymentMethod(null);
            setDiscountType("NONE");
            setDiscountValue("");
        } catch (err) {
            toast.error(err.message || "Failed to finalize bill");
        } finally {
            setFinalizingBill(false);
        }
    };

    const handleDeleteIndividualTable = async (tableId) => {
        if (!confirm("Are you sure you want to delete this table?")) return;
        try {
            const res = await fetch(`${apiConfig?.BASE_URL}/api/pos/tables/${tableId}`, {
                method: "DELETE", credentials: "include",
            });
            if (res.ok) fetchTables();
        } catch (err) {
            console.error("Delete failed", err);
        }
    };

    const handleTableClick = (table) => {
        if (table.status === "Running") {
            handleShowBillPreview({ stopPropagation: () => {} }, table);
            return;
        }
        setSelectedTable(table);
    };

    const handleAppendOrder = (table) => setSendAppendOrder(table);

    return (
        <div className="p-4 lg:p-10 bg-[#F8FAFB] min-h-screen transition-all duration-300">
            <Toaster position="top-right" />

            {/* ── Header ─────────────────────────────────────────────────────── */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-5 lg:mb-8 gap-3">
                <div>
                    <h1 className="text-xl lg:text-3xl font-black text-slate-900 tracking-tight">
                        Table Management
                    </h1>
                    <p className="text-slate-500 font-medium text-xs lg:text-sm">
                        Monitor and manage your floor layout in real-time.
                    </p>
                </div>
                <div className="flex items-center gap-2">
                    {/* Printer settings icon button */}
                    <button
                        onClick={() => setPrinterModalOpen(true)}
                        className={`relative p-2.5 lg:p-3 rounded-2xl border transition-all shadow-sm ${autoPrintKOT || autoPrintBill
                            ? "bg-emerald-50 border-emerald-200 text-emerald-600"
                            : "bg-white border-slate-200 text-slate-500 hover:border-[#FF5C00] hover:text-[#FF5C00]"
                            }`}
                        title="Printer Settings"
                    >
                        <Printer size={18} />
                        {/* Live dot — shows how many are ON */}
                        {(autoPrintKOT || autoPrintBill) && (
                            <span className="absolute -top-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full flex items-center justify-center text-white text-[8px] font-black">
                                {[autoPrintKOT, autoPrintBill].filter(Boolean).length}
                            </span>
                        )}
                    </button>
                    <button
                        onClick={() => router.push("/dashboard/pos")}
                        className="flex items-center gap-2 bg-[#FF5C00] text-white px-4 py-2.5 lg:px-6 lg:py-3 rounded-2xl font-bold text-xs shadow-lg shadow-orange-200 hover:bg-[#e65200] transition-all active:scale-95"
                    >
                        <Plus size={16} />
                        ADD NEW TABLES
                    </button>
                </div>
            </div>

            {/* ── Table Areas ────────────────────────────────────────────────── */}
            <div className="space-y-12">
                {loading ? (
                    // Skeleton: two placeholder area rows
                    <>
                        <AreaSkeleton />
                        <AreaSkeleton />
                    </>
                ) : (
                    Object.keys(areas).map((areaName) => (
                        <div key={areaName} className="relative">
                            <div className="flex justify-between items-center mb-4 lg:mb-6">
                                <div className="flex items-center gap-2 lg:gap-3">
                                    <div className="p-1.5 lg:p-2 bg-white rounded-xl shadow-sm border border-slate-100">
                                        <LayoutGrid size={16} className="text-slate-400" />
                                    </div>
                                    <h2 className="font-black text-slate-800 uppercase text-xs lg:text-sm tracking-widest">
                                        {areaName}{" "}
                                        <span className="text-slate-400 ml-1">({areas[areaName].length})</span>
                                    </h2>
                                </div>
                                <button
                                    onClick={() => setEditSittingArea({ name: areaName, count: areas[areaName].length })}
                                    className="flex items-center gap-1.5 text-[10px] font-black text-slate-500 bg-white border border-slate-200 px-3 py-2 rounded-xl hover:border-[#FF5C00] hover:text-[#FF5C00] transition-all shadow-sm"
                                >
                                    <Settings2 size={12} />
                                    ADJUST
                                </button>
                            </div>

                            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 gap-3 lg:gap-6">
                                {areas[areaName].map((table) => (
                                    <div key={table._id} className="relative group">
                                        <button
                                            onClick={() => handleTableClick(table)}
                                            className={`w-full aspect-square rounded-[1.5rem] flex flex-col items-center justify-center gap-1 lg:gap-2 transition-all duration-300 relative overflow-hidden
                                                    ${table.status === "Running"
                                                    ? "bg-[#FF5C00] text-white shadow-xl shadow-orange-200 ring-4 ring-orange-100"
                                                    : "bg-white text-slate-800 border-2 border-slate-100 hover:border-[#FF5C00] hover:shadow-lg shadow-sm"
                                                }`}
                                        >
                                            {table.status === "Running" && getMinutesAgo(table) !== null && (
                                                <span className="absolute top-2 left-2 text-[8px] lg:text-[9px] font-black uppercase tracking-widest bg-black/15 px-2 py-0.5 rounded-full">
                                                    {getMinutesAgo(table)} Min
                                                </span>
                                            )}
                                            <Armchair
                                                size={18}
                                                className={`${table.status === "Running" ? "text-white/40" : "text-slate-200"}`}
                                            />
                                            <span className="text-lg lg:text-xl font-black tracking-tighter">
                                                {formatTableLabel(table)}
                                            </span>
                                            {table.status === "Running" ? (
                                                <span className="text-sm lg:text-base font-black tracking-tight">
                                                    ₹{getTableTotal(table).toFixed(2)}
                                                </span>
                                            ) : (
                                                <span className="text-[9px] lg:text-[10px] font-black uppercase tracking-widest px-2 py-0.5 rounded-full bg-slate-50 text-slate-400">
                                                    Vacant
                                                </span>
                                            )}
                                        </button>

                                        {/* Running table actions */}
                                        {table.status === "Running" && (
                                            <>
                                                {/* Mobile: row below card */}
                                                <div className="flex sm:hidden justify-center gap-2 mt-2">
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); handleAppendOrder(table); }}
                                                        className="bg-green-500 text-white p-2 rounded-xl shadow-sm"
                                                        title="Add Items"
                                                    >
                                                        <Plus size={13} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => handleShowBillPreview(e, table)}
                                                        className="bg-[#FF5C00] text-white p-2 rounded-xl"
                                                        title="View Bill"
                                                    >
                                                        <Printer size={13} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => {
                                                            e.stopPropagation();
                                                            setShiftData({ orderId: table.currentOrderId, currentTable: table.tableName });
                                                        }}
                                                        className="bg-blue-500 text-white p-2 rounded-xl"
                                                    >
                                                        <MoveHorizontal size={13} />
                                                    </button>
                                                </div>

                                                {/* Desktop: overlay column */}
                                                <div className="hidden sm:flex absolute top-2 right-2 flex-col gap-2">
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); handleAppendOrder(table); }}
                                                        className="bg-white/20 hover:bg-white text-white hover:text-green-600 p-2 rounded-full transition-all shadow-sm"
                                                        title="Add Items"
                                                    >
                                                        <Plus size={14} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => handleShowBillPreview(e, table)}
                                                        className="bg-white/20 hover:bg-white text-white hover:text-[#FF5C00] p-2 rounded-full transition-all"
                                                        title="View Bill"
                                                    >
                                                        <Printer size={14} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => {
                                                            e.stopPropagation();
                                                            setShiftData({ orderId: table.currentOrderId, currentTable: table.tableName });
                                                        }}
                                                        className="bg-white/20 hover:bg-white text-white hover:text-blue-500 p-2 rounded-full transition-all"
                                                    >
                                                        <MoveHorizontal size={14} />
                                                    </button>
                                                </div>
                                            </>
                                        )}

                                        {/* Delete (Vacant only) */}
                                        {table.status !== "Running" && (
                                            <button
                                                onClick={(e) => { e.stopPropagation(); handleDeleteIndividualTable(table._id); }}
                                                className="absolute -top-1 -right-1 bg-white text-red-500 p-2 rounded-full opacity-0 group-hover:opacity-100 transition-all shadow-md border"
                                            >
                                                <Trash2 size={12} />
                                            </button>
                                        )}
                                    </div>
                                ))}
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* ── Modals ─────────────────────────────────────────────────────── */}

            {/* Shift Table Modal */}
            {shiftData && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
                    <div className="bg-white rounded-[2rem] p-8 w-full max-w-sm shadow-2xl">
                        {!showMergeConfirm ? (
                            <>
                                <div className="flex justify-between items-center mb-6">
                                    <h3 className="text-xl font-black text-slate-900">Shift Table</h3>
                                    <button onClick={() => { setShiftData(null); setShowMergeConfirm(false); }} className="text-slate-400 hover:text-slate-600">
                                        <X size={20} />
                                    </button>
                                </div>
                                <p className="text-sm text-slate-500 mb-4">
                                    Moving order from <b>Table {shiftData.currentTable}</b> to:
                                </p>
                                <input
                                    type="text"
                                    placeholder="New table number..."
                                    className="w-full bg-slate-50 border-2 border-slate-100 rounded-xl px-4 py-3 mb-4 focus:border-[#FF5C00] outline-none font-bold"
                                    value={newTableNumInput}
                                    onChange={(e) => setNewTableNumInput(e.target.value)}
                                />
                                <button
                                    onClick={() => handleShiftConfirm(false)}
                                    className="w-full bg-[#FF5C00] text-white py-3 rounded-xl font-bold hover:bg-[#e65200] transition-all"
                                >
                                    CONFIRM SHIFT
                                </button>
                            </>
                        ) : (
                            <>
                                <div className="flex flex-col items-center text-center mb-6">
                                    <div className="w-16 h-16 bg-amber-50 rounded-full flex items-center justify-center mb-4">
                                        <MoveHorizontal size={28} className="text-amber-500" />
                                    </div>
                                    <h3 className="text-xl font-black text-slate-900">Table Already Occupied!</h3>
                                    <p className="text-sm text-slate-500 mt-2 leading-relaxed">
                                        Table <b>{newTableNumInput}</b> is currently running.<br />
                                        Do you want to <span className="text-[#FF5C00] font-bold">merge</span> Table{" "}
                                        <b>{shiftData.currentTable}</b> into Table <b>{newTableNumInput}</b>?
                                    </p>
                                </div>
                                <div className="bg-slate-50 rounded-2xl p-4 mb-6 space-y-2">
                                    {[
                                        `All items from Table ${shiftData.currentTable} will move to Table ${newTableNumInput}`,
                                        "Bills will be combined into one",
                                        `Table ${shiftData.currentTable} will become vacant`,
                                    ].map((msg, i) => (
                                        <div key={i} className="flex items-center gap-2 text-xs font-bold text-slate-600">
                                            <div className="w-1.5 h-1.5 rounded-full bg-[#FF5C00] shrink-0" />
                                            {msg}
                                        </div>
                                    ))}
                                </div>
                                <div className="flex gap-3">
                                    <button
                                        onClick={() => { setShowMergeConfirm(false); setShiftData(null); setNewTableNumInput(""); }}
                                        className="flex-1 py-3 bg-slate-100 text-slate-600 rounded-xl font-bold text-sm hover:bg-slate-200 transition-all"
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        onClick={() => handleShiftConfirm(true)}
                                        className="flex-1 py-3 bg-[#FF5C00] text-white rounded-xl font-bold text-sm hover:bg-[#e65200] transition-all shadow-lg shadow-orange-200"
                                    >
                                        Yes, Merge!
                                    </button>
                                </div>
                            </>
                        )}
                    </div>
                </div>
            )}

            {/* Bill Preview Modal */}
            {billPreview && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
                    <div className="bg-white rounded-[2rem] w-full max-w-sm shadow-2xl flex flex-col max-h-[85vh] overflow-hidden">

                        {/* HEADER — fixed */}
                        <div className="flex justify-between items-center px-6 pt-6 pb-4 border-b border-slate-100 shrink-0">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 bg-orange-50 rounded-2xl flex items-center justify-center">
                                    <Receipt size={20} className="text-[#FF5C00]" />
                                </div>
                                <div>
                                    <h3 className="text-lg font-black text-slate-900 leading-none">
                                        Table {billPreview.bill.tableNumber || billPreview.table?.tableName}
                                    </h3>
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-1">
                                        Bill Summary
                                    </p>
                                </div>
                            </div>
                            <button
                                onClick={() => setBillPreview(null)}
                                className="text-slate-400 hover:text-slate-600 transition-colors p-1"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* ITEMS LIST — scrollable */}
                        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">
                            {billPreview.bill.items && billPreview.bill.items.map((item, idx) => (
                                <div key={idx} className="flex justify-between items-center text-sm font-bold text-slate-700">
                                    <div className="flex items-center gap-3">
                                        <span className="text-[10px] font-black px-2 py-1 bg-slate-50 border border-slate-100 rounded-lg text-slate-500">
                                            {item.quantity}x
                                        </span>
                                        <span className="text-slate-800 font-extrabold">{item.name}</span>
                                    </div>
                                    <span className="text-slate-900 font-black">₹{(item.basePrice * item.quantity).toFixed(2)}</span>
                                </div>
                            ))}
                        </div>

                        {(() => {
                            const { discountAmount, finalAmount } = getDiscountedBill();
                            return (
                                <>
                                    {/* BILL TOTALS — fixed */}
                                    <div className="px-6 py-4 bg-slate-50/50 border-t border-b border-slate-100 shrink-0 space-y-2">
                                        <div className="flex justify-between text-xs font-bold text-slate-400">
                                            <span>Subtotal</span>
                                            <span>₹{(billPreview.bill.subTotal || 0).toFixed(2)}</span>
                                        </div>
                                        <div className="flex justify-between text-xs font-bold text-slate-400">
                                            <span>GST ({billPreview.bill.gstRate}%)</span>
                                            <span>₹{(billPreview.bill.gstAmount || 0).toFixed(2)}</span>
                                        </div>
                                        {discountAmount > 0 && (
                                            <div className="flex justify-between text-xs font-bold text-green-600">
                                                <span>Discount ({discountType === "PERCENTAGE" ? `${discountValue}%` : "Fixed"})</span>
                                                <span>- ₹{discountAmount.toFixed(2)}</span>
                                            </div>
                                        )}
                                        <div className="flex justify-between items-center pt-2 border-t border-slate-100">
                                            <span className="text-xs font-black text-slate-900 uppercase tracking-widest">TOTAL</span>
                                            <span className="text-2xl font-black text-[#FF5C00]">₹{finalAmount.toFixed(2)}</span>
                                        </div>
                                    </div>

                                    {/* ACTIONS / CONTROLS — fixed */}
                                    <div className="p-6 shrink-0 space-y-5">
                                        {/* DISCOUNT SECTION */}
                                        <div>
                                            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2.5">
                                                Apply Discount
                                            </p>
                                            <div className="flex gap-2">
                                                <button
                                                    onClick={() => {
                                                        if (discountType === "PERCENTAGE") {
                                                            setDiscountType("NONE");
                                                            setDiscountValue("");
                                                        } else {
                                                            setDiscountType("PERCENTAGE");
                                                            setDiscountValue("");
                                                        }
                                                    }}
                                                    className={`flex-1 py-2.5 rounded-xl text-[10px] font-black uppercase border-2 transition-all ${
                                                        discountType === "PERCENTAGE"
                                                            ? "bg-orange-50 border-[#FF5C00] text-[#FF5C00]"
                                                            : "bg-white border-slate-100 text-slate-400 hover:border-slate-200"
                                                    }`}
                                                >
                                                    PERCENTAGE (%)
                                                </button>
                                                <button
                                                    onClick={() => {
                                                        if (discountType === "FIXED") {
                                                            setDiscountType("NONE");
                                                            setDiscountValue("");
                                                        } else {
                                                            setDiscountType("FIXED");
                                                            setDiscountValue("");
                                                        }
                                                    }}
                                                    className={`flex-1 py-2.5 rounded-xl text-[10px] font-black uppercase border-2 transition-all ${
                                                        discountType === "FIXED"
                                                            ? "bg-orange-50 border-[#FF5C00] text-[#FF5C00]"
                                                            : "bg-white border-slate-100 text-slate-400 hover:border-slate-200"
                                                    }`}
                                                >
                                                    FIXED (₹)
                                                </button>
                                            </div>
                                            {discountType !== "NONE" && (
                                                <div className="mt-3 relative">
                                                    <span className="absolute left-4 top-1/2 -translate-y-1/2 text-sm font-black text-slate-400">
                                                        {discountType === "PERCENTAGE" ? "%" : "₹"}
                                                    </span>
                                                    <input
                                                        type="number"
                                                        value={discountValue}
                                                        onChange={(e) => setDiscountValue(e.target.value)}
                                                        placeholder={discountType === "PERCENTAGE" ? "Discount Percentage..." : "Discount Amount..."}
                                                        className="w-full pl-9 pr-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl text-sm font-black focus:border-[#FF5C00] outline-none transition-all"
                                                    />
                                                </div>
                                            )}
                                        </div>

                                        {/* PAYMENT METHOD SECTION */}
                                        <div>
                                            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2.5">
                                                Select Payment Method
                                            </p>
                                            <div className="grid grid-cols-3 gap-2">
                                                {/* CASH */}
                                                <button
                                                    onClick={() => setSelectedPaymentMethod("CASH")}
                                                    className={`py-3 rounded-xl text-[10px] font-black uppercase border-2 transition-all text-center ${
                                                        selectedPaymentMethod === "CASH"
                                                            ? "bg-emerald-500 border-emerald-500 text-white shadow-md shadow-emerald-100"
                                                            : "bg-white border-emerald-100 text-emerald-600 hover:border-[#22c55e]"
                                                    }`}
                                                >
                                                    CASH
                                                </button>
                                                {/* UPI */}
                                                <button
                                                    onClick={() => setSelectedPaymentMethod("UPI")}
                                                    className={`py-3 rounded-xl text-[10px] font-black uppercase border-2 transition-all text-center ${
                                                        selectedPaymentMethod === "UPI"
                                                            ? "bg-blue-500 border-blue-500 text-white shadow-md shadow-blue-100"
                                                            : "bg-white border-blue-100 text-blue-600 hover:border-[#3b82f6]"
                                                    }`}
                                                >
                                                    UPI
                                                </button>
                                                {/* CARD */}
                                                <button
                                                    onClick={() => setSelectedPaymentMethod("CARD")}
                                                    className={`py-3 rounded-xl text-[10px] font-black uppercase border-2 transition-all text-center ${
                                                        selectedPaymentMethod === "CARD"
                                                            ? "bg-purple-500 border-purple-500 text-white shadow-md shadow-purple-100"
                                                            : "bg-white border-purple-100 text-purple-600 hover:border-[#a855f7]"
                                                    }`}
                                                >
                                                    CARD
                                                </button>
                                            </div>

                                            {/* PAY LATER and SPLIT buttons below the grid */}
                                            <div className="grid grid-cols-2 gap-2 mt-2">
                                                <button
                                                    onClick={() => {
                                                        setPayLaterOpen(true);
                                                    }}
                                                    className="py-3 bg-white border-2 border-amber-100 hover:border-[#f59e0b] text-amber-600 rounded-xl text-[10px] font-black uppercase transition-all text-center"
                                                >
                                                    PAY LATER
                                                </button>
                                                <button
                                                    onClick={() => {
                                                        setSplitOpen(true);
                                                    }}
                                                    className="py-3 bg-white border-2 border-violet-100 hover:border-[#8b5cf6] text-violet-600 rounded-xl text-[10px] font-black uppercase transition-all text-center flex items-center justify-center gap-1"
                                                >
                                                    ✂ SPLIT
                                                </button>
                                            </div>
                                        </div>

                                        {/* MODAL BOTTOM BUTTONS */}
                                        <div className="flex gap-3 pt-2">
                                            <button
                                                onClick={() => setBillPreview(null)}
                                                className="flex-1 py-3.5 bg-slate-50 hover:bg-slate-100 text-slate-700 rounded-xl text-[11px] font-black uppercase transition-all"
                                            >
                                                Close
                                            </button>
                                            <button
                                                onClick={finalizeBillWithPayment}
                                                disabled={!selectedPaymentMethod || finalizingBill}
                                                className="flex-1 py-3.5 bg-[#FF5C00] hover:bg-[#e65200] disabled:opacity-40 text-white rounded-xl text-[11px] font-black uppercase tracking-widest transition-all flex items-center justify-center gap-1.5 shadow-lg shadow-orange-100"
                                            >
                                                <Receipt size={13} />
                                                {finalizingBill ? "Processing..." : "Confirm & Serve"}
                                            </button>
                                        </div>
                                    </div>
                                </>
                            );
                        })()}
                    </div>
                </div>
            )}

            {/* Split Payment Quick Modal */}
            {splitOpen && (
                <SplitPaymentQuickModal
                    total={getDiscountedBill().finalAmount}
                    isLoading={splitLoading}
                    onConfirm={handleSplitPayment}
                    onCancel={() => setSplitOpen(false)}
                />
            )}

            {/* Pay Later Full Modal */}
            {payLaterOpen && (
                <PayLaterFullModal
                    orderTotal={getDiscountedBill().finalAmount}
                    isLoading={payLaterLoading}
                    onConfirm={handlePayLater}
                    onCancel={() => setPayLaterOpen(false)}
                />
            )}

            {/* Menu Modal */}
            {(selectedTable || sendAppendOrder) && (
                <MenuModal
                    table={selectedTable || sendAppendOrder}
                    sendAppendOrder={sendAppendOrder}
                    close={() => {
                        setSelectedTable(null);
                        setSendAppendOrder(null);
                        fetchTables();
                    }}
                />
            )}

            {/* Adjust Layout Modal */}
            {editSittingArea && (
                <SittingEditorModal
                    area={editSittingArea}
                    onClose={() => {
                        setEditSittingArea(null);
                        fetchTables();
                    }}
                />
            )}

            {/* Printer Settings Modal */}
            {printerModalOpen && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
                    <div className="bg-white rounded-[2rem] p-8 w-full max-w-sm shadow-2xl">
                        <div className="flex justify-between items-center mb-6">
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 bg-slate-50 rounded-2xl flex items-center justify-center text-slate-500">
                                    <Printer size={20} />
                                </div>
                                <h3 className="text-xl font-black text-slate-900">Printer Settings</h3>
                            </div>
                            <button onClick={() => setPrinterModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                                <X size={20} />
                            </button>
                        </div>
                        
                        <div className="space-y-4 mb-6">
                            <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-100">
                                <div>
                                    <p className="text-sm font-black text-slate-800">Auto Print KOT</p>
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">Prints when order is placed</p>
                                </div>
                                <button
                                    onClick={() => handleTogglePrinter("autoPrintKOT")}
                                    disabled={printerSaving}
                                    className={`w-12 h-6 rounded-full p-1 transition-all duration-300 ${
                                        autoPrintKOT ? "bg-emerald-500" : "bg-slate-200"
                                    }`}
                                >
                                    <div
                                        className={`w-4 h-4 rounded-full bg-white transition-all duration-300 ${
                                            autoPrintKOT ? "translate-x-6" : "translate-x-0"
                                        }`}
                                    />
                                </button>
                            </div>

                            <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-100">
                                <div>
                                    <p className="text-sm font-black text-slate-800">Auto Print Bill</p>
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">Prints when order is served</p>
                                </div>
                                <button
                                    onClick={() => handleTogglePrinter("autoPrintBill")}
                                    disabled={printerSaving}
                                    className={`w-12 h-6 rounded-full p-1 transition-all duration-300 ${
                                        autoPrintBill ? "bg-emerald-500" : "bg-slate-200"
                                    }`}
                                >
                                    <div
                                        className={`w-4 h-4 rounded-full bg-white transition-all duration-300 ${
                                            autoPrintBill ? "translate-x-6" : "translate-x-0"
                                        }`}
                                    />
                                </button>
                            </div>
                        </div>

                        <button
                            onClick={() => setPrinterModalOpen(false)}
                            className="w-full py-4 bg-slate-900 text-white rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-slate-800 transition-all"
                        >
                            Done
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
