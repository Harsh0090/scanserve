import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool primary;
  final String? sub;
  final String? trend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.primary = false,
    this.sub,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: primary ? null : Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: primary
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: primary ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (sub != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          if (trend == 'up')
                            Icon(
                              LucideIcons.arrowUpRight,
                              size: 11.sp,
                              color: Colors.green.shade400,
                            ),
                          if (trend == 'down')
                            Icon(
                              LucideIcons.arrowDownRight,
                              size: 11.sp,
                              color: Colors.red.shade400,
                            ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              sub!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: trend == 'up'
                                    ? Colors.green.shade400
                                    : trend == 'down'
                                    ? Colors.red.shade400
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary
                      ? const Color(0xFFFF5C00)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: primary ? Colors.white : const Color(0xFFFF5C00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
