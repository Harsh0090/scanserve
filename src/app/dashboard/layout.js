

// // "use client";

// // import { useEffect, useRef, useState } from "react";
// // import { usePathname, useRouter } from "next/navigation";
// // import { useAuth } from "../context/AuthContext";
// // import useTrialListener from "../../hooks/useTrialListener";
// // import Sidebar from "../components/Sidebar";
// // import { getSocket } from "../lib/socket";
// // import { WifiOff, RefreshCw } from "lucide-react";
// // import toast, { Toaster } from "react-hot-toast";

// // export default function DashboardLayout({ children }) {

// //   useTrialListener();

// //   const pathname = usePathname();
// //   const router = useRouter();
// //   const { user } = useAuth();

// //   const audioRef = useRef(null);

// //   const order_ready_alert = useRef(null)

// //   const [isOffline, setIsOffline] = useState(false);
// //   const [isAlerting, setIsAlerting] = useState(false);

// //   const restaurantId = user?.restaurantId;

// //   /*
// //   ---------------------------------------------
// //   INTERNET STATUS MONITOR
// //   ---------------------------------------------
// //   */

// //   useEffect(() => {

// //     setIsOffline(!navigator.onLine);

// //     const goOnline = () => setIsOffline(false);
// //     const goOffline = () => setIsOffline(true);

// //     window.addEventListener("online", goOnline);
// //     window.addEventListener("offline", goOffline);

// //     return () => {
// //       window.removeEventListener("online", goOnline);
// //       window.removeEventListener("offline", goOffline);
// //     };

// //   }, []);

// //   /*
// //   ---------------------------------------------
// //   AUDIO INITIALIZATION
// //   ---------------------------------------------
// //   */

// //   useEffect(() => {

// //     const audio = new Audio("/tring_tring.mp3");
// //     audio.preload = "auto";


// //     audioRef.current = audio;

// //     const unlockAudio = () => {

// //       audio.play()
// //         .then(() => {
// //           audio.pause();
// //           audio.currentTime = 0;
// //         })
// //         .catch(() => { });

// //       window.removeEventListener("click", unlockAudio);

// //     };

// //     window.addEventListener("click", unlockAudio);

// //   }, []);



// //   useEffect(() => {

// //     const audio = new Audio("/bicycle_bell.mp3");
// //     audio.preload = "auto";


// //     order_ready_alert.current = audio;

// //     const unlockAudio = () => {

// //       audio.play()
// //         .then(() => {
// //           audio.pause();
// //           audio.currentTime = 0;
// //         })
// //         .catch(() => { });

// //       window.removeEventListener("click", unlockAudio);

// //     };

// //     window.addEventListener("click", unlockAudio);

// //   }, []);

// //   /*
// //   ---------------------------------------------
// //   REQUEST NOTIFICATION PERMISSION
// //   ---------------------------------------------
// //   */

// //   useEffect(() => {

// //     const askPermission = async () => {

// //       if ("Notification" in window && Notification.permission === "default") {
// //         await Notification.requestPermission();
// //       }

// //     };

// //     window.addEventListener("click", askPermission, { once: true });

// //     return () => window.removeEventListener("click", askPermission);

// //   }, []);

// //   /*
// //   ---------------------------------------------
// //   SOCKET ORDER ALERT SYSTEM
// //   ---------------------------------------------
// //   */

// //   useEffect(() => {

// //     if (!restaurantId) return;

// //     const socket = getSocket(restaurantId);

// //     console.log("Socket connected:", socket.id);

// //     const triggerAlert = (order) => {

// //       // const isOnOrdersPage = pathname.includes("/dashboard/orders");

// //       // if (isOnOrdersPage) return;

// //       console.log("🔔 New Order Received");

// //       /*
// //       SCREEN BLINK
// //       */

// //       setIsAlerting(true);

// //       setTimeout(() => {
// //         setIsAlerting(false);
// //       }, 7000);

// //       /*
// //       PLAY SOUND
// //       */

