import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfitDashboardPage extends ConsumerStatefulWidget {
  const ProfitDashboardPage({super.key});
  @override
  ConsumerState<ProfitDashboardPage> createState() => _ProfitDashboardPageState();
}

class _ProfitDashboardPageState extends ConsumerState<ProfitDashboardPage> {
  Map<String, dynamic>? _data;
  List<dynamic> _expenses = [];
  Map<String, dynamic>? _gstData;
  List<dynamic> _branches = [];
  String _selectedBranch = '';
  bool _isLoading = false;
  int _touchedIndex = -1;

  bool _isGstEnabled = false;
  num _selectedGstRate = 5;

  late DateTime _startDate;
  late DateTime _endDate;

  final _formTitleController = TextEditingController();
  final _formAmountController = TextEditingController();
  String _formCategory = 'RENT';
  late DateTime _formDate;

  final List<String> _categories = [
    "RENT", "SALARY", "RAW_MATERIAL", "ELECTRICITY", "WATER", "GAS",
    "INTERNET", "STAFF_BENEFITS", "MAINTENANCE", "REPAIRS", "EQUIPMENT",
    "MARKETING", "ADVERTISING", "DISCOUNTS_GIVEN", "PAYMENT_FEES",
    "DELIVERY", "PACKAGING", "TAXES", "LICENSES", "OTHER"
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = today;
    _startDate = DateTime(2026, 1, 1);
    _formDate = today;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _initData() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (user['role'] == 'owner') {
      final restaurants = user['restaurants'] ?? [];
      _branches = [ {'_id': 'ALL', 'name': 'All Branches'}, ...restaurants ];
      _selectedBranch = 'ALL';
    } else {
      _selectedBranch = user['restaurantId'] ?? '';
    }
    _isGstEnabled = user['gstEnabled'] == true;
    _selectedGstRate = user['gstRate'] ?? 5;

    _fetchAllData();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _fetchAllData() async {
    final user = ref.read(authProvider).user;
    if (user == null || _selectedBranch.isEmpty) return;

    final isLimited = user['role'] != 'owner' && user['permissionLevel'] == 'LIMITED';
    setState(() => _isLoading = true);
    
    try {
      await _fetchExpenses();
      if (!isLimited) {
        await _fetchProfit();
        await _fetchGSTReport();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final url = (user['role'] == 'owner' && _selectedBranch == 'ALL')
        ? '/api/expenses/org-profit?from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}'
        : '/api/expenses/profit?from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}&branchId=$_selectedBranch';
    try {
      final res = await apiFetch(url);
      if (mounted) setState(() => _data = {'totalSales': res['totalSales'] ?? 0, 'totalExpenses': res['totalExpenses'] ?? 0, 'netProfit': res['profit'] ?? 0});
    } catch (e) {
      debugPrint("Profit err $e");
    }
  }

  Future<void> _fetchExpenses() async {
    final url = '/api/expenses/?branchId=$_selectedBranch&from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}';
    try {
      final res = await apiFetch(url);
      if (mounted && res is List) {
        setState(() => _expenses = res.reversed.toList());
      }
    } catch (e) {
      debugPrint("Expenses err $e");
    }
  }

  Future<void> _fetchGSTReport() async {
    final url = '/api/analytics/gst-report?from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}&restaurantId=$_selectedBranch';
    try {
      final res = await apiFetch(url);
      if (mounted) setState(() => _gstData = res);
    } catch (e) {
      debugPrint("GST err $e");
    }
  }

  Future<void> _handleAddExpense() async {
    if (_selectedBranch == 'ALL') {
      _showBranchSelectionPopup();
      return;
    }
    if (_formAmountController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await apiFetch('/api/expenses', method: 'POST', data: {
        'title': _formCategory == 'OTHER' ? _formTitleController.text : '',
        'category': _formCategory,
        'amount': num.parse(_formAmountController.text),
        'expenseDate': _fmtDate(_formDate),
        'restaurant': _selectedBranch
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
         _formTitleController.clear();
         _formAmountController.clear();
      }
      _fetchAllData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteExpense(String id) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Expense?', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: TextStyle(fontSize: 12.sp, color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('DELETE', style: TextStyle(color: Colors.red, fontSize: 12.sp, fontWeight: FontWeight.bold))),
        ],
      )
    );
    if (act != true) return;
    
    setState(() => _isLoading = true);
    try {
      await apiFetch('/api/expenses/$id', method: 'DELETE');
      _fetchAllData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enableGST(num rate) async {
    try {
      final res = await apiFetch('/api/organization/gstTwo', method: 'PUT', data: {
        'gstEnabled': true,
        'gstRate': rate
      });
      setState(() {
         _isGstEnabled = res['gstEnabled'] == true;
         _selectedGstRate = res['gstRate'] ?? 5;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GST enabled at $rate%')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to enable GST: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Reactive: If user just loaded, initialize data
    if (user != null && _selectedBranch.isEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initData();
      });
    }

    final isLimited = user?['role'] != 'owner' && user?['permissionLevel'] == 'LIMITED';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading && _data == null && _expenses.isEmpty
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D00)))
        : SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100)),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isMobile = constraints.maxWidth < 750;
                      return Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: isMobile ? 0 : 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24.r), boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20.r)]),
                                  child: Icon(LucideIcons.layoutDashboard, color: Colors.orange, size: 24.sp),
                                ),
                                SizedBox(width: 20.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isLimited ? 'EXPENSE TRACKER' : 'FINANCE ANALYTICS', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                                      SizedBox(height: 8.h),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8.w, runSpacing: 4.h,
                                        children: [
                                          Container(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4.r)), child: Text((user?['role'] ?? '').toString().toUpperCase(), style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w900, color: Colors.white))),
                                          Text('${_fmtDate(_startDate)} — ${_fmtDate(_endDate)}', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          if (isMobile) SizedBox(height: 16.h),
                          Wrap(
                        spacing: 12.w, runSpacing: 12.h, crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (user?['role'] == 'owner')
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey.shade100)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBranch.isEmpty ? null : _selectedBranch,
                                  items: _branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)))).toList(),
                                  onChanged: (v) { if (v != null) { setState(() => _selectedBranch = v); _fetchAllData(); } },
                                ),
                              ),
                            ),
                          // Date display (simpler than full picker for space)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey.shade100)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.calendar, size: 14.sp, color: Colors.orange),
                                SizedBox(width: 8.w),
                                Text('${_fmtDate(_startDate)} / ${_fmtDate(_endDate)}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
                              if (picked != null) {
                                setState(() { _startDate = picked.start; _endDate = picked.end; });
                                _fetchAllData();
                              }
                            },
                            icon: Icon(LucideIcons.filter, size: 14.sp),
                            label: Text('APPLY DATES', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))
                            ),
                          )
                        ],
                      )
                    ],
                  );
                },
              ),
            ),
                SizedBox(height: 32.h),

                // Main Content
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    return Flex(
                      direction: isDesktop ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isDesktop ? 2 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isLimited && _data != null) ...[
                                // KPI Cards
                                LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final cardWidth = constraints.maxWidth < 600 ? constraints.maxWidth : (constraints.maxWidth - 32.w) / 3;
                                    return Wrap(
                                      spacing: 16.w, runSpacing: 16.h,
                                      children: [
                                        SizedBox(width: cardWidth, child: _buildKpiCard('Gross Sales', '₹${_data!['totalSales']}', const Color(0xFF0F172A), LucideIcons.indianRupee)),
                                        SizedBox(width: cardWidth, child: _buildKpiCard('Expenses', '₹${_data!['totalExpenses']}', Colors.red, null)),
                                        SizedBox(width: cardWidth, child: _buildKpiCard('Net Profit', '₹${_data!['netProfit']}', _data!['netProfit'] >= 0 ? Colors.green : Colors.red, null)),
                                      ],
                                    );
                                  }
                                ),
                                SizedBox(height: 24.h),

                                // GST Box
                                if (_isGstEnabled && _gstData != null)
                                  Container(
                                    padding: EdgeInsets.all(32.r),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          runSpacing: 12.h,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8.r)), child: Icon(LucideIcons.receipt, color: Colors.green, size: 20.sp)),
                                                SizedBox(width: 12.w),
                                                Text('GST BREAKDOWN (${_selectedGstRate}%)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                              ],
                                            ),
                                            Container(padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16.r)), child: Text('TAX COMPLIANT', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w900))),
                                          ],
                                        ),
                                        SizedBox(height: 24.h),
                                        LayoutBuilder(
                                          builder: (ctx, constraints) {
                                            final isMobile = constraints.maxWidth < 600;
                                            final itemWidth = isMobile ? (constraints.maxWidth - 16.w) / 2 : (constraints.maxWidth - 48.w) / 4;
                                            return Wrap(
                                              spacing: 16.w, runSpacing: 16.h,
                                              children: [
                                                SizedBox(width: itemWidth, child: _buildGstItem('Taxable', '₹${num.parse(_gstData!['totalSales']?.toString() ?? '0').toStringAsFixed(0)}', Colors.grey.shade50, Colors.black)),
                                                SizedBox(width: itemWidth, child: _buildGstItem('CGST', '₹${(num.parse(_gstData!['totalGST']?.toString() ?? '0') / 2).toStringAsFixed(2)}', Colors.grey.shade50, Colors.green)),
                                                SizedBox(width: itemWidth, child: _buildGstItem('SGST', '₹${(num.parse(_gstData!['totalGST']?.toString() ?? '0') / 2).toStringAsFixed(2)}', Colors.grey.shade50, Colors.green)),
                                                SizedBox(width: itemWidth, child: _buildGstItem('Total GST', '₹${num.parse(_gstData!['totalGST']?.toString() ?? '0').toStringAsFixed(0)}', Colors.orange, Colors.white, titleColor: Colors.orange.shade100)),
                                              ],
                                            );
                                          }
                                        )
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 24.h),

                                // Margin Analysis
                                Container(
                                  padding: EdgeInsets.all(32.r),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100)),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    runSpacing: 24.h, spacing: 24.w,
                                    children: [
                                       SizedBox(
                                         width: 300.w,
                                         child: Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             Text('MARGIN ANALYSIS', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                             SizedBox(height: 8.h),
                                             Text('Visual comparison of revenue vs. operational costs for the selected period.', style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
                                             SizedBox(height: 16.h),
                                             Row(
                                               children: [
                                                 Container(width: 12.r, height: 12.r, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                                 SizedBox(width: 8.w),
                                                 Text('PROFIT', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900)),
                                                 SizedBox(width: 24.w),
                                                 Container(width: 12.r, height: 12.r, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                                 SizedBox(width: 8.w),
                                                 Text('EXPENSES', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900)),
                                               ],
                                             )
                                           ],
                                         )
                                       ),
                                       // Pie Chart
                                       SizedBox(
                                         width: 200.w, height: 200.w,
                                         child: _buildPieChart(),
                                       )
                                    ],
                                  ),
                                ),
                                SizedBox(height: 24.h),
                              ],

                              // Transactions Table
                              Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100)),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(32.r),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('TRANSACTION HISTORY', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1.w)),
                                          Text('${_expenses.length} Records Found', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Divider(height: 1, color: Colors.grey.shade100),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _expenses.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade50),
                                      itemBuilder: (ctx, idx) {
                                        final exp = _expenses[idx];
                                        return Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text((exp['title']?.toString().isNotEmpty == true ? exp['title'] : exp['category']).toString().toUpperCase(), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                                    Text(exp['category'].toString().replaceAll('_', ' '), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(_fmtDate(DateTime.tryParse(exp['expenseDate']?.toString() ?? '') ?? DateTime.now()), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey)),
                                              ),
                                              Expanded(
                                                child: Text('-₹${exp['amount']}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.red), textAlign: TextAlign.right),
                                              ),
                                              IconButton(
                                                onPressed: () => _handleDeleteExpense(exp['_id']),
                                                icon: Icon(LucideIcons.trash2, color: Colors.red, size: 16.sp),
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        if (isDesktop) SizedBox(width: 32.w),
                        // Sidebar
                        Expanded(
                          flex: isDesktop ? 1 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isDesktop) ...[
                                if (!_isGstEnabled)
                                  Container(
                                    padding: EdgeInsets.all(24.r),
                                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(32.r)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(LucideIcons.shieldCheck, color: Colors.orange, size: 16.sp),
                                                SizedBox(width: 8.w),
                                                Text('GST STATUS', style: TextStyle(color: Colors.orange, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1.w)),
                                              ],
                                            ),
                                            Icon(LucideIcons.toggleLeft, color: Colors.grey, size: 24.sp),
                                          ],
                                        ),
                                        SizedBox(height: 16.h),
                                        Text('GST tracking is disabled. Tap below to enable.', style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 16.h),
                                        Row(
                                          children: [
                                            Expanded(child: ElevatedButton(onPressed: () => _enableGST(5), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: Text('Enable 5%', style: TextStyle(color: Colors.white, fontSize: 12.sp)))),
                                            SizedBox(width: 8.w),
                                            Expanded(child: ElevatedButton(onPressed: () => _enableGST(18), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: Text('Enable 18%', style: TextStyle(color: Colors.white, fontSize: 12.sp)))),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 24.h),
                              ],

                              // Add Expense Form
                              Container(
                                padding: EdgeInsets.all(32.r),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20.r)]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12.r)), child: Icon(LucideIcons.plusCircle, color: Colors.white, size: 20.sp)),
                                        SizedBox(width: 12.w),
                                        Text('ADD EXPENSE', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5.w)),
                                      ],
                                    ),
                                    SizedBox(height: 24.h),
                                    Text('CATEGORY', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.w)),
                                    SizedBox(height: 8.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.transparent)),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _formCategory,
                                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)))).toList(),
                                          onChanged: (v) { if (v != null) setState(() { _formCategory = v; _formTitleController.clear(); }); },
                                        )
                                      ),
                                    ),
                                    if (_formCategory == 'OTHER') ...[
                                      SizedBox(height: 16.h),
                                      TextField(
                                        controller: _formTitleController,
                                        decoration: InputDecoration(hintText: 'Specify Title', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.r), borderSide: BorderSide.none)),
                                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                                      )
                                    ],
                                    SizedBox(height: 16.h),
                                    Text('AMOUNT (₹)', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.w)),
                                    SizedBox(height: 8.h),
                                    TextField(
                                      controller: _formAmountController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(LucideIcons.indianRupee, size: 18.sp),
                                        hintText: '0',
                                        filled: true, fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.r), borderSide: BorderSide.none)
                                      ),
                                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text('DATE', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.w)),
                                    SizedBox(height: 8.h),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(context: context, initialDate: _formDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                                        if (d != null) setState(() => _formDate = d);
                                      },
                                      child: Container(
                                        width: double.infinity, padding: EdgeInsets.all(16.r),
                                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20.r)),
                                        child: Text(_fmtDate(_formDate), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(height: 24.h),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _handleAddExpense,
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 20.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r))),
                                        child: Text(_isLoading ? 'SAVING...' : 'SAVE TRANSACTION', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1.w)),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    );
                  }
                )
              ],
            ),
          ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color valueColor, IconData? icon) {
    return Container(
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40.r), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2.w)),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: valueColor, letterSpacing: -1.w)),
              if (icon != null)
                Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8.r)), child: Icon(icon, color: Colors.grey.shade300, size: 20.sp))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGstItem(String title, String amount, Color bgColor, Color textColor, {Color? titleColor}) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w900, color: titleColor ?? Colors.grey)),
          SizedBox(height: 4.h),
          Text(amount, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final expensesVal = num.parse(_data!['totalExpenses']?.toString() ?? '0').toDouble();
    final profitVal = num.parse(_data!['netProfit']?.toString() ?? '0').toDouble();
    final validProfit = profitVal > 0 ? profitVal : 0.0;
    
    if (expensesVal == 0 && validProfit == 0) {
      return const Center(child: Text('No Data', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sectionsSpace: 4,
        centerSpaceRadius: 60,
        sections: [
          PieChartSectionData(
            color: Colors.green, // emerald
            value: validProfit,
            title: '₹${validProfit.toInt()}',
            radius: _touchedIndex == 0 ? 30.r : 20.r,
            titleStyle: TextStyle(fontSize: _touchedIndex == 0 ? 12.sp : 9.sp, fontWeight: FontWeight.bold, color: _touchedIndex == 0 ? Colors.green.shade900 : Colors.transparent),
          ),
          PieChartSectionData(
            color: Colors.red,
            value: expensesVal,
            title: '₹${expensesVal.toInt()}',
            radius: _touchedIndex == 1 ? 30.r : 20.r,
            titleStyle: TextStyle(fontSize: _touchedIndex == 1 ? 12.sp : 9.sp, fontWeight: FontWeight.bold, color: _touchedIndex == 1 ? Colors.red.shade900 : Colors.transparent),
          ),
        ]
      ),
      swapAnimationDuration: const Duration(milliseconds: 150),
    );
  }

  void _showBranchSelectionPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          child: Container(
            padding: EdgeInsets.all(24.r),
            constraints: BoxConstraints(maxWidth: 400.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16.r)),
                      child: Icon(LucideIcons.store, color: Colors.orange, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Text('Select Branch', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  ],
                ),
                SizedBox(height: 8.h),
                Text('Please choose a specific branch to add the expense.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                SizedBox(height: 24.h),
                ..._branches.where((b) => b['_id'] != 'ALL').map((b) => 
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0.h),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() { _selectedBranch = b['_id']; });
                        _fetchAllData();
                        _handleAddExpense(); // Retry with updated branch
                      },
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b['name'], style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), fontSize: 14.sp)),
                            Icon(LucideIcons.chevronRight, size: 16.sp, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  )
                ).toList(),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1.w, fontSize: 12.sp)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }
}
