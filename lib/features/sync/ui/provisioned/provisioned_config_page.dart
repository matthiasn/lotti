import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

class ProvisionedConfigWidget extends ConsumerStatefulWidget {
  const ProvisionedConfigWidget({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<ProvisionedConfigWidget> createState() =>
      _ProvisionedConfigWidgetState();
}

class _ProvisionedConfigWidgetState
    extends ConsumerState<ProvisionedConfigWidget> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startConfiguration();
    });
  }

  void _startConfiguration() {
    if (_started) return;
    _started = true;
    ref.read(provisioningControllerProvider).when(
          initial: () {},
          bundleDecoded: (bundle) {
            ref
                .read(provisioningControllerProvider.notifier)
                .configureFromBundle(
                  bundle,
                  rotatePassword: isDesktop,
                );
          },
          loggingIn: () {},
          joiningRoom: () {},
          rotatingPassword: () {},
          ready: (_) {},
          done: () {},
          error: (_) {},
        );
  }

  @override
  Widget build(BuildContext context) {
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
      error: (message) => _ErrorView(
        message: message,
        onRetry: () {
          _started = false;
          _startConfiguration();
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

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.handoverBase64});

  final String handoverBase64;

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
                data: handoverBase64,
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
        SelectableText(
          handoverBase64,
          style: context.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView();

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
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

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
          message,
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
