import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipos de alerta de tormenta que activamos
const List<String> _kStormEventTypes = [
  'Thunderstorm Warning',
  'Severe Thunderstorm Warning',
  'Thunderstorm Watch',
  'Severe Thunderstorm Watch',
  'Tornado Warning',
  'Tornado Watch',
  'Special Weather Statement',
  'Flash Flood Warning', // inundaciones = presion barometrica baja = perros ansiosos
];

class NwsStormAlert {
  final String event;
  final String headline;
  final String zone;
  final DateTime onset;
  final DateTime expires;

  const NwsStormAlert({
    required this.event,
    required this.headline,
    required this.zone,
    required this.onset,
    required this.expires,
  });

  bool get isActive => DateTime.now().isBefore(expires);

  @override
  String toString() => 'NwsStormAlert($event @ $zone until $expires)';
}

/// Servicio NWS — consulta alertas meteorologicas sin API key.
///
/// Flujo:
///   1. Obtiene lat/lng del dispositivo (geolocator)
///   2. GET api.weather.gov/points/{lat},{lng} → extrae zone ID
///   3. GET api.weather.gov/alerts/active?zone={zoneId} → filtra tormentas
///
/// Sin servidor. Sin costo. Solo requiere permiso de ubicacion.
class NwsService {
  NwsService._();
  static final NwsService instance = NwsService._();

  static const String _kPrefZone = 'nws_last_zone';
  static const Duration _kHttpTimeout = Duration(seconds: 15);

  // ── Ubicacion ─────────────────────────────────────────────

  /// Obtiene la posicion actual. Retorna null si el permiso fue denegado.
  Future<Position?> _getPosition() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint('[NWS] Permiso de ubicacion denegado');
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // bajo consumo de bateria
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[NWS] getPosition error: $e');
      return null;
    }
  }

  // ── Zone ID ───────────────────────────────────────────────

  /// Resuelve el NWS county zone ID para una coordenada.
  /// Ej: lat=40.71, lng=-74.00 → "NJZ006"
  Future<String?> _resolveZone(double lat, double lng) async {
    // Usar cache — el zone raramente cambia
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kPrefZone);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[NWS] Zone desde cache: $cached');
      return cached;
    }

    final url = Uri.parse(
      'https://api.weather.gov/points/${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}',
    );
    try {
      final resp = await http.get(url, headers: {
        'User-Agent': 'SignaraApp/1.0 (monica@huntershearthealth.com)',
        'Accept': 'application/geo+json',
      }).timeout(_kHttpTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[NWS] points error ${resp.statusCode}');
        return null;
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final props = json['properties'] as Map<String, dynamic>?;
      // forecastZone es una URL: .../zones/forecast/NJZ006
      final zoneUrl = props?['forecastZone'] as String?;
      final zoneId = zoneUrl?.split('/').last;

      if (zoneId != null && zoneId.isNotEmpty) {
        await prefs.setString(_kPrefZone, zoneId);
        debugPrint('[NWS] Zone resuelta: $zoneId');
        return zoneId;
      }
    } catch (e) {
      debugPrint('[NWS] resolveZone error: $e');
    }
    return null;
  }

  // ── Alertas ───────────────────────────────────────────────

  /// Consulta alertas activas para el zone ID.
  /// Retorna lista de alertas de tormenta relevantes.
  Future<List<NwsStormAlert>> fetchAlertsForZone(String zoneId) async {
    final url = Uri.parse(
      'https://api.weather.gov/alerts/active?zone=$zoneId&status=actual&message_type=alert',
    );
    try {
      final resp = await http.get(url, headers: {
        'User-Agent': 'SignaraApp/1.0 (monica@huntershearthealth.com)',
        'Accept': 'application/geo+json',
      }).timeout(_kHttpTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[NWS] alerts error ${resp.statusCode}');
        return [];
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = (json['features'] as List<dynamic>?) ?? [];

      final alerts = <NwsStormAlert>[];
      for (final f in features) {
        final props = (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>?;
        if (props == null) continue;

        final event = props['event'] as String? ?? '';
        if (!_kStormEventTypes.any((t) => event.contains(t.split(' ').first))) {
          // Filtro rapido: debe contener al menos una palabra clave
          final lc = event.toLowerCase();
          final match = lc.contains('thunder') ||
              lc.contains('tornado') ||
              lc.contains('storm') ||
              lc.contains('flood');
          if (!match) continue;
        }

        final headline = props['headline'] as String? ?? event;
        final expiresStr = props['expires'] as String?;
        final onsetStr = props['onset'] as String?;

        DateTime expires;
        DateTime onset;
        try {
          expires = expiresStr != null
              ? DateTime.parse(expiresStr)
              : DateTime.now().add(const Duration(hours: 2));
          onset = onsetStr != null
              ? DateTime.parse(onsetStr)
              : DateTime.now();
        } catch (_) {
          expires = DateTime.now().add(const Duration(hours: 2));
          onset = DateTime.now();
        }

        alerts.add(NwsStormAlert(
          event: event,
          headline: headline,
          zone: zoneId,
          onset: onset,
          expires: expires,
        ));
      }

      debugPrint('[NWS] ${alerts.length} alertas de tormenta en $zoneId');
      return alerts;
    } catch (e) {
      debugPrint('[NWS] fetchAlerts error: $e');
      return [];
    }
  }

  /// Metodo principal: detecta si hay tormenta en la ubicacion actual.
  /// Retorna la primera alerta activa, o null si no hay ninguna.
  Future<NwsStormAlert?> checkForStorm() async {
    final pos = await _getPosition();
    if (pos == null) return null;

    final zoneId = await _resolveZone(pos.latitude, pos.longitude);
    if (zoneId == null) return null;

    final alerts = await fetchAlertsForZone(zoneId);
    return alerts.where((a) => a.isActive).firstOrNull;
  }

  /// Invalida el cache del zone ID (llamar si el usuario cambia de ciudad).
  Future<void> clearZoneCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefZone);
  }
}
