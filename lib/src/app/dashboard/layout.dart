import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../components/Sidebar.dart';
import '../../services/order_alarm_service.dart';
import '../../utils/responsive.dart';

class DashboardLayout extends ConsumerStatefulWidget {
  final Widget child;
  const DashboardLayout({required this.child, super.key});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // Website layout for tablets and every landscape device,
    // drawer-based mobile layout for portrait phones.
    return Responsive.useDesktopLayout(context)
        ? _buildTabletLayout()
        : _buildMobileLayout();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TABLET LAYOUT
  // Persistent sidebar on the left, main content on the right.
  // No Drawer, no AppBar hamburger.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9FAFB),
      body: Listener(
        onPointerDown: (_) => OrderAlarmService.muteSound(),
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: [
            // ── Persistent sidebar ──────────────────────────────────────
            SizedBox(
              width: Responsive.sidebarWidth(context),
              child: const Sidebar(isInline: true),
            ),

            // ── Main content ─────────────────────────────────────────────
            Expanded(
              child: SizedBox.expand(
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT  (original drawer-based layout, unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9FAFB),
      // Dark mobile header, same as the website's mobile top bar.
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5C00),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                LucideIcons.qrCode,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'SCAN'),
                  TextSpan(
                    text: 'SERVE',
                    style: TextStyle(color: Color(0xFFFF5C00)),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                icon: const Icon(LucideIcons.menu, color: Colors.white),
                tooltip: 'Navigation Menu',
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
          ),
        ],
      ),
      drawer: const Drawer(
        width: 300,
        backgroundColor: Color(0xFF0F172A),
        shape: RoundedRectangleBorder(),
        child: Sidebar(isInline: false),
      ),
      body: Listener(
        onPointerDown: (_) => OrderAlarmService.muteSound(),
        behavior: HitTestBehavior.translucent,
        child: SizedBox.expand(
          child: widget.child,
        ),
      ),
    );
  }
}
