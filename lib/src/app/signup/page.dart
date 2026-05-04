import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/apiClient.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../context/AuthContext.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  bool _isLoading = false;
  int _activeSlide = 0;
  Timer? _timer;

  final Map<String, dynamic> _form = {
    'organizationName': '',
    'businessType': '',
    'mode': '',
    'email': '',
    'password': '',
    'phone': '',
    'gstEnabled': false,
    'gstRate': 5,
  };

  final List<Map<String, String>> _onboardingData = [
    {
      "image": "https://images.unsplash.com/photo-1595079676339-1534801ad6cf?auto=format&fit=crop&q=80&w=1200",
      "title": "Simple QR Access",
      "description": "Customers scan a unique QR code at their table to instantly access your digital storefront."
    },
    {
      "image": "https://images.unsplash.com/photo-1556742044-3c52d6e88c62?auto=format&fit=crop&q=80&w=1200",
      "title": "Browse the Menu",
      "description": "A beautiful, interactive menu on their own device. No more waiting for physical menus."
    },
    {
      "image": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=1200",
      "title": "Instant Ordering",
      "description": "Orders go directly from the customer's phone to your kitchen. Speed up service and reduce errors."
    },
    {
      "image": "https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&q=80&w=1200",
      "title": "Manage with Ease",
      "description": "Watch orders arrive in real-time on your dashboard. Track sales and manage inventory effortlessly."
    }
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

  bool get _isFormValid {
    return _form['businessType'] != '' &&
           _form['mode'] != '' &&
           _form['organizationName'].toString().isNotEmpty &&
           _form['email'].toString().contains('@') &&
           _form['phone'].toString().length >= 10 &&
           _form['password'].toString().length >= 6;
  }

  Future<void> _submit() async {
    if (!_isFormValid || _isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final res = await apiFetch('/api/auth/signup', method: 'POST', data: _form);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
        );
        
        final userData = res['data'] ?? res;
        ref.read(authProvider.notifier).setUserData(userData is Map<String, dynamic> ? userData : res);

        final type = userData['businessType'] ?? '';
        if (type == "RESTAURANT") {
          context.go('/dashboard/pos');
        } else {
          context.go('/dashboard/orders');
        }
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      padding: EdgeInsets.all(64.r),
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
                            children: List.generate(_onboardingData.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.only(right: 8.w),
                                height: 6.h,
                                width: _activeSlide == index ? 32.w : 8.w,
                                decoration: BoxDecoration(
                                  color: _activeSlide == index ? const Color(0xFFFF5C00) : Colors.white38,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              );
                            }),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),

          // Form Section
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 1.sh < 700 ? 24.h : 48.h,
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
                          'Create Partner Account',
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        const Text(
                          'Join the network of modern food businesses.',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 40.h),

                        // Form Fields
                        _buildLabel('Business Nature'),
                        Container(
                          margin: EdgeInsets.only(bottom: 24.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.building2, color: Colors.grey, size: 20.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _form['businessType'] == '' ? null : _form['businessType'],
                                    hint: const Text('Select Business Type', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                                    isExpanded: true,
                                    icon: const Icon(LucideIcons.chevronDown, color: Colors.grey),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'RESTAURANT',
                                        child: Text(
                                          'Cafe / Restaurant',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'FOOD_TRUCK',
                                        child: Text(
                                          'Food Truck',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) => setState(() {
                                      _form['businessType'] = val!;
                                      _form['mode'] = ''; // Reset mode on business type change
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_form['businessType'] != '') ...[
                          _buildLabel('How will you use this?'),
                          Column(
                            children: [
                              _buildModeCard(
                                value: "quick",
                                title: "Orders only",
                                sub: "Fast mode — café, food truck, stall",
                                bullets: ["1-tap order creation", "Auto token numbers", "Jumps straight to Preparing"],
                              ),
                              SizedBox(height: 12.h),
                              _buildModeCard(
                                value: "full",
                                title: "Full setup",
                                sub: "Restaurant, tables, kitchen display",
                                bullets: ["Table management & QR menus", "Full lifecycle: Accept → Served", "GST billing"],
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                        ],

                        _buildLabel('Brand Name'),
                        _buildTextField(LucideIcons.edit2, 'e.g. Scan Serve', (val) => _form['organizationName'] = val, false), // edit2 used securely
                        
                        _buildLabel('Email'),
                        _buildTextField(LucideIcons.mail, 'admin@example.com', (val) => _form['email'] = val, false),

                        _buildLabel('Phone'),
                        _buildTextField(LucideIcons.phone, '9876543210', (val) => _form['phone'] = val, false),

                        _buildLabel('Password'),
                        _buildTextField(LucideIcons.lock, '••••••••', (val) => _form['password'] = val, true),

                        SizedBox(height: 8.h),
                        _buildLabel('GST Settings'),
                        Row(
                          children: [
                            Checkbox(
                              value: _form['gstEnabled'],
                              activeColor: const Color(0xFFFF5C00),
                              onChanged: (val) => setState(() => _form['gstEnabled'] = val!),
                            ),
                            const Text('Enable GST', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                        if (_form['gstEnabled'])
                          Container(
                            margin: EdgeInsets.only(top: 8.h, bottom: 24.h),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _form['gstRate'],
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                    value: 5,
                                    child: Text('5% GST', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                  ),
                                  DropdownMenuItem(
                                    value: 18,
                                    child: Text('18% GST', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _form['gstRate'] = val!),
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 16.h),
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_isLoading ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5C00),
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'GET STARTED',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w900,
                                          color: _isFormValid ? Colors.white : Colors.grey.shade400,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        LucideIcons.arrowRight,
                                        size: 20.sp,
                                        color: _isFormValid ? Colors.white : Colors.grey.shade400,
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
                              Text(
                                'Already have an account? ',
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              InkWell(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(fontSize: 12.sp, color: const Color(0xFFFF5C00), fontWeight: FontWeight.w900),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
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

  Widget _buildTextField(IconData icon, String hint, Function(String) onChanged, bool isPassword) {
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
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
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
  Widget _buildModeCard({
    required String value,
    required String title,
    required String sub,
    required List<String> bullets,
  }) {
    bool isSelected = _form['mode'] == value;
    return InkWell(
      onTap: () => setState(() => _form['mode'] = value),
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5C00) : Colors.grey.shade200,
            width: 2.r,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 12.h),
            ...bullets.map((b) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: [
                      Container(
                        width: 4.r,
                        height: 4.r,
                        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        b,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
