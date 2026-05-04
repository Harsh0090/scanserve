import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/apiClient.dart';

/// Top-level background message handler.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("FCM: Handling background message: ${message.messageId}");
  log("FCM: Background Data: ${message.data}");

  // Support both 'type' and 'status' fields, and trim whitespace
  String type = (message.data['type'] ?? message.data['status'] ?? '')
      .toString()
      .trim()
      .toUpperCase();

  if (message.notification == null || type == 'READY') {
    log("FCM: Forcing internal notification for type: $type");
    await FirebaseMessagingService().showNotificationInternal(message);
  }
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  FirebaseMessaging get _messaging {
    if (Firebase.apps.isEmpty) {
      throw StateError("Firebase not initialized");
    }
    return FirebaseMessaging.instance;
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging and Local Notifications.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        log("Firebase not initialized. Skipping messaging init.");
        return;
      }

      // 1. Request Permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('User granted permission');
      } else {
        log('User declined or has not accepted permission');
      }

      // 2. Setup Local Notifications for Foreground
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
      );

      // 3. Create Notification Channels
      const AndroidNotificationChannel defaultChannel =
          AndroidNotificationChannel(
            'default_notification_channel',
            'Default Notifications',
            description: 'This channel is used for all general notifications.',
            importance: Importance.max,
            playSound: true,
          );

      const AndroidNotificationChannel orderChannel =
          AndroidNotificationChannel(
            'order_ringing_channel_v7',
            'Order Notifications',
            description: 'Used for new order alerts with persistent ringing.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('ringing'),
          );

      const AndroidNotificationChannel readyChannel =
          AndroidNotificationChannel(
            'order_ready_channel_v1',
            'Order Ready',
            description: 'Used for alerts when an order is ready for pickup.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('order_ready'),
          );

      const AndroidNotificationChannel reorderChannel =
          AndroidNotificationChannel(
            'reorder_channel_v1',
            'Reorder Alerts',
            description: 'Used for reorder alerts.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('reorder'),
          );

      log("🚀 FCM: Creating Notification Channels...");
      final flutterLocalNotificationsPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (flutterLocalNotificationsPlugin == null) {
        log("❌ FCM: Android plugin implementation not found!");
      } else {
        await flutterLocalNotificationsPlugin.createNotificationChannel(
          defaultChannel,
        );
        await flutterLocalNotificationsPlugin.createNotificationChannel(
          orderChannel,
        );
        await flutterLocalNotificationsPlugin.createNotificationChannel(
          readyChannel,
        );
        await flutterLocalNotificationsPlugin.createNotificationChannel(
          reorderChannel,
        );
        log("✅ FCM: All Notification Channels created successfully.");
      }

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log(
          "🎁 Foreground Message: ${message.notification?.title} | Data: ${message.data}",
        );
        showNotificationInternal(message);
      });

      // 5. Handle Background/Terminated state when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log("App opened from notification: ${message.notification?.title}");
      });

      // 6. Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        log(
          "App started from terminated state via notification: ${initialMessage.notification?.title}",
        );
      }

      // 7. Get FCM Token
      String? token = await _messaging.getToken();
      log("🎁 FCM: TOKEN GENERATED: $token");

      _messaging.onTokenRefresh.listen((newToken) {
        log("🔄 FCM: Token Refreshed: $newToken");
      });

      log("✅ FCM: FirebaseMessagingService initialized successfully.");
    } catch (e, stack) {
      log("❌ FCM: Error during messaging init: $e");
      log("❌ FCM: Stacktrace: $stack");
    }
  }

  /// Shows a notification with support for persistent ringing for orders.
  Future<void> showNotificationInternal(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;
    log("🎁 FCM: Received Data Payload: $data");
    log("🎁 FCM: Notification Body: ${notification?.body}");

    // Robust type detection using both 'type' and 'status' fields
    String type = (data['type'] ?? data['status'] ?? '').toString().trim().toUpperCase();
    log("🎁 FCM: Resolved Type: $type");

    bool isOrder =
        type == 'NEW' ||
        type == 'NEW_ORDER' ||
        (type == '' && data['orderId'] != null);
    bool isReady = type == 'READY';
    bool isUpdate = type == 'UPDATE';

    String channelId = 'default_notification_channel';
    String soundResource = '';
    List<AndroidNotificationAction>? actions;

    if (isReady) {
      channelId = 'order_ready_channel_v1';
      soundResource = 'order_ready';
      actions = [
        const AndroidNotificationAction(
          'dismiss_notification',
          'OK',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ];
    } else if (isUpdate) {
      channelId = 'reorder_channel_v1';
      soundResource = 'reorder';
      actions = [
        const AndroidNotificationAction(
          'dismiss_notification',
          'OK',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ];
    } else if (isOrder) {
      channelId = 'order_ringing_channel_v7';
      soundResource = 'ringing';
      actions = [
        const AndroidNotificationAction(
          'accept_order',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'decline_order',
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      isOrder
          ? 'Order Notifications'
          : (isReady
                ? 'Order Ready'
                : (isUpdate ? 'Order Updated' : 'Default Notifications')),
      channelDescription: (isOrder || isReady || isUpdate)
          ? 'Used for new order alerts with persistent ringing.'
          : 'General alerts.',
      icon: '@mipmap/ic_launcher',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      fullScreenIntent: isOrder || isReady || isUpdate,
      category: (isOrder || isReady || isUpdate)
          ? AndroidNotificationCategory.alarm
          : null,
      onlyAlertOnce: false,
      sound: soundResource.isNotEmpty
          ? RawResourceAndroidNotificationSound(soundResource)
          : null,
      audioAttributesUsage: (isOrder || isReady || isUpdate)
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      actions: actions,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    log("🔔 FCM: Showing Notification | Channel: $channelId | Type: $type");
    log("🔔 FCM: Payload orderId: ${data['orderId']}");

    // Ensure the notification ID fits within a 32-bit signed integer (Sint31/32)
    int notificationId =
        (DateTime.now().millisecondsSinceEpoch % 100000) +
        (data['orderId'].hashCode.abs() % 100000);

    await _localNotifications.show(
      id: notificationId,
      title:
          notification?.title ??
          (isOrder ? "New Order Received!" : "Notification"),
      body:
          notification?.body ??
          (isOrder ? "You have a new order. Please respond." : ""),
      notificationDetails: platformDetails,
      payload: data['orderId'] ?? '',
    );
    log("✅ FCM: Notification displayed with ID: $notificationId");
  }

  /// Registers the FCM token with the backend.
  Future<void> registerToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        log("⚠️ Firebase not initialized. Cannot register token.");
        return;
      }
      String? token = await _messaging.getToken();
      if (token != null) {
        log("🔗 Registering FCM token with backend: $token");
        final res = await apiFetch(
          '/api/users/save-token',
          method: 'POST',
          data: {'token': token},
        );
        log("✅ FCM Token Registration Result: $res");
      }
    } catch (e) {
      log("❌ Error registering FCM token: $e");
    }
  }

  /// Sets up the background message handler.
  static void setupBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      log("Error setting background handler: $e");
    }
  }

  /// Handles notification response (button clicks or tap).
  @pragma('vm:entry-point')
  static void handleNotificationResponse(NotificationResponse response) {
    String? orderId = response.payload;
    String? actionId = response.actionId;

    log("🔔 Notification Response: Action=$actionId, OrderID=$orderId");

    if (orderId == null || orderId.isEmpty) return;

    if (actionId == 'accept_order') {
      _updateOrderStatus(orderId, 'ACCEPTED');
    } else if (actionId == 'decline_order') {
      _cancelOrder(orderId);
    } else if (actionId == 'dismiss_notification') {
      log("🔔 Notification Dismissed by User");
    } else {
      log("Notification tapped without action button");
    }
  }

  static Future<void> _cancelOrder(String orderId) async {
    try {
      log("🚀 FCM: Cancelling Order $orderId...");
      await apiFetch('/api/admin/orders/$orderId/cancel', method: 'PATCH');
      log("✅ FCM: Order $orderId cancelled successfully");
    } catch (e) {
      log("❌ FCM: Failed to cancel order ($orderId): $e");
    }
  }

  static Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      log("🚀 FCM: Updating Order $orderId to $status...");
      final startTime = DateTime.now();
      await apiFetch(
        '/api/admin/orders/$orderId/status',
        method: 'PATCH',
        data: {'status': status},
      );
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      log("✅ FCM: Order $orderId status updated to $status in ${duration}ms");
    } catch (e) {
      log("❌ FCM: Failed to update order status ($orderId -> $status): $e");
    }
  }
}
