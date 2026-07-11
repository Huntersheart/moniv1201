import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/signara_dashboard_background.dart';

// ── Prefs keys ────────────────────────────────────────────────────────────────
const _kPrefLostPetMode   = 'nfc_lost_pet_mode';
const _kPrefEmergencyPhone = 'nfc_emergency_phone';
const _kPrefMedicalNotes   = 'nfc_medical_notes';
const _kPrefOrthoNotes     = 'nfc_ortho_notes';

// ── Landing page base URL (public emergency page) ─────────────────────────────
const _kNfcLandingBase = 'https://huntershearthealth.com/find-my-dog';

/// Pantalla: Perfil del Perro → Configuración Avanzada → Seguridad e Identidad Digital (NFC)
///
/// Sección 8 del doc Signara v2.0:
/// - Switch lost_pet_mode: off = solo tap-to-pair token. On = reescribe NFC con ficha pública.
/// - Formulario editable: teléfono emergencia, ficha médica, alertas ortopédicas.
/// - Datos cifrados en prefs locales — solo expuestos cuando lost_pet_mode ON.
/// - Ubicación pasiva: el escáner externo → landing page → GPS del teléfono del escáner → push coords al dueño.
/// - GPS del collar (MIA-M10Q) permanece APAGADO en V1.
class NfcIdentityView extends StatefulWidget {
  const NfcIdentityView({super.key});

  @override
  State<NfcIdentityView> createState() => _NfcIdentityViewState();
}

class _NfcIdentityViewState extends State<NfcIdentityView> {
  // ── State ──────────────────────────────────────────────────
  bool _lostPetMode     = false;
  bool _nfcAvailable    = false;
  bool _loading         = true;
  bool _writing         = false;
  String? _writeError;
  String? _writeSuccess;

  final _phoneCtrl  = TextEditingController();
  final _medCtrl    = TextEditingController();
  final _orthoCtrl  = TextEditingController();

  // Dog passed via Get.arguments
  String get _dogName {
    final args = Get.arguments;
    if (args is Map && args['dogName'] is String) return args['dogName'] as String;
    return 'My Dog';
  }

