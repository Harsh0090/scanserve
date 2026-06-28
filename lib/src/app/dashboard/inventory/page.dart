import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  bool _loading = true;
  List<dynamic> _items = [];
  String? _editingItem;
  bool _showForm = false;
  bool _saving = false;

  Map<String, dynamic> _form = {
    'name': '',
    'unit': 'piece',
    'currentStock': '',
    'lowStockThreshold': '',
    'costPerUnit': '',
  };

  Map<String, dynamic> _editForm = {};
  
  final List<String> _unitOptions = ["piece", "g", "kg", "ml", "ltr"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInventory();
    });
  }

  Future<void> _fetchInventory() async {
    setState(() => _loading = true);
    try {
      final res = await apiFetch("/api/inventory/items");
      setState(() {
        _items = (res is List) ? res : (res['data'] ?? []);
      });
    } catch (err) {
      debugPrint(err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createItem() async {
    if (_form['name'].toString().isEmpty || _form['currentStock'].toString().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
       return;
    }
    
    setState(() => _saving = true);
    try {
      await apiFetch("/api/inventory/item", method: "POST", data: {
        ..._form,
        'currentStock': num.tryParse(_form['currentStock'].toString()) ?? 0,
        'lowStockThreshold': num.tryParse(_form['lowStockThreshold'].toString()) ?? 0,
        'costPerUnit': num.tryParse(_form['costPerUnit'].toString()) ?? 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item created')));
      setState(() {
        _form = {
          'name': '',
          'unit': 'piece',
          'currentStock': '',
          'lowStockThreshold': '',
          'costPerUnit': '',
        };
        _showForm = false;
      });
      _fetchInventory();
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create item')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (confirm != true) return;

    try {
      await apiFetch("/api/inventory/item/$id", method: "DELETE");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
      _fetchInventory();
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
    }
  }

  void _startEdit(dynamic item) {
    setState(() {
      _editingItem = item['_id'];
      _editForm = {
        'name': item['name'],
        'unit': item['unit'],
        'currentStock': item['currentStock'].toString(),
        'lowStockThreshold': item['lowStockThreshold'].toString(),
        'costPerUnit': item['costPerUnit'].toString(),
      };
    });
  }

  Future<void> _saveEdit(String id) async {
    try {
      await apiFetch("/api/inventory/item/$id", method: "PATCH", data: {
        ..._editForm,
        'currentStock': num.tryParse(_editForm['currentStock'].toString()) ?? 0,
        'lowStockThreshold': num.tryParse(_editForm['lowStockThreshold'].toString()) ?? 0,
        'costPerUnit': num.tryParse(_editForm['costPerUnit'].toString()) ?? 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item updated')));
      setState(() => _editingItem = null);
      _fetchInventory();
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update')));
    }
  }

  @override
  Widget build(BuildContext context) {
    int lowStockCount = _items.where((i) => (i['currentStock'] ?? 0) <= (i['lowStockThreshold'] ?? 0)).length;
    double totalValue = _items.fold(0, (sum, i) => sum + ((i['currentStock'] ?? 0) * (i['costPerUnit'] ?? 0)));

    final isMobile = MediaQuery.of(context).size.width < 600.w;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.r : 24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Manage ingredients and raw\nstock',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade400, height: 1.3),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showForm = !_showForm),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5C00).withOpacity(0.3),
                          blurRadius: 12.r,
                          offset: Offset(0, 6.h),
                        ),
                      ]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_showForm ? LucideIcons.x : LucideIcons.plus, color: Colors.white, size: 16.sp),
                        SizedBox(width: 8.w),
                        Text(
                          _showForm ? 'Cancel' : 'Add\nItem',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.sp, height: 1.1),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Stats
            Row(
              children: [
                Expanded(child: _buildStatCard("Total\nItems", _items.length.toString(), false)),
                SizedBox(width: 12.w),
                Expanded(child: _buildStatCard("Low\nStock", lowStockCount.toString(), lowStockCount > 0)),
                SizedBox(width: 12.w),
                Expanded(child: _buildStatCard("Total\nValue", "₹${totalValue.toStringAsFixed(0)}", false)),
              ],
            ),
            SizedBox(height: 24.h),

            // Form
            if (_showForm) ...[
              Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.package, color: const Color(0xFFFF5C00), size: 16.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'NEW INVENTORY ITEM',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Wrap(
                      spacing: 12.w,
                      runSpacing: 12.h,
                      children: [
                        _buildInputField('Name (e.g. Aloo Patty)', 'name', isMobile),
                        _buildUnitDropdown(isMobile),
                        _buildInputField('Current Stock', 'currentStock', isMobile, isNumber: true),
                        _buildInputField('Low Alert At', 'lowStockThreshold', isMobile, isNumber: true),
                        _buildInputField('Cost per Unit (₹)', 'costPerUnit', isMobile, isNumber: true),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    ElevatedButton(
                      onPressed: _saving ? null : _createItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: Text(
                        _saving ? 'Creating...' : 'Create Item',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // Grid
            if (_loading)
              const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
            else if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Column(
                    children: [
                      Icon(LucideIcons.package, size: 48.sp, color: Colors.grey.shade300),
                      SizedBox(height: 12.h),
                      Text('No inventory items yet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 14.sp)),
                      Text('Click "Add Item" to get started', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400.w,
                  mainAxisExtent: 380.h,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildInventoryCard(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, bool isRed) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade300, letterSpacing: 1, height: 1.2), maxLines: 2),
          SizedBox(height: 12.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: isRed ? Colors.red : const Color(0xFF0F172A), letterSpacing: -1)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String hint, String fieldKey, bool isMobile, {bool isNumber = false}) {
    return SizedBox(
      width: isMobile ? double.infinity : 150.w,
      child: TextField(
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: (val) => setState(() => _form[fieldKey] = val),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFFF5C00))),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown(bool isMobile) {
    return SizedBox(
      width: isMobile ? double.infinity : 150.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _form['unit'],
            isExpanded: true,
            style: TextStyle(fontSize: 12.sp, color: Colors.black, fontWeight: FontWeight.w500),
            items: _unitOptions.map((String u) {
              return DropdownMenuItem<String>(value: u, child: Text(u));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _form['unit'] = val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(dynamic item) {
    final bool isLow = (item['currentStock'] ?? 0) <= (item['lowStockThreshold'] ?? 0);
    final bool isEditing = _editingItem == item['_id'];
    
    double stockPct = 100.0;
    if ((item['lowStockThreshold'] ?? 0) > 0) {
      stockPct = ((item['currentStock'] ?? 0) / ((item['lowStockThreshold'] ?? 1) * 3)) * 100;
      if (stockPct > 100) stockPct = 100;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12.r, offset: Offset(0, 6.h)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 6.h, width: double.infinity, color: isLow ? Colors.red.shade400 : const Color(0xFFFF5C00)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isEditing)
                              TextField(
                                onChanged: (v) => _editForm['name'] = v,
                                controller: TextEditingController(text: _editForm['name'])..selection = TextSelection.collapsed(offset: _editForm['name'].toString().length),
                                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: UnderlineInputBorder()),
                              )
                            else
                              Text(item['name'] ?? '', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            SizedBox(height: 4.h),
                            if (isEditing)
                              DropdownButton<String>(
                                value: _editForm['unit'],
                                isDense: true,
                                style: TextStyle(fontSize: 12.sp, color: Colors.black, fontWeight: FontWeight.w900),
                                items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (v) { if (v != null) setState(() => _editForm['unit'] = v); },
                              )
                            else
                              Text(item['unit'].toString().toUpperCase(), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade300, letterSpacing: 1)),
                          ],
                        ),
                      ),
                      if (isLow)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12.r)),
                          child: Row(
                            children: [
                              Icon(LucideIcons.alertTriangle, size: 10.sp, color: Colors.red),
                              SizedBox(width: 4.w),
                              Text('LOW', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  
                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('STOCK LEVEL', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade300, letterSpacing: 1)),
                      Text('${item['currentStock']} ${item['unit']}', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade300)),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    height: 8.h,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8.r)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: MediaQuery.of(context).size.width * (stockPct / 100) * 0.4, // Approximation
                        decoration: BoxDecoration(color: isLow ? Colors.red.shade400 : const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(8.r)),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  
                  // Details
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDetailRow('Current Stock', 'currentStock', item, isEditing),
                        _buildDetailRow('Low Alert At', 'lowStockThreshold', item, isEditing),
                        _buildDetailRow('Cost per Unit', 'costPerUnit', item, isEditing, prefix: '₹'),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Value', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade300)),
                            Text('₹${((item['currentStock'] ?? 0) * (item['costPerUnit'] ?? 0)).toStringAsFixed(2)}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF5C00))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Buttons
                  SizedBox(height: 16.h),
                  if (isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _saveEdit(item['_id']),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), padding: EdgeInsets.symmetric(vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                            child: Text('Save', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _editingItem = null),
                            style: TextButton.styleFrom(backgroundColor: Colors.grey.shade100, padding: EdgeInsets.symmetric(vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                            child: Text('Cancel', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _startEdit(item),
                            icon: Icon(LucideIcons.pencil, size: 14.sp, color: Colors.white),
                            label: Text('Edit', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), padding: EdgeInsets.symmetric(vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _deleteItem(item['_id']),
                            icon: Icon(LucideIcons.trash2, size: 14.sp, color: const Color(0xFFE11D48)),
                            label: Text('Delete', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: const Color(0xFFE11D48))),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF1F2), elevation: 0, padding: EdgeInsets.symmetric(vertical: 12.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                          ),
                        ),
                      ],
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String key, dynamic item, bool isEditing, {String prefix = ''}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade300)),
          if (isEditing)
            SizedBox(
              width: 60.w,
              child: TextField(
                onChanged: (v) => _editForm[key] = v,
                controller: TextEditingController(text: _editForm[key].toString())..selection = TextSelection.collapsed(offset: _editForm[key].toString().length),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: UnderlineInputBorder()),
              ),
            )
          else
            Text('$prefix${item[key]}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
