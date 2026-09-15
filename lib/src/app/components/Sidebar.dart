import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../context/AuthContext.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

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

    // Use the raw user object for role/businessType filtering.
    // authState.user = res['data'] from /api/auth/me, which has role, restaurantId, etc at top level.
    final navItems = _getFilteredItems(authState.user);
    final currentPath = GoRouterState.of(context).uri.toString();

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEFF2F4))),
        ),
        child: Column(
          children: [
            // LOGO & CLOSE SECTION
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        context.go('/');
                        if (Scaffold.of(context).hasDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
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
                          SizedBox(width: 10.w),
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
                                    height: 1.1,
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
                  ),

                  // Close Drawer Button
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20.sp,
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

            // NAVIGATION ITEMS
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final bool isActive = currentPath.startsWith(item['href']);

                  return InkWell(
                    onTap: () {
                      context.go(item['href']);
                      if (Scaffold.of(context).hasDrawer) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.symmetric(
                        vertical: 14.h,
                        horizontal: 16.w,
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
                        children: [
                          Icon(
                            item['icon'],
                            size: 22.sp,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: 14.sp,
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

            // FOOTER LOGOUT
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFF2F4))),
              ),
              child: InkWell(
                onTap: () {
                  if (Scaffold.of(context).hasDrawer) {
                    Navigator.of(context).pop();
                  }
                  _handleLogout();
                },
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.logOut,
                      size: 22.sp,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14.sp,
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

