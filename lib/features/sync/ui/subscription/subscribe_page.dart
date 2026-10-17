import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/sync_setup_entry.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// First page of the subscribe sheet: plan choice, then waiting for the
/// browser checkout. Once paid it hands over to the connect page, which the
/// pairing-code journey shares.
SliverWoltModalSheetPage subscribePage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    title: context.messages.syncSubscribeTitle,
    padding: WoltModalConfig.pagePadding,
    child: SubscribeBody(pageIndexNotifier: pageIndexNotifier),
  );
}

class SubscribeBody extends ConsumerStatefulWidget {
  const SubscribeBody({required this.pageIndexNotifier, super.key});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<SubscribeBody> createState() => _SubscribeBodyState();
}

class _SubscribeBodyState extends ConsumerState<SubscribeBody> {
  @override
  void initState() {
    super.initState();
    // A checkout left open, or paid while the app was closed, continues.
    unawaited(ref.read(syncSubscriptionControllerProvider.notifier).resume());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncSubscriptionControllerProvider, (_, next) {
      if (next is SyncSubscribeConnecting) {
        widget.pageIndexNotifier.value = SyncSetupPage.connect;
      }
    });
    final state = ref.watch(syncSubscriptionControllerProvider);
    final controller = ref.read(syncSubscriptionControllerProvider.notifier);

    return switch (state) {
      SyncSubscribeOpening() => _Progress(
        context.messages.syncSubscribeOpening,
      ),
      SyncSubscribeClaiming() ||
      SyncSubscribeConnecting() ||
      SyncSubscribeDone() => _Progress(context.messages.syncSubscribeClaiming),
      SyncSubscribeAwaitingPayment(:final checkoutUrl) => _AwaitingPayment(
        canReopen: checkoutUrl != null,
        onReopen: controller.reopenCheckout,
        onCancel: controller.cancel,
      ),
      SyncSubscribeIdle() => _PlanChoice(onChoose: controller.subscribe),
      SyncSubscribeCheckoutExpired() => _PlanChoice(
        notice: context.messages.syncSubscribeExpired,
        onChoose: controller.subscribe,
      ),
      SyncSubscribeFailed(:final failure) => _PlanChoice(
        notice: _failureMessage(context.messages, failure),
        noticeIsError: true,
        onChoose: controller.subscribe,
      ),
    };
  }

  static String _failureMessage(
    AppLocalizations messages,
    SyncSubscribeFailure failure,
  ) => switch (failure) {
    SyncSubscribeFailure.offline => messages.syncSubscribeErrorOffline,
    SyncSubscribeFailure.service => messages.syncSubscribeErrorService,
    SyncSubscribeFailure.browserUnavailable =>
      messages.syncSubscribeErrorBrowser,
    SyncSubscribeFailure.alreadySetUp =>
      messages.syncSubscribeErrorAlreadySetUp,
    SyncSubscribeFailure.invalidBundle =>
      messages.syncSubscribeErrorInvalidBundle,
  };
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice({
    required this.onChoose,
    this.notice,
    this.noticeIsError = false,
  });

  final Future<void> Function(SyncSubscriptionPlan plan) onChoose;
  final String? notice;
  final bool noticeIsError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final notice = this.notice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SyncDevicePairMotif(state: SyncDevicePairMotifState.idle),
        ),
        SizedBox(height: tokens.spacing.step6),
        Text(
          messages.syncSubscribeIntro,
          style: tokens.typography.styles.body.bodyMedium,
        ),
        if (notice != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            notice,
            key: const Key('sync_subscribe_notice'),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: noticeIsError
                  ? tokens.colors.alert.error.defaultColor
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step6),
        // Annual first and loudest: one charge a year costs the user less in
        // fees and leaves eleven fewer renewals that can fail.
        DesignSystemButton(
          key: const Key('sync_subscribe_annual'),
          label: messages.syncSubscribeAnnual,
          size: DesignSystemButtonSize.large,
          onPressed: () => onChoose(SyncSubscriptionPlan.annual),
        ),
        SizedBox(height: tokens.spacing.step3),
        DesignSystemButton(
          key: const Key('sync_subscribe_monthly'),
          label: messages.syncSubscribeMonthly,
          size: DesignSystemButtonSize.large,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: () => onChoose(SyncSubscriptionPlan.monthly),
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.syncSubscribeFootnote,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

class _AwaitingPayment extends StatelessWidget {
  const _AwaitingPayment({
    required this.canReopen,
    required this.onReopen,
    required this.onCancel,
  });

  final bool canReopen;
  final Future<void> Function() onReopen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Progress(messages.syncSubscribeAwaiting),
        SizedBox(height: tokens.spacing.step6),
        if (canReopen) ...[
          DesignSystemButton(
            key: const Key('sync_subscribe_reopen'),
            label: messages.syncSubscribeReopen,
            leadingIcon: LottiIcons.openExternal,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: onReopen,
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        DesignSystemButton(
          key: const Key('sync_subscribe_cancel'),
          label: messages.settingsMatrixCancel,
          variant: DesignSystemButtonVariant.quiet,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
      child: Column(
        children: [
          const DesignSystemSpinner(),
          SizedBox(height: tokens.spacing.step5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