// //       if (audioRef.current) {

// //         audioRef.current.currentTime = 0;

// //         audioRef.current.play().catch(() => {
// //           console.log("Audio blocked");
// //         });

// //       }

// //       /*
// //       BROWSER NOTIFICATION
// //       */

// //       if ("Notification" in window && Notification.permission === "granted") {

// //         const notification = new Notification("🔔 New Order!", {
// //           body: `Table ${order.tableNumber || "NA"} • ₹${order.estimatedTotal}`,
// //           icon: "/favicon.ico",
// //           tag: "order-alert"
// //         });

// //         notification.onclick = () => {

// //           window.focus();

// //           if (audioRef.current) {
// //             audioRef.current.pause();
// //           }

// //           router.push("/dashboard/orders");

// //         };

// //       }

// //     };

// //     socket.on("new_order", triggerAlert);
// //     socket.on("order_updated", triggerAlert);

// //     return () => {

// //       socket.off("new_order", triggerAlert);
// //       socket.off("order_updated", triggerAlert);

// //     };

// //   }, [restaurantId, pathname, router]);




// //   /*
// // Waiter Notifition 
// // code 

// //   */


// //   useEffect(() => {

// //     if (!restaurantId) return;

// //     const socket = getSocket(restaurantId);

// //     console.log("Socket connected:", socket.id);

// //     const triggerAlert = (order) => {

// //       console.log("🔔 New Order Received");

// //       setIsAlerting(true);

// //       setTimeout(() => {
// //         setIsAlerting(false);
// //       }, 7000);

// //       if (audioRef.current) {
// //         audioRef.current.currentTime = 0;
// //         audioRef.current.play().catch(() => {
// //           console.log("Audio blocked");
// //         });
// //       }

// //       if ("Notification" in window && Notification.permission === "granted") {

// //         const notification = new Notification("🔔 New Order!", {
// //           body: `Table ${order.tableNumber || "NA"} • ₹${order.estimatedTotal}`,
// //           icon: "/favicon.ico",
// //           tag: "order-alert"
// //         });

// //         notification.onclick = () => {

// //           window.focus();

// //           if (audioRef.current) {
// //             audioRef.current.pause();
// //           }

// //           router.push("/dashboard/orders");

// //         };
// //       }
// //     };

// //     /*
// //      NEW ORDER
// //     */
// //     socket.on("new_order", triggerAlert);

// //     /*
// //      STATUS UPDATE
// //     */
// //     socket.on("order_updated", triggerAlert);

// //     /*
// //      🍽 ORDER READY (Kitchen → Waiter)
// //     */
// //     socket.on("order_ready", (data) => {

// //       console.log("🍽 Order Ready For Waiter");

// //       if (order_ready_alert.current) {
// //         order_ready_alert.current.currentTime = 0;
// //         order_ready_alert.current.play().catch(() => { });
// //       }
// //       console.log(" 🍽 ORDER READY", data)
// //       // toast.success(`Table ${data.tableNumber} order ready`);

// //       toast.success(
// //         data.tableNumber
// //           ? `Table ${data.tableNumber} order ready`
// //           : `Order ready for pickup`
// //       );

// //     });

// //     /*
// //      CLEANUP
// //     */
// //     return () => {

// //       socket.off("new_order", triggerAlert);
// //       socket.off("order_updated", triggerAlert);
// //       socket.off("order_ready");

// //     };

// //   }, [restaurantId, pathname, router]);
// //   /*
// //   ---------------------------------------------
// //   UI
// //   ---------------------------------------------
// //   */

// //   return (

// //     <div
// //       className={`flex flex-col lg:flex-row min-h-screen relative transition-all duration-300 ${isAlerting ? "bg-orange-50" : ""
// //         }`}
// //     >
// //       <Toaster position="top-center" />
// //       <Sidebar />

// //       <main className="flex-1 w-full bg-gray-50 relative">

// //         {children}

