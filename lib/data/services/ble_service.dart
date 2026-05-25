import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUIDs deben coincidir exactamente con el firmware signara_collar_v1_ble.ino
const String _kServiceUuid  = 'a1230001-abcd-1234-5678-a12300000000';
const String _kHapticUuid   = 'a1230002-abcd-1234-5678-a12300000000';
const String _kStatusUuid   = 'a1230003-abcd-1234-5678-a12300000000';
const String _kDeviceName   = 'SIGNARA_COLLAR';

/// Comandos BLE (byte 0) — igual que firmware
const int _kCmdHaptic = 0x01;
const int _kCmdStorm  = 0x02;
const int _kCmdOff    = 0x03;

/// Presets (byte 1) — igual que firmware
const int _kPresetCalm     = 0x01;
const int _kPresetModerate = 0x02;
const int _kPresetStrong   = 0x03;

/// Estado de la conexion BLE
enum BleStatus { disconnected, scanning, connecting, connected }

/// Datos de status recibidos del collar (STATUS_UUID Notify cada 2s)
class CollarStatus {
  final int statusByte;
  final double pressure;
  final double tempBody;
  final double tempAmbient;
  final double humidity;
  final int ldtValue;
  final bool gpsFixed;

  const CollarStatus({
    required this.statusByte,
    required this.pressure,
    required this.tempBody,
    required this.tempAmbient,
    required this.humidity,
    required this.ldtValue,
    required this.gpsFixed,
  });

  bool get stormMode  => (statusByte & 0x80) != 0;
  bool get hasGpsFix  => gpsFixed;

  factory CollarStatus.fromJson(Map<String, dynamic> j) {
    return CollarStatus(
      statusByte:   (j['st']  as num?)?.toInt()    ?? 0,
      pressure:     (j['p']   as num?)?.toDouble() ?? 0,
      tempBody:     (j['tc']  as num?)?.toDouble() ?? 0,
      tempAmbient:  (j['ta']  as num?)?.toDouble() ?? 0,
      humidity:     (j['hum'] as num?)?.toDouble() ?? 0,
      ldtValue:     (j['ldt'] as num?)?.toInt()    ?? 0,
      gpsFixed:     ((j['gps'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}

/// Servicio BLE para el collar SIGNARA.
///
/// Uso:
///   final svc = BleService();
///   svc.statusStream.listen((s) => print(s.tempBody));
///   await svc.startAutoConnect();
///   await svc.sendHaptic(preset: 0);   // 0=Calm 1=Moderate 2=Strong
///   await svc.sendStorm(preset: 0);
///   await svc.sendOff();
///   await svc.disconnect();
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  // ── Estado ────────────────────────────────────────────────
  final _statusController   = StreamController<BleStatus>.broadcast();
  final _collarController   = StreamController<CollarStatus>.broadcast();

  Stream<BleStatus>    get connectionStream => _statusController.stream;
  Stream<CollarStatus> get statusStream     => _collarController.stream;

  BleStatus _bleStatus = BleStatus.disconnected;
  BleStatus get currentStatus => _bleStatus;
  bool get isConnected => _bleStatus == BleStatus.connected;

  BluetoothDevice?       _device;
  BluetoothCharacteristic? _hapticChar;
  BluetoothCharacteristic? _statusChar;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<bool>? _isScanSub;

  bool _autoConnectEnabled = false;

  // ── Auto-connect ─────────────────────────────────────────

  /// Inicia escaneo continuo hasta encontrar SIGNARA_COLLAR y conectar.
  /// Si se desconecta, reintenta automaticamente.
  Future<void> startAutoConnect() async {
    _autoConnectEnabled = true;
    await _startScan();
  }

  Future<void> stopAutoConnect() async {
    _autoConnectEnabled = false;
    await disconnect();
  }

  Future<void> _startScan() async {
    if (_bleStatus != BleStatus.disconnected) return;
    _setStatus(BleStatus.scanning);

    // Cancelar listeners anteriores para evitar acumulacion
    _scanSub?.cancel();
    _isScanSub?.cancel();

    // Escuchar resultados ANTES de iniciar el scan
    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) async {
        // Filtrar manualmente por nombre (withNames bloquea en iOS sin pareo previo)
        final match = results.where((r) => r.device.platformName == _kDeviceName).firstOrNull;
        if (match == null) return;
        debugPrint('[BLE] Collar encontrado: ${match.device.remoteId}');
        await FlutterBluePlus.stopScan();
        _scanSub?.cancel();
        _isScanSub?.cancel();
        await _connectToDevice(match.device);
      },
      onError: (Object e) {
        debugPrint('[BLE] scan stream error: $e');
        _setStatus(BleStatus.disconnected);
        _scheduleRetry();
      },
    );

    // Si el scan termina sin encontrar el collar
    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _bleStatus == BleStatus.scanning) {
        debugPrint('[BLE] Scan finalizado — collar no encontrado, reintentando...');
        _setStatus(BleStatus.disconnected);
        _scheduleRetry();
      }
    });

    try {
      // Sin withNames para que iOS pueda descubrir dispositivos no pareados
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('[BLE] startScan error: $e');
      _scanSub?.cancel();
      _isScanSub?.cancel();
      _setStatus(BleStatus.disconnected);
      _scheduleRetry();
      return;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _setStatus(BleStatus.connecting);
    _device = device;

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('[BLE] Desconectado del collar');
        _hapticChar = null;
        _statusChar = null;
        _notifySub?.cancel();
        _setStatus(BleStatus.disconnected);
        if (_autoConnectEnabled) _scheduleRetry();
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 8));
      await _discoverServices(device);
    } catch (e) {
      debugPrint('[BLE] connect error: $e');
      _setStatus(BleStatus.disconnected);
      _scheduleRetry();
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() != _kServiceUuid) continue;
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == _kHapticUuid) _hapticChar = char;
        if (uuid == _kStatusUuid) _statusChar = char;
      }
    }

    if (_hapticChar == null || _statusChar == null) {
      debugPrint('[BLE] Caracteristicas no encontradas — firmware correcto?');
      await device.disconnect();
      return;
    }

    // Suscribirse a notificaciones de status
    await _statusChar!.setNotifyValue(true);
    _notifySub?.cancel();
    _notifySub = _statusChar!.onValueReceived.listen((data) {
      try {
        final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        _collarController.add(CollarStatus.fromJson(json));
      } catch (e) {
        debugPrint('[BLE] status parse error: $e');
      }
    });

    _setStatus(BleStatus.connected);
    debugPrint('[BLE] Conectado a SIGNARA_COLLAR ✓');
  }

  void _scheduleRetry() {
    if (!_autoConnectEnabled) return;
    debugPrint('[BLE] Reintentando en 5s...');
    Future.delayed(const Duration(seconds: 5), () {
      if (_autoConnectEnabled && _bleStatus == BleStatus.disconnected) {
        _startScan();
      }
    });
  }

  // ── Comandos hapticos ────────────────────────────────────

  /// preset: 0=Calm, 1=Moderate, 2=Strong
  Future<void> sendHaptic({required int preset}) async {
    await _write([_kCmdHaptic, _presetByte(preset)]);
  }

  Future<void> sendStorm({required int preset}) async {
    await _write([_kCmdStorm, _presetByte(preset)]);
  }

  Future<void> sendOff() async {
    await _write([_kCmdOff, 0x00]);
  }

  Future<void> _write(List<int> bytes) async {
    if (_hapticChar == null) {
      debugPrint('[BLE] write ignorado — no conectado');
      return;
    }
    try {
      await _hapticChar!.write(bytes, withoutResponse: false);
      debugPrint('[BLE] write OK: $bytes');
    } catch (e) {
      debugPrint('[BLE] write error: $e');
    }
  }

  int _presetByte(int index) {
    switch (index) {
      case 0: return _kPresetCalm;
      case 1: return _kPresetModerate;
      case 2: return _kPresetStrong;
      default: return _kPresetCalm;
    }
  }

  // ── Disconnect ───────────────────────────────────────────

  Future<void> disconnect() async {
    _scanSub?.cancel();
    _isScanSub?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device    = null;
    _hapticChar = null;
    _statusChar = null;
    _setStatus(BleStatus.disconnected);
  }

  void _setStatus(BleStatus s) {
    _bleStatus = s;
    _statusController.add(s);
  }

  void dispose() {
    _statusController.close();
    _collarController.close();
  }
}
