import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/apiClient.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../context/AuthContext.dart';
import '../../utils/responsive.dart';

// Website palette (Sidebar.js)
const Color _kNavy = Color(0xFF0F172A);
const Color _kPanel = Color(0xFF1E293B);
const Color _kOrange = Color(0xFFFF5C00);

class Sidebar extends ConsumerStatefulWidget {
  /// [isInline] = true  → rendered as a persistent left-rail on tablets.
  /// [isInline] = false → rendered inside a Drawer (mobile default).
  final bool isInline;
  const Sidebar({super.key, this.isInline = false});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  final List<Map<String, dynamic>> _allNavItems = [
    {
      "name": "Live Orders",
      "href": "/dashboard/orders",
      "icon": LucideIcons.clipboardList,
    },
    {
      "name": "Table Management",
      "href": "/dashboard/OwnerSetup",
      "icon": LucideIcons.layoutDashboard,
    },
    {
      "name": "Analytics",
      "href": "/dashboard/analytics",
      "icon": LucideIcons.barChart3,
    },
    {
      "name": "Item Sales",
      "href": "/dashboard/item-sales",
      "icon": LucideIcons.package,
    },
    {
      "name": "Expense Tracker",
      "href": "/dashboard/profit",
      "icon": LucideIcons.receipt,
    },
    {
      "name": "Upsell Logic",
      "href": "/dashboard/upsell",
      "icon": LucideIcons.sparkles,
    },
    {
      "name": "Menu Manager",
      "href": "/dashboard/menu",
      "icon": LucideIcons.utensilsCrossed,
    },
    {
      "name": "Inventory",
      "href": "/dashboard/inventory",
      "icon": LucideIcons.package,
    },
    {
      "name": "QR Print",
      "href": "/dashboard/tablegenerator",
      "icon": LucideIcons.qrCode,
    },
    {
      "name": "Payment Setup",
      "href": "/dashboard/payment-setup",
      "icon": LucideIcons.wallet,
    },
    {
      "name": "Staff Manager",
      "href": "/dashboard/createmanager",
      "icon": LucideIcons.userPlus,
    },
    {
      "name": "Branch Control",
      "href": "/dashboard/createbranch",
      "icon": LucideIcons.gitBranch,
    },
    {
      "name": "Buy Subscription",
      "href": "/dashboard/IncreaseBranchLimit",
      "icon": LucideIcons.podcast,
    },
    {
      "name": "Settings",
      "href": "/dashboard/settings",
      "icon": LucideIcons.settings,
    },
    {
      "name": "Profile",
      "href": "/dashboard/profile",
      "icon": LucideIcons.user,
    },
  ];

  List<Map<String, dynamic>> _getFilteredItems(Map<String, dynamic>? rawUser) {
    if (rawUser == null) return [];

    // authState.user is the direct API response data (res['data'] from /api/auth/me).
    // role, businessType, permissionLevel are at the top level.
    List<Map<String, dynamic>> filteredItems = [];
    final role = rawUser['role'] ?? 'owner';
    final permissionLevel = rawUser['permissionLevel'] ?? 'FULL';
    final rawBusinessType = (rawUser['businessType'] ?? rawUser['type'] ?? 'RESTAURANT').toString().toUpperCase();

    // 1. Role-based filtering
    if (role == "owner") {
      filteredItems = List.from(_allNavItems);
    } else if (role == "manager") {
      if (permissionLevel == "LIMITED") {
        filteredItems = _allNavItems
            .where(
              (item) => [
                "Live Orders",
                "Table Management",
                "Expense Tracker",
                "Menu Manager",
                "Inventory",
                "Payment Setup",
                "Settings",
                "Profile",
              ].contains(item['name']),
            )
            .toList();
      } else {
        filteredItems = _allNavItems
            .where(
              (item) => [
                "Live Orders",
                "Table Management",
                "Analytics",
                "Item Sales",
                "Expense Tracker",
                "Menu Manager",
                "Inventory",
                "QR Print",
                "Payment Setup",
                "Settings",
                "Profile",
              ].contains(item['name']),
            )
            .toList();
      }
    }

    // 2. Business Type Filtering
    if (rawBusinessType == "FOOD_TRUCK") {
      filteredItems.removeWhere((item) => item['name'] == "Table Management");
    } else {
      // If NOT a food truck, hide payment setup
      filteredItems.removeWhere((item) => item['name'] == "Payment Setup");
    }

    return filteredItems;
  }

  // ── Low-stock alerts (same source as the website's bell) ────────────────
  List<Map<String, dynamic>> _lowStockItems = [];
  Timer? _lowStockTimer;

