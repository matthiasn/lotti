import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
// Only the numeric font features: the same tabular/slashed-zero set the task
// action bar's Track time pill and the sidebar timer use, so every elapsed
// clock in the app ticks without changing width.
import 'package:lotti/themes/theme_text_styles.dart'
    show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:lotti/widgets/misc/timer_navigation.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

/// Which of the island's items are running, as the shell lays out around
/// them: whether a time recording runs, and whether a recording the island
/// shows ([MobileActivityIsland.showsRecording]) does.
@immutable
class MobileActivity {
  const MobileActivity({required this.timer, required this.recording});

  static const none = MobileActivity(timer: false, recording: false);

  final bool timer;
  final bool recording;

  /// How many capsules the island stacks.
  int get count => (timer ? 1 : 0) + (recording ? 1 : 0);

  bool get isEmpty => count == 0;

  @override
  bool operator ==(Object other) =>
      other is MobileActivity &&
      other.timer == timer &&
      other.recording == recording;

  @override
  int get hashCode => Object.hash(timer, recording);
}

/// Watches the running timer and the recorder once and hands the shell the
/// resulting [MobileActivity], so the launcher's reserved centre, the
/// island's position and the estate pages pad by all read the same rule
/// as what the island renders.
///
/// The timer stream ticks every second while a timer runs, but only whether
/// one runs matters here — the island ticks its own digits — so [builder]
/// runs when a timer starts or stops, not on every tick. [child] is a
/// prebuilt subtree passed through untouched.
class MobileActivityBuilder extends ConsumerStatefulWidget {
  const MobileActivityBuilder({
    required this.omitAudio,
    required this.builder,
    required this.child,
    super.key,
  });

  /// See [MobileActivityIsland.omitAudio].
  final bool omitAudio;

  final Widget Function(
    BuildContext context,
    MobileActivity activity,
    Widget child,
  )
  builder;

  final Widget child;

  @override
  ConsumerState<MobileActivityBuilder> createState() =>
      _MobileActivityBuilderState();
}

class _MobileActivityBuilderState extends ConsumerState<MobileActivityBuilder> {
  /// Whether a timer runs, seeded like the island so a timer already running
  /// on the first frame claims its room on that frame too.
  late final bool _timerAtStart;

  /// Created once: a mapped stream built in [build] would resubscribe on
  /// every rebuild.
  late final Stream<bool> _timerRuns;

  @override
  void initState() {
    super.initState();
    final timeService = ref.read(timeServiceProvider);
    _timerAtStart = timeService.getCurrent() != null;
    _timerRuns = timeService.getStream().map((e) => e != null).distinct();
  }

  @override
  Widget build(BuildContext context) {
    // Same guard as the island: if the recorder controller fails to build
    // (MediaKit/audio issues), no recording shows, so none counts here.
    bool recording;
    try {
      recording = ref.watch(
        audioRecorderControllerProvider.select(
          (state) => MobileActivityIsland.showsRecording(
            state,
            omitAudio: widget.omitAudio,
          ),
        ),
      );
    } catch (_) {
      recording = false;
    }

    return StreamBuilder<bool>(
      initialData: _timerAtStart,
      stream: _timerRuns,
      builder: (context, snapshot) => widget.builder(
        context,
        MobileActivity(timer: snapshot.data ?? false, recording: recording),
        widget.child,
      ),
    );
  }
}

