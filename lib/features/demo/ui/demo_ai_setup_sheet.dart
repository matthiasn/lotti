import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/demo/ai/demo_real_ai_wiring.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// The guided "enable real AI in the demo" flow.
///
/// The demo world ships with fictional AI providers that can never answer,
/// so the first AI tap (and a settings row) leads here: an intro step that
/// says so plainly — real AI in the demo runs against the user's real AI
/// account, and the key stays inside the demo world unless copied over on
/// exit — followed by the SAME connect + API-key panels onboarding uses.
/// Those panels write through the active generation's `AiConfigRepository`,
/// which in the demo IS the demo `ai_config.sqlite`: nothing here duplicates
/// provider/model/profile creation, and nothing touches the real world.
///
/// Presented like `OnboardingWelcomeModal`: a transparent full-screen route
/// with a dim barrier, because the reused panels were designed for that
/// canvas (their own backdrop, keyboard room for the key step).
class DemoAiSetupSheet {
  // Uninstantiable namespace — only the static [show] is ever used.
  DemoAiSetupSheet._(); // coverage:ignore-line

  /// Bound on waiting for the demo-world wiring before the intercepted
  /// action retries: long enough for the stamping writes on any healthy
  /// device, short enough that a wedged demo database cannot hang the retry
  /// forever (the wiring itself never throws — failures are logged and
  /// degrade to the pre-connect behavior).
  static const Duration wiringRetryTimeout = Duration(seconds: 10);

  /// Shows the flow. [onConfigured] fires after the route has popped IF a
  /// real provider was connected — callers use it to retry the AI action
  /// the nudge intercepted. The retry WAITS (bounded by
  /// [wiringRetryTimeout]) for the demo-world wiring kicked off on connect,
  /// so the retried skill run sees the seeded tasks already stamped with a
  /// runnable profile instead of racing the stamping writes.
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onConfigured,
    @visibleForTesting DemoWorldWiring? wireWorld,
  }) async {
    var connected = false;
    Future<void>? wiring;
    final dismissLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    await rootNavigator.push(
      PageRouteBuilder<void>(
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
              child: _DemoAiSetupScaffold(
                onConnected: (wiringFuture) {
                  connected = true;
                  wiring = wiringFuture;
                },
                onClose: () => Navigator.of(routeContext).pop(),
                wireWorld: wireWorld,
              ),
            ),
          );
        },
      ),
    );

    if (!connected) return;
    final pendingWiring = wiring;
    if (pendingWiring != null) {
      // The wiring runs concurrently with the success beat; only the RETRY
      // has to wait for it (see [wiringRetryTimeout]).
      await pendingWiring.timeout(wiringRetryTimeout, onTimeout: () {});
    }
    onConfigured?.call();
  }
}

/// Full-screen transparent canvas hosting the flow — the same centered /
/// bottom-sheet split as onboarding's scaffold, so the reused panels render
/// on the canvas they were designed for.
class _DemoAiSetupScaffold extends StatelessWidget {
  const _DemoAiSetupScaffold({
    required this.onConnected,
    required this.onClose,
    this.wireWorld,
  });

  final void Function(Future<void> wiring) onConnected;
  final VoidCallback onClose;
  final DemoWorldWiring? wireWorld;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 600;
    // The panel swallows its own taps so tapping it never reaches the
    // outer dismiss layer (see _OnboardingScaffold for the rationale).
    final panel = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DemoAiSetupFlow(
        onConnected: onConnected,
        onClose: onClose,
        wireWorld: wireWorld,
      ),
    );

    final Widget content;
    if (wide) {
      content = SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.designTokens.spacing.step5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: panel,
            ),
          ),
        ),
      );
    } else {
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: content,
      ),
    );
  }
}

enum DemoAiSetupStep { intro, connect, apiKey, success }

/// Points the demo world's seeded content at the connected provider's
/// bundled profile ([onboardingSeededProfileId]), so AI skills on seeded
/// tasks resolve a runnable profile instead of logging "no profile
/// configured". Injectable so widget tests can observe the call without a
/// live database.
typedef DemoWorldWiring =
    Future<void> Function(InferenceProviderType providerType);

Future<void> _defaultWireWorld(InferenceProviderType providerType) async {
  final profileId = onboardingSeededProfileId(providerType);
  if (profileId == null) return;
  await wireDemoWorldToRealProfile(
    profileId: profileId,
    journalDb: getIt<JournalDb>(),
    persistence: getIt<PersistenceLogic>(),
  );
}

/// The step flow: intro → connect → apiKey → success. Public (with a
/// [initialStep] seam) so widget tests can pump it without the route.
@visibleForTesting
class DemoAiSetupFlow extends StatefulWidget {
  const DemoAiSetupFlow({
    required this.onConnected,
    required this.onClose,
    this.initialStep = DemoAiSetupStep.intro,
    this.wireWorld,
    super.key,
  });

  /// Fired the moment the API-key panel reports a created provider —
  /// BEFORE the success beat, so a dismissal on that beat still counts.
  /// Receives the in-flight wiring future so [DemoAiSetupSheet.show] can
  /// hold the intercepted-action retry until the stamping writes are done.
  final void Function(Future<void> wiring) onConnected;

  /// Pops the hosting route.
  final VoidCallback onClose;

  final DemoAiSetupStep initialStep;

  /// Test seam; production wires the active demo generation's services.
  final DemoWorldWiring? wireWorld;

  @override
  State<DemoAiSetupFlow> createState() => _DemoAiSetupFlowState();
}

class _DemoAiSetupFlowState extends State<DemoAiSetupFlow> {
  late DemoAiSetupStep _step = widget.initialStep;

  /// Set by the connect step, which is the only writer. Seeded with the
  /// first tile the connect panel lists rather than left `late`, because
  /// [DemoAiSetupFlow.initialStep] lets a caller open straight on `apiKey`
  /// or `success` — steps that read this before the connect step could run.
  InferenceProviderType _type = onboardingPrimaryProviders.first;

  /// Runs concurrently with the success beat (which must not wait on the
  /// stamping writes) but is handed to [DemoAiSetupFlow.onConnected] so the
  /// intercepted-action retry can await it. A wiring failure only degrades
  /// seeded tasks back to the pre-connect behavior (logged, never surfaced
  /// as a crash) — this future always completes normally.
  Future<void> _runWiring() async {
    try {
      await (widget.wireWorld ?? _defaultWireWorld)(_type);
    } catch (exception, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          exception,
          stackTrace: stackTrace,
          subDomain: 'demoAiSetupWiring',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: MotionDurations.medium4,
        switchInCurve: MotionCurves.emphasizedDecelerate,
        switchOutCurve: MotionCurves.emphasizedDecelerate,
        child: _buildStep(context),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case DemoAiSetupStep.intro:
        return _DemoAiIntroPanel(
          key: const ValueKey('demo-ai-intro'),
          onContinue: () => setState(() => _step = DemoAiSetupStep.connect),
          onCancel: widget.onClose,
        );
      case DemoAiSetupStep.connect:
        return OnboardingConnectPanel(
          key: const ValueKey('demo-ai-connect'),
          onBack: () => setState(() => _step = DemoAiSetupStep.intro),
          onSelect: (type) => setState(() {
            _type = type;
            _step = DemoAiSetupStep.apiKey;
          }),
        );
      case DemoAiSetupStep.apiKey:
        return OnboardingApiKeyPanel(
          key: ValueKey('demo-ai-apikey-${_type.name}'),
          type: _type,
          onBack: () => setState(() => _step = DemoAiSetupStep.connect),
          onConnected: () {
            widget.onConnected(_runWiring());
            setState(() => _step = DemoAiSetupStep.success);
          },
        );
      case DemoAiSetupStep.success:
        return OnboardingSuccessView(
          key: const ValueKey('demo-ai-success'),
          accent: context.designTokens.colors.interactive.enabled,
          title: context.messages.demoAiSetupSuccessTitle,
          subtitle: context.messages.demoAiSetupSuccessBody,
          continueLabel: MaterialLocalizations.of(
            context,
          ).continueButtonLabel,
          onContinue: widget.onClose,
        );
    }
  }
}

/// Intro step: names the deal before any provider UI — the demo's AI is
/// pretend; connecting here uses the user's REAL AI account from inside the
/// demo world; the key stays in the demo world unless copied over on exit.
class _DemoAiIntroPanel extends StatelessWidget {
  const _DemoAiIntroPanel({
    required this.onContinue,
    required this.onCancel,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final panelBg = tokens.colors.background.level01;
    final textHigh = tokens.colors.text.highEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          // The shared alive onboarding backdrop, so the intro reads as the
          // first beat of the same dialogue the connect/key panels continue.
          const Positioned.fill(child: OnboardingBackdrop()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0.35),
                    panelBg.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step6,
              tokens.spacing.step5,
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LottiIcons.science,
                  size: tokens.spacing.step8,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(height: tokens.spacing.step4),
                Text(
                  messages.demoAiNudgeTitle,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  messages.demoAiNudgeBody,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step6),
                DesignSystemButton(
                  label: messages.demoAiNudgeConfirm,
                  size: DesignSystemButtonSize.large,
                  fullWidth: true,
                  onPressed: onContinue,
                ),
                SizedBox(height: tokens.spacing.step2),
                DesignSystemButton(
                  label: messages.demoAiNudgeCancel,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.large,
                  onPressed: onCancel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