// //         {isAlerting && (
// //           <div className="absolute inset-0 pointer-events-none animate-pulse bg-orange-400/10" />
// //         )}

// //       </main>

// //       {isOffline && (

// //         <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm">

// //           <div className="bg-white p-8 rounded-[2.5rem] shadow-2xl max-w-sm w-full mx-4 text-center space-y-6">

// //             <div className="w-20 h-20 bg-red-50 rounded-full flex items-center justify-center mx-auto">
// //               <WifiOff className="text-red-500 animate-pulse" size={40} />
// //             </div>

// //             <div>
// //               <h2 className="text-2xl font-black text-slate-800">
// //                 Connection Lost
// //               </h2>

// //               <p className="text-slate-500 font-medium mt-2">
// //                 Your internet is disconnected. Please check your router or mobile data.
// //               </p>
// //             </div>

// //             <button
// //               onClick={() => window.location.reload()}
// //               className="w-full py-4 bg-slate-800 hover:bg-slate-900 text-white rounded-2xl font-black flex items-center justify-center gap-2"
// //             >
// //               <RefreshCw size={18} />
// //               TRY RECONNECTING
// //             </button>

// //           </div>

// //         </div>

// //       )}

// //     </div>

// //   );

// // }






// "use client";

// import { useEffect, useRef, useState } from "react";
// import { usePathname, useRouter } from "next/navigation";
// import { useAuth } from "../context/AuthContext";
// import useTrialListener from "../../hooks/useTrialListener";
// import Sidebar from "../components/Sidebar";
// import { getSocket } from "../lib/socket";
// import { WifiOff, RefreshCw } from "lucide-react";
// import toast, { Toaster } from "react-hot-toast";
// import apiConfig from "@/utils/apiConfig";

// export default function DashboardLayout({ children }) {

//   useTrialListener();

//   const pathname = usePathname();
//   const router = useRouter();
//   const { user } = useAuth();

//   const newOrderAudio = useRef(null);
//   const orderUpdateAudio = useRef(null);
//   const orderReadyAudio = useRef(null);

//   const [isOffline, setIsOffline] = useState(false);
//   const [isAlerting, setIsAlerting] = useState(false);

//   const restaurantId = user?.restaurantId;



//   /*
// ---------------------------------------------
// KEEP TAB ALIVE (IMPORTANT)
// ---------------------------------------------
// */

// useEffect(() => {

//   const keepAlive = new Audio("/  fourfiveseconds.mp3");

//   keepAlive.loop = true;
//   keepAlive.volume = 0;

//   keepAlive.play().catch(() => {
//     console.log("Silent keep-alive blocked until user interaction");
//   });

// }, []);

//   /*
//   ---------------------------------------------
//   INTERNET STATUS MONITOR
//   ---------------------------------------------
//   */

//   useEffect(() => {

//     setIsOffline(!navigator.onLine);

//     const goOnline = () => setIsOffline(false);
//     const goOffline = () => setIsOffline(true);

//     window.addEventListener("online", goOnline);
//     window.addEventListener("offline", goOffline);

//     return () => {
//       window.removeEventListener("online", goOnline);
//       window.removeEventListener("offline", goOffline);
//     };

//   }, []);

//   /*
//   ---------------------------------------------
//   AUDIO INITIALIZATION
//   ---------------------------------------------
//   */

//   useEffect(() => {

//     newOrderAudio.current = new Audio("/tring_tring.mp3");
//     orderUpdateAudio.current = new Audio("/uber_notif_order.mp3");
//     orderReadyAudio.current = new Audio("/bicycle_bell.mp3");

//     newOrderAudio.current.preload = "auto";
//     orderUpdateAudio.current.preload = "auto";
//     orderReadyAudio.current.preload = "auto";

//     const unlockAudio = () => {

//       [newOrderAudio, orderUpdateAudio, orderReadyAudio].forEach(ref => {

//         if (ref.current) {
//           ref.current.play()
//             .then(() => {
//               ref.current.pause();
//               ref.current.currentTime = 0;
//             })
//             .catch(() => {});
//         }