/// The mobile shell's "something is running" island: glass capsules that
/// sit in the bottom navigation row, centred between the leading chips and
/// the page action, while a time recording and/or an audio recording runs
/// somewhere other than the page on screen.
///
/// It is built from the launcher chips' own vocabulary
/// ([DsGlassChipSurface], [dsGlassChipFill], [dsGlassChipBorder]) so the row
/// reads as one glass dialect, a step shorter than the chips so it reads as
/// their subordinate rather than a third peer.
///
/// A running timer is a red dot and its elapsed time; a live recording is
/// the level orb and its elapsed time. Each is a button — the timer opens
/// the running entry ([navigateToTimerTarget]), the recording reopens its
/// modal. Both at once share one capsule, a hairline between the halves,
/// which meet at it and reach the capsule's ends so every point of the pill
/// is a target.
///
/// Only when the row has no room for that capsule does the shell pass
/// [stacked]: the two become capsules of their own, timer above recording
/// at one shared width. The lowest capsule keeps the row's centre line, so
/// a stack grows upward out of the row rather than pushing the row down or
/// clipping ([dockedBottom]). The order the shell tries, and the floating
/// fallback past it, is [MobileIslandLayout.resolve]'s. With nothing running
/// the island renders nothing and reserves nothing.
///
/// The island belongs to the launcher row, so it shows only while that row
/// is docked — where the menu button and, on list tabs, the page's add
/// action are on screen. A page that owns the bottom edge with a sticky
/// action bar (a task, entry or event detail, a settings editor such as Edit
/// category, a project, goal, habit or person page) has no such row, and the
/// island never shows there: it would only compete with the page's own
/// primary actions. The shell applies this rule.
///
/// Which recordings count is decided once, in [showsRecording], and the
/// shell reads the same rule through [MobileActivityBuilder] — so the space
/// the row and the pages reserve for the island can never disagree with
/// what it renders.
class MobileActivityIsland extends ConsumerWidget {
  const MobileActivityIsland({
    required this.omitAudio,
    this.stacked = false,
    super.key,
  });

  /// Whether the recording half is left out altogether. Flatpak builds
  /// carry no MediaKit-backed recorder, so the shell passes true there.
  final bool omitAudio;

  /// Whether a timer and a recording running together stack as two
  /// capsules instead of sharing one. Meaningless with one item running.
  final bool stacked;

  static const Key islandKey = ValueKey('mobileActivityIsland');
  static const Key timerKey = ValueKey('mobileActivityIslandTimer');
  static const Key recordingKey = ValueKey('mobileActivityIslandRecording');
  static const Key dividerKey = ValueKey('mobileActivityIslandDivider');

  /// Rendered height of one capsule, which is also its tap height: a step
  /// under the 48 px chips it sits beside at the default text size.
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

  /// Air between two stacked capsules.
  static double stackGap(BuildContext context) =>
      context.designTokens.spacing.step2;

  /// How many capsules the island shows for [activity].
  static int _rows(MobileActivity activity, {required bool stacked}) =>
      activity.isEmpty ? 0 : (stacked ? activity.count : 1);

  /// Height of the island with [activity] running.
  static double stackHeight(
    BuildContext context,
    MobileActivity activity, {
    required bool stacked,
  }) {
    final rows = _rows(activity, stacked: stacked);
    return rows == 0
        ? 0
        : capsuleHeight(context) * rows + stackGap(context) * (rows - 1);
  }

  /// Air between the bar and the island when it floats above the row
  /// because the row has no band wide enough for it.
  static double floatGap(BuildContext context) =>
      context.designTokens.spacing.step3;

  /// The island's bottom offset while it sits in the row: the lowest
  /// capsule centred on the launcher's row, so one capsule sits level with
  /// the chips and a second one stacks upward from there.
  static double dockedBottom(BuildContext context) =>
      MobileNavigationLauncher.rowBottom(context) +
      (MobileNavigationLauncher.chipHeight(context) - capsuleHeight(context)) /
          2;

  /// Vertical estate the island claims above the launcher, which pages pad
  /// their scrollables by through the shell's overlay-height scope.
  ///
  /// [inRow], one capsule sits inside the row and claims nothing; a stack
  /// claims only what rises above the row's top. Floating above the bar,
  /// the whole island and its [floatGap] count.
  static double heightAboveBar(
    BuildContext context,
    MobileActivity activity, {
    required bool inRow,
    required bool stacked,
  }) {
    if (activity.isEmpty) return 0;
    final height = stackHeight(context, activity, stacked: stacked);
    if (!inRow) return height + floatGap(context);
    return math.max(
      0,
      dockedBottom(context) +
          height -
          MobileNavigationLauncher.barHeight(context),
    );
  }

