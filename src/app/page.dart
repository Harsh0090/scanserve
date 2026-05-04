import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'context/AuthContext.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _activeLevel = 1;
  bool _expLocked = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  void _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
      context.go('/');
    }
  }

  void _handleContactSubmit() {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request sent! Our team will call you shortly.'),
        backgroundColor: Colors.green,
      ),
    );
    _nameController.clear();
    _restaurantController.clear();
    _phoneController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show a loading screen while auth state is being resolved.
    // In release mode, rendering with an unresolved auth state causes a
    // silent crash / freeze because deep null-chains like
    // user['data']?['restaurants']?[0]?['name'] are evaluated eagerly.
    if (authState.loading2) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
        ),
      );
    }

    final user = authState.user;
    final isLoggedIn = user != null;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.h),
        child: ClipRect(
          child: Container(
            color: Colors.white.withAlpha(230),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (!isMobile) ...[
                        Text(
                          'SCAN',
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'SERVE',
                          style: TextStyle(
                            color: const Color(0xFFFF5C00),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'SCAN',
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'SERVE',
                          style: TextStyle(
                            color: const Color(0xFFFF5C00),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isLoggedIn)
                    ElevatedButton(
                      onPressed: () => context.push('/signup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16.w : 24.w,
                          vertical: isMobile ? 12.h : 16.h,
                        ),
                      ),
                      child: Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: isMobile ? 10.sp : 12.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                  else
                    PopupMenuButton(
                      offset: Offset(0, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.orange.shade50,
                        radius: isMobile ? 20.r : 24.r,
                        child: Text(
                          ((user['data']?['restaurants']?[0]?['name'] ??
                                      user['restaurants']?[0]?['name'] ??
                                      'N')
                                  as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: const Color(0xFFFF5C00),
                            fontWeight: FontWeight.w900,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Text(
                            'Dashboard',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                          ),
                          onTap: () => context.push('/dashboard/orders'),
                        ),
                        PopupMenuItem(
                          child: Text(
                            'Live Menu',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                          ),
                          onTap: () {
                            if (user['restaurantId'] != null) {
                              context.push('/${user['restaurantId']}');
                            }
                          },
                        ),
                        PopupMenuItem(
                          onTap: _handleLogout,
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HERO
            Container(
              height: isMobile ? null : 1.sh,
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 120.h,
              ),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isMobile) SizedBox(height: 40.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          color: const Color(0xFFFF5C00),
                          size: 14.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'SMARTER GROWTH LOGIC',
                          style: TextStyle(
                            color: const Color(0xFFFF5C00),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    'YOUR MENU,\nBUT PROFITABLE.',
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isMobile ? 40.sp : 56.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -2,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'The average menu ignores upselling. Scan Serve automates it, suggesting the perfect pairings for every dish.',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: isMobile ? 16.sp : 18.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  ElevatedButton(
                    onPressed: () {
                      if (isLoggedIn) {
                        context.push('/dashboard/orders');
                      } else {
                        context.push('/signup');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 48.w,
                        vertical: 24.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLoggedIn ? 'ENTER DASHBOARD' : 'START FREE TRIAL',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(width: 12.w),
                        Icon(LucideIcons.arrowRight, size: 20.sp),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // THE FLOW
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: isMobile ? 40.h : 80.h,
              ),
              child: Column(
                children: [
                  Text(
                    'OPERATIONS',
                    style: TextStyle(
                      color: const Color(0xFFFF5C00),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'FROM SCAN TO SERVED',
                    style: TextStyle(
                      fontSize: isMobile ? 24.sp : 32.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 48.h),
                  Wrap(
                    spacing: 24.w,
                    runSpacing: 24.h,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFlowCard(
                        LucideIcons.scanLine,
                        'QR Scan',
                        'Customers scan a custom table QR. No app required.',
                        isMobile,
                      ),
                      _buildFlowCard(
                        LucideIcons.trendingUp,
                        'Smart Upsell',
                        'Automated pairings appear instantly to boost your ticket size.',
                        isMobile,
                      ),
                      _buildFlowCard(
                        LucideIcons.utensils,
                        'Kitchen Sync',
                        'Orders fly directly to your Kitchen Command Center.',
                        isMobile,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // JOURNEY (Scroll Locked on Desktop)
            Listener(
              onPointerSignal: isMobile
                  ? null
                  : (pointerSignal) {
                      if (!_expLocked) return;
                      if (pointerSignal is PointerScrollEvent) {
                        if (pointerSignal.scrollDelta.dy > 0 &&
                            _activeLevel < 4) {
                          setState(() => _activeLevel++);
                        } else if (pointerSignal.scrollDelta.dy < 0 &&
                            _activeLevel > 1) {
                          setState(() => _activeLevel--);
                        } else if (pointerSignal.scrollDelta.dy > 0 &&
                            _activeLevel == 4) {
                          setState(() => _expLocked = false);
                        }
                      }
                    },
              child: Container(
                height: isMobile ? null : 1.sh,
                color: const Color(0xFF0F172A),
                padding: EdgeInsets.all(isMobile ? 24.r : 40.r),
                child: Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  children: [
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) SizedBox(height: 40.h),
                          Text(
                            'THE CUSTOMER\nLIFECYCLE.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 32.sp : 40.sp,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 40.h),
                          _buildJourneyStep(
                            1,
                            '01. Scan Table QR',
                            'Fastest entry into your digital world.',
                            isMobile,
                          ),
                          _buildJourneyStep(
                            2,
                            '02. Browse Digital Menu',
                            'High-density catalog with 3D icons.',
                            isMobile,
                          ),
                          _buildJourneyStep(
                            3,
                            '03. Smart Add & Upsell',
                            'Selecting an item triggers automated pairings.',
                            isMobile,
                          ),
                          _buildJourneyStep(
                            4,
                            '04. Order Confirmed',
                            'Instant confirmation with real-time kitchen sync.',
                            isMobile,
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile) SizedBox(width: 40.w),
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Container(
                        height: isMobile ? 300.h : null,
                        margin: EdgeInsets.only(
                          top: isMobile ? 32.h : 0,
                          bottom: isMobile ? 40.h : 0,
                        ),
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Center(
                          child: Text(
                            'Level $_activeLevel Visual',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // PRICING
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: isMobile ? 40.h : 80.h,
              ),
              child: Column(
                children: [
                  Text(
                    'INVEST IN GROWTH.',
                    style: TextStyle(
                      fontSize: isMobile ? 32.sp : 48.sp,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40.h),
                  Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: SizedBox(
                          width: isMobile ? double.infinity : null,
                          child: _buildPricingCard('Essential', '1,999', false),
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? 0 : 24.w,
                        height: isMobile ? 24.h : 0,
                      ),
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: SizedBox(
                          width: isMobile ? double.infinity : null,
                          child: _buildPricingCard(
                            'Professional',
                            '3,999',
                            true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CONTACT FORM
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: isMobile ? 40.h : 80.h,
              ),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    'REQUEST YOUR DEMO',
                    style: TextStyle(
                      fontSize: isMobile ? 24.sp : 32.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: 'Owner / Manager Name',
                      labelStyle: TextStyle(fontSize: 12.sp),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _restaurantController,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: 'Restaurant Name',
                      labelStyle: TextStyle(fontSize: 12.sp),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _phoneController,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: 'WhatsApp Contact',
                      labelStyle: TextStyle(fontSize: 12.sp),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton(
                      onPressed: _handleContactSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: 24.h,
                          horizontal: 48.w,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'SCALE MY KITCHEN NOW',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FOOTER
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(40.r),
              color: const Color(0xFF0F172A),
              alignment: Alignment.center,
              child: Text(
                '© 2026 Scan Serve Technologies',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowCard(
    IconData icon,
    String title,
    String desc,
    bool isMobile,
  ) {
    return Container(
      width: isMobile ? double.infinity : 300.w,
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: CustomColors.slate.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40.sp, color: const Color(0xFFFF5C00)),
          SizedBox(height: 24.h),
          Text(
            title,
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 16.h),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyStep(
    int level,
    String title,
    String desc,
    bool isMobile,
  ) {
    bool isActive = isMobile ? true : _activeLevel == level;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withAlpha(20) : Colors.transparent,
        border: Border.all(
          color: isActive ? const Color(0xFFFF5C00) : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              color: isActive ? const Color(0xFFFF5C00) : Colors.white54,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isActive)
            Text(
              desc,
              style: TextStyle(fontSize: 14.sp, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(String variant, String price, bool isPro) {
    return Container(
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: isPro ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(
          color: isPro
              ? const Color(0xFFFF5C00).withAlpha(100)
              : Colors.grey.shade200,
          width: isPro ? 4.w : 1.w,
        ),
      ),
      child: Column(
        children: [
          Text(
            variant.toUpperCase(),
            style: TextStyle(
              fontSize: 12.sp,
              color: isPro ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            '₹$price',
            style: TextStyle(
              color: isPro ? Colors.white : Colors.black,
              fontSize: 48.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isPro ? Colors.white : const Color(0xFF0F172A),
                foregroundColor: isPro ? Colors.black : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 48.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'SELECT',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Adding Custom Colors Ext to Material for exact mapping
extension CustomColors on Colors {
  static const MaterialColor slate = MaterialColor(0xFF64748B, <int, Color>{
    100: Color(0xFFF1F5F9),
    200: Color(0xFFE2E8F0),
  });
}
