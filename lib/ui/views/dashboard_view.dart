import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/dog_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/dog_repository.dart';
import '../../ui/controllers/auth_controller.dart';
import '../../ui/controllers/dashboard_controller.dart';
import '../widgets/signara_dashboard_background.dart';
import '../widgets/signara_logo_mark.dart';
import '../widgets/signara_primary_button.dart';

const Color _kDashboardCardBg = Color(0xFF1A1A1A);

/// Shown before [AppRoutes.selectModule] — user confirms, then picks Collar / Vest / Hip.
Future<void> _confirmStartSessionThenSelectModule(
  BuildContext context, {
  required String dogId,
  bool closeParentFirst = false,
}) async {
  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Start session?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Next, choose a module (Collar, Vest, or Hip). When you end the session, '
        'all logs and notes are saved to your account in Firebase.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 15,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Continue',
            style: TextStyle(
              color: AppColors.signaraGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  if (closeParentFirst) {
    Navigator.of(context).pop();
  }
  Get.toNamed(
    AppRoutes.selectModule,
    arguments: <String, dynamic>{'dogId': dogId},
  );
}



/// Bottom-nav PNGs (filenames use project spelling `seleted` / `unseleted`).
abstract final class _DashboardNavIcons {
  static const String dashboardSelected = 'assets/icons/dashboard_seleted.png';
  static const String dashboardUnselected = 'assets/icons/dashboard_seleted_icon.png';
  static const String dogSelected = 'assets/icons/dog_seleted_icon.png';
  static const String dogUnselected = 'assets/icons/dog_unseleted_icon.png';
  static const String sessionSelected = 'assets/icons/session_history_seleted_icon.png';
  static const String sessionUnselected = 'assets/icons/session_history_unseleted.png';
}


Widget _bottomNavIcon(String asset, {double size = 26}) {
  return Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    gaplessPlayback: true,
  );
}

