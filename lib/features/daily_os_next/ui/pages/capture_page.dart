import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/transcript_editor.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

part 'capture_layout_metrics.dart';

/// Max width for the centred capture column and the "Today so far" card so
/// the calm single column reads comfortably on wide layouts. Defined once so
/// the standalone page and the modal content can't drift apart.
const double _captureContentMaxWidth = 560;

/// Entry surface of the agentic Daily OS — voice-first check-in.
///
/// Layout: vertically centred greeting → headline → voice button →
/// state row (idle hint / waveform + transcript / "Got it." +
/// Reconcile CTA). Plain, calm, no calendar or task list visible.
/// Mirrors `prototype/screens/capture.jsx` variant A.
class CapturePage extends ConsumerWidget {
  const CapturePage({
    this.forDate,
    this.actualBlocks = const [],
    this.dateStrip,
    super.key,
  });

  /// Day this capture is for. Defaults to `DateTime.now()`, which
  /// routes the capture to today's day-agent. When the route-level
  /// root mounts CapturePage for a different selected date it passes
  /// the local midnight of that day so the resulting day-agent is
  /// keyed on the chosen day instead of today.
  final DateTime? forDate;

  /// Already recorded sessions for [forDate]. The route-level root
  /// resolves these before mounting Capture so the screen does not
  /// look empty on days that already have tracked time.
  final List<TimeBlock> actualBlocks;

  /// Optional widget rendered in the AppBar title slot — used by the
  /// route-level root to expose a date strip while Capture is open
  /// for a non-today date.
  final Widget? dateStrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(captureControllerProvider);
    final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        toolbarHeight: 48,
        title: dateStrip,
        actions: [
          const ProcessingCategoryFilterButton(),
          SizedBox(width: tokens.spacing.step3),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          key: const Key('daily_os_capture_bottom_nav_padding'),
          padding: EdgeInsets.only(bottom: bottomNavHeight),
          child: Column(
            children: [
              // "Today so far" pins to the top of the column; the
              // greeting + orb stay centred in the remaining space
              // below (handoff v2 item 1 — no clipping, intentional
              // rhythm).
              if (actualBlocks.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step5,
                    tokens.spacing.step4,
                    tokens.spacing.step5,
                    0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _captureContentMaxWidth,
                      ),
                      child: TimeSpentCard(
                        blocks: actualBlocks,
                        title: _timeSpentTitle(context),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = CaptureLayoutMetrics.resolve(
                      tokens,
                      phase: state.phase,
                      viewportHeight: constraints.maxHeight,
                    );

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _captureContentMaxWidth,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacing.step5,
                                vertical: tokens.spacing.step6,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const _GreetingBlock(),
                                  SizedBox(height: tokens.spacing.step6),
                                  _Headline(forDate: forDate),
                                  _PastTrackingPrompt(forDate: forDate),
                                  SizedBox(height: tokens.spacing.step8),
                                  VoiceButton(
                                    phase: state.phase,
                                    dbfs: state.dbfs,
                                    semanticLabel: _voiceButtonLabel(
                                      context,
                                      state.phase,
                                    ),
                                    onTap: () => ref
                                        .read(
                                          captureControllerProvider.notifier,
                                        )
                                        .toggle(),
                                  ),
                                  SizedBox(height: tokens.spacing.step5),
                                  _StateSlot(
                                    state: state,
                                    height: layout.stateSlotHeight,
                                    liveTranscriptLineCount:
                                        layout.liveTranscriptLineCount,
                                    reviewTranscriptLineCount:
                                        layout.reviewTranscriptLineCount,
                                  ),
                                  if (state.phase == CapturePhase.captured) ...[
                                    SizedBox(height: tokens.spacing.step6),
                                    _ReconcileCta(
                                      state: state,
                                      forDate: forDate,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Today so far" for today; the date-neutral "Time spent" label for
  /// any other day so the eyebrow never misleads.
  String? _timeSpentTitle(BuildContext context) {
    final date = forDate;
    if (date == null) return null;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(date.year, date.month, date.day);
    if (picked.isAtSameMomentAs(today)) return null;
    return context.messages.dailyOsNextTimeSpentTitlePast;
  }

  String _voiceButtonLabel(BuildContext context, CapturePhase phase) {
    switch (phase) {
      case CapturePhase.idle:
      case CapturePhase.error:
        return context.messages.dailyOsNextCaptureVoiceButtonStart;
      case CapturePhase.listening:
        return context.messages.dailyOsNextCaptureVoiceButtonStop;
      case CapturePhase.transcribing:
      case CapturePhase.captured:
        return context.messages.dailyOsNextCaptureVoiceButtonReset;
    }
  }
}

/// Scaffold-free capture content for hosting inside the day-planning modal.
///
/// Renders the same calm greeting → headline → voice orb → state row as the
/// standalone capture surface, but without the page chrome (AppBar /
/// bottom-nav padding / inline advance CTA) — the modal supplies a top bar
/// and a sticky glass action bar instead. The voice orb stays the in-body
/// hero recording control; advance/secondary actions live in the action bar.
class CaptureModalContent extends ConsumerWidget {
  const CaptureModalContent({
    this.forDate,
    this.actualBlocks = const [],
    super.key,
  });

  final DateTime? forDate;
  final List<TimeBlock> actualBlocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(captureControllerProvider);

    return Column(
      children: [
        // "Today so far" pins to the top; greeting + orb stay centred in
        // the remaining space below (handoff v2 item 1).
        if (actualBlocks.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step4,
              tokens.spacing.step5,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _captureContentMaxWidth,
                ),
                child: TimeSpentCard(
                  blocks: actualBlocks,
                  title: _timeSpentTitle(context),
                ),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = CaptureLayoutMetrics.resolve(
                tokens,
                phase: state.phase,
                viewportHeight: constraints.maxHeight,
              );

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _captureContentMaxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.step5,
                          vertical: tokens.spacing.step6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _GreetingBlock(),
                            SizedBox(height: tokens.spacing.step6),
                            _Headline(forDate: forDate),
                            _PastTrackingPrompt(forDate: forDate),
                            SizedBox(height: tokens.spacing.step8),
                            VoiceButton(
                              phase: state.phase,
                              dbfs: state.dbfs,
                              semanticLabel: _voiceButtonLabel(
                                context,
                                state.phase,
                              ),
                              onTap: () => ref
                                  .read(captureControllerProvider.notifier)
                                  .toggle(),
                            ),
                            SizedBox(height: tokens.spacing.step5),
                            _StateSlot(
                              state: state,
                              height: layout.stateSlotHeight,
                              liveTranscriptLineCount:
                                  layout.liveTranscriptLineCount,
                              reviewTranscriptLineCount:
                                  layout.reviewTranscriptLineCount,
                              // The modal's sticky glass bar already offers a
                              // "Type instead" pill, so drop the redundant
                              // inline link from the idle hint.
                              showInlineTypeInstead: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String? _timeSpentTitle(BuildContext context) {
    final date = forDate;
    if (date == null) return null;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(date.year, date.month, date.day);
    if (picked.isAtSameMomentAs(today)) return null;
    return context.messages.dailyOsNextTimeSpentTitlePast;
  }

  String _voiceButtonLabel(BuildContext context, CapturePhase phase) {
    switch (phase) {
      case CapturePhase.idle:
      case CapturePhase.error:
        return context.messages.dailyOsNextCaptureVoiceButtonStart;
      case CapturePhase.listening:
        return context.messages.dailyOsNextCaptureVoiceButtonStop;
      case CapturePhase.transcribing:
      case CapturePhase.captured:
        return context.messages.dailyOsNextCaptureVoiceButtonReset;
    }
  }
}

class _GreetingBlock extends ConsumerWidget {
  const _GreetingBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final userName = ref.watch(
      dailyOsPreferencesControllerProvider.select((prefs) => prefs.userName),
    );
    final hour = clock.now().hour;
    final greetingWord = hour < 12
        ? context.messages.dailyOsNextGreetingMorning
        : hour < 18
        ? context.messages.dailyOsNextGreetingAfternoon
        : context.messages.dailyOsNextGreetingEvening;
    // Calm three-tier hierarchy: quiet greeting line over a 23/600
    // page title — contrast carries the hierarchy, not size.
    return Column(
      children: [
        Text(
          userName.isEmpty
              ? context.messages.dailyOsNextGreetingHi
              : context.messages.dailyOsNextGreetingHiName(userName),
          style: calmGreetingStyle(tokens),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          greetingWord,
          style: calmPageTitleStyle(tokens),
        ),
      ],
    );
  }
}

class _PastTrackingPrompt extends StatelessWidget {
  const _PastTrackingPrompt({this.forDate});

  final DateTime? forDate;

  @override
  Widget build(BuildContext context) {
    final date = forDate;
    if (date == null) return const SizedBox.shrink();
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(date.year, date.month, date.day);
    if (!picked.isBefore(today)) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    final formatted = DateFormat.MMMd(locale).format(date);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Text(
        context.messages.dailyOsNextCapturePastPrompt(formatted),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({this.forDate});

  /// When Capture is mounted for a non-today date, the trailing
  /// "for today?" copy is swapped for `for <formatted date>?` so the
  /// headline doesn't mislead.
  final DateTime? forDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tail = _resolveTail(context);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        // Calm hero — 34/500, the single large display line on this
        // screen (was the louder 35/700 heading1).
        style: calmHeroStyle(tokens),
        children: [
          TextSpan(
            text: '${context.messages.dailyOsNextCaptureHeadlineLead} ',
          ),
          TextSpan(
            text: tail,
            style: TextStyle(color: tokens.colors.text.lowEmphasis),
          ),
        ],
      ),
    );
  }

  String _resolveTail(BuildContext context) {
    final messages = context.messages;
    final date = forDate;
    if (date == null) return messages.dailyOsNextCaptureHeadlineTail;
    final now = clock.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final picked = DateTime.utc(date.year, date.month, date.day);
    if (picked.isAtSameMomentAs(today)) {
      return messages.dailyOsNextCaptureHeadlineTail;
    }
    final delta = picked.difference(today).inDays;
    if (delta == 1) return messages.dailyOsNextCaptureHeadlineTailTomorrow;
    if (delta == -1) return messages.dailyOsNextCaptureHeadlineTailYesterday;
    final locale = Localizations.localeOf(context).toString();
    final formatted = DateFormat.MMMd(locale).format(date);
    return messages.dailyOsNextCaptureHeadlineTailForDate(formatted);
  }
}

class _StateSlot extends StatelessWidget {
  const _StateSlot({
    required this.state,
    required this.height,
    required this.liveTranscriptLineCount,
    required this.reviewTranscriptLineCount,
    this.showInlineTypeInstead = true,
  });

  final CaptureState state;
  final double height;
  final int liveTranscriptLineCount;
  final int reviewTranscriptLineCount;

  /// Whether the idle hint includes the inline "Type instead" link. The
  /// modal host sets this false because its sticky glass bar carries the
  /// same action.
  final bool showInlineTypeInstead;

  @override
  Widget build(BuildContext context) {
    final row = Align(
      alignment: Alignment.topCenter,
      child: _StateRow(
        state: state,
        height: height,
        liveTranscriptLineCount: liveTranscriptLineCount,
        reviewTranscriptLineCount: reviewTranscriptLineCount,
        showInlineTypeInstead: showInlineTypeInstead,
      ),
    );

    if (state.phase == CapturePhase.captured) {
      return ConstrainedBox(
        key: const Key('daily_os_capture_state_slot'),
        constraints: BoxConstraints(minHeight: height),
        child: row,
      );
    }

    return SizedBox(
      key: const Key('daily_os_capture_state_slot'),
      height: height,
      child: row,
    );
  }
}

class _StateRow extends ConsumerWidget {
  const _StateRow({
    required this.state,
    required this.height,
    required this.liveTranscriptLineCount,
    required this.reviewTranscriptLineCount,
    this.showInlineTypeInstead = true,
  });

  final CaptureState state;
  final double height;
  final int liveTranscriptLineCount;
  final int reviewTranscriptLineCount;
  final bool showInlineTypeInstead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    switch (state.phase) {
      case CapturePhase.idle:
        return _IdleCaptureActions(
          showTypeInstead: showInlineTypeInstead,
          onTypeInstead: () =>
              ref.read(captureControllerProvider.notifier).startTyping(),
        );
      case CapturePhase.listening:
        return SizedBox(
          key: const Key('daily_os_capture_listening_status_area'),
          height: height,
          child: Column(
            children: [
              SizedBox(height: tokens.spacing.step3),
              Text(
                messages.dailyOsNextCaptureListening,
                style: calmEyebrowStyle(
                  tokens,
                  color: tokens.colors.interactive.enabled,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              LiveWaveform(amplitudes: state.amplitudes),
              SizedBox(height: tokens.spacing.step4),
              _LiveTranscriptViewport(
                text: state.partialTranscript,
                color: tokens.colors.text.lowEmphasis,
                visibleLineCount: liveTranscriptLineCount,
              ),
            ],
          ),
        );
      case CapturePhase.transcribing:
        return Column(
          children: [
            Text(
              messages.dailyOsNextCaptureListening,
              style: calmEyebrowStyle(
                tokens,
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.colors.interactive.enabled,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.dailyOsNextCaptureIdleHint,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        );
      case CapturePhase.captured:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              messages.dailyOsNextCaptureCaptured,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            TranscriptEditor(
              fieldKey: const Key('daily_os_capture_transcript_editor'),
              transcript: state.transcript,
              lineCount: reviewTranscriptLineCount,
              onChanged: ref
                  .read(captureControllerProvider.notifier)
                  .updateTranscript,
            ),
          ],
        );
      case CapturePhase.error:
        return Text(
          _captureErrorMessage(context, state.error) ??
              messages.dailyOsNextCaptureIdleHint,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        );
    }
  }
}

String? _captureErrorMessage(BuildContext context, CaptureError? error) {
  final messages = context.messages;
  return switch (error) {
    CaptureError.microphonePermissionDenied =>
      messages.dailyOsNextCaptureErrorMicrophonePermissionDenied,
    CaptureError.recordingStartFailed =>
      messages.dailyOsNextCaptureErrorRecordingStartFailed,
    CaptureError.realtimeTranscriptionStartFailed =>
      messages.dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed,
    CaptureError.noActiveRealtimeSession =>
      messages.dailyOsNextCaptureErrorNoActiveRealtimeSession,
    CaptureError.realtimeTranscriptionFailed =>
      messages.dailyOsNextCaptureErrorRealtimeTranscriptionFailed,
    CaptureError.noAudioRecorded =>
      messages.dailyOsNextCaptureErrorNoAudioRecorded,
    CaptureError.transcriptionFailed =>
      messages.dailyOsNextCaptureErrorTranscriptionFailed,
    null => null,
  };
}

class _IdleCaptureActions extends StatelessWidget {
  const _IdleCaptureActions({
    required this.onTypeInstead,
    this.showTypeInstead = true,
  });

  final VoidCallback onTypeInstead;

  /// When false, only the "Tap to talk" hint renders — the inline
  /// "Type instead" link is dropped (the modal host carries it on its
  /// sticky glass bar instead).
  final bool showTypeInstead;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final talkHint = Text(
      context.messages.dailyOsNextCaptureIdleTalk,
      style: dotStyle,
    );
    if (!showTypeInstead) {
      return talkHint;
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step2,
      children: [
        talkHint,
        Container(
          width: tokens.spacing.step1,
          height: tokens.spacing.step1,
          decoration: BoxDecoration(
            color: tokens.colors.text.lowEmphasis,
            shape: BoxShape.circle,
          ),
        ),
        _InlineCaptureAction(
          label: context.messages.dailyOsNextCaptureTypeInstead,
          onTap: onTypeInstead,
        ),
      ],
    );
  }
}

class _InlineCaptureAction extends StatelessWidget {
  const _InlineCaptureAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step1,
            vertical: tokens.spacing.step1,
          ),
          child: Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.interactive.enabled,
              decoration: TextDecoration.underline,
              decorationColor: tokens.colors.interactive.enabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveTranscriptViewport extends StatelessWidget {
  const _LiveTranscriptViewport({
    required this.text,
    required this.color,
    required this.visibleLineCount,
  });

  final String text;
  final Color color;
  final int visibleLineCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textStyle = _TranscriptText.resolveStyle(
      tokens,
      color: color,
      italic: true,
    );
    final fontSize = textStyle.fontSize ?? tokens.typography.size.bodyMedium;
    final lineHeight = textStyle.height == null
        ? tokens.typography.lineHeight.bodyMedium
        : fontSize * textStyle.height!;
    final viewportHeight = lineHeight * visibleLineCount;
    return SizedBox(
      key: const Key('daily_os_capture_live_transcript_viewport'),
      height: viewportHeight,
      width: double.infinity,
      child: SingleChildScrollView(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewportHeight),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _TranscriptText(
              text: text,
              italic: true,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptText extends StatelessWidget {
  const _TranscriptText({
    required this.text,
    required this.italic,
    required this.color,
  });

  final String text;
  final bool italic;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (text.isEmpty) return const SizedBox.shrink();
    final style = resolveStyle(tokens, color: color, italic: italic);
    return Text(
      text,
      textAlign: TextAlign.center,
      strutStyle: StrutStyle.fromTextStyle(
        style,
        forceStrutHeight: true,
      ),
      style: style,
    );
  }

  static TextStyle resolveStyle(
    DsTokens tokens, {
    required Color color,
    required bool italic,
  }) {
    return tokens.typography.styles.body.bodyMedium.copyWith(
      color: color,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
  }
}

class _ReconcileCta extends ConsumerStatefulWidget {
  const _ReconcileCta({required this.state, this.forDate});

  final CaptureState state;
  final DateTime? forDate;

  @override
  ConsumerState<_ReconcileCta> createState() => _ReconcileCtaState();
}

class _ReconcileCtaState extends ConsumerState<_ReconcileCta> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (widget.state.phase != CapturePhase.captured) {
      // Reserve roughly the same vertical space so the surrounding
      // layout does not jump when the CTA appears.
      return SizedBox(height: tokens.spacing.step9);
    }
    final hasTranscript = widget.state.transcript.trim().isNotEmpty;
    return FilledButton(
      onPressed: _submitting || !hasTranscript ? null : _onSubmit,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.colors.interactive.enabled,
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.dailyOsNextCaptureReconcileCta,
            style: tokens.typography.styles.subtitle.subtitle1,
          ),
          SizedBox(width: tokens.spacing.step2),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    final transcript = widget.state.transcript.trim();
    if (transcript.isEmpty) return;
    setState(() => _submitting = true);
    final agent = ref.read(dayAgentProvider);
    final navigator = Navigator.of(context);
    try {
      final captureId = await agent.submitCapture(
        transcript: transcript,
        // `capturedAt` routes the capture to the day-agent for that
        // day. When the route-level root mounts CapturePage for a
        // non-today selected date, pass that date so the resulting
        // plan lands on the chosen day instead of today.
        capturedAt: _capturedAtForSelectedDate(widget.forDate),
        audioId: widget.state.audioId,
      );
      if (!mounted) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReconcilePage(
            captureId: captureId,
            dayDate: widget.forDate ?? clock.now(),
          ),
        ),
      );
      if (mounted) {
        ref.read(captureControllerProvider.notifier).reset();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  DateTime _capturedAtForSelectedDate(DateTime? selectedDate) =>
      capturedAtForSelectedDate(clock.now(), selectedDate);
}

/// Resolves the `capturedAt` timestamp for a submitted capture: the
/// calendar day of [selectedDate] combined with the current time-of-day
/// from [now]. When [selectedDate] is null (the route mounts for today),
/// [now] is returned unchanged.
///
/// Pure and clock-injected so the year/month/day-vs-time-of-day invariant
/// can be property-tested at month/year boundaries without widget setup.
@visibleForTesting
DateTime capturedAtForSelectedDate(DateTime now, DateTime? selectedDate) {
  if (selectedDate == null) return now;
  return DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
  );
}