  /// Width the island takes with [activity] running, measured as it will
  /// paint at the current text scale: the shared capsule's when both run
  /// side by side, otherwise the widest single capsule's.
  ///
  /// The elapsed times are measured on a fixed `00:00:00`: the digits are
  /// tabular, so every reading below a hundred hours paints at that width,
  /// and the reserve does not jitter as the clock ticks. Beyond that — or
  /// in a band too narrow even for this — the capsule scales its content
  /// down to fit rather than clipping a digit.
  static double width(
    BuildContext context,
    MobileActivity activity, {
    required bool stacked,
  }) {
    if (activity.isEmpty) return 0;
    final tokens = context.designTokens;
    final digits = _measure(context, '00:00:00', _elapsedStyle(tokens));
    final timer = _timerGlyphWidth(context) + tokens.spacing.step3 + digits;
    final recording =
        _recordingGlyphWidth(context) + tokens.spacing.step3 + digits;
    final outer = _outerInset(context) * 2;
    if (activity.count == 2 && !stacked) {
      return outer +
          timer +
          _innerInset(context) * 2 +
          BorderWidths.hairline +
          recording;
    }
    return outer +
        math.max(
          activity.timer ? timer : 0,
          activity.recording ? recording : 0,
        );
  }

  /// Horizontal room the island may take when it floats: the window inside
  /// its safe-area insets and `spacing.step3` gutters.
  static double availableWidth(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return MediaQuery.sizeOf(context).width -
        insets.left -
        insets.right -
        context.designTokens.spacing.step3 * 2;
  }

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

  /// Air between a capsule's ends and its content.
  static double _outerInset(BuildContext context) =>
      context.designTokens.spacing.step4;

  /// Air either side of the hairline in the shared capsule.
  static double _innerInset(BuildContext context) =>
      context.designTokens.spacing.step3;

  static double _timerGlyphWidth(BuildContext context) =>
      context.designTokens.spacing.step4;

  static double _recordingGlyphWidth(BuildContext context) =>
      context.designTokens.spacing.step6;

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
    final timeService = ref.read(timeServiceProvider);
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
        final outer = _outerInset(context);
        final inner = _innerInset(context);
        Widget timerHalf({required bool framed, required double end}) =>
            _TimerSegment(
              entry: timer!,
              elapsed: formatDuration(entryDuration(timer)),
              linkedFrom: timeService.linkedFrom,
              framed: framed,
              inset: EdgeInsetsDirectional.only(start: outer, end: end),
            );
        Widget recordingHalf({required bool framed, required double start}) =>
            _RecordingSegment(
              state: recording!,
              elapsed: formatDuration(recording.progress),
              framed: framed,
              inset: EdgeInsetsDirectional.only(start: start, end: outer),
            );

        final Widget island;
        if (timer != null && recording != null && !stacked) {
          // Side by side in one capsule. The capsule's insets and the air
          // around the hairline belong to the halves, so the whole pill is
          // a tap target.
          island = _Glass(
            key: islandKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timerHalf(framed: false, end: inner),
                const _SegmentDivider(),
                recordingHalf(framed: false, start: inner),
              ],
            ),
          );
        } else {
          // One capsule per item; when both run, one shared width so the
          // stack reads as one column rather than two ragged pills.
          island = IntrinsicWidth(
            key: islandKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (timer != null) timerHalf(framed: true, end: outer),
                if (timer != null && recording != null)
                  SizedBox(height: stackGap(context)),
                if (recording != null)
                  recordingHalf(framed: true, start: outer),
              ],
            ),
          );
        }
        return Center(child: island);
      },
    );
  }
}

/// How the shell lays the island out for one frame: whether it sits in the
/// launcher row or floats, whether two items stack, and the launcher that
/// goes with it.
@immutable
class MobileIslandLayout {
  const MobileIslandLayout({
    required this.launcher,
    required this.inRow,
    required this.stacked,
  });

