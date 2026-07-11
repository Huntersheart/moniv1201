import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session_model.dart';

/// Generates a CSV file from a list of sessions and triggers the system share sheet.
///
/// Columns (all modules):
///   Date, Time, Dog, Module, Duration, Notes
///
/// Collar columns:
///   Limp, Response to Haptic, Calming Effect, Haptic Preset, Intensity,
///   Heart Rate (BPM), SpO2 (%), Body Temp (°C), LDT Events, GPS Fix
///
/// Vest columns:
///   Pain Level, Asymmetry (%), Load Side, Heart Rate (BPM), Body Temp (°C),
///   Resp Rate, Worn
///
/// Hip: placeholder (no BLE sensor fields in V1)
class SessionCsvService {
  // ── Label maps ─────────────────────────────────────────────────────────────
  static const _responseLabels = [
    'No improvement',
    'Slight improvement',
    'Clear improvement',
  ];
  static const _calmingLabels = [
    '',
    'None',
    'Minimal',
    'Moderate',
    'Good',
    'Strong',
  ];
  static const _vestLoadSideLabels = [
    'Symmetric',
    'Off-Right',
    'Off-Left',
  ];
  static const _vestPainLabels = [
    'No signs',
    'Possible',
    'Likely',
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _label(List<String> list, int index) {
    if (index < 0 || index >= list.length) return '';
    return list[index];
  }

  // ── CSV builder ────────────────────────────────────────────────────────────

  /// Builds a CSV string from [sessions].
  static String buildCsv(List<SessionModel> sessions) {
    final buf = StringBuffer();

    // ── Header ──────────────────────────────────────────────
    buf.writeln([
      // Common
      'Date',
      'Time',
      'Dog',
      'Module',
      'Duration',
      // Collar — manual
      'Limp',
      'Response to Haptic',
      'Calming Effect',
      'Haptic Preset',
      'Intensity (1-10)',
      'Haptic On',
      // Collar — sensor
      'Collar HR (BPM)',
      'Collar SpO2 (%)',
      'Collar Temp (°C)',
      'Collar LDT Events',
      'Collar GPS Fix',
      // Vest — sensor + auto-assessment
      'Vest Pain Level',
      'Vest Asymmetry (%)',
      'Vest Load Side',
      'Vest HR (BPM)',
      'Vest Temp (°C)',
      'Vest Resp Rate (/min)',
      'Vest Worn',
      // Common
      'Notes',
    ].map(_esc).join(','));

    // ── Rows ─────────────────────────────────────────────────
    for (final s in sessions) {
      final isCollar = s.moduleType.toLowerCase() == 'collar';
      final isVest   = s.moduleType.toLowerCase() == 'vest';

      buf.writeln([
        // Common
        _esc(_date(s.startTime)),
        _esc(_time(s.startTime)),
        _esc(s.dogName.isNotEmpty ? s.dogName : s.dogId),
        _esc(s.sessionTypeDisplay),
        _esc(_duration(s.durationSeconds)),
        // Collar — manual questionnaire
        _esc(isCollar ? s.limpDisplayLabel : ''),
        _esc(isCollar ? _label(_responseLabels, s.responseLevel) : ''),
        _esc(isCollar ? _label(_calmingLabels, s.calmingLevel.clamp(0, 5)) : ''),
        _esc(isCollar ? s.hapticPreset : ''),
        _esc(isCollar ? s.intensityScore10.toString() : ''),
        _esc(isCollar ? (s.hapticOn ? 'Yes' : 'No') : ''),
        // Collar — sensor data
        _esc(isCollar && s.collarHeartRate > 0 ? s.collarHeartRate.toString() : ''),
        _esc(isCollar && s.collarSpo2 > 0      ? s.collarSpo2.toString() : ''),
        _esc(isCollar && s.collarTempBody > 0  ? s.collarTempBody.toStringAsFixed(1) : ''),
        _esc(isCollar ? s.collarLdt.toString() : ''),
        _esc(isCollar ? (s.collarGpsFix ? 'Yes' : 'No') : ''),
        // Vest — auto-assessment + sensor
        _esc(isVest ? _label(_vestPainLabels,    s.vestPainLevel) : ''),
        _esc(isVest ? s.vestAsymmetryPct.toString() : ''),
        _esc(isVest ? _label(_vestLoadSideLabels, s.vestLoadSide) : ''),
        _esc(isVest && s.vestHeartRate > 0    ? s.vestHeartRate.toString() : ''),
        _esc(isVest && s.vestTempBody > -900  ? s.vestTempBody.toStringAsFixed(1) : ''),
        _esc(isVest && s.vestRespRate > 0     ? s.vestRespRate.toString() : ''),
        _esc(isVest ? (s.vestWorn == 1 ? 'Yes' : 'No') : ''),
        // Notes
        _esc(s.notes),
      ].join(','));
    }

    return buf.toString();
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Writes CSV to a temp file and opens system share sheet.
  static Future<void> exportAndShare({
    required List<SessionModel> sessions,
    required String dogName,
  }) async {
    final csv      = buildCsv(sessions);
    final dir      = await getTemporaryDirectory();
    final safeName = dogName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final now      = DateTime.now();
    final stamp    = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final file     = File('${dir.path}/signara_${safeName}_$stamp.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Signara sessions — $dogName',
      ),
    );
  }
}
