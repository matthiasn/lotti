import 'package:flutter/material.dart';
// Removed Riverpod dependency here to avoid page-level rebuilds.
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

class SyncStatsPage extends StatelessWidget {
  const SyncStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Always render the stats page; subpanels manage their own updates.
    return SyncFeatureGate(
      child: Scaffold(
        appBar: TitleAppBar(title: context.messages.settingsMatrixStatsTitle),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: ModernBaseCard(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: EdgeInsets.all(AppTheme.cardPadding),
            child: IncomingStats(),
          ),
        ),
      ),
    );
  }
}
