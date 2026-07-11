import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/signara_dashboard_background.dart';

// ── Prefs keys ────────────────────────────────────────────────────────────────
const _kPrefLostPetMode      = 'nfc_lost_pet_mode';
const _kPrefOwnerName        = 'nfc_owner_name';
const _kPrefPhone1           = 'nfc_phone1';
const _kPrefPhone2           = 'nfc_phone2';
const _kPrefPhone2Name       = 'nfc_phone2_name';
const _kPrefMicrochip        = 'nfc_microchip';
const _kPrefMedicalNotes     = 'nfc_medical_notes';
const _kPrefOrthoNotes       = 'nfc_ortho_notes';
const _kPrefBehaviorNotes    = 'nfc_behavior_notes';
const _kPrefRewardEnabled    = 'nfc_reward_enabled';
const _kPrefRewardAmount     = 'nfc_reward_amount';

// ── Landing page base URL ─────────────────────────────────────────────────────
const _kNfcLandingBase = 'https://huntershearthealth.com/find-my-dog';

/// Pantalla: dog detail → Security & Digital Identity (NFC)
///
/// LÓGICA DE DOS NIVELES (como una plaquita + ficha médica):
///
/// SIEMPRE (chip escaneado con switch OFF):
///   → Nombre del perro, foto, teléfono principal
///   → Botón "Notify owner" que envía ubicación del escáner al dueño
///   → "This dog has an owner" — nunca hay silencio
///
/// LOST PET MODE ON (switch activo):
///   → Agrega: contacto secundario, microchip, notas médicas,
///     alertas ortopédicas, comportamiento, recompensa
class NfcIdentityView extends StatefulWidget {
  const NfcIdentityView({super.key});

  @override
  State<NfcIdentityView> createState() => _NfcIdentityViewState();
}

class _NfcIdentityViewState extends State<NfcIdentityView> {
  bool    _lostPetMode  = false;
  bool    _nfcAvailable = false;
  bool    _loading      = true;
  bool    _writing      = false;
  bool    _rewardEnabled = false;
  String? _writeError;
  String? _writeSuccess;

  final _ownerNameCtrl    = TextEditingController();
  final _phone1Ctrl       = TextEditingController();
  final _phone2Ctrl       = TextEditingController();
  final _phone2NameCtrl   = TextEditingController();
  final _microchipCtrl    = TextEditingController();
  final _medCtrl          = TextEditingController();
  final _orthoCtrl        = TextEditingController();
  final _behaviorCtrl     = TextEditingController();
  final _rewardCtrl       = TextEditingController();

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

