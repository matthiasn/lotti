import 'package:flutter/material.dart';
// Removed Riverpod dependency here to avoid page-level rebuilds.
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Mobile / legacy wrapper. Keeps the `SliverBoxAdapterPage` chrome
/// + `SyncFeatureGate` and delegates content to [SyncStatsBody] so
/// the same widget can render inside the Settings V2 detail pane
/// (plan step 7).
class SyncStatsPage extends StatelessWidget {
  const SyncStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixStatsTitle,
        subtitle: context.messages.settingsSyncStatsSubtitle,
        showBackButton: true,
        padding: const EdgeInsets.all(12),
        child: const SyncStatsBody(),
      ),
    );
  }
}

/// Content body for the sync-stats page. A single card wrapping
/// [IncomingStats]; the heavy pipeline-metrics widget manages its own
/// streams so this body stays state-free.
class SyncStatsBody extends StatelessWidget {
  const SyncStatsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModernBaseCard(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: EdgeInsets.all(AppTheme.cardPadding),
      child: IncomingStats(),
    );
  }
}
