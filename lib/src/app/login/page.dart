import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/apiClient.dart';
import '../context/AuthContext.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isLoading = false;
  int _activeSlide = 0;
  Timer? _timer;

  String _email = '';
  String _password = '';

  final List<Map<String, String>> _onboardingData = [
    {
      "image":
          "https://images.unsplash.com/photo-1595079676339-1534801ad6cf?auto=format&fit=crop&q=80&w=1200",
      "title": "Simple QR Access",
      "description":
          "Customers scan a unique QR code at their table to instantly access your digital storefront.",
    },
    {
      "image":
          "https://images.unsplash.com/photo-1556742044-3c52d6e88c62?auto=format&fit=crop&q=80&w=1200",
      "title": "Browse the Menu",
      "description":
          "A beautiful, interactive menu on their own device. No more waiting for physical menus.",
    },
    {
      "image":
          "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=1200",
      "title": "Instant Ordering",
      "description":
          "Orders go directly from the customer's phone to your kitchen. Speed up service and reduce errors.",
    },
    {
      "image":
          "https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&q=80&w=1200",
      "title": "Manage with Ease",
      "description":
          "Watch orders arrive in real-time on your dashboard. Track sales and manage inventory effortlessly.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _activeSlide = (_activeSlide + 1) % _onboardingData.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isFormValid => _email.contains('@') && _password.isNotEmpty;

  Future<void> _handleLogin() async {
    if (!_isFormValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final res = await apiFetch(
        '/api/auth/login',
        method: 'POST',
        data: {'email': _email, 'password': _password},
      );
      print("🔍 Login Response: $res");

      // Directly update the context with the login response
      // Robust check: if we got here without exception, and we have data/token, it's a success
      final userData = res['data'] ?? res;
      final bool looksSubstantial = (userData is Map && (userData.containsKey('token') || userData.containsKey('restaurantId')));
      print("📝 Evaluation: Success=${res['success']}, LooksSubstantial=$looksSubstantial");

      if (res['success'] == true || (res is Map && looksSubstantial)) {
        print("✅ Login Successful, updating user data");
        ref.read(authProvider.notifier).setUserData(userData is Map<String, dynamic> ? userData : res);
      } else {
        print("⚠️ Login response ambiguous, reloading session");
        // Fallback: reload session if response didn't contain full user info
        await ref.read(authProvider.notifier).loadSession();
      }

      if (mounted) {
        print("🚀 Redirecting to dashboard");
        context.go('/dashboard/orders');
      }
    } catch (e) {
      print("❌ Login Failed Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard/orders');
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Carousel Section (Hidden on small screens)
          if (screenWidth >= 900)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(seconds: 1),
                    child: Image.network(
                      _onboardingData[_activeSlide]['image']!,
                      key: ValueKey<int>(_activeSlide),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Container(color: Colors.black.withAlpha(100)), // Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(36.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _onboardingData[_activeSlide]['title']!,
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            _onboardingData[_activeSlide]['description']!,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Row(
                            children: List.generate(_onboardingData.length, (
                              index,
                            ) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.only(right: 6.w),
                                height: 4.h,
                                width: _activeSlide == index ? 24.w : 6.w,
                                decoration: BoxDecoration(
                                  color: _activeSlide == index
                                      ? const Color(0xFFFF5C00)
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Form Section
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0.w,
                  vertical: isTablet ? 24.0.h : (1.sh < 700 ? 16.0.h : 32.0.h),
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32.r,
                              height: 32.r,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C00),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Q',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'QRserve',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Access your admin control center.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Form Fields
                        _buildLabel('Email Address'),
                        _buildTextField(
                          LucideIcons.mail,
                          'admin@qrserve.com',
                          (val) => _email = val,
                          false,
                        ),

                        _buildLabel('Secret Password'),
                        _buildTextField(
                          LucideIcons.lock,
                          '••••••••',
                          (val) => _password = val,
                          true,
                        ),

                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_isLoading
                                ? _handleLogin
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5C00),
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Enter Dashboard',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5.sp,
                                          color: _isFormValid
                                              ? Colors.white
                                              : Colors.grey.shade400,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        LucideIcons.arrowRight,
                                        size: 16.sp,
                                        color: _isFormValid
                                            ? Colors.white
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: 24.h),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Don\'t have an account? ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              InkWell(
                                onTap: () => context.go('/signup'),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: const Color(0xFFFF5C00),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.sp,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String hint,
    Function(String) onChanged,
    bool isPassword,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        obscureText: isPassword,
        onChanged: onChanged,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
          fontSize: 13.5.sp,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5.sp),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 18.sp),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ),
    );
  }
}

