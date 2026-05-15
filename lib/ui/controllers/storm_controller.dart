import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';

import '../../data/services/nws_service.dart';
import '../../data/services/ble_service.dart';

/// Claves en SharedPreferences
const String _kPrefLastSentZone = 'storm_last_sent_zone';
const String _kPrefLastSentAt   = 'storm_last_sent_at';

/// Cooldown: no mandar CMD_STORM de nuevo si ya se mando en las ultimas 6h
/// para la misma zona (evita spam durante una tormenta larga)
const Duration _kCooldown = Duration(hours: 6);

/// StormController — detecta tormentas via NWS y manda CMD_STORM al collar.
///
/// Funciona en dos modos:
///   1. Foreground: Timer cada 15 min (mientras la app esta activa)
///   2. Background: background_fetch callback (iOS/Android, ~15-30 min)
///
/// El collar maneja el storm mode de forma autonoma una vez recibe el comando:
///   vibra en patron Calm cada 8s durante 30 min sin necesitar BLE activo.
class StormController extends GetxController {
  // ── Estado observable ──────────────────────────────────────
  final stormAlertActive   = false.obs;
  final lastAlertHeadline  = ''.obs;
  final lastCheckTime      = Rxn<DateTime>();
  final commandSentCount   = 0.obs;

  // ── Internos ───────────────────────────────────────────────
  Timer? _foregroundTimer;
  bool _initialized = false;

  @override
  void onInit() {
    super.onInit();
    _initBackgroundFetch();
    _startForegroundTimer();
    // Primera consulta inmediata al iniciar
    Future.delayed(const Duration(seconds: 3), checkAndAlert);
  }

  @override
  void onClose() {
    _foregroundTimer?.cancel();
    super.onClose();
  }

