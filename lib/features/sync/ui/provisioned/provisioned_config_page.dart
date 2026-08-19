import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/auto_verification_launcher.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:lotti/features/sync/ui/widgets/sync_wizard_progress_track.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Below this width the error bar stacks its two remedies: their labels are
/// deliberately spelled out ("Retry this code" / "Enter a new code"), and
/// side by side on a phone sheet they truncate into indistinguishability.
const double kSyncErrorActionRowMinWidth = 420;

SliverWoltModalSheetPage provisionedConfigPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _ConfigActionBar(pageIndexNotifier: pageIndexNotifier),
    // The setup flow's own title. Reusing the roster's name titled a sheet
    // "Devices" that also contains a "Devices" section header.
    title: context.messages.provisionedSyncImportTitle,
    padding:
        WoltModalConfig.pagePadding +
        const EdgeInsets.only(
          bottom: WoltModalConfig.stickyActionBarClearance,
        ),
    child: const ProvisionedConfigWidget(),
  );
}

class _ConfigActionBar extends ConsumerWidget {
  const _ConfigActionBar({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  /// Whether the paired screen still gates on the emoji ceremony. The `done`
  /// ending is the only one with a checklist; `ready` (first device) has
  /// nothing outstanding and keeps the accent on Go to Devices.
  bool _ceremonyOutstanding(WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final isDone = state.maybeWhen(done: () => true, orElse: () => false);
    if (!isDone) return false;
    final devices = ref.watch(syncDevicesControllerProvider).value;
    final verified =
        devices?.any((d) => !d.isCurrentDevice && d.verified) ?? false;
    return !verified;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final isComplete = state.maybeWhen(
      ready: (_) => true,
      done: () => true,
      orElse: () => false,
    );
    final isError = state.maybeWhen(error: (_) => true, orElse: () => false);

    // Going back is only safe where rescanning is the remedy. Mid-flight it
    // drops the user onto a live scanner while `configureFromBundle` runs;
    // from the success state, pressing Connect again logs out the working
    // session and retries with a password that has already been rotated away.
    final canGoBack = state.maybeWhen(
      initial: () => true,
      bundleDecoded: (_) => true,
      orElse: () => false,
    );

    if (isError) {
      // The accent belongs on "Enter a new code": a rejected login usually
      // means the code predates a password rotation (the first pairing from
      // a CLI bundle rotates it) or was mangled in transit, and both are
      // fixed by fetching a fresh code — never by re-attempting this one.
      // Retry stays for the transient-network case, demoted: as the accent
      // it re-attempted exactly the credential that just failed.
      final retry = DesignSystemButton(
        key: const Key('provisioned_config_retry'),
        onPressed: () =>
            ref.read(provisioningControllerProvider.notifier).retry(),
        label: context.messages.syncPairRetryThisCode,
        variant: DesignSystemButtonVariant.secondary,
        size: DesignSystemButtonSize.large,
      );
      final newCode = DesignSystemButton(
        key: const Key('provisioned_config_new_code'),
        onPressed: () {
          // Reset first: the import page listens for the return to
          // the initial state and clears its stale decoded bundle.
          ref.read(provisioningControllerProvider.notifier).reset();
          pageIndexNotifier.value = 0;
        },
        label: context.messages.syncPairEnterNewCode,
        size: DesignSystemButtonSize.large,
      );
      return SyncStickyBar(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The whole point of this bar is the distinction between the two
            // remedies — two ellipsized halves of a phone-width row erase it,
            // and German/Swedish labels don't fit side by side. Stack below
            // the same breakpoint the pairing card uses, accent on top.
            if (constraints.maxWidth < kSyncErrorActionRowMinWidth) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  newCode,
                  SizedBox(height: context.designTokens.spacing.step3),
                  retry,
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: retry),
                SizedBox(width: context.designTokens.spacing.step2),
                Flexible(child: newCode),
              ],
            );
          },
        ),
      );
    }

    final ceremonyOutstanding = _ceremonyOutstanding(ref);

    return SyncStickyBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ceremonyOutstanding
                // Back is unsafe from the done state, and the ceremony is the
                // one thing left — the quiet slot points at the roster
                // instead.
                ? DesignSystemButton(
                    onPressed: () => pageIndexNotifier.value = 2,
                    label: context.messages.syncPairGoToDevices,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.large,
                  )
                : DesignSystemButton(
                    onPressed: canGoBack
                        ? () => pageIndexNotifier.value = 0
                        : null,
                    label: context.messages.syncPairBack,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.large,
                  ),
          ),
          SizedBox(width: context.designTokens.spacing.step2),
          Flexible(
            // One accent slot, filled by whatever the user should press next:
            // the ceremony while it gates everything, the roster afterwards.
            //
            // Disabled until a ceremony target exists: right after the
            // handover the peer's device keys are often still in flight, the
            // unverified list is empty, and a relaunch request would vanish
            // into a launcher with nothing to relaunch. The launcher opens
            // the ceremony on its own the moment the keys land; the button
            // enables at the same moment, for reopening a dismissed sheet.
            child: ceremonyOutstanding
                ? DesignSystemButton(
                    key: const Key('provisioned_config_show_emoji'),
                    onPressed:
                        (ref.watch(matrixUnverifiedControllerProvider).value ??
                                [])
                            .isEmpty
                        ? null
                        : () => ref
                              .read(matrixVerificationRelaunchProvider.notifier)
                              .request(),
                    label: context.messages.syncPairShowEmoji,
                    size: DesignSystemButtonSize.large,
                  )
                : DesignSystemButton(
                    onPressed: isComplete
                        ? () => pageIndexNotifier.value = 2
                        : null,
                    // Named for where it lands. "Next Page" says nothing
                    // about what the user is about to see.
                    label: context.messages.syncPairGoToDevices,
                    size: DesignSystemButtonSize.large,
                  ),
          ),
        ],
      ),
    );
  }
}

