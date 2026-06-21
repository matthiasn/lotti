import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/get_it.dart';

/// The FTUE "connect your brain" front door: a full-screen cinematic route
/// whose body crossfades between a welcome (animated `heroStyle` hero) and a
/// matching dark connect page (combined backdrop + provider tiles).
///
/// A full-screen route (not a bottom sheet) keeps the in-panel back button
/// reliably hittable and gives the keyboard-driven steps room. It owns only the
/// framing; provider creation reuses the existing per-provider FTUE setup via
/// `onProviderSelected`.
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

    InferenceProviderType? selected;

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        reverseTransitionDuration: MotionDurations.short4,
        pageBuilder: (routeContext, animation, _) => FadeTransition(
          opacity: animation,
          child: _OnboardingScaffold(
            heroStyle: heroStyle,
            onProviderModalShown: () => unawaited(
              repo?.recordEvent(OnboardingEventName.providerModalShown),
            ),
            onSelect: (type) {
              selected = type;
              Navigator.of(routeContext).pop();
            },
            onSkip: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );

    if (selected != null) {
      onProviderSelected(selected!);
    } else {
      unawaited(repo?.recordEvent(OnboardingEventName.welcomeSkipped));
      onDismiss();
    }
  }
}

/// The full-screen dark canvas hosting the flow. Seamless (scaffold and panels
/// share the dark background) so the animated backdrop reads as the whole
/// screen, with the content block centered and scrollable for small viewports.
class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onSelect,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onSelect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dsTokensDark.colors.background.level01,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _OnboardingFlow(
                heroStyle: heroStyle,
                onProviderModalShown: onProviderModalShown,
                onSelect: onSelect,
                onSkip: onSkip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal two-step flow: welcome ⇄ connect, swapped with a crossfade +
/// height animation. Owning the step locally keeps the back button hittable.
class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onSelect,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onSelect;
  final VoidCallback onSkip;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  bool _connect = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: MotionDurations.medium2,
        child: _connect
            ? OnboardingConnectPanel(
                key: const ValueKey('onboarding-connect'),
                onBack: () => setState(() => _connect = false),
                onSelect: widget.onSelect,
              )
            : OnboardingHeroPanel(
                key: const ValueKey('onboarding-welcome'),
                heroStyle: widget.heroStyle,
                onConnect: () {
                  setState(() => _connect = true);
                  widget.onProviderModalShown();
                },
                onSkip: widget.onSkip,
              ),
      ),
    );
  }
}
