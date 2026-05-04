import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/apiClient.dart';
import '../context/AuthContext.dart';
import 'widgets/stat_card.dart';
import 'widgets/payment_breakdown.dart';
import 'widgets/expense_summary.dart';
import 'widgets/revenue_chart.dart';

class LoggedInHomePage extends ConsumerStatefulWidget {
  const LoggedInHomePage({super.key});
  @override
  ConsumerState<LoggedInHomePage> createState() => _LoggedInHomePageState();
}

class _LoggedInHomePageState extends ConsumerState<LoggedInHomePage> {
  String _filter = 'week';
  String _customFrom = '';
  String _customTo = '';
  Map<String, dynamic>? _summary;
  List<dynamic> _graphData = [];
  Map<String, dynamic>? _expenseData;
  bool _loading = false;
  bool _loggingOut = false;

  String? get _restaurantId {
    final u = ref.read(authProvider).user;
    return u?['data']?['restaurants']?[0]?['_id'] ?? u?['restaurants']?[0]?['_id'] ?? u?['restaurantId'];
  }

  String get _restaurantName {
    final u = ref.read(authProvider).user;
    return u?['data']?['restaurants']?[0]?['name'] ?? u?['restaurants']?[0]?['name'] ?? 'Restaurant';
  }

  bool get _isFoodTruck {
    final u = ref.read(authProvider).user;
    final bt = u?['data']?['restaurants']?[0]?['businessType'] ?? u?['businessType'] ?? '';
    return bt == 'food_truck';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 6));
    _customTo = _fmtDate(now);
    _customFrom = _fmtDate(past);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, String> _getDateRange() {
    final today = _fmtDate(DateTime.now());
    if (_filter == 'today') return {'startDate': today, 'endDate': today};
    if (_filter == 'custom') return {'startDate': _customFrom, 'endDate': _customTo};
    final past = DateTime.now().subtract(const Duration(days: 6));
    return {'startDate': _fmtDate(past), 'endDate': today};
  }

  Future<void> _fetchData() async {
    final rid = _restaurantId;
    if (rid == null) return;
    if (_filter == 'custom' && (_customFrom.isEmpty || _customTo.isEmpty)) return;
    setState(() => _loading = true);
    final range = _getDateRange();
    final s = range['startDate']!;
    final e = range['endDate']!;

    try {
      final results = await Future.wait([
        apiFetch('/api/analytics/summary?restaurantId=$rid&startDate=$s&endDate=$e'),
        apiFetch('/api/analytics/revenue-graph?restaurantId=$rid&startDate=$s&endDate=$e'),
        apiFetch('/api/expenses/org-profit?from=$s&to=$e').catchError((_) => null),
      ]);
      if (!mounted) return;
      _summary = results[0];
      _graphData = results[1] is List ? results[1] : [];
      final exp = results[2];
      if (exp != null && exp is Map<String, dynamic>) {
        _expenseData = {
          'total': exp['totalExpenses'] ?? exp['expenses'] ?? exp['total'] ?? 0,
          'breakdown': exp['breakdown'] ?? exp['expenseByCategory'] ?? [],
        };
      } else {
        _expenseData = null;
      }
    } catch (err) {
      debugPrint('FETCH_ERROR: $err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully'), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final netRevenue = (_summary?['netRevenue'] ?? 0).toDouble();
    final totalExpense = (_expenseData?['total'] ?? 0).toDouble();
    final netProfit = netRevenue - totalExpense;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(children: [
        _buildTopBar(context, user),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('WELCOME BACK',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 3)),
                    const SizedBox(height: 4),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '$_restaurantName ',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1)),
                      const TextSpan(text: 'Overview',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00), letterSpacing: -1)),
                    ])),
                    const SizedBox(height: 20),
                    _buildKpiCards(netRevenue, netProfit),
                    const SizedBox(height: 16),
                    _buildChartRow(netRevenue),
                    const SizedBox(height: 16),
                    ExpenseSummary(expense: _expenseData, revenue: netRevenue),
                  ]),
                ),
        ),
      ]),
    );
  }

  Widget _buildTopBar(BuildContext context, Map<String, dynamic>? user) {
    return Container(
      color: Colors.white.withOpacity(0.9),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, bottom: 8),
      child: Column(children: [
        Row(children: [
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _navPill('Dashboard', LucideIcons.layoutGrid, '/dashboard/orders', dark: true),
            const SizedBox(width: 8),
            _navPill('Live Menu', LucideIcons.globe, '/${user?['restaurantId'] ?? ''}'),
            const SizedBox(width: 8),
            _navPill('Analytics', LucideIcons.barChart2, '/dashboard/analytics'),
          ]))),
          const SizedBox(width: 8),
          _logoutBtn(),
        ]),
        const SizedBox(height: 8),
        _buildFilterRow(),
      ]),
    );
  }

  Widget _navPill(String label, IconData icon, String href, {bool dark = false}) {
    return GestureDetector(
      onTap: () => context.push(href),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: dark ? null : Border.all(color: Colors.transparent),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: dark ? const Color(0xFFFF5C00) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5,
            color: dark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(width: 4),
          Icon(LucideIcons.externalLink, size: 9, color: dark ? Colors.white38 : const Color(0xFFCBD5E1)),
        ]),
      ),
    );
  }

  Widget _logoutBtn() {
    return GestureDetector(
      onTap: _loggingOut ? null : _handleLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(children: [
          Icon(LucideIcons.logOut, size: 14, color: Colors.red.shade500),
          const SizedBox(width: 6),
          Text(_loggingOut ? '...' : 'LOGOUT', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.red.shade500)),
        ]),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(children: [
          _filterBtn('Today', 'today'),
          _filterBtn('Week', 'week'),
          _filterBtn('Custom', 'custom'),
        ]),
      ),
      if (_filter == 'custom') ...[
        const SizedBox(width: 8),
        Expanded(child: _customDateRow()),
      ],
    ]);
  }

  Widget _filterBtn(String label, String key) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = key);
        if (key != 'custom') _fetchData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)] : null,
        ),
        child: Text(label.toUpperCase(), style: TextStyle(
          fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5,
          color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _customDateRow() {
    return Row(children: [
      const Icon(LucideIcons.calendarDays, size: 14, color: Color(0xFFFF5C00)),
      const SizedBox(width: 4),
      Expanded(child: GestureDetector(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(_customFrom) ?? DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime.now());
          if (d != null) setState(() => _customFrom = _fmtDate(d));
        },
        child: Text(_customFrom, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      )),
      const Text(' \u2192 ', style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w900)),
      Expanded(child: GestureDetector(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(_customTo) ?? DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime.now());
          if (d != null) setState(() => _customTo = _fmtDate(d));
        },
        child: Text(_customTo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      )),
      GestureDetector(
        onTap: _fetchData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(10)),
          child: const Text('APPLY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
        ),
      ),
    ]);
  }

  Widget _buildKpiCards(double netRevenue, double netProfit) {
    final filterLabel = _filter == 'today' ? 'Today' : _filter == 'week' ? 'Last 7 days' : '$_customFrom \u2013 $_customTo';
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
      children: [
        StatCard(title: 'Total Orders', value: '${_summary?['totalOrders'] ?? '\u2014'}',
          icon: LucideIcons.package, sub: filterLabel),
        StatCard(title: 'Gross Revenue', value: '\u20B9${_fmtNum(netRevenue)}',
          icon: LucideIcons.trendingUp, sub: 'Net of all sales', trend: 'up'),
        StatCard(title: 'Net Profit', value: '\u20B9${_fmtNum(netProfit.abs())}',
          icon: LucideIcons.indianRupee, sub: netProfit >= 0 ? 'After expenses' : 'Loss this period',
          trend: netProfit >= 0 ? 'up' : 'down'),
        StatCard(title: 'Upsell Revenue', value: '\u20B9${_fmtNum((_summary?['upsellRevenue'] ?? 0).toDouble())}',
          icon: LucideIcons.sparkles, sub: 'Auto-suggested adds', trend: 'up', primary: true),
      ],
    );
  }

  Widget _buildChartRow(double netRevenue) {
    final totalExpense = (_expenseData?['total'] ?? 0).toDouble();
    return LayoutBuilder(builder: (ctx, constraints) {
      if (constraints.maxWidth > 700) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: RevenueChart(graphData: _graphData)),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: _sidePanel(netRevenue, totalExpense)),
        ]);
      }
      return Column(children: [
        RevenueChart(graphData: _graphData),
        const SizedBox(height: 12),
        _sidePanel(netRevenue, totalExpense),
      ]);
    });
  }

  Widget _sidePanel(double netRevenue, double totalExpense) {
    if (_isFoodTruck && _summary?['paymentBreakdown'] != null) {
      return PaymentBreakdown(data: _summary!['paymentBreakdown']);
    }
    final avgOrder = (_summary?['totalOrders'] != null && _summary!['totalOrders'] > 0)
        ? (netRevenue / _summary!['totalOrders']).round() : 0;
    final upsellRate = netRevenue > 0
        ? ((_summary?['upsellRevenue'] ?? 0).toDouble() / netRevenue * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('QUICK STATS',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('Period Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _quickStat('Avg Order Value', '\u20B9${_fmtNum(avgOrder.toDouble())}'),
        _quickStat('Upsell Rate', '$upsellRate%'),
        _quickStat('Total Expenses', '\u20B9${_fmtNum(totalExpense)}'),
      ]),
    );
  }

  Widget _quickStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
      ]),
    );
  }

  String _fmtNum(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
