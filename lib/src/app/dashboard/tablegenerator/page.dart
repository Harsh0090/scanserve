import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/apiClient.dart';
import '../../context/AuthContext.dart';

class TableGeneratorPage extends ConsumerStatefulWidget {
  const TableGeneratorPage({super.key});
  @override
  ConsumerState<TableGeneratorPage> createState() => _TableGeneratorPageState();
}

class _TableGeneratorPageState extends ConsumerState<TableGeneratorPage> {
  String _count = '';
  List<dynamic> _tables = [];
  bool _isLoading = false;

  Future<void> _generate() async {
    final countInt = int.tryParse(_count);
    if (countInt == null || countInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of tables')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider).user;
      final restaurantId = user?['restaurantId'] ?? user?['_id'];

      final res = await apiFetch(
        '/api/tables/generate',
        method: 'POST',
        data: {
          'tableCount': countInt,
          if (restaurantId != null) 'restaurantId': restaurantId,
        },
      );
      if (res['tables'] != null) {
        setState(() => _tables = res['tables']);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to generate QR codes'),
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printQR(dynamic table) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Printing Table ${table['tableNumber']} (Requires native printing package)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1100.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.qrCode,
                              size: 14.sp,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'SMART QR GENERATION',
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
                      SizedBox(height: 16.h),
                      Text(
                        'Generate Table QRs',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -1,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Create instant digital menu access for every table in your restaurant.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),

                // Input Card
                Container(
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40.r),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade50.withAlpha(50),
                        blurRadius: 20.r,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isMobile = constraints.maxWidth < 600.w;
                          return Flex(
                            direction: isMobile
                                ? Axis.vertical
                                : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HOW MANY TABLES?',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
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
                                      child: Row(
                                        children: [
                                          Icon(
                                            LucideIcons.layoutGrid,
                                            size: 20.sp,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: TextField(
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (v) => _count = v,
                                              decoration: InputDecoration(
                                                hintText: 'e.g. 15',
                                                border: InputBorder.none,
                                              ),
                                              style: TextStyle(
                                                fontSize: 20.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMobile)
                                SizedBox(height: 16.h)
                              else
                                SizedBox(width: 24.w),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generate,
                                icon: Icon(LucideIcons.zap, size: 18.sp),
                                label: Text(
                                  _isLoading ? 'GENERATING...' : 'GENERATE QRS',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 40.w,
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
                      Container(
                        padding: EdgeInsets.all(20.sp),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.info,
                              color: Colors.blue,
                              size: 18.sp,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TRIAL PHASE BENEFIT',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.blue,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Generating QR codes is FREE in your trial. These codes will link directly to your digital menu.',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
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
                ),
                SizedBox(height: 40.h),

                // QR Grid
                if (_tables.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tables.length,
                    itemBuilder: (ctx, idx) {
                      final table = _tables[idx];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        padding: EdgeInsets.all(16.sp),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade50.withAlpha(20),
                              blurRadius: 10.r,
                              offset: Offset(0, 4.h),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // QR Code
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Image.network(
                                'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent(table['qrUrl'] ?? '')}',
                                width: 140.w,
                                height: 140.w,
                                errorBuilder: (ctx, err, stack) => Icon(
                                  LucideIcons.qrCode,
                                  size: 140.w,
                                  color: Colors.black12,
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            // Details
                            Column(
                              children: [
                                Text(
                                  'OUTLET ASSET',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Table ${table['tableNumber']}',
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            // Print Action
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _printQR(table),
                                icon: Icon(LucideIcons.printer, size: 18.sp),
                                label: Text(
                                  'PRINT LABEL',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: BorderSide(color: Colors.grey.shade200),
                                  backgroundColor: Colors.grey.shade50,
                                  padding: EdgeInsets.symmetric(vertical: 20.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                SizedBox(height: 48.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.shieldCheck,
                      color: Colors.green,
                      size: 14.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'POWERED BY QRSERVE SECURE SYSTEMS',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