  /// Tries, in order, until one fits: both items side by side in the row
  /// (the page action keeping its word if it can, else down to its glyph);
  /// stacked in the row; and, past that, floating above the bar — side by
  /// side if the window has room, stacked if not — with the launcher
  /// reserving nothing.
  ///
  /// The ladder is always resolved for the docked row: the island only
  /// shows while the launcher does, and a launcher sliding away carries the
  /// island off in the layout it already had.
  ///
  /// [buildLauncher] builds the row with a given reserved centre width.
  factory MobileIslandLayout.resolve(
    BuildContext context, {
    required MobileActivity activity,
    required MobileNavigationLauncher Function(double reservedCenterWidth)
    buildLauncher,
  }) {
    if (activity.isEmpty) {
      return MobileIslandLayout(
        launcher: buildLauncher(0),
        inRow: true,
        stacked: false,
      );
    }
    for (final stacked in [false, if (activity.count > 1) true]) {
      final launcher = buildLauncher(
        MobileActivityIsland.width(context, activity, stacked: stacked),
      );
      if (launcher.centerFits(context)) {
        return MobileIslandLayout(
          launcher: launcher,
          inRow: true,
          stacked: stacked,
        );
      }
    }
    return MobileIslandLayout(
      launcher: buildLauncher(0),
      inRow: false,
      stacked:
          activity.count > 1 &&
          MobileActivityIsland.width(context, activity, stacked: false) >
              MobileActivityIsland.availableWidth(context),
    );
  }

  final MobileNavigationLauncher launcher;
  final bool inRow;
  final bool stacked;
}

/// The elapsed-time style both halves share: the chip register, in the
/// tabular figures that keep the digits from shifting width as they tick.
TextStyle _elapsedStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

/// The glass capsule: the launcher chips' surface, one capsule tall.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final height = MobileActivityIsland.capsuleHeight(context);
    return DsGlassChipSurface(
      radius: radius,
      blurred: true,
      child: Container(
        height: height,
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
        // Last resort beneath the shell's layout ladder: in a space too
        // narrow even for one elapsed time — the largest text scale on the
        // narrowest phone — the content shrinks rather than clipping a
        // digit. At every size the ladder handles, this is a no-op.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
  }
}

/// One item's button: [glyph] and [elapsed] inside [inset]. [framed], it is
/// a glass capsule of its own, a target end to end; otherwise it is a half
/// of the shared capsule, its inset part of its target.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.buttonKey,
    required this.glyph,
    required this.elapsed,
    required this.semanticLabel,
    required this.onTap,
    required this.framed,
    required this.inset,
    this.semanticHint,
  });

  final Key buttonKey;
  final Widget glyph;
  final String elapsed;
  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback onTap;
  final bool framed;
  final EdgeInsetsGeometry inset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final content = Padding(
      padding: inset,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          SizedBox(width: tokens.spacing.step3),
          Text(elapsed, style: _elapsedStyle(tokens)),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: buttonKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: framed ? _Glass(child: content) : content,
          ),
        ),
      ),
    );
  }
}

class _TimerSegment extends ConsumerWidget {
  const _TimerSegment({
    required this.entry,
    required this.elapsed,
    required this.linkedFrom,
    required this.framed,
    required this.inset,
  });

  final JournalEntity entry;
  final String elapsed;
  final JournalEntity? linkedFrom;
  final bool framed;
  final EdgeInsetsGeometry inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final size = MobileActivityIsland._timerGlyphWidth(context);
    return _Segment(
      buttonKey: MobileActivityIsland.timerKey,
      elapsed: elapsed,
      framed: framed,
      inset: inset,
      semanticLabel: '${messages.sidebarRunningTimerLabel}, $elapsed',
      semanticHint: messages.taskActionBarOpenRunningTimer,
      onTap: () => navigateToTimerTarget(
        current: entry,
        linkedFrom: linkedFrom,
        ref: ref,
      ),
      glyph: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.colors.alert.error.defaultColor,
        ),
      ),
    );
  }
}

class _RecordingSegment extends ConsumerWidget {
  const _RecordingSegment({
    required this.state,
    required this.elapsed,
    required this.framed,
    required this.inset,
  });

  final AudioRecorderState state;
  final String elapsed;
  final bool framed;
  final EdgeInsetsGeometry inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return _Segment(
      buttonKey: MobileActivityIsland.recordingKey,
      elapsed: elapsed,
      framed: framed,
      inset: inset,
      semanticLabel:
          '${context.messages.taskActionBarAudioRecordingActive}, $elapsed',
      onTap: () => unawaited(reopen()),
      glyph: AudioRecordingOrb(
        dBFS: state.dBFS,
        size: MobileActivityIsland._recordingGlyphWidth(context),
      ),
    );
  }
}

/// The hairline between the two halves of the shared capsule. It carries no
/// air of its own — the halves on either side pad up to it, so a tap beside
/// the rule still lands on a half.
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
