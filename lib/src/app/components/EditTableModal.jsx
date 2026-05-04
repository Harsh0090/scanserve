"use client";
import { useState } from "react";
import { X, Plus, Minus, Save, Trash2 } from "lucide-react";
import apiConfig from "@/utils/apiConfig";

export default function SittingEditorModal({ area, onClose }) {
    const [newCount, setNewCount] = useState(area?.count || 0);
    const [loading, setLoading] = useState(false);

    // ✅ Logic to update the whole sitting count (5 to 7)
    // const handleSave = async () => {
    //     setLoading(true);
    //     try {
    //         const res = await fetch(`http://localhost:5000/api/pos/update-sitting`, {
    //             method: "POST",
    //             headers: { 
    //                 "Content-Type": "application/json",
    //                 Authorization: `Bearer ${localStorage.getItem("token")}` 
    //             },
    //             body: JSON.stringify({ 
    //                 areaName: area.name, 
    //                 targetCount: newCount,
    //                 restaurantId: localStorage.getItem("restaurantId")
    //             })
    //         });
    //         if (res.ok) onClose();
    //     } catch (err) {
    //         console.error(err);
    //     } finally {
    //         setLoading(false);
    //     }
    // };

    const handleSave = async () => {
        setLoading(true);

        try {
            const res = await fetch(`${apiConfig?.BASE_URL}/api/pos/update-sitting`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: "include",   // 🔥🔥🔥 CRITICAL
                body: JSON.stringify({
                    areaName: area.name,
                    targetCount: newCount,
                }),
            });

            if (res.ok) onClose();

        } catch (err) {
            console.error(err);

        } finally {
            setLoading(false);
        }
    };

    // ✅ Logic to delete the entire AREA (Optional, use with caution)
    // const handleDeleteArea = async () => {
    //     if (!confirm(`Are you sure you want to delete ALL tables in ${area.name}?`)) return;
    //     setLoading(true);
    //     try {
    //         // Using targetCount 0 will effectively delete all blank tables in that area
    //         const res = await fetch(`http://localhost:5000/api/pos/update-sitting`, {
    //             method: "POST",
    //             headers: { "Content-Type": "application/json", Authorization: `Bearer ${localStorage.getItem("token")}` },
    //             body: JSON.stringify({ areaName: area.name, targetCount: 0, restaurantId: localStorage.getItem("restaurantId") })
    //         });
    //         if (res.ok) onClose();
    //     } catch (err) {
    //         alert("Delete failed");
    //     } finally {
    //         setLoading(false);
    //     }
    // };

    const handleDeleteArea = async () => {
        if (!confirm(`Delete ALL tables in ${area.name}?`)) return;

        setLoading(true);

        try {
            const res = await fetch(`${apiConfig?.BASE_URL}/api/pos/update-sitting`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: "include",   // 🔥🔥🔥 REQUIRED
                body: JSON.stringify({
                    areaName: area.name,
                    targetCount: 0,
                }),
            });

            if (res.ok) onClose();

        } catch (err) {
            alert("Delete failed");

        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[100] p-4">
            <div className="bg-white w-full max-w-md rounded-[2.5rem] shadow-2xl overflow-hidden">
                <div className="p-8">
                    <div className="flex justify-between items-center mb-8">
                        <h2 className="text-2xl font-black text-gray-900">Sitting: {area.name}</h2>
                        <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-full"><X /></button>
                    </div>

                    <div className="bg-gray-50 rounded-3xl p-8 text-center mb-6">
                        <p className="text-gray-400 font-bold uppercase text-[10px] tracking-widest mb-4">Target Table Count</p>
                        <div className="flex items-center justify-center gap-8">
                            <button onClick={() => setNewCount(Math.max(0, newCount - 1))} className="w-12 h-12 bg-white rounded-xl shadow-sm border flex items-center justify-center"><Minus /></button>
                            <span className="text-6xl font-black">{newCount}</span>
                            <button onClick={() => setNewCount(newCount + 1)} className="w-12 h-12 bg-white rounded-xl shadow-sm border flex items-center justify-center"><Plus /></button>
                        </div>
                    </div>

                    <div className="space-y-3">
                        <button
                            onClick={handleSave}
                            className="w-full py-5 bg-blue-600 text-white rounded-2xl font-black text-lg shadow-lg hover:bg-blue-700 transition-all flex items-center justify-center gap-2"
                        >
                            <Save className="w-5 h-5" /> SAVE SITTING
                        </button>

                        <button
                            onClick={handleDeleteArea}
                            className="w-full py-4 text-red-500 font-bold hover:bg-red-50 rounded-2xl transition-all flex items-center justify-center gap-2"
                        >
                            <Trash2 className="w-4 h-4" /> DELETE ALL BLANK TABLES
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}