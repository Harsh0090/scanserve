// // // ✅ FILE 4 — layout.js (FIXED HYDRATION)

// // // 📁 src/app/layout.js

// // import { OnboardingProvider } from "./context/OnboardingContext";
// // import { TrialProvider } from "./context/TrialContext";
// // import { AuthProvider } from "./context/AuthContext";

// // import TrialGuard from "./components/TrialGuard";
// // import TrialExpiredModal from "./components/TrialExpiredModal";
// // import SignupSuccessModal from "./components/SignupSuccessModal";
// // import { Toaster } from "react-hot-toast";
// // import "./globals.css";

// // export default function RootLayout({ children }) {
// //   return (
// //     // 1. Added suppressHydrationWarning to <html>
// //     <html lang="en" suppressHydrationWarning>
// //       {/* 2. Added suppressHydrationWarning to <body> */}
// //       <body className="antialiased" suppressHydrationWarning>
// //         <AuthProvider>
// //           <OnboardingProvider>
// //             <TrialProvider>

// //               {/* 🔒 FREEZE APP */}
// //               <TrialGuard>
// //                 {children}
// //               </TrialGuard>

// //               {/* GLOBAL MODALS */}
// //               <SignupSuccessModal />
// //               <TrialExpiredModal />

// //               <Toaster position="bottom-center" />
// //             </TrialProvider>
// //           </OnboardingProvider>
// //         </AuthProvider>
// //       </body>
// //     </html>
// //   );
// // }

// // //layout.js
// // "use client";

// // import { usePathname } from "next/navigation";
// // import { OnboardingProvider } from "./context/OnboardingContext";
// // import { TrialProvider } from "./context/TrialContext";
// // import { AuthProvider } from "./context/AuthContext";

// // import TrialGuard from "./components/TrialGuard";
// // import TrialExpiredModal from "./components/TrialExpiredModal";
// // import SignupSuccessModal from "./components/SignupSuccessModal";
// // import { Toaster } from "react-hot-toast";
// // import "./globals.css";

// // export default function RootLayout({ children }) {
// //   const pathname = usePathname();

// //   // 🚫 DEFINE EXCLUDED ROUTES
// //   // 1. Static routes: /login and /signup
// //   // 2. Dynamic Menu routes: /[id]/[tableNumber] 
// //   // We check if the path starts with a slash followed by content, but isn't 'dashboard' or 'admin'
// //   const isExcludedRoute =
// //     pathname === "/login" || pathname === "/signup";

    
// //   return (
// //     <html lang="en" suppressHydrationWarning>
// //       <body className="antialiased" suppressHydrationWarning>
// //         <AuthProvider>
// //           <OnboardingProvider>
// //             <TrialProvider>

// //               {/* 🔒 TRIAL GUARD LOGIC */}
// //               {isExcludedRoute ? (
// //                 // Bypass guard for Login, Signup, and Customer Menu
// //                 <>{children}</>
// //               ) : (
// //                 // Enforce guard for Dashboard and other Admin areas
// //                 <TrialGuard>
// //                   {children}
// //                 </TrialGuard>
// //               )}

// //               {/* GLOBAL MODALS */}
// //               <SignupSuccessModal />

// //               {/* 🚫 Only show Expired Modal if the route is NOT excluded */}
// //               {!isExcludedRoute && <TrialExpiredModal />}

// //               <Toaster position="bottom-center" />
// //             </TrialProvider>
// //           </OnboardingProvider>
// //         </AuthProvider>
// //       </body>
// //     </html>
// //   );
// // }


// // layout.js

// import { AuthProvider } from "./context/AuthContext";
// import { OnboardingProvider } from "./context/OnboardingContext";
// import { TrialProvider } from "./context/TrialContext";

// import TrialGuard from "./components/TrialGuard";
// import TrialExpiredModal from "./components/TrialExpiredModal";
// import SignupSuccessModal from "./components/SignupSuccessModal";

// import { Toaster } from "react-hot-toast";
// import "./globals.css";

// export const metadata = {
//   title: "ScanServe",
//   icons: {
//     icon: "/Favicon.png",
//   },
// };

// export default function RootLayout({ children }) {

//   return (
//     <html lang="en">
//       <body className="antialiased">

//         <AuthProvider>
//           <OnboardingProvider>
//             <TrialProvider>

//               {children}

//               <SignupSuccessModal />
//               <TrialExpiredModal />

//               <Toaster position="bottom-center" />

//             </TrialProvider>
//           </OnboardingProvider>
//         </AuthProvider>

//       </body>
//     </html>
//   );
// }



// layout.js

import { AuthProvider } from "./context/AuthContext";
import { OnboardingProvider } from "./context/OnboardingContext";
import { TrialProvider } from "./context/TrialContext";

import AuthGuard from "./components/AuthGuard";
import TrialGuard from "./components/TrialGuard";
import TrialExpiredModal from "./components/TrialExpiredModal";
import SignupSuccessModal from "./components/SignupSuccessModal";

import { Toaster } from "react-hot-toast";
import "./globals.css";

export const metadata = {
  title: "ScanServe",
  icons: {
    icon: "/Favicon.png",
  },
};

export default function RootLayout({ children }) {

  return (
    <html lang="en">
      <body className="antialiased">

        <AuthProvider>
          <OnboardingProvider>
            <TrialProvider>

              <AuthGuard>

                <TrialGuard>
                  {children}
                </TrialGuard>

              </AuthGuard>

              <SignupSuccessModal />
              <TrialExpiredModal />

              <Toaster position="bottom-center" />

            </TrialProvider>
          </OnboardingProvider>
        </AuthProvider>

      </body>
    </html>
  );
}