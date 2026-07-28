import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
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
class SyncSetupEmptyState extends ConsumerStatefulWidget {
  const SyncSetupEmptyState({super.key});

  @override
  ConsumerState<SyncSetupEmptyState> createState() =>
      _SyncSetupEmptyStateState();
}

class _SyncSetupEmptyStateState extends ConsumerState<SyncSetupEmptyState> {
  late final ValueNotifier<int> pageIndexNotifier;

  @override
  void initState() {
    super.initState();
    pageIndexNotifier = ValueNotifier(0);
  }

  @override
  void dispose() {
    pageIndexNotifier.dispose();
    super.dispose();
  }

  void _openWizard() {
    final matrixService = ref.read(matrixServiceProvider);
    final isConfigured =
        matrixService.isLoggedIn() && matrixService.syncRoomId != null;
    pageIndexNotifier.value = 0;

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
          ),
          provisionedConfigPage(
            context: modalContext,
            pageIndexNotifier: pageIndexNotifier,
          ),
          provisionedStatusPage(
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
                leadingIcon: Icons.qr_code_scanner,
                onPressed: _openWizard,
              ),
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
