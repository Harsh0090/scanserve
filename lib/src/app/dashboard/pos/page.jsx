"use client";
import apiConfig from "@/utils/apiConfig";
import { useState } from "react";

export default function PosSetup() {
  const [area, setArea] = useState("AC");
  const [tableCount, setTableCount] = useState(""); // Changed from tableName to tableCount



  const handleSave = async () => {
    try {
      const res = await fetch(`${apiConfig?.BASE_URL}/api/pos/setup`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          areaName: area,
          tableCount: parseInt(tableCount),
        }),
      });

      const data = await res.json();

      if (res.ok) {
        alert(`${tableCount} tables added successfully to ${area}!`);
        setTableCount("");
      } else {
        alert(`Error: ${data.message}`);
      }

    } catch (err) {
      console.error("SETUP ERROR:", err);
      alert("Network error");
    }
  };

  
  return (
    <div className="p-8 max-w-md mx-auto bg-white shadow rounded">
      <h2 className="text-xl font-bold mb-4">Design Restaurant Layout</h2>

      <label className="block mb-2 text-sm font-medium">Area Name (e.g., Garden, AC)</label>
      <input
        className="border w-full p-2 mb-4 rounded"
        value={area}
        onChange={(e) => setArea(e.target.value)}
        placeholder="e.g. AC Room"
      />

      <label className="block mb-2 text-sm font-medium">How many tables to create?</label>
      <input
        type="number"
        className="border w-full p-2 mb-4 rounded"
        value={tableCount}
        onChange={(e) => setTableCount(e.target.value)}
        placeholder="e.g. 5"
      />

      <button
        onClick={handleSave}
        className="bg-red-600 text-white w-full py-2 rounded font-bold hover:bg-red-700 transition-colors"
      >
        Generate Tables
      </button>

      <p className="mt-4 text-xs text-gray-500 italic">
        * Entering "5" will automatically create tables 1, 2, 3, 4, and 5 in the {area} area.
      </p>
    </div>
  );
}