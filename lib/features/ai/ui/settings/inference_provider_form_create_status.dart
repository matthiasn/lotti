part of 'inference_provider_edit_page.dart';

/// Live "Connection check" strip rendered below the Base URL field in
/// create mode. Watches the per-provider
/// [ConnectionVerifierController] state and surfaces one of four
/// faces:
///
/// - [ConnectionCheckIdle]: nothing rendered (the strip slot reserves
///   no vertical space when there is no probe to show — the form
///   stays tight when the user hasn't entered a key).
/// - [ConnectionCheckChecking]: a translucent surface with a
///   `CircularProgressIndicator` and the "Checking key…" caption.
/// - [ConnectionCheckVerified]: a green tinted card with a check icon,
///   the localised "Connection verified · N models · responded in Xms"
///   subtitle, and a Re-test button.
/// - [ConnectionCheckFailedHttp] / [ConnectionCheckFailedNetwork]: a
///   warning-tinted card with the failure reason and a Retry button.
class _ConnectionStatusStrip extends ConsumerWidget {
  const _ConnectionStatusStrip({
    required this.providerType,
    required this.onRetest,
  });

  final InferenceProviderType providerType;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(
      connectionVerifierControllerProvider(providerType),
    );

    switch (state) {
      case ConnectionCheckIdle():
        return const SizedBox.shrink();

      case ConnectionCheckChecking():
        return _StripShell(
          background: tokens.colors.background.level02,
          border: tokens.colors.decorative.level01,
          child: Row(
            children: [
              SizedBox(
                width: tokens.spacing.step5,
                height: tokens.spacing.step5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.aiProviderConnectionCheckingLabel,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        );

      case final ConnectionCheckVerified verified:
        final success = tokens.colors.alert.success.defaultColor;
        return _StripShell(
          background: success.withValues(alpha: 0.10),
          border: success.withValues(alpha: 0.32),
          child: Row(
            children: [
              Container(
                width: tokens.spacing.step6,
                height: tokens.spacing.step6,
                decoration: BoxDecoration(
                  color: success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.onInteractiveAlert,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messages.aiProviderConnectionVerifiedTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      messages.aiProviderConnectionVerifiedSubtitle(
                        verified.modelCount,
                        verified.latency.inMilliseconds,
                      ),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.aiProviderConnectionRetestButton,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: onRetest,
              ),
            ],
          ),
        );

      case final ConnectionCheckFailedHttp failed:
        return _failedStrip(
          tokens: tokens,
          messages: messages,
          title: messages.aiProviderConnectionFailedTitle(
            aiProviderDisplayName(type: providerType, messages: messages),
          ),
          detail: messages.aiProviderConnectionFailedHttpDetail(
            failed.status,
            failed.message,
          ),
          onRetry: onRetest,
        );

      case final ConnectionCheckFailedNetwork failed:
        // Pick the localized detail string by the failure code so
        // service-layer constants (timeout / invalid base URL / bad
        // response shape) stay l10n-aware. Raw platform exception
        // messages still flow through the generic `network` arm.
        final detail = switch (failed.code) {
          ConnectionFailureCode.timeout =>
            messages.aiProviderConnectionFailedTimeoutDetail,
          ConnectionFailureCode.invalidBaseUrl =>
            messages.aiProviderConnectionFailedInvalidBaseUrlDetail,
          ConnectionFailureCode.badResponseShape =>
            messages.aiProviderConnectionFailedBadResponseDetail(
              failed.message,
            ),
          ConnectionFailureCode.network =>
            messages.aiProviderConnectionFailedNetworkDetail(failed.message),
        };
        return _failedStrip(
          tokens: tokens,
          messages: messages,
          title: messages.aiProviderConnectionFailedTitle(
            aiProviderDisplayName(type: providerType, messages: messages),
          ),
          detail: detail,
          onRetry: onRetest,
        );
    }
  }

  Widget _failedStrip({
    required DsTokens tokens,
    required AppLocalizations messages,
    required String title,
    required String detail,
    required VoidCallback onRetry,
  }) {
    final danger = tokens.colors.alert.error.defaultColor;
    return _StripShell(
      background: danger.withValues(alpha: 0.10),
      border: danger.withValues(alpha: 0.32),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step6,
            height: tokens.spacing.step6,
            decoration: BoxDecoration(color: danger, shape: BoxShape.circle),
            child: Icon(
              Icons.close_rounded,
              size: tokens.spacing.step5,
              color: tokens.colors.text.onInteractiveAlert,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  detail,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemButton(
            label: messages.aiProviderConnectionRetryButton,
            variant: DesignSystemButtonVariant.tertiary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _StripShell extends StatelessWidget {
  const _StripShell({
    required this.background,
    required this.border,
    required this.child,
  });

  final Color background;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
