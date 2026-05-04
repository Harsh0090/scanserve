// // "use client";
// // import { useTrial } from "../context/TrialContext";

// // export default function TrialGuard({ children }) {
// //   const { trialExpired } = useTrial();

// //   if (!trialExpired) return children;

// //   return (
// //     <div className="pointer-events-none select-none opacity-60">
// //       {children}
// //     </div>
// //   );
// // }


// // "use client";

// // import { useTrial } from "../context/TrialContext";

// // export default function TrialGuard({ children }) {

// //   const { isTrialExpired } = useTrial();

// //   console.log(isTrialExpired, "isTrialExpired");


// //   if (isTrialExpired) {
// //     return null; // freeze app
// //   }

// //   return children;
// // }



// "use client";

// import { useTrial } from "../context/TrialContext";
// import { usePathname } from "next/navigation";

// export default function TrialGuard({ children }) {

//   const { isTrialExpired } = useTrial();
//   const pathname = usePathname();

//   // 🔥 Allow subscription page even if expired
//   const allowedRoutes = [
//     "/dashboard/IncreaseBranchLimit",
//   ];

//   const isAllowed = allowedRoutes.some(route =>
//     pathname.startsWith(route)
//   );

//   if (isTrialExpired && !isAllowed) {
//     return null;  // freeze other pages
//   }

//   return children;
// }



"use client";

import { useTrial } from "../context/TrialContext";
import { usePathname } from "next/navigation";

export default function TrialGuard({ children }) {

  const { isTrialExpired } = useTrial();
  const pathname = usePathname();

  /*
   Only protect dashboard routes
  */
  const isDashboard = pathname.startsWith("/dashboard");

  /*
   Allowed routes even if expired
  */
  const allowedRoutes = [
    "/dashboard/IncreaseBranchLimit",
  ];

  const isAllowed = allowedRoutes.some(route =>
    pathname.startsWith(route)
  );

  /*
   If not dashboard → allow
  */
  if (!isDashboard) {
    return children;
  }

  /*
   If trial expired inside dashboard
  */
  if (isTrialExpired && !isAllowed) {
    return null;
  }

  return children;
}