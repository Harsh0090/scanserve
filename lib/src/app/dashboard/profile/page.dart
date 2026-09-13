import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../services/kot_print_service.dart';
import '../../context/AuthContext.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _autoPrintKOT = false;
  bool _autoPrintBill = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromUser();
  }

  void _initFromUser() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      final data = (user['data'] is Map) ? user['data'] : user;
      setState(() {
        _autoPrintKOT = data['autoPrintKOT'] == true;
        _autoPrintBill = data['autoPrintBill'] == true;
      });
    }
  }

  Future<void> _savePrintingSettings({bool? nextKOT, bool? nextBill}) async {
    final prevKOT = _autoPrintKOT;
    final prevBill = _autoPrintBill;

    final updatedKOT = nextKOT ?? _autoPrintKOT;
    final updatedBill = nextBill ?? _autoPrintBill;

    setState(() {
      _autoPrintKOT = updatedKOT;
      _autoPrintBill = updatedBill;
      _isSaving = true;
    });

    try {
      final kotService = ref.read(kotPrintServiceProvider);
      // Save both together via PATCH /api/auth/update-printer-settings
      await kotService.updatePrinterSettings(
        autoPrintKOT: updatedKOT,
        autoPrintBill: updatedBill,
      );
      await ref.read(authProvider.notifier).loadSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printing preferences updated!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _autoPrintKOT = prevKOT;
          _autoPrintBill = prevBill;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update printing settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final data = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});

    final name = data['name'] ?? data['restaurantName'] ?? 'Admin User';
    final email = data['email'] ?? data['phone'] ?? 'admin@scanserve.in';
    final role = (data['role'] ?? 'Owner').toString().toUpperCase();
    final restaurantName = data['restaurant']?['name'] ??
        data['restaurants']?[0]?['name'] ??
        data['restaurantName'] ??
        'Restaurant';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5ED),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        LucideIcons.user,
                        color: const Color(0xFFFF5C00),
                        size: 26.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Profile',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Manage your restaurant profile and device preferences',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 32.h),

                // USER INFO CARD
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 16.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34.r,
                        backgroundColor: const Color(0xFFFF5C00),
                        child: Text(
                          name.toString().substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name.toString(),
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1D4ED8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              restaurantName.toString(),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF5C00),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              email.toString(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),

                // PRINTING SECTION
                Text(
                  'PRINTING PREFERENCES',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 16.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // TOGGLE 1: Auto Print KOT
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Icon(
                                LucideIcons.printer,
                                color: const Color(0xFF10B981),
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto Print KOT',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    'Shows a Print KOT button on every incoming order',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoPrintKOT,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: _isSaving
                                  ? null
                                  : (val) => _savePrintingSettings(nextKOT: val),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),

                      // TOGGLE 2: Auto Print Bill
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Icon(
                                LucideIcons.receipt,
                                color: const Color(0xFF10B981),
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto Print Bill',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    'Automatically print receipt when order is served',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoPrintBill,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: _isSaving
                                  ? null
                                  : (val) => _savePrintingSettings(nextBill: val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
