import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
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
import 'package:lotti/widgets/modal/confirmation_modal.dart';
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
          // The destructive zone sits below its own hairline at the very
          // end: signing this device out is never the reason the page was
          // opened, and the divider is what keeps it from reading as one
          // more card action.
          const DesignSystemDivider(),
          SizedBox(height: tokens.spacing.step4),
          // One secondary grammar for the page's two support actions: both
          // compact, both on the content rail, and — now — both at the same
          // size. They were medium and small, which is two pill geometries
          // for a pair this comment claimed were "sized to match".
          // A Wrap, not a Row: a long localized disconnect label ("Stop
          // syncing this device" is half again as long in German) overflowed
          // a Row whose first child took its intrinsic width unconditionally.
          // runSpacing is a section step because on a phone these two always
          // wrap onto separate runs, and a destructive action must not sit
          // one hairline above a benign one.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DesignSystemButton(
                  // Destructive but rare, and never the reason someone opened
                  // this page: borderless, so the constructive "Add device"
                  // above stays the loudest control. The icon keeps the
                  // destructive reading legible without relying on hue alone.
                  //
                  // alignsLabelToLeadingEdge because a borderless button's
                  // horizontal padding has nothing to make it legible as
                  // padding: the outlined pill beside it has the same inset,
                  // but its stroke sits on the rail and the eye reads the
                  // stroke. Without the flag this glyph simply looked indented
                  // by step4, giving the footer three left edges in a 12pt
                  // band. DiagnosticInfoButton must NOT take the flag — with
                  // a border, the pull would hang the stroke outside the rail.
                  variant: DesignSystemButtonVariant.dangerTertiary,
                  alignsLabelToLeadingEdge: true,
                  leadingIcon: LottiIcons.linkOff,
                  onPressed: () async {
                    // The app's destructive-confirm grammar, the same one the
                    // per-device removal uses: warning glyph, title, and
                    // action-bar buttons. This is the account-level action —
                    // it signs *this* device out of sync entirely — and it
                    // used to get a bare AlertDialog, a weaker guard than the
                    // narrower per-device delete beside it.
                    final confirmed = await showConfirmationModal(
                      context: context,
                      title: messages.syncDeleteConfigQuestion,
                      message: messages.syncDisconnectExplanation,
                      confirmLabel: messages.syncDeleteConfigConfirm,
                      cancelLabel: messages.settingsMatrixCancel,
                    );
                    if (confirmed) {
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
          ),
        ],
      ),
    );
  }
}
