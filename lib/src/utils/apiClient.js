// // // export async function apiFetch(url, options = {}) {
// // //   const API_BASE = "http://localhost:5000";
// // //   const token = localStorage.getItem("token"); // 🔥 IMPORTANT

// // //   const res = await fetch(`${API_BASE}${url}`, {
// // //     ...options,
// // //     headers: {
// // //       "Content-Type": "application/json",
// // //       Authorization: token ? `Bearer ${token}` : "",
// // //       ...(options.headers || {}),
// // //     },
// // //   });

// // //   const data = await res.json();

// // //   if (res.status === 402 && data.code === "TRIAL_EXPIRED") {
// // //     window.dispatchEvent(
// // //       new CustomEvent("trial-expired", {
// // //         detail: data.contact,
// // //       })
// // //     );
// // //     return null;
// // //   }

// // //   if (!res.ok) {
// // //     throw new Error(data.message || "Request failed");
// // //   }

// // //   return data;
// // // }




// // export async function apiFetch(url, options = {}) {
// //   const API_BASE = "http://localhost:5000";

// //   const res = await fetch(`${API_BASE}${url}`, {
// //     ...options,

// //     credentials: "include",   // 🔥🔥🔥 THIS IS THE NEW TOKEN

// //     headers: {
// //       "Content-Type": "application/json",
// //       ...(options.headers || {}),
// //     },
// //   });

// //   const data = await res.json();

// //   if (res.status === 402 && data.code === "TRIAL_EXPIRED") {
// //     window.dispatchEvent(
// //       new CustomEvent("trial-expired", {
// //         detail: data.contact,
// //       })
// //     );
// //     return null;
// //   }

// //   if (!res.ok) {
// //     throw new Error(data.message || "Request failed");
// //   }

// //   return data;
// // }


// const API_BASE = "http://localhost:5000";

// export async function apiFetch(url, options = {}) {
//   try {
//     const res = await fetch(`${API_BASE}${url}`, {
//       credentials: "include", // ✅ CRITICAL FOR COOKIES
//       headers: {
//         "Content-Type": "application/json",
//         ...(options.headers || {}),
//       },
//       ...options,
//     });

//     const data = await res.json();

//     if (!res.ok) {
//       throw new Error(data.message || "Request failed");
//     }

//     return data;

//   } catch (err) {
//     console.error("API ERROR:", err.message);
//     throw err;
//   }
// }


// const BASE_URL = "http://localhost:5000";
// const BASE_URL = "https://restaurant-model-backend.onrender.com";
// import apiConfig from "../utils/apiConfig";


// export async function apiFetch(url, options = {}) {
//   try {
//     const res = await fetch(`${apiConfig?.BASE_URL}${url}`, {
//       credentials: "include",   // 🔥 REQUIRED FOR COOKIES
//       ...options,
//       headers: {
//         ...(options.body instanceof FormData
//           ? {}  // ❌ Don't set JSON header for FormData
//           : { "Content-Type": "application/json" }),
//         ...(options.headers || {}),
//       },
//     });

//     const data = await res.json().catch(() => ({}));

//     if (!res.ok) {
//       throw new Error(data.message || "Request failed");
//     }

//     return data;

//   } catch (err) {
//     console.error("API ERROR:", err.message);
//     throw err;
//   }
// }



// import apiConfig from "../utils/apiConfig";

// export async function apiFetch(url, options = {}) {
//   try {

//     const res = await fetch(`${apiConfig?.BASE_URL}${url}`, {
//       credentials: "include",
//       ...options,
//       headers: {
//         ...(options.body instanceof FormData
//           ? {}
//           : { "Content-Type": "application/json" }),
//         ...(options.headers || {}),
//       },
//     });

//     const data = await res.json().catch(() => ({}));

//     /*
//      🔥 GLOBAL TRIAL EXPIRED HANDLER
//     */
//     if (data?.code === "TRIAL_EXPIRED") {

//       // Prevent multiple popups
//       if (!window.__trialPopupShown) {
//         window.__trialPopupShown = true;

//         window.dispatchEvent(
//           new CustomEvent("trialExpired")
//         );
//       }

//       return Promise.reject(data);
//     }

//     if (!res.ok) {
//       throw new Error(data.message || "Request failed");
//     }

//     return data;

//   } catch (err) {
//     console.error("API ERROR:", err.message);
//     throw err;
//   }
// }




import apiConfig from "../utils/apiConfig";

export async function apiFetch(url, options = {}) {
  try {

    const res = await fetch(`${apiConfig?.BASE_URL}${url}`, {
      credentials: "include",
      ...options,
      headers: {
        ...(options.body instanceof FormData
          ? {}
          : { "Content-Type": "application/json" }),
        ...(options.headers || {}),
      },
    });

    const data = await res.json().catch(() => ({}));
    console.log(data, "Data");
    /*
     🔥 TRIAL EXPIRED DETECTION
    */
    if (data?.subscriptionStatus === "EXPIRED") {
console.log("inside the condition ")
      if (typeof window !== "undefined") {
        window.dispatchEvent(new Event("TRIAL_EXPIRED"));
      }

      return Promise.reject(data);
    }

    if (!res.ok) {
      throw new Error(data.message || "Request failed");
    }

    return data;

  } catch (err) {
    console.error("API ERROR:", err.message);
    throw err;
  }
}