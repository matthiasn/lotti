import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The not-yet-configured face of the Devices surface: what sync is, in one
/// line, and the one action that starts it.
///
/// Deliberately an empty state rather than a settings row. The row duplicated
/// the navigation entry that had just been tapped — "Devices" under a header
/// reading "Devices" — and left the rest of the pane blank, so the flow's
/// first screen read as a dead end with a second door in it.
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
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.sectionGap),
      child: DesignSystemEmptyState(
        icon: MdiIcons.cellphoneLink,
        title: messages.syncSetupEmptyTitle,
        hint: messages.syncSetupEmptyHint,
        action: DesignSystemButton(
          key: const Key('sync_setup_cta'),
          label: messages.syncSetupCta,
          size: DesignSystemButtonSize.large,
          leadingIcon: Icons.qr_code_scanner,
          onPressed: _openWizard,
        ),
      ),
    );
  }
}