class ProvisionedConfigWidget extends ConsumerWidget {
  const ProvisionedConfigWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final messages = context.messages;

    // The three endings own their screens; the progress track belongs to the
    // journey and disappears once the journey has ended one way or another.
    final inFlight = state.maybeWhen(
      ready: (_) => false,
      done: () => false,
      error: (_) => false,
      orElse: () => true,
    );

    final body = state.when(
      initial: () => const _ConnectingView(label: ''),
      bundleDecoded: (_) => const _ConnectingView(label: ''),
      loggingIn: () => _ConnectingView(
        label: messages.provisionedSyncLoggingIn,
      ),
      joiningRoom: () => _ConnectingView(
        label: messages.provisionedSyncJoiningRoom,
      ),
      rotatingPassword: () => _ConnectingView(
        label: messages.provisionedSyncRotatingPassword,
      ),
      // `ready` and `done` are not the same ending. `ready` follows a fresh
      // CLI `provisioned` bundle, so this is usually the account's *first*
      // device: there is no peer to run an emoji ceremony with and none to
      // push settings from, and showing the two-outstanding-steps card told
      // that user to wait on a device that does not exist. `done` follows a
      // peer handover, so a peer demonstrably exists.
      //
      // A rotated bundle leaves a handover payload behind, but it is the same
      // credential `regenerateHandover()` mints on demand from the persisted
      // config — so pairing the next device belongs to "Add device" on the
      // roster, not to a second QR on the screen that just consumed one.
      ready: (_) => const _FirstDeviceView(),
      done: () => const _PairedView(),
      error: (error) => _ErrorView(error: error),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inFlight) ...[
          const SyncWizardProgressTrack(active: SyncWizardStep.connect),
          SizedBox(height: context.designTokens.spacing.sectionGap),
        ],
        body,
      ],
    );
  }
}

/// The wait, narrated by the journey's own figure: dots streaming from this
/// device toward the account it is joining, over the phase currently running.
class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      children: [
        SizedBox(height: tokens.spacing.step6),
        const SyncDevicePairMotif(
          state: SyncDevicePairMotifState.connecting,
        ),
        if (label.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step6),
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle1,
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: tokens.spacing.step6),
      ],
    );
  }
}

