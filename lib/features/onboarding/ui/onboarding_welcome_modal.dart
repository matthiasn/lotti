import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_category_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_step.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_recording_style_step.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';

/// The seeded inference profile attached to categories created for a freshly
/// connected provider — so each chosen category resolves to a real model.
String? onboardingSeededProfileId(InferenceProviderType type) => switch (type) {
  InferenceProviderType.melious => profileMeliousId,
  InferenceProviderType.gemini => profileGeminiFlashId,
  InferenceProviderType.mistral => profileMistralEuId,
  InferenceProviderType.alibaba => profileAlibabaId,
  InferenceProviderType.openAi => profileOpenAiId,
  InferenceProviderType.ollama => profileLocalId,
  _ => null,
};

/// The areas created in the onboarding category step, handed to the in-panel
/// first-task step so the structured task lands in a real place — and so the
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
    VoidCallback? onCompleted,
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
    // The task the in-panel first-task step landed — carried out of the modal
    // route so the real task page can be opened once the modal has popped.
    String? createdTaskId;
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
                // The in-panel first-task step landed a real task — remember
                // its id and pop the modal; the task page is opened below once
                // the modal route is gone.
                onTaskCreated: (taskId) {
                  createdTaskId = taskId;
                  Navigator.of(routeContext).pop();
                },
                // Reached when the first-task step cannot produce a task at
                // all (a total structuring failure) — finish onboarding.
                onComplete: () => Navigator.of(routeContext).pop(),
                onSkip: () => Navigator.of(routeContext).pop(),
              ),
            ),
          );
        },
      ),
    );

    if (connectedType != null) {
      // The user completed the essential setup (a provider + models were
      // created), so the front-door welcome has done its job -- let the caller
      // retire it permanently. Fires whether or not a first task then landed;
      // the skip path below never reaches here.
      onCompleted?.call();
      unawaited(
        repo?.recordEvent(
          OnboardingEventName.providerConnected,
          provider: connectedType!.name,
        ),
      );
      // The in-panel first-task step landed a real task: the payoff is the
      // real task page, opened now that the modal route is gone.
      final taskId = createdTaskId;
      if (taskId != null) {
        openOnboardingCreatedTask(taskId);
      }
    } else {
      unawaited(repo?.recordEvent(OnboardingEventName.welcomeSkipped));
      onDismiss();
    }
  }
}

/// Lands the user on their freshly created task once the onboarding modal has
/// popped. Deep-links through the app's canonical task route, which also
/// switches to the Tasks destination — the flow may have been launched from
/// anywhere (first run, or the Settings → Maintenance debug entry), and a bare
/// detail-stack push from another tab would open the task invisibly.
@visibleForTesting
void openOnboardingCreatedTask(String taskId) {
  beamToNamed('/tasks/$taskId');
}

/// Full-screen dark canvas hosting the flow, centered + scrollable so the
/// keyboard step fits on small viewports.
class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onConnected,
    required this.onTaskCreated,
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final void Function(String taskId) onTaskCreated;
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
        onTaskCreated: onTaskCreated,
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

enum _FlowStep {
  welcome,
  connect,
  apiKey,
  success,
  recordingStyle,
  category,
  firstTask,
}

/// Internal step flow swapped with a crossfade + height animation. Owning
/// the step locally keeps the in-panel back buttons hittable.
class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({
    required this.heroStyle,
    required this.onProviderModalShown,
    required this.onConnected,
    required this.onTaskCreated,
    required this.onComplete,
    required this.onSkip,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onProviderModalShown;
  final void Function(InferenceProviderType) onConnected;
  final void Function(String taskId) onTaskCreated;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  _FlowStep _step = _FlowStep.welcome;
  late InferenceProviderType _type;

  /// The areas created in the category step, carried into the first-task step.
  /// Set exactly once when the category step advances.
  late OnboardingFirstCapture _capture;

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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                // Several steps (e.g. the welcome hero and the connect
                // page) run their own continuous particle-animation
                // backdrop. Left running, an outgoing step's backdrop
                // paints every frame right alongside the incoming step's —
                // twice the continuous custom-painting cost for the
                // duration of the crossfade, which is enough to visibly
                // stutter on slower renderers (the iOS Simulator's Metal
                // translation in particular). `TickerMode(enabled: false)`
                // freezes every ticker in the subtree (all
                // `AnimationController`s) the instant a step becomes
                // "previous" -- it still fades out via the outer
                // `AnimatedSwitcher`'s opacity animation, just on its last
                // painted frame instead of a live one.
                child: TickerMode(enabled: false, child: child),
              ),
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
          onContinue: () => setState(() => _step = _FlowStep.recordingStyle),
        );
      case _FlowStep.recordingStyle:
        return OnboardingRecordingStyleStep(
          key: const ValueKey('onboarding-recording-style'),
          onContinue: () => setState(() => _step = _FlowStep.category),
        );
      case _FlowStep.category:
        return _OnboardingCategoryStep(
          key: const ValueKey('onboarding-category'),
          type: _type,
          // The category step finished with at least one created area — the
          // first-task finale stays *inside* the panel (the same dialogue),
          // rather than popping out to a full-screen takeover.
          onStartCapture: (capture) => setState(() {
            _capture = capture;
            _step = _FlowStep.firstTask;
          }),
          onDone: widget.onComplete,
        );
      case _FlowStep.firstTask:
        return OnboardingFirstTaskStep(
          key: const ValueKey('onboarding-first-task'),
          categories: _capture.categories,
          providerName: _capture.providerName,
          onTaskCreated: widget.onTaskCreated,
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

  /// Invoked with the created areas when the user finishes with at least one
  /// selection — the flow advances to the in-panel first-task step.
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
    try {
      final repository = ref.read(categoryRepositoryProvider);
      final profileId = onboardingSeededProfileId(widget.type);
      // Resolved before the await gap so no BuildContext is touched afterwards.
      final providerName = onboardingProviderName(
        context.messages,
        widget.type,
      );
      final chosen = options.where((o) => _selected.contains(o.label)).toList();

      // Category names are UNIQUE across *all* rows in the database —
      // including soft-deleted, private-hidden, and archived ones — so the
      // duplicate check must consult the unfiltered set: a visible-only fetch
      // would miss rows that still trip the constraint and make Continue die
      // with an opaque error.
      final existing = await repository.getAllCategoriesIncludingHidden();

      final created = <OnboardingCaptureCategory>[];
      for (var i = 0; i < chosen.length; i++) {
        final label = chosen[i].label;
        final match = existing
            .where((c) => c.name.toLowerCase() == label.toLowerCase())
            .firstOrNull;
        if (match != null) {
          // Reuse the existing category, made fit for its new job: resurrect
          // a soft-deleted row, un-archive an inactive one (the first task
          // must land somewhere the user's task views can show), and bind the
          // just-seeded inference profile so the first-task structuring can
          // actually run — the whole point of the area the user just picked.
          // Laura becomes the default task-agent template only when no
          // template is bound yet: a user-chosen template must survive.
          // `private` is deliberately left untouched: flipping it would
          // expose content the user chose to hide.
          var reusable = match.copyWith(deletedAt: null, active: true);
          if (profileId != null) {
            reusable = reusable.copyWith(defaultProfileId: profileId);
            if (reusable.defaultTemplateId == null) {
              reusable = reusable.copyWith(defaultTemplateId: lauraTemplateId);
            }
          }
          final reused = await repository.updateCategory(reusable);
          created.add(
            OnboardingCaptureCategory(id: reused.id, label: reused.name),
          );
          continue;
        }
        // Laura rides along with the profile so the first task (and every
        // later task in this area) gets a task agent auto-assigned — the
        // template only makes sense with a profile that can actually run it.
        final category = await repository.createCategory(
          name: label,
          color: _palette[i % _palette.length],
          defaultProfileId: profileId,
          defaultTemplateId: profileId != null ? lauraTemplateId : null,
        );
        created.add(
          OnboardingCaptureCategory(id: category.id, label: category.name),
        );
      }

      if (created.isNotEmpty) {
        // Hand every created area to the in-panel first-task step. With more
        // than one area the step lets the user pick which one the task lands
        // in.
        widget.onStartCapture(
          OnboardingFirstCapture(
            categories: created,
            providerName: providerName,
          ),
        );
      } else {
        // No area selected — nothing to capture into, so just finish.
        // Defensive: Continue is disabled until at least one area is selected.
        widget.onDone(); // coverage:ignore-line
      }
    } catch (error, stackTrace) {
      // A category write failure must not die silently under the Continue
      // button — log it so a field failure is diagnosable, and surface a toast
      // so the user knows to retry.
      getIt<LoggingService>().captureException(
        error,
        domain: 'ONBOARDING',
        subDomain: 'OnboardingCategoryStep.createCategories',
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    } finally {
      // Release the lock if a repository write threw. On success the modal has
      // already popped (widget unmounted), so guard with mounted.
      if (mounted) setState(() => _busy = false);
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
