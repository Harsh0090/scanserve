import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Carousel Section (Hidden on small screens)
          if (1.sw >= 900)
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
                      padding: EdgeInsets.all(64.0.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _onboardingData[_activeSlide]['title']!,
                            style: TextStyle(
                              fontSize: 48.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            _onboardingData[_activeSlide]['description']!,
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          Row(
                            children: List.generate(_onboardingData.length, (
                              index,
                            ) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.only(right: 8.w),
                                height: 6.h,
                                width: _activeSlide == index ? 32.w : 8.w,
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
                    vertical: 1.sh < 700 ? 24.0.h : 48.0.h,
                  ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 420.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C00),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Q',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'QRserve',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        const Text(
                          'Access your admin control center.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 40.h),

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

                        SizedBox(height: 16.h),
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_isLoading
                                ? _handleLogin
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5C00),
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Enter Dashboard',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.sp,
                                          color: _isFormValid
                                              ? Colors.white
                                              : Colors.grey.shade400,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        LucideIcons.arrowRight,
                                        size: 20.sp,
                                        color: _isFormValid
                                            ? Colors.white
                                            : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: 40.h),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Don\'t have an account? ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              InkWell(
                                onTap: () => context.go('/signup'),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: const Color(0xFFFF5C00),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.sp,
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
      padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1.5,
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
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        obscureText: isPassword,
        onChanged: onChanged,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
          fontSize: 14.sp,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18.h),
        ),
      ),
    );
  }
}