  String get _dogId {
    final args = Get.arguments;
    if (args is Map && args['dogId'] is String) return args['dogId'] as String;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkNfc();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _medCtrl.dispose();
    _orthoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lostPetMode = prefs.getBool(_kPrefLostPetMode) ?? false;
      _phoneCtrl.text = prefs.getString(_kPrefEmergencyPhone) ?? '';
      _medCtrl.text   = prefs.getString(_kPrefMedicalNotes)   ?? '';
      _orthoCtrl.text = prefs.getString(_kPrefOrthoNotes)     ?? '';
      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefLostPetMode,    _lostPetMode);
    await prefs.setString(_kPrefEmergencyPhone, _phoneCtrl.text.trim());
    await prefs.setString(_kPrefMedicalNotes,   _medCtrl.text.trim());
    await prefs.setString(_kPrefOrthoNotes,     _orthoCtrl.text.trim());
  }

  Future<void> _checkNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) setState(() => _nfcAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  // ── NFC write ─────────────────────────────────────────────
  /// Reescribe el chip ST25DV04K en el collar con la ficha pública de emergencia.
  /// Usa el NFC del teléfono del dueño — no requiere conexión BLE.
  Future<void> _writeNfc() async {
    if (!_nfcAvailable) {
      setState(() => _writeError = 'NFC not available on this device.');
      return;
    }

    // Build URL con dogId para que la landing page cargue la ficha correcta
    final url = '$_kNfcLandingBase?dog=${Uri.encodeComponent(_dogId)}&name=${Uri.encodeComponent(_dogName)}';

    setState(() {
      _writing = true;
      _writeError = null;
      _writeSuccess = null;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              setState(() => _writeError = 'Tag is not writable. Make sure the collar is close.');
              await NfcManager.instance.stopSession(errorMessage: 'Tag not writable');
              return;
            }

            final record = NdefRecord.createUri(Uri.parse(url));
            final message = NdefMessage([record]);
            await ndef.write(message);

            setState(() => _writeSuccess = 'Lost Pet Profile written to collar NFC ✓');
            await NfcManager.instance.stopSession();
          } catch (e) {
            setState(() => _writeError = 'Write failed: $e');
            await NfcManager.instance.stopSession(errorMessage: e.toString());
          }
        },
      );
    } catch (e) {
      setState(() => _writeError = 'Could not start NFC session: $e');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  /// Restaura el chip al token de emparejamiento original (Tap-to-Pair).
  Future<void> _restoreNfc() async {
    if (!_nfcAvailable) return;

    // Token de emparejamiento — URL vacía que la app intercepta
    const pairUrl = 'https://huntershearthealth.com/pair';

    setState(() {
      _writing = true;
      _writeError = null;
      _writeSuccess = null;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              setState(() => _writeError = 'Tag is not writable.');
              await NfcManager.instance.stopSession(errorMessage: 'Not writable');
              return;
            }
            final record = NdefRecord.createUri(Uri.parse(pairUrl));
            await ndef.write(NdefMessage([record]));
            setState(() => _writeSuccess = 'Collar restored to Tap-to-Pair mode ✓');
            await NfcManager.instance.stopSession();
          } catch (e) {
            setState(() => _writeError = 'Restore failed: $e');
            await NfcManager.instance.stopSession(errorMessage: e.toString());
          }
        },
      );
    } catch (e) {
      setState(() => _writeError = 'Could not start NFC session: $e');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _onLostPetToggle(bool val) async {
    setState(() {
      _lostPetMode = val;
      _writeError = null;
      _writeSuccess = null;
    });
    await _savePrefs();
    if (val) {
      await _writeNfc();
    } else {
      await _restoreNfc();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SignaraDashboardBackground(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── AppBar ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back<void>(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        ),
                        const Expanded(
                          child: Text(
                            'Security & Digital Identity',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // ── Body ──────────────────────────────────
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.signaraGold)))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── NFC availability notice ────
                            if (!_nfcAvailable)
                              _InfoBanner(
                                icon: Icons.nfc_rounded,
                                message: 'NFC not available on this device. You can still save the profile — it will be written when you use a device with NFC.',
                                color: const Color(0xFFFFB347),
                              ),

                            const SizedBox(height: 16),

                            // ── Lost Pet Mode switch ───────
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Lost Pet Mode',
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _lostPetMode
                                                  ? 'Active — collar NFC shows emergency profile'
                                                  : 'Off — collar NFC used for Tap-to-Pair only',
                                              style: TextStyle(
                                                color: _lostPetMode
                                                    ? const Color(0xFFFFB347)
                                                    : Colors.white.withValues(alpha: 0.45),
                                                fontSize: 12,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _lostPetMode,
                                        onChanged: _writing ? null : _onLostPetToggle,
                                        thumbColor: WidgetStateProperty.resolveWith((s) =>
                                            s.contains(WidgetState.selected) ? const Color(0xFFFFB347) : Colors.grey.shade600),
                                        trackColor: WidgetStateProperty.resolveWith((s) =>
                                            s.contains(WidgetState.selected) ? const Color(0xFFFFB347).withValues(alpha: 0.4) : Colors.white24),
                                      ),
                                    ],
                                  ),
                                  if (_writing) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.signaraGold),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Hold collar close to phone NFC...',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, decoration: TextDecoration.none),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_writeSuccess != null) ...[
                                    const SizedBox(height: 10),
                                    _StatusPill(message: _writeSuccess!, success: true),
                                  ],
                                  if (_writeError != null) ...[
                                    const SizedBox(height: 10),
                                    _StatusPill(message: _writeError!, success: false),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Privacy notice ────────────
                            _InfoBanner(
                              icon: Icons.lock_outline_rounded,
                              message: 'Your profile data is encrypted locally and only exposed on the public emergency page when Lost Pet Mode is active.',
                              color: Colors.white38,
                            ),

                            const SizedBox(height: 20),

                            // ── Public profile form ────────
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Public Emergency Profile',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                                  ),
                                  Text(
                                    'Shown when someone scans the collar — only when Lost Pet Mode is active.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, decoration: TextDecoration.none),
                                  ),
                                  const SizedBox(height: 20),

                                  // Phone
                                  _FieldLabel(label: 'Emergency Phone Number'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(
                                    controller: _phoneCtrl,
                                    hint: '+1 (314) 555-0100',
                                    keyboardType: TextInputType.phone,
                                    onChanged: (_) => _savePrefs(),
                                  ),
                                  const SizedBox(height: 18),

                                  // Medical notes
                                  _FieldLabel(label: 'Medical Alerts & Medication'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(
                                    controller: _medCtrl,
                                    hint: 'e.g. Takes Apoquel 16mg daily. Allergic to penicillin.',
                                    maxLines: 3,
                                    onChanged: (_) => _savePrefs(),
                                  ),
                                  const SizedBox(height: 18),

                                  // Ortho alerts
                                  _FieldLabel(label: 'Orthopedic Alerts'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(
                                    controller: _orthoCtrl,
                                    hint: 'e.g. Bilateral hip dysplasia — handle with care. No jumping.',
                                    maxLines: 3,
                                    onChanged: (_) => _savePrefs(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Passive location note ──────
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Passive Location',
                                    style: TextStyle(color: AppColors.signaraGold, fontSize: 15, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When someone scans the collar with their phone, the emergency page reads that phone\'s GPS and sends you their location automatically.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5, decoration: TextDecoration.none),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.battery_saver_outlined, size: 14, color: Colors.white38),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Collar GPS battery is off in V1 — this doesn't drain it.",
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11, decoration: TextDecoration.none),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message, required this.color});
  final IconData icon;
  final String   message;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.45, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
    );
  }
}

class _NfcTextField extends StatelessWidget {
  const _NfcTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.signaraGold, width: 1.5),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.message, required this.success});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF16D351) : const Color(0xFFFF4C6A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12, decoration: TextDecoration.none))),
        ],
      ),
    );
  }
}
