import 'dart:async';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/apiClient.dart';

// Entry point for the foreground-service Dart isolate.
@pragma('vm:entry-point')
void startOrderAlarmCallback() {
  FlutterForegroundTask.setTaskHandler(OrderAlarmTaskHandler());
}

class OrderAlarmService {
  OrderAlarmService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'order_alarm_service_v1',
        channelName: 'Order Alarm',
        channelDescription: 'Rings continuously for incoming orders until you respond.',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> startAlarm({
    required String orderId,
    required String title,
    required String body,
    required String type,
  }) async {
    final bool isOrder = type == 'NEW' || type == 'NEW_ORDER' || type.isEmpty;

    final List<NotificationButton> buttons = isOrder
        ? [
            const NotificationButton(id: 'accept_order', text: 'Accept'),
            const NotificationButton(id: 'decline_order', text: 'Decline'),
          ]
        : [const NotificationButton(id: 'dismiss_notification', text: 'OK')];

    final Map<String, dynamic> taskData = {'orderId': orderId, 'type': type};

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
        notificationButtons: buttons,
        callback: startOrderAlarmCallback,
      );
      FlutterForegroundTask.sendDataToTask({...taskData, 'restart_audio': true});
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 9001,
        notificationTitle: title,
        notificationText: body,
        notificationButtons: buttons,
        callback: startOrderAlarmCallback,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      FlutterForegroundTask.sendDataToTask(taskData);
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static void addActionCallback(DataCallback callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  static void removeActionCallback(DataCallback callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}

class OrderAlarmTaskHandler extends TaskHandler {
  AudioPlayer? _player;
  String? _orderId;
  String? _type;
  Timer? _autoStopTimer;
  bool _isStopping = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    log('OrderAlarm: service started (starter=$starter)');
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    _orderId = map['orderId'] as String?;
    _type    = map['type'] as String? ?? 'NEW';

    if (map['restart_audio'] == true) {
      _restartAudio();
    } else {
      _startAudio();
      _scheduleAutoStop();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    log('OrderAlarm: service destroyed (isTimeout=$isTimeout)');
    _autoStopTimer?.cancel();
    await _stopAudio();
  }

  @override
  void onNotificationButtonPressed(String id) {
    log('OrderAlarm: button -> $id');
    _handleAction(id);
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _startAudio() async {
    try {
      await _stopAudio();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/${_soundFile()}'));
      log('OrderAlarm: playing ${_soundFile()} in loop');
    } catch (e) {
      log('OrderAlarm: audio error -> $e');
    }
  }

  Future<void> _restartAudio() async {
    await _stopAudio();
    await _startAudio();
    _scheduleAutoStop();
  }

  Future<void> _stopAudio() async {
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = null;
    } catch (_) {}
  }

  String _soundFile() {
    switch ((_type ?? '').toUpperCase()) {
      case 'READY':  return 'order_ready.mp3';
      case 'UPDATE': return 'reorder.mp3';
      default:       return 'ringing.mp3';
    }
  }

  void _scheduleAutoStop() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 90), () {
      log('OrderAlarm: auto-stopping after 90s');
      FlutterForegroundTask.stopService();
    });
  }

  Future<void> _handleAction(String actionId) async {
    if (_isStopping) return;
    _isStopping = true;

    await _stopAudio();
    _autoStopTimer?.cancel();

    final String? orderId = _orderId;

    FlutterForegroundTask.sendDataToMain({'action': actionId, 'orderId': orderId});

    if (orderId != null && orderId.isNotEmpty) {
      try {
        await initCookies();
        if (actionId == 'accept_order') {
          await apiFetch('/api/admin/orders/$orderId/status', method: 'PATCH', data: {'status': 'ACCEPTED'});
          log('OrderAlarm: order $orderId ACCEPTED');
        } else if (actionId == 'decline_order') {
          await apiFetch('/api/admin/orders/$orderId/cancel', method: 'PATCH');
          log('OrderAlarm: order $orderId CANCELLED');
        }
      } catch (e) {
        log('OrderAlarm: API call failed -> $e');
      }
    }

    await FlutterForegroundTask.stopService();
  }
}
