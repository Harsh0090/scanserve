import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';
import 'package:fl_chart/fl_chart.dart';

class UpsellPage extends ConsumerStatefulWidget {
  const UpsellPage({super.key});
  @override
  ConsumerState<UpsellPage> createState() => _UpsellPageState();
}

class _UpsellPageState extends ConsumerState<UpsellPage> {
  bool _isLoading = false;
  List<dynamic> _menuItems = [];
  List<dynamic> _rules = [];

  List<dynamic> _branches = [];
  String _selectedBranch = 'ALL';
  late DateTime _startDate;
  late DateTime _endDate;
  List<dynamic> _graphData = [];

  String _triggerItem = '';
  String _suggestedItem = '';
  final _titleController = TextEditingController();

  bool _editMode = false;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = today;
    _startDate = DateTime(2026, 1, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _getUpsellBase(Map<String, dynamic> user) {
    return user['role'] == 'owner'
        ? '/api/upsell/global'
        : '/api/upsell/branch';
  }

  String _getMenuBase(Map<String, dynamic> user) {
    return user['role'] == 'owner' ? '/api/global-menu' : '/api/branch-menu';
  }

  Future<void> _loadData() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    if (user['role'] == 'owner') {
      final restaurants = user['restaurants'] ?? [];
      _branches = [
        {'_id': 'ALL', 'name': 'All Branches'},
        ...restaurants,
      ];
      _selectedBranch = 'ALL';
    } else {
      _selectedBranch = user['restaurantId'] ?? '';
    }

    setState(() => _isLoading = true);
    await Future.wait([_fetchMenu(user), _fetchRules(user), _fetchGraphData()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchGraphData() async {
    final user = ref.read(authProvider).user;
    if (user == null || _selectedBranch.isEmpty) return;
    final url = (user['role'] == 'owner' && _selectedBranch == 'ALL')
        ? '/api/analytics/org-revenue-graph?from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}'
        : '/api/analytics/revenue-graph?from=${_fmtDate(_startDate)}&to=${_fmtDate(_endDate)}&restaurantId=$_selectedBranch';
    try {
      final res = await apiFetch(url);
      if (mounted && res is List) {
        setState(() => _graphData = res);
      }
    } catch (e) {
      debugPrint("Graph err: $e");
    }
  }

  Future<void> _fetchMenu(Map<String, dynamic> user) async {
    try {
      final res = await apiFetch('${_getMenuBase(user)}/items');
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _menuItems = (res['data'] as List)
                .map(
                  (i) => {
                    '_id': i['_id'],
                    'name': i['name'] ?? i['globalItem']?['name'] ?? 'Unknown',
                  },
                )
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Menu fetch error: $e");
    }
  }

  Future<void> _fetchRules(Map<String, dynamic> user) async {
    try {
      final res = await apiFetch(_getUpsellBase(user));
      if (res is List) {
        if (mounted) {
          setState(() {
            _rules = res
                .map(
                  (r) => {
                    '_id': r['_id'],
                    'title': r['title'],
                    'triggerItem': r['globalTriggerItem'] ?? r['triggerItem'],
                    'suggestedItem':
                        r['globalSuggestedItem'] ?? r['suggestedItem'],
                  },
                )
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Rules fetch error: $e");
    }
  }

  void _resetForm() {
    setState(() {
      _triggerItem = '';
      _suggestedItem = '';
      _titleController.clear();
      _editMode = false;
      _editingId = null;
    });
  }

  Future<void> _createOrUpdateRule() async {
    if (_triggerItem.isEmpty || _suggestedItem.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select both dishes')));
      return;
    }

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final method = _editMode ? 'PATCH' : 'POST';
      final url = _editMode
          ? '${_getUpsellBase(user)}/$_editingId'
          : _getUpsellBase(user);

      final res = await apiFetch(
        url,
        method: method,
        data: {
          'triggerItemId': _triggerItem,
          'suggestedItemId': _suggestedItem,
          'title': _titleController.text.isNotEmpty
              ? _titleController.text
              : 'Would you like to add this?',
        },
      );

      if (res['organization'] != null || res['_id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editMode ? 'Pairing updated' : 'Strategy deployed'),
          ),
        );
        _resetForm();
        await _fetchRules(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Operation failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRule(String id) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently remove this pairing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (act != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await apiFetch('/api/upsell/$id', method: 'DELETE');
      if (res['message'] == 'Upsell rule deleted') {
        setState(() {
          _rules.removeWhere((r) => r['_id'] == id);
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Rule removed')));
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Delete failed')),
          );
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isOwner = user?['role'] == 'owner';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading && _menuItems.isEmpty && _rules.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C00),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade100,
                              blurRadius: 10.r,
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.sparkles,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'REVENUE STRATEGY',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                      children: [
                        TextSpan(text: 'UPSELL '),
                        TextSpan(
                          text: 'LOGIC',
                          style: TextStyle(color: Color(0xFFFF5C00)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Design automated pairings to boost your average order value.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Analytics Controls & Graph
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isOwner)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch.isEmpty
                                  ? null
                                  : _selectedBranch,
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
                                  _fetchGraphData();
                                }
                              },
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 14.sp,
                              color: Colors.orange,
                            ),
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
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = picked.start;
                              _endDate = picked.end;
                            });
                            _fetchGraphData();
                          }
                        },
                        icon: const Icon(LucideIcons.filter, size: 14),
                        label: const Text(
                          'APPLY DATES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 16.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                  (_graphData.isEmpty)
                      ? SizedBox.shrink()
                      : const SizedBox(height: 24),
                  (_graphData.isEmpty)
                      ? SizedBox.shrink()
                      : Container(
                          height: 300.h,
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40.r),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SALES VS UPSELL TRENDS',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              Expanded(child: _buildGraph()),
                            ],
                          ),
                        ),
                  SizedBox(height: 32.h),

                  // Creation Zone
                  if (isOwner)
                    Container(
                      padding: EdgeInsets.all(32.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40.r),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 20.r,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _editMode
                                    ? 'MODIFY PAIRING'
                                    : 'CREATE NEW PAIRING',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFF5C00),
                                  letterSpacing: 1,
                                ),
                              ),
                              if (_editMode)
                                TextButton.icon(
                                  onPressed: _resetForm,
                                  icon: Icon(
                                    LucideIcons.refreshCcw,
                                    size: 14.sp,
                                    color: Colors.grey,
                                  ),
                                  label: Text(
                                    'RESET FORM',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final isMobile = constraints.maxWidth < 600.w;
                              return Flex(
                                direction: isMobile
                                    ? Axis.vertical
                                    : Axis.horizontal,
                                children: [
                                  Expanded(
                                    flex: isMobile ? 0 : 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'IF A CUSTOMER BUYS...',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              hint: Text(
                                                'Select Primary Item',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              value: _triggerItem.isEmpty
                                                  ? null
                                                  : _triggerItem,
                                              items: _menuItems
                                                  .map(
                                                    (i) =>
                                                        DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: i['_id'],
                                                          child: Text(
                                                            i['name'],
                                                            style: TextStyle(
                                                              fontSize: 14.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) {
                                                if (v != null)
                                                  setState(
                                                    () => _triggerItem = v,
                                                  );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isMobile)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24.w,
                                        vertical: 16.h,
                                      ),
                                      child: Icon(
                                        LucideIcons.arrowRight,
                                        color: Colors.grey,
                                        size: 24.sp,
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 16),
                                  Expanded(
                                    flex: isMobile ? 0 : 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'OFFER THEM THIS...',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              hint: const Text(
                                                'Select Suggestion',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              value: _suggestedItem.isEmpty
                                                  ? null
                                                  : _suggestedItem,
                                              items: _menuItems
                                                  .map(
                                                    (i) =>
                                                        DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: i['_id'],
                                                          child: Text(
                                                            i['name'],
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) {
                                                if (v != null)
                                                  setState(
                                                    () => _suggestedItem = v,
                                                  );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMobile)
                                    const SizedBox(height: 24)
                                  else
                                    const SizedBox(width: 24),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _createOrUpdateRule,
                                    icon: Icon(
                                      _editMode
                                          ? LucideIcons.checkCircle
                                          : LucideIcons.plusCircle,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _editMode ? 'UPDATE' : 'DEPLOY',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32.w,
                                        vertical: 20.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.r),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 32.h),
                          const Divider(height: 1, color: Colors.black12),
                          SizedBox(height: 24.h),
                          Text(
                            'PITCH MESSAGE',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText:
                                  "e.g. 'Complete your meal with our special bun maska!'",
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFFFF5C00),
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 48.h),

                  // Current Pairings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURRENT PAIRINGS',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'ACTIVE RULES',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '${_rules.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  if (_rules.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(64.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40.r),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.sparkles,
                              color: Colors.grey,
                              size: 40.sp,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No automated rules currently live.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isMobile = constraints.maxWidth < 600.w;
                        final cardWidth = isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16.w) / 2;
                        return Wrap(
                          spacing: 16.w,
                          runSpacing: 16.h,
                          children: _rules.map((rule) {
                            return SizedBox(
                              width: cardWidth,
                              child: Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32.r),
                                  border: Border.all(
                                    color: Colors.grey.shade100,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(5),
                                      blurRadius: 10.r,
                                      offset: Offset(0, 4.h),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'ID: ${(rule['_id'] as String).substring((rule['_id'] as String).length - 6).toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        if (isOwner)
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  LucideIcons.edit,
                                                  size: 16.sp,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _editMode = true;
                                                    _editingId = rule['_id'];
                                                    _triggerItem =
                                                        rule['triggerItem']?['_id'] ??
                                                        '';
                                                    _suggestedItem =
                                                        rule['suggestedItem']?['_id'] ??
                                                        '';
                                                    _titleController.text =
                                                        rule['title'] ?? '';
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  LucideIcons.trash2,
                                                  size: 16.sp,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () =>
                                                    _deleteRule(rule['_id']),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(12.r),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'IF BUY',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  rule['triggerItem']?['name'] ??
                                                      'Unknown',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                          ),
                                          child: Icon(
                                            LucideIcons.arrowRight,
                                            size: 16.sp,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(12.r),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'SUGGEST',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                                Text(
                                                  rule['suggestedItem']?['name'] ??
                                                      'Unknown',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8.w,
                                          height: 8.w,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            '"${rule['title']}"',
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildGraph() {
    if (_graphData.isEmpty)
      return const Center(
        child: Text(
          "No Data",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );

    final List<FlSpot> upsellSpots = [];
    double maxY = 0;

    for (int i = 0; i < _graphData.length; i++) {
      final data = _graphData[i];
      final upsell = double.tryParse(data['upsell']?.toString() ?? '0') ?? 0;
      if (upsell > maxY) maxY = upsell;
      upsellSpots.add(FlSpot(i.toDouble(), upsell));
    }

    if (maxY == 0)
      return const Center(
        child: Text(
          "No Upsell Data for selected period",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (val, _) {
                if (val.toInt() >= 0 && val.toInt() < _graphData.length) {
                  final d = _graphData[val.toInt()]['date']?.toString() ?? '';
                  final parts = d.split('-');
                  if (parts.length >= 3)
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${parts[2]}/${parts[1]}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: upsellSpots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [Colors.orange.withAlpha(50), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
