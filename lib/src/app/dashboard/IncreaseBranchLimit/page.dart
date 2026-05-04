import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';

class ManagePlanPage extends ConsumerStatefulWidget {
  const ManagePlanPage({super.key});
  @override
  ConsumerState<ManagePlanPage> createState() => _ManagePlanPageState();
}

class _ManagePlanPageState extends ConsumerState<ManagePlanPage> {
  Map<String, dynamic> _info = {
    'plan': 'ACTIVE',
    'isTrialActive': true,
    'branchLimits': {'restaurant': 1, 'foodTruck': 0},
  };

  bool _isLoading = true;
  bool _isActionLoading = false;
  int _restaurantCount = 1;
  int _foodTruckCount = 0;
  bool _showTrialModal = false;

  static const int RESTAURANT_UNIT_PRICE = 3999;
  static const int FOOD_TRUCK_UNIT_PRICE = 1999;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSubscriptionInfo();
    });
  }

  Future<void> _fetchSubscriptionInfo() async {
    setState(() => _isLoading = true);
    try {
      final res = await apiFetch('/api/subscription/info');
      if (res['branchLimits'] != null) {
        setState(() {
          _info = res;
          _restaurantCount = res['branchLimits']['restaurant'] ?? 0;
          _foodTruckCount = res['branchLimits']['foodTruck'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync subscription data: $e')),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleConfirm() async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (_info['branchLimits'] == null || user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data not loaded')));
      return;
    }

    final isRestaurantIncreased =
        _restaurantCount > (_info['branchLimits']['restaurant'] ?? 0);
    final isFoodTruckIncreased =
        _foodTruckCount > (_info['branchLimits']['foodTruck'] ?? 0);
    final trialActive = user['subscriptionStatus'] == 'TRIAL_ACTIVE';
    final trialExpired =
        user['subscriptionStatus'] == 'EXPIRED' && user['plan'] == 'TRIAL';
    final subscriptionActive = user['subscriptionStatus'] == 'ACTIVE';

    if (trialActive && !isRestaurantIncreased && !isFoodTruckIncreased) {
      setState(() => _showTrialModal = true);
      return;
    }

    if (trialExpired) {
      await _processSubscriptionActivation();
      return;
    }

    if (subscriptionActive) {
      if (!isRestaurantIncreased && !isFoodTruckIncreased) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No changes detected')));
        return;
      }

      setState(() => _isActionLoading = true);
      try {
        if (isRestaurantIncreased)
          await _processUpgrade('RESTAURANT', _restaurantCount);
        if (isFoodTruckIncreased)
          await _processUpgrade('FOOD_TRUCK', _foodTruckCount);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expansion action failed')),
          );
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
      return;
    }

    if (isRestaurantIncreased)
      await _processUpgrade('RESTAURANT', _restaurantCount);
    if (isFoodTruckIncreased)
      await _processUpgrade('FOOD_TRUCK', _foodTruckCount);
  }

  Future<void> _processSubscriptionActivation() async {
    try {
      final baseRes = await apiFetch(
        '/api/payment/activate-subscription',
        method: 'POST',
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Checkout Authenticated (Razorpay)'),
            content: Text(
              'Order ID: ${baseRes['orderId']}\nAmount: ₹${baseRes['amount']}\n\nBackend has successfully generated the checkout session. Implement Razorpay Flutter SDK to process the final transaction natively.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('UNDERSTOOD'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activation failed: $e')));
    }
  }

  Future<void> _processUpgrade(String type, int count) async {
    try {
      final res = await apiFetch(
        '/api/payment/increase-branches',
        method: 'POST',
        data: {'type': type, 'newLimit': count},
      );

      if (res['trial'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$type updated during trial')));
          setState(() {
            _info['branchLimits'] = res['branchLimits'];
          });
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Upgrade Authenticated (Razorpay)'),
            content: Text(
              'Order ID: ${res['orderId']}\nAmount: ₹${res['amount']}\n\nBackend has securely generated the expansion session token. Implement Razorpay Flutter SDK to process this transaction.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('UNDERSTOOD'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upgrade failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFCF6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D00)),
        ),
      );
    }

    final int currentTotal =
        (_restaurantCount * RESTAURANT_UNIT_PRICE) +
        (_foodTruckCount * FOOD_TRUCK_UNIT_PRICE);
    final bool isTrial = _info['isTrialActive'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1100.w),
                child: Column(
                  children: [
                    // Header
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16.w,
                      runSpacing: 16.h,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D00),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Text(
                                'SUBSCRIPTION MANAGER',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -1,
                                ),
                                children: [
                                  TextSpan(text: 'Manage Your '),
                                  TextSpan(
                                    text: 'Outlets',
                                    style: TextStyle(color: Color(0xFFFF4D00)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: isTrial
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isTrial
                                      ? LucideIcons.clock
                                      : LucideIcons.shieldCheck,
                                  size: 16.sp,
                                  color: isTrial ? Colors.orange : Colors.green,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.grey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    isTrial
                                        ? 'TRIAL PERIOD'
                                        : 'SUBSCRIPTION ACTIVE',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.h),

                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isMobile = constraints.maxWidth < 800.w;
                        return Flex(
                          direction: isMobile ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Branch Selection Panel
                            Expanded(
                              flex: isMobile ? 0 : 3,
                              child: Container(
                                padding: EdgeInsets.all(32.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40.r),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SELECT BRANCHES',
                                              style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'ADD OR REMOVE LOCATIONS',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'CURRENT LIMITS',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.orange,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            Text(
                                              '${_info['branchLimits']?['restaurant'] ?? 0} RES | ${_info['branchLimits']?['foodTruck'] ?? 0} TRK',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 32.h),

                                    // Restaurant Card
                                    Container(
                                      padding: EdgeInsets.all(24.r),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(
                                          24.r,
                                        ),
                                        border: Border.all(
                                          color: Colors.grey.shade100,
                                        ),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 16.w,
                                        runSpacing: 16.h,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        16.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.grey.shade100,
                                                  ),
                                                ),
                                                child: Icon(
                                                  LucideIcons.store,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                              SizedBox(width: 16.w),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'RESTAURANT / CAFE',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    '₹3,999 / MONTHLY',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(8.r),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => _restaurantCount =
                                                        _restaurantCount > 0
                                                        ? _restaurantCount - 1
                                                        : 0,
                                                  ),
                                                  icon: Icon(
                                                    LucideIcons.minus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  splashRadius: 24,
                                                ),
                                                Container(
                                                  width: 32.w,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$_restaurantCount',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => _restaurantCount++,
                                                  ),
                                                  icon: Icon(
                                                    LucideIcons.plus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  splashRadius: 24,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16.h),

                                    // Food Truck Card
                                    Container(
                                      padding: EdgeInsets.all(24.r),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(
                                          24.r,
                                        ),
                                        border: Border.all(
                                          color: Colors.grey.shade100,
                                        ),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 16.w,
                                        runSpacing: 16.h,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        16.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.grey.shade100,
                                                  ),
                                                ),
                                                child: Icon(
                                                  LucideIcons.truck,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              SizedBox(width: 16.w),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'FOOD TRUCK',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF0F172A),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    '₹1,999 / MONTHLY',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(8.r),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => _foodTruckCount =
                                                        _foodTruckCount > 0
                                                        ? _foodTruckCount - 1
                                                        : 0,
                                                  ),
                                                  icon: Icon(
                                                    LucideIcons.minus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  splashRadius: 24,
                                                ),
                                                Container(
                                                  width: 32.w,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$_foodTruckCount',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => _foodTruckCount++,
                                                  ),
                                                  icon: Icon(
                                                    LucideIcons.plus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  splashRadius: 24,
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
                            if (isMobile)
                              SizedBox(height: 24.h)
                            else
                              SizedBox(width: 24.w),

                            // Summary Panel
                            Expanded(
                              flex: isMobile ? 0 : 2,
                              child: Container(
                                padding: EdgeInsets.all(32.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(40.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(50),
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FINAL BILLING SUMMARY',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.orange,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    SizedBox(height: 24.h),

                                    Container(
                                      padding: EdgeInsets.only(bottom: 24.h),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white24,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '$_restaurantCount × RESTAURANT',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              Text(
                                                '₹${(_restaurantCount * 3999)}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '$_foodTruckCount × FOOD TRUCK',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              Text(
                                                '₹${(_foodTruckCount * 1999)}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 24.h),

                                    Text(
                                      'TOTAL MONTHLY BILL',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '₹$currentTotal',
                                          style: TextStyle(
                                            fontSize: 40.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          '/ MONTH',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 32.h),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isActionLoading
                                            ? null
                                            : _handleConfirm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFF4D00,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 20.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (_isActionLoading)
                                              SizedBox(
                                                width: 16.w,
                                                height: 16.h,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            else
                                              Icon(
                                                LucideIcons.creditCard,
                                                size: 16.sp,
                                              ),
                                            SizedBox(width: 12.w),
                                            Text(
                                              _isActionLoading
                                                  ? 'VERIFYING...'
                                                  : 'CONFIRM EXPANSION',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            if (!_isActionLoading) ...[
                                              SizedBox(width: 12.w),
                                              Icon(
                                                LucideIcons.arrowRight,
                                                size: 16.sp,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 24.h),
                                    Center(
                                      child: Text(
                                        'PAYMENT SECURED VIA RAZORPAY',
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_showTrialModal)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 400.w),
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          LucideIcons.alertCircle,
                          color: Colors.orange,
                          size: 32.sp,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            fontStyle: FontStyle.italic,
                          ),
                          children: [
                            TextSpan(text: 'TRIAL POLICY '),
                            TextSpan(
                              text: 'NOTICE',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Payment cannot be made during the trial phase. Official payments are only available after your trial period is completed.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REQUIREMENT',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'To expand during trial, you must select a number higher than your current branch count.',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _showTrialModal = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'UNDERSTAND & CONTINUE',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
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
    );
  }
}