/// Bottom tab: [GestureDetector] + icon/label (replaces [BottomNavigationBar] ink/focus).
class _GestureNavTab extends StatelessWidget {
  const _GestureNavTab({
    required this.selected,
    required this.selectedAsset,
    required this.unselectedAsset,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String selectedAsset;
  final String unselectedAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bottomNavIcon(selected ? selectedAsset : unselectedAsset),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.signaraGold : Colors.white70,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hunter Hearts main shell — header, **Dashboard** tab (Select Dog + Recent Sessions), bottom nav.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _tabIndex = 0;

  late final DashboardController _ctrl;
  late final AuthController _authCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<DashboardController>();
    _authCtrl = Get.find<AuthController>();
  }

  void _logout() {
    _authCtrl.logout();
  }

  Future<void> _openAddDog() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final savedDogId = await Get.toNamed(AppRoutes.addDog);
    if (!mounted) return;
    if (savedDogId is! String || savedDogId.isEmpty) return;
    setState(() => _tabIndex = 1);
    void selectSavedDog() {
      final idx = _ctrl.dogs.indexWhere((d) => d.dogId == savedDogId);
      if (idx >= 0) {
        _ctrl.selectDog(idx);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final idx2 = _ctrl.dogs.indexWhere((d) => d.dogId == savedDogId);
          if (idx2 >= 0) {
            _ctrl.selectDog(idx2);
          } else {
            _ctrl.selectDog(0);
          }
        });
      }
    }
    selectSavedDog();
  }

  Future<void> _showDogDetailDialog(BuildContext context, _DogRow dog) {
    if (dog.dogModel == null) return Future<void>.value();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _DogDetailDialogScaffold(dog: dog);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SignaraDashboardBackground(),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onLogout: _logout, authCtrl: _authCtrl),
                  Expanded(
                    child: Obx(() {
                      final dogs = _ctrl.dogs
                          .map(_DogRow.fromModel)
                          .toList();
                      final sessionRows = _ctrl.completedSessions
                          .map(_SessionRow.fromModel)
                          .toList();
                      final homeSessions = sessionRows.take(2).toList();
                      final latestRow =
                          sessionRows.isNotEmpty ? sessionRows.first : null;
                      return IndexedStack(
                        index: _tabIndex,
                        children: [
                          _DashboardHomeTab(
                            dogs: dogs,
                            sessions: homeSessions,
                            latestSession: latestRow,
                            selectedDogIndex: _ctrl.selectedDogIndex.value,
                            onSelectDogIndex: _ctrl.selectDog,
                            onDogCardTap: (d) => _showDogDetailDialog(context, d),
                            onSeeAllDogs: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _tabIndex = 1);
                            },
                            onAddDog: _openAddDog,
                            onStartSession: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final dog = _ctrl.selectedDog;
                              if (dog == null) {
                                Get.snackbar(
                                  'Select a dog',
                                  'Choose a dog above before starting a session.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  margin: const EdgeInsets.all(16),
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              _confirmStartSessionThenSelectModule(
                                context,
                                dogId: dog.dogId,
                              );
                            },
                          ),
                          _DogTabPanel(
                            dogs: dogs,
                            selectedDogIndex: _ctrl.selectedDogIndex.value,
                            onSelectDogIndex: _ctrl.selectDog,
                            onDogCardTap: (d) => _showDogDetailDialog(context, d),
                            onDeleteDog: (d) {
                              if (d.dogModel != null) _ctrl.deleteDog(d.dogModel!);
                            },
                            onAddDog: _openAddDog,
                          ),
                          _SessionHistoryPanel(sessions: sessionRows),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom > 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _GestureNavTab(
                      selected: _tabIndex == 0,
                      selectedAsset: _DashboardNavIcons.dashboardSelected,
                      unselectedAsset: _DashboardNavIcons.dashboardUnselected,
                      label: 'Dashboard',
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _tabIndex = 0);
                      },
                    ),
                  ),
                  Expanded(
                    child: _GestureNavTab(
                      selected: _tabIndex == 1,
                      selectedAsset: _DashboardNavIcons.dogSelected,
                      unselectedAsset: _DashboardNavIcons.dogUnselected,
                      label: 'Dog',
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _tabIndex = 1);
                      },
                    ),
                  ),
                  Expanded(
                    child: _GestureNavTab(
                      selected: _tabIndex == 2,
                      selectedAsset: _DashboardNavIcons.sessionSelected,
                      unselectedAsset: _DashboardNavIcons.sessionUnselected,
                      label: 'Session History',
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _tabIndex = 2);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashboard header — uses [StreamBuilder] for live user display-name/email
/// from `users/{uid}` in Firestore.
class _Header extends StatelessWidget {
  const _Header({required this.onLogout, required this.authCtrl});

  final VoidCallback onLogout;
  final AuthController authCtrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      child: Row(
        children: [
          const SignaraBrandLogoMark(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<UserModel?>(
              stream: authCtrl.userProfileStream,
              builder: (context, snap) {
                final user = snap.data;
                final name = (user?.displayName.isNotEmpty == true)
                    ? user!.displayName
                    : (user?.email.isNotEmpty == true
                        ? user!.email.split('@').first
                        : 'Hunter Hearts');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Hunter Hearts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (user != null)
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

/// Adapter to keep the existing card/dialog UI compatible with DogModel
class _DogRow {
  const _DogRow({
    required this.name,
    required this.age,
    required this.weight,
    required this.gender,
    this.anxietyBullet = '',
    this.mobilityBullet = '',
    this.notesSample = '',
    this.photoUrl = '',
    this.dogModel,
  });

  factory _DogRow.fromModel(DogModel m) => _DogRow(
        name: m.name,
        age: m.ageDisplay,
        weight: m.weightDisplay,
        gender: m.gender,
        anxietyBullet: m.anxietyHistory.isNotEmpty ? m.anxietyHistory.first : '—',
        mobilityBullet: m.mobilityHistory.isNotEmpty ? m.mobilityHistory.first : '—',
        notesSample: m.healthNotes.isEmpty ? 'No notes yet.' : m.healthNotes,
        photoUrl: m.photoUrl,
        dogModel: m,
      );

  final String name;
  final String age;
  final String weight;
  final String gender;
  final String anxietyBullet;
  final String mobilityBullet;
  final String notesSample;
  final String photoUrl;
  final DogModel? dogModel;
}

class _SessionRow {
  const _SessionRow({
    required this.sessionLabel,
    required this.dateLine,
    required this.duration,
    required this.movement,
    required this.comfort,
    required this.energy,
    this.deviceId = 'collar',
    this.sessionModel,
  });

  factory _SessionRow.fromModel(SessionModel m) => _SessionRow(
        sessionLabel: 'Session Type: ${m.deviceLabel}',
        dateLine: 'Date: ${m.dateDisplay}',
        duration: m.durationDisplay,
        movement: m.movementScore10,
        comfort: m.comfortScore10,
        energy: m.energyScore10,
        deviceId: m.moduleType,
        sessionModel: m,
      );

  final String sessionLabel;
  final String dateLine;
  final String duration;
  final int movement;
  final int comfort;
  final int energy;
  final String deviceId;
  final SessionModel? sessionModel;
}

// _SessionSummaryData replaced by SessionModel from Firestore

// Demo data removed — now driven by Firestore via DashboardController

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab({
    required this.dogs,
    required this.sessions,
    this.latestSession,
    required this.selectedDogIndex,
    required this.onSelectDogIndex,
    required this.onDogCardTap,
    required this.onSeeAllDogs,
    required this.onAddDog,
    required this.onStartSession,
  });

  final List<_DogRow> dogs;
  final List<_SessionRow> sessions;
  final _SessionRow? latestSession;
  final int selectedDogIndex;
  final ValueChanged<int> onSelectDogIndex;
  final void Function(_DogRow dog) onDogCardTap;
  final VoidCallback onSeeAllDogs;
  final Future<void> Function() onAddDog;
  final VoidCallback onStartSession;

  static const Color _movementGreen = Color(0xFF66BB6A);
  static const Color _comfortPurple = Color(0xFFBA68C8);
  static const Color _emptyStateGrey = Color(0xFF808080);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dogs.isEmpty)
            const Text(
              'Select Dog',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    'Select Dog',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllDogs,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.signaraGold,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            'Choose which dog to work with',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          if (dogs.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No dogs added yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _emptyStateGrey,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            SignaraPrimaryButton(
              label: 'Add Your First Dog',
              onPressed: () => onAddDog(),
            ),
          ] else ...[
            ...List.generate(dogs.length, (i) {
              final d = dogs[i];
              final selected = i == selectedDogIndex;
              return Padding(
                padding: EdgeInsets.only(bottom: i == dogs.length - 1 ? 0 : 12),
                child: GestureDetector(
                  onTap: () {
                    onSelectDogIndex(i);
                    onDogCardTap(d);
                  },
                  child: _DogSelectCard(data: d, selected: selected),
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onAddDog(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.signaraGold,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Add Dog',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // SignaraPrimaryButton(
          //   label: 'Start Session',
          //   onPressed: onStartSession,
          // ),
          // const SizedBox(height: 28),
          // if (latestSession?.sessionModel != null) ...[
          //   const Text(
          //     'Session summary',
          //     style: TextStyle(
          //       color: Colors.white,
          //       fontSize: 20,
          //       fontWeight: FontWeight.w700,
          //     ),
          //   ),
          //   const SizedBox(height: 8),
          //   Text(
          //     'Latest completed session (saved to cloud)',
          //     style: TextStyle(
          //       color: Colors.white.withValues(alpha: 0.55),
          //       fontSize: 14,
          //       fontWeight: FontWeight.w400,
          //     ),
          //   ),
          //   const SizedBox(height: 14),
          //   // _LatestSessionSummaryCard(
          //   //   row: latestSession!,
          //   //   dogName: _dogNameForSession(dogs, latestSession!.sessionModel!),
          //   //   onOpenFull: () {
          //   //     final id = latestSession!.sessionModel!.sessionId;
          //   //     if (id.isEmpty) return;
          //   //     Get.toNamed(
          //   //       AppRoutes.sessionSummary,
          //   //       arguments: <String, dynamic>{'sessionId': id},
          //   //     );
          //   //   },
          //   // ),
          //   const SizedBox(height: 28),
          // ],
        
        
        
          const Text(
            'Recent Sessions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No Session yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _emptyStateGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            )
          else
            ...sessions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final m = s.sessionModel;
                    if (m == null || m.sessionId.isEmpty) return;
                    Get.toNamed(
                      AppRoutes.sessionSummary,
                      arguments: <String, dynamic>{'sessionId': m.sessionId},
                    );
                  },
                  child: _RecentSessionCard(
                    data: s,
                    cardBg: _kDashboardCardBg,
                    movementColor: _movementGreen,
                    comfortColor: _comfortPurple,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



/// Full-detail preview of the most recent Firestore session on the home tab.
// class _LatestSessionSummaryCard extends StatelessWidget {
//   const _LatestSessionSummaryCard({
//     required this.row,
//     this.dogName,
//     required this.onOpenFull,
//   });

//   final _SessionRow row;
//   final String? dogName;
//   final VoidCallback onOpenFull;

//   static const Color _cardBg = Color(0xFF1E1E1E);
//   static const Color _valueGreen = Color(0xFF66BB6A);

//   @override
//   Widget build(BuildContext context) {
//     final s = row.sessionModel!;
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: _cardBg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Text(
//             s.dateDisplay,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           if (dogName != null && dogName!.isNotEmpty) ...[
//             const SizedBox(height: 6),
//             Text(
//               'Dog: $dogName',
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.65),
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//           const SizedBox(height: 14),
//           _pair('Duration', s.durationDisplay, _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Device', s.deviceLabel, _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Module', _moduleTypeLabel(s.moduleType), _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Haptic', s.hapticPreset, _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Intensity', '${s.intensityScore10}/10', _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Haptic on', s.hapticOn ? 'Yes' : 'No', Colors.white70),
//           const SizedBox(height: 10),
//           _pair('Calming', '${s.calmingLevel}/5', AppColors.signaraGold),
//           const SizedBox(height: 10),
//           _pair('Response', s.responseDisplayLabel, _valueGreen),
//           const SizedBox(height: 10),
//           _pair('Limp', s.limpDisplayLabel, Colors.white70),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Expanded(
//                 child: _miniMetric(
//                   'Movement',
//                   row.movement,
//                   AppColors.sessionMovementGreen,
//                 ),
//               ),
//               Expanded(
//                 child: _miniMetric(
//                   'Comfort',
//                   row.comfort,
//                   AppColors.sessionComfortPurple,
//                 ),
//               ),
//               Expanded(
//                 child: _miniMetric('Energy', row.energy, AppColors.signaraGold),
//               ),
//             ],
//           ),
//           if (s.notes.trim().isNotEmpty) ...[
//             const SizedBox(height: 14),
//             Text(
//               'Notes',
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.7),
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               s.notes.trim(),
//               maxLines: 4,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.85),
//                 fontSize: 14,
//                 height: 1.4,
//               ),
//             ),
//           ],
//           if (s.photoUrl.trim().isNotEmpty || s.videoUrl.trim().isNotEmpty) ...[
//             const SizedBox(height: 10),
//             Text(
//               s.photoUrl.trim().isNotEmpty && s.videoUrl.trim().isNotEmpty
//                   ? 'Photo and video attached'
//                   : s.photoUrl.trim().isNotEmpty
//                       ? 'Photo attached'
//                       : 'Video attached',
//               style: TextStyle(
//                 color: AppColors.signaraGold.withValues(alpha: 0.9),
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//           const SizedBox(height: 16),
//           TextButton(
//             onPressed: onOpenFull,
//             style: TextButton.styleFrom(
//               foregroundColor: AppColors.signaraGold,
//               padding: EdgeInsets.zero,
//               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             ),
//             child: const Text(
//               'Open full summary',
//               style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pair(String label, String value, Color valueColor) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 100,
//           child: Text(
//             label,
//             style: TextStyle(
//               color: Colors.white.withValues(alpha: 0.65),
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: TextStyle(
//               color: valueColor,
//               fontSize: 14,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _miniMetric(String label, int value, Color color) {
//     return Text(
//       '$label: $value',
//       textAlign: TextAlign.center,
//       style: TextStyle(
//         color: color,
//         fontSize: 13,
//         fontWeight: FontWeight.w800,
//       ),
//     );
//   }
// }

class _DogTabPanel extends StatelessWidget {
  const _DogTabPanel({
    required this.dogs,
    required this.selectedDogIndex,
    required this.onSelectDogIndex,
    required this.onDogCardTap,
    required this.onDeleteDog,
    required this.onAddDog,
  });

  final List<_DogRow> dogs;
  final int selectedDogIndex;
  final ValueChanged<int> onSelectDogIndex;
  final void Function(_DogRow dog) onDogCardTap;
  final void Function(_DogRow dog) onDeleteDog;
  final Future<void> Function() onAddDog;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select Dog',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which dog to work with',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          if (dogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                'No dogs added yet.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                ),
              ),
            )
          else
            ...List.generate(dogs.length, (i) {
              final d = dogs[i];
              final selected = i == selectedDogIndex;
              return Padding(
                padding: EdgeInsets.only(bottom: i == dogs.length - 1 ? 0 : 12),
                child: GestureDetector(
                  onTap: () {
                    onSelectDogIndex(i);
                    onDogCardTap(d);
                  },
                  child: _DogSelectCard(data: d, selected: selected),
                ),
              );
            }),
          const SizedBox(height: 24),
            SignaraPrimaryButton(
            label: 'Add New Dog',
            onPressed: onAddDog,
          ),
        ],
      ),
    );
  }
}


class _DogSelectCard extends StatelessWidget {
  const _DogSelectCard({
    required this.data,
    required this.selected,
  });

  final _DogRow data;
  final bool selected;

  static const Color _ringGreen = Color(0xFF3D6B4F);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kDashboardCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.signaraGold : Colors.transparent,
          width: selected ? 2.2 : 0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.signaraGold.withValues(alpha: 0.38),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _ringGreen.withValues(alpha: 0.55),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: ClipOval(
              child: data.photoUrl.isNotEmpty
                  ? Image.network(
                      data.photoUrl,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                      errorBuilder: (_, e, s) => Image.asset(
                        'assets/icons/dog_icon.png',
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/dog_icon.png',
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _DogStatInline(label: 'Age', value: data.age),
                    _DogStatInline(label: 'Weight', value: data.weight),
                    _DogStatInline(label: 'Gender', value: data.gender),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `Age: 5years` — label + colon in white, value in gold (matches reference).
class _DogStatInline extends StatelessWidget {
  const _DogStatInline({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.2,
            decoration: TextDecoration.none,
            decorationThickness: 0,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(decoration: TextDecoration.none),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.signaraGold,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blurred scrim + gold-bordered dog detail sheet (reference UI).
class _DogDetailDialogScaffold extends StatelessWidget {
  const _DogDetailDialogScaffold({required this.dog});

  final _DogRow dog;

  @override
  Widget build(BuildContext context) {
    final model = dog.dogModel;
    if (model == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.48),
          child: Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _DogDetailDialogContent(initialDog: model),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full dog profile from Firestore `users/{uid}/dogs/{dogId}` (live stream).
class _DogDetailDialogContent extends StatelessWidget {
  const _DogDetailDialogContent({required this.initialDog});

  final DogModel initialDog;

  static const Color _ringGreen = Color(0xFF3D6B4F);

  static const TextStyle _dialogTextBase = TextStyle(
    decoration: TextDecoration.none,
    decorationThickness: 0,
    decorationColor: Colors.transparent,
  );

  static Widget _bulletBlock(List<String> items, TextStyle base) {
    if (items.isEmpty) {
      return Text(
        'None recorded',
        style: base.copyWith(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 14,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $t',
                style: base.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DogModel?>(
      stream: Get.find<DogRepository>().watchDog(
        userId: initialDog.ownerId,
        dogId: initialDog.dogId,
      ),
      initialData: initialDog,
      builder: (context, snapshot) {
        final d = snapshot.data;
        if (d == null) {
          return Material(
            color: Colors.transparent,
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF151815),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.signaraGold.withValues(alpha: 0.7)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dog profile unavailable',
                    style: _dialogTextBase.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        final panel = Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF151815),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.signaraGold.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.signaraGold.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 0,
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: _dialogTextBase,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Get.find<DashboardController>().deleteDog(d);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 26),
                    ),
                  ],
                ),
                Center(
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _ringGreen.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: d.photoUrl.isNotEmpty
                          ? Image.network(
                              d.photoUrl,
                              fit: BoxFit.cover,
                              width: 108,
                              height: 108,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                'assets/icons/dog_icon.png',
                                fit: BoxFit.cover,
                                width: 108,
                                height: 108,
                              ),
                            )
                          : Image.asset(
                              'assets/icons/dog_icon.png',
                              fit: BoxFit.cover,
                              width: 108,
                              height: 108,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  d.name,
                  textAlign: TextAlign.center,
                  style: _dialogTextBase.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (d.breed.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.breed.trim(),
                    textAlign: TextAlign.center,
                    style: _dialogTextBase.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DogStatInline(label: 'Age', value: d.ageDisplay),
                    _DogStatInline(label: 'Weight', value: d.weightDisplay),
                    _DogStatInline(label: 'Gender', value: d.gender),
                  ],
                ),
                if (d.microchipId.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Microchip: ${d.microchipId.trim()}',
                    textAlign: TextAlign.center,
                    style: _dialogTextBase.copyWith(
                      color: AppColors.signaraGold.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (d.vaccinationDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Vaccination: ${_formatDate(d.vaccinationDate!)}',
                    textAlign: TextAlign.center,
                    style: _dialogTextBase.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Anxiety History',
                  style: _dialogTextBase.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _bulletBlock(d.anxietyHistory, _dialogTextBase),
                const SizedBox(height: 16),
                Text(
                  'Mobility History',
                  style: _dialogTextBase.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _bulletBlock(d.mobilityHistory, _dialogTextBase),
                const SizedBox(height: 18),
                Text(
                  'Additional Notes',
                  style: _dialogTextBase.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    d.healthNotes.trim().isEmpty ? 'No notes yet.' : d.healthNotes.trim(),
                    style: _dialogTextBase.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SignaraPrimaryButton(
                  label: 'Start Session',
                  onPressed: () async {
                    final dash = Get.find<DashboardController>();
                    final idx = dash.dogs.indexWhere((x) => x.dogId == d.dogId);
                    if (idx >= 0) {
                      dash.selectDog(idx);
                    }
                    await _confirmStartSessionThenSelectModule(
                      context,
                      dogId: d.dogId,
                      closeParentFirst: true,
                    );
                  },
                ),
              ],
            ),
          ),
        );

        return Material(
          color: Colors.transparent,
          type: MaterialType.transparency,
          child: panel,
        );
      },
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({
    required this.data,
    required this.cardBg,
    required this.movementColor,
    required this.comfortColor,
    this.sessionHistoryStyle = false,
  });

  final _SessionRow data;
  final Color cardBg;
  final Color movementColor;
  final Color comfortColor;
  /// Reference Session Log: flat grey card, thin white outline, mustard duration (no gold glow).
  final bool sessionHistoryStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sessionHistoryStyle
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.signaraGold.withValues(alpha: 0.45),
          width: sessionHistoryStyle ? 1 : 1.2,
        ),
        boxShadow: sessionHistoryStyle
            ? null
            : [
                BoxShadow(
                  color: AppColors.signaraGold.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.sessionLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.dateLine,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: sessionHistoryStyle ? 0.75 : 1.0),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                data.duration,
                style: const TextStyle(
                  color: AppColors.signaraGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricChip(
                label: 'Movement',
                value: data.movement,
                valueColor: movementColor,
              ),
              _MetricChip(
                label: 'Comfort',
                value: data.comfort,
                valueColor: comfortColor,
              ),
              _MetricChip(
                label: 'Energy',
                value: data.energy,
                valueColor: AppColors.signaraGold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: '$value',
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SESSION HISTORY — list from Firestore; tap opens [SessionSummaryView] by id
// =============================================================================

class _SessionHistoryPanel extends StatefulWidget {
  const _SessionHistoryPanel({required this.sessions});

  final List<_SessionRow> sessions;

  @override
  State<_SessionHistoryPanel> createState() => _SessionHistoryPanelState();
}

class _SessionHistoryPanelState extends State<_SessionHistoryPanel> {
  String _activeFilter = 'collar';

  List<_SessionRow> get _filteredSessions =>
      widget.sessions.where(_rowMatchesFilter).toList();

  bool _rowMatchesFilter(_SessionRow s) {
    final t = s.deviceId;
    if (t != 'collar' && t != 'vest' && t != 'hip') return true;
    return t == _activeFilter;
  }

  @override
  Widget build(BuildContext context) {
    return _SessionLogView(
      activeFilter: _activeFilter,
      sessions: _filteredSessions,
      onFilterChanged: (f) => setState(() => _activeFilter = f),
      onSessionTap: (s) {
        final m = s.sessionModel;
        if (m == null || m.sessionId.isEmpty) return;
        Get.toNamed(
          AppRoutes.sessionSummary,
          arguments: <String, dynamic>{'sessionId': m.sessionId},
        );
      },
    );
  }
}

// ── Screen 1 ──────────────────────────────────────────────────────────────────

class _SessionLogView extends StatelessWidget {
  const _SessionLogView({
    required this.activeFilter,
    required this.sessions,
    required this.onFilterChanged,
    required this.onSessionTap,
  });

  final String activeFilter;
  final List<_SessionRow> sessions;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_SessionRow> onSessionTap;

  static const Color _movementGreen = Color(0xFF66BB6A);
  static const Color _comfortPurple = Color(0xFFBA68C8);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Session Log',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Complete Session',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SessionFilterChip(
                label: 'Collar',
                selected: activeFilter == 'collar',
                onTap: () => onFilterChanged('collar'),
              ),
              const SizedBox(width: 10),
              _SessionFilterChip(
                label: 'Vest',
                selected: activeFilter == 'vest',
                onTap: () => onFilterChanged('vest'),
              ),
              const SizedBox(width: 10),
              _SessionFilterChip(
                label: 'Hip',
                selected: activeFilter == 'hip',
                onTap: () => onFilterChanged('hip'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No sessions found',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ...sessions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GestureDetector(
                  onTap: () => onSessionTap(s),
                  child: _RecentSessionCard(
                    data: s,
                    cardBg: _kDashboardCardBg,
                    movementColor: _movementGreen,
                    comfortColor: _comfortPurple,
                    sessionHistoryStyle: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionFilterChip extends StatelessWidget {
  const _SessionFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.signaraGold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.signaraGold
                : Colors.white.withValues(alpha: 0.45),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1A) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
