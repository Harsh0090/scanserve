import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../utils/apiClient.dart';
import '../../components/MenuModal.dart';

class OwnerSetupPage extends StatefulWidget {
  const OwnerSetupPage({super.key});
  @override
  State<OwnerSetupPage> createState() => _OwnerSetupPageState();
}

class _OwnerSetupPageState extends State<OwnerSetupPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, List<dynamic>> _areas = {};
  bool _isLoading = false;
  Map<String, dynamic>? _selectedTable;

  @override
  void initState() {
    super.initState();
    _fetchTables();
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
        if (mounted) setState(() => _areas = grouped);
      }
    } catch (e) {
      debugPrint("Failed to fetch tables: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _showShiftModal(dynamic table) {
    String newNum = '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Shift Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Moving order from ${table['tableName']} to:', style: TextStyle(fontSize: 14.sp)),
          SizedBox(height: 16.h),
          TextField(
            onChanged: (v) => newNum = v,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(hintText: 'New table number...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
          )
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: TextStyle(fontSize: 12.sp, color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)), padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h)),
          onPressed: () async {
            if (newNum.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await apiFetch('/api/admin/orders/${table['currentOrderId']}/shift', method: 'PATCH', data: {'newTableNumber': newNum});
              _fetchTables();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Table shifted')));
            } catch (e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          child: Text('CONFIRM SHIFT', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
        )
      ],
    ));
  }

  Future<void> _handlePrintBill(dynamic table) async {
    if (table['currentOrderId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active order')));
      return;
    }
    try {
      await apiFetch('/api/admin/orders/${table['currentOrderId']}/print-bill', method: 'PATCH');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill Printed Successfully (Mocked for Flutter)')));
         _fetchTables();
      }
    } catch (e) {
      debugPrint("Print err $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _areas.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4D00))));
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFB),
      endDrawer: MenuModal(
        table: _selectedTable,
        onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        onOrderPlaced: (newOrder) {
          _fetchTables(); // Refresh table statuses instantly
        },
        sendAppendOrder: _selectedTable != null && _selectedTable!['status'] == 'Running' 
            ? _selectedTable 
            : null,
      ),
      body: SingleChildScrollView(
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
                    )
                  ],
                );
              }
            ),
            SizedBox(height: 32.h),
            // Areas
            ..._areas.entries.map((area) {
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
                            Container(padding: EdgeInsets.all(8.r), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8.r)), child: Icon(LucideIcons.layoutGrid, size: 18.sp, color: Colors.grey)),
                            SizedBox(width: 12.w),
                            Text('${area.key.toUpperCase()} (${area.value.length})', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 2.w, color: const Color(0xFF0F172A)))
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjust Layout (EditTableModal) Not Implemented')));
                          },
                          icon: Icon(LucideIcons.settings, size: 14.sp),
                          label: Text('ADJUST LAYOUT', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
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
                      itemCount: area.value.length,
                      itemBuilder: (ctx, idx) {
                        final table = area.value[idx];
                        final isRunning = table['status'] == 'Running';
                        return Stack(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _selectedTable = table);
                                _scaffoldKey.currentState?.openEndDrawer();
                              },
                              borderRadius: BorderRadius.circular(24.r),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: isRunning ? const Color(0xFFFF5C00) : Colors.white,
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: isRunning ? Border.all(color: Colors.transparent) : Border.all(color: Colors.grey.shade200),
                                  boxShadow: isRunning ? [BoxShadow(color: const Color(0xFFFF5C00).withAlpha(50), blurRadius: 20.r)] : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.armchair, size: 32.sp, color: isRunning ? Colors.white.withAlpha(100) : Colors.grey.shade300),
                                    SizedBox(height: 8.h),
                                    Text('${table['tableName']}', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: isRunning ? Colors.white : const Color(0xFF0F172A))),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                      decoration: BoxDecoration(color: isRunning ? Colors.white.withAlpha(50) : Colors.grey.shade50, borderRadius: BorderRadius.circular(20.r)),
                                      child: Text(isRunning ? 'OCCUPIED' : 'VACANT', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: isRunning ? Colors.white : Colors.grey, letterSpacing: 1.w))
                                    )
                                  ],
                                ),
                              ),
                            ),
                            if (isRunning) ...[
                              Positioned(
                                top: 8.h, right: 8.w,
                                child: Column(
                                  children: [
                                    _buildActionBtn(LucideIcons.plus, Colors.green, () {
                                      setState(() => _selectedTable = table);
                                      _scaffoldKey.currentState?.openEndDrawer();
                                    }),
                                    _buildActionBtn(LucideIcons.printer, const Color(0xFFFF5C00), () => _handlePrintBill(table)),
                                    _buildActionBtn(LucideIcons.moveHorizontal, Colors.blue, () => _showShiftModal(table)),
                                  ],
                                )
                              )
                            ] else ...[
                               Positioned(
                                top: 0, right: 0,
                                child: IconButton(
                                  onPressed: () => _handleDeleteTable(table['_id']),
                                  icon: Icon(LucideIcons.trash2, color: Colors.red, size: 16.sp),
                                  style: IconButton.styleFrom(backgroundColor: Colors.white, shadowColor: Colors.black.withAlpha(20), elevation: 2),
                                )
                              )
                            ]
                          ],
                        );
                      },
                    )
                  ],
                ),
              );
            }).toList()
          ],
        ),
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
