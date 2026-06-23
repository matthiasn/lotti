import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/pages/onboarding_capture_page.dart';
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

/// The areas created in the onboarding category step, handed to the live
/// first-capture page so the structured task lands in a real place — and so the
/// user can pick which one when they created more than one.
class OnboardingFirstCapture {
  const OnboardingFirstCapture({
    required this.categories,
    this.providerName,
  });

  final List<OnboardingCaptureCategory> categories;
  final String? providerName;
}

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
    // The first category created in the category step — carried out of the
    // modal route so the live first-capture page can be pushed after the modal
    // pops (a full-screen route, not a child of the transparent modal).
    OnboardingFirstCapture? firstCapture;
    final dismissLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    await rootNavigator.push(
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
                // The category step finished with at least one created area —
                // remember it and pop the modal; the capture page is pushed
                // below once the modal route is gone.
                onStartCapture: (capture) {
                  firstCapture = capture;
                  Navigator.of(routeContext).pop();
                },
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
      // The user connected a provider and created at least one area: drop them
      // straight into the live first-capture aha on a full-screen route. Its
      // onDone pops back to the app.
      final capture = firstCapture;
      if (capture != null) {
        await rootNavigator.push(
          MaterialPageRoute<void>(
            builder: (captureContext) => OnboardingCapturePage(
              categories: capture.categories,
              providerName: capture.providerName,
              onDone: () => Navigator.of(captureContext).pop(),
            ),
          ),
        );
      }
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
    required this.onStartCapture,
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final void Function(OnboardingFirstCapture) onStartCapture;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so the dim barrier (and the app behind it) shows
    // around the panel; the panel supplies its own dark surface.
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 600;
    // The panel swallows its own taps (an opaque no-op tap) so tapping it never
    // reaches the surrounding dismiss layer. The scroll view around it fills the
    // screen and would otherwise absorb taps before they reach the route's modal
    // barrier, so the route's `barrierDismissible` alone never fired — instead an
    // explicit dismiss layer wraps the body and pops on a tap outside the panel
    // (matching the app's tap-outside-to-close convention).
    final panel = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: _OnboardingFlow(
        heroStyle: heroStyle,
        onProviderModalShown: onProviderModalShown,
        onConnected: onConnected,
        onStartCapture: onStartCapture,
        onComplete: onComplete,
        onSkip: onSkip,
      ),
    );

    final Widget content;
    if (wide) {
      // Desktop: a centred dialog capped at a comfortable width.
      content = SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: panel,
            ),
          ),
        ),
      );
    } else {
      // Phone: a full-width sheet flush to the bottom edge — it covers the app's
      // bottom navigation (no SafeArea bottom inset, no horizontal margin). The
      // panel's own content carries the bottom safe-area padding so controls
      // clear the home indicator while the surface still reaches the screen edge.
      content = Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: mq.padding.top),
          child: panel,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      // Tapping anywhere outside the panel closes the flow, the same as tapping
      // the dim barrier — `onSkip` pops the route and the post-pop logic records
      // skip vs. connected appropriately.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSkip,
        child: content,
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
    required this.onStartCapture,
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final void Function(OnboardingFirstCapture) onStartCapture;
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
          onStartCapture: widget.onStartCapture,
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
    required this.onStartCapture,
    required this.onDone,
    super.key,
  });

  final InferenceProviderType type;

  /// Invoked with the first created area when the user finishes with at least
  /// one selection — the modal pops and hands these to the live capture page.
  final void Function(OnboardingFirstCapture) onStartCapture;

  /// Invoked when the step completes with no area created (nothing selected) —
  /// just pops the modal back to the app.
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
    // Resolved before the await gap so no BuildContext is touched afterwards.
    final providerName = onboardingProviderName(context.messages, widget.type);
    final chosen = options.where((o) => _selected.contains(o.label)).toList();

    final created = <OnboardingCaptureCategory>[];
    for (var i = 0; i < chosen.length; i++) {
      final category = await repository.createCategory(
        name: chosen[i].label,
        color: _palette[i % _palette.length],
        defaultProfileId: profileId,
      );
      created.add(
        OnboardingCaptureCategory(id: category.id, label: category.name),
      );
    }

    if (created.isNotEmpty) {
      // Hand every created area to the live first-capture aha; the modal pops
      // and pushes the capture page in its place. With more than one area the
      // page lets the user pick which one the task lands in.
      widget.onStartCapture(
        OnboardingFirstCapture(
          categories: created,
          providerName: providerName,
        ),
      );
    } else {
      // No area selected — nothing to capture into, so just finish.
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final options = _options(messages);
    return OnboardingCategoryView(
      accent: dsTokensDark.colors.interactive.enabled,
      title: messages.onboardingCategoryTitle,
      explanation: messages.onboardingCategoryExplanation,
      whyLabel: messages.onboardingCategoryWhy,
      continueLabel: messages.onboardingCategoryContinue,
      addOwnLabel: messages.onboardingCategoryAddOwn,
      options: options,
      selected: _selected,
      onToggle: _toggle,
      onWhy: _explainWhy,
      onAddOwn: _addOwn,
      onContinue: () => _continue(options),
    );
  }

  Future<void> _explainWhy() async {
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(messages.onboardingCategoryWhy),
        content: Text(
          messages.onboardingCategoryWhyDetail(
            onboardingProviderName(messages, widget.type),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(material.okButtonLabel),
          ),
        ],
      ),
    );
  }
}
