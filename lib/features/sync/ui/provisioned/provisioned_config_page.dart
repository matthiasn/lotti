import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage provisionedConfigPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: _ConfigActionBar(pageIndexNotifier: pageIndexNotifier),
    title: context.messages.provisionedSyncImportTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
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

    return ColoredBox(
      color: context.colorScheme.surface,
      child: Padding(
        padding: WoltModalConfig.pagePadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: OutlinedButton(
                onPressed: () => pageIndexNotifier.value = 0,
                child: Text(context.messages.settingsMatrixPreviousPage),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LottiPrimaryButton(
                onPressed:
                    isComplete ? () => pageIndexNotifier.value = 2 : null,
                label: context.messages.settingsMatrixNextPage,
              ),
            ),
          ],
        ),
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

    return state.when(
      initial: () => const Center(child: CircularProgressIndicator()),
      bundleDecoded: (_) => const Center(child: CircularProgressIndicator()),
      loggingIn: () => _ProgressStep(
        label: messages.provisionedSyncLoggingIn,
        step: 1,
        totalSteps: isDesktop ? 3 : 2,
      ),
      joiningRoom: () => _ProgressStep(
        label: messages.provisionedSyncJoiningRoom,
        step: 2,
        totalSteps: isDesktop ? 3 : 2,
      ),
      rotatingPassword: () => _ProgressStep(
        label: messages.provisionedSyncRotatingPassword,
        step: 3,
        totalSteps: 3,
      ),
      ready: (handoverBase64) => _ReadyView(
        handoverBase64: handoverBase64,
        pageIndexNotifier: pageIndexNotifier,
      ),
      done: () => const _DoneView(),
      error: (error) => _ErrorView(
        error: error,
        onRetry: () {
          ref.read(provisioningControllerProvider.notifier).retry();
        },
      ),
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
    return SyncFlowSection(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            label,
            style: context.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: step / totalSteps,
          ),
          const SizedBox(height: 8),
          Text(
            '$step / $totalSteps',
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReadyView extends ConsumerStatefulWidget {
  const _ReadyView({
    required this.handoverBase64,
    required this.pageIndexNotifier,
  });

  final String handoverBase64;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<_ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends ConsumerState<_ReadyView> {
  bool _revealed = false;
  bool _autoAdvancedToStatus = false;
  bool _advanceCheckInFlight = false;
  StreamSubscription<KeyVerificationRunner>? _outgoingSub;
  StreamSubscription<KeyVerificationRunner>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _subscribeVerificationStreams();
  }

  @override
  void dispose() {
    _outgoingSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  void _subscribeVerificationStreams() {
    final matrixService = ref.read(matrixServiceProvider);

    Future<bool> waitUntilNoUnverifiedDevices() async {
      const attempts = 20;
      const delay = Duration(milliseconds: 350);

      for (var i = 0; i < attempts; i++) {
        if (!mounted) return false;
        ref.invalidate(matrixUnverifiedControllerProvider);
        if (matrixService.getUnverifiedDevices().isEmpty) {
          return true;
        }
        await Future<void>.delayed(delay);
      }

      if (!mounted) return false;
      ref.invalidate(matrixUnverifiedControllerProvider);
      return matrixService.getUnverifiedDevices().isEmpty;
    }

    Future<void> maybeAdvance(KeyVerificationRunner runner) async {
      final isDone = runner.lastStep == 'm.key.verification.done' ||
          runner.keyVerification.isDone;
      if (!isDone ||
          _autoAdvancedToStatus ||
          _advanceCheckInFlight ||
          !isDesktop) {
        return;
      }

      _advanceCheckInFlight = true;
      try {
        final noUnverifiedDevices = await waitUntilNoUnverifiedDevices();
        if (!mounted || _autoAdvancedToStatus || !noUnverifiedDevices) return;

        _autoAdvancedToStatus = true;
        widget.pageIndexNotifier.value = 2;
      } finally {
        _advanceCheckInFlight = false;
      }
    }

    _outgoingSub = matrixService.keyVerificationStream.listen((runner) {
      unawaited(maybeAdvance(runner));
    });
    _incomingSub = matrixService.incomingKeyVerificationRunnerStream.listen(
      (runner) => unawaited(maybeAdvance(runner)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Column(
      children: [
        SyncFlowSection(
          child: Column(
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: widget.handoverBase64,
                      padding: EdgeInsets.zero,
                      size: 240,
                      key: const Key('provisionedQrImage'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                messages.provisionedSyncReady,
                style: context.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _revealed
                        ? SelectableText(
                            widget.handoverBase64,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          )
                        : Text(
                            '\u2022' * 24,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                  ),
                  IconButton(
                    key: const Key('toggleHandoverVisibility'),
                    icon: Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
                  IconButton(
                    key: const Key('copyHandoverData'),
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final copiedMessage =
                          context.messages.provisionedSyncCopiedToClipboard;
                      await Clipboard.setData(
                        ClipboardData(text: widget.handoverBase64),
                      );
                      messenger.showSnackBar(
                        SnackBar(content: Text(copiedMessage)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneView extends ConsumerStatefulWidget {
  const _DoneView();

  @override
  ConsumerState<_DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends ConsumerState<_DoneView> {
  Timer? _delayTimer;
  bool _verificationTriggered = false;

  @override
  void initState() {
    super.initState();
    // Wait for Matrix SDK to sync device keys from server before checking
    _delayTimer = Timer(const Duration(seconds: 3), _triggerVerification);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerVerification() async {
    if (!mounted || _verificationTriggered) return;

    final matrixService = ref.read(matrixServiceProvider);
    final unverifiedDevices = matrixService.getUnverifiedDevices();
    if (unverifiedDevices.isNotEmpty && mounted) {
      final lock = ref.read(matrixVerificationModalLockProvider.notifier);
      if (!lock.tryAcquire()) return;
      setState(() => _verificationTriggered = true);
      try {
        await showVerificationModalSheet(
          context: context,
          title: context.messages.settingsMatrixVerifyLabel,
          child: VerificationModal(unverifiedDevices.first),
        );
      } finally {
        if (mounted) {
          ref.invalidate(matrixUnverifiedControllerProvider);
        }
        lock.release();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SyncFlowSection(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: context.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            context.messages.provisionedSyncDone,
            style: context.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
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
          const SizedBox(height: 24),
          Icon(
            Icons.error_outline,
            size: 64,
            color: context.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            messages.provisionedSyncError,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: context.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LottiSecondaryButton(
            onPressed: onRetry,
            label: messages.provisionedSyncRetry,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