//       });

//       window.removeEventListener("click", unlockAudio);

//     };

//     window.addEventListener("click", unlockAudio);

//   }, []);

//   /*
//   ---------------------------------------------
//   REQUEST NOTIFICATION PERMISSION
//   ---------------------------------------------
//   */

//   useEffect(() => {

//     const askPermission = async () => {

//       if ("Notification" in window && Notification.permission === "default") {
//         await Notification.requestPermission();
//       }

//     };

//     window.addEventListener("click", askPermission, { once: true });

//     return () => window.removeEventListener("click", askPermission);

//   }, []);

//   /*
//   ---------------------------------------------
//   SOCKET ORDER ALERT SYSTEM
//   ---------------------------------------------
//   */

//   useEffect(() => {

//     if (!restaurantId) return;

//     const socket = getSocket(restaurantId);

//     console.log("Socket connected:", socket.id);

//     /*
//     -------------------------
//     NEW ORDER
//     -------------------------
//     */

//     socket.on("new_order", (order) => {

//       console.log("🆕 NEW ORDER");

//       setIsAlerting(true);
//       setTimeout(() => setIsAlerting(false), 7000);

//       if (newOrderAudio.current) {
//         newOrderAudio.current.currentTime = 0;
//         newOrderAudio.current.play().catch(() => {});
//       }

//       showNotification(order, "New Order");

//     });

//     /*
//     -------------------------
//     ORDER UPDATED
//     -------------------------
//     */

//     socket.on("order_updated", (order) => {

//       console.log("🔄 ORDER UPDATED");

//       if (orderUpdateAudio.current) {
//         orderUpdateAudio.current.currentTime = 0;
//         orderUpdateAudio.current.play().catch(() => {});
//       }

//       showNotification(order, "Order Updated");

//     });

//     /*
//     -------------------------
//     ORDER READY
//     -------------------------
//     */

//     socket.on("order_ready", (data) => {

//       console.log("🍽 ORDER READY");

//       if (orderReadyAudio.current) {
//         orderReadyAudio.current.currentTime = 0;
//         orderReadyAudio.current.play().catch(() => {});
//       }

//       toast.success(
//         data.tableNumber
//           ? `Table ${data.tableNumber} order ready`
//           : "Order ready for pickup"
//       );

//     });

//     return () => {

//       socket.off("new_order");
//       socket.off("order_updated");
//       socket.off("order_ready");

//     };

//   }, [restaurantId]);

//   /*
//   ---------------------------------------------
//   BROWSER NOTIFICATION
//   ---------------------------------------------
//   */

//   const showNotification = (order, title) => {

//     if ("Notification" in window && Notification.permission === "granted") {

//       const notification = new Notification(`🔔 ${title}`, {
//         body: `Table ${order.tableNumber || "NA"} • ₹${order.estimatedTotal}`,
//         icon: "/favicon.ico",
//         tag: "order-alert"
//       });

//       notification.onclick = () => {

//         window.focus();
//         router.push("/dashboard/orders");

//       };

//     }

//   };




//   /*
// ---------------------------------------------
// ORDER POLLING FALLBACK
// ---------------------------------------------
// */

// useEffect(() => {

//   if (!restaurantId) return;

//   const checkOrders = async () => {

//     try {

//       const res = await fetch(`${apiConfig?.BASE_URL}/api/orders/latest?restaurantId=${restaurantId}`);

//       if (!res.ok) return;

//       const data = await res.json();

//       if (data?.newOrder) {

//         console.log("⚠️ Missed order detected via polling");

//         if (newOrderAudio.current) {
//           newOrderAudio.current.currentTime = 0;
//           newOrderAudio.current.play().catch(()=>{});
//         }

//       }

//     } catch (err) {

//       console.log("Polling failed");

//     }

//   };

//   const interval = setInterval(checkOrders, 120000); // every 2 minutes

