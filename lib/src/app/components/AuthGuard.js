// // "use client";
// // import { useEffect, useState } from "react";
// // import { useRouter, usePathname } from "next/navigation";

// // export default function AuthGuard({ children }) {
// //   const router = useRouter();
// //   const pathname = usePathname();
// //   const [isAuthorized, setIsAuthorized] = useState(false);

// //   useEffect(() => {
// //     const token = localStorage.getItem("token");

// //     if (!token) {
// //       // If no token, send them to login
// //       router.push("/login");
// //     } else {
// //       // If token exists, allow them to see the dashboard
// //       setIsAuthorized(true);
// //     }
// //   }, [router, pathname]);

// //   // Show a loading spinner while checking authorization
// //   if (!isAuthorized) {
// //     return (
// //       <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC]">
// //         <div className="flex flex-col items-center gap-4">
// //           <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-[#FF4C00]"></div>
// //           <p className="text-slate-400 font-bold animate-pulse">Verifying Access...</p>
// //         </div>
// //       </div>
// //     );
// //   }

// //   return children;
// // }


// "use client";

// import { useEffect } from "react";
// import { usePathname, useRouter } from "next/navigation";
// import { useAuth } from "../context/AuthContext";

// export default function AuthGuard({ children }) {

//   const { user, loading2 } = useAuth();
//   const router = useRouter();
//   const pathname = usePathname();

//   useEffect(() => {

//     if (loading2) return;

//     const isAuthPage =
//       pathname === "/login" || pathname === "/signup";

//     /*
//     --------------------------------------------------
//     If user already logged in → block login/signup
//     --------------------------------------------------
//     */

//     if (user && isAuthPage) {
//       router.replace("/dashboard/orders");
//     }
  

//   }, [user, loading2, pathname, router]);

//   /*
//   --------------------------------------------------
//   Show loader while session is loading
//   --------------------------------------------------
//   */

//   if (loading2) {
//     return (
//       <div className="flex items-center justify-center min-h-screen text-gray-500 text-lg">
//         Loading session...
//       </div>
//     );
//   }

//   return children;
// }


"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "../context/AuthContext";

export default function AuthGuard({ children }) {

  const { user, loading2 } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  const isAuthPage =
    pathname === "/login" || pathname === "/signup";

  const isDashboardRoute =
    pathname.startsWith("/dashboard");

  useEffect(() => {

    if (loading2) return;

    // Logged in user should not see login/signup
    if (user && isAuthPage) {
      router.replace("/dashboard/orders");
    }
    

  }, [user, loading2, pathname, router]);

  /*
  Important fix:
  Only block loading on login/signup pages.
  Dashboard routes are already protected by middleware.
  */

  if (loading2 && isAuthPage) {
    return (
      <div className="flex items-center justify-center min-h-screen text-gray-500 text-lg">
        Loading session...
      </div>
    );
  }

  return children;
}