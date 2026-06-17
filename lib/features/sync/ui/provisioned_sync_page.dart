import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / Beamer wrapper for the provisioned-sync (QR-pairing) entry.
///
/// Mirrors `SyncStatsPage` / `BackfillSettingsPage`: adds the
/// [SliverBoxAdapterPage] chrome + the [SyncFeatureGate] flag check and
/// delegates the content to [ProvisionedSyncSettingsCard]. On desktop the
/// same card is embedded directly by the `sync-provisioned` panel, which
/// supplies its own chrome — so the wrapper exists only for the mobile
/// drill-down's `/settings/sync/provisioned` leaf.
class ProvisionedSyncPage extends StatelessWidget {
  const ProvisionedSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.provisionedSyncTitle,
        subtitle: context.messages.provisionedSyncSubtitle,
        showBackButton: true,
        padding: EdgeInsets.symmetric(
          horizontal: context.designTokens.spacing.step5,
        ),
        child: const ProvisionedSyncSettingsCard(showDivider: false),
      ),
    );
  }
}
