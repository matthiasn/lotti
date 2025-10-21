import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

class SyncStatsPage extends ConsumerWidget {
  const SyncStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse the same provider IncomingStats uses so we can show a nicer
    // page-level loading state (no empty card while loading).
    final stats = ref.watch(matrixStatsControllerProvider);

    return SyncFeatureGate(
      child: Scaffold(
        appBar: TitleAppBar(title: context.messages.settingsMatrixStatsTitle),
        body: stats.when(
          data: (_) => const SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: ModernBaseCard(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: EdgeInsets.all(AppTheme.cardPadding),
              child: IncomingStats(),
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading Matrix stats',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          loading: () => Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
