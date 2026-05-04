

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
    MoveHorizontal, // Added for Shift Table icon
} from "lucide-react";
import MenuModal from "../../components/MenuModal";
import SittingEditorModal from "../../components/EditTableModal";
import { useRouter } from "next/navigation";
// --- Shift API Function ---
import apiConfig from "@/utils/apiConfig";
export const shiftOrderTable = async (orderId, newTableNumber) => {
    const res = await fetch(
        `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/shift`,
        {
            method: "PATCH",
            credentials: "include", // ✅ CRITICAL
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ newTableNumber }),
        },
    );

    const data = await res.json();

    if (!res.ok) {
        throw new Error(data.message || "Shift failed");
    }

    return data;
};

export default function PosPage() {
    const [areas, setAreas] = useState({});
    const [selectedTable, setSelectedTable] = useState(null);
    const [editSittingArea, setEditSittingArea] = useState(null);
    const [loading, setLoading] = useState(false);
    // --- Shift States ---
    const [shiftData, setShiftData] = useState(null); // { orderId, currentTable }
    const [newTableNumInput, setNewTableNumInput] = useState("");

    const [sendAppendOrder, setSendAppendOrder] = useState(null)

    const router = useRouter();

    useEffect(() => {
        fetchTables();
    }, []);

    const fetchTables = async () => {
        try {
            setLoading(true);
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/pos/tables?t=${Date.now()}`,
                {
                    credentials: "include",
                    cache: "no-cache",
                },
            );

            const data = await res.json();

            if (Array.isArray(data)) {
                const grouped = data.reduce((acc, table) => {
                    const area = table.areaName ? table.areaName.trim() : "Unassigned";

                    acc[area] = acc[area] || [];
                    acc[area].push(table);

                    return acc;
                }, {});

                /*
                      🔥🔥🔥 CRITICAL FIX — SORT EACH AREA
                    */
                Object.keys(grouped).forEach((area) => {
                    grouped[area].sort(
                        (a, b) => Number(a.tableName) - Number(b.tableName),
                    );
                });

                setAreas(grouped);
            }
        } catch (err) {
            console.error("Failed to fetch tables", err);
        } finally {
            setLoading(false);
        }
    };
    const handleShiftConfirm = async () => {
        if (!newTableNumInput) return alert("Please enter a new table number");

        try {
            await shiftOrderTable(shiftData.orderId, newTableNumInput);

            setShiftData(null);
            setNewTableNumInput("");

            fetchTables();

            alert("Table shifted successfully");
        } catch (err) {
            alert(err.message);
        }
    };
//     const handlePrintBill = async (e, table) => {
//         e.stopPropagation();

//         const orderId = table?.currentOrderId;

//         if (!orderId) return alert("No active order found");

//         try {
//             const res = await fetch(
//                 `${apiConfig?.BASE_URL}/api/admin/orders/${orderId}/print-bill`, // ✅ FIXED
//                 {
//                     method: "PATCH",
//                     credentials: "include",
//                 },
//             );

//             const data = await res.json();

//             if (!res.ok) return alert(data.message);

//             const bill = data.bill;

//             const printWindow = window.open("", "_blank");

//             printWindow.document.write(`
//             <html>
//                 <head><title>Bill</title></head>
//                 <body style="font-family: sans-serif; padding: 20px;">
//                     <h2>Restaurant Bill - Table ${bill.tableNumber}</h2>
//                     <hr />
//                     ${bill.items
//                     .map(
//                         (i) =>
//                             `<p>${i.quantity} x ${i.name} - ₹${i.basePrice * i.quantity}</p>`,
//                     )
//                     .join("")}
//                     <hr />
//                   <h3>Subtotal: ₹${bill.subTotal}</h3>
// <h3>GST (${bill.gstRate}%): ₹${bill.gstAmount}</h3>
// <hr />
// <h2>Total: ₹${bill.total}</h2>
//                 </body>
//             </html>
//         `);

//             printWindow.document.close();
//             printWindow.print();

//             fetchTables();
//         } catch (err) {
//             console.error("PRINT ERROR:", err);
//         }
//     };



const handlePrintBill = async (e, table) => {
  e.stopPropagation();

  const orderId = table?.currentOrderId;

  if (!orderId) {
    alert("No active order found");
    return;
  }

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
      alert(data.message);
      return;
    }

    const bill = data.bill;

    const html = `
      <html>
        <head>
          <style>

            body{
              font-family: monospace;
              width:300px;
              margin:0 auto;
              padding:10px;
            }

            .center{
              text-align:center;
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
              font-weight:bold;
              font-size:16px;
            }

            @media print {
              @page { margin:0; }
            }

          </style>
        </head>

        <body>

          <div class="center">
            <h2>${bill.restaurantName || "RESTAURANT"}</h2>
            <div>Table: ${bill.tableNumber}</div>
            <div>${new Date().toLocaleString()}</div>
          </div>

          <div class="line"></div>

          <table>

            <tr>
              <td><b>Item</b></td>
              <td class="qty"><b>Qty</b></td>
              <td class="right"><b>Price</b></td>
            </tr>

            ${bill.items.map(i => `
              <tr>
                <td>${i.name}</td>
                <td class="qty">${i.quantity}</td>
                <td class="right">₹${(i.basePrice * i.quantity).toFixed(2)}</td>
              </tr>
            `).join("")}

          </table>

          <div class="line"></div>

          <div class="right">
            <div>Subtotal: ₹${bill.subTotal.toFixed(2)}</div>
            <div>GST (${bill.gstRate}%): ₹${bill.gstAmount.toFixed(2)}</div>
            <div class="total">TOTAL: ₹${bill.total.toFixed(2)}</div>
          </div>

          <div class="line"></div>

          <div class="center">Thank You! Visit Again</div>

        </body>
      </html>
    `;

    // Hidden iframe print
    const iframe = document.createElement("iframe");
    iframe.style.position = "fixed";
    iframe.style.right = "0";
    iframe.style.bottom = "0";
    iframe.style.width = "0";
    iframe.style.height = "0";
    iframe.style.border = "0";

    document.body.appendChild(iframe);

    const doc = iframe.contentWindow.document;

    doc.open();
    doc.write(html);
    doc.close();

    iframe.onload = () => {
      iframe.contentWindow.focus();
      iframe.contentWindow.print();

      setTimeout(() => {
        document.body.removeChild(iframe);
      }, 1000);
    };

    fetchTables();

  } catch (err) {
    console.error("PRINT ERROR:", err);
  }
};



    const handleDeleteIndividualTable = async (tableId) => {
        if (!confirm("Are you sure you want to delete this table?")) return;

        try {
            const res = await fetch(
                `${apiConfig?.BASE_URL}/api/pos/tables/${tableId}`,
                {
                    method: "DELETE",
                    credentials: "include", // ✅ CRITICAL
                },
            );

            if (res.ok) fetchTables();
        } catch (err) {
            console.error("Delete failed", err);
        }
    };
    const handleTableClick = (table) => {
        if (table.status === "Running") return alert("Table already running");
        console.log("Selected Table:", table);
        setSelectedTable(table);
    };

    const handleAppendOrder = (table) => {
        console.log(table);
        setSendAppendOrder(table)
    }
    if (loading) {
        return (
            <div className="flex items-center justify-center h-screen bg-[#FDFCF6]">
                <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4D00]"></div>
            </div>
        );
    }

    return (
        <div className="p-4 lg:p-10 bg-[#F8FAFB] min-h-screen lg:ml-64 transition-all duration-300">
            {/* Header Section */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-10 gap-4">
                <div>
                    <h1 className="text-3xl font-black text-slate-900 tracking-tight">
                        Table Management
                    </h1>
                    <p className="text-slate-500 font-medium text-sm">
                        Monitor and manage your floor layout in real-time.
                    </p>
                </div>
                <button
                    onClick={() => router.push("/dashboard/pos")}
                    className="flex items-center gap-2 bg-[#FF5C00] text-white px-6 py-3 rounded-2xl font-bold shadow-lg shadow-orange-200 hover:bg-[#e65200] transition-all active:scale-95"
                >
                    <Plus size={20} />
                    ADD NEW TABLES
                </button>
            </div>

            <div className="space-y-12">
                {Object.keys(areas).map((areaName) => (
                    <div key={areaName} className="relative">
                        <div className="flex justify-between items-center mb-6">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white rounded-xl shadow-sm border border-slate-100">
                                    <LayoutGrid size={18} className="text-slate-400" />
                                </div>
                                <h2 className="font-black text-slate-800 uppercase text-sm tracking-widest">
                                    {areaName}{" "}
                                    <span className="text-slate-400 ml-1">
                                        ({areas[areaName].length})
                                    </span>
                                </h2>
                            </div>
                            <button
                                onClick={() =>
                                    setEditSittingArea({
                                        name: areaName,
                                        count: areas[areaName].length,
                                    })
                                }
                                className="flex items-center gap-2 text-[11px] font-black text-slate-500 bg-white border border-slate-200 px-4 py-2 rounded-xl hover:border-[#FF5C00] hover:text-[#FF5C00] transition-all shadow-sm"
                            >
                                <Settings2 size={14} />
                                ADJUST LAYOUT
                            </button>
                        </div>

                        <div className="grid grid-cols-3 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 gap-6">
                            {areas[areaName].map((table) => (
                                <div key={table._id} className="relative group">
                                    <button
                                        onClick={() => handleTableClick(table)}
                                        className={`w-full aspect-square rounded-[1.5rem] flex flex-col items-center justify-center gap-2 transition-all duration-300 relative overflow-hidden
                                        ${table.status === "Running"
                                                ? "bg-[#FF5C00] text-white shadow-xl shadow-orange-200 ring-4 ring-orange-100"
                                                : "bg-white text-slate-800 border-2 border-slate-100 hover:border-[#FF5C00] hover:shadow-lg shadow-sm"
                                            }`}
                                    >
                                        <Armchair
                                            size={24}
                                            className={`${table.status === "Running" ? "text-white/40" : "text-slate-200"}`}
                                        />
                                        <span className="text-3xl font-black tracking-tighter">
                                            {table.tableName}
                                        </span>
                                        <span
                                            className={`text-[10px] font-black uppercase tracking-widest px-3 py-1 rounded-full ${table.status === "Running" ? "bg-white/20" : "bg-slate-50 text-slate-400"}`}
                                        >
                                            {table.status === "Running" ? "Occupied" : "Vacant"}
                                        </span>
                                    </button>

                                    {/* Actions for Running Tables */}
                                    {/* {table.status === "Running" && (
                                        <div className="absolute top-2 right-2 flex flex-col gap-2">
                                            <button
                                                onClick={(e) => handlePrintBill(e, table)}
                                                className="bg-white/20 hover:bg-white text-white hover:text-[#FF5C00] p-2 rounded-full transition-all"
                                            >
                                                <Printer size={14} />
                                            </button>
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    setShiftData({
                                                        orderId: table.currentOrderId,
                                                        currentTable: table.tableName,
                                                    });
                                                }}
                                                className="bg-white/20 hover:bg-white text-white hover:text-blue-500 p-2 rounded-full transition-all"
                                            >
                                                <MoveHorizontal size={14} />
                                            </button>
                                        </div>
                                    )} */}


                                    {/* Actions for Running Tables */}
                                    {table.status === "Running" && (
                                        <div className="absolute top-2 right-2 flex flex-col gap-2">
                                            {/* 🔥 NEW: Add More Items Button */}
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    // Replace this with your function to open menu/modal
                                                    handleAppendOrder(table);
                                                }}
                                                className="bg-white/20 hover:bg-white text-white hover:text-green-600 p-2 rounded-full transition-all shadow-sm"
                                                title="Add Items"
                                            >
                                                <Plus size={14} />
                                            </button>

                                            <button
                                                onClick={(e) => handlePrintBill(e, table)}
                                                className="bg-white/20 hover:bg-white text-white hover:text-[#FF5C00] p-2 rounded-full transition-all"
                                            >
                                                <Printer size={14} />
                                            </button>

                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    setShiftData({
                                                        orderId: table.currentOrderId,
                                                        currentTable: table.tableName,
                                                    });
                                                }}
                                                className="bg-white/20 hover:bg-white text-white hover:text-blue-500 p-2 rounded-full transition-all"
                                            >
                                                <MoveHorizontal size={14} />
                                            </button>
                                        </div>
                                    )}

                                    {/* Delete Button (Vacant) */}
                                    {table.status !== "Running" && (
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                handleDeleteIndividualTable(table._id);
                                            }}
                                            className="absolute -top-1 -right-1 bg-white text-red-500 p-2 rounded-full opacity-0 group-hover:opacity-100 transition-all shadow-md border"
                                        >
                                            <Trash2 size={12} />
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    </div>
                ))}
            </div>

            {/* --- MODALS --- */}

            {/* Shift Table Modal */}
            {shiftData && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[110] flex items-center justify-center p-4">
                    <div className="bg-white rounded-[2rem] p-8 w-full max-w-sm shadow-2xl">
                        <div className="flex justify-between items-center mb-6">
                            <h3 className="text-xl font-black text-slate-900">Shift Table</h3>
                            <button
                                onClick={() => setShiftData(null)}
                                className="text-slate-400 hover:text-slate-600"
                            >
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
                            onClick={handleShiftConfirm}
                            className="w-full bg-[#FF5C00] text-white py-3 rounded-xl font-bold hover:bg-[#e65200] transition-all"
                        >
                            CONFIRM SHIFT
                        </button>
                    </div>
                </div>
            )}

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

            {editSittingArea && (
                <SittingEditorModal
                    area={editSittingArea}
                    onClose={() => {
                        setEditSittingArea(null);
                        fetchTables();
                    }}
                />
            )}
        </div>
    );
}
