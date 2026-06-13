import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/user_model.dart';
import '../../controllers/admin_controller.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        backgroundColor: const Color(0xFF0A0F1E),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminHeader(tabs: _tabs),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _UsersTab(),
                    _SessionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.tabs});

  final TabController tabs;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                // Stats chips
                Obx(() => _StatChip(
                      label: 'Users',
                      value: ctrl.users.length,
                      color: AppColors.signaraGold,
                    )),
                const SizedBox(width: 8),
                Obx(() => _StatChip(
                      label: 'Sessions',
                      value: ctrl.totalSessions,
                      color: const Color(0xFF66BB6A),
                    )),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            indicatorColor: AppColors.signaraGold,
            indicatorWeight: 2,
            labelColor: AppColors.signaraGold,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Sessions'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Users Tab ──────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    return Obx(() {
      if (ctrl.isLoadingUsers.value && ctrl.users.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.signaraGold));
      }
      if (ctrl.users.isEmpty) {
        return const Center(
          child: Text('No users found.',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: ctrl.users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final user = ctrl.users[i];
          return _UserCard(user: user);
        },
      );
    });
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    final isUpdating = ctrl.roleUpdateUid.value == user.uid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isAdmin
              ? AppColors.signaraGold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.isAdmin
                  ? AppColors.signaraGold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            child: user.avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(user.avatarUrl, fit: BoxFit.cover))
                : Icon(
                    user.isAdmin
                        ? Icons.shield_rounded
                        : Icons.person_rounded,
                    color: user.isAdmin
                        ? AppColors.signaraGold
                        : Colors.white54,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : '(no name)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _RoleBadge(isAdmin: user.isAdmin),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Role toggle button
          Obx(() {
            final updating = ctrl.roleUpdateUid.value == user.uid;
            if (updating) {
              return const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.signaraGold),
              );
            }
            return _RoleToggleButton(
              isAdmin: user.isAdmin,
              onTap: () => user.isAdmin
                  ? ctrl.demoteToPioneer(user)
                  : ctrl.promoteToAdmin(user),
            );
          }),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.signaraGold.withValues(alpha: 0.15)
            : const Color(0xFF66BB6A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Pioneer',
        style: TextStyle(
          color: isAdmin
              ? AppColors.signaraGold
              : const Color(0xFF66BB6A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RoleToggleButton extends StatelessWidget {
  const _RoleToggleButton({required this.isAdmin, required this.onTap});

  final bool isAdmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isAdmin
              ? Colors.red.withValues(alpha: 0.12)
              : AppColors.signaraGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdmin
                ? Colors.red.withValues(alpha: 0.4)
                : AppColors.signaraGold.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          isAdmin ? 'Demote' : 'Make Admin',
          style: TextStyle(
            color: isAdmin ? Colors.red[300] : AppColors.signaraGold,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Sessions Tab ───────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();
    return Obx(() {
      if (ctrl.isLoadingSessions.value && ctrl.sessions.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.signaraGold));
      }
      if (ctrl.sessions.isEmpty) {
        return const Center(
          child: Text('No sessions yet.',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: ctrl.sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final session = ctrl.sessions[i];
          // Find the user for this session
          final user = ctrl.users.firstWhereOrNull(
              (u) => u.uid == session.userId);
          return _SessionCard(session: session, user: user);
        },
      );
    });
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.user});

  final SessionModel session;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final userName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : user?.email.split('@').first ?? session.userId.substring(0, 8);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.dogName.isNotEmpty
                      ? session.dogName
                      : 'Dog (${session.dogId.substring(0, 6)})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              _ModuleBadge(moduleType: session.moduleType),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text(
                userName,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time_rounded,
                  color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text(
                session.dateDisplay,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${session.durationDisplay}s',
                style: const TextStyle(
                    color: AppColors.signaraGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniMetric(
                  label: 'Movement',
                  value: session.movementScore10,
                  color: const Color(0xFF66BB6A)),
              _MiniMetric(
                  label: 'Comfort',
                  value: session.comfortScore10,
                  color: const Color(0xFFBA68C8)),
              _MiniMetric(
                  label: 'Energy',
                  value: session.energyScore10,
                  color: AppColors.signaraGold),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({required this.moduleType});

  final String moduleType;

  @override
  Widget build(BuildContext context) {
    final label = moduleType == 'collar'
        ? 'Collar'
        : moduleType == 'vest'
            ? 'Vest'
            : moduleType == 'hip'
                ? 'Hip'
                : moduleType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: '$value/10',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
