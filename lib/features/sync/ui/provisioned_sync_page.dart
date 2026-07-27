import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

/// Mobile / Beamer wrapper for the provisioned-sync (QR-pairing) entry.
///
/// Mirrors `SyncStatsPage` / `BackfillSettingsPage`: adds the
/// [SliverBoxAdapterPage] chrome + the [SyncFeatureGate] flag check. The body
/// matches the desktop `sync-provisioned` panel exactly — once sync is
/// configured the roster *is* this screen, and only the not-yet-configured
/// case shows the setup card.
///
/// That parity is load-bearing, not tidiness: every instruction in the pairing
/// flow says "open Settings → Sync Settings → Devices, then choose Add
/// device". While this page rendered the card unconditionally, mobile users
/// following that sentence landed on a screen with no Add device on it and had
/// to discover one more tap.
class ProvisionedSyncPage extends ConsumerWidget {
  const ProvisionedSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so completing setup (or disconnecting) swaps the body without
    // needing a re-navigation.
    ref.watch(provisioningControllerProvider);
    final service = ref.watch(matrixServiceProvider);
    final configured = service.isLoggedIn() && service.syncRoomId != null;

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.provisionedSyncTitle,
        subtitle: context.messages.provisionedSyncSubtitle,
        showBackButton: true,
        padding: EdgeInsets.symmetric(
          horizontal: context.designTokens.spacing.step5,
        ),
        child: configured
            ? const ProvisionedStatusWidget(embedded: true)
            : const ProvisionedSyncSettingsCard(showDivider: false),
      ),
    );
  }
}
