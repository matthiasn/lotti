import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/auto_verification_launcher.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
    child: ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
  );
}

class _ConfigActionBar extends ConsumerWidget {
  const _ConfigActionBar({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final isComplete = state.when(
      initial: () => false,
      bundleDecoded: (_) => false,
      loggingIn: () => false,
      joiningRoom: () => false,
      rotatingPassword: () => false,
      ready: (_) => true,
      done: () => true,
      error: (_) => false,
    );

    // Going back is only safe where rescanning is the remedy. Mid-flight it
    // drops the user onto a live scanner while `configureFromBundle` runs;
    // from the success state, pressing Connect again logs out the working
    // session and retries with a password that has already been rotated away.
    final canGoBack = state.when(
      initial: () => true,
      bundleDecoded: (_) => true,
      loggingIn: () => false,
      joiningRoom: () => false,
      rotatingPassword: () => false,
      ready: (_) => false,
      done: () => false,
      error: (_) => true,
    );

    return SyncStickyBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: DesignSystemButton(
              onPressed: canGoBack ? () => pageIndexNotifier.value = 0 : null,
              label: context.messages.syncPairBack,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
            ),
          ),
          SizedBox(width: context.designTokens.spacing.step2),
          Flexible(
            child: DesignSystemButton(
              onPressed: isComplete ? () => pageIndexNotifier.value = 2 : null,
              // Named for where it lands. "Next Page" says nothing about
              // what the user is about to see, on the one screen where the
              // remaining work is described in terms of that destination.
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
  const ProvisionedConfigWidget({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningControllerProvider);
    final messages = context.messages;

    // Only a `provisioned` bundle rotates the password, so the step count
    // follows the bundle kind. Keying it off the platform made a rotating
    // mobile run count "1/2, 2/2, 3/3".
    final totalSteps =
        ref.read(provisioningControllerProvider.notifier).rotatesPassword
        ? 3
        : 2;

    final body = state.when(
      initial: () => const _ProgressStep(label: '', step: 0, totalSteps: 1),
      bundleDecoded: (_) => const _ProgressStep(
        label: '',
        step: 0,
        totalSteps: 1,
      ),
      loggingIn: () => _ProgressStep(
        label: messages.provisionedSyncLoggingIn,
        step: 1,
        totalSteps: totalSteps,
      ),
      joiningRoom: () => _ProgressStep(
        label: messages.provisionedSyncJoiningRoom,
        step: 2,
        totalSteps: totalSteps,
      ),
      rotatingPassword: () => _ProgressStep(
        label: messages.provisionedSyncRotatingPassword,
        step: 3,
        totalSteps: 3,
      ),
      // A rotated bundle leaves a handover payload behind, but it is the same
      // credential `regenerateHandover()` mints on demand from the persisted
      // config — so pairing the next device belongs to "Add device" on the
      // roster, not to a second QR on the screen that just consumed one.
      ready: (_) => _PairedView(pageIndexNotifier: pageIndexNotifier),
      done: () => _PairedView(pageIndexNotifier: pageIndexNotifier),
      error: (error) => _ErrorView(
        error: error,
        onRetry: () {
          ref.read(provisioningControllerProvider.notifier).retry();
        },
      ),
    );

    // The same position line the scan and confirm screens carry — but naming
    // what step 3 is *doing*. A constant "Finish" printed above a spinner, a
    // red error card, or a card headed "Two things left" is a lie in all three.
    final stepLabel = state.when(
      initial: () => messages.syncPairStepConnecting,
      bundleDecoded: (_) => messages.syncPairStepConnecting,
      loggingIn: () => messages.syncPairStepConnecting,
      joiningRoom: () => messages.syncPairStepConnecting,
      rotatingPassword: () => messages.syncPairStepConnecting,
      ready: (_) => messages.syncPairStepAlmost,
      done: () => messages.syncPairStepAlmost,
      error: (_) => messages.syncPairStepFailed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncPairStepIndicator(label: stepLabel),
        body,
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.step,
    required this.totalSteps,
  });

  final String label;
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SyncFlowSection(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: tokens.spacing.step6),
          const DesignSystemSpinner(),
          SizedBox(height: tokens.spacing.step6),
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle1,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.step3),
            // Deliberately carries no "2 / 3" caption: this bar measures
            // progress *within* the final step, and a second fraction beside
            // "Step 3 of 3" reads as a contradiction.
            DesignSystemProgressBar(
              key: const Key('provisioned_config_progress'),
              value: step / totalSteps,
              semanticsLabel: label,
            ),
          ],
          SizedBox(height: tokens.spacing.step2),
        ],
      ),
    );
  }
}