  @override
  void initState() {
    super.initState();
    _fetchLowStock();
    _lowStockTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchLowStock(),
    );
  }

  @override
  void dispose() {
    _lowStockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLowStock() async {
    if (ref.read(authProvider).user == null) return;
    try {
      final res = await apiFetch('/api/inventory/items');
      final all = (res is Map ? res['data'] : null) ?? [];
      if (all is! List) return;
      final low = all
          .whereType<Map>()
          .where((i) =>
              (num.tryParse('${i['currentStock']}') ?? 0) <=
              (num.tryParse('${i['lowStockThreshold']}') ?? 0))
          .map((i) => Map<String, dynamic>.from(i))
          .toList();
      if (mounted) setState(() => _lowStockItems = low);
    } catch (_) {
      // Non-critical: the bell simply shows no alerts.
    }
  }

  void _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  void _closeDrawerIfOpen() {
    if (!widget.isInline) {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.isDrawerOpen) {
        Navigator.of(context).pop();
      }
    }
  }

  void _navigateTo(String href) {
    // On mobile (drawer mode) pop the drawer first, then navigate.
    _closeDrawerIfOpen();
    context.go(href);
  }

  // ── Low-stock dropdown panel (mirrors the website) ─────────────────────
  void _showLowStockPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 90),
          child: Material(
            color: _kPanel,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 288,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPanelHeader(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 288),
                    child: _lowStockItems.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(LucideIcons.package,
                                    size: 28, color: Color(0xFF475569)),
                                SizedBox(height: 8),
                                Text(
                                  'All stock levels are healthy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: _lowStockItems
                                .map((item) => _buildLowStockRow(ctx, item))
                                .toList(),
                          ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _navigateTo('/dashboard/inventory');
                    },
                    child: Container(
                      color: const Color(0x33000000),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        'VIEW FULL INVENTORY →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _kOrange,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.triangleAlert,
              size: 14, color: Color(0xFFFB923C)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'LOW STOCK ALERTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.6,
              ),
            ),
          ),
          if (_lowStockItems.isNotEmpty)
            _pill('${_lowStockItems.length} items', const Color(0x33EF4444)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFFF87171),
        ),
      ),
    );
  }

  Widget _buildLowStockRow(BuildContext ctx, Map<String, dynamic> item) {
    final stock = num.tryParse('${item['currentStock']}') ?? 0;
    final min = num.tryParse('${item['lowStockThreshold']}') ?? 0;
    final double pct =
        min > 0 ? (stock / min * 100).clamp(4, 100).toDouble() : 100;

    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        _navigateTo('/dashboard/inventory');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['name'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                _pill('LOW', const Color(0x1AEF4444)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$stock ${item['unit'] ?? ''} remaining',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'Min: $min',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 4,
                backgroundColor: const Color(0x1AFFFFFF),
                color: const Color(0xFFF87171),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.loading2) {
      return Container(
        width: double.infinity,
        color: _kNavy,
        child: const Center(
          child: CircularProgressIndicator(color: _kOrange),
        ),
      );
    }

    final navItems = _getFilteredItems(authState.user);
    final currentPath = GoRouterState.of(context).uri.toString();

    // Landscape phones have little vertical room – tighten the rail.
    final bool compact = Responsive.isCompactHeight(context);
    final double logoPad = compact ? 16.0 : 24.0;
    final double itemPad = compact ? 11.0 : 15.0;

    return Container(
      width: double.infinity,
      color: _kNavy,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // ── LOGO + BELL ROW ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(logoPad, logoPad, 8, logoPad),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _closeDrawerIfOpen();
                        context.go('/');
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kOrange,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _kOrange.withAlpha(50),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.qrCode,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'SCAN'),
                                  TextSpan(
                                    text: 'SERVE',
                                    style: TextStyle(color: _kOrange),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bell with low-stock count
                  IconButton(
                    onPressed: _showLowStockPanel,
                    tooltip: 'Low Stock Alerts',
                    icon: Badge(
                      isLabelVisible: _lowStockItems.isNotEmpty,
                      backgroundColor: const Color(0xFFEF4444),
                      label: Text(
                        '${_lowStockItems.length}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.bell,
                        size: 20,
                        color: _lowStockItems.isNotEmpty
                            ? const Color(0xFFFB923C)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),

                  // Close button only inside a Drawer (mobile)
                  if (!widget.isInline)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: _closeDrawerIfOpen,
                      tooltip: 'Close Menu',
                    ),
                ],
              ),
            ),

            // ── NAVIGATION ──────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'MAIN TERMINAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  for (final item in navItems)
                    _buildNavItem(
                      item,
                      isActive: currentPath.startsWith(item['href']),
                      padding: itemPad,
                    ),
                ],
              ),
            ),

            // ── FOOTER ──────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 16),
              decoration: const BoxDecoration(
                color: Color(0x33000000),
                border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _closeDrawerIfOpen();
                  _handleLogout();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: itemPad),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.logOut,
                          size: 20, color: Color(0xFFF87171)),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'TERMINATE SESSION',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF87171),
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    Map<String, dynamic> item, {
    required bool isActive,
    required double padding,
  }) {
    final bool showLowDot =
        item['name'] == 'Inventory' && _lowStockItems.isNotEmpty;
    final Color fg = isActive ? Colors.white : const Color(0xB394A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? _kOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        shadowColor: _kOrange.withAlpha(60),
        elevation: isActive ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: const Color(0x0DFFFFFF),
          onTap: () => _navigateTo(item['href']),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Icon(item['icon'], size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (item['name'] as String).toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: fg,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (showLowDot)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  )
                else if (isActive)
                  const Icon(LucideIcons.chevronRight,
                      size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
