import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../controllers/progress_report_controller.dart';
import 'session_compare_view.dart';

class ProgressReportView extends GetView<ProgressReportController> {
  const ProgressReportView({super.key});

  static const _bg = Color(0xFF0B1120);
  static const _surface = Color(0xFF131F30);
  static const _surface2 = Color(0xFF1A2840);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Obx(() => Text(
              '${controller.dogName} · Progress',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            )),
        actions: [
          Obx(() {
            final sessions = controller.filteredSessions;
            return TextButton.icon(
              onPressed: sessions.length >= 2
                  ? () => Get.to(
                        () => SessionCompareView(sessions: sessions),
                      )
                  : null,
              icon: Icon(
                Icons.compare_arrows,
                color: sessions.length >= 2
                    ? AppColors.signaraGold
                    : Colors.white24,
                size: 20,
              ),
              label: Text(
                'Compare',
                style: TextStyle(
                  color: sessions.length >= 2
                      ? AppColors.signaraGold
                      : Colors.white24,
                  fontSize: 13,
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.signaraGold),
          );
        }
        final sessions = controller.filteredSessions;
        if (sessions.isEmpty) return _buildEmpty();
        return RefreshIndicator(
          onRefresh: controller.loadSessions,
          color: AppColors.signaraGold,
          child: _buildContent(sessions),
        );
      }),
    );
  }

  Widget _buildContent(List<SessionModel> sessions) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDaySelector(),
          const SizedBox(height: 16),
          _buildTrendBanner(sessions),
          const SizedBox(height: 16),
          _buildMetricSelector(),
          const SizedBox(height: 12),
          _buildChart(sessions),
          const SizedBox(height: 16),
          _buildQuickStats(sessions),
        ],
      ),
    );
  }

  // ── Day Selector ───────────────────────────────────────────────────────────

  Widget _buildDaySelector() {
    return Obx(() => Row(
          children: [7, 30, 90].map((days) {
            final selected = days == controller.selectedDays.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => controller.setDays(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.signaraGold.withOpacity(0.15)
                        : _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.signaraGold
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    '$days days',
                    style: TextStyle(
                      color: selected
                          ? AppColors.signaraGold
                          : Colors.white54,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ));
  }

  // ── Trend Banner ───────────────────────────────────────────────────────────

  Widget _buildTrendBanner(List<SessionModel> sessions) {
    return Obx(() {
      final trend = controller.trend;
      final metric = controller.selectedMetric.value;

      final (color, icon, label, sub) = switch (trend) {
        TrendDirection.improving => (
            AppColors.success,
            Icons.trending_up_rounded,
            'Improving',
            'Keep it up!'
          ),
        TrendDirection.worsening => (
            AppColors.error,
            Icons.trending_down_rounded,
            'Needs attention',
            'Review recent sessions'
          ),
        TrendDirection.stable => (
            const Color(0xFFFFB300),
            Icons.trending_flat_rounded,
            'Stable',
            'No significant change'
          ),
      };

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${metric.label} · ${controller.selectedDays.value} days · ${sessions.length} sessions',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(sub,
                style: TextStyle(
                    color: color.withOpacity(0.7), fontSize: 12)),
          ],
        ),
      );
    });
  }

  // ── Metric Selector ────────────────────────────────────────────────────────

  Widget _buildMetricSelector() {
    return Obx(() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ProgressMetric.values.map((m) {
              final selected = m == controller.selectedMetric.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.setMetric(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.signaraGold.withOpacity(0.12)
                          : _surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.signaraGold
                            : Colors.white10,
                      ),
                    ),
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.signaraGold
                            : Colors.white60,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ));
  }

  // ── Line Chart ─────────────────────────────────────────────────────────────

  Widget _buildChart(List<SessionModel> sessions) {
    return Obx(() {
      final metric = controller.selectedMetric.value;
      final spots = <FlSpot>[];
      for (int i = 0; i < sessions.length; i++) {
        final val = metric.valueOf(sessions[i]);
        if (val != null) spots.add(FlSpot(i.toDouble(), val));
      }

      if (spots.isEmpty) {
        return Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sensors_off, color: Colors.white24, size: 36),
              const SizedBox(height: 8),
              Text(
                'No ${metric.label} data in this range',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        );
      }

      final values = spots.map((s) => s.y).toList();
      final rawMin = values.reduce((a, b) => a < b ? a : b);
      final rawMax = values.reduce((a, b) => a > b ? a : b);
      final padding = (rawMax - rawMin) * 0.2 + 0.5;
      final minY = (rawMin - padding).clamp(0, double.infinity);
      final maxY = rawMax + padding;

      return Container(
        height: 240,
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (val, _) => Text(
                    val.toStringAsFixed(
                        metric == ProgressMetric.heartRate ? 0 : 1),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: sessions.length > 8
                      ? (sessions.length / 5).roundToDouble()
                      : 1,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= sessions.length) {
                      return const SizedBox.shrink();
                    }
                    final d = sessions[idx].startTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${d.month}/${d.day}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.signaraGold,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3.5,
                    color: AppColors.signaraGold,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.signaraGold.withOpacity(0.25),
                      AppColors.signaraGold.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF0B1120),
                getTooltipItems: (touchedSpots) =>
                    touchedSpots.map((s) {
                  final idx = s.x.toInt();
                  final session =
                      idx < sessions.length ? sessions[idx] : null;
                  final dateStr = session != null
                      ? '${session.startTime.month}/${session.startTime.day}'
                      : '';
                  return LineTooltipItem(
                    '$dateStr\n${s.y.toStringAsFixed(metric == ProgressMetric.heartRate ? 0 : 1)} ${metric.unit}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── Quick Stats ────────────────────────────────────────────────────────────

  Widget _buildQuickStats(List<SessionModel> sessions) {
    return Obx(() {
      final metric = controller.selectedMetric.value;
      final values = sessions
          .map((s) => metric.valueOf(s))
          .whereType<double>()
          .toList();
      if (values.isEmpty) return const SizedBox.shrink();

      final avg = values.reduce((a, b) => a + b) / values.length;
      final max = values.reduce((a, b) => a > b ? a : b);
      final min = values.reduce((a, b) => a < b ? a : b);

      return Row(
        children: [
          _statCard('Average', avg, metric.unit),
          const SizedBox(width: 10),
          _statCard('Best', metric.lowerIsBetter ? min : max, metric.unit,
              color: AppColors.success),
          const SizedBox(width: 10),
          _statCard('Worst', metric.lowerIsBetter ? max : min, metric.unit,
              color: AppColors.error),
        ],
      );
    });
  }

  Widget _statCard(String label, double value, String unit,
      {Color? color}) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_outlined,
              color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('No vest sessions found',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Complete at least one vest session\nto see ${controller.dogName}\'s progress.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: controller.loadSessions,
            icon: const Icon(Icons.refresh,
                color: AppColors.signaraGold),
            label: const Text('Refresh',
                style: TextStyle(color: AppColors.signaraGold)),
          ),
        ],
      ),
    );
  }
}
