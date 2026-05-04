import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ExpenseSummary extends StatelessWidget {
  final Map<String, dynamic>? expense;
  final double revenue;
  const ExpenseSummary({super.key, this.expense, required this.revenue});

  @override
  Widget build(BuildContext context) {
    final total = (expense?['total'] ?? 0).toDouble();
    final netProfit = revenue - total;
    final profitPct = revenue > 0 ? (netProfit / revenue * 100).round() : 0;
    final categories = (expense?['breakdown'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FINANCE OVERVIEW',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Profit & Expenses',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12.sp),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  LucideIcons.trendingDown,
                  size: 18.sp,
                  color: Color(0xFFFF5C00),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              _tile(
                'Revenue',
                revenue,
                Colors.white,
                Colors.white.withOpacity(0.05),
              ),
              SizedBox(width: 8.w),
              _tile(
                'Expenses',
                total,
                Colors.red.shade400,
                Colors.red.withOpacity(0.1),
              ),
              SizedBox(width: 8.w),
              _tile(
                'Net Profit',
                netProfit.abs(),
                netProfit >= 0 ? Colors.green.shade400 : Colors.red.shade400,
                netProfit >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MARGIN',
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 2,
                ),
              ),
              Text(
                '$profitPct%',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                  color: profitPct >= 0
                      ? Colors.green.shade400
                      : Colors.red.shade400,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: (profitPct.abs() / 100).clamp(0.0, 1.0),
              minHeight: 8.h,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: profitPct >= 0
                  ? Colors.green.shade500
                  : Colors.red.shade500,
            ),
          ),
          if (categories.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Text(
              'TOP EXPENSES',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 12.h),
            ...categories
                .take(3)
                .map(
                  (cat) => Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cat['category']}'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCBD5E1),
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '-\u20B9${_fmt(cat['amount'])}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _tile(String label, double value, Color textColor, Color bg) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(14.sp),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: label == 'Expenses'
                    ? Colors.red.shade400
                    : const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '\u20B9${_fmt(value)}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) => (v is num ? v : num.tryParse('$v') ?? 0)
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
