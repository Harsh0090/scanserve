// // "use client";
// // import { useEffect, useState } from "react";
// // import { apiFetch } from "../utils/apiClient";

// // export function useTrialBill() {
// //   const [bill, setBill] = useState(null);
// //   const [loading, setLoading] = useState(true);

// //   useEffect(() => {
// //     apiFetch("/api/subscription/trial-bill")
// //       .then((data) => {
// //         if (data) setBill(data);
// //       })
// //       .finally(() => setLoading(false));
// //   }, []);

// //   return { bill, loading };
// // }


// // 📁 hooks/useTrialBill.js (NEW FILE)
// "use client";
// import { useEffect, useState } from "react";
// import { apiFetch } from "../utils/apiClient";

// export function useTrialBill() {
//   const [bill, setBill] = useState(null);
//   const [loading, setLoading] = useState(true);

//   useEffect(() => {
//     apiFetch("/api/subscription/trial-bill")
//       .then((data) => {
//         if (data) setBill(data);
//       })
//       .finally(() => setLoading(false));
//   }, []);

//   return { bill, loading };
// }

"use client";
import { useEffect, useState } from "react";
import { apiFetch } from "../utils/apiClient";

export function useTrialBill() {
  const [bill, setBill] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch("/api/subscription/trial-bill")
      .then((data) => {
        if (data) setBill(data);
      })
      .finally(() => setLoading(false));
  }, []);

  return { bill, loading };
}