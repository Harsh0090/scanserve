import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/layout.dart';
import 'utils/apiClient.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with fallback
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
    print("✅ Firebase initialized successfully (Default)");
  } catch (e) {
    print("⚠️ Default Firebase init failed, trying manual fallback: $e");
    try {
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
      log("🚀 main: Setting up Background Handler...");
      FirebaseMessagingService.setupBackgroundHandler();
    } catch (e) {
      print("⚠️ main: Error setting background handler: $e");
    }
  }

  await initCookies();

  if (isFirebaseInitialized) {
    final messagingService = FirebaseMessagingService();
    log("🚀 main: Initializing Messaging Service...");
    messagingService
        .init()
        .then((_) {
          log("✅ main: Messaging Service initialized.");
        })
        .catchError((e) {
          print("❌ main: Error initializing messaging: $e");
        });
  }

  runApp(const ProviderScope(child: RootLayout()));
}
