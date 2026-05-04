import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  bool _loadingBranches = true;
  List<dynamic> _branches = [];
  String _selectedBranch = '';

  Map<String, dynamic>? _summary;
  List<dynamic> _graphData = [];

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = today;
    _startDate = today.subtract(const Duration(days: 6));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBranches();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await apiFetch('/api/restaurants/list-for-analytics');
      if (mounted) {
        setState(() {
          _branches = res['branches'] ?? [];
          if (res['mode'] == 'single' && _branches.length == 1) {
            _selectedBranch = _branches[0]['_id'];
          }
          _loadingBranches = false;
        });
        _fetchAnalytics();
      }
    } catch (e) {
      debugPrint("Error fetching branches: $e");
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _fetchAnalytics() async {
    if (_selectedBranch.isEmpty) return;

    final sDate = _formatDate(_startDate);
    final eDate = _formatDate(_endDate);

    try {
      final summaryUrl = _selectedBranch == 'ALL'
          ? '/api/analytics/org-summary?startDate=$sDate&endDate=$eDate'
          : '/api/analytics/summary?restaurantId=$_selectedBranch&startDate=$sDate&endDate=$eDate';

      final summaryRes = await apiFetch(summaryUrl);

      final graphUrl = _selectedBranch == 'ALL'
          ? '/api/analytics/org-revenue-graph?startDate=$sDate&endDate=$eDate'
          : '/api/analytics/revenue-graph?restaurantId=$_selectedBranch&startDate=$sDate&endDate=$eDate';

      final graphRes = await apiFetch(graphUrl);

      if (mounted) {
        setState(() {
          _summary = summaryRes is Map
              ? Map<String, dynamic>.from(summaryRes)
              : null;
          _graphData = graphRes is List ? graphRes : [];
        });
      }
    } catch (e) {
      debugPrint("Analytics error: $e");
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _fetchAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final gstEnabled = user?['gstEnabled'] == true;
    final isFoodTruck =
        user?['businessType'] == 'FOOD_TRUCK' ||
        user?['type'] == 'foodtruck' ||
        user?['data']?['businessType'] == 'FOOD_TRUCK' ||
        user?['data']?['type'] == 'foodtruck';

    // Reactive: If user just loaded, initialize data
    if (user != null && _branches.isEmpty && _loadingBranches) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchBranches();
      });
    }

    if (_loadingBranches && _branches.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFCF6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D00)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isMobile = constraints.maxWidth < 700.w;
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
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                            children: const [
                              TextSpan(text: 'Scan '),
                              TextSpan(
                                text: 'Serve',
                                style: TextStyle(color: Color(0xFFEA580C)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'PERFORMANCE INSIGHTS & REVENUE DYNAMICS',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    if (isMobile) SizedBox(height: 16.h),
                    Wrap(
                      spacing: 12.w,
                      runSpacing: 12.h,
                      children: [
                        // Branch Selector
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch.isEmpty
                                  ? null
                                  : _selectedBranch,
                              hint: Text(
                                'Select Branch...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                              icon: Icon(
                                LucideIcons.chevronDown,
                                size: 16.sp,
                                color: Colors.grey,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text(
                                    'All Branches',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                                ..._branches.map(
                                  (b) => DropdownMenuItem(
                                    value: b['_id'],
                                    child: Text(
                                      b['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBranch = val);
                                  _fetchAnalytics();
                                }
                              },
                            ),
                          ),
                        ),
                        // Date Picker
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _selectDate(context, true),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'START DATE',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_startDate),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Container(
                                width: 1.w,
                                height: 24.h,
                                color: Colors.grey.shade200,
                              ),
                              SizedBox(width: 16.w),
                              InkWell(
                                onTap: () => _selectDate(context, false),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'END DATE',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_endDate),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E293B),
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
                  ],
                );
              },
            ),
            SizedBox(height: 32.h),

            if (_selectedBranch.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 60.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48.r),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.barChart3,
                        size: 48.sp,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'WAITING FOR BRANCH SELECTION',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              )
            else if (_summary == null)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(60.r),
                  child: const CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else ...[
              // Stat Cards
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final crossAxisCount = constraints.maxWidth < 600.w
                      ? 1
                      : constraints.maxWidth < 1000.w
                      ? 2
                      : 4;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16.r,
                    crossAxisSpacing: 16.r,
                    childAspectRatio: 2.5,
                    children: [
                      _buildStatCard(
                        'Total Orders',
                        '${(_summary?['totalOrders'] ?? 0)}',
                        LucideIcons.package,
                        false,
                      ),
                      _buildStatCard(
                        'Net Revenue',
                        '₹${num.parse(_summary?['netRevenue']?.toString() ?? '0').toStringAsFixed(0)}',
                        LucideIcons.trendingUp,
                        false,
                      ),
                      if (gstEnabled)
                        _buildStatCard(
                          'GST Collected',
                          '₹${num.parse(_summary?['gstCollected']?.toString() ?? '0').toStringAsFixed(2)}',
                          LucideIcons.indianRupee,
                          false,
                        ),
                      _buildStatCard(
                        'Upsell Revenue',
                        '₹${num.parse(_summary?['upsellRevenue']?.toString() ?? '0').toStringAsFixed(0)}',
                        LucideIcons.sparkles,
                        true,
                      ),
                    ],
                  );
                },
              ),
              if (isFoodTruck) ...[
                SizedBox(height: 24.h),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: min(400.w, constraints.maxWidth),
                      ),
                      child: _buildPaymentBreakdown(
                        _summary?['paymentBreakdown'],
                      ),
                    );
                  },
                ),
              ],
              SizedBox(height: 24.h),

              // Simple Chart Placeholder for Revenue
              Container(
                padding: EdgeInsets.all(32.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40.r),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 16.h,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REVENUE DYNAMICS',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'SALES VS UPSELL TRENDS',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12.w,
                              height: 12.h,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'SALES',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Container(
                              width: 12.w,
                              height: 12.h,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'UPSELL',
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
                    SizedBox(height: 40.h),
                    // Live Graph
                    SizedBox(
                      height: 300.h,
                      width: double.infinity,
                      child: _buildChart(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    bool primary,
  ) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        border: primary ? null : Border.all(color: Colors.grey.shade100),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
              ]
            : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10.r)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: primary ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: primary ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: primary ? const Color(0xFFFF5C00) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              icon,
              color: primary ? Colors.white : const Color(0xFFFF5C00),
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(Map<String, dynamic>? data) {
    final cash = num.parse(data?['CASH']?.toString() ?? '0');
    final upi = num.parse(data?['UPI']?.toString() ?? '0');
    final card = num.parse(data?['CARD']?.toString() ?? '0');
    final total = cash + upi + card > 0 ? cash + upi + card : 1;

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAYMENT DYNAMICS',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  LucideIcons.trendingUp,
                  size: 14.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildPaymentRow('Cash', cash, total, Colors.green),
          SizedBox(height: 16.h),
          _buildPaymentRow('UPI', upi, total, const Color(0xFFFF5C00)),
          SizedBox(height: 16.h),
          _buildPaymentRow('Card', card, total, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, num value, num total, Color color) {
    final percentage = (value / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          height: 6.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4.r),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percentage.toDouble(),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_graphData.isEmpty) {
      return const Center(
        child: Text(
          'No data for this range',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
    }

    final List<FlSpot> salesSpots = [];
    final List<FlSpot> upsellSpots = [];
    double maxX = _graphData.length.toDouble() - 1;
    double maxY = 0;

    for (int i = 0; i < _graphData.length; i++) {
      final data = _graphData[i];
      if (data is! Map) continue;
      final sales = double.tryParse(data['sales']?.toString() ?? '0') ?? 0;
      final upsell = double.tryParse(data['upsell']?.toString() ?? '0') ?? 0;
      if (sales > maxY) maxY = sales;
      if (upsell > maxY) maxY = upsell;
      salesSpots.add(FlSpot(i.toDouble(), sales));
      upsellSpots.add(FlSpot(i.toDouble(), upsell));
    }

    maxY = maxY > 0 ? maxY * 1.2 : 100;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < _graphData.length) {
                    final strDate = _graphData[idx]['date']?.toString() ?? '';
                    String label = strDate;
                    if (strDate.length >= 10) {
                      final parts = strDate.substring(0, 10).split('-');
                      if (parts.length == 3) {
                        label = '${parts[2]}/${parts[1]}';
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: salesSpots,
              isCurved: true,
              color: const Color(0xFFFF4D00),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF4D00).withAlpha(50),
                    const Color(0xFFFF4D00).withAlpha(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            LineChartBarData(
              spots: upsellSpots,
              isCurved: true,
              color: const Color(0xFF10B981),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withAlpha(50),
                    const Color(0xFF10B981).withAlpha(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
