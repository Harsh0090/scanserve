import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../context/AuthContext.dart';

// ─── Breakpoint (must match DashboardLayout) ─────────────────────────────
const double _kTabletBreakpoint = 768.0;

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

  void _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  void _navigateTo(String href) {
    // On mobile (drawer mode) pop the drawer first, then navigate.
    if (!widget.isInline) {
      final scaffold = Scaffold.of(context);
      if (scaffold.isDrawerOpen) {
        Navigator.of(context).pop();
      }
    }
    context.go(href);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.loading2) {
      return Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
        ),
      );
    }

    final navItems = _getFilteredItems(authState.user);
    final currentPath = GoRouterState.of(context).uri.toString();

    // ── Adaptive sizing ────────────────────────────────────────────────────
    // When inline on a tablet we use slightly tighter paddings / font sizes
    // so the sidebar fits in its 240 dp column without relying on .sp / .w
    // scaling (which targets the 402-wide phone canvas).
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= _kTabletBreakpoint;

    final double itemVertPad = isTablet ? 12.0 : 14.h;
    final double itemHorizPad = isTablet ? 14.0 : 16.w;
    final double itemFontSize = isTablet ? 13.0 : 14.sp;
    final double iconSize = isTablet ? 20.0 : 22.sp;
    final double itemSpacing = isTablet ? 10.0 : 14.w;
    final double listHorizPad = isTablet ? 12.0 : 16.w;
    final double listVertPad = isTablet ? 10.0 : 12.h;
    final double itemRadius = isTablet ? 14.0 : 16.0;
    final double logoIconSize = isTablet ? 18.0 : 20.sp;
    final double logoFontSize = isTablet ? 16.0 : 18.sp;
    final double logoPad = isTablet ? 16.0 : 20.0;

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEFF2F4))),
        ),
        child: Column(
          children: [
            // ── LOGO & CLOSE SECTION ───────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: logoPad,
                vertical: logoPad,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        context.go('/');
                        if (!widget.isInline &&
                            Scaffold.of(context).hasDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isTablet ? 6.0 : 6.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5C00),
                              borderRadius: BorderRadius.circular(
                                isTablet ? 8.0 : 8.r,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.qrCode,
                              color: Colors.white,
                              size: logoIconSize,
                            ),
                          ),
                          SizedBox(width: isTablet ? 10.0 : 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Scan Serve',
                                  style: TextStyle(
                                    fontSize: logoFontSize,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    height: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ADMIN PORTAL',
                                  style: TextStyle(
                                    fontSize: isTablet ? 9.0 : 9.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Show close button only inside a Drawer (mobile)
                  if (!widget.isInline)
                    IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: isTablet ? 20.0 : 20.sp,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        if (Scaffold.of(context).hasDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                      tooltip: 'Close Menu',
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEFF2F4)),

            // ── NAVIGATION ITEMS ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: listHorizPad,
                  vertical: listVertPad,
                ),
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final bool isActive = currentPath.startsWith(item['href']);

                  return InkWell(
                    onTap: () => _navigateTo(item['href']),
                    borderRadius: BorderRadius.circular(itemRadius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        bottom: isTablet ? 6.0 : 8.h,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: itemVertPad,
                        horizontal: itemHorizPad,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFF5C00)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(itemRadius),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF5C00).withAlpha(100),
                                  blurRadius: isTablet ? 8.0 : 10.r,
                                  offset: Offset(0, isTablet ? 3.0 : 4.h),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'],
                            size: iconSize,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                          SizedBox(width: itemSpacing),
                          Expanded(
                            child: Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: itemFontSize,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── FOOTER LOGOUT ─────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(isTablet ? 16.0 : 20.r),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFF2F4))),
              ),
              child: InkWell(
                onTap: () {
                  if (!widget.isInline && Scaffold.of(context).hasDrawer) {
                    Navigator.of(context).pop();
                  }
                  _handleLogout();
                },
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.logOut,
                      size: iconSize,
                      color: Colors.grey,
                    ),
                    SizedBox(width: itemSpacing),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: itemFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
