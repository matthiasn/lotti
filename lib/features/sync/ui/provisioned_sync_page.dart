import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/state/sync_configured_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

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
    // Reactive: watching the service alone hands back one stable object, so
    // it never rebuilds when login and room hydration complete during an
    // unawaited startup — leaving the setup card up on a configured device.
    final configured = ref.watch(syncConfiguredProvider);

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
            : const SyncSetupEmptyState(),
      ),
    );
  }
}

/// Headerless desktop body of the provisioned-sync (Devices) leaf, for the
/// settings detail pane: the same roster-or-setup-card choice as
/// [ProvisionedSyncPage], without its page chrome.
///
/// The card is Matrix-only, so the body is gated on [enableMatrixFlag] — but
/// unlike [SyncFeatureGate] it does not redirect away when the flag is off;
/// it renders nothing. Read through [configFlagProvider] so the flag stream
/// is cached across rebuilds instead of resubscribed on each one.
class ProvisionedSyncBody extends ConsumerWidget {
  const ProvisionedSyncBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final enabled =
        ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false;
    if (!enabled) return const SizedBox.shrink();

    final configured = ref.watch(syncConfiguredProvider);

    // Once sync is set up, the roster IS this panel: hiding it behind a card
    // that opens a modal added a tap and a second surface with the same
    // name. Capped at the shared reading measure: uncapped, the roster's
    // cards and buttons stretched across the entire detail pane.
    return DetailContentWidth(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
        child: configured
            ? const ProvisionedStatusWidget(embedded: true)
            : const SyncSetupEmptyState(),
      ),
    );
  }
}
