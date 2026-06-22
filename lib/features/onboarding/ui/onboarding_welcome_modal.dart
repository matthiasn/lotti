import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_category_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The seeded inference profile attached to categories created for a freshly
/// connected provider — so each chosen category resolves to a real model.
String? onboardingSeededProfileId(InferenceProviderType type) => switch (type) {
  InferenceProviderType.gemini => profileGeminiFlashId,
  InferenceProviderType.mistral => profileMistralEuId,
  InferenceProviderType.alibaba => profileAlibabaId,
  InferenceProviderType.openAi => profileOpenAiId,
  InferenceProviderType.ollama => profileLocalId,
  _ => null,
};

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

enum _FlowStep { welcome, connect, apiKey, success, category }

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
          onContinue: () => setState(() => _step = _FlowStep.category),
        );
      case _FlowStep.category:
        return _OnboardingCategoryStep(
          key: const ValueKey('onboarding-category'),
          type: _type,
          onDone: widget.onComplete,
        );
    }
  }
}

/// The category step: the user picks the life areas the just-connected provider
/// should power; on continue each selected area becomes a real category bound
/// to the provider's seeded inference profile (so it can actually run).
class _OnboardingCategoryStep extends ConsumerStatefulWidget {
  const _OnboardingCategoryStep({
    required this.type,
    required this.onDone,
    super.key,
  });

  final InferenceProviderType type;
  final VoidCallback onDone;

  @override
  ConsumerState<_OnboardingCategoryStep> createState() =>
      _OnboardingCategoryStepState();
}

class _OnboardingCategoryStepState
    extends ConsumerState<_OnboardingCategoryStep> {
  final _selected = <String>{};
  final _custom = <OnboardingCategoryOption>[];
  var _busy = false;

  // Starter colours for the created categories (category colours are data the
  // user can recolour later, not design tokens).
  static const _palette = [
    '#5ED4B7',
    '#4285F4',
    '#FF7043',
    '#AB47BC',
    '#66BB6A',
    '#FFA726',
  ];

  List<OnboardingCategoryOption> _options(AppLocalizations m) => [
    OnboardingCategoryOption(
      label: m.onboardingCategoryWork,
      icon: Icons.work_outline_rounded,
    ),
    OnboardingCategoryOption(
      label: m.onboardingCategoryFitness,
      icon: Icons.fitness_center_rounded,
    ),
    OnboardingCategoryOption(
      label: m.onboardingCategoryFamily,
      icon: Icons.home_rounded,
    ),
    OnboardingCategoryOption(
      label: m.onboardingCategoryFriends,
      icon: Icons.group_rounded,
    ),
    ..._custom,
  ];

  void _toggle(String label) => setState(() {
    if (!_selected.remove(label)) _selected.add(label);
  });

  Future<void> _addOwn() async {
    final controller = TextEditingController();
    final material = MaterialLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.messages.onboardingCategoryAddOwn),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(material.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(material.okButtonLabel),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      if (_options(context.messages).every((o) => o.label != name)) {
        _custom.add(
          OnboardingCategoryOption(
            label: name,
            icon: Icons.label_outline_rounded,
          ),
        );
      }
      _selected.add(name);
    });
  }

  Future<void> _continue(List<OnboardingCategoryOption> options) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repository = ref.read(categoryRepositoryProvider);
    final profileId = onboardingSeededProfileId(widget.type);
    final chosen = options.where((o) => _selected.contains(o.label)).toList();
    for (var i = 0; i < chosen.length; i++) {
      await repository.createCategory(
        name: chosen[i].label,
        color: _palette[i % _palette.length],
        defaultProfileId: profileId,
      );
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final options = _options(messages);
    return OnboardingCategoryView(
      accent: dsTokensDark.colors.interactive.enabled,
      title: messages.onboardingCategoryTitle,
      explanation: messages.onboardingCategoryExplanation(
        onboardingProviderName(messages, widget.type),
      ),
      continueLabel: messages.onboardingCategoryContinue,
      addOwnLabel: messages.onboardingCategoryAddOwn,
      options: options,
      selected: _selected,
      onToggle: _toggle,
      onAddOwn: _addOwn,
      onContinue: () => _continue(options),
    );
  }
}
