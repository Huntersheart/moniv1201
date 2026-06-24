import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/services/vest_ble_service.dart';

export '../../data/services/vest_ble_service.dart'
    show VestBleStatus, VestStatus;

/// GetX controller que expone el estado BLE del vest a la UI.
///
/// - Se registra una sola vez en InitialBinding (singleton global).
/// - SessionLiveController lo usa para iniciar/detener la sesión del vest.
/// - SessionLiveView lo usa para mostrar el indicador de conexión y datos de sensores.
class VestBleController extends GetxController {
  final _ble = VestBleService.instance;

  // ── Estado observable ─────────────────────────────────────
  final status     = VestBleStatus.disconnected.obs;
  final vestStatus = Rxn<VestStatus>();

  // ── Datos de sensores accesibles directamente en la UI ────
  int    get heartRate   => vestStatus.value?.heartRate   ?? -1;
  int    get spo2        => vestStatus.value?.spo2        ?? -1;
  double get tempBody    => vestStatus.value?.tempBody    ?? -999;
  double get tempAmbient => vestStatus.value?.tempAmbient ?? -999;
  double get humidity    => vestStatus.value?.humidity    ?? -999;
  bool   get hasContact  => vestStatus.value?.hasContact  ?? false;

  StreamSubscription<VestBleStatus>? _statusSub;
  StreamSubscription<VestStatus>?    _vestSub;

  // ── Getters UI ────────────────────────────────────────────
  bool get isConnected  => status.value == VestBleStatus.connected;
  bool get isScanning   => status.value == VestBleStatus.scanning;
  bool get isConnecting => status.value == VestBleStatus.connecting;

  String get statusLabel {
    switch (status.value) {
      case VestBleStatus.connected:    return 'Vest connected';
      case VestBleStatus.connecting:   return 'Connecting vest...';
      case VestBleStatus.scanning:     return 'Looking for vest...';
      case VestBleStatus.disconnected: return 'Vest not found';
    }
  }

  @override
  void onInit() {
    super.onInit();
    _statusSub = _ble.connectionStream.listen((s) {
      status.value = s;
      debugPrint('[VestBleController] status: $s');
    });
    _vestSub = _ble.vestStream.listen((s) {
      vestStatus.value = s;
    });
  }

  @override
  void onClose() {
    _statusSub?.cancel();
    _vestSub?.cancel();
    super.onClose();
  }

  // ── Control de sesión ─────────────────────────────────────

  /// Llamar cuando empieza una sesión de vest.
  Future<void> startSession() async {
    await _ble.startAutoConnect();
  }

  /// Llamar cuando termina la sesión.
  Future<void> endSession() async {
    await _ble.stopAutoConnect();
  }
}
