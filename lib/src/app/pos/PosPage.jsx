// 📄 src/pages/PosPage.jsx
"use client";
import { useEffect, useState } from "react";
import TableGrid from "../components/TableGrid";
import MenuModal from "../components/MenuModal";
import apiConfig from "@/utils/apiConfig";
export default function PosPage() {
  const [tables, setTables] = useState([]);
  const [activeTable, setActiveTable] = useState(null);
  const [order, setOrder] = useState(null);

  const token = localStorage.getItem("token");

  useEffect(() => {
    fetchTables();
  }, []);

  const fetchTables = async () => {
    const res = await fetch(`${apiConfig?.BASE_URL}/api/pos/tables`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const data = await res.json();
    setTables(data);
  };

  const openTable = async (table) => {
    const res = await fetch(
      `https://restaurant-model-backend.onrender.com/api/pos/table/${table._id}/order`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const data = await res.json();
    setActiveTable(table);
    setOrder(data);
  };

  return (
    <div className="p-4">
      <h1 className="text-xl font-bold mb-4">POS – Table View</h1>

      <TableGrid tables={tables} onSelect={openTable} />

      {activeTable && (
        <MenuModal
          table={activeTable}
          order={order}
          close={() => setActiveTable(null)}
        />
      )}
    </div>
  );
}