//   return () => clearInterval(interval);

// }, [restaurantId]);
//   /*
//   ---------------------------------------------
//   UI
//   ---------------------------------------------
//   */

//   return (

//     <div
//       className={`flex flex-col lg:flex-row min-h-screen relative transition-all duration-300 ${isAlerting ? "bg-orange-50" : ""}`}
//     >

//       <Toaster position="top-center" />

//       <Sidebar />

//       <main className="flex-1 w-full bg-gray-50 relative">

//         {children}

//         {isAlerting && (
//           <div className="absolute inset-0 pointer-events-none animate-pulse bg-orange-400/10" />
//         )}

//       </main>

//       {isOffline && (

//         <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm">

//           <div className="bg-white p-8 rounded-[2.5rem] shadow-2xl max-w-sm w-full mx-4 text-center space-y-6">

//             <div className="w-20 h-20 bg-red-50 rounded-full flex items-center justify-center mx-auto">
//               <WifiOff className="text-red-500 animate-pulse" size={40} />
//             </div>

//             <div>
//               <h2 className="text-2xl font-black text-slate-800">
//                 Connection Lost
//               </h2>

//               <p className="text-slate-500 font-medium mt-2">
//                 Your internet is disconnected. Please check your router or mobile data.
//               </p>
//             </div>

//             <button
//               onClick={() => window.location.reload()}
//               className="w-full py-4 bg-slate-800 hover:bg-slate-900 text-white rounded-2xl font-black flex items-center justify-center gap-2"
//             >
//               <RefreshCw size={18} />
//               TRY RECONNECTING
//             </button>

//           </div>

//         </div>

//       )}

//     </div>

//   );

// }
















"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "../context/AuthContext";
import useTrialListener from "../../hooks/useTrialListener";
import Sidebar from "../components/Sidebar";
import { getSocket } from "../lib/socket";
import { WifiOff, RefreshCw } from "lucide-react";
import toast, { Toaster } from "react-hot-toast";
import apiConfig from "@/utils/apiConfig";

