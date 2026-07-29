import 'package:flutter/material.dart';
// Removed Riverpod dependency here to avoid page-level rebuilds.
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / legacy wrapper. Keeps the `SliverBoxAdapterPage` chrome
/// + `SyncFeatureGate` and delegates content to [SyncStatsBody] so
/// the same widget can render inside the Settings V2 detail pane
/// (plan step 7).
class SyncStatsPage extends StatelessWidget {
  const SyncStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixStatsTitle,
        subtitle: context.messages.settingsSyncStatsSubtitle,
        showBackButton: true,
        padding: EdgeInsets.all(tokens.spacing.step5),
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
    return const DesignSystemSectionCard(
      child: IncomingStats(),
    );
  }
}
