// import { QRCode } from "react-qrcode-logo";

// export default function QRCard({ table }) {
//   return (
//     <div className="border rounded p-4 flex flex-col items-center gap-2 shadow">
//       <QRCode
//         value={table.qrUrl}
//         size={180}
//         logoText={`Table ${table.tableNumber}`}
//         removeQrCodeBehindLogo={true}
//       />
//       <p className="font-bold text-gray-800">Table {table.tableNumber}</p>

//       <button
//         onClick={() => downloadQR(table)}
//         className="px-3 py-1 text-xs bg-gray-200 rounded"
//       >
//         Download
//       </button>
//     </div>
//   );
// }

// function downloadQR(table) {
//   const canvas = document.querySelector(`canvas`);
//   const url = canvas.toDataURL("image/png");
//   const link = document.createElement("a");
//   link.href = url;
//   link.download = `table-${table.tableNumber}.png`;
//   link.click();
// }

//QRCard.js
// import { QRCode } from "react-qrcode-logo";
// import { useRef } from "react";

// export default function QRCard({ table }) {
//   const canvasRef = useRef(null);


//   const printQR = () => {
//   const canvas = canvasRef.current.querySelector("canvas");
//   const dataUrl = canvas.toDataURL("image/png");

//   const cafeName = "Gullu Cafe" || "My Cafe";
//   const powerBy = "Powered by QRServe";

//   const printWindow = window.open("", "_blank", "width=400,height=600");
//   printWindow.document.write(`
//     <html>
//       <head>
//         <title>Print QR - Table ${table.tableNumber}</title>
//         <style>
//           body {
//             display: flex;
//             flex-direction: column;
//             align-items: center;
//             font-family: Arial, sans-serif;
//             padding-top: 30px;
//           }
//           img {
//             width: 260px;
//             height: 260px;
//             margin-bottom: 16px;
//           }
//           .title {
//             font-size: 22px;
//             font-weight: bold;
//             margin-bottom: 4px;
//           }
//           .cafe {
//             font-size: 16px;
//             color: #444;
//             margin-bottom: 8px;
//           }
//           .powered {
//             font-size: 12px;
//             color: #888;
//             margin-top: 20px;
//           }
//         </style>
//       </head>
//       <body>
//         <img src="${dataUrl}" />
//         <div class="title">Table ${table.tableNumber}</div>
//         <div class="cafe">${cafeName}</div>
//         <div class="powered">${powerBy}</div>

//         <script>
//           window.onload = function() {
//             window.print();
//             window.onafterprint = window.close;
//           };
//         </script>
//       </body>
//     </html>
//   `);
// };


//   return (
//     <div className="border rounded p-4 flex flex-col items-center gap-2 shadow">
//       <div ref={canvasRef}>
//         <QRCode
//           value={table.qrUrl}
//           size={180}
//           logoText={`Table ${table.tableNumber}`}
//           removeQrCodeBehindLogo
//         />
//       </div>

//       <p className="font-bold text-gray-800">Table {table.tableNumber}</p>

//       <button
//         onClick={printQR}
//         className="px-3 py-1 text-xs bg-gray-200 rounded"
//       >
//         Print
//       </button>
//     </div>
//   );
// }




import { QRCode } from "react-qrcode-logo";
import { useRef } from "react";
import { Printer, Download, Monitor } from "lucide-react";

export default function QRCard({ table }) {
  const canvasRef = useRef(null);

  const printQR = () => {
    const canvas = canvasRef.current.querySelector("canvas");
    const dataUrl = canvas.toDataURL("image/png");

    const cafeName = localStorage.getItem("restaurantName") || "Our Restaurant";
    const powerBy = "Powered by QRServe";

    const printWindow = window.open("", "_blank", "width=600,height=800");
    
    // 🔥 Fix: Writing the HTML structure properly
    printWindow.document.write(`
      <html>
        <head>
          <title>Print QR - Table ${table.tableNumber}</title>
          <style>
            @page { margin: 0; }
            body {
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              font-family: 'Inter', Arial, sans-serif;
              padding: 40px;
              height: 100vh;
              margin: 0;
            }
            .card {
              border: 2px solid #EEE;
              border-radius: 40px;
              padding: 40px;
              text-align: center;
              width: 300px;
            }
            img {
              width: 250px;
              height: 250px;
              margin-bottom: 24px;
            }
            .table-num {
              font-size: 32px;
              font-weight: 900;
              color: #111;
              margin-bottom: 4px;
              text-transform: uppercase;
              letter-spacing: -0.02em;
            }
            .cafe {
              font-size: 16px;
              font-weight: 600;
              color: #FF4F01;
              margin-bottom: 20px;
            }
            .powered {
              font-size: 10px;
              font-weight: 800;
              color: #AAA;
              text-transform: uppercase;
              letter-spacing: 0.1em;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <img src="${dataUrl}" />
            <div class="table-num">Table ${table.tableNumber}</div>
            <div class="cafe">${cafeName}</div>
            <div class="powered">${powerBy}</div>
          </div>
          <script>
            window.onload = function() {
              window.print();
              setTimeout(() => { window.close(); }, 500);
            };
          </script>
        </body>
      </html>
    `);
    
    // 🔥 ESSENTIAL FIX: Close the document stream so the browser knows it's ready to print
    printWindow.document.close();
  };

  return (
    <div className="bg-white rounded-[2.5rem] border border-gray-100 p-8 flex flex-col items-center gap-6 shadow-lg shadow-orange-100/10 hover:shadow-orange-100/30 transition-all group">
      <div className="bg-gray-50 p-6 rounded-[2rem] group-hover:bg-white group-hover:shadow-inner transition-colors border border-gray-100">
        <div ref={canvasRef}>
          <QRCode
            value={table.qrUrl}
            size={180}
            logoText={`T-${table.tableNumber}`}
            logoColor="#FF4F01"
            qrStyle="dots"
            eyeRadius={10}
            removeQrCodeBehindLogo
          />
        </div>
      </div>

      <div className="text-center">
        <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Outlet Asset</p>
        <p className="text-2xl font-black text-gray-900 tracking-tight">Table {table.tableNumber}</p>
      </div>

      <button
        onClick={printQR}
        className="w-full flex items-center justify-center gap-2 py-4 bg-gray-50 hover:bg-orange-600 hover:text-white rounded-2xl text-[10px] font-black uppercase tracking-widest text-gray-400 transition-all border border-transparent hover:border-orange-500"
      >
        <Printer size={14} /> Print Label
      </button>
    </div>
  );
}