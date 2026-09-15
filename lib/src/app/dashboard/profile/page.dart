import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(LucideIcons.logOut, color: Colors.red, size: 20.sp),
            SizedBox(width: 10.w),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out of ScanServe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final data = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});

    final name = (data['name'] ?? data['restaurantName'] ?? 'Admin User').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? 'Owner').toString().toUpperCase();
    final permissionLevel = (data['permissionLevel'] ?? '').toString().toUpperCase();
    final rawBusinessType = (data['businessType'] ?? data['type'] ?? 'RESTAURANT').toString().toUpperCase();
    final businessType = rawBusinessType == 'FOOD_TRUCK' ? 'Food Truck' : 'Restaurant';
    final restaurantName = (data['restaurant']?['name'] ??
        data['restaurants']?[0]?['name'] ??
        data['restaurantName'] ??
        'Restaurant').toString();
    final address = (data['restaurant']?['address'] ?? data['address'] ?? '').toString();

    final initial = (name.trim().isNotEmpty ? name.trim()[0] : 'U').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Profile',
                            style: TextStyle(
                              fontSize: 22.sp,
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
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // USER HERO CARD
                Container(
                  padding: EdgeInsets.all(20.r),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30.r,
                        backgroundColor: const Color(0xFFFF5C00),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8.w,
                              runSpacing: 4.h,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6.r),
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
                              restaurantName,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF5C00),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty || phone.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                email.isNotEmpty ? email : phone,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28.h),

                // ACCOUNT & RESTAURANT DETAILS SECTION
                Text(
                  'ACCOUNT DETAILS',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 10.h),

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
                      _buildDetailRow(
                        icon: LucideIcons.utensilsCrossed,
                        label: 'Store / Brand',
                        value: restaurantName,
                        isFirst: true,
                      ),
                      if (email.isNotEmpty) ...[
                        Divider(height: 1, color: Colors.grey.shade100),
                        _buildDetailRow(
                          icon: LucideIcons.mail,
                          label: 'Email Address',
                          value: email,
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        Divider(height: 1, color: Colors.grey.shade100),
                        _buildDetailRow(
                          icon: LucideIcons.phone,
                          label: 'Phone Number',
                          value: phone,
                        ),
                      ],
                      Divider(height: 1, color: Colors.grey.shade100),
                      _buildDetailRow(
                        icon: LucideIcons.store,
                        label: 'Business Type',
                        value: businessType,
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _buildDetailRow(
                        icon: LucideIcons.shieldCheck,
                        label: 'Role & Permissions',
                        value: permissionLevel.isNotEmpty
                            ? '$role ($permissionLevel ACCESS)'
                            : role,
                      ),
                      if (address.isNotEmpty) ...[
                        Divider(height: 1, color: Colors.grey.shade100),
                        _buildDetailRow(
                          icon: LucideIcons.mapPin,
                          label: 'Address',
                          value: address,
                          isLast: true,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 28.h),

                // PRINTING PREFERENCES SECTION
                Text(
                  'PRINTING PREFERENCES',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 10.h),

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
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
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
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto Print KOT',
                                    style: TextStyle(
                                      fontSize: 15.sp,
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
                            SizedBox(width: 8.w),
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
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
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
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto Print Bill',
                                    style: TextStyle(
                                      fontSize: 15.sp,
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
                            SizedBox(width: 8.w),
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
                SizedBox(height: 32.h),

                // SIGN OUT BUTTON
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: InkWell(
                    onTap: _confirmLogout,
                    borderRadius: BorderRadius.circular(16.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.logOut, color: Colors.red.shade600, size: 18.sp),
                          SizedBox(width: 10.w),
                          Text(
                            'Sign Out of Account',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Icon(
              icon,
              size: 16.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(width: 14.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
