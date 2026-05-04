import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import 'package:go_router/go_router.dart';

class CreateBranchPage extends ConsumerStatefulWidget {
  const CreateBranchPage({super.key});
  @override
  ConsumerState<CreateBranchPage> createState() => _CreateBranchPageState();
}

class _CreateBranchPageState extends ConsumerState<CreateBranchPage> {
  String _name = '';
  String _city = '';
  String _businessType = 'RESTAURANT';
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _branches = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranches();
    });
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    try {
      final res = await apiFetch('/api/restaurants');
      if (res is List) {
        if (mounted) setState(() => _branches = res);
      }
    } catch (e) {
      debugPrint("LOAD_BRANCH_ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBranch() async {
    if (_name.isEmpty || _city.isEmpty || _businessType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch details are incomplete')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await apiFetch(
        '/api/restaurants',
        method: 'POST',
        data: {'name': _name, 'city': _city, 'businessType': _businessType},
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Empire Expanded! 🎉')));
        setState(() {
          _name = '';
          _city = '';
          _businessType = 'RESTAURANT';
        });
        _loadBranches();
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (!mounted) return;

      if (errorStr.contains('TRIAL_BRANCH_LIMIT_REACHED')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Trial Limit Reached'),
            content: const Text(
              'Your trial branch limit is reached. Add more branches after trial ends.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (errorStr.contains('BRANCH_LIMIT_EXCEEDED')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Upgrade Required'),
            content: const Text(
              'Branch limit exceeded. Please upgrade your subscription to add securely more branches.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('UNDERSTOOD'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorStr)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Top Navigation Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (MediaQuery.of(context).size.width > 900.w)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(right: 16.w),
                          child: IconButton(
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: Icon(
                              LucideIcons.menu,
                              size: 24.sp,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expand Empire',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'INFRASTRUCTURE / BRANCH REGISTRY',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.trendingUp,
                        size: 14.sp,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'OUTLETS: ${_branches.length}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Pane: Registry Form (Desktop)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (MediaQuery.of(context).size.width <= 900.w)
                      return const SizedBox.shrink();
                    return _buildFormPane();
                  },
                ),

                // Right Side: Live Network Preview
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.globe,
                                  size: 18.sp,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'ACTIVE NETWORK LEDGER',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                'LIVE SYNC',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),

                        Expanded(
                          child: _branches.isEmpty
                              ? Center(
                                  child: Container(
                                    padding: EdgeInsets.all(48.r),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        style: BorderStyle.none,
                                      ),
                                      borderRadius: BorderRadius.circular(32.r),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.building2,
                                          size: 64.sp,
                                          color: Colors.black12,
                                        ),
                                        SizedBox(height: 16.h),
                                        Text(
                                          'NO BRANCHES DEPLOYED YET',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400.w,
                                        mainAxisExtent: 220.h,
                                        crossAxisSpacing: 24.w,
                                        mainAxisSpacing: 24.h,
                                      ),
                                  itemCount: _branches.length,
                                  itemBuilder: (ctx, idx) {
                                    final b = _branches[idx];
                                    return Container(
                                      padding: EdgeInsets.all(32.r),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          40.r,
                                        ),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.shade50
                                                .withAlpha(20),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12.r),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        16.r,
                                                      ),
                                                ),
                                                child: Icon(
                                                  LucideIcons.store,
                                                  size: 24.sp,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        16.r,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade100,
                                                  ),
                                                ),
                                                child: Text(
                                                  'ONLINE',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.green,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            b['name'] ?? 'Unnamed',
                                            style: TextStyle(
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Icon(
                                                LucideIcons.mapPin,
                                                size: 14.sp,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: Text(
                                                  b['city'] ??
                                                      'Unknown location',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () => context.go(
                                              '/dashboard/createmanager',
                                            ), // Navigating, passing id is omitted for simplicity in port
                                            child: Container(
                                              padding: EdgeInsets.only(
                                                top: 16.h,
                                              ),
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    color: Colors.black12,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'CREATE MANAGER',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.grey,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                  Icon(
                                                    LucideIcons.chevronRight,
                                                    size: 16.sp,
                                                    color: Colors.grey,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width > 400.w
          ? 400.w
          : MediaQuery.of(context).size.width * 0.9,
      child: SafeArea(child: _buildFormPane(isDrawer: true)),
    );
  }

  Widget _buildFormPane({bool isDrawer = false}) {
    return Container(
      width: isDrawer ? double.infinity : 450.w,
      padding: EdgeInsets.all(isDrawer ? 24.r : 40.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 10.r),
              ],
            ),
            child: Icon(LucideIcons.plus, size: 24.sp, color: Colors.orange),
          ),
          SizedBox(height: 24.h),
          Text(
            'Branch\nRegistration',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Deploy a new point of sale to your network.',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 32.h),

          Expanded(
            child: ListView(
              children: [
                Text(
                  'ESTABLISHMENT NAME',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.store, size: 20.sp, color: Colors.grey),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => _name = v,
                          decoration: InputDecoration(
                            hintText: 'e.g. Malviya Nagar Bistro',
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                Text(
                  'OPERATING CITY',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 20.sp, color: Colors.grey),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => _city = v,
                          decoration: InputDecoration(
                            hintText: 'e.g. Mumbai',
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                Text(
                  'BUSINESS TYPE',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _businessType = 'RESTAURANT'),
                        child: Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: _businessType == 'RESTAURANT'
                                ? Colors.orange.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: _businessType == 'RESTAURANT'
                                  ? Colors.orange
                                  : Colors.grey.shade200,
                              width: 2.r,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cafe / Restaurant',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Tables, dine-in, POS',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _businessType = 'FOOD_TRUCK'),
                        child: Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: _businessType == 'FOOD_TRUCK'
                                ? Colors.orange.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: _businessType == 'FOOD_TRUCK'
                                  ? Colors.orange
                                  : Colors.grey.shade200,
                              width: 2.r,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Food Truck',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Walk-in orders only',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                Container(
                  padding: EdgeInsets.all(16.sp),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.shieldCheck,
                            size: 16.sp,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'CLOUD DEPLOYMENT',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Provisioned with Menu Master Template and live sync.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _createBranch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting)
                        SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.w,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (_isSubmitting)
                        SizedBox(width: 12.w)
                      else
                        const SizedBox.shrink(),
                      Text(
                        _isSubmitting ? 'INITIALIZING...' : 'INITIALIZE BRANCH',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
