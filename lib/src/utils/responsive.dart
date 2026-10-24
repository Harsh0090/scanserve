import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Central breakpoints and layout helpers shared by the whole app.
///
/// Layout rules:
///  • Portrait phone / portrait small tablet → mobile UI (drawer navigation).
///  • Any landscape device, or any screen ≥ 768 dp wide → website UI
///    (persistent sidebar + desktop page layouts).
class Responsive {
  Responsive._();

  /// Width at which a portrait screen switches to the website layout.
  static const double tabletBreakpoint = 768.0;

  /// Smallest landscape width that still gets the website layout.
  static const double minLandscapeDesktopWidth = 560.0;

  /// Shortest side at which a device is treated as a tablet.
  static const double tabletShortestSide = 600.0;

  static Size _size(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isLandscape(BuildContext context) {
    final size = _size(context);
    return size.width > size.height;
  }

  /// True for tablets (shortest side ≥ 600 dp) regardless of orientation.
  static bool isTabletDevice(BuildContext context) =>
      _size(context).shortestSide >= tabletShortestSide;

  /// True for landscape phones (short height) – useful to tighten spacing.
  static bool isCompactHeight(BuildContext context) =>
      _size(context).height < 500;

  /// Whether the dashboard shows the website layout (persistent sidebar).
  static bool useDesktopLayout(BuildContext context) {
    final size = _size(context);
    if (size.width >= tabletBreakpoint) return true;
    return size.width > size.height && size.width >= minLandscapeDesktopWidth;
  }

  /// Width of the persistent sidebar when [useDesktopLayout] is true.
  static double sidebarWidth(BuildContext context) {
    final width = _size(context).width;
    // Website uses w-72 (288px) on large screens.
    if (width >= 1200) return 288.0;
    if (width >= 900) return 240.0;
    return 220.0;
  }

  /// Width available to page content (screen width minus the sidebar).
  static double contentWidth(BuildContext context) {
    final width = _size(context).width;
    if (!useDesktopLayout(context)) return width;
    return width - sidebarWidth(context) - 1;
  }

  /// Width of a side pane (forms, category lists) next to the main content,
  /// clamped so the main content always keeps at least ~55% of the space.
  static double sidePaneWidth(BuildContext context, double preferred) {
    return math.min(preferred, contentWidth(context) * 0.45);
  }

  /// Width for dialogs / sheets that should never exceed the screen.
  static double dialogWidth(BuildContext context, double preferred) {
    return math.min(preferred, _size(context).width * 0.92);
  }

  /// Width for end-drawers such as the order MenuModal.
  static double endDrawerWidth(BuildContext context) {
    final width = _size(context).width;
    if (!useDesktopLayout(context)) return width;
    return math.min(740.0, math.max(width * 0.75, math.min(width, 480.0)));
  }

  /// Grid column count for card lists based on the available width.
  static int gridColumns(
    double availableWidth, {
    double minCardWidth = 280,
    int maxColumns = 4,
  }) {
    final count = (availableWidth / minCardWidth).floor();
    return count.clamp(1, maxColumns);
  }
}
