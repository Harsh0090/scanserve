// Add this component to your Landing Page / Home Page
import Script from "next/script";
import apiConfig from "@/utils/apiConfig";
export function TrialFloatingBadge({ daysLeft }) {
    if (daysLeft === null) return null;


    const handleUpgrade = async () => {
        console.log("click      ")
        console.log("Razorpay key:", process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID);

        const token = localStorage.getItem("token");

        if (!token) {
            alert("Please login first");
            return;
        }

        // 1️⃣ Create order on backend
        const res = await fetch(`${apiConfig?.BASE_URL}/api/payment/create`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${token}`,
            },
        });

        const data = await res.json();

        if (!res.ok) {
            alert(data.message || "Payment init failed");
            return;
        }

        // 2️⃣ Open Razorpay
        const options = {
            key: process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID,
            amount: data.amount,
            currency: "INR",
            order_id: data.orderId,
            name: "Restaurant Ordering Pro",
            description: "Monthly Subscription",
            // handler: async function (response) {
            //     // 3️⃣ Verify payment
            //     const verifyRes = await fetch("http://localhost:5000/api/payment/verify", {
            //         method: "POST",
            //         headers: {
            //             "Content-Type": "application/json",
            //             Authorization: `Bearer ${token}`,
            //         },
            //         body: JSON.stringify(response),
            //     });

            //     const verifyData = await verifyRes.json();

            //     if (verifyRes.ok) {
            //         alert("Payment successful 🎉");
            //         window.location.reload();
            //     } else {
            //         alert(verifyData.message || "Payment verification failed");
            //     }
            // },
            // theme: {
            //     color: "#F97316",
            // },

            handler: async function (response) {
                const verifyRes = await fetch(`${API_BASE}/api/payment/verify`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        Authorization: `Bearer ${token}`,
                    },
                    body: JSON.stringify({
                        razorpay_order_id: response.razorpay_order_id,
                        razorpay_payment_id: response.razorpay_payment_id,
                        razorpay_signature: response.razorpay_signature,
                    }),
                });

                const data = await verifyRes.json();

                if (!verifyRes.ok) {
                    alert(data.message || "Verification failed");
                    return;
                }

                alert("Payment successful 🎉");
                window.location.reload();
            }
        };

        const razorpay = new window.Razorpay(options);
        razorpay.open();
    };


    return (
        <>
            <Script
                src="https://checkout.razorpay.com/v1/checkout.js"
                strategy="lazyOnload"
            />
            <div className="fixed bottom-8 right-8 z-[60] animate-bounce-slow">
                <div className="bg-white border-2 border-orange-500 rounded-2xl p-4 shadow-2xl flex items-center gap-4 max-w-xs">
                    <div className="bg-orange-100 p-2 rounded-xl text-2xl">⏳</div>
                    <div>
                        <p className="text-[10px] font-black text-orange-600 uppercase">Trial Ending</p>
                        <p className="text-sm font-bold text-gray-900">{daysLeft} Days Remaining</p>
                        <button
                            onClick={handleUpgrade}
                            className="text-xs font-bold text-blue-600 hover:underline"
                        >
                            Lock in Pro features →
                        </button>
                    </div>
                </div>
            </div>
        </>

    );
}