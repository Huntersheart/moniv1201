import 'package:get/get.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

enum ProgressMetric {
  heartRate,
  temperature,
  pain,
  limp,
  recovery;

  String get label {
    switch (this) {
      case ProgressMetric.heartRate:    return 'Heart Rate';
      case ProgressMetric.temperature:  return 'Temperature';
      case ProgressMetric.pain:         return 'Pain';
      case ProgressMetric.limp:         return 'Limp';
      case ProgressMetric.recovery:     return 'Recovery';
    }
  }

  String get unit {
    switch (this) {
      case ProgressMetric.heartRate:   return 'bpm';
      case ProgressMetric.temperature: return '°C';
      case ProgressMetric.pain:        return '/2';
      case ProgressMetric.limp:        return '/1';
      case ProgressMetric.recovery:    return '/2';
    }
  }

  /// true = lower value means the dog is doing better
  bool get lowerIsBetter {
    switch (this) {
      case ProgressMetric.pain:
      case ProgressMetric.limp:
        return true;
      default:
        return false;
    }
  }

  /// HR and temp are context-dependent — we don't color them red/green
  bool get isNeutral {
    return this == ProgressMetric.heartRate ||
        this == ProgressMetric.temperature;
  }

  /// Extract the numeric value from a SessionModel for this metric.
  /// Returns null if no reading available.
  double? valueOf(SessionModel s) {
    switch (this) {
      case ProgressMetric.heartRate:
        return s.vestHeartRate > 0 ? s.vestHeartRate.toDouble() : null;
      case ProgressMetric.temperature:
        return s.vestTempBody > -900 ? s.vestTempBody : null;
      case ProgressMetric.pain:
        return s.vestPainLevel.toDouble();
      case ProgressMetric.limp:
        return s.limpLevel.toDouble();
      case ProgressMetric.recovery:
        return s.responseLevel.toDouble();
    }
  }
}

enum TrendDirection { improving, worsening, stable }

class ProgressReportController extends GetxController {
  final _repo = SessionRepository();

  // ── Arguments passed via Get.toNamed ──────────────────────────────────────
  final String dogId;
  final String dogName;

  ProgressReportController({required this.dogId, required this.dogName});

  // ── Reactive state ─────────────────────────────────────────────────────────
  final RxBool loading = true.obs;
  final RxList<SessionModel> allSessions = <SessionModel>[].obs;
  final RxInt selectedDays = 30.obs;
  final Rx<ProgressMetric> selectedMetric = ProgressMetric.heartRate.obs;

  // ── Derived ────────────────────────────────────────────────────────────────

  /// Sessions filtered to vest-only and within the selected day range,
  /// sorted oldest → newest for the chart.
  List<SessionModel> get filteredSessions {
    final cutoff = DateTime.now().subtract(Duration(days: selectedDays.value));
    return allSessions
        .where((s) =>
            s.isVestOrHipModule &&
            s.startTime.isAfter(cutoff))
        .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  TrendDirection get trend =>
      _calculateTrend(filteredSessions, selectedMetric.value);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    loadSessions();
  }

  Future<void> loadSessions() async {
    loading.value = true;
    try {
      // Fetch enough sessions to cover 90 days (our max range)
      final sessions = await _repo.getDogSessions(dogId, limit: 200);
      allSessions.assignAll(sessions);
    } catch (e) {
      allSessions.clear();
    } finally {
      loading.value = false;
    }
  }

  void setDays(int days) => selectedDays.value = days;
  void setMetric(ProgressMetric m) => selectedMetric.value = m;

  // ── Trend calculation ──────────────────────────────────────────────────────

  static TrendDirection _calculateTrend(
    List<SessionModel> sessions,
    ProgressMetric metric,
  ) {
    final values = sessions
        .map((s) => metric.valueOf(s))
        .whereType<double>()
        .toList();

    if (values.length < 3) return TrendDirection.stable;

    final mid = values.length ~/ 2;
    final firstAvg = values.take(mid).reduce((a, b) => a + b) / mid;
    final secondAvg =
        values.skip(mid).reduce((a, b) => a + b) / (values.length - mid);

    final delta = secondAvg - firstAvg;
    // 10% threshold for small-scale metrics, 5% for large-scale
    final threshold = firstAvg.abs() *
        (metric == ProgressMetric.heartRate ||
                metric == ProgressMetric.temperature
            ? 0.05
            : 0.15);

    if (delta.abs() <= threshold || threshold == 0) {
      return TrendDirection.stable;
    }

    if (metric.isNeutral) return TrendDirection.stable;

    return metric.lowerIsBetter
        ? (delta < 0 ? TrendDirection.improving : TrendDirection.worsening)
        : (delta > 0 ? TrendDirection.improving : TrendDirection.worsening);
  }
}
