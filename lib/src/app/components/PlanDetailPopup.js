'use client'
import React, { useState } from 'react';

export default function PlanDetailPopup({ isOpen, onClose }) {
    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
            <div className="bg-[#FFFBEB] w-full max-w-5xl rounded-[3rem] overflow-hidden shadow-2xl flex flex-col md:flex-row relative animate-in zoom-in-95 duration-300">

                {/* Close Button */}
                <button
                    onClick={onClose}
                    className="absolute top-6 right-6 w-10 h-10 bg-white/50 hover:bg-white rounded-full flex items-center justify-center text-gray-500 transition-colors z-10"
                >
                    ✕
                </button>

                {/* Left Side: The "Restaurant Pro" Card */}
                <div className="md:w-[40%] bg-orange-600 p-10 text-white flex flex-col justify-center">
                    <div className="bg-orange-500 text-xs inline-block px-4 py-1.5 rounded-full mb-6 font-bold self-start">
                        MOST POPULAR
                    </div>
                    <h3 className="text-3xl font-black mb-2">Restaurant Pro</h3>
                    <p className="text-5xl font-black mb-8">$29<span className="text-xl opacity-70 font-medium">/mo</span></p>

                    <ul className="space-y-5 mb-10 text-lg opacity-90">
                        <li className="flex items-center gap-3">✅ Unlimited Table Orders</li>
                        <li className="flex items-center gap-3">✅ Kitchen Display System</li>
                        <li className="flex items-center gap-3">✅ WhatsApp Notifications</li>
                        <li className="flex items-center gap-3">✅ Inventory Management</li>
                        <li className="flex items-center gap-3">✅ Smart Upsell System</li>
                    </ul>

                    <a href="/signup" className="w-full py-4 rounded-2xl bg-white text-orange-600 text-center font-black text-lg hover:shadow-xl transition-all active:scale-95">
                        Start Free Trial Now
                    </a>
                </div>

                {/* Right Side: The Flow Explanation */}
                <div className="flex-1 p-10 md:p-14 overflow-y-auto max-h-[90vh]">
                    <h2 className="text-2xl font-black text-gray-900 mb-8">How it works for you:</h2>

                    <div className="space-y-8 relative">
                        {/* Step 1 */}
                        <div className="flex gap-6">
                            <div className="w-12 h-12 rounded-2xl bg-orange-100 text-orange-600 flex items-center justify-center font-black text-xl shrink-0">1</div>
                            <div>
                                <h4 className="font-bold text-gray-900 text-lg">Sign Up & Profile</h4>
                                <p className="text-gray-500 text-sm mt-1 leading-relaxed">Enter your restaurant name, location, and owner details. This creates your private portal.</p>
                            </div>
                        </div>

                        {/* Step 2 */}
                        <div className="flex gap-6">
                            <div className="w-12 h-12 rounded-2xl bg-orange-600 text-white flex items-center justify-center font-black text-xl shrink-0 shadow-lg shadow-orange-200">2</div>
                            <div>
                                <h4 className="font-bold text-gray-900 text-lg">Secure Payment</h4>
                                <p className="text-gray-700 text-sm mt-1 leading-relaxed font-semibold">Complete your subscription payment. Once successful, our system **instantly activates** your Dashboard and Public Menu URL.</p>
                                <div className="mt-3 flex gap-2">
                                    <span className="text-[10px] bg-green-100 text-green-700 px-2 py-1 rounded font-bold">CREDIT CARD</span>
                                    <span className="text-[10px] bg-green-100 text-green-700 px-2 py-1 rounded font-bold">UPI / WALLETS</span>
                                </div>
                            </div>
                        </div>
                        {/* Step 3 */}
                        <div className="flex gap-6">
                            <div className="w-12 h-12 rounded-2xl bg-orange-100 text-orange-600 flex items-center justify-center font-black text-xl shrink-0">3</div>
                            <div>
                                <h4 className="font-bold text-gray-900 text-lg">Add Menu & Go Public</h4>
                                <p className="text-gray-500 text-sm mt-1 leading-relaxed">Login to your active dashboard, add your dishes with **Upsell Suggestions**, and your QR codes are ready for customers to scan!</p>
                            </div>
                        </div>

                        {/* Step 4 */}
                        <div className="flex gap-6">
                            <div className="flex flex-col items-center">
                                <div className="w-10 h-10 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center font-bold">4</div>
                            </div>
                            <div>
                                <h4 className="font-bold text-gray-800 text-lg">Go Live</h4>
                                <p className="text-gray-500 text-sm mt-1 leading-relaxed">Print your QR codes and place them on tables. Customers scan and order—no app required.</p>
                            </div>
                        </div>
                    </div>

                    {/* Customer Support Footer */}
                    <div className="mt-12 p-6 bg-white rounded-3xl border border-orange-100 flex items-center justify-between">
                        <div>
                            <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Need help setting up?</p>
                            <p className="text-gray-800 font-bold mt-1">Our team is available 24/7</p>
                        </div>
                        <a
                            href="tel:+1234567890"
                            className="bg-gray-900 text-white px-5 py-3 rounded-xl font-bold flex items-center gap-2 hover:bg-gray-800 transition-colors"
                        >
                            📞 +91 8739901216
                        </a>
                    </div>
                </div>
            </div>
        </div>
    );
}