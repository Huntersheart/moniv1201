import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUIDs deben coincidir exactamente con SignaraVest.ino
const String _kServiceUuid = 'a1240001-abcd-1234-5678-a12400000000';
const String _kCmdUuid     = 'a1240002-abcd-1234-5678-a12400000000';
const String _kStatusUuid  = 'a1240003-abcd-1234-5678-a12400000000';
const String _kDeviceName  = 'SIGNARA_VEST';

const int _kCmdPing = 0x01;

/// Datos del vest recibidos via BLE (STATUS_UUID Notify cada 2s)
///
/// JSON del firmware:
/// {"hr":%d,"spo2":%d,"hrv":%d,"spo2v":%d,
///  "tc":%.2f,"ta":%.2f,"hum":%.2f,
///  "ax":%.3f,"ay":%.3f,"az":%.3f,
///  "gx":%.3f,"gy":%.3f,"gz":%.3f,
///  "fsl":%d,"fsr":%d}
class VestStatus {
  final int    heartRate;    // BPM  (-1 = sin contacto)
  final int    spo2;         // %    (-1 = sin contacto)
  final bool   hrValid;
  final bool   spo2Valid;
  final double tempBody;     // TMP117 °C
  final double tempAmbient;  // BME280 °C
  final double humidity;     // %
  // LSM6DSOX
  final double ax, ay, az;   // m/s²
  final double gx, gy, gz;   // rad/s
  // ADS1115 + FSR 406 — escápula izquierda / derecha
  // Rango raw: 0–32767 (ADS1115 16-bit con GAIN_ONE)
  // Sin contacto: ~2900 (ruido de entrada flotante)
  final int fsrLeft;
  final int fsrRight;

  const VestStatus({
    required this.heartRate,
    required this.spo2,
    required this.hrValid,
    required this.spo2Valid,
    required this.tempBody,
    required this.tempAmbient,
    required this.humidity,
    required this.ax, required this.ay, required this.az,
    required this.gx, required this.gy, required this.gz,
    required this.fsrLeft,
    required this.fsrRight,
  });

  bool get hasContact => heartRate != -1;

  /// Asimetría de carga entre escápulas (0.0 = simétrico, 1.0 = todo en un lado)
  /// Útil para detectar compensación postural / cojera de Hunter.
  double get scapularAsymmetry {
    final total = fsrLeft + fsrRight;
    if (total == 0) return 0;
    final diff = (fsrLeft - fsrRight).abs();
    return diff / total;
  }

  factory VestStatus.fromJson(Map<String, dynamic> j) {
    return VestStatus(
      heartRate:    (j['hr']    as num?)?.toInt()    ?? -1,
      spo2:         (j['spo2']  as num?)?.toInt()    ?? -1,
      hrValid:      ((j['hrv']  as num?)?.toInt()    ?? 0) == 1,
      spo2Valid:    ((j['spo2v'] as num?)?.toInt()   ?? 0) == 1,
      tempBody:     (j['tc']    as num?)?.toDouble() ?? -999,
      tempAmbient:  (j['ta']    as num?)?.toDouble() ?? -999,
      humidity:     (j['hum']   as num?)?.toDouble() ?? -999,
      ax: (j['ax'] as num?)?.toDouble() ?? 0,
      ay: (j['ay'] as num?)?.toDouble() ?? 0,
      az: (j['az'] as num?)?.toDouble() ?? 0,
      gx: (j['gx'] as num?)?.toDouble() ?? 0,
      gy: (j['gy'] as num?)?.toDouble() ?? 0,
      gz: (j['gz'] as num?)?.toDouble() ?? 0,
      fsrLeft:  (j['fsl'] as num?)?.toInt() ?? 0,
      fsrRight: (j['fsr'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Estado de la conexión BLE del vest
enum VestBleStatus { disconnected, scanning, connecting, connected }

/// Servicio BLE para el Support Vest SIGNARA.
class VestBleService {
  VestBleService._();
  static final VestBleService instance = VestBleService._();

  // ── Streams ───────────────────────────────────────────────
  final _statusCtrl = StreamController<VestBleStatus>.broadcast();
  final _vestCtrl   = StreamController<VestStatus>.broadcast();

  Stream<VestBleStatus> get connectionStream => _statusCtrl.stream;
  Stream<VestStatus>    get vestStream       => _vestCtrl.stream;

  VestBleStatus _bleStatus = VestBleStatus.disconnected;
  VestBleStatus get currentStatus => _bleStatus;
  bool get isConnected => _bleStatus == VestBleStatus.connected;

  BluetoothDevice?         _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _statusChar;

  StreamSubscription<List<ScanResult>>?         _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>?                _notifySub;
  StreamSubscription<bool>?                     _isScanSub;

  bool _autoConnectEnabled = false;

  // ── Auto-connect ─────────────────────────────────────────

  Future<void> startAutoConnect() async {
    _autoConnectEnabled = true;
    await _startScan();
  }

  Future<void> stopAutoConnect() async {
    _autoConnectEnabled = false;
    await disconnect();
  }

  Future<void> _startScan() async {
    if (_bleStatus != VestBleStatus.disconnected) return;
    _setStatus(VestBleStatus.scanning);

    _scanSub?.cancel();
    _isScanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) async {
        final match = results
            .where((r) => r.device.platformName == _kDeviceName)
            .firstOrNull;
        if (match == null) return;
        debugPrint('[VestBLE] Vest encontrado: ${match.device.remoteId}');
        await FlutterBluePlus.stopScan();
        _scanSub?.cancel();
        _isScanSub?.cancel();
        await _connectToDevice(match.device);
      },
      onError: (Object e) {
        debugPrint('[VestBLE] scan error: $e');
        _setStatus(VestBleStatus.disconnected);
        _scheduleRetry();
      },
    );

    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _bleStatus == VestBleStatus.scanning) {
        debugPrint('[VestBLE] Scan finalizado — vest no encontrado, reintentando...');
        _setStatus(VestBleStatus.disconnected);
        _scheduleRetry();
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[VestBLE] startScan error: $e');
      _scanSub?.cancel();
      _isScanSub?.cancel();
      _setStatus(VestBleStatus.disconnected);
      _scheduleRetry();
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _setStatus(VestBleStatus.connecting);
    _device = device;

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('[VestBLE] Desconectado del vest');
        _cmdChar    = null;
        _statusChar = null;
        _notifySub?.cancel();
        _setStatus(VestBleStatus.disconnected);
        if (_autoConnectEnabled) _scheduleRetry();
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 8));
      await _discoverServices(device);
    } catch (e) {
      debugPrint('[VestBLE] connect error: $e');
      _setStatus(VestBleStatus.disconnected);
      _scheduleRetry();
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() != _kServiceUuid) continue;
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == _kCmdUuid)    _cmdChar    = char;
        if (uuid == _kStatusUuid) _statusChar = char;
      }
    }

    if (_cmdChar == null || _statusChar == null) {
      debugPrint('[VestBLE] Caracteristicas no encontradas — firmware correcto?');
      await device.disconnect();
      return;
    }

    await _statusChar!.setNotifyValue(true);
    _notifySub?.cancel();
    _notifySub = _statusChar!.onValueReceived.listen((data) {
      try {
        final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        _vestCtrl.add(VestStatus.fromJson(json));
      } catch (e) {
        debugPrint('[VestBLE] status parse error: $e');
      }
    });

    _setStatus(VestBleStatus.connected);
    debugPrint('[VestBLE] Conectado a SIGNARA_VEST ✓');
  }

  void _scheduleRetry() {
    if (!_autoConnectEnabled) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_autoConnectEnabled && _bleStatus == VestBleStatus.disconnected) {
        _startScan();
      }
    });
  }

  /// Envía CMD_PING al vest (confirma conexión)
  Future<void> sendPing() async {
    if (_cmdChar == null) return;
    try {
      await _cmdChar!.write([_kCmdPing], withoutResponse: false);
    } catch (e) {
      debugPrint('[VestBLE] ping error: $e');
    }
  }

  Future<void> disconnect() async {
    _scanSub?.cancel();
    _isScanSub?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    try { await _device?.disconnect(); } catch (_) {}
    _device     = null;
    _cmdChar    = null;
    _statusChar = null;
    _setStatus(VestBleStatus.disconnected);
  }

  void _setStatus(VestBleStatus s) {
    _bleStatus = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    _statusCtrl.close();
    _vestCtrl.close();
  }
}
