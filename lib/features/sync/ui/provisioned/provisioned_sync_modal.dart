import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/manual_credentials_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned/sync_setup_entry.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The not-yet-configured face of the Devices surface: the two-device motif
/// with its gap still open, what sync is in one line, and the one action
/// that starts it.
///
/// Deliberately an empty state rather than a settings row. The row duplicated
/// the navigation entry that had just been tapped — "Devices" under a header
/// reading "Devices" — and left the rest of the pane blank, so the flow's
/// first screen read as a dead end with a second door in it. The motif is the
/// same figure the connect step and the verified celebration carry, so the
/// journey opens and closes on one image.
///
/// On Linux a second, quieter way in sits under the action: signing in with a
/// Matrix account by hand (GitHub #4055), for the first device of a user who
/// has an account but nobody to mint a provisioning bundle. Gated to Linux
/// deliberately — it is the platform where self-hosters run the homeserver
/// beside the app — and the sheet only carries the credentials page there.
class SyncSetupEmptyState extends ConsumerStatefulWidget {
  const SyncSetupEmptyState({super.key});

  @override
  ConsumerState<SyncSetupEmptyState> createState() =>
      _SyncSetupEmptyStateState();
}

class _SyncSetupEmptyStateState extends ConsumerState<SyncSetupEmptyState> {
  late final ValueNotifier<int> pageIndexNotifier;

  /// The entry page the connect step was last reached from. Tracked off the
  /// page index rather than reported by the entry pages: the connect step is
  /// reachable only from an entry page, so the last entry page shown is the
  /// one that sent the user on.
  late final ValueNotifier<SyncSetupEntry> entryNotifier;

  @override
  void initState() {
    super.initState();
    pageIndexNotifier = ValueNotifier(SyncSetupPage.pairingCode)
      ..addListener(_trackEntry);
    entryNotifier = ValueNotifier(SyncSetupEntry.pairingCode);
  }

  @override
  void dispose() {
    pageIndexNotifier
      ..removeListener(_trackEntry)
      ..dispose();
    entryNotifier.dispose();
    super.dispose();
  }

  void _trackEntry() {
    for (final entry in SyncSetupEntry.values) {
      if (entry.page == pageIndexNotifier.value) {
        entryNotifier.value = entry;
        return;
      }
    }
  }

  void _openWizard({SyncSetupEntry entry = SyncSetupEntry.pairingCode}) {
    final matrixService = ref.read(matrixServiceProvider);
    final isConfigured =
        matrixService.isLoggedIn() && matrixService.syncRoomId != null;
    pageIndexNotifier.value = entry.page;
    // The listener is silent when the index did not change.
    _trackEntry();

    ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalContext) {
        if (isConfigured) {
          return [
            provisionedStatusPage(
              context: modalContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ];
        }

        return [
          bundleImportPage(
            context: modalContext,
            pageIndexNotifier: pageIndexNotifier,
            onSignInWithAccount: isLinux
                ? () => pageIndexNotifier.value = SyncSetupPage.credentials
                : null,
          ),
          provisionedConfigPage(
            context: modalContext,
            pageIndexNotifier: pageIndexNotifier,
            entry: entryNotifier,
          ),
          provisionedStatusPage(
            context: modalContext,
            pageIndexNotifier: pageIndexNotifier,
          ),
          if (isLinux)
            manualCredentialsPage(
              context: modalContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: tokens.spacing.sectionGap,
        horizontal: tokens.spacing.step6,
      ),
      child: Center(
        child: ConstrainedBox(
          // Half the detail rail: a centred column that holds its measure on
          // a maximized window instead of a stamp adrift in a megapixel of
          // page background.
          constraints: const BoxConstraints(
            maxWidth: kDetailContentMaxWidth / 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SyncDevicePairMotif(state: SyncDevicePairMotifState.idle),
              SizedBox(height: tokens.spacing.step6),
              Text(
                messages.syncSetupEmptyTitle,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.heading.heading2,
              ),
              SizedBox(height: tokens.spacing.step3),
              Text(
                messages.syncSetupEmptyHint,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step6),
              DesignSystemButton(
                key: const Key('sync_setup_cta'),
                label: messages.syncSetupCta,
                size: DesignSystemButtonSize.large,
                leadingIcon: LottiIcons.scanQr,
                onPressed: _openWizard,
              ),
              if (isLinux) ...[
                SizedBox(height: tokens.spacing.step4),
                // Quiet, under the accent: the code is still the main road,
                // this is the one for a user with an account and no code.
                DesignSystemInlineAction(
                  key: const Key('sync_setup_use_account'),
                  onTap: () => _openWizard(entry: SyncSetupEntry.credentials),
                  leadingIcon: LottiIcons.key,
                  label: messages.syncSetupUseAccountLink,
                  semanticsLabel: messages.syncSetupUseAccountLink,
                ),
              ],
              SizedBox(height: tokens.spacing.step5),
              Text(
                messages.syncSetupEmptyFootnote,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