/// The end of a fresh provisioning run: this device is the account, and
/// nothing is outstanding. Deliberately not [_PairedView] — there is no peer
/// to verify against and none to receive settings from, so both of that
/// screen's remaining steps would be unperformable. Quiet success, no false
/// checklist.
class _FirstDeviceView extends StatelessWidget {
  const _FirstDeviceView();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      key: const Key('paired_first_device'),
      children: [
        SizedBox(height: tokens.spacing.step6),
        _StateFigure(
          background: tokens.colors.surface.selected,
          child: Icon(
            LottiIcons.confirm,
            size: IconSizes.xl,
            color: tokens.colors.interactive.enabled,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.syncPairedFirstDeviceTitle,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
          child: Text(
            messages.syncPairedFirstDeviceBody,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
      ],
    );
  }
}

/// Success, honest about the gate: connected, plus the two steps that stand
/// between this device and readable entries — the SAS ceremony (auto-launched
/// here, re-launchable from the bar's accent) and the settings push only the
/// other device can perform.
class _PairedView extends ConsumerWidget {
  const _PairedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // One source for "is the ceremony done", used by the checklist and the
    // sticky bar. Computed separately, they contradicted each other.
    final devices = ref.watch(syncDevicesControllerProvider).value;
    final verified =
        devices?.any((d) => !d.isCurrentDevice && d.verified) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutoVerificationLauncher(),
        Row(
          children: [
            _StateFigure(
              size: IconSizes.xxxl,
              background: tokens.colors.surface.selected,
              child: Icon(
                LottiIcons.confirm,
                size: IconSizes.l,
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages.provisionedSyncDone,
                    style: tokens.typography.styles.heading.heading3,
                  ),
                  if (!verified)
                    Text(
                      messages.syncPairedStepsLeft,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step5),
        // The gate, drawn as a gate: the ceremony leads with the accent
        // while it blocks everything; the settings hand-off waits behind a
        // lock until the ceremony opens it.
        SyncWell(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VerifyStep(verified: verified),
              Divider(
                height: tokens.spacing.step1 / 2,
                thickness: tokens.spacing.step1 / 2,
                color: tokens.colors.decorative.level01,
              ),
              _GateStep(
                index: 2,
                state: verified ? _GateState.active : _GateState.locked,
                title: messages.syncPairedSettingsStepTitle,
                body: messages.syncPairedSettingsStep,
                detail: verified
                    ? messages.syncPairedSettingsStepFallback
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A circular tinted figure behind a state icon — the endings' shared anchor.
class _StateFigure extends StatelessWidget {
  const _StateFigure({
    required this.background,
    required this.child,
    this.size,
  });

  final Color background;
  final Widget child;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final side = size ?? tokens.spacing.step10;

    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: SizedBox(
        width: side,
        height: side,
        child: Center(child: child),
      ),
    );
  }
}

enum _GateState { active, locked, done }

/// One rung of the paired screen's gate checklist: numbered marker, title,
/// caption — with the accent edge while it is the thing to do, a lock while
/// it cannot be done yet, and a check once it is behind the user.
class _GateStep extends StatelessWidget {
  const _GateStep({
    required this.index,
    required this.state,
    required this.title,
    required this.body,
    super.key,
    this.detail,
    this.statusChild,
  });

  final int index;
  final _GateState state;
  final String title;
  final String body;

  /// A fallback route, kept off the main line: inlining it forced the item
  /// to wrap to seven short lines on the narrowest measure in the journey.
  final String? detail;

  /// Live progress content rendered under the body (spinner, fallback).
  final Widget? statusChild;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locked = state == _GateState.locked;
    final done = state == _GateState.done;
    final detail = this.detail;
    final statusChild = this.statusChild;

    final Widget marker;
    if (done) {
      marker = Icon(
        LottiIcons.confirmCircled,
        size: IconSizes.l,
        color: tokens.colors.alert.success.defaultColor,
      );
    } else {
      final ring = locked
          ? tokens.colors.decorative.level02
          : tokens.colors.interactive.enabled;
      marker = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: BorderWidths.emphasis),
        ),
        child: SizedBox(
          width: tokens.spacing.step6,
          height: tokens.spacing.step6,
          child: Center(
            child: Text(
              '$index',
              style: tokens.typography.styles.others.caption.copyWith(
                fontWeight: tokens.typography.weight.bold,
                color: locked
                    ? tokens.colors.text.mediumEmphasis
                    : tokens.colors.interactive.enabled,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: state == _GateState.active
            ? Border(
                left: BorderSide(
                  color: tokens.colors.interactive.enabled,
                  width: BorderWidths.emphasis,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            marker,
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: locked || done
                                    ? tokens.colors.text.mediumEmphasis
                                    : tokens.colors.text.highEmphasis,
                              ),
                        ),
                      ),
                      if (locked) ...[
                        SizedBox(width: tokens.spacing.step2),
                        Icon(
                          LottiIcons.lock,
                          size: IconSizes.xs,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    body,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: locked
                          ? tokens.colors.text.lowEmphasis
                          : tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                  if (detail != null) ...[
                    SizedBox(height: tokens.spacing.step2),
                    Text(
                      detail,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ],
                  if (statusChild != null) ...[
                    SizedBox(height: tokens.spacing.step3),
                    statusChild,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How long the emoji prompt may be absent before the fallback is offered.
/// The keys usually arrive in a second or two; a minute of unexplained spinner
/// on the step that gates readability is what made this feel broken.
const Duration kVerifyStallTimeout = Duration(seconds: 20);

/// Step 1 with live state, in three branches: waiting, stalled, and done.
///
/// The done branch is not cosmetic. Absence from `getUnverifiedDevices()` means
/// *both* "keys have not arrived yet" and "the ceremony succeeded", so a
/// two-branch version told a user who had just matched the emoji that they were
/// still waiting for it — on the terminal screen of the whole flow. Success is
/// therefore read off the roster, the same signal the device cards badge with.
class _VerifyStep extends ConsumerStatefulWidget {
  const _VerifyStep({required this.verified});

  /// Whether a peer on the roster is verified — the ceremony's only durable
  /// success signal, since a verified device drops out of the unverified set
  /// exactly as an unpaired one does.
  final bool verified;

  @override
  ConsumerState<_VerifyStep> createState() => _VerifyStepState();
}

class _VerifyStepState extends ConsumerState<_VerifyStep> {
  /// True once the prompt has failed to appear for long enough that telling
  /// the user to keep waiting is no longer honest.
  bool _stalled = false;
  Timer? _stallTimer;

  @override
  void initState() {
    super.initState();
    _stallTimer = Timer(kVerifyStallTimeout, () {
      if (mounted) setState(() => _stalled = true);
    });
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    super.dispose();
  }

  /// Re-reads both sides of the trust state. The ceremony completes out of
  /// band, so "nothing happened" and "it worked and nobody told this screen"
  /// look identical until something asks again.
  void _recheck() {
    ref
      ..invalidate(matrixUnverifiedControllerProvider)
      ..invalidate(syncDevicesControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final verified = widget.verified;
    final statusStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    if (verified) {
      _stallTimer?.cancel();
      return _GateStep(
        key: const Key('paired_verify_done'),
        index: 1,
        state: _GateState.done,
        title: messages.syncPairedVerifyStepTitle,
        body: messages.syncPairedVerifyStepDone,
      );
    }

    final status = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The spinner stays even once stalled — the ceremony may still
        // arrive — but waiting stops being the only story on screen.
        Row(
          key: const Key('paired_verify_waiting'),
          children: [
            const DesignSystemSpinner(
              size: IconSizes.xs,
              strokeWidth: BorderWidths.hairline,
            ),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: Text(
                messages.syncPairedVerifyWaiting,
                style: statusStyle,
              ),
            ),
          ],
        ),
        if (_stalled) ...[
          SizedBox(height: tokens.spacing.step3),
          // A prompt that never comes is the one case where waiting is not
          // the answer, and it was the only case with no remedy on screen.
          // The dismissed-prompt case is served by the bar's accent.
          Column(
            key: const Key('paired_verify_fallback'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(messages.syncPairedVerifyFallback, style: statusStyle),
              SizedBox(height: tokens.spacing.step2),
              DesignSystemButton(
                key: const Key('paired_verify_recheck'),
                label: messages.syncPairCheckAgain,
                variant: DesignSystemButtonVariant.outlined,
                onPressed: _recheck,
              ),
            ],
          ),
        ],
      ],
    );

    return _GateStep(
      index: 1,
      state: _GateState.active,
      title: messages.syncPairedVerifyStepTitle,
      body: messages.syncPairedVerifyStep,
      statusChild: status,
    );
  }
}

/// The failure ending: what went wrong and why, without its own button — the
/// remedies live in the sticky bar, where "Enter a new code" carries the
/// accent because a stale code is the usual culprit.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final ProvisioningError error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final errorMessage = switch (error) {
      ProvisioningError.loginFailed => messages.provisionedSyncErrorLoginFailed,
      ProvisioningError.configurationError =>
        messages.provisionedSyncErrorConfigurationFailed,
    };

    return Column(
      children: [
        SizedBox(height: tokens.spacing.step6),
        _StateFigure(
          background: tokens.colors.alert.error.defaultColor.withValues(
            alpha: 0.16,
          ),
          child: Icon(
            LottiIcons.error,
            size: IconSizes.xl,
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.provisionedSyncError,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
          child: Text(
            errorMessage,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
      ],
    );
  }
}