  String get _dogPhotoUrl {
    final args = Get.arguments;
    if (args is Map && args['photoUrl'] is String) return args['photoUrl'] as String;
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
    _ownerNameCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    _phone2NameCtrl.dispose();
    _microchipCtrl.dispose();
    _medCtrl.dispose();
    _orthoCtrl.dispose();
    _behaviorCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lostPetMode       = prefs.getBool(_kPrefLostPetMode)   ?? false;
      _rewardEnabled     = prefs.getBool(_kPrefRewardEnabled)  ?? false;
      _ownerNameCtrl.text  = prefs.getString(_kPrefOwnerName)   ?? '';
      _phone1Ctrl.text     = prefs.getString(_kPrefPhone1)      ?? '';
      _phone2Ctrl.text     = prefs.getString(_kPrefPhone2)      ?? '';
      _phone2NameCtrl.text = prefs.getString(_kPrefPhone2Name)  ?? '';
      _microchipCtrl.text  = prefs.getString(_kPrefMicrochip)   ?? '';
      _medCtrl.text        = prefs.getString(_kPrefMedicalNotes) ?? '';
      _orthoCtrl.text      = prefs.getString(_kPrefOrthoNotes)  ?? '';
      _behaviorCtrl.text   = prefs.getString(_kPrefBehaviorNotes) ?? '';
      _rewardCtrl.text     = prefs.getString(_kPrefRewardAmount) ?? '';
      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefLostPetMode,      _lostPetMode);
    await prefs.setBool(_kPrefRewardEnabled,    _rewardEnabled);
    await prefs.setString(_kPrefOwnerName,      _ownerNameCtrl.text.trim());
    await prefs.setString(_kPrefPhone1,         _phone1Ctrl.text.trim());
    await prefs.setString(_kPrefPhone2,         _phone2Ctrl.text.trim());
    await prefs.setString(_kPrefPhone2Name,     _phone2NameCtrl.text.trim());
    await prefs.setString(_kPrefMicrochip,      _microchipCtrl.text.trim());
    await prefs.setString(_kPrefMedicalNotes,   _medCtrl.text.trim());
    await prefs.setString(_kPrefOrthoNotes,     _orthoCtrl.text.trim());
    await prefs.setString(_kPrefBehaviorNotes,  _behaviorCtrl.text.trim());
    await prefs.setString(_kPrefRewardAmount,   _rewardCtrl.text.trim());
  }

  Future<void> _checkNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) setState(() => _nfcAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  // ── Builds NFC URL ────────────────────────────────────────
  /// SIEMPRE incluye: dogId, dogName, phone1 — el teléfono siempre visible como una plaquita.
  /// En Lost Pet Mode agrega todos los demás campos.
  String _buildNfcUrl() {
    final base = Uri.parse(_kNfcLandingBase);
    final params = <String, String>{
      'dog':   _dogId,
      'name':  _dogName,
      'owner': _ownerNameCtrl.text.trim(),
      'tel':   _phone1Ctrl.text.trim(),   // siempre visible
    };

    if (_lostPetMode) {
      if (_phone2Ctrl.text.trim().isNotEmpty) {
        params['tel2']      = _phone2Ctrl.text.trim();
        params['tel2name']  = _phone2NameCtrl.text.trim();
      }
      if (_microchipCtrl.text.trim().isNotEmpty) {
        params['chip'] = _microchipCtrl.text.trim();
      }
      if (_medCtrl.text.trim().isNotEmpty) {
        params['med'] = _medCtrl.text.trim();
      }
      if (_orthoCtrl.text.trim().isNotEmpty) {
        params['ortho'] = _orthoCtrl.text.trim();
      }
      if (_behaviorCtrl.text.trim().isNotEmpty) {
        params['behavior'] = _behaviorCtrl.text.trim();
      }
      if (_rewardEnabled && _rewardCtrl.text.trim().isNotEmpty) {
        params['reward'] = _rewardCtrl.text.trim();
      }
      params['mode'] = 'lost';
    }

    return base.replace(queryParameters: params).toString();
  }

  Future<void> _writeNfc() async {
    if (!_nfcAvailable) {
      setState(() => _writeError = 'NFC not available on this device.');
      return;
    }
    if (_phone1Ctrl.text.trim().isEmpty) {
      setState(() => _writeError = 'Add a primary phone number first — it\'s always shown when the collar is scanned.');
      return;
    }

    final url = _buildNfcUrl();
    setState(() { _writing = true; _writeError = null; _writeSuccess = null; });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              setState(() => _writeError = 'Tag not writable — hold collar closer.');
              await NfcManager.instance.stopSession(errorMessage: 'Not writable');
              return;
            }
            final record  = NdefRecord.createUri(Uri.parse(url));
            await ndef.write(NdefMessage([record]));
            setState(() => _writeSuccess = _lostPetMode
                ? 'Lost Pet profile written to collar ✓'
                : 'Basic profile written to collar ✓');
            await NfcManager.instance.stopSession();
          } catch (e) {
            setState(() => _writeError = 'Write failed: $e');
            await NfcManager.instance.stopSession(errorMessage: e.toString());
          }
        },
      );
    } catch (e) {
      setState(() => _writeError = 'Could not start NFC: $e');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _onLostPetToggle(bool val) async {
    setState(() { _lostPetMode = val; _writeError = null; _writeSuccess = null; });
    await _savePrefs();
    await _writeNfc();
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back<void>(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        ),
                        const Expanded(
                          child: Text('Security & Digital Identity',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.signaraGold)))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            // ── Explicación de 2 niveles ──────────────
                            _InfoBanner(
                              icon: Icons.info_outline_rounded,
                              message: 'Like a dog tag: phone number is always visible when the collar is scanned — no switch needed. Lost Pet Mode adds full medical profile and secondary contact.',
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 20),

                            // ── NFC unavailable ───────────────────────
                            if (!_nfcAvailable) ...[
                              _InfoBanner(
                                icon: Icons.nfc_rounded,
                                message: 'NFC not available on this device. Save your profile here — write to collar from an NFC-enabled phone.',
                                color: const Color(0xFFFFB347),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── SIEMPRE VISIBLE (dog tag info) ────────
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.pets_rounded, color: AppColors.signaraGold, size: 16),
                                    const SizedBox(width: 8),
                                    const Text('Always Visible',
                                      style: TextStyle(color: AppColors.signaraGold, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16D351).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF16D351).withValues(alpha: 0.4)),
                                      ),
                                      child: const Text('Like a dog tag',
                                        style: TextStyle(color: Color(0xFF16D351), fontSize: 10, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                                    ),
                                  ]),
                                  const SizedBox(height: 16),
                                  _FieldLabel(label: 'Owner Name'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _ownerNameCtrl, hint: 'e.g. Monica', onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 16),
                                  _FieldLabel(label: 'Primary Phone *'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _phone1Ctrl, hint: '+1 (314) 555-0100', keyboardType: TextInputType.phone, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 4),
                                  Text('Required — shown every time the collar is scanned.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11, decoration: TextDecoration.none)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Lost Pet Mode switch ───────────────────
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
                                            const Text('Lost Pet Mode',
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                                            const SizedBox(height: 4),
                                            Text(
                                              _lostPetMode
                                                  ? 'Active — full profile visible on collar scan'
                                                  : 'Off — only phone number visible',
                                              style: TextStyle(
                                                color: _lostPetMode ? const Color(0xFFFFB347) : Colors.white.withValues(alpha: 0.45),
                                                fontSize: 12, decoration: TextDecoration.none),
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
                                    Row(children: [
                                      const SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.signaraGold)),
                                      const SizedBox(width: 10),
                                      Text('Hold collar close to phone NFC...',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, decoration: TextDecoration.none)),
                                    ]),
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

                            // ── Write manually button ─────────────────
                            OutlinedButton.icon(
                              onPressed: _writing ? null : _writeNfc,
                              icon: const Icon(Icons.nfc_rounded, color: AppColors.signaraGold, size: 18),
                              label: const Text('Write to Collar Now',
                                style: TextStyle(color: AppColors.signaraGold, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.signaraGold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Full profile (Lost Pet Mode fields) ───
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.lock_open_outlined, size: 15, color: Color(0xFFFFB347)),
                                    const SizedBox(width: 8),
                                    const Text('Full Emergency Profile',
                                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text('Exposed only when Lost Pet Mode is active.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, decoration: TextDecoration.none)),
                                  const SizedBox(height: 20),

                                  // Secondary contact
                                  _FieldLabel(label: 'Secondary Contact Name'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _phone2NameCtrl, hint: 'e.g. Dante', onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 14),
                                  _FieldLabel(label: 'Secondary Contact Phone'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _phone2Ctrl, hint: '+1 (314) 555-0200', keyboardType: TextInputType.phone, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 18),

                                  // Microchip
                                  _FieldLabel(label: 'Microchip Number'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _microchipCtrl, hint: '985112345678901', keyboardType: TextInputType.number, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 18),

                                  // Medical
                                  _FieldLabel(label: 'Medical Alerts & Medication'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _medCtrl, hint: 'e.g. Takes Apoquel 16mg daily. Allergic to penicillin.', maxLines: 3, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 18),

                                  // Ortho
                                  _FieldLabel(label: 'Orthopedic Alerts'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _orthoCtrl, hint: 'e.g. Hip dysplasia — no jumping, handle with care.', maxLines: 2, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 18),

                                  // Behavior
                                  _FieldLabel(label: 'Behavior Notes'),
                                  const SizedBox(height: 6),
                                  _NfcTextField(controller: _behaviorCtrl, hint: 'e.g. Friendly. Nervous with strangers — don\'t chase. Responds to "Hunter".', maxLines: 2, onChanged: (_) => _savePrefs()),
                                  const SizedBox(height: 18),

                                  // Reward toggle
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Reward Offered',
                                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                                            Text('Optional — motivates people to contact you.',
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, decoration: TextDecoration.none)),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _rewardEnabled,
                                        onChanged: (v) { setState(() => _rewardEnabled = v); _savePrefs(); },
                                        thumbColor: WidgetStateProperty.resolveWith((s) =>
                                            s.contains(WidgetState.selected) ? AppColors.signaraGold : Colors.grey.shade600),
                                        trackColor: WidgetStateProperty.resolveWith((s) =>
                                            s.contains(WidgetState.selected) ? AppColors.signaraGold.withValues(alpha: 0.4) : Colors.white24),
                                      ),
                                    ],
                                  ),
                                  if (_rewardEnabled) ...[
                                    const SizedBox(height: 10),
                                    _NfcTextField(controller: _rewardCtrl, hint: 'e.g. \$100 reward', onChanged: (_) => _savePrefs()),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Privacy note ──────────────────────────
                            _InfoBanner(
                              icon: Icons.lock_outline_rounded,
                              message: 'Home address is never included — location flows from the finder\'s phone to you, never the other way.',
                              color: Colors.white38,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: child,
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message, required this.color});
  final IconData icon;
  final String   message;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
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
        Expanded(child: Text(message,
          style: TextStyle(color: color, fontSize: 12, height: 1.45, decoration: TextDecoration.none))),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label,
    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none));
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
  Widget build(BuildContext context) => TextField(
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
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.signaraGold, width: 1.5)),
    ),
  );
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
      child: Row(children: [
        Icon(success ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12, decoration: TextDecoration.none))),
      ]),
    );
  }
}
