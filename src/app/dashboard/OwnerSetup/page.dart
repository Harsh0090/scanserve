import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../../../utils/apiClient.dart';
import '../../components/MenuModal.dart';
import '../../context/AuthContext.dart';
import '../../../services/kot_print_service.dart';

class OwnerSetupPage extends ConsumerStatefulWidget {
  const OwnerSetupPage({super.key});
  @override
  ConsumerState<OwnerSetupPage> createState() => _OwnerSetupPageState();
}

class _OwnerSetupPageState extends ConsumerState<OwnerSetupPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, List<dynamic>> _areas = {};
  List<String> _areaOrder = [];
  bool _isLoading = false;
  Map<String, dynamic>? _selectedTable;

  // Live order maps and bill states
  Map<String, dynamic> _orderByTable = {};
  bool _isBillLoading = false;
  Map<String, dynamic>? _billPreview;
  String? _selectedPaymentMethod;
  bool _isFinalizingBill = false;

  // Shift table states
  Map<String, dynamic>? _shiftData;
  String _newTableNumInput = "";
  bool _showMergeConfirm = false;

  // Discount states
  String _discountType = 'NONE'; // 'NONE', 'PERCENTAGE', 'FIXED'
  String _discountValue = '';

  @override
  void initState() {
    super.initState();
    _fetchTables();
    _fetchAreaOrder();
  }

  Future<void> _fetchTables() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/pos/tables?t=${DateTime.now().millisecondsSinceEpoch}');
      if (data is List) {
        final Map<String, List<dynamic>> grouped = {};
        for (var table in data) {
          final area = (table['areaName'] ?? 'Unassigned').toString().trim();
          grouped.putIfAbsent(area, () => []).add(table);
        }
        grouped.forEach((key, list) {
          list.sort((a, b) {
            final aName = a['tableName'].toString();
            final bName = b['tableName'].toString();
            final aNum = int.tryParse(aName);
            final bNum = int.tryParse(bName);
            if (aNum != null && bNum != null) {
              return aNum.compareTo(bNum);
            }
            return aName.compareTo(bName);
          });
        });
        if (mounted) {
          setState(() {
            _areas = grouped;
          });
        }
      }
      await _fetchLiveOrders();
    } catch (e) {
      debugPrint("Failed to fetch tables: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLiveOrders() async {
    try {
      final data = await apiFetch('/api/admin/orders/live?t=${DateTime.now().millisecondsSinceEpoch}');
      if (data is List) {
        final Map<String, dynamic> map = {};
        for (var order in data) {
          if (order['tableNumber'] != null) {
            map[order['tableNumber'].toString()] = order;
          }
        }
        if (mounted) {
          setState(() {
            _orderByTable = map;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch live orders: $e");
    }
  }

  Future<void> _fetchAreaOrder() async {
    try {
      final data = await apiFetch('/api/pos/area-order');
      if (data is List) {
        final List<String> list = [];
        for (var item in data) {
          if (item is Map && item['areaName'] != null) {
            list.add(item['areaName'].toString());
          } else if (item is String) {
            list.add(item);
          }
        }
        if (mounted) {
          setState(() {
            _areaOrder = list;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch area order: $e");
    }
  }

  List<String> _getSortedAreaNames() {
    final allAreas = _areas.keys.toList();
    final ordered = _areaOrder.where((name) => allAreas.contains(name)).toList();
    final unordered = allAreas.where((name) => !_areaOrder.contains(name)).toList();
    return [...ordered, ...unordered];
  }

  Future<void> _moveArea(String areaName, String direction) async {
    final current = _getSortedAreaNames();
    final idx = current.indexOf(areaName);
    if (idx == -1) return;
    final swapIdx = direction == 'up' ? idx - 1 : idx + 1;
    if (swapIdx < 0 || swapIdx >= current.length) return;

    final newOrder = List<String>.from(current);
    final temp = newOrder[idx];
    newOrder[idx] = newOrder[swapIdx];
    newOrder[swapIdx] = temp;

    setState(() {
      _areaOrder = newOrder;
    });

    try {
      await apiFetch(
        '/api/pos/area-order',
        method: 'POST',
        data: {'orderedAreaNames': newOrder},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save area order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _fetchAreaOrder();
    }
  }

  String _formatCardLabel(Map<String, dynamic> table) {
    final area = (table['areaName'] ?? '').toString().trim();
    final name = (table['displayLabel'] ?? table['tableName'] ?? '').toString().trim();
    if (name.isEmpty) return area;
    if (area.isEmpty) return name;
    if (name.toLowerCase().startsWith(area.toLowerCase())) {
      return name;
    }
    return '$area $name';
  }

  Widget _buildReorderArrows(String areaName, int index, int totalCount) {
    final canMoveUp = index > 0;
    final canMoveDown = index < totalCount - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: canMoveUp ? () => _moveArea(areaName, 'up') : null,
          borderRadius: BorderRadius.circular(4.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Text(
              '▲',
              style: TextStyle(
                fontSize: 10.sp,
                height: 1.0,
                fontWeight: FontWeight.bold,
                color: canMoveUp ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
        SizedBox(height: 1.h),
        InkWell(
          onTap: canMoveDown ? () => _moveArea(areaName, 'down') : null,
          borderRadius: BorderRadius.circular(4.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Text(
              '▼',
              style: TextStyle(
                fontSize: 10.sp,
                height: 1.0,
                fontWeight: FontWeight.bold,
                color: canMoveDown ? const Color(0xFF64748B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getTableTotal(Map<String, dynamic> table) {
    final order = _orderByTable[table['tableName'].toString()];
    if (order == null || order['items'] == null) return 0.0;
    final items = order['items'] as List;
    double sum = 0.0;
    for (var i in items) {
      final itemObj = i['item'] as Map?;
      final price = (itemObj?['branchPrice'] ?? i['basePrice'] ?? 0.0) as num;
      final qty = (i['quantity'] ?? 0) as num;
      sum += price.toDouble() * qty.toDouble();
    }
    return sum;
  }

  int? _getMinutesAgo(Map<String, dynamic> table) {
    final order = _orderByTable[table['tableName'].toString()];
    if (order == null || order['createdAt'] == null) return null;
    try {
      final createdAt = DateTime.parse(order['createdAt'].toString());
      final diff = DateTime.now().difference(createdAt).inMinutes;
      return math.max(0, diff);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleDeleteTable(String tableId) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delete', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this table?', style: TextStyle(fontSize: 14.sp)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: TextStyle(fontSize: 12.sp, color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('DELETE', style: TextStyle(color: Colors.red, fontSize: 12.sp, fontWeight: FontWeight.bold))),
        ],
      )
    );
    if (act != true) return;
    try {
      await apiFetch('/api/pos/tables/$tableId', method: 'DELETE');
      _fetchTables();
    } catch (e) {
      debugPrint("Delete failed $e");
    }
  }

  void _showShiftModal(Map<String, dynamic> table) {
    final currentTableNum = table['tableName']?.toString() ?? '';
    final currentArea = (table['areaName'] ?? '').toString();
    final currentLabel = (table['displayLabel'] ?? table['tableName']).toString();

    setState(() {
      _shiftData = {
        'orderId': table['currentOrderId'],
        'currentTable': table['tableName'],
        'currentAreaName': currentArea,
      };
      _newTableNumInput = "";
      _showMergeConfirm = false;
    });

    final List<DropdownMenuItem<String>> dropdownItems = [];
    _areas.forEach((areaName, tableList) {
      for (var t in tableList) {
        if (t['tableName']?.toString() == currentTableNum) continue;
        final id = (t['_id'] ?? t['tableName']).toString();
        final disp = (t['displayLabel'] ?? t['tableName']).toString();
        final isRunning = t['status'] == 'Running';
        dropdownItems.add(
          DropdownMenuItem<String>(
            value: id,
            child: Text(
              '$areaName $disp${isRunning ? " (Occupied)" : ""}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: isRunning ? const Color(0xFFFF5C00) : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
            contentPadding: EdgeInsets.all(24.r),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_showMergeConfirm) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shift Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: const Color(0xFF0F172A))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(LucideIcons.x, size: 20.sp, color: Colors.grey),
                      )
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text('Moving order from $currentArea $currentLabel to:', style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600)),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: _newTableNumInput.isEmpty ? null : _newTableNumInput,
                    hint: Text('Select table...', style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
                    isExpanded: true,
                    items: dropdownItems,
                    onChanged: (v) {
                      setDialogState(() {
                        _newTableNumInput = v ?? '';
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFB),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12.r)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2), borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      onPressed: _newTableNumInput.isEmpty ? null : () => _handleShiftConfirm(ctx, setDialogState, false),
                      child: Text('CONFIRM SHIFT', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56.r,
                          height: 56.r,
                          decoration: const BoxDecoration(color: Color(0xFFFFFBEB), shape: BoxShape.circle),
                          child: Icon(LucideIcons.moveHorizontal, size: 28.sp, color: const Color(0xFFF59E0B)),
                        ),
                        SizedBox(height: 16.h),
                        Text('Table Already Occupied!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: const Color(0xFF0F172A))),
                        SizedBox(height: 8.h),
                        Text(
                          'Selected table is currently running.\nDo you want to merge Table ${_shiftData?['currentTable']} into it?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(16.r)),
                    child: Column(
                      children: [
                        _buildMergeBullet('All items from the current table will move to the target table'),
                        SizedBox(height: 8.h),
                        _buildMergeBullet('Bills will be combined into one'),
                        SizedBox(height: 8.h),
                        _buildMergeBullet('Current table will become vacant'),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          onPressed: () => _handleShiftConfirm(ctx, setDialogState, true),
                          child: Text('Yes, Merge!', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildMergeBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Container(width: 6.r, height: 6.r, decoration: const BoxDecoration(color: Color(0xFFFF5C00), shape: BoxShape.circle)),
        ),
        SizedBox(width: 8.w),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
      ],
    );
  }

  Future<void> _handleShiftConfirm(BuildContext dialogContext, StateSetter setDialogState, bool mergeConfirmed) async {
    if (_newTableNumInput.isEmpty) return;
    try {
      final response = await dioClient.patch(
        '/api/admin/orders/${_shiftData?['orderId']}/shift',
        data: {
          'newTableId': _newTableNumInput,
          'newTableNumber': _newTableNumInput,
          'mergeConfirmed': mergeConfirmed,
        },
      );
      
      final data = response.data;
      Navigator.pop(dialogContext);
      _fetchTables();
      if (mounted) {
        final isMerged = data is Map && data['merged'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMerged ? 'Tables merged successfully!' : 'Table shifted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data is Map && e.response?.data['requiresMerge'] == true) {
        setDialogState(() {
          _showMergeConfirm = true;
        });
      } else {
        String msg = 'Shift failed';
        final responseData = e.response?.data;
        if (responseData is Map && responseData['message'] != null) {
          msg = responseData['message'].toString();
        } else if (e.message != null) {
          msg = e.message!;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getActiveOrderForTable(Map<String, dynamic> table) async {
    final tableName = table['tableName']?.toString() ?? '';
    var order = _orderByTable[tableName];

    final orderId = table['currentOrderId']?.toString() ?? order?['_id']?.toString();
    if (order == null && orderId != null && orderId.isNotEmpty) {
      try {
        final res = await apiFetch('/api/admin/orders/$orderId');
        if (res is Map && res['order'] != null) {
          order = Map<String, dynamic>.from(res['order']);
        } else if (res is Map) {
          order = Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint("Error fetching order by ID: $e");
      }
    }

    if (order is Map<String, dynamic>) {
      return order;
    } else if (order is Map) {
      return Map<String, dynamic>.from(order);
    }
    return null;
  }

  // TRIGGER 5: Reprint Full KOT from Table Card
  Future<void> _reprintFullKOT(Map<String, dynamic> table) async {
    try {
      final order = await _getActiveOrderForTable(table);
      if (order == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active order found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final items = (order['items'] is List) ? List<dynamic>.from(order['items']) : <dynamic>[];
      final user = ref.read(authProvider).user;
      final restName = user?['restaurants']?[0]?['name'] ?? user?['data']?['restaurants']?[0]?['name'] ?? user?['name'];
      final tableNum = table['tableName']?.toString() ?? order['tableNumber']?.toString();
      final custName = order['customerName']?.toString();

      final kotService = ref.read(kotPrintServiceProvider);
      await kotService.printKOT(
        orderId: order['_id'].toString(),
        items: items,
        isAddOn: false,
        tableNumber: tableNum,
        customerName: custName,
        restaurantName: restName?.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full KOT sent to printer ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reprint failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // TRIGGER 6: Reprint New Items Only from Table Card
  Future<void> _reprintNewItemsKOT(Map<String, dynamic> table) async {
    try {
      final order = await _getActiveOrderForTable(table);
      if (order == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active order found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final lastAddedIds = (order['lastAddedItems'] is List)
          ? List<dynamic>.from(order['lastAddedItems']).map((e) => e.toString()).toSet()
          : <String>{};

      final allItems = (order['items'] is List) ? List<dynamic>.from(order['items']) : <dynamic>[];

      final newItems = allItems.where((item) {
        if (item is! Map) return false;
        final rawItem = item['item'];
        final itemId = (rawItem is Map) ? rawItem['_id']?.toString() : rawItem?.toString();
        return itemId != null && lastAddedIds.contains(itemId);
      }).toList();

      if (newItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No recently added items found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final user = ref.read(authProvider).user;
      final restName = user?['restaurants']?[0]?['name'] ?? user?['data']?['restaurants']?[0]?['name'] ?? user?['name'];
      final tableNum = table['tableName']?.toString() ?? order['tableNumber']?.toString();
      final custName = order['customerName']?.toString();

      final kotService = ref.read(kotPrintServiceProvider);
      await kotService.printKOT(
        orderId: order['_id'].toString(),
        items: newItems,
        isAddOn: true,
        tableNumber: tableNum,
        customerName: custName,
        restaurantName: restName?.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New items KOT sent to printer ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reprint failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReprintKOTOptions(Map<String, dynamic> table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        LucideIcons.zap,
                        color: const Color(0xFFD97706),
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reprint KOT — Table ${table['tableName']}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Select print ticket mode',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                // Option 1: Full KOT
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(LucideIcons.printer, size: 20.sp, color: const Color(0xFF334155)),
                  ),
                  title: Text(
                    'Full KOT',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'All items',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                  ),
                  trailing: Icon(LucideIcons.chevronRight, size: 18.sp, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reprintFullKOT(table);
                  },
                ),
                SizedBox(height: 12.h),
                // Option 2: New Items Only
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5ED),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(LucideIcons.sparkles, size: 20.sp, color: const Color(0xFFFF5C00)),
                  ),
                  title: Text(
                    'New Items Only',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Recently added',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                  ),
                  trailing: Icon(LucideIcons.chevronRight, size: 18.sp, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reprintNewItemsKOT(table);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleShowBillPreview(Map<String, dynamic> table) async {
    final orderId = table['currentOrderId'];
    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active order found'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() {
      _isBillLoading = true;
    });

    try {
      final data = await apiFetch('/api/admin/orders/$orderId/bill-preview', method: 'GET');
      if (data != null && data['bill'] != null) {
        setState(() {
          _selectedPaymentMethod = null;
          _discountType = 'NONE';
          _discountValue = '';
          _billPreview = {
            'bill': data['bill'],
            'table': table,
          };
        });
        _showBillPreviewDialog();
      } else {
        throw Exception('Invalid bill preview response');
      }
    } catch (e) {
      debugPrint("BILL FETCH ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bill: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBillLoading = false;
        });
      }
    }
  }

  void _showBillPreviewDialog() {
    final TextEditingController discountController = TextEditingController(text: _discountValue);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bill = _billPreview?['bill'] as Map<String, dynamic>;
          final tableObj = _billPreview?['table'] as Map<String, dynamic>;
          final items = (bill['items'] as List?) ?? [];
          final subTotal = (bill['subTotal'] ?? 0.0) as num;
          final gstRate = (bill['gstRate'] ?? 0.0) as num;
          final gstAmount = (bill['gstAmount'] ?? 0.0) as num;

          final discInfo = _getDiscountedBill();
          final discountAmount = discInfo['discountAmount'] as double;
          final finalAmount = discInfo['finalAmount'] as double;
          
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.r)),
            contentPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            content: Container(
              width: 380.w,
              constraints: BoxConstraints(maxHeight: 0.85.sh),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header (fixed)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(color: const Color(0xFFFFF5ED), borderRadius: BorderRadius.circular(16.r)),
                              child: Icon(LucideIcons.receipt, color: const Color(0xFFFF5C00), size: 22.sp),
                            ),
                            SizedBox(width: 14.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Table ${bill['tableNumber'] ?? tableObj['tableName']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: const Color(0xFF0F172A))),
                                SizedBox(height: 4.h),
                                Text('BILL SUMMARY', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.w)),
                              ],
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                            child: Icon(LucideIcons.x, size: 18.sp, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Item List
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Column(
                              children: items.map((item) {
                                final qty = (item['quantity'] ?? 0) as num;
                                final price = (item['basePrice'] ?? 0.0) as num;
                                final name = (item['name'] ?? '').toString();
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8.r)),
                                              child: Text('${qty}x', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade700)),
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Text(name, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Text('₹${(price * qty).toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          
                          // Subtotals, GST, Total
                          Container(
                            color: const Color(0xFFF8FAFB),
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                                    Text('₹${subTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('GST (${gstRate}%)', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                                    Text('₹${gstAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                  ],
                                ),
                                if (discountAmount > 0) ...[
                                  SizedBox(height: 8.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _discountType == 'PERCENTAGE' 
                                          ? 'Discount (${_discountValue}%)' 
                                          : 'Discount (Fixed)', 
                                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.green)
                                      ),
                                      Text('- ₹${discountAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                ],
                                SizedBox(height: 12.h),
                                Divider(color: Colors.grey.shade200, height: 1),
                                SizedBox(height: 12.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('TOTAL', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                    Text('₹${finalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF5C00))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Apply Discount Section
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('APPLY DISCOUNT', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5.w)),
                                SizedBox(height: 12.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: _discountType == 'PERCENTAGE' ? const Color(0xFFFFF5ED) : Colors.white,
                                          side: BorderSide(
                                            color: _discountType == 'PERCENTAGE' ? const Color(0xFFFF5C00) : Colors.grey.shade200,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                          padding: EdgeInsets.symmetric(vertical: 14.h),
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            if (_discountType == 'PERCENTAGE') {
                                              _discountType = 'NONE';
                                              _discountValue = '';
                                              discountController.clear();
                                            } else {
                                              _discountType = 'PERCENTAGE';
                                              _discountValue = '';
                                              discountController.clear();
                                            }
                                          });
                                        },
                                        child: Text(
                                          'PERCENTAGE (%)',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w900,
                                            color: _discountType == 'PERCENTAGE' ? const Color(0xFFFF5C00) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: _discountType == 'FIXED' ? const Color(0xFFFFF5ED) : Colors.white,
                                          side: BorderSide(
                                            color: _discountType == 'FIXED' ? const Color(0xFFFF5C00) : Colors.grey.shade200,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                          padding: EdgeInsets.symmetric(vertical: 14.h),
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            if (_discountType == 'FIXED') {
                                              _discountType = 'NONE';
                                              _discountValue = '';
                                              discountController.clear();
                                            } else {
                                              _discountType = 'FIXED';
                                              _discountValue = '';
                                              discountController.clear();
                                            }
                                          });
                                        },
                                        child: Text(
                                          'FIXED (₹)',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w900,
                                            color: _discountType == 'FIXED' ? const Color(0xFFFF5C00) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_discountType != 'NONE') ...[
                                  SizedBox(height: 12.h),
                                  TextField(
                                    controller: discountController,
                                    onChanged: (v) {
                                      setDialogState(() {
                                        _discountValue = v;
                                      });
                                    },
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      prefixText: _discountType == 'PERCENTAGE' ? '% ' : '₹ ',
                                      prefixStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.grey),
                                      hintText: _discountType == 'PERCENTAGE' ? 'Enter percentage...' : 'Enter amount...',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFB),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12.r)),
                                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2), borderRadius: BorderRadius.circular(12.r)),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          
                          // Payment Method Section
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SELECT PAYMENT METHOD', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5.w)),
                                SizedBox(height: 12.h),
                                Row(
                                  children: [
                                    Expanded(child: _buildPaymentMethodBtn('CASH', setDialogState)),
                                    SizedBox(width: 8.w),
                                    Expanded(child: _buildPaymentMethodBtn('UPI', setDialogState)),
                                    SizedBox(width: 8.w),
                                    Expanded(child: _buildPaymentMethodBtn('CARD', setDialogState)),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFFEF3C7), width: 1.5),
                                          backgroundColor: const Color(0xFFFEF3C7).withOpacity(0.2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                          padding: EdgeInsets.symmetric(vertical: 14.h),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showPayLaterDialog(context, finalAmount);
                                        },
                                        child: Text(
                                          'PAY LATER',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFE0E7FF), width: 1.5),
                                          backgroundColor: const Color(0xFFEEF2FF).withOpacity(0.2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                                          padding: EdgeInsets.symmetric(vertical: 14.h),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showSplitPaymentDialog(context, finalAmount);
                                        },
                                        child: Text(
                                          '✂ SPLIT',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Action Buttons
                          Padding(
                            padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 24.h),
                            child: Builder(
                              builder: (context) {
                                final user = ref.read(authProvider).user;
                                final userData = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});
                                final bool autoPrintBill = userData['autoPrintBill'] == true;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade200),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                          padding: EdgeInsets.symmetric(vertical: 16.h),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                        },
                                        child: Text('Close', style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      flex: autoPrintBill ? 1 : 2,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: autoPrintBill ? Colors.grey.shade100 : const Color(0xFFFF5C00),
                                          foregroundColor: autoPrintBill ? Colors.grey.shade800 : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                          padding: EdgeInsets.symmetric(vertical: 16.h),
                                          disabledBackgroundColor: Colors.grey.shade300,
                                          elevation: autoPrintBill ? 0 : 2,
                                        ),
                                        onPressed: (_selectedPaymentMethod == null || _isFinalizingBill) 
                                            ? null 
                                            : () => _finalizeBillWithPayment(ctx, setDialogState, shouldPrint: false),
                                        icon: _isFinalizingBill 
                                            ? const SizedBox.shrink()
                                            : Icon(LucideIcons.receipt, size: 16.sp, color: autoPrintBill ? Colors.grey.shade700 : Colors.white),
                                        label: _isFinalizingBill 
                                            ? SizedBox(width: 18.r, height: 18.r, child: CircularProgressIndicator(color: autoPrintBill ? Colors.grey : Colors.white, strokeWidth: 2))
                                            : Text('Mark Paid', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                    if (autoPrintBill) ...[
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFF5C00),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                            padding: EdgeInsets.symmetric(vertical: 16.h),
                                            disabledBackgroundColor: Colors.grey.shade300,
                                            elevation: 2,
                                          ),
                                          onPressed: (_selectedPaymentMethod == null || _isFinalizingBill) 
                                              ? null 
                                              : () => _finalizeBillWithPayment(ctx, setDialogState, shouldPrint: true),
                                          icon: _isFinalizingBill 
                                              ? const SizedBox.shrink()
                                              : Icon(LucideIcons.printer, size: 16.sp, color: Colors.white),
                                          label: _isFinalizingBill 
                                              ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : Text('Print Bill', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildPaymentMethodBtn(String method, StateSetter setDialogState) {
    final isSelected = _selectedPaymentMethod == method;
    
    Color activeBg;
    Color activeBorder;
    Color activeText;
    Color idleBg;
    Color idleBorder;
    Color idleText;
    
    if (method == 'CASH') {
      activeBg = const Color(0xFF10B981);
      activeBorder = const Color(0xFF10B981);
      activeText = Colors.white;
      idleBg = const Color(0xFFECFDF5);
      idleBorder = const Color(0xFFA7F3D0);
      idleText = const Color(0xFF047857);
    } else if (method == 'UPI') {
      activeBg = const Color(0xFF3B82F6);
      activeBorder = const Color(0xFF3B82F6);
      activeText = Colors.white;
      idleBg = const Color(0xFFEFF6FF);
      idleBorder = const Color(0xFFBFDBFE);
      idleText = const Color(0xFF1D4ED8);
    } else {
      activeBg = const Color(0xFF8B5CF6);
      activeBorder = const Color(0xFF8B5CF6);
      activeText = Colors.white;
      idleBg = const Color(0xFFF5F3FF);
      idleBorder = const Color(0xFFDDD6FE);
      idleText = const Color(0xFF6D28D9);
    }
    
    return InkWell(
      onTap: () {
        setDialogState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : idleBg,
          border: Border.all(color: isSelected ? activeBorder : idleBorder, width: 1.5),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          method,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            color: isSelected ? activeText : idleText,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getDiscountedBill() {
    final bill = _billPreview?['bill'] as Map<String, dynamic>?;
    final total = (bill?['total'] ?? 0.0) as num;
    final value = double.tryParse(_discountValue) ?? 0.0;

    if (_discountType == 'NONE' || value <= 0) {
      return {'discountAmount': 0.0, 'finalAmount': total.toDouble(), 'error': null};
    }

    if (_discountType == 'PERCENTAGE') {
      if (value > 100) {
        return {'discountAmount': 0.0, 'finalAmount': total.toDouble(), 'error': 'Cannot exceed 100%'};
      }
      final amount = (total * value) / 100.0;
      return {'discountAmount': amount, 'finalAmount': total.toDouble() - amount, 'error': null};
    }

    if (_discountType == 'FIXED') {
      if (value > total) {
        return {'discountAmount': 0.0, 'finalAmount': total.toDouble(), 'error': 'Cannot exceed bill amount'};
      }
      return {'discountAmount': value, 'finalAmount': total.toDouble() - value, 'error': null};
    }

    return {'discountAmount': 0.0, 'finalAmount': total.toDouble(), 'error': null};
  }

  Future<void> _finalizeBillWithPayment(BuildContext dialogContext, StateSetter setDialogState, {bool shouldPrint = true}) async {
    final orderId = _billPreview?['table']?['currentOrderId'];
    if (orderId == null) return;
    if (_selectedPaymentMethod == null) return;

    final discInfo = _getDiscountedBill();
    if (discInfo['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(discInfo['error'].toString()), backgroundColor: Colors.red),
      );
      return;
    }
    
    setDialogState(() {
      _isFinalizingBill = true;
    });

    try {
      await apiFetch(
        '/api/admin/orders/collect-payment',
        method: 'PATCH',
        data: {
          'orderId': orderId,
          'paymentMethod': _selectedPaymentMethod,
          'discountType': _discountType,
          'discountValue': double.tryParse(_discountValue) ?? 0.0,
        },
      );
      
      if (shouldPrint) {
        await apiFetch(
          '/api/admin/orders/$orderId/print-bill',
          method: 'PATCH',
        );
      }
      
      Navigator.pop(dialogContext);
      _fetchTables();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldPrint
                  ? 'Served & paid via $_selectedPaymentMethod'
                  : 'Marked paid via $_selectedPaymentMethod · Table cleared',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {
        _selectedPaymentMethod = null;
        _discountType = 'NONE';
        _discountValue = '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setDialogState(() {
        _isFinalizingBill = false;
      });
    }
  }

  void _showPayLaterDialog(BuildContext parentCtx, double finalAmount) {
    final orderId = _billPreview?['table']?['currentOrderId'];
    if (orderId == null) return;

    final TextEditingController nameController = TextEditingController();
    final TextEditingController paidNowController = TextEditingController();
    
    bool partialMode = false;
    bool isSaving = false;

    showDialog(
      context: parentCtx,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final customerName = nameController.text.trim();
          final paidNowVal = double.tryParse(paidNowController.text) ?? 0.0;
          final remaining = math.max(0.0, finalAmount - paidNowVal);

          final isValid = customerName.isNotEmpty && 
              (!partialMode || (paidNowController.text.isNotEmpty && paidNowVal > 0 && paidNowVal < finalAmount));

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.r)),
            contentPadding: EdgeInsets.all(24.r),
            content: Container(
              width: 360.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16.r)),
                          child: Icon(LucideIcons.alertTriangle, color: const Color(0xFFD97706), size: 20.sp),
                        ),
                        SizedBox(width: 12.w),
                        Text('PAY LATER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text('Enter customer name to track this order', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5.w)),
                    SizedBox(height: 16.h),
    
                    // Customer name TextField
                    TextField(
                      controller: nameController,
                      onChanged: (v) => setDialogState(() {}),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Customer name...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFB),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2), borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                    SizedBox(height: 12.h),
    
                    // Partial mode button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: partialMode ? const Color(0xFFFEF3C7).withOpacity(0.2) : Colors.white,
                          side: BorderSide(
                            color: partialMode ? const Color(0xFFD97706) : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            partialMode = !partialMode;
                            paidNowController.clear();
                          });
                        },
                        child: Text(
                          partialMode ? 'PARTIAL PAYMENT ON' : 'PAID SOMETHING NOW? (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: partialMode ? const Color(0xFFD97706) : Colors.grey.shade500,
                            letterSpacing: 0.5.w,
                          ),
                        ),
                      ),
                    ),
    
                    if (partialMode) ...[
                      SizedBox(height: 12.h),
                      TextField(
                        controller: paidNowController,
                        onChanged: (v) => setDialogState(() {}),
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.grey),
                          hintText: 'Amount paid now...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFB),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12.r)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2), borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ),
                      if (paidNowController.text.isNotEmpty && paidNowVal > 0) ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total bill', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
                                  Text('₹${finalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.grey.shade800)),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Paid now', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.green)),
                                  Text('- ₹${paidNowVal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.green)),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Divider(color: const Color(0xFFFEF3C7)),
                              SizedBox(height: 8.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Remaining', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: const Color(0xFFD97706))),
                                  Text('₹${remaining.toStringAsFixed(2)}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFFD97706))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
    
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5.w)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                            ),
                            onPressed: (!isValid || isSaving)
                                ? null
                                : () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      await apiFetch(
                                        '/api/admin/orders/$orderId/pay-later',
                                        method: 'PATCH',
                                        data: {
                                          'customerName': customerName,
                                          'paidNow': partialMode ? paidNowVal : 0.0,
                                          'remaining': partialMode ? remaining : finalAmount,
                                        },
                                      );
                                      Navigator.pop(ctx);
                                      _fetchTables();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(partialMode
                                                ? '₹${paidNowVal.toStringAsFixed(2)} collected · ₹${remaining.toStringAsFixed(2)} pending for $customerName'
                                                : 'Pay Later saved for $customerName'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    } finally {
                                      setDialogState(() => isSaving = false);
                                    }
                                  },
                            child: Text(
                              isSaving ? 'Saving...' : 'Confirm',
                              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5.w),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSplitPaymentDialog(BuildContext parentCtx, double finalAmount) {
    final orderId = _billPreview?['table']?['currentOrderId'];
    if (orderId == null) return;

    String method1 = 'CASH';
    String method2 = 'UPI';
    final TextEditingController amount1Controller = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: parentCtx,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final val1 = double.tryParse(amount1Controller.text) ?? 0.0;
          final val2 = amount1Controller.text.isNotEmpty ? math.max(0.0, finalAmount - val1) : 0.0;
          
          final isValid = method1 != method2 && 
              amount1Controller.text.isNotEmpty && 
              val1 > 0 && 
              val1 < finalAmount;

          final METHODS = ['CASH', 'UPI', 'CARD'];

          Widget buildMethodBtn(String method, bool isFirst) {
            final isSelected = isFirst ? (method1 == method) : (method2 == method);
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setDialogState(() {
                    if (isFirst) {
                      method1 = method;
                      if (method == method2) {
                        method2 = METHODS.firstWhere((x) => x != method);
                      }
                    } else {
                      method2 = method;
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF5ED) : const Color(0xFFF8FAFB),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFF5C00) : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    method,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? const Color(0xFFFF5C00) : Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.r)),
            contentPadding: EdgeInsets.all(24.r),
            content: Container(
              width: 360.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Split Payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: const Color(0xFF0F172A))),
                    SizedBox(height: 4.h),
                    Text('TOTAL: ₹${finalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5.w)),
                    SizedBox(height: 16.h),
    
                    Text('FIRST METHOD', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5.w)),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        buildMethodBtn('CASH', true),
                        SizedBox(width: 8.w),
                        buildMethodBtn('UPI', true),
                        SizedBox(width: 8.w),
                        buildMethodBtn('CARD', true),
                      ],
                    ),
                    SizedBox(height: 12.h),
    
                    TextField(
                      controller: amount1Controller,
                      onChanged: (v) => setDialogState(() {}),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Amount by $method1...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFB),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12.r)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2), borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                    SizedBox(height: 16.h),
    
                    Text('SECOND METHOD', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5.w)),
                    SizedBox(height: 8.h),
                    Row(
                      children: METHODS.where((m) => m != method1).map((m) => buildMethodBtn(m, false)).toList(),
                    ),
                    SizedBox(height: 16.h),
    
                    if (isValid) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(12.r)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$method1: ₹${val1.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            Text('$method2: ₹${val2.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5.w)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1), // Indigo
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                            ),
                            onPressed: (!isValid || isSaving)
                                ? null
                                : () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      await apiFetch(
                                        '/api/orders/split-payment',
                                        method: 'POST',
                                        data: {
                                          'orderId': orderId,
                                          'payments': [
                                            {'method': method1, 'amount': val1},
                                            {'method': method2, 'amount': val2},
                                          ],
                                          'discountType': _discountType,
                                          'discountValue': double.tryParse(_discountValue) ?? 0.0,
                                        },
                                      );
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _discountType = 'NONE';
                                        _discountValue = '';
                                      });
                                      _fetchTables();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Split payment collected ✓'), backgroundColor: Colors.green),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    } finally {
                                      setDialogState(() => isSaving = false);
                                    }
                                  },
                            child: Text(
                              isSaving ? 'Processing...' : 'Confirm',
                              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5.w),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAdjustLayoutModal(String areaName, int currentCount) {
    int newCount = currentCount;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
            contentPadding: EdgeInsets.all(24.r),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Sitting: $areaName', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: Icon(LucideIcons.x, size: 16.sp, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    children: [
                      Text('TARGET TABLE COUNT', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.w)),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (newCount > 0) {
                                setDialogState(() {
                                  newCount--;
                                });
                              }
                            },
                            child: Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12.r), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4.r)]),
                              child: Icon(LucideIcons.minus, size: 16.sp, color: Colors.black87),
                            ),
                          ),
                          SizedBox(width: 24.w),
                          Text('$newCount', style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                          SizedBox(width: 24.w),
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                newCount++;
                              });
                            },
                            child: Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12.r), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4.r)]),
                              child: Icon(LucideIcons.plus, size: 16.sp, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    onPressed: isSaving 
                        ? null 
                        : () async {
                            setDialogState(() => isSaving = true);
                            try {
                              await apiFetch('/api/pos/update-sitting', method: 'POST', data: {
                                'areaName': areaName,
                                'targetCount': newCount,
                              });
                              Navigator.pop(ctx);
                              _fetchTables();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
                              }
                            } finally {
                              setDialogState(() => isSaving = false);
                            }
                          },
                    icon: isSaving 
                        ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(LucideIcons.save, size: 18.sp, color: Colors.white),
                    label: Text(isSaving ? 'SAVING...' : 'SAVE SITTING', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
                  ),
                ),
                SizedBox(height: 10.h),
                
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    onPressed: isSaving 
                        ? null 
                        : () async {
                            final confirmDel = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
                                content: Text('Delete ALL blank tables in $areaName?', style: TextStyle(fontSize: 14.sp)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmDel != true) return;
                            
                            setDialogState(() => isSaving = true);
                            try {
                              await apiFetch('/api/pos/update-sitting', method: 'POST', data: {
                                'areaName': areaName,
                                'targetCount': 0,
                              });
                              Navigator.pop(ctx);
                              _fetchTables();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
                              }
                            } finally {
                              setDialogState(() => isSaving = false);
                            }
                          },
                    icon: Icon(LucideIcons.trash2, size: 16.sp),
                    label: Text('DELETE ALL BLANK TABLES', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showPrinterSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final user = ref.watch(authProvider).user;
            final userData = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});
            final bool autoPrintKOT = userData['autoPrintKOT'] == true;
            final bool autoPrintBill = userData['autoPrintBill'] == true;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF5ED),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(LucideIcons.printer, color: const Color(0xFFFF5C00), size: 20.sp),
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Print Settings', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                SizedBox(height: 2.h),
                                Text('Saves instantly on toggle', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(LucideIcons.x, size: 18.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    SwitchListTile.adaptive(
                      title: Text('Auto Print KOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      subtitle: Text('Kitchen ticket on every order', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                      value: autoPrintKOT,
                      activeTrackColor: const Color(0xFFA7F3D0),
                      activeThumbColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        try {
                          final kotService = ref.read(kotPrintServiceProvider);
                          await kotService.updatePrinterSettings(autoPrintKOT: val);
                          final updatedUser = Map<String, dynamic>.from(userData);
                          updatedUser['autoPrintKOT'] = val;
                          ref.read(authProvider.notifier).setUserData(updatedUser);
                          setModalState(() {});
                        } catch (e) {
                          debugPrint('Error updating printer settings: $e');
                        }
                      },
                    ),
                    Divider(color: Colors.grey.shade100),
                    SwitchListTile.adaptive(
                      title: Text('Auto Print Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      subtitle: Text('Customer receipt on checkout', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                      value: autoPrintBill,
                      activeTrackColor: const Color(0xFFA7F3D0),
                      activeThumbColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        try {
                          final kotService = ref.read(kotPrintServiceProvider);
                          await kotService.updatePrinterSettings(autoPrintBill: val);
                          final updatedUser = Map<String, dynamic>.from(userData);
                          updatedUser['autoPrintBill'] = val;
                          ref.read(authProvider.notifier).setUserData(updatedUser);
                          setModalState(() {});
                        } catch (e) {
                          debugPrint('Error updating printer settings: $e');
                        }
                      },
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.go('/dashboard/settings');
                        },
                        child: Text('More Printer Settings', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userData = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});
    final bool autoPrintKOT = userData['autoPrintKOT'] == true;
    final bool autoPrintBill = userData['autoPrintBill'] == true;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFB),
      endDrawer: MenuModal(
        table: _selectedTable,
        onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        onOrderPlaced: (newOrder) {
          _fetchTables();
        },
        sendAppendOrder: _selectedTable != null && _selectedTable!['status'] == 'Running' 
            ? _selectedTable 
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isMobile = 1.sw < 768;
                    return Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16.w,
                      runSpacing: 16.h,
                      children: [
                        SizedBox(
                          width: isMobile ? 1.sw : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Table Management', style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                              Text('Monitor and manage your floor layout in real-time.', style: TextStyle(fontSize: 14.sp, color: Colors.grey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  onPressed: () => _showPrinterSettingsModal(context),
                                  icon: Icon(
                                    LucideIcons.printer,
                                    size: 18.sp,
                                    color: (autoPrintKOT || autoPrintBill)
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF475569),
                                  ),
                                  tooltip: 'Printer Settings',
                                  style: IconButton.styleFrom(
                                    backgroundColor: (autoPrintKOT || autoPrintBill)
                                        ? const Color(0xFFECFDF5)
                                        : Colors.white,
                                    side: BorderSide(
                                      color: (autoPrintKOT || autoPrintBill)
                                          ? const Color(0xFFA7F3D0)
                                          : Colors.grey.shade200,
                                    ),
                                    padding: EdgeInsets.all(14.r),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                  ),
                                ),
                                if (autoPrintKOT || autoPrintBill)
                                  Positioned(
                                    top: -4.h,
                                    right: -4.w,
                                    child: Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: BoxConstraints(minWidth: 16.r, minHeight: 16.r),
                                      child: Center(
                                        child: Text(
                                          '${(autoPrintKOT ? 1 : 0) + (autoPrintBill ? 1 : 0)}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 12.w),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/dashboard/pos'),
                              icon: Icon(LucideIcons.plus, size: 18.sp),
                              label: Text('ADD NEW TABLES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5C00),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              ),
                            ),
                          ],
                        )
                      ],
                    );
                  }
                ),
                SizedBox(height: 32.h),
                
                // Areas or skeleton loader
                if (_isLoading && _areas.isEmpty) ...[
                  const SkeletonArea(),
                  const SkeletonArea(),
                ] else ..._getSortedAreaNames().asMap().entries.map((entry) {
                  final index = entry.key;
                  final areaName = entry.value;
                  final tables = _areas[areaName] ?? [];
                  final totalAreaCount = _getSortedAreaNames().length;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 40.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildReorderArrows(areaName, index, totalAreaCount),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8.r)),
                                  child: Icon(LucideIcons.layoutGrid, size: 18.sp, color: Colors.grey),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  '${areaName.toUpperCase()} (${tables.length})',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 2.w, color: const Color(0xFF0F172A)),
                                )
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAdjustLayoutModal(areaName, tables.length),
                              icon: Icon(LucideIcons.settings, size: 14.sp),
                              label: Text('ADJUST', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF5C00),
                                side: const BorderSide(color: Color(0xFFFF5C00)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            )
                          ],
                        ),
                        SizedBox(height: 16.h),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180.w,
                            mainAxisSpacing: 16.h,
                            crossAxisSpacing: 16.w,
                            childAspectRatio: 1,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (ctx, idx) {
                            final table = tables[idx];
                            final isRunning = table['status'] == 'Running';
                            final double totalAmount = _getTableTotal(table);
                            final int? minutesAgo = _getMinutesAgo(table);
                            
                            return Stack(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (isRunning) {
                                      _handleShowBillPreview(table);
                                    } else {
                                      setState(() => _selectedTable = table);
                                      _scaffoldKey.currentState?.openEndDrawer();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(24.r),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isRunning ? const Color(0xFFFF5C00) : Colors.white,
                                      borderRadius: BorderRadius.circular(24.r),
                                      border: isRunning ? Border.all(color: Colors.transparent) : Border.all(color: Colors.grey.shade200),
                                      boxShadow: isRunning 
                                          ? [BoxShadow(color: const Color(0xFFFF5C00).withAlpha(50), blurRadius: 20.r, offset: const Offset(0, 8))] 
                                          : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10.r, offset: const Offset(0, 4))],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (isRunning && minutesAgo != null)
                                          Positioned(
                                            top: 10.h,
                                            left: 10.w,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withAlpha(40),
                                                borderRadius: BorderRadius.circular(12.r),
                                              ),
                                              child: Text(
                                                '$minutesAgo Min',
                                                style: TextStyle(
                                                  fontSize: 8.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5.w,
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              LucideIcons.armchair,
                                              size: 28.sp,
                                              color: isRunning ? Colors.white.withAlpha(100) : Colors.grey.shade300,
                                            ),
                                            SizedBox(height: 6.h),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                              child: Text(
                                                _formatCardLabel(table),
                                                style: TextStyle(
                                                  fontSize: 22.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: isRunning ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: isRunning ? Colors.white.withAlpha(50) : Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(20.r),
                                              ),
                                              child: Text(
                                                isRunning 
                                                    ? '₹${totalAmount.toStringAsFixed(2)}' 
                                                    : 'VACANT',
                                                style: TextStyle(
                                                  fontSize: isRunning ? 11.sp : 9.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: isRunning ? Colors.white : Colors.grey.shade500,
                                                  letterSpacing: isRunning ? 0.0 : 0.5.w,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isRunning) ...[
                                  Positioned(
                                    top: 8.h,
                                    right: 8.w,
                                    child: Column(
                                      children: [
                                        _buildActionBtn(
                                          LucideIcons.plus,
                                          Colors.green,
                                          () {
                                            setState(() => _selectedTable = table);
                                            _scaffoldKey.currentState?.openEndDrawer();
                                          },
                                        ),
                                        _buildActionBtn(
                                          LucideIcons.printer,
                                          const Color(0xFFFF5C00),
                                          () => _handleShowBillPreview(table),
                                        ),
                                        if (autoPrintKOT)
                                          _buildActionBtn(
                                            LucideIcons.zap,
                                            const Color(0xFFF59E0B),
                                            () => _showReprintKOTOptions(table),
                                          ),
                                        _buildActionBtn(
                                          LucideIcons.moveHorizontal,
                                          Colors.blue,
                                          () => _showShiftModal(table),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Positioned(
                                    top: 4.h,
                                    right: 4.w,
                                    child: IconButton(
                                      onPressed: () => _handleDeleteTable(table['_id']),
                                      icon: Icon(LucideIcons.trash2, color: Colors.red.shade400, size: 14.sp),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        shadowColor: Colors.black.withAlpha(20),
                                        elevation: 2,
                                        padding: EdgeInsets.all(6.r),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        )
                      ],
                    ),
                  );
                })
              ],
            ),
          ),
          if (_isBillLoading)
            Container(
              color: Colors.black.withAlpha(80),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color hoverColor, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(color: Colors.white.withAlpha(50), shape: BoxShape.circle),
          child: Icon(icon, size: 14.sp, color: Colors.white),
        ),
      ),
    );
  }
}

class SkeletonArea extends StatefulWidget {
  const SkeletonArea({super.key});

  @override
  State<SkeletonArea> createState() => _SkeletonAreaState();
}

class _SkeletonAreaState extends State<SkeletonArea> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: EdgeInsets.only(bottom: 40.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      width: 120.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 80.w,
                  height: 28.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180.w,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 1,
              ),
              itemCount: 6,
              itemBuilder: (ctx, idx) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

