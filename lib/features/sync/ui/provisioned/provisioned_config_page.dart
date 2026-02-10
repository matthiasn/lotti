import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
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

    return Padding(
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
              onPressed: isComplete ? () => pageIndexNotifier.value = 2 : null,
              label: context.messages.settingsMatrixNextPage,
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
      ready: (handoverBase64) => _ReadyView(handoverBase64: handoverBase64),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          label,
          style: context.textTheme.titleMedium,
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
      ],
    );
  }
}

class _ReadyView extends StatefulWidget {
  const _ReadyView({required this.handoverBase64});

  final String handoverBase64;

  @override
  State<_ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends State<_ReadyView> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Column(
      children: [
        const SizedBox(height: 20),
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
                await Clipboard.setData(
                  ClipboardData(text: widget.handoverBase64),
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.messages.provisionedSyncCopiedToClipboard,
                    ),
                  ),
                );
              },
            ),
          ],
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
  bool _verificationTriggered = false;

  @override
  void initState() {
    super.initState();
    _autoTriggerVerification();
  }

  Future<void> _autoTriggerVerification() async {
    // Wait for Matrix SDK to sync device keys from server
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _verificationTriggered) return;

    final matrixService = ref.read(matrixServiceProvider);
    final unverifiedDevices = matrixService.getUnverifiedDevices();
    if (unverifiedDevices.isNotEmpty && mounted) {
      setState(() => _verificationTriggered = true);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => VerificationModal(unverifiedDevices.first),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
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
    final messages = context.messages;
    final errorMessage = switch (error) {
      ProvisioningError.loginFailed => messages.provisionedSyncErrorLoginFailed,
      ProvisioningError.configurationError =>
        messages.provisionedSyncErrorConfigurationFailed,
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
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
      ],
    );
  }
}
