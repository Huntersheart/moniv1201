import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/services/ble_service.dart';

export '../../data/services/ble_service.dart' show BleStatus, CollarStatus;

/// GetX controller que expone el estado BLE a la UI.
///
/// - Se registra una sola vez en InitialBinding (singleton global).
/// - SessionLiveController lo usa para mandar comandos al collar.
/// - SessionLiveView lo usa para mostrar el indicador de conexion.
class BleController extends GetxController {
  final _ble = BleService.instance;

  // ── Estado observable ─────────────────────────────────
  final status        = BleStatus.disconnected.obs;
  final collarStatus  = Rxn<CollarStatus>();

  StreamSubscription<BleStatus>?    _statusSub;
  StreamSubscription<CollarStatus>? _collarSub;

  // ── Getters UI ────────────────────────────────────────
  bool get isConnected  => status.value == BleStatus.connected;
  bool get isScanning   => status.value == BleStatus.scanning;
  bool get isConnecting => status.value == BleStatus.connecting;

  String get statusLabel {
    switch (status.value) {
      case BleStatus.connected:    return 'Collar connected';
      case BleStatus.connecting:   return 'Connecting...';
      case BleStatus.scanning:     return 'Looking for collar...';
      case BleStatus.disconnected: return 'Collar not found';
    }
  }

  @override
  void onInit() {
    super.onInit();
    _statusSub = _ble.connectionStream.listen((s) {
      status.value = s;
      debugPrint('[BleController] status: $s');
    });
    _collarSub = _ble.statusStream.listen((s) {
      collarStatus.value = s;
    });
  }

  @override
  void onClose() {
    _statusSub?.cancel();
    _collarSub?.cancel();
    super.onClose();
  }

  // ── Control de sesion ─────────────────────────────────

  /// Llamar cuando empieza una sesion de collar.
  Future<void> startSession() async {
    await _ble.startAutoConnect();
  }

  /// Llamar cuando termina la sesion.
  Future<void> endSession() async {
    await _ble.stopAutoConnect();
  }

  // ── Comandos hapticos ─────────────────────────────────

  /// preset: 0=Calm, 1=Moderate, 2=Strong
  Future<void> sendHaptic({required int preset}) async {
    await _ble.sendHaptic(preset: preset);
  }

  Future<void> sendStorm({required int preset}) async {
    await _ble.sendStorm(preset: preset);
  }

  Future<void> sendOff() async {
    await _ble.sendOff();
  }
}