export default function DashboardLayout({ children }) {

  useTrialListener();

  const pathname = usePathname();
  const router = useRouter();
  const { user } = useAuth();

  const newOrderAudio = useRef(null);
  const orderUpdateAudio = useRef(null);
  const orderReadyAudio = useRef(null);

  const lastOrderRef = useRef(null);

  const [isOffline, setIsOffline] = useState(false);
  const [isAlerting, setIsAlerting] = useState(false);

  const restaurantId = user?.restaurantId;

  /*
  ---------------------------------------------
  KEEP TAB ALIVE
  ---------------------------------------------
  */

  useEffect(() => {

    const keepAlive = new Audio("/fourfiveseconds.mp3");

    keepAlive.loop = true;
    keepAlive.volume = 0;

    keepAlive.play().catch(() => {
      console.log("keep alive blocked until user click");
    });

  }, []);

  /*
  ---------------------------------------------
  INTERNET MONITOR
  ---------------------------------------------
  */

  useEffect(() => {

    setIsOffline(!navigator.onLine);

    const goOnline = () => setIsOffline(false);
    const goOffline = () => setIsOffline(true);

    window.addEventListener("online", goOnline);
    window.addEventListener("offline", goOffline);

    return () => {

      window.removeEventListener("online", goOnline);
      window.removeEventListener("offline", goOffline);

    };

  }, []);

  /*
  ---------------------------------------------
  AUDIO INITIALIZATION
  ---------------------------------------------
  */

  useEffect(() => {

    newOrderAudio.current = new Audio("/tring_tring.mp3");
    orderUpdateAudio.current = new Audio("/uber_notif_order.mp3");
    orderReadyAudio.current = new Audio("/bicycle_bell.mp3");

    const unlockAudio = () => {

      [newOrderAudio, orderUpdateAudio, orderReadyAudio].forEach(ref => {

        if (ref.current) {

          ref.current.play()
            .then(() => {

              ref.current.pause();
              ref.current.currentTime = 0;

            })
            .catch(()=>{});

        }

      });

      window.removeEventListener("click", unlockAudio);

    };

    window.addEventListener("click", unlockAudio);

  }, []);

  /*
  ---------------------------------------------
  SOCKET ORDER ALERTS
  ---------------------------------------------
  */

  useEffect(() => {

    if (!restaurantId) return;

    const socket = getSocket(restaurantId);

    socket.on("new_order", (order) => {

      console.log("🆕 NEW ORDER");

      lastOrderRef.current = order._id;

      setIsAlerting(true);
      setTimeout(()=>setIsAlerting(false),7000);

      if(newOrderAudio.current){

        newOrderAudio.current.currentTime = 0;
        newOrderAudio.current.play().catch(()=>{});

      }

      showNotification(order,"New Order");

    });

    socket.on("order_updated",(order)=>{

      console.log("🔄 ORDER UPDATED");

      if(orderUpdateAudio.current){

        orderUpdateAudio.current.currentTime = 0;
        orderUpdateAudio.current.play().catch(()=>{});

      }

      showNotification(order,"Order Updated");

    });

    socket.on("order_ready",(data)=>{

      console.log("🍽 ORDER READY");

      if(orderReadyAudio.current){

        orderReadyAudio.current.currentTime = 0;
        orderReadyAudio.current.play().catch(()=>{});

      }

      toast.success(
        data.tableNumber
        ? `Table ${data.tableNumber} order ready`
        : `Order ready`
      );

    });

    return ()=>{

      socket.off("new_order");
      socket.off("order_updated");
      socket.off("order_ready");

    }

  },[restaurantId]);

  /*
  ---------------------------------------------
  POLLING FALLBACK
  ---------------------------------------------
  */

  useEffect(()=>{

    if(!restaurantId) return;

    const checkOrders = async()=>{

      try{

        const res = await fetch(`${apiConfig.BASE_URL}/api/orders/latest?restaurantId=${restaurantId}`);

        if(!res.ok) return;

        const data = await res.json();

        if(data?.orderId && data.orderId !== lastOrderRef.current){

          lastOrderRef.current = data.orderId;

          console.log("⚠️ Polling detected missed order");

          if(newOrderAudio.current){

            newOrderAudio.current.currentTime = 0;
            newOrderAudio.current.play().catch(()=>{});

          }

        }

      }
      catch(err){

        console.log("Polling error");

      }

    }

    const interval = setInterval(checkOrders,60000);

    return ()=>clearInterval(interval);

  },[restaurantId]);

  /*
  ---------------------------------------------
  NOTIFICATION
  ---------------------------------------------
  */

  const showNotification = (order,title)=>{

    if("Notification" in window && Notification.permission==="granted"){

      const notification = new Notification(`🔔 ${title}`,{

        body:`Table ${order.tableNumber || "NA"} • ₹${order.estimatedTotal}`,
        icon:"/favicon.ico"

      });

      notification.onclick = ()=>{

        window.focus();
        router.push("/dashboard/orders");

      }

    }

  }

  /*
  ---------------------------------------------
  UI
  ---------------------------------------------
  */

  return (

    <div className={`flex flex-col lg:flex-row min-h-screen ${isAlerting?"bg-orange-50":""}`}>

      <Toaster position="top-center"/>

      <Sidebar/>

      <main className="flex-1 w-full bg-gray-50 relative">

        {children}

      </main>

      {isOffline && (

        <div className="fixed inset-0 flex items-center justify-center bg-black/50">

          <div className="bg-white p-6 rounded-xl text-center">

            <WifiOff size={40}/>

            <h2 className="text-xl font-bold mt-3">Connection Lost</h2>

            <button
            onClick={()=>window.location.reload()}
            className="mt-4 bg-black text-white px-6 py-2 rounded"
            >

            <RefreshCw size={16}/> Retry

            </button>

          </div>

        </div>

      )}

    </div>

  )

}