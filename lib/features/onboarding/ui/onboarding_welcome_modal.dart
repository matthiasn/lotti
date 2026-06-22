import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/get_it.dart';

/// The FTUE "connect your brain" front door: a full-screen cinematic route that
/// crossfades through three steps — a welcome (animated `heroStyle` hero), a
/// matching connect page (provider tiles), and a key step that creates the
/// provider and runs the existing per-provider FTUE setup natively.
///
/// A full-screen route (not a bottom sheet) keeps the in-panel back buttons
/// reliably hittable and gives the keyboard step room. `onDismiss` fires only
/// when the user backs out without connecting.
class OnboardingWelcomeModal {
  // Uninstantiable namespace — only the static [show] is ever used.
  OnboardingWelcomeModal._(); // coverage:ignore-line

  static Future<void> show(
    BuildContext context, {
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

    InferenceProviderType? connectedType;

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        // Transparent route + dim barrier: the app stays visible (dimmed)
        // behind the floating panel rather than being replaced by a solid
        // takeover.
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        reverseTransitionDuration: MotionDurations.short4,
        pageBuilder: (routeContext, animation, _) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: MotionCurves.emphasizedDecelerate,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: _OnboardingScaffold(
                heroStyle: heroStyle,
                onProviderModalShown: () => unawaited(
                  repo?.recordEvent(OnboardingEventName.providerModalShown),
                ),
                onConnected: (type) {
                  connectedType = type;
                  Navigator.of(routeContext).pop();
                },
                onSkip: () => Navigator.of(routeContext).pop(),
              ),
            ),
          );
        },
      ),
    );

    if (connectedType != null) {
      unawaited(
        repo?.recordEvent(
          OnboardingEventName.providerConnected,
          provider: connectedType!.name,
        ),
      );
    } else {
      unawaited(repo?.recordEvent(OnboardingEventName.welcomeSkipped));
      onDismiss();
    }
  }
}

/// Full-screen dark canvas hosting the flow, centered + scrollable so the
/// keyboard step fits on small viewports.
class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onConnected,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so the dim barrier (and the app behind it) shows
    // around the panel; the panel supplies its own dark surface. Anchored to
    // the bottom as a sheet on phones, centered as a dialog on wide screens.
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: wide ? Alignment.center : Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 24 : 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _OnboardingFlow(
                heroStyle: heroStyle,
                onProviderModalShown: onProviderModalShown,
                onConnected: onConnected,
                onSkip: onSkip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FlowStep { welcome, connect, apiKey }

/// Internal three-step flow swapped with a crossfade + height animation. Owning
/// the step locally keeps the in-panel back buttons hittable.
class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onConnected,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final VoidCallback onSkip;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  _FlowStep _step = _FlowStep.welcome;
  late InferenceProviderType _type;

  @override
  Widget build(BuildContext context) {
    // All three steps render at ONE fixed height so the modal never resizes
    // between steps — the source of the screen-to-screen "jump". ~72% of the
    // viewport (clamped) comfortably fits the tallest step (welcome) while
    // keeping the shorter steps from looking stranded. With every step the same
    // height, the crossfade is a pure opacity blend (identical dark
    // backgrounds, no colour seam) with zero layout movement.
    final screenHeight = MediaQuery.sizeOf(context).height;
    // The welcome (first) step is the tallest and is the height the user wants
    // every step to share. Its hero + promise + CTAs run ≈ 760 at phone width,
    // so the common height tracks the viewport but floors high enough to fit
    // the welcome without clipping; the shorter steps fill the rest with their
    // own backdrop (the constellation animation reads nicely in that space).
    final panelHeight = (screenHeight * 0.9).clamp(790.0, 900.0);
    return AnimatedSwitcher(
      duration: MotionDurations.medium4,
      switchInCurve: MotionCurves.emphasizedDecelerate,
      switchOutCurve: MotionCurves.emphasizedDecelerate,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          // Equal-height children, so a plain fill never clips or overflows.
          for (final child in previousChildren) Positioned.fill(child: child),
          ?currentChild,
        ],
      ),
      child: SizedBox(
        // Key by step (+ provider for the key step) so the switcher crossfades
        // on every real navigation, including re-entering the key step for a
        // different provider.
        key: ValueKey(
          _step == _FlowStep.apiKey ? 'apiKey-${_type.name}' : _step.name,
        ),
        height: panelHeight,
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _FlowStep.welcome:
        return OnboardingHeroPanel(
          key: const ValueKey('onboarding-welcome'),
          heroStyle: widget.heroStyle,
          onConnect: () {
            setState(() => _step = _FlowStep.connect);
            widget.onProviderModalShown();
          },
          onSkip: widget.onSkip,
        );
      case _FlowStep.connect:
        return OnboardingConnectPanel(
          key: const ValueKey('onboarding-connect'),
          onBack: () => setState(() => _step = _FlowStep.welcome),
          onSelect: (type) => setState(() {
            _type = type;
            _step = _FlowStep.apiKey;
          }),
        );
      case _FlowStep.apiKey:
        return OnboardingApiKeyPanel(
          key: ValueKey('onboarding-apikey-${_type.name}'),
          type: _type,
          onBack: () => setState(() => _step = _FlowStep.connect),
          onConnected: () => widget.onConnected(_type),
        );
    }
  }
}
