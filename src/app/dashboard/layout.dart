import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../components/Sidebar.dart';
import '../../services/order_alarm_service.dart';

// ─── Breakpoint ────────────────────────────────────────────────────────────
// Screens with a logical width ≥ 768 dp are treated as "tablet" mode.
const double _kTabletBreakpoint = 768.0;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= _kTabletBreakpoint;

    return isTablet ? _buildTabletLayout() : _buildMobileLayout();
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
              width: 240,
              child: const Sidebar(isInline: true),
            ),

            // ── Thin divider ─────────────────────────────────────────────
            Container(
              width: 1,
              color: const Color(0xFFEFF2F4),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
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
                size: 18.sp,
              ),
            ),
            SizedBox(width: 8.w),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
                children: const [
                  TextSpan(text: 'Scan '),
                  TextSpan(
                    text: 'Serve',
                    style: TextStyle(color: Color(0xFFFF5C00)),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Navigation Menu',
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: const Drawer(
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
