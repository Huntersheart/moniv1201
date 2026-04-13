import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Reusable **public** widget (exported library API — no leading `_`).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
