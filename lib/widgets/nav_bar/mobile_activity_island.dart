import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/time_service.dart';
// Only the numeric font features: the same tabular/slashed-zero set the task
// action bar's Track time pill and the sidebar timer use, so every elapsed
// clock in the app ticks without changing width.
import 'package:lotti/themes/theme_text_styles.dart'
    show numericBadgeFontFeatures;
import 'package:lotti/widgets/misc/timer_navigation.dart';
import 'package:material_ui/material_ui.dart';

/// The mobile shell's "something is running" island: one glass capsule that
/// floats above the bottom navigation while a time recording and/or an
/// audio recording runs somewhere other than the page on screen.
///
/// It replaced two square-bottomed *tabs* that were drawn to sit flush on
/// the top edge of the old full-width bar. The launcher is not a bar — it is
/// a transparent strip with centred glass chips — so the tabs floated in
/// mid-air over page content with nothing to be an extension of, in the
/// legacy Material palette rather than the launcher's glass. The island is
/// built from the same vocabulary as those chips ([DsGlassChipSurface],
/// [dsGlassChipFill], [dsGlassChipBorder]) and floats [gapAboveBar] above
/// whichever bar the shell shows, so it reads the same over the launcher and
/// over the classic five-slot bar.
///
/// A running timer is a red dot and its elapsed time; a live recording is
/// the level orb and its elapsed time; both at once share the capsule with a
/// hairline between them. Each half is its own button — the timer opens the
/// running entry ([navigateToTimerTarget]), the recording reopens its modal —
/// and the halves meet at the hairline and reach the capsule's ends, so every
/// point of the pill is a target. With nothing running the island renders
/// nothing and reserves nothing.
///
/// Which recordings count is decided once, in [showsRecording], and the
/// shell's overlay-height scope reads the same rule — so the space pages
/// reserve for the island can never disagree with what it renders.
///
/// Prose degrades before payloads, as on the launcher beside it: when both
/// halves no longer fit the window with their digits — large accessibility
/// text on a narrow phone — the recording half drops to its orb
/// ([bothHalvesFit]). The orb still says "live"; the timer's digits have no
/// glyph-only reading, so they are the payload that never gives.
class MobileActivityIsland extends ConsumerWidget {
  const MobileActivityIsland({required this.omitAudio, super.key});

  /// Whether the recording half is left out altogether. Flatpak builds carry
  /// no MediaKit-backed recorder, so the shell passes true there.
  final bool omitAudio;

  static const Key capsuleKey = ValueKey('mobileActivityIsland');
  static const Key timerKey = ValueKey('mobileActivityIslandTimer');
  static const Key recordingKey = ValueKey('mobileActivityIslandRecording');
  static const Key dividerKey = ValueKey('mobileActivityIslandDivider');

  /// Rendered height of the capsule, which is also its tap height: a step
  /// under the 48 px chips it floats above at the default text size, so it
  /// reads as their subordinate rather than a third peer on the row.
  ///
  /// Like the launcher's chips, it grows with the system text scale rather
  /// than clipping: the `subtitle2` line the digits sit on, scaled the way
  /// the text itself is, inside `spacing.step2` of air above and below —
  /// never below `spacing.step8`. Fractional scaled lines round up, since
  /// Flutter snaps the rendered line to a whole logical pixel too.
  static double capsuleHeight(BuildContext context) {
    final tokens = context.designTokens;
    final scaledLine = MediaQuery.textScalerOf(
      context,
    ).scale(tokens.typography.lineHeight.subtitle2).ceilToDouble();
    return math.max(
      tokens.spacing.step8,
      scaledLine + tokens.spacing.step2 * 2,
    );
  }

  /// Air between the capsule and the bar (or the safe-area edge, once the
  /// bar has slid away).
  static double gapAboveBar(BuildContext context) =>
      context.designTokens.spacing.step3;

  /// Vertical estate the island claims above the bar while it shows. Pages
  /// pad their scrollables by this through the shell's overlay-height scope.
  static double reservedHeight(BuildContext context) =>
      capsuleHeight(context) + gapAboveBar(context);

  /// Whether [state] is a recording the island shows: a session in flight —
  /// recording, or paused mid-session, which the modal treats as active too
  /// — with its modal closed, and not on a build that omits audio. A paused
  /// session with its modal dismissed has no other way back on the phone.
  static bool showsRecording(
    AudioRecorderState state, {
    required bool omitAudio,
  }) =>
      !omitAudio &&
      (state.status == AudioRecorderStatus.recording ||
          state.status == AudioRecorderStatus.paused) &&
      !state.modalVisible;

  /// Horizontal room the capsule may take: the window inside its safe-area
  /// insets and the same gutters the launcher keeps.
  static double availableWidth(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return MediaQuery.sizeOf(context).width -
        insets.left -
        insets.right -
        context.designTokens.spacing.step3 * 2;
  }

  /// Whether both halves fit side by side with their digits intact at the
  /// current text scale — the capsule's own insets, the dot, the orb, the
  /// hairline band and both elapsed times measured as they will paint.
  /// Below the threshold the recording half renders its orb alone.
  ///
  /// Measured rather than guessed, like the launcher's `labelsFit`: the digits
  /// are user-scaled, so no fixed breakpoint can tell whether `01:15:45` and
  /// `00:03:12` share a 320 px window at 3×.
  static bool bothHalvesFit(
    BuildContext context, {
    required String timerElapsed,
    required String recordingElapsed,
  }) {
    final style = _elapsedStyle(context.designTokens);
    final needed =
        _insetWidth(context) * 2 +
        _timerGlyphWidth(context) +
        _measure(context, timerElapsed, style) +
        _dividerBandWidth(context) +
        _recordingGlyphWidth(context) +
        _measure(context, recordingElapsed, style);
    return needed <= availableWidth(context);
  }

  static double _insetWidth(BuildContext context) =>
      context.designTokens.spacing.step4;

  /// The dot and the gap that follows it.
  static double _timerGlyphWidth(BuildContext context) =>
      context.designTokens.spacing.step4 + context.designTokens.spacing.step3;

  /// The orb and the gap that follows it.
  static double _recordingGlyphWidth(BuildContext context) =>
      context.designTokens.spacing.step6 + context.designTokens.spacing.step3;

  /// The hairline and the air on either side of it, which the neighbouring
  /// halves carry as their own inner insets.
  static double _dividerBandWidth(BuildContext context) =>
      context.designTokens.spacing.step3 * 2 + BorderWidths.hairline;

  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = getIt<TimeService>();
    AudioRecorderState? recording;
    try {
      final state = ref.watch(audioRecorderControllerProvider);
      if (showsRecording(state, omitAudio: omitAudio)) recording = state;
    } catch (_) {
      // Audio/MediaKit wiring failed to build: the island degrades to the
      // timer half instead of taking the shell down with it.
      recording = null;
    }

    return StreamBuilder<JournalEntity?>(
      // Seeded so an already-running timer shows on the first frame instead
      // of waiting a second for the stream's next tick.
      initialData: timeService.getCurrent(),
      stream: timeService.getStream(),
      builder: (context, snapshot) {
        final timer = snapshot.data;
        if (timer == null && recording == null) {
          return const SizedBox.shrink();
        }
        return _Capsule(
          timer: timer,
          linkedFrom: timeService.linkedFrom,
          recording: recording,
        );
      },
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.timer,
    required this.linkedFrom,
    required this.recording,
  });

  final JournalEntity? timer;
  final JournalEntity? linkedFrom;
  final AudioRecorderState? recording;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final timer = this.timer;
    final recording = this.recording;
    final both = timer != null && recording != null;
    final timerElapsed = timer == null
        ? null
        : formatDuration(entryDuration(timer));
    final recordingElapsed = recording == null
        ? null
        : formatDuration(recording.progress);
    final recordingDigits =
        !both ||
        MobileActivityIsland.bothHalvesFit(
          context,
          timerElapsed: timerElapsed!,
          recordingElapsed: recordingElapsed!,
        );
    // The capsule's insets and the air around the hairline belong to the
    // halves, not to the container, so the whole pill is a tap target: an
    // outer end of the capsule and the band around the divider are the
    // neighbouring half's own padding.
    final outer = spacing.step4;
    final inner = spacing.step3;
    return Center(
      child: DsGlassChipSurface(
        radius: radius,
        blurred: true,
        child: Container(
          key: MobileActivityIsland.capsuleKey,
          height: MobileActivityIsland.capsuleHeight(context),
          decoration: BoxDecoration(
            color: dsGlassChipFill(tokens),
            borderRadius: radius,
          ),
          // The hairline is a foreground decoration, as on every glass chip:
          // painted over the fill without widening the capsule.
          foregroundDecoration: BoxDecoration(
            border: dsGlassChipBorder(tokens),
            borderRadius: radius,
          ),
          // Last resort beneath [MobileActivityIsland.bothHalvesFit]: on a
          // window where even the degraded content cannot fit — a lone
          // elapsed time at the largest text scale on the narrowest phone —
          // the content shrinks to the window rather than clipping a digit.
          // At every size the rule handles, the box renders at its natural
          // size and this is a no-op.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: MobileActivityIsland.capsuleHeight(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // Stretched, so each half's tap target is the capsule's full
                // height rather than its text line.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (timer != null)
                    _TimerSegment(
                      entry: timer,
                      elapsed: timerElapsed!,
                      linkedFrom: linkedFrom,
                      inset: EdgeInsetsDirectional.only(
                        start: outer,
                        end: both ? inner : outer,
                      ),
                    ),
                  if (both) const _SegmentDivider(),
                  if (recording != null)
                    _RecordingSegment(
                      state: recording,
                      elapsed: recordingElapsed!,
                      showDigits: recordingDigits,
                      inset: EdgeInsetsDirectional.only(
                        start: both ? inner : outer,
                        end: outer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The elapsed-time style both halves share: the chip register, in the
/// tabular figures that keep the digits from shifting width as they tick.
TextStyle _elapsedStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

class _TimerSegment extends ConsumerWidget {
  const _TimerSegment({
    required this.entry,
    required this.elapsed,
    required this.linkedFrom,
    required this.inset,
  });

  final JournalEntity entry;
  final String elapsed;
  final JournalEntity? linkedFrom;
  final EdgeInsetsGeometry inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    void open() => navigateToTimerTarget(
      current: entry,
      linkedFrom: linkedFrom,
      ref: ref,
    );
    return Semantics(
      button: true,
      label: '${messages.sidebarRunningTimerLabel}, $elapsed',
      hint: messages.taskActionBarOpenRunningTimer,
      onTap: open,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: MobileActivityIsland.timerKey,
            behavior: HitTestBehavior.opaque,
            onTap: open,
            child: Padding(
              padding: inset,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: tokens.spacing.step4,
                    height: tokens.spacing.step4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.colors.alert.error.defaultColor,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Text(elapsed, style: _elapsedStyle(tokens)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingSegment extends ConsumerWidget {
  const _RecordingSegment({
    required this.state,
    required this.elapsed,
    required this.showDigits,
    required this.inset,
  });

  final AudioRecorderState state;
  final String elapsed;

  /// False under width pressure: the orb alone stands for the recording.
  final bool showDigits;
  final EdgeInsetsGeometry inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final linkedId = state.linkedId;
    // Watched, not only read at tap time: the provider is autoDispose, and
    // the subscription is what keeps the linked entry loaded and warm for
    // as long as this half is on screen.
    if (linkedId != null) ref.watch(entryControllerProvider(linkedId));
    // The modal takes the linked entry's category so an uncategorised
    // session cannot inherit an earlier one — which is exactly why it must
    // not be handed `null` merely because the entry is still loading. The
    // category is resolved at tap time and awaited: a null after the await
    // is a missing entry (or one that failed to load), never a loading
    // state.
    Future<void> reopen() async {
      String? categoryId;
      if (linkedId != null) {
        try {
          final loaded = await ref.read(
            entryControllerProvider(linkedId).future,
          );
          categoryId = loaded?.entry?.categoryId;
        } catch (_) {
          categoryId = null;
        }
        if (!context.mounted) return;
      }
      // Taps queued behind that await must not stack sheets: by the time a
      // later one resumes, the first has already opened the modal (which
      // marks itself visible) or the session has ended, and either way there
      // is nothing left to reopen.
      final current = ref.read(audioRecorderControllerProvider);
      if (!MobileActivityIsland.showsRecording(current, omitAudio: false)) {
        return;
      }
      await AudioRecordingModal.show(
        context,
        linkedId: linkedId,
        categoryId: categoryId,
        useRootNavigator: false,
      );
    }

    return Semantics(
      button: true,
      // Announced with its time either way: the digits may leave the
      // capsule under width pressure, never the announcement.
      label: '${context.messages.taskActionBarAudioRecordingActive}, $elapsed',
      onTap: () => unawaited(reopen()),
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: MobileActivityIsland.recordingKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(reopen()),
            child: Padding(
              padding: inset,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AudioRecordingOrb(
                    dBFS: state.dBFS,
                    size: tokens.spacing.step6,
                  ),
                  if (showDigits) ...[
                    SizedBox(width: tokens.spacing.step3),
                    Text(elapsed, style: _elapsedStyle(tokens)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hairline between the two halves when both run. It carries no air of
/// its own — the halves on either side pad up to it, so a tap beside the
/// rule still lands on a half.
class _SegmentDivider extends StatelessWidget {
  const _SegmentDivider();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: SizedBox(
        key: MobileActivityIsland.dividerKey,
        width: BorderWidths.hairline,
        height: tokens.spacing.step5,
        child: ColoredBox(color: tokens.colors.decorative.level01),
      ),
    );
  }
}
