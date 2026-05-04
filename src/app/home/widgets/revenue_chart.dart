import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RevenueChart extends StatelessWidget {
  final List<dynamic> graphData;
  const RevenueChart({super.key, required this.graphData});

  @override
  Widget build(BuildContext context) {
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
                    'REVENUE DYNAMICS',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Sales vs Upsell Trend',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _legend(const Color(0xFFFF5C00), 'Sales'),
                  SizedBox(width: 12.w),
                  _legend(const Color(0xFF10B981), 'Upsell'),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 220.h,
            child: graphData.isEmpty ? _empty() : _chart(),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
    children: [
      Container(
        width: 10.w,
        height: 10.h,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      SizedBox(width: 6.w),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
        ),
      ),
    ],
  );

  Widget _empty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.barChart2, size: 40.sp, color: Colors.grey.shade200),
        SizedBox(height: 12.h),
        Text(
          'NO CHART DATA YET',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade300,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );

  Widget _chart() {
    final salesSpots = <FlSpot>[];
    final upsellSpots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < graphData.length; i++) {
      final item = graphData[i];
      final s = (item['sales'] ?? 0).toDouble();
      final u = (item['upsell'] ?? 0).toDouble();
      salesSpots.add(FlSpot(i.toDouble(), s));
      upsellSpots.add(FlSpot(i.toDouble(), u));
      if (s > maxY) maxY = s;
      if (u > maxY) maxY = u;
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                _fmtK(v),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= graphData.length)
                  return const SizedBox.shrink();
                final d = '${graphData[i]['date'] ?? ''}';
                final short = d.length > 5 ? d.substring(5) : d;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    short,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItems: (spots) => spots.map((s) {
              final color = s.barIndex == 0
                  ? const Color(0xFFFF5C00)
                  : const Color(0xFF10B981);
              final label = s.barIndex == 0 ? 'Sales' : 'Upsell';
              return LineTooltipItem(
                '$label: \u20B9${s.y.toStringAsFixed(0)}',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          _line(salesSpots, const Color(0xFFFF5C00)),
          _line(upsellSpots, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    color: color,
    barWidth: 3,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
  );

  String _fmtK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
