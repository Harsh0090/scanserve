import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';

class ItemSalesPage extends ConsumerStatefulWidget {
  const ItemSalesPage({super.key});

  @override
  ConsumerState<ItemSalesPage> createState() => _ItemSalesPageState();
}

class _ItemSalesPageState extends ConsumerState<ItemSalesPage> {
  String _activeTab = 'items'; // 'items' | 'categories'

  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {'totalItemsSold': 0, 'totalRevenue': 0};

  List<dynamic> _categories = [];
  Map<String, dynamic> _categorySummary = {'totalItemsSold': 0, 'totalRevenue': 0};

  bool _loading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _branches = [];
  String _selectedBranch = '';

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = today;
    _startDate = DateTime(today.year, 1, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initData() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (user['role'] == 'owner') {
      final restaurants = user['restaurants'] ?? [];
      _branches = [
        {'_id': 'ALL', 'name': 'All Branches'},
        ...restaurants
      ];
      _selectedBranch = 'ALL';
    } else {
      _selectedBranch = user['restaurantId'] ?? '';
    }

    _fetchData();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtCurrency(dynamic val) {
    if (val == null) return '0';
    final num n = num.tryParse(val.toString()) ?? 0;
    final int rounded = n.round();
    final String s = rounded.abs().toString();
    if (s.length <= 3) {
      return (rounded < 0 ? '-' : '') + s;
    }
    final String lastThree = s.substring(s.length - 3);
    final String rest = s.substring(0, s.length - 3);
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buf.write(',');
      }
      buf.write(rest[i]);
    }
    buf.write(',');
    buf.write(lastThree);
    return (rounded < 0 ? '-' : '') + buf.toString();
  }

  String _fmtNumber(dynamic val) {
    if (val == null) return '0';
    final num n = num.tryParse(val.toString()) ?? 0;
    final int rounded = n.round();
    final String s = rounded.abs().toString();
    if (s.length <= 3) {
      return (rounded < 0 ? '-' : '') + s;
    }
    final String lastThree = s.substring(s.length - 3);
    final String rest = s.substring(0, s.length - 3);
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buf.write(',');
      }
      buf.write(rest[i]);
    }
    buf.write(',');
    buf.write(lastThree);
    return (rounded < 0 ? '-' : '') + buf.toString();
  }

  Future<void> _fetchData() async {
    if (_selectedBranch.isEmpty) return;
    if (_activeTab == 'items') {
      await _fetchItemSales();
    } else {
      await _fetchCategorySales();
    }
  }

  Future<void> _fetchItemSales() async {
    final user = ref.read(authProvider).user;
    if (user == null || _selectedBranch.isEmpty) return;

    setState(() => _loading = true);

    try {
      final s = _fmtDate(_startDate);
      final e = _fmtDate(_endDate);
      final String url = (user['role'] == 'owner' && _selectedBranch == 'ALL')
          ? '/api/analytics/org-item-sales?startDate=$s&endDate=$e'
          : '/api/analytics/item-sales?restaurantId=$_selectedBranch&startDate=$s&endDate=$e';

      final res = await apiFetch(url);
      if (res is Map && mounted) {
        setState(() {
          _items = (res['items'] as List?) ?? [];
          final summaryMap = res['summary'] as Map?;
          _summary = {
            'totalItemsSold': summaryMap?['totalItemsSold'] ?? 0,
            'totalRevenue': summaryMap?['totalRevenue'] ?? 0,
          };
        });
      }
    } catch (e) {
      debugPrint("Error fetching item sales: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCategorySales() async {
    final user = ref.read(authProvider).user;
    if (user == null || _selectedBranch.isEmpty) return;

    setState(() => _loading = true);

    try {
      final s = _fmtDate(_startDate);
      final e = _fmtDate(_endDate);
      final String url = (user['role'] == 'owner' && _selectedBranch == 'ALL')
          ? '/api/analytics/org-category-sales?startDate=$s&endDate=$e'
          : '/api/analytics/category-sales?restaurantId=$_selectedBranch&startDate=$s&endDate=$e';

      final res = await apiFetch(url);
      if (res is Map && mounted) {
        setState(() {
          _categories = (res['items'] as List?) ?? [];
          final summaryMap = res['summary'] as Map?;
          _categorySummary = {
            'totalItemsSold': summaryMap?['totalItemsSold'] ?? 0,
            'totalRevenue': summaryMap?['totalRevenue'] ?? 0,
          };
        });
      }
    } catch (e) {
      debugPrint("Error fetching category sales: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _currentData => _activeTab == 'items' ? _items : _categories;

  Map<String, dynamic> get _currentSummary =>
      _activeTab == 'items' ? _summary : _categorySummary;

  List<dynamic> get _top10 => _currentData.take(10).toList();

  List<dynamic> get _filteredData {
    if (_searchQuery.trim().isEmpty) return _currentData;
    return _currentData.where((i) {
      final name = (i['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user != null && _selectedBranch.isEmpty && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initData();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(user),
            SizedBox(height: 24.h),

            // Tab Switcher (Item Sales | Category Sales)
            _buildTabSwitcher(),
            SizedBox(height: 24.h),

            // Summary Cards (2 Cards)
            _buildSummaryCards(),
            SizedBox(height: 24.h),

            // Top 10 Selling Section
            _buildTop10Section(),
            SizedBox(height: 24.h),

            // Search & Full Transactions List
            _buildFullListSection(),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isMobile = constraints.maxWidth < 768;
          return Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment:
                isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: isMobile ? 0 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20.r,
                          ),
                        ],
                      ),
                      child: Icon(LucideIcons.package,
                          color: Colors.orange, size: 24.sp),
                    ),
                    SizedBox(width: 20.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SALES TRACKER',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8.w,
                            runSpacing: 4.h,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  (user?['role'] ?? '').toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '${_fmtDate(_startDate)} — ${_fmtDate(_endDate)}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isMobile) SizedBox(height: 16.h),
              Wrap(
                spacing: 12.w,
                runSpacing: 12.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (user?['role'] == 'owner')
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBranch.isEmpty ? null : _selectedBranch,
                          items: _branches
                              .map(
                                (b) => DropdownMenuItem<String>(
                                  value: b['_id'],
                                  child: Text(
                                    b['name'],
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedBranch = v);
                              _fetchData();
                            }
                          },
                        ),
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 14.sp, color: Colors.orange),
                        SizedBox(width: 8.w),
                        Text(
                          '${_fmtDate(_startDate)} / ${_fmtDate(_endDate)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(
                          start: _startDate,
                          end: _endDate,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                        });
                        _fetchData();
                      }
                    },
                    icon: Icon(LucideIcons.filter, size: 14.sp),
                    label: Text(
                      'APPLY',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 24.w, vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            title: 'Item Sales',
            icon: LucideIcons.package,
            isSelected: _activeTab == 'items',
            onTap: () {
              if (_activeTab != 'items') {
                setState(() {
                  _activeTab = 'items';
                  _searchQuery = '';
                  _searchController.clear();
                });
                _fetchItemSales();
              }
            },
          ),
          SizedBox(width: 8.w),
          _buildTabButton(
            title: 'Category Sales',
            icon: LucideIcons.layoutGrid,
            isSelected: _activeTab == 'categories',
            onTap: () {
              if (_activeTab != 'categories') {
                setState(() {
                  _activeTab = 'categories';
                  _searchQuery = '';
                  _searchController.clear();
                });
                _fetchCategorySales();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8.r,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            SizedBox(width: 8.w),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile
            ? (constraints.maxWidth - 12.w) / 2
            : (constraints.maxWidth - 16.w) / 2;

        return Wrap(
          spacing: 16.w,
          runSpacing: 16.h,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: _activeTab == 'items'
                    ? 'Total Items Sold'
                    : 'Total Items Sold (by Category)',
                value: _fmtNumber(_currentSummary['totalItemsSold'] ?? 0),
                valueColor: const Color(0xFF0F172A),
                icon: LucideIcons.package,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: _activeTab == 'items'
                    ? 'Item Revenue'
                    : 'Category Revenue',
                value: '₹${_fmtCurrency(_currentSummary['totalRevenue'] ?? 0)}',
                valueColor: const Color(0xFF059669),
                icon: LucideIcons.indianRupee,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: const Color(0xFFCBD5E1), size: 16.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTop10Section() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(36.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -20.r,
            right: -20.r,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                LucideIcons.trophy,
                size: 140.sp,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(28.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.trendingUp,
                        size: 16.sp, color: const Color(0xFF34D399)),
                    SizedBox(width: 8.w),
                    Text(
                      _activeTab == 'items'
                          ? 'TOP 10 SELLING ITEMS'
                          : 'TOP 10 SELLING CATEGORIES',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF34D399),
                      ),
                    ),
                  )
                else if (_top10.isNotEmpty)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final isTablet =
                          constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
                      final cardWidth = isMobile
                          ? (constraints.maxWidth - 12.w) / 2
                          : isTablet
                              ? (constraints.maxWidth - 24.w) / 3
                              : (constraints.maxWidth - 48.w) / 5;

                      return Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        children: _top10.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final upsellQty = num.tryParse(
                                  item['upsellQuantity']?.toString() ?? '0') ??
                              0;
                          final uniqueItemCount = item['uniqueItemCount'];

                          return SizedBox(
                            width: cardWidth,
                            child: Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'RANK #${index + 1}',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF34D399),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (upsellQty > 0)
                                        Tooltip(
                                          message: 'Includes upsells',
                                          child: Icon(
                                            LucideIcons.sparkles,
                                            size: 12.sp,
                                            color: const Color(0xFFFB923C),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    (item['name'] ?? '').toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_activeTab == 'categories' &&
                                      uniqueItemCount != null) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      '$uniqueItemCount unique items',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 12.h),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _fmtNumber(item['totalQuantity'] ?? 0),
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'SOLD',
                                            style: TextStyle(
                                              fontSize: 8.sp,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF64748B),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${_fmtCurrency(item['totalRevenue'] ?? 0)}',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF34D399),
                                            ),
                                          ),
                                          Text(
                                            'REVENUE',
                                            style: TextStyle(
                                              fontSize: 8.sp,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF64748B),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.h),
                    child: Center(
                      child: Text(
                        'No sales data for this period',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildFullListSection() {
    final filtered = _filteredData;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search bar
          Padding(
            padding: EdgeInsets.all(24.r),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isMobile = constraints.maxWidth < 650;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isMobile
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeTab == 'items' ? 'ALL ITEMS' : 'ALL CATEGORIES',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${filtered.length} of ${_currentData.length} shown',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    if (isMobile) SizedBox(height: 16.h),
                    SizedBox(
                      width: isMobile ? double.infinity : 280.w,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: _activeTab == 'items'
                              ? 'Search item name...'
                              : 'Search category name...',
                          hintStyle: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 16.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                SizedBox(
                  width: 50.w,
                  child: Text(
                    'RANK',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _activeTab == 'items' ? 'ITEM NAME' : 'CATEGORY NAME',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'QTY SOLD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'ORDERS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (_activeTab == 'categories')
                  Expanded(
                    flex: 1,
                    child: Text(
                      'UNIQUE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REVENUE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Content List
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40.h),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No items matching "$_searchQuery"'
                      : 'No sales data for this period',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey.shade50),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final originalRank =
                    _currentData.indexWhere((i) => i['name'] == item['name']) +
                        1;
                final upsellQty = num.tryParse(
                        item['upsellQuantity']?.toString() ?? '0') ??
                    0;
                final isTop3 = originalRank <= 3;

                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24.w, vertical: 14.h),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50.w,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: isTop3
                                  ? const Color(0xFFFFF7ED)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              '#$originalRank',
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w900,
                                color: isTop3
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item['name'] ?? '').toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (upsellQty > 0) ...[
                              SizedBox(height: 2.h),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.sparkles,
                                    size: 9.sp,
                                    color: const Color(0xFFEA580C),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '$upsellQty via upsell',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          _fmtNumber(item['totalQuantity'] ?? 0),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          _fmtNumber(item['ordersCount'] ?? 0),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (_activeTab == 'categories')
                        Expanded(
                          flex: 1,
                          child: Text(
                            _fmtNumber(item['uniqueItemCount'] ?? 0),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${_fmtCurrency(item['totalRevenue'] ?? 0)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
