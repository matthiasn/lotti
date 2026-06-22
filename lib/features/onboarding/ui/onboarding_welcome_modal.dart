import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    final dismissLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        // Transparent route + dim barrier: the app stays visible (dimmed)
        // behind the floating panel rather than being replaced by a solid
        // takeover. Tapping the dim barrier closes it, matching the app's
        // modal convention.
        opaque: false,
        barrierDismissible: true,
        barrierLabel: dismissLabel,
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
                // The connection succeeded (provider + models created) — record
                // it now so it counts even if the user dismisses on the success
                // beat; the route stays open to show that beat.
                onConnected: (type) => connectedType = type,
                onComplete: () => Navigator.of(routeContext).pop(),
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
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so the dim barrier (and the app behind it) shows
    // around the panel; the panel supplies its own dark surface.
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 600;
    final flow = _OnboardingFlow(
      heroStyle: heroStyle,
      onProviderModalShown: onProviderModalShown,
      onConnected: onConnected,
      onComplete: onComplete,
      onSkip: onSkip,
    );

    if (wide) {
      // Desktop: a centred dialog capped at a comfortable width.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: flow,
              ),
            ),
          ),
        ),
      );
    }

    // Phone: a full-width sheet flush to the bottom edge — it covers the app's
    // bottom navigation (no SafeArea bottom inset, no horizontal margin). The
    // panel's own content carries the bottom safe-area padding so controls
    // clear the home indicator while the surface still reaches the screen edge.
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: mq.padding.top),
          child: flow,
        ),
      ),
    );
  }
}

enum _FlowStep { welcome, connect, apiKey, success }

/// Internal three-step flow swapped with a crossfade + height animation. Owning
/// the step locally keeps the in-panel back buttons hittable.
class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onConnected,
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  _FlowStep _step = _FlowStep.welcome;
  late InferenceProviderType _type;

  @override
  Widget build(BuildContext context) {
    // Each step is its own natural height (a bottom sheet on phones), and
    // AnimatedSize eases the height between steps so the transition is smooth
    // without forcing every step to the tallest one's height (which made the
    // shorter steps balloon to near-fullscreen).
    return AnimatedSize(
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: MotionDurations.medium4,
        switchInCurve: MotionCurves.emphasizedDecelerate,
        switchOutCurve: MotionCurves.emphasizedDecelerate,
        // Outgoing steps are pinned top at their own (loose) height — NOT
        // Positioned.fill, which would stretch a taller outgoing step into a
        // shorter incoming box and overflow it while the height eases.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previousChildren)
              Positioned(top: 0, left: 0, right: 0, child: child),
            ?currentChild,
          ],
        ),
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
          onConnected: () {
            // Provider + models are created — record the win and reveal the
            // success beat instead of dropping silently into the app.
            widget.onConnected(_type);
            setState(() => _step = _FlowStep.success);
          },
        );
      case _FlowStep.success:
        return OnboardingSuccessView(
          key: const ValueKey('onboarding-success'),
          accent: dsTokensDark.colors.interactive.enabled,
          title: context.messages.onboardingSuccessTitle,
          subtitle: context.messages.onboardingSuccessSubtitle,
          continueLabel: context.messages.onboardingSuccessContinue,
          onContinue: widget.onComplete,
        );
    }
  }
}
