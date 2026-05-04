// Flutter's default entry point — lib/main.dart.
// The app code follows the Next.js src/app folder convention.
// lib/src is a directory junction pointing to the project's src/ folder,
// allowing package:frontend/src/... imports to resolve correctly.
import 'dart:developer';
import 'package:ScanServe/src/app/layout.dart';
import 'package:ScanServe/src/services/firebase_messaging_service.dart';
import 'package:ScanServe/src/utils/apiClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  bool isFirebaseInitialized = false;
  try {
    // Attempt default initialization first
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
    print("✅ Firebase initialized successfully (Default)");
  } catch (e) {
    print("⚠️ Default Firebase init failed, trying manual fallback: $e");
    try {
      // Manual fallback for Android (using values from google-services.json)
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDYNmEZNBKdwu31kpZH8tKSbK7EALiqR7k",
          appId: "1:812659576966:android:d7ae53d8cf4ce90b478107",
          messagingSenderId: "812659576966",
          projectId: "scanserve-a86d5",
          storageBucket: "scanserve-a86d5.firebasestorage.app",
        ),
      );
      isFirebaseInitialized = true;
      print("✅ Firebase initialized successfully (Manual Fallback)");
    } catch (e2) {
      print(
        "🔥 FIREBASE CRITICAL ERROR: Both default and manual init failed: $e2",
      );
    }
  }

  if (isFirebaseInitialized) {
    try {
      FirebaseMessagingService.setupBackgroundHandler();
    } catch (e) {
      print("⚠️ Error setting background handler: $e");
    }
  }

  // Initialize Cookies (CRITICAL for session)
  await initCookies();

  // Initialize Messaging Service (Async, don't block main)
  if (isFirebaseInitialized) {
    final messagingService = FirebaseMessagingService();
    messagingService.init().catchError(
      (e) => log("Error initializing messaging: $e"),
    );
  }

  runApp(const ProviderScope(child: RootLayout()));
}
