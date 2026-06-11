import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/text_scale_policy.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/edge_fade.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/transcript_editor.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Max width for the centred capture column and the "Today so far" card so
/// the calm single column reads comfortably on wide layouts. Defined once so
/// the standalone page and the modal content can't drift apart.
const double _captureContentMaxWidth = 560;

/// Entry surface of the agentic Daily OS — voice-first check-in.
///
/// Layout contract (shared with [CaptureModalContent] via the same body):
/// the orb is **anchored to the bottom** of the surface, directly above the
/// action area, and never moves between phases. The live transcript grows
/// *upward* from just above the orb inside a bounded viewport; the header
/// swaps copy per phase at the top. Nothing the user is touching ever
/// shifts under their finger.
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
          child: _CaptureSurface(
            forDate: forDate,
            actualBlocks: actualBlocks,
            showInlineAdvanceCta: true,
          ),
        ),
      ),
    );
  }
}

/// Scaffold-free capture content for hosting inside the day-planning modal.
///
/// Same anchored body as the standalone page, but without page chrome or
/// the inline advance CTA — the modal supplies a top bar and a sticky glass
/// action bar that carries every clickable action instead.
class CaptureModalContent extends StatelessWidget {
  const CaptureModalContent({
    this.forDate,
    this.actualBlocks = const [],
    super.key,
  });

  final DateTime? forDate;
  final List<TimeBlock> actualBlocks;

  @override
  Widget build(BuildContext context) {
    return _CaptureSurface(
      forDate: forDate,
      actualBlocks: actualBlocks,
      showInlineAdvanceCta: false,
    );
  }
}

/// Shared capture surface: optional "Today so far" card pinned on top, the
/// anchored capture body below.
class _CaptureSurface extends ConsumerWidget {
  const _CaptureSurface({
    required this.forDate,
    required this.actualBlocks,
    required this.showInlineAdvanceCta,
  });

  final DateTime? forDate;
  final List<TimeBlock> actualBlocks;

  /// Whether the captured phase renders its own advance CTA inside the
  /// body (standalone page) instead of relying on a host action bar
  /// (modal).
  final bool showInlineAdvanceCta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    // Meter ticks (amplitudes/dbfs, many per second while listening) only
    // rebuild the orb zone, which watches those fields itself.
    final state = ref.watch(
      captureControllerProvider.select((s) => s.withoutMeter),
    );

    return Column(
      children: [
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
                  title: _timeSpentTitle(context, forDate),
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _captureContentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step6,
                  tokens.spacing.step5,
                  tokens.spacing.step5,
                ),
                child: _CaptureFlowBody(
                  state: state,
                  forDate: forDate,
                  showInlineAdvanceCta: showInlineAdvanceCta,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The anchored capture skeleton.
///
/// ```text
/// header (greeting + per-phase headline)   ← top, copy swaps in place
/// transcript zone                           ← Expanded, grows upward
/// orb zone (waveform · orb · caption)       ← fixed height, fixed position
/// [inline advance CTA]                      ← standalone page only
/// ```
///
/// Stability contract: the orb zone's height is identical in every phase
/// (the waveform slot is always reserved, the caption is a single fixed
/// strut line), so the orb never moves while the user interacts with it.
/// Phase-dependent header height differences are absorbed by the
/// transcript zone, never by the orb.
class _CaptureFlowBody extends ConsumerWidget {
  const _CaptureFlowBody({
    required this.state,
    required this.forDate,
    required this.showInlineAdvanceCta,
  });

  final CaptureState state;
  final DateTime? forDate;
  final bool showInlineAdvanceCta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(captureControllerProvider.notifier);

    // At very large accessibility text the headline can no longer share a
    // pocket-phone viewport with the orb; remove it from layout entirely
    // (never height-clip it — a partially visible glyph reads as a
    // rendering defect) and let the zone + orb carry the screen.
    final showHeader = dailyOsTextScaleOf(context) < kDailyOsHideHeaderScale;

    final body = Column(
      children: [
        if (showHeader) ...[
          _CaptureHeader(phase: state.phase, forDate: forDate),
          SizedBox(height: tokens.spacing.step4),
        ],
        Expanded(
          child: _TranscriptZone(state: state, notifier: notifier),
        ),
        SizedBox(height: tokens.spacing.step4),
        _OrbZone(state: state, onTap: notifier.toggle),
        if (showInlineAdvanceCta) ...[
          SizedBox(height: tokens.spacing.step5),
          _InlineFooterSlot(state: state, forDate: forDate),
        ],
      ],
    );

    // Canonical fill-or-scroll pattern: on a normal viewport the column
    // fills it exactly and the transcript zone takes the slack (orb pinned
    // at the bottom). Under squeeze — huge accessibility text, tiny or
    // split windows — the zone shrinks toward zero first, and only when
    // the fixed parts alone (header, orb zone, footer slot) exceed the
    // viewport does the body scroll. No height estimates: the fixed parts
    // measure themselves via IntrinsicHeight.
    //
    // `reverse: true` so the scroll fallback anchors the BOTTOM: the orb,
    // its caption, and the newest spoken words must stay on screen at any
    // text scale — it is the headline that scrolls away, never the voice
    // control (a 2x-text reviewer otherwise loses the orb entirely and
    // cannot start the flow).
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget scroll = SingleChildScrollView(
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: body),
          ),
        );
        if (!showHeader) {
          // Under squeeze the reverse scroll can cut content at the top
          // edge; dissolve it instead of slicing glyphs mid-x-height.
          final lineHeight = MediaQuery.textScalerOf(
            context,
          ).scale(tokens.typography.lineHeight.bodyMedium);
          scroll = EdgeFade(
            rampExtent: lineHeight * 1.2,
            child: scroll,
          );
        }
        return scroll;
      },
    );
  }
}

/// Standalone-page footer slot below the orb zone. Hosts the phase's
/// inline action — "Type instead" while idle, the advance CTA once
/// captured — inside one reserved-height slot so the orb above never
/// moves. (The modal host has no such slot; its sticky glass bar carries
/// these actions.)
class _InlineFooterSlot extends ConsumerWidget {
  const _InlineFooterSlot({required this.state, this.forDate});

  final CaptureState state;
  final DateTime? forDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    switch (state.phase) {
      case CapturePhase.captured:
        return _ReconcileCta(state: state, forDate: forDate);
      case CapturePhase.idle:
      case CapturePhase.error:
        return SizedBox(
          height: tokens.spacing.step9,
          child: Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(captureControllerProvider.notifier).startTyping(),
              style: TextButton.styleFrom(
                foregroundColor: tokens.colors.interactive.enabled,
              ),
              child: Text(
                context.messages.dailyOsNextCaptureTypeInstead,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.interactive.enabled,
                ),
              ),
            ),
          ),
        );
      case CapturePhase.listening:
      case CapturePhase.transcribing:
        return SizedBox(height: tokens.spacing.step9);
    }
  }
}

// ─────────────────────────────── Header ────────────────────────────────

/// Quiet greeting line over a per-phase headline. The headline cross-fades
/// when the phase changes; layout differences are absorbed below it.
class _CaptureHeader extends ConsumerWidget {
  const _CaptureHeader({required this.phase, required this.forDate});

  final CapturePhase phase;
  final DateTime? forDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final userName = ref.watch(
      dailyOsPreferencesControllerProvider.select((prefs) => prefs.userName),
    );
    final hour = clock.now().hour;
    final greetingWord = hour < 12
        ? messages.dailyOsNextGreetingMorning
        : hour < 18
        ? messages.dailyOsNextGreetingAfternoon
        : messages.dailyOsNextGreetingEvening;
    final greeting = userName.isEmpty
        ? greetingWord
        : '${messages.dailyOsNextGreetingHiName(userName)} · $greetingWord';

    return Column(
      children: [
        Text(
          greeting,
          style: calmGreetingStyle(tokens),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: tokens.spacing.step3),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [...previousChildren, ?currentChild],
          ),
          child: KeyedSubtree(
            key: ValueKey<CapturePhase>(_headlineGroup(phase)),
            child: _Headline(phase: phase, forDate: forDate),
          ),
        ),
        _PastTrackingPrompt(forDate: forDate),
      ],
    );
  }

  /// Idle and error share the idle headline so an error doesn't flash a
  /// new headline on top of the error message.
  CapturePhase _headlineGroup(CapturePhase phase) =>
      phase == CapturePhase.error ? CapturePhase.idle : phase;
}

class _Headline extends StatelessWidget {
  const _Headline({required this.phase, this.forDate});

  final CapturePhase phase;

  /// When Capture is mounted for a non-today date, the trailing
  /// "for today?" copy is swapped for `for <formatted date>?` so the
  /// headline doesn't mislead.
  final DateTime? forDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final style = calmDisplayStyle(tokens);

    switch (phase) {
      case CapturePhase.idle:
      case CapturePhase.error:
        // Text.rich (not RichText) so the ambient textScaler applies — the
        // headline must grow with accessibility text sizes like everything
        // else.
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: '${messages.dailyOsNextCaptureHeadlineLead} '),
              TextSpan(
                text: _resolveTail(context),
                style: TextStyle(color: tokens.colors.text.lowEmphasis),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case CapturePhase.listening:
        return Text(
          messages.dailyOsNextCaptureHeadlineListening,
          textAlign: TextAlign.center,
          style: style,
        );
      case CapturePhase.transcribing:
        return Text(
          messages.dailyOsNextCaptureHeadlineTranscribing,
          textAlign: TextAlign.center,
          style: style,
        );
      case CapturePhase.captured:
        return Text(
          messages.dailyOsNextCaptureHeadlineCaptured,
          textAlign: TextAlign.center,
          style: style,
        );
    }
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
    // Weekday included everywhere a concrete date is planned — "Jun 8"
    // forces a mental calendar lookup; "Wed, Jun 8" answers it.
    final formatted = DateFormat.MMMEd(locale).format(date);
    return messages.dailyOsNextCaptureHeadlineTailForDate(formatted);
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
    final formatted = DateFormat.MMMEd(locale).format(date);
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

// ──────────────────────────── Transcript zone ──────────────────────────

/// Bounded area between the header and the orb where words materialise.
///
/// While listening/transcribing the live transcript is pinned to the
/// *bottom* of the zone — text appears right above the orb and grows
/// upward, the oldest words dissolving under a top fade once the zone is
/// full. In the captured phase the same zone hosts the editable
/// transcript. Idle shows a quiet example utterance where the live words
/// will land; errors render here in place of text.
class _TranscriptZone extends StatelessWidget {
  const _TranscriptZone({required this.state, required this.notifier});

  final CaptureState state;
  final CaptureController notifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    switch (state.phase) {
      case CapturePhase.idle:
        // Static content sits directly under the headline — pooling the
        // flexible slack between question and content read as a dead band;
        // the slack now lives between content and orb instead.
        // Attached below the headline so greeting/headline/example read as
        // one editorial block above the mic stage — not a quote floating
        // unanchored in the middle of the void.
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step10),
            child: Text(
              context.messages.dailyOsNextCaptureIdleExample,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      case CapturePhase.listening:
        return LiveTranscriptView(
          text: state.partialTranscript,
          color: tokens.colors.text.mediumEmphasis,
        );
      case CapturePhase.transcribing:
        return AnimatedOpacity(
          opacity: 0.55,
          duration: const Duration(milliseconds: 200),
          child: LiveTranscriptView(
            text: state.partialTranscript,
            color: tokens.colors.text.mediumEmphasis,
          ),
        );
      case CapturePhase.captured:
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
            child: TranscriptEditor(
              fieldKey: const Key('daily_os_capture_transcript_editor'),
              transcript: state.transcript,
              lineCount: 3,
              onChanged: notifier.updateTranscript,
            ),
          ),
        );
      case CapturePhase.error:
        return Center(
          child: Text(
            _captureErrorMessage(context, state.error) ??
                context.messages.dailyOsNextCaptureIdleHint,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        );
    }
  }
}

// ─────────────────────────────── Orb zone ──────────────────────────────

/// Capture's parameterisation of the shared [VoiceOrbZone]: resolves the
/// status caption, its color, and the semantic label per [CapturePhase].
/// The caption is status only — actions live on the orb and the host's
/// action bar.
///
/// Watches the meter fields itself (the parent watches `withoutMeter`),
/// so amplitude ticks rebuild only this zone.
class _OrbZone extends ConsumerWidget {
  const _OrbZone({required this.state, required this.onTap});

  final CaptureState state;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (amplitudes, dbfs) = ref.watch(
      captureControllerProvider.select((s) => (s.amplitudes, s.dbfs)),
    );
    final (caption, captionColor) = switch (state.phase) {
      CapturePhase.idle || CapturePhase.error => (
        voiceIdleHint(context),
        tokens.colors.text.lowEmphasis,
      ),
      CapturePhase.listening => (
        messages.dailyOsNextCaptureListeningStatus,
        tokens.colors.text.mediumEmphasis,
      ),
      CapturePhase.transcribing => (
        messages.dailyOsNextCaptureTranscribing,
        tokens.colors.text.mediumEmphasis,
      ),
      CapturePhase.captured => (
        messages.dailyOsNextCaptureCaptured,
        tokens.colors.text.mediumEmphasis,
      ),
    };

    return VoiceOrbZone(
      phase: state.phase,
      caption: caption,
      captionColor: captionColor,
      semanticLabel: _voiceButtonLabel(context, state.phase),
      amplitudes: amplitudes,
      dbfs: dbfs,
      onTap: onTap,
    );
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

String? _timeSpentTitle(BuildContext context, DateTime? forDate) {
  final date = forDate;
  if (date == null) return null;
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = DateTime(date.year, date.month, date.day);
  if (picked.isAtSameMomentAs(today)) return null;
  return context.messages.dailyOsNextTimeSpentTitlePast;
}

// ───────────────────────── Inline advance CTA ──────────────────────────

/// Standalone-page advance CTA. Only built in the captured phase — the
/// hosting [_InlineFooterSlot] reserves the space in every other phase.
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
