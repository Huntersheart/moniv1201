import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones locales para Signara.
///
/// Uso:
///   await NotificationService.instance.init();
///   await NotificationService.instance.showStormAlert(headline: '...');
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── IDs de notificación ───────────────────────────────────
  static const int _kStormId = 1001;

  // ── Canales Android ───────────────────────────────────────
  static const _kStormChannel = AndroidNotificationChannel(
    'signara_storm',
    'Storm Shield Alerts',
    description: 'Alerts when a pressure drop indicates an incoming storm.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Inicializar — llamar una sola vez en main() antes de runApp.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Crear canal en Android 8+
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_kStormChannel);

    _initialized = true;
    debugPrint('[NotificationService] Initialized ✓');
  }

  /// Solicitar permisos en iOS (llamar después de login).
  Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? true; // Android no necesita solicitud explícita
  }

  /// Muestra la notificación push de Storm Shield.
  ///
  /// [headline] — texto de la alerta NWS o mensaje personalizado.
  Future<void> showStormAlert({String headline = ''}) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'signara_storm',
      'Storm Shield Alerts',
      channelDescription: 'Signara storm pressure alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFB347),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = headline.isNotEmpty
        ? headline
        : 'Se detectó una caída drástica de presión atmosférica. Una tormenta se acerca en los próximos 30–45 minutos. Momento ideal para dar medicación preventiva si es necesario.';

    await _plugin.show(
      _kStormId,
      '🌩️ Alerta de Tormenta de Signara',
      body,
      details,
    );

    debugPrint('[NotificationService] Storm alert shown ✓');
  }

  /// Cancelar la notificación storm activa.
  Future<void> cancelStormAlert() async {
    await _plugin.cancel(_kStormId);
  }
}
