import 'package:flutter/material.dart';
// Removed Riverpod dependency here to avoid page-level rebuilds.
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

class SyncStatsPage extends StatelessWidget {
  const SyncStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Always render the stats page; subpanels manage their own updates.
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixStatsTitle,
        subtitle: context.messages.settingsSyncStatsSubtitle,
        showBackButton: true,
        padding: const EdgeInsets.all(12),
        child: const ModernBaseCard(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: EdgeInsets.all(AppTheme.cardPadding),
          child: IncomingStats(),
        ),
      ),
    );
  }
}
