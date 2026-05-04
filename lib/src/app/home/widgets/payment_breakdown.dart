import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentBreakdown extends StatelessWidget {
  final Map<String, dynamic> data;
  const PaymentBreakdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cash = (data['CASH'] ?? 0).toDouble();
    final upi = (data['UPI'] ?? 0).toDouble();
    final card = (data['CARD'] ?? 0).toDouble();
    final total = (cash + upi + card) == 0 ? 1.0 : (cash + upi + card);

    final methods = [
      {
        'label': 'Cash',
        'value': cash,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF047857),
      },
      {
        'label': 'UPI',
        'value': upi,
        'color': const Color(0xFFFF5C00),
        'bg': const Color(0xFFFFF7ED),
        'text': const Color(0xFFC2410C),
      },
      {
        'label': 'Card',
        'value': card,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFFEFF6FF),
        'text': const Color(0xFF1D4ED8),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                    'PAYMENT BREAKDOWN',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Cash · UPI · Card',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(12.sp),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  LucideIcons.wallet,
                  size: 18.sp,
                  color: Color(0xFFFF5C00),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: methods.map((m) {
              final val = m['value'] as double;
              final pct = (val / total * 100).round();
              return Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  padding: EdgeInsets.all(14.sp),
                  decoration: BoxDecoration(
                    color: m['bg'] as Color,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          color: m['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        (m['label'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: (m['text'] as Color).withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '\u20B9${val.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: m['text'] as Color,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          color: (m['text'] as Color).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: Row(
              children: methods.map((m) {
                final val = m['value'] as double;
                return Expanded(
                  flex: (val / total * 100).round().clamp(1, 100),
                  child: Container(
                    height: 8.h,
                    color: m['color'] as Color,
                    margin: EdgeInsets.symmetric(horizontal: 1.w),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