  // ── Foreground Timer ───────────────────────────────────────

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => checkAndAlert(),
    );
    debugPrint('[Storm] Foreground timer iniciado (cada 15 min)');
  }

  // ── Background Fetch (iOS + Android) ──────────────────────

  Future<void> _initBackgroundFetch() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,         // minutos — iOS puede ignorar y usar ~30
          stopOnTerminate: false,           // continua aunque el usuario cierre la app
          enableHeadless: true,             // Android headless mode
          requiresBatteryNotLow: false,     // queremos que funcione aunque la bateria este baja
          requiresCharging: false,
          requiresStorageNotLow: false,
          startOnBoot: true,                // Android: inicia automaticamente al reiniciar
        ),
        _onBackgroundFetch,
        _onBackgroundFetchTimeout,
      );

      // El registro del headless callback se hace en main.dart antes de runApp
      // para que funcione incluso cuando la app esta completamente cerrada.
      debugPrint('[Storm] background_fetch configurado ✓');
    } catch (e) {
      debugPrint('[Storm] background_fetch init error: $e');
    }
  }

  Future<void> _onBackgroundFetch(String taskId) async {
    debugPrint('[Storm] Background fetch task: $taskId');
    await checkAndAlert();
    BackgroundFetch.finish(taskId);
  }

  Future<void> _onBackgroundFetchTimeout(String taskId) async {
    debugPrint('[Storm] Background fetch TIMEOUT: $taskId');
    BackgroundFetch.finish(taskId);
  }

  // ── Logica principal ───────────────────────────────────────

  /// Consulta NWS y manda CMD_STORM si detecta alerta nueva.
  /// Seguro llamar repetidamente — tiene anti-spam por cooldown.
  Future<void> checkAndAlert() async {
    debugPrint('[Storm] Consultando NWS...');
    lastCheckTime.value = DateTime.now();

    try {
      final alert = await NwsService.instance.checkForStorm();

      if (alert == null) {
        stormAlertActive.value = false;
        debugPrint('[Storm] Sin alertas activas');
        return;
      }

      stormAlertActive.value = true;
      lastAlertHeadline.value = alert.headline;
      debugPrint('[Storm] ALERTA: ${alert.event} en ${alert.zone}');

      // Anti-spam: verificar cooldown antes de mandar BLE
      final shouldSend = await _shouldSendCommand(alert.zone);
      if (!shouldSend) {
        debugPrint('[Storm] Cooldown activo — comando omitido');
        return;
      }

      await _sendStormCommand(alert.zone);
    } catch (e) {
      debugPrint('[Storm] checkAndAlert error: $e');
    }
  }

  Future<bool> _shouldSendCommand(String zone) async {
    final prefs = await SharedPreferences.getInstance();
    final lastZone = prefs.getString(_kPrefLastSentZone);
    final lastSentMs = prefs.getInt(_kPrefLastSentAt) ?? 0;
    final lastSent = DateTime.fromMillisecondsSinceEpoch(lastSentMs);
    final elapsed = DateTime.now().difference(lastSent);

    // Mandar si: zona diferente O ya paso el cooldown
    if (lastZone == zone && elapsed < _kCooldown) {
      debugPrint('[Storm] Cooldown: ${elapsed.inMinutes} min desde ultimo envio en $zone');
      return false;
    }
    return true;
  }

  Future<void> _sendStormCommand(String zone) async {
    final ble = BleService.instance;

    if (!ble.isConnected) {
      debugPrint('[Storm] BLE no conectado — iniciando auto-connect');
      await ble.startAutoConnect();
      // Esperar hasta 12s a que se conecte
      for (int i = 0; i < 12; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (ble.isConnected) break;
      }
    }

    if (!ble.isConnected) {
      debugPrint('[Storm] BLE no disponible despues de espera — no se puede enviar');
      return;
    }

    // Mandar CMD_STORM + PRESET_CALM → collar vibra solo durante 30 min
    await ble.sendStorm(preset: 0); // 0 = Calm
    debugPrint('[Storm] CMD_STORM enviado al collar ✓');

    // Guardar timestamp para anti-spam
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLastSentZone, zone);
    await prefs.setInt(_kPrefLastSentAt, DateTime.now().millisecondsSinceEpoch);

    commandSentCount.value++;
  }

  // ── Utilidades publicas ────────────────────────────────────

  /// Forzar verificacion manual (para boton en UI si se necesita)
  Future<void> forceCheck() => checkAndAlert();

  /// Limpiar historial de alertas (para testing)
  Future<void> resetHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefLastSentZone);
    await prefs.remove(_kPrefLastSentAt);
    await NwsService.instance.clearZoneCache();
    stormAlertActive.value = false;
    lastAlertHeadline.value = '';
    commandSentCount.value = 0;
    debugPrint('[Storm] Historial reseteado');
  }
}

// ── Headless callback (app completamente cerrada) ─────────────
// Debe ser top-level (no metodo de clase) para background_fetch
@pragma('vm:entry-point')
void stormHeadlessCallback(HeadlessTask task) async {
  final taskId = task.taskId;
  final isTimeout = task.timeout;

  if (isTimeout) {
    debugPrint('[Storm Headless] TIMEOUT: $taskId');
    BackgroundFetch.finish(taskId);
    return;
  }

  debugPrint('[Storm Headless] Tarea: $taskId');

  try {
    final alert = await NwsService.instance.checkForStorm();
    if (alert != null) {
      debugPrint('[Storm Headless] Alerta detectada: ${alert.event}');
      // En modo headless no tenemos UI ni GetX — mandar BLE directamente
      final ble = BleService.instance;
      await ble.startAutoConnect();

      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (ble.isConnected) break;
      }

      if (ble.isConnected) {
        await ble.sendStorm(preset: 0);
        debugPrint('[Storm Headless] CMD_STORM enviado ✓');
      }
    }
  } catch (e) {
    debugPrint('[Storm Headless] error: $e');
  }

  BackgroundFetch.finish(taskId);
}