/// Success, plus the two things that are genuinely still outstanding: the SAS
/// ceremony (auto-launched here) and the settings push, which only the other
/// device can perform.
class _PairedView extends ConsumerWidget {
  const _PairedView({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // One source for "is the ceremony done", used by the card's title and by
    // the step body. Computed separately, they contradicted each other: the
    // card said "Two things left" and carried an imperative at full weight
    // while a green check one line below said the same step was complete.
    final devices = ref.watch(syncDevicesControllerProvider).value;
    final verified =
        devices?.any((d) => !d.isCurrentDevice && d.verified) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutoVerificationLauncher(),
        // A single quiet line: connecting is the part that is already
        // finished, and it must not out-shout the card below it, which says
        // this device still cannot read anything.
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: tokens.spacing.step5,
              color: tokens.colors.alert.success.defaultColor,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                messages.provisionedSyncDone,
                style: tokens.typography.styles.subtitle.subtitle1,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        SyncFlowSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                verified
                    ? messages.syncPairedNextTitleOne
                    : messages.syncPairedNextTitle,
                style: tokens.typography.styles.subtitle.subtitle1,
              ),
              SizedBox(height: tokens.spacing.step4),
              // Once verification is done, the outstanding item leads and the
              // finished one closes: a card headed "One thing left" that opens
              // with a paragraph about completed work spends the reader's
              // first fixation on nothing they can act on.
              //
              // Numerals only while the list is genuinely ordered — "2." under
              // a title saying one thing is left sent the reader hunting for a
              // missing first item.
              if (verified) ...[
                _NextStep(
                  index: 2,
                  bulleted: true,
                  text: messages.syncPairedSettingsStep,
                  detail: messages.syncPairedSettingsStepFallback,
                ),
                SizedBox(height: tokens.spacing.step4),
                const _VerifyStep(verified: true),
              ] else ...[
                const _VerifyStep(verified: false),
                SizedBox(height: tokens.spacing.step4),
                _NextStep(
                  index: 2,
                  text: messages.syncPairedSettingsStep,
                  detail: messages.syncPairedSettingsStepFallback,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// How long the emoji prompt may be absent before the fallback is offered.
/// The keys usually arrive in a second or two; a minute of unexplained spinner
/// on the step that gates readability is what made this feel broken.
const Duration kVerifyStallTimeout = Duration(seconds: 20);

/// Step 1 with live state, in three branches: waiting, awaiting the user's
/// confirmation, and done.
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

  /// Reopens the ceremony for a device that is already awaiting confirmation.
  /// Re-querying cannot help there — the prompt arrived and was dismissed.
  void _showAgain() =>
      ref.read(matrixVerificationRelaunchProvider.notifier).request();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final unverified = ref.watch(matrixUnverifiedControllerProvider).value;
    final verified = widget.verified;
    final awaitingConfirmation = unverified != null && unverified.isNotEmpty;
    // The live state of a security-critical step; at lowEmphasis it was the
    // faintest thing on the page while being the only part still moving.
    final statusStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    if (verified) _stallTimer?.cancel();

    // The fallback names the roster rather than rendering a second door to it:
    // the sticky bar's "Go to Devices" is a few centimetres away, and two
    // controls with the same label read as two different destinations.
    Widget fallback({required bool dismissed}) => Column(
      key: const Key('paired_verify_fallback'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(messages.syncPairedVerifyFallback, style: statusStyle),
        SizedBox(height: tokens.spacing.step2),
        // Two different situations, two different remedies. A prompt that
        // arrived and was dismissed needs reopening; one that never arrived
        // needs the trust state re-read.
        DesignSystemButton(
          key: const Key('paired_verify_recheck'),
          label: dismissed
              ? messages.syncPairShowEmojiAgain
              : messages.syncPairCheckAgain,
          variant: DesignSystemButtonVariant.outlined,
          onPressed: dismissed ? _showAgain : _recheck,
        ),
      ],
    );

    if (verified) {
      // Past tense, through the same row component as its sibling: appending a
      // green line under a live imperative left the screen asserting two
      // opposite things about the same fact, on two different grids.
      return _NextStep(
        key: const Key('paired_verify_done'),
        index: 1,
        text: messages.syncPairedVerifyStepDone,
        done: true,
      );
    }

    final Widget status;
    if (awaitingConfirmation) {
      status = fallback(dismissed: true);
    } else {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const Key('paired_verify_waiting'),
            children: [
              DesignSystemSpinner(
                size: tokens.spacing.step4,
                strokeWidth: tokens.spacing.step1 / 2,
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
          // A prompt that never comes is the one case where waiting is not
          // the answer, and it was the only case with no remedy on screen.
          if (_stalled) ...[
            SizedBox(height: tokens.spacing.step2),
            fallback(dismissed: false),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NextStep(index: 1, text: messages.syncPairedVerifyStep),
        SizedBox(height: tokens.spacing.step2),
        Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step6),
          child: status,
        ),
      ],
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.index,
    required this.text,
    super.key,
    this.detail,
    this.done = false,
    this.bulleted = false,
  });

  final int index;
  final String text;

  /// A fallback route, kept off the main line: inlining it forced the item to
  /// wrap to seven short lines on the narrowest measure in the journey.
  final String? detail;

  /// Swaps the ordinal for a check and drops the ink — but keeps the type
  /// rank, so a completed row still sits on the list's grid rather than
  /// becoming a smaller, dimmer thing nested under it.
  final bool done;

  /// Swaps the ordinal for a neutral marker. A single outstanding item does
  /// not need a number, and numbering it "2." contradicts the count above it.
  final bool bulleted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final detail = this.detail;
    final body = tokens.typography.styles.body.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (done)
          Icon(
            Icons.check_circle_rounded,
            size: tokens.spacing.step5,
            color: tokens.colors.alert.success.defaultColor,
          )
        else if (bulleted)
          Icon(
            Icons.radio_button_unchecked_rounded,
            size: tokens.spacing.step5,
            color: tokens.colors.text.mediumEmphasis,
          )
        else
          Text(
            '$index.',
            style: body.copyWith(color: tokens.colors.text.mediumEmphasis),
          ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: body.copyWith(
                  color: done
                      ? tokens.colors.text.mediumEmphasis
                      : tokens.colors.text.highEmphasis,
                ),
              ),
              if (detail != null) ...[
                SizedBox(height: tokens.spacing.step2),
                Text(
                  detail,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final ProvisioningError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final errorMessage = switch (error) {
      ProvisioningError.loginFailed => messages.provisionedSyncErrorLoginFailed,
      ProvisioningError.configurationError =>
        messages.provisionedSyncErrorConfigurationFailed,
    };

    return SyncFlowSection(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: tokens.spacing.step6),
          Icon(
            Icons.error_outline,
            size: tokens.spacing.step10,
            color: tokens.colors.alert.error.defaultColor,
          ),
          SizedBox(height: tokens.spacing.step6),
          Text(
            messages.provisionedSyncError,
            style: tokens.typography.styles.subtitle.subtitle1,
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            errorMessage,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.step6),
          DesignSystemButton(
            onPressed: onRetry,
            label: messages.provisionedSyncRetry,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
      ),
    );
  }
}
