import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The FTUE "connect your brain" front door: a two-page adaptive modal
/// (cinematic welcome → provider tiles). It owns only the framing; provider
/// creation reuses the existing per-provider FTUE setup via
/// `onProviderSelected` (which the caller wires to `navigateToCreateProvider`).
///
/// Skipping is honest but subordinate: dismissing the modal records a skip and
/// lets the app fall through to its normal empty state, where a later phase
/// adds the standing "connect a brain" nudge.
class OnboardingWelcomeModal {
  OnboardingWelcomeModal._();

  /// The three providers surfaced as co-equals on the connect page. MLX is
  /// deliberately excluded from the FTUE (a multi-GB download has no place in a
  /// first session); it stays available later in Settings.
  static const primaryProviders = <InferenceProviderType>[
    InferenceProviderType.gemini,
    InferenceProviderType.mistral,
    InferenceProviderType.alibaba,
  ];

  /// Surfaced behind the "More options" disclosure.
  static const moreProviders = <InferenceProviderType>[
    InferenceProviderType.openAi,
    InferenceProviderType.ollama,
  ];

  static Future<void> show(
    BuildContext context, {
    required void Function(InferenceProviderType) onProviderSelected,
    required VoidCallback onDismiss,
    OnboardingMetricsRepository? metrics,
  }) async {
    final repo =
        metrics ??
        (getIt.isRegistered<OnboardingMetricsRepository>()
            ? getIt<OnboardingMetricsRepository>()
            : null);
    unawaited(repo?.recordEvent(OnboardingEventName.welcomeShown));

    final pageIndexNotifier = ValueNotifier<int>(0);
    var providerModalRecorded = false;
    pageIndexNotifier.addListener(() {
      if (pageIndexNotifier.value >= 1 && !providerModalRecorded) {
        providerModalRecorded = true;
        unawaited(repo?.recordEvent(OnboardingEventName.providerModalShown));
      }
    });

    InferenceProviderType? selected;

    await ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalContext) => [
        ModalUtils.modalSheetPage(
          context: modalContext,
          hasTopBarLayer: false,
          padding: EdgeInsets.zero,
          child: OnboardingHeroPanel(
            onConnect: () => pageIndexNotifier.value = 1,
            onSkip: () => Navigator.of(modalContext).pop(),
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.onboardingConnectTitle,
          showCloseButton: true,
          onTapBack: () => pageIndexNotifier.value = 0,
          child: _ConnectPage(
            onSelect: (type) {
              selected = type;
              Navigator.of(modalContext).pop();
            },
          ),
        ),
      ],
    );

    pageIndexNotifier.dispose();

    if (selected != null) {
      onProviderSelected(selected!);
    } else {
      unawaited(repo?.recordEvent(OnboardingEventName.welcomeSkipped));
      onDismiss();
    }
  }
}

/// Curated welcome-specific provider name (more marketing-forward than the
/// generic AI-settings label — e.g. "Qwen" rather than "Alibaba").
String onboardingProviderName(AppLocalizations m, InferenceProviderType type) {
  return switch (type) {
    InferenceProviderType.gemini => m.onboardingConnectGeminiName,
    InferenceProviderType.mistral => m.onboardingConnectMistralName,
    InferenceProviderType.alibaba => m.onboardingConnectQwenName,
    InferenceProviderType.openAi => m.onboardingConnectOpenAiName,
    InferenceProviderType.ollama => m.onboardingConnectOllamaName,
    _ => aiProviderDisplayName(type: type, messages: m),
  };
}

/// Curated welcome-specific tagline; empty for providers without one.
String onboardingProviderTagline(
  AppLocalizations m,
  InferenceProviderType type,
) {
  return switch (type) {
    InferenceProviderType.gemini => m.onboardingConnectGeminiTagline,
    InferenceProviderType.mistral => m.onboardingConnectMistralTagline,
    InferenceProviderType.alibaba => m.onboardingConnectQwenTagline,
    _ => '',
  };
}

class _ConnectPage extends StatefulWidget {
  const _ConnectPage({required this.onSelect});

  final void Function(InferenceProviderType) onSelect;

  @override
  State<_ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<_ConnectPage> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in OnboardingWelcomeModal.primaryProviders)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step3),
            child: _ProviderTile(
              type: type,
              onTap: () => widget.onSelect(type),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => setState(() => _showMore = !_showMore),
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showMore
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: tokens.spacing.step4,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step1),
                  Text(
                    context.messages.onboardingConnectMoreOptions,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.interactive.enabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showMore)
          for (final type in OnboardingWelcomeModal.moreProviders)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step2),
              child: _ProviderTile(
                type: type,
                onTap: () => widget.onSelect(type),
              ),
            ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.type, required this.onTap});

  final InferenceProviderType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = aiProviderAccent(type: type, tokens: tokens);
    final surface = aiProviderSurface(type: type, tokens: tokens);
    final tagline = onboardingProviderTagline(messages, type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedModalItem(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          // Elevated card: lighter than the sheet background in both themes
          // (light level01 = white, dark level02 > level01), with a soft
          // shadow so it floats above the surface rather than sinking below it.
          color: isDark
              ? tokens.colors.background.level02
              : tokens.colors.background.level01,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step3),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(aiProviderIcon(type), color: accent),
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onboardingProviderName(messages, type),
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  if (tagline.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: Text(
                        tagline,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}
