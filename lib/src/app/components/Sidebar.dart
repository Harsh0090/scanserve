import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../context/AuthContext.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  bool _isExpanded = true;

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
                "Payment Setup",
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
                "Expense Tracker",
                "Menu Manager",
                "QR Print",
                "Payment Setup",
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.loading2) {
      return Container(
        width: _isExpanded ? 280.w : 96.w,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
        ),
      );
    }

    // Use the raw user object for role/businessType filtering.
    // authState.user = res['data'] from /api/auth/me, which has role, restaurantId, etc at top level.
    final navItems = _getFilteredItems(authState.user);
    final currentPath = GoRouterState.of(context).uri.toString();
    final isMobile = MediaQuery.of(context).size.width < 768.w;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isMobile ? double.infinity : (_isExpanded ? 280.w : 96.w),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEFF2F4))),
        ),
        child: Column(
          children: [
            // LOGO SECTION
            Padding(
              padding: EdgeInsets.all(24.r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isMobile || _isExpanded)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: Row(
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
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Scan Serve',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      height: 1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'ADMIN PORTAL',
                                    style: TextStyle(
                                      fontSize: 9.sp,
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
                    )
                  else
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C00),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          LucideIcons.qrCode,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),

                  // Toggle Button (Hidden on very tiny constraints but visible normally)
                  if (!isMobile)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 4.r,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isExpanded
                              ? LucideIcons.chevronLeft
                              : LucideIcons.chevronRight,
                          size: 16.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // NAVIGATION ITEMS
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final bool isActive = currentPath.startsWith(item['href']);

                  return Tooltip(
                    message: (isMobile || _isExpanded) ? '' : item['name'],
                    child: InkWell(
                      onTap: () {
                        context.go(item['href']);
                        if (isMobile && Scaffold.of(context).hasDrawer) {
                          Navigator.pop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(16.r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                          horizontal: (isMobile || _isExpanded) ? 20.w : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFF5C00)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF5C00,
                                    ).withAlpha(100),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: (isMobile || _isExpanded)
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              item['icon'],
                              size: 22.sp,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                            if (isMobile || _isExpanded) ...[
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // FOOTER LOGOUT
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFF2F4))),
              ),
              child: InkWell(
                onTap: _handleLogout,
                child: Row(
                  mainAxisAlignment: (isMobile || _isExpanded)
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.logOut,
                      size: 22.sp,
                      color: Colors.grey,
                    ),
                    if (isMobile || _isExpanded) ...[
                      SizedBox(width: 16.w),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
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
