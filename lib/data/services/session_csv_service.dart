import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session_model.dart';

/// Generates a CSV file from a list of sessions and triggers the system share sheet.
///
/// Columns (all modules):
///   Date, Time, Dog, Module, Duration, Notes
///
/// Collar-specific:
///   Movement (1-10), Comfort (1-10), Energy (1-10),
///   Haptic Preset, Intensity, Haptic On,
///   Limp, Response to Haptic, Calming Effect
///
/// Vest-specific:
///   Stability (1-5), Weight Bearing, Pain Signs
///
/// Hip-specific:
///   Mobility (1-5), Pain Signs, Sat/Stood Alone
class SessionCsvService {
  static const _vestWeightBearingLabels = ['Normal', 'Shifting', 'Avoiding'];
  static const _painSignsLabels = ['None', 'Mild', 'Moderate', 'Severe'];
  static const _responseLabels = ['No improvement', 'Slight improvement', 'Clear improvement'];
  static const _calmingLabels = ['', 'None', 'Minimal', 'Moderate', 'Good', 'Strong'];

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _date(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _time(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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

  /// Builds a CSV string from [sessions].
  static String buildCsv(List<SessionModel> sessions) {
    final buf = StringBuffer();

    // Header
    buf.writeln([
      'Date',
      'Time',
      'Dog',
      'Module',
      'Duration',
      // Collar
      'Movement (1-10)',
      'Comfort (1-10)',
      'Energy (1-10)',
      'Haptic Preset',
      'Intensity',
      'Haptic On',
      'Limp',
      'Response to Haptic',
      'Calming Effect',
      // Vest
      'Stability (1-5)',
      'Weight Bearing',
      'Pain Signs (Vest)',
      // Hip
      'Mobility (1-5)',
      'Pain Signs (Hip)',
      'Sat/Stood Alone',
      // Common
      'Notes',
    ].map(_esc).join(','));

    for (final s in sessions) {
      final isCollar = s.moduleType.toLowerCase() == 'collar';
      final isVest   = s.moduleType.toLowerCase() == 'vest';
      final isHip    = s.moduleType.toLowerCase() == 'hip';

      buf.writeln([
        _esc(_date(s.startTime)),
        _esc(_time(s.startTime)),
        _esc(s.dogName.isNotEmpty ? s.dogName : s.dogId),
        _esc(s.sessionTypeDisplay),
        _esc(_duration(s.durationSeconds)),
        // Collar fields — blank for vest/hip
        _esc(isCollar ? s.movementScore10.toString() : ''),
        _esc(isCollar ? s.comfortScore10.toString()  : ''),
        _esc(isCollar ? s.energyScore10.toString()   : ''),
        _esc(isCollar ? s.hapticPreset : ''),
        _esc(isCollar ? s.intensityScore10.toString() : ''),
        _esc(isCollar ? (s.hapticOn ? 'Yes' : 'No') : ''),
        _esc(isCollar ? s.limpDisplayLabel : ''),
        _esc(isCollar ? _label(_responseLabels, s.responseLevel) : ''),
        _esc(isCollar ? _label(_calmingLabels, s.calmingLevel.clamp(0, 5)) : ''),
        // Vest fields
        _esc(isVest ? s.vestStability.toString() : ''),
        _esc(isVest ? _label(_vestWeightBearingLabels, s.vestWeightBearing) : ''),
        _esc(isVest ? _label(_painSignsLabels, s.vestPainSigns) : ''),
        // Hip fields
        _esc(isHip ? s.hipMobility.toString() : ''),
        _esc(isHip ? _label(_painSignsLabels, s.hipPainSigns) : ''),
        _esc(isHip ? (s.hipSatStoodAlone == 1 ? 'Yes' : 'No') : ''),
        // Notes
        _esc(s.notes),
      ].join(','));
    }

    return buf.toString();
  }

  /// Writes CSV to a temp file and opens system share sheet.
  /// [dogName] is used in the filename.
  static Future<void> exportAndShare({
    required List<SessionModel> sessions,
    required String dogName,
  }) async {
    final csv = buildCsv(sessions);
    final dir = await getTemporaryDirectory();
    final safeName = dogName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final file = File('${dir.path}/signara_${safeName}_$stamp.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Signara sessions — $dogName',
      ),
    );
  }
}
