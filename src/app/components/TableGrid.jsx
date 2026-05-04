// // 📄 src/components/pos/TableGrid.jsx
// "use client";
// export default function TableGrid({ tables, onSelect }) {
//     console.log(tables,":tables")
//   return (
//     <div className="grid grid-cols-4 gap-4">
//       {tables?.map((t) => (
//         <div
//           key={t._id}
//           onClick={() => onSelect(t)}
//           className={`p-4 rounded cursor-pointer text-center border
//             ${t.status === "RUNNING" ? "bg-yellow-200" : "bg-green-100"}`}
//         >
//           <div className="font-bold">{t.name}</div>
//           <div className="text-xs">{t.section}</div>
//         </div>
//       ))}
//     </div>
//   );
// }


// src/components/pos/TableGrid.jsx
"use client"
export default function TableGrid({ tables, onSelect }) {
  return (
    <div className="grid grid-cols-4 gap-4">
      {tables.map(t => (
        <div
          key={t._id}
          onClick={() => onSelect(t)}
          className={`p-4 rounded cursor-pointer border text-center
            ${t.status === "RUNNING"
              ? "bg-yellow-200"
              : "bg-green-100"}`}
        >
          <div className="font-bold">{t.name}</div>
          <div className="text-xs">{t.section}</div>
        </div>
      ))}
    </div>
  );
}