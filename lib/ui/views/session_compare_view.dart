import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/session_model.dart';
import '../controllers/progress_report_controller.dart';

class SessionCompareView extends StatefulWidget {
  final List<SessionModel> sessions;

  const SessionCompareView({super.key, required this.sessions});

  @override
  State<SessionCompareView> createState() => _SessionCompareViewState();
}

class _SessionCompareViewState extends State<SessionCompareView> {
  late SessionModel _sessionA;
  late SessionModel _sessionB;

  static const _bg = Color(0xFF0B1120);
  static const _surface = Color(0xFF131F30);

  static const _colorA = Color(0xFF9575CD); // purple
  static const _colorB = AppColors.signaraGold; // cyan

  @override
  void initState() {
    super.initState();
    _sessionA = widget.sessions.first;
    _sessionB = widget.sessions.last;
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Compare Sessions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSelectors(),
            const SizedBox(height: 24),
            _buildTable(),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  // ── Session Selectors ──────────────────────────────────────────────────────

  Widget _buildSelectors() {
    return Row(
      children: [
        Expanded(
          child: _dropdown(
            label: 'Session A  (Before)',
            selected: _sessionA,
            color: _colorA,
            onChanged: (s) => setState(() => _sessionA = s!),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.compare_arrows, color: Colors.white30, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown(
            label: 'Session B  (After)',
            selected: _sessionB,
            color: _colorB,
            onChanged: (s) => setState(() => _sessionB = s!),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required SessionModel selected,
    required Color color,
    required ValueChanged<SessionModel?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: DropdownButton<SessionModel>(
            value: selected,
            isExpanded: true,
            dropdownColor: _surface,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: widget.sessions.map((s) {
              return DropdownMenuItem(
                value: s,
                child: Text(
                  '${_fmt(s.startTime)} · ${s.sessionTypeDisplay}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── Comparison Table ───────────────────────────────────────────────────────

  Widget _buildTable() {
    final rows = [
      _Row(metric: ProgressMetric.heartRate,   a: _sessionA, b: _sessionB),
      _Row(metric: ProgressMetric.temperature, a: _sessionA, b: _sessionB),
      _Row(metric: ProgressMetric.pain,        a: _sessionA, b: _sessionB),
      _Row(metric: ProgressMetric.limp,        a: _sessionA, b: _sessionB),
      _Row(metric: ProgressMetric.recovery,    a: _sessionA, b: _sessionB),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                    flex: 2,
                    child: Text('Metric',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                  child: Text(
                    _fmt(_sessionA.startTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _colorA,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    _fmt(_sessionB.startTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _colorB,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...rows.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(_Row r) {
    final aVal = r.metric.valueOf(r.a);
    final bVal = r.metric.valueOf(r.b);

    final aStr = aVal != null
        ? '${aVal.toStringAsFixed(r.metric == ProgressMetric.heartRate ? 0 : 1)} ${r.metric.unit}'
        : '—';
    final bStr = bVal != null
        ? '${bVal.toStringAsFixed(r.metric == ProgressMetric.heartRate ? 0 : 1)} ${r.metric.unit}'
        : '—';

    Widget deltaWidget = const SizedBox(width: 44);
    if (aVal != null && bVal != null) {
      final delta = bVal - aVal;
      final arrow = delta == 0
          ? '→'
          : delta > 0
              ? '↑'
              : '↓';

      Color color = Colors.white38;
      if (!r.metric.isNeutral && delta != 0) {
        final improved = r.metric.lowerIsBetter ? delta < 0 : delta > 0;
        color = improved ? AppColors.success : AppColors.error;
      }

      deltaWidget = SizedBox(
        width: 44,
        child: Text(
          '$arrow ${delta.abs().toStringAsFixed(1)}',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(r.metric.label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(
            child: Text(aStr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _colorA, fontSize: 13)),
          ),
          Expanded(
            child: Text(bStr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _colorB, fontSize: 13)),
          ),
          deltaWidget,
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white30, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Arrows show change from A → B.  '
              'Green = improvement · Red = worsening · Gray = neutral/no data.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final ProgressMetric metric;
  final SessionModel a;
  final SessionModel b;
  const _Row({required this.metric, required this.a, required this.b});
}
