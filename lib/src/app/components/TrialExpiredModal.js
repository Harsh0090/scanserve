// "use client";
// import { useTrial } from "../context/TrialContext";
// import { useTrialBill } from "../../hooks/useTrialBill";
// import Link from "next/link";

// export default function TrialExpiredModal() {
//   const { trialExpired, contact } = useTrial();
//   const { bill, loading } = useTrialBill();

//   if (!trialExpired) return null;

//   return (
//     <div className="fixed inset-0 z-[9999] bg-slate-900/80 backdrop-blur-sm flex items-center justify-center p-4">
//       <div className="bg-white rounded-3xl shadow-2xl w-full max-w-[400px] overflow-hidden border border-slate-100">
        
//         {/* Header Section */}
//         <div className="bg-red-50 py-4 border-b border-red-100">
//           <h2 className="text-red-600 font-bold text-center tracking-wide uppercase text-sm">
//             Trial Account Expired
//           </h2>
//         </div>

//         <div className="p-8">
//           {loading ? (
//             <div className="flex flex-col items-center py-6">
//               <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mb-4"></div>
//               <p className="text-slate-500 text-sm">Calculating your final bill...</p>
//             </div>
//           ) : bill ? (
//             <div className="space-y-4">
//               {/* Billing Details */}
//               <div className="space-y-2 pb-4 border-b border-dashed border-slate-200">
//                 <div className="flex justify-between text-slate-600">
//                   <span>Branches Used</span>
//                   <span className="font-bold text-slate-900">{bill.usedBranches}</span>
//                 </div>
//                 <div className="flex justify-between text-slate-600">
//                   <span>Price per Branch</span>
//                   <span className="font-semibold text-slate-900">₹{bill.pricePerBranch}</span>
//                 </div>
//               </div>

//               {/* Total Section */}
//               <div className="flex justify-between items-center py-2">
//                 <span className="text-slate-900 font-bold text-lg">Total Amount</span>
//                 <span className="text-2xl font-black text-indigo-600">
//                   ₹{bill.totalAmount}
//                 </span>
//               </div>

//               {/* Action Buttons */}
//               <div className="pt-4 space-y-3">
//                 <Link 
//                   href="/dashboard/IncreaseBranchLimit"
//                   className="block w-full bg-indigo-600 hover:bg-indigo-700 text-white text-center py-4 rounded-2xl font-bold transition-all shadow-lg shadow-indigo-100 active:scale-[0.98]"
//                 >
//                   Pay & Upgrade Now
//                 </Link>

//                 <div className="bg-slate-50 rounded-2xl p-4 text-center border border-slate-100">
//                   <p className="text-xs text-slate-500 font-medium mb-1">
//                     Need custom pricing?
//                   </p>
//                   <a 
//                     href={`tel:${contact}`}
//                     className="text-slate-900 font-bold hover:text-indigo-600 transition-colors"
//                   >
//                     Contact Sales: {contact}
//                   </a>
//                 </div>
//               </div>
//             </div>
//           ) : (
//             <p className="text-center text-slate-500">Could not load billing info. Please contact support.</p>
//           )}
//         </div>

//         {/* Footer Note */}
//         <div className="pb-6 text-center px-8">
//           <p className="text-[10px] text-slate-400 leading-tight">
//             Admin access is restricted until the subscription is active. 
//             By upgrading, you agree to our Terms of Service.
//           </p>
//         </div>
//       </div>
//     </div>
//   );
// }


// "use client";

// import { useTrial } from "../context/TrialContext";
// import { useRouter } from "next/navigation";

// export default function TrialExpiredModal() {

//   const { isTrialExpired } = useTrial();
//   console.log(isTrialExpired,"isTrialExpired")
//   const router = useRouter();

//   if (!isTrialExpired) return null;

//   return (
//     <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[9999]">
//       <div className="bg-white p-8 rounded-xl text-center">
//         <h2 className="text-xl font-bold mb-4">
//           Trial Expired
//         </h2>
//         <p className="mb-6">
//           Your trial period has ended.
//         </p>
//         <button
//           className="bg-orange-500 text-white px-6 py-2 rounded-lg"
//           onClick={() => router.push("/dashboard/IncreaseBranchLimit")}
//         >
//           Buy Subscription
//         </button>
//       </div>
//     </div>
//   );
// }




// "use client";

// import { useTrial } from "../context/TrialContext";
// import { usePathname, useRouter } from "next/navigation";

// export default function TrialExpiredModal() {

//   const { isTrialExpired } = useTrial();
//   const pathname = usePathname();
//   const router = useRouter();

//   const billingRoute = "/dashboard/IncreaseBranchLimit";

//   // 🔥 If not expired → no modal
//   if (!isTrialExpired) return null;

//   // 🔥 If already on billing page → DO NOT block
//   if (pathname.startsWith(billingRoute)) {
//     return null;
//   }

//   return (
//     <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[9999]">
//       <div className="bg-white p-8 rounded-xl text-center">
//         <h2 className="text-xl font-bold mb-4">
//           Trial Expired
//         </h2>
//         <p className="mb-6">
//           Your trial period has ended.
//         </p>
//         <button
//           className="bg-orange-500 text-white px-6 py-2 rounded-lg"
//           onClick={() => router.push(billingRoute)}
//         >
//           Buy Subscription
//         </button>
//       </div>
//     </div>
//   );
// }


"use client";

import { useTrial } from "../context/TrialContext";
import { usePathname, useRouter } from "next/navigation";

export default function TrialExpiredModal() {

  const { isTrialExpired } = useTrial();
  const pathname = usePathname();
  const router = useRouter();

  const billingRoute = "/dashboard/IncreaseBranchLimit";

  /*
   Only show inside dashboard
  */
  const isDashboard = pathname.startsWith("/dashboard");

  /*
   If not dashboard → never show modal
  */
  if (!isDashboard) return null;

  /*
   If trial not expired
  */
  if (!isTrialExpired) return null;

  /*
   If already on billing page
  */
  if (pathname.startsWith(billingRoute)) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[9999]">
      <div className="bg-white p-8 rounded-xl text-center">
        <h2 className="text-xl font-bold mb-4">
          Trial Expired
        </h2>

        <p className="mb-6">
          Your trial period has ended.
        </p>

        <button
          className="bg-orange-500 text-white px-6 py-2 rounded-lg"
          onClick={() => router.push(billingRoute)}
        >
          Buy Subscription
        </button>

      </div>
    </div>
  );
}