import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/edge_fade.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/learning_cards.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Drafting wait screen — the latency-as-reflection beat between
/// Reconcile and the Day view.
///
/// The wait is carried by a single hero moment: the decoder-bars thinking
/// shader over a rotating one-line narration of what the agent is doing,
/// with yesterday's learning cards below as real content to read while
/// waiting. No skeleton shimmer — the narration is the progress indicator.
///
/// When the controller flips to [DraftingPhase.ready], the screen
/// either returns to the route-level root (preferred in the full app,
/// preserving the date picker) or auto-pushes [DayPage] for standalone
/// preview usage.
class DraftingPage extends ConsumerStatefulWidget {
  const DraftingPage({
    required this.captureId,
    required this.decidedTaskIds,
    required this.dayDate,
    this.decidedCaptureItemIds = const [],
    this.returnToRootOnReady = false,
    super.key,
  });

  final CaptureId captureId;
  final List<String> decidedTaskIds;
  final List<String> decidedCaptureItemIds;
  final DateTime dayDate;
  final bool returnToRootOnReady;

  @override
  ConsumerState<DraftingPage> createState() => _DraftingPageState();
}

class _DraftingPageState extends ConsumerState<DraftingPage> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final params = DraftingParams(
      captureId: widget.captureId,
      decidedTaskIds: widget.decidedTaskIds,
      decidedCaptureItemIds: widget.decidedCaptureItemIds,
      dayDate: widget.dayDate,
    );

    ref.listen<AsyncValue<DraftingState>>(draftingControllerProvider(params), (
      previous,
      next,
    ) {
      final value = next.value;
      if (value == null || _advanced) return;
      if (value.phase == DraftingPhase.ready && value.draft != null) {
        _advanced = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.returnToRootOnReady) {
            ref.invalidate(
              currentDraftPlanProvider(
                DateTime(
                  widget.dayDate.year,
                  widget.dayDate.month,
                  widget.dayDate.day,
                ),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
            return;
          }
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => DayPage(draft: value.draft!),
            ),
          );
        });
      }
    });

    final asyncState = ref.watch(draftingControllerProvider(params));

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        child: switch (asyncState) {
          _ when asyncState.hasValue => DraftingModalContent(
            state: asyncState.requireValue,
          ),
          _ when asyncState.hasError => Center(
            child: Text(
              context.messages.dailyOsNextGenericError,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Scaffold-free drafting wait content (thinking hero + narration ticker +
/// learning cards) for hosting inside the day-planning modal as well as
/// the standalone [DraftingPage].
class DraftingModalContent extends StatelessWidget {
  const DraftingModalContent({required this.state, super.key});

  final DraftingState state;

  /// Single calm column — matches the capture surface's content width so
  /// the ritual keeps one rhythm across steps.
  static const double _contentMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDrafting = state.phase == DraftingPhase.drafting;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Content scrolling past the sheet edge dissolves over the last ~36px
    // instead of being razor-cut at full brightness.
    return EdgeFade(
      rampExtent: 36,
      fadeTop: false,
      minFraction: 0.04,
      child: SingleChildScrollView(
        // Extra bottom padding so the last learning-card line clears the
        // fade band when scrolled to the end.
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step6,
          tokens.spacing.step5,
          tokens.spacing.step10,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reserved eyebrow slot keeps the headline baseline at the
                // same height as the other steps.
                Text(' ', style: calmGreetingStyle(tokens)),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  context.messages.dailyOsNextDraftingHeader,
                  textAlign: TextAlign.center,
                  style: calmDisplayStyle(tokens),
                ),
                SizedBox(height: tokens.spacing.step6),
                AiThinkingShaderPresence(
                  isRunning: isDrafting,
                  height: 44,
                  indicatorKey: DraftingModalContent.thinkingShaderKey,
                ),
                SizedBox(height: tokens.spacing.step5),
                DraftingStatusTicker(active: isDrafting),
                SizedBox(height: tokens.spacing.step8),
                // The learning cards arrive mid-draft, after the user is
                // already reading the status ticker. Reveal their height open
                // (the stretch alignment keeps the width fixed) so they ease in
                // instead of popping into the column.
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: reduceMotion
                      ? Duration.zero
                      : MotionDurations.medium2,
                  curve: MotionCurves.emphasizedDecelerate,
                  child: state.learningCards != null
                      ? LearningCardsColumn(cards: state.learningCards!)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stable key on the hero thinking shader, for presence asserts.
  @visibleForTesting
  static const Key thinkingShaderKey = ValueKey('drafting-thinking-shader');
}

/// One-line narration of what the agent is doing, rotating through a fixed
/// localized sequence with a fade-through-slide transition.
///
/// The sequence is deterministic (no randomness — reproducible in tests
/// and screenshots) and long enough (~20s per cycle) that a fast cloud
/// draft never sees a repeat and a slow local first run doesn't feel like
/// a stuck loop.
class DraftingStatusTicker extends StatefulWidget {
  const DraftingStatusTicker({
    required this.active,
    this.interval = const Duration(milliseconds: 2600),
    super.key,
  });

  /// Whether the agent is currently drafting; pauses rotation when false.
  final bool active;

  /// Time each line stays on screen.
  final Duration interval;

  /// The localized narration lines, in rotation order.
  static List<String> linesOf(AppLocalizations messages) => [
    messages.dailyOsNextDraftingStatusReading,
    messages.dailyOsNextDraftingStatusMatching,
    messages.dailyOsNextDraftingStatusYesterday,
    messages.dailyOsNextDraftingStatusDeepWork,
    messages.dailyOsNextDraftingStatusBreathing,
    messages.dailyOsNextDraftingStatusAfternoon,
    messages.dailyOsNextDraftingStatusTimings,
    messages.dailyOsNextDraftingStatusAlmost,
  ];

  @override
  State<DraftingStatusTicker> createState() => _DraftingStatusTickerState();
}

class _DraftingStatusTickerState extends State<DraftingStatusTicker> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(DraftingStatusTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _timer == null) {
      _start();
    } else if (!widget.active) {
      _stop();
    }
  }

  void _start() {
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _index++);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final lines = DraftingStatusTicker.linesOf(context.messages);
    final text = lines[_index % lines.length];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
