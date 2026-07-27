import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/auto_verification_launcher.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/diagnostic_info_button.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_devices_list.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage provisionedStatusPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _StatusActionBar(
      pageIndexNotifier: pageIndexNotifier,
    ),
    // The setup flow's own title. Reusing the roster's name titled a sheet
    // "Devices" that also contains a "Devices" section header.
    title: context.messages.provisionedSyncImportTitle,
    padding:
        WoltModalConfig.pagePadding +
        const EdgeInsets.only(
          bottom: WoltModalConfig.stickyActionBarClearance,
        ),
    child: const ProvisionedStatusWidget(),
  );
}

class _StatusActionBar extends ConsumerWidget {
  const _StatusActionBar({
    required this.pageIndexNotifier,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SyncStickyBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Spacer(),
          SizedBox(width: context.designTokens.spacing.step3),
          Flexible(
            child: DesignSystemButton(
              onPressed: () {
                // Keep notifier state predictable for future multi-step flows.
                pageIndexNotifier.value = 0;
                Navigator.of(context).pop();
              },
              label: context.messages.tasksLabelsDialogClose,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
            ),
          ),
        ],
      ),
    );
  }
}

class ProvisionedStatusWidget extends ConsumerWidget {
  const ProvisionedStatusWidget({super.key, this.embedded = false});

  /// True when rendered directly in the settings detail pane rather than
  /// inside the pairing modal. Embedded, there is no sheet to dismiss after
  /// disconnecting — popping would walk the user out of Settings.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixService = ref.watch(matrixServiceProvider);
    final messages = context.messages;
    final tokens = context.designTokens;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AutoVerificationLauncher(),
          const SyncDevicesList(),
          SizedBox(height: tokens.spacing.sectionGap),
          // One secondary grammar for the page's two support actions: both
          // compact, both on the content rail. Full-width and large gave the
          // disconnect the exact geometry of the "Add device" primary above.
          // A Wrap, not a Row: a long localized disconnect label ("Stop
          // syncing this device" is half again as long in German) overflowed
          // a Row whose first child took its intrinsic width unconditionally.
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DesignSystemButton(
                // Destructive but rare, and never the reason someone opened
                // this page: borderless, so the constructive "Add device"
                // above stays the loudest control. Sized to match the
                // diagnostics button beside it — at large + fullWidth it had
                // the exact geometry of that primary.
                variant: DesignSystemButtonVariant.dangerTertiary,
                size: DesignSystemButtonSize.medium,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(messages.syncDeleteConfigQuestion),
                      content: Text(messages.syncDisconnectExplanation),
                      actions: [
                        DesignSystemButton(
                          label: messages.settingsMatrixCancel,
                          variant: DesignSystemButtonVariant.tertiary,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                        DesignSystemButton(
                          label: messages.syncDeleteConfigConfirm,
                          variant: DesignSystemButtonVariant.danger,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                        ),
                      ],
                    ),
                  );
                  if (confirmed ?? false) {
                    try {
                      await matrixService.deleteConfig();
                    } catch (e, stackTrace) {
                      // Silent failure left the pane showing a "configured"
                      // view of a config that had not been torn down, with
                      // nothing said and nothing logged.
                      getIt<DomainLogger>().error(
                        LogDomain.sync,
                        e,
                        stackTrace: stackTrace,
                        subDomain: 'deleteConfig',
                      );
                      if (context.mounted) {
                        context.showToast(
                          tone: DesignSystemToastTone.error,
                          title: messages.syncDisconnectFailed,
                        );
                      }
                      return;
                    }
                    if (!context.mounted) return;
                    ref.read(provisioningControllerProvider.notifier).reset();
                    if (!embedded) await Navigator.of(context).maybePop();
                  }
                },
                label: messages.provisionedSyncDisconnect,
              ),
              // Last and smallest: a diagnostics dump is the least likely
              // reason anyone opens this sheet, and as the first bordered pill
              // in the row it won a weight contest against the account action.
              const DiagnosticInfoButton(),
            ],
          ),
        ],
      ),
    );
  }
}
