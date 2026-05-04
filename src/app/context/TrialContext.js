// // // // // //TrialContext.js
// // // // // "use client";
// // // // // import { createContext, useContext, useState } from "react";

// // // // // const TrialContext = createContext(null);

// // // // // export function TrialProvider({ children }) {
// // // // //   const [trialExpired, setTrialExpired] = useState(false);
// // // // //   const [contact, setContact] = useState(null);

// // // // //   const triggerTrialExpired = (contactNumber) => {
// // // // //     setContact(contactNumber || "8739901216");
// // // // //     setTrialExpired(true);
// // // // //   };

// // // // //   const closeTrialModal = () => setTrialExpired(false);

// // // // //   return (
// // // // //     <TrialContext.Provider
// // // // //       value={{ trialExpired, contact, triggerTrialExpired, closeTrialModal }}
// // // // //     >
// // // // //       {children}
// // // // //     </TrialContext.Provider>
// // // // //   );
// // // // // }

// // // // // export const useTrial = () => useContext(TrialContext);







// // // // // ✅ FILE 1 — TrialContext.js (FIXED)

// // // // // 📁 src/context/TrialContext.js

// // // // "use client";
// // // // import { createContext, useContext, useState } from "react";

// // // // const TrialContext = createContext(null);

// // // // export function TrialProvider({ children }) {
// // // //   const [trialExpired, setTrialExpired] = useState(false);
// // // //   const [contact, setContact] = useState("8739901214");

// // // //   // 🔒 CAN ONLY GO TRUE — NEVER FALSE
// // // //   const triggerTrialExpired = (contactNumber) => {
// // // //     setContact(contactNumber || "8739901214");
// // // //     setTrialExpired(true);
// // // //   };

// // // //   return (
// // // //     <TrialContext.Provider
// // // //       value={{
// // // //         trialExpired,
// // // //         contact,
// // // //         triggerTrialExpired,
// // // //       }}
// // // //     >
// // // //       {children}
// // // //     </TrialContext.Provider>
// // // //   );
// // // // }

// // // // export const useTrial = () => useContext(TrialContext);



// // // // 📁 context/TrialContext.js (CRITICAL FIX)
// // // "use client";
// // // import { createContext, useContext, useEffect, useState } from "react";

// // // const TrialContext = createContext(null);

// // // export function TrialProvider({ children }) {
// // //   const [trialExpired, setTrialExpired] = useState(false);
// // //   const [contact, setContact] = useState(null);

// // //   const triggerTrialExpired = (contactNumber) => {
// // //     setContact(contactNumber || "8739901214");
// // //     setTrialExpired(true);
// // //   };

// // //   useEffect(() => {
// // //     const handler = (e) => triggerTrialExpired(e.detail);
// // //     window.addEventListener("trial-expired", handler);
// // //     return () => window.removeEventListener("trial-expired", handler);
// // //   }, []);

// // //   return (
// // //     <TrialContext.Provider value={{ trialExpired, contact }}>
// // //       {children}
// // //     </TrialContext.Provider>
// // //   );
// // // }

// // // export const useTrial = () => useContext(TrialContext);









// // "use client";

// // import { createContext, useContext, useState } from "react";

// // const TrialContext = createContext();

// // export function TrialProvider({ children }) {

// //   const [isTrialExpired, setIsTrialExpired] = useState(false);

// //   const triggerTrialExpired = () => {
// //     setIsTrialExpired(true);
// //   };

// //   return (
// //     <TrialContext.Provider
// //       value={{
// //         isTrialExpired,
// //         triggerTrialExpired,
// //       }}
// //     >
// //       {children}
// //     </TrialContext.Provider>
// //   );
// // }

// // export function useTrial() {
// //   return useContext(TrialContext);
// // }



// "use client";

// import { createContext, useContext, useEffect, useState } from "react";

// const TrialContext = createContext();

// export function TrialProvider({ children }) {

//   const [isTrialExpired, setIsTrialExpired] = useState(false);

//   useEffect(() => {

//     const handler = () => {
//       setIsTrialExpired(true);
//     };

//     window.addEventListener("TRIAL_EXPIRED", handler);

//     return () => {
//       window.removeEventListener("TRIAL_EXPIRED", handler);
//     };

//   }, []);

//   return (
//     <TrialContext.Provider
//       value={{
//         isTrialExpired,
//       }}
//     >
//       {children}
//     </TrialContext.Provider>
//   );
// }

// export function useTrial() {
//   return useContext(TrialContext);
// }





"use client";

import { createContext, useContext, useEffect, useState } from "react";
import { useAuth } from "./AuthContext";

const TrialContext = createContext();

export function TrialProvider({ children }) {

  const { user } = useAuth();   // 🔥 pull subscription info
  const [isTrialExpired, setIsTrialExpired] = useState(false);

  /*
   🔥 1️⃣ React to backend subscription state
  */
  useEffect(() => {

    if (!user) return;

    if (
      user.subscriptionStatus === "EXPIRED" ||
      user.subscriptionStatus === "SUSPENDED"
    ) {
      console.log("inside the if contiton ")
      setIsTrialExpired(true);
    } else {
      console.log("inside the else condition")
      setIsTrialExpired(false);
    }

  }, [user]);

  /*
   🔥 2️⃣ Fallback: listen to API-level block
  */
  useEffect(() => {

    const handler = () => {
      setIsTrialExpired(true);
    };

    window.addEventListener("TRIAL_EXPIRED", handler);

    return () => {
      window.removeEventListener("TRIAL_EXPIRED", handler);
    };

  }, []);

  return (
    <TrialContext.Provider value={{ isTrialExpired }}>
      {children}
    </TrialContext.Provider>
  );
}

export function useTrial() {
  return useContext(TrialContext);
}