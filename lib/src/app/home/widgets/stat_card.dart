import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: primary ? null : Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: primary
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: primary
                      ? const Color(0xFFFF5C00)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  icon,
                  size: 16.sp,
                  color: primary ? Colors.white : const Color(0xFFFF5C00),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: primary ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (sub != null) ...[
            SizedBox(height: 3.h),
            Row(
              children: [
                if (trend == 'up')
                  Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: Icon(
                      LucideIcons.arrowUpRight,
                      size: 11.sp,
                      color: Colors.green.shade500,
                    ),
                  ),
                if (trend == 'down')
                  Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: Icon(
                      LucideIcons.arrowDownRight,
                      size: 11.sp,
                      color: Colors.red.shade500,
                    ),
                  ),
                Expanded(
                  child: Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: trend == 'up'
                          ? Colors.green.shade500
                          : trend == 'down'
                              ? Colors.red.shade500
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
