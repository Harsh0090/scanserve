import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';

class ManagerCreatePage extends ConsumerStatefulWidget {
  const ManagerCreatePage({super.key});
  @override
  ConsumerState<ManagerCreatePage> createState() => _ManagerCreatePageState();
}

class _ManagerCreatePageState extends ConsumerState<ManagerCreatePage> {
  List<dynamic> _branches = [];
  String _branchId = '';
  String _email = '';
  String _password = '';
  String _permissionLevel = 'LIMITED';
  String _searchTerm = '';

  bool _isLoading = true;
  bool _isSubmitting = false;

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
      } else {
        throw Exception(res['message'] ?? 'Failed to load branches');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_branchId.isEmpty ||
        _email.isEmpty ||
        _password.isEmpty ||
        _permissionLevel.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await apiFetch(
        '/api/restaurants/$_branchId/assign-manager',
        method: 'POST',
        data: {
          'email': _email,
          'password': _password,
          'permissionLevel': _permissionLevel,
        },
      );

      if (res['manager'] != null ||
          res['message']?.toString().toLowerCase().contains('success') ==
              true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Manager assigned successfully!')),
          );
          setState(() {
            _email = '';
            _password = '';
          });
          _loadBranches();
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        }
      } else {
        throw Exception(res['message'] ?? 'Assignment failed');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _removeManager(String branchId) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Manager Access?'),
        content: const Text(
          'Are you sure you want to remove the manager for this branch? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'REMOVE',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (act != true) return;

    try {
      await apiFetch(
        '/api/restaurants/$branchId/remove-manager',
        method: 'DELETE',
      );
      await _loadBranches();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager access revoked successfully')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to revoke manager: $e')));
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

    final filteredBranches = _branches.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchTerm.toLowerCase());
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Header Action Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.w,
              runSpacing: 16.h,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'ACCESS CONTROL',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isDesktop = MediaQuery.of(context).size.width > 900.w;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isDesktop ? 250.w : 200.w,
                          height: 48.h,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.search,
                                size: 16.sp,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => _searchTerm = v),
                                  decoration: const InputDecoration(
                                    hintText: 'Search...',
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
                        if (!isDesktop) ...[
                          SizedBox(width: 16.w),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: Icon(LucideIcons.userPlus, size: 16.sp),
                            label: Text(
                              'NEW',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D00),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 16.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Pane: Registration Form (Desktop)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    if (MediaQuery.of(context).size.width <= 900.w)
                      return const SizedBox.shrink();
                    return _buildFormPane();
                  },
                ),

                // Right Pane: Live Staff Ledger
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(32.r),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.users,
                                  size: 18.sp,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'MANAGEMENT TEAM',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.shieldCheck,
                                  size: 14.sp,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'SECURE CLOUD SYNC',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),

                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400.w,
                                  mainAxisExtent: 220.h,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                            itemCount: filteredBranches.length,
                            itemBuilder: (ctx, idx) {
                              final b = filteredBranches[idx];
                              final hasManager = b['manager'] != null;
                              return Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32.r),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 48.w,
                                          height: 48.h,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                          ),
                                          child: Icon(
                                            LucideIcons.building2,
                                            size: 24.sp,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (hasManager)
                                          IconButton(
                                            onPressed: () =>
                                                _removeManager(b['_id']),
                                            icon: Icon(
                                              LucideIcons.trash2,
                                              size: 16.sp,
                                              color: Colors.red,
                                            ),
                                          )
                                        else
                                          IconButton(
                                            onPressed: () {},
                                            icon: Icon(
                                              LucideIcons.trash2,
                                              size: 16.sp,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      b['name'] ?? 'Unnamed',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        Icon(
                                          LucideIcons.mail,
                                          size: 12.sp,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            b['manager']?['email'] ??
                                                'No manager assigned',
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
                                    SizedBox(height: 16.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12.h,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.black12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'STATUS',
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.grey,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: hasManager
                                                  ? Colors.green.shade50
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              hasManager ? 'ACTIVE' : 'VACANT',
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w900,
                                                color: hasManager
                                                    ? Colors.green.shade700
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
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
      padding: EdgeInsets.all(isDrawer ? 24.r : 32.r),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.userPlus, size: 14.sp, color: Colors.orange),
                SizedBox(width: 8.w),
                Text(
                  'NEW ASSIGNMENT',
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
          SizedBox(height: 32.h),

          Expanded(
            child: ListView(
              children: [
                Text(
                  'TARGET BRANCH',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.building2,
                        size: 18.sp,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text(
                              'Select Outlet',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            value: _branchId.isEmpty ? null : _branchId,
                            items: _branches
                                .map(
                                  (b) => DropdownMenuItem<String>(
                                    value: b['_id'],
                                    child: Text(
                                      b['name'],
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _branchId = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                Text(
                  'LOGIN EMAIL',
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
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.mail, size: 18.sp, color: Colors.grey),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => _email = v,
                          decoration: InputDecoration(
                            hintText: 'manager@email.com',
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
                  'ACCESS PASSWORD',
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
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.lock, size: 18.sp, color: Colors.grey),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: TextField(
                          obscureText: true,
                          onChanged: (v) => _password = v,
                          decoration: InputDecoration(
                            hintText: '••••••••',
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
                  'MANAGER ACCESS LEVEL',
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
                            setState(() => _permissionLevel = 'LIMITED'),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: _permissionLevel == 'LIMITED'
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: _permissionLevel == 'LIMITED'
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'OPERATIONS ONLY',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: _permissionLevel == 'LIMITED'
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _permissionLevel = 'FULL'),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: _permissionLevel == 'FULL'
                                ? const Color(0xFFFF4D00)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: _permissionLevel == 'FULL'
                                  ? const Color(0xFFFF4D00)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'FULL FINANCIAL',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: _permissionLevel == 'FULL'
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),

                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: Icon(LucideIcons.arrowRight, size: 16.sp),
                  label: Text(
                    _isSubmitting ? 'WORKING...' : 'DEPLOY MANAGER',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
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
}
