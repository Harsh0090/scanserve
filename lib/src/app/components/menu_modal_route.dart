import 'package:flutter/material.dart';
import '../../services/order_alarm_service.dart';
import 'MenuModal.dart';

/// Opens [MenuModal] as a full-screen page over the whole app (sidebar
/// included), matching the website's `fixed inset-0 w-full h-full` modal.
///
/// The modal may call `onClose` more than once (e.g. back button and the
/// delayed auto-close after placing an order), so closing only removes this
/// route and never pops anything underneath it.
Future<void> showMenuModalFullScreen(
  BuildContext context, {
  Map<String, dynamic>? table,
  Map<String, dynamic>? sendAppendOrder,
  Function(dynamic)? onOrderPlaced,
  VoidCallback? onClosed,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  late final PageRoute<void> route;

  void close() {
    if (!route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  route = PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, animation, secondaryAnimation) => Listener(
      // Same as the dashboard shell: any tap silences the new-order alarm.
      onPointerDown: (_) => OrderAlarmService.muteSound(),
      behavior: HitTestBehavior.translucent,
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: MenuModal(
            table: table,
            sendAppendOrder: sendAppendOrder,
            onOrderPlaced: onOrderPlaced,
            onClose: close,
          ),
        ),
      ),
    ),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  return navigator.push(route).whenComplete(() => onClosed?.call());
}
