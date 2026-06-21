import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The FTUE "connect your brain" front door: a two-page adaptive modal —
/// a cinematic welcome (animated `heroStyle` hero) → a matching dark connect
/// page (aurora backdrop + provider tiles). It owns only the framing; provider
/// creation reuses the existing per-provider FTUE setup via `onProviderSelected`
/// (which the caller wires to `navigateToCreateProvider`).
///
/// Skipping is honest but subordinate: dismissing the modal records a skip and
/// lets the app fall through to its normal empty state.
class OnboardingWelcomeModal {
  OnboardingWelcomeModal._();

  static Future<void> show(
    BuildContext context, {
    required void Function(InferenceProviderType) onProviderSelected,
    required VoidCallback onDismiss,
    OnboardingMetricsRepository? metrics,
    OnboardingHeroStyle heroStyle = OnboardingHeroStyle.constellation,
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
            heroStyle: heroStyle,
            onConnect: () => pageIndexNotifier.value = 1,
            onSkip: () => Navigator.of(modalContext).pop(),
          ),
        ),
        ModalUtils.modalSheetPage(
          context: modalContext,
          hasTopBarLayer: false,
          padding: EdgeInsets.zero,
          child: OnboardingConnectPanel(
            onBack: () => pageIndexNotifier.value = 0,
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
