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
/// the level orb and its elapsed time. Each is a capsule of its own and a
/// button end to end — the timer opens the running entry
/// ([navigateToTimerTarget]), the recording reopens its modal. Both at once
/// stack, timer above recording, at one shared width. The lowest capsule
/// keeps the row's centre line, so the stack grows upward out of the row
/// rather than pushing the row down or clipping ([dockedBottom]). Where the
/// row has no band wide enough even with the page action down to its glyph
/// — the largest text on the narrowest phone with every chip docked — the
/// island floats [floatGap] above the bar at full width instead. With
/// nothing running the island renders nothing and reserves nothing.
///
/// Which recordings count is decided once, in [showsRecording], and the
/// shell reads the same rule through [MobileActivityBuilder] — so the space
/// the row and the pages reserve for the island can never disagree with
/// what it renders.
class MobileActivityIsland extends ConsumerWidget {
  const MobileActivityIsland({required this.omitAudio, super.key});

  /// Whether the recording capsule is left out altogether. Flatpak builds
  /// carry no MediaKit-backed recorder, so the shell passes true there.
  final bool omitAudio;

  static const Key islandKey = ValueKey('mobileActivityIsland');
  static const Key timerKey = ValueKey('mobileActivityIslandTimer');
  static const Key recordingKey = ValueKey('mobileActivityIslandRecording');

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

  /// Height of the island with [activity] running.
  static double stackHeight(BuildContext context, MobileActivity activity) =>
      activity.isEmpty
      ? 0
      : capsuleHeight(context) * activity.count +
            stackGap(context) * (activity.count - 1);

  /// Air below the island whenever it floats rather than sitting in the row:
  /// above the bar when the row has no band wide enough for it, or above the
  /// bottom safe-area edge once the bar has slid away.
  static double floatGap(BuildContext context) =>
      context.designTokens.spacing.step3;

  /// The island's bottom offset while the bar is docked: the lowest capsule
  /// centred on the launcher's row, so one capsule sits level with the
  /// chips and a second one stacks upward from there.
  static double dockedBottom(BuildContext context) =>
      MobileNavigationLauncher.rowBottom(context) +
      (MobileNavigationLauncher.chipHeight(context) - capsuleHeight(context)) /
          2;

  /// Vertical estate the island claims above the launcher, which pages pad
  /// their scrollables by through the shell's overlay-height scope.
  ///
  /// [inRow], one capsule sits inside the row and claims nothing; a stack
  /// claims only what rises above the row's top. Floating — above the bar,
  /// or above the edge once the bar slid away — the whole stack and its
  /// [floatGap] count.
  static double heightAboveBar(
    BuildContext context,
    MobileActivity activity, {
    required bool inRow,
  }) {
    if (activity.isEmpty) return 0;
    final height = stackHeight(context, activity);
    if (!inRow) return height + floatGap(context);
    return math.max(
      0,
      dockedBottom(context) +
          height -
          MobileNavigationLauncher.barHeight(context),
    );
  }

  /// Width the island takes with [activity] running: its widest capsule,
  /// measured as it will paint at the current text scale.
  ///
  /// The elapsed times are measured on a fixed `00:00:00`: the digits are
  /// tabular, so every reading below a hundred hours paints at that width,
  /// and the reserve does not jitter as the clock ticks. Beyond that — or
  /// in a band too narrow even for this — the capsule scales its content
  /// down to fit rather than clipping a digit.
  static double width(BuildContext context, MobileActivity activity) {
    final tokens = context.designTokens;
    final digits = _measure(context, '00:00:00', _elapsedStyle(tokens));
    final inset = _insetWidth(context) * 2 + tokens.spacing.step3;
    return math.max(
      activity.timer ? inset + tokens.spacing.step4 + digits : 0,
      activity.recording ? inset + tokens.spacing.step6 + digits : 0,
    );
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

  static double _insetWidth(BuildContext context) =>
      context.designTokens.spacing.step4;

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
      // timer capsule instead of taking the shell down with it.
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
        return Center(
          // One shared width: the widest capsule's, so a stack reads as one
          // column rather than two ragged pills.
          child: IntrinsicWidth(
            key: islandKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (timer != null)
                  _TimerCapsule(
                    entry: timer,
                    elapsed: formatDuration(entryDuration(timer)),
                    linkedFrom: timeService.linkedFrom,
                  ),
                if (timer != null && recording != null)
                  SizedBox(height: stackGap(context)),
                if (recording != null)
                  _RecordingCapsule(
                    state: recording,
                    elapsed: formatDuration(recording.progress),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The elapsed-time style both capsules share: the chip register, in the
/// tabular figures that keep the digits from shifting width as they tick.
TextStyle _elapsedStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

/// One glass capsule: [glyph] and [elapsed] centred inside the chip
/// surface, the whole capsule one button.
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.buttonKey,
    required this.glyph,
    required this.elapsed,
    required this.semanticLabel,
    required this.onTap,
    this.semanticHint,
  });

  final Key buttonKey;
  final Widget glyph;
  final String elapsed;
  final String semanticLabel;
  final String? semanticHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final height = MobileActivityIsland.capsuleHeight(context);
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
            child: DsGlassChipSurface(
              radius: radius,
              blurred: true,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: dsGlassChipFill(tokens),
                  borderRadius: radius,
                ),
                // The hairline is a foreground decoration, as on every glass
                // chip: painted over the fill without widening the capsule.
                foregroundDecoration: BoxDecoration(
                  border: dsGlassChipBorder(tokens),
                  borderRadius: radius,
                ),
                // Last resort beneath the launcher's reserved centre: in a
                // band too narrow even for one elapsed time — the largest
                // text scale on the narrowest phone — the content shrinks
                // to the band rather than clipping a digit. At every size
                // the reserve handles, this is a no-op.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MobileActivityIsland._insetWidth(context),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          glyph,
                          SizedBox(width: tokens.spacing.step3),
                          Text(elapsed, style: _elapsedStyle(tokens)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerCapsule extends ConsumerWidget {
  const _TimerCapsule({
    required this.entry,
    required this.elapsed,
    required this.linkedFrom,
  });

  final JournalEntity entry;
  final String elapsed;
  final JournalEntity? linkedFrom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return _Capsule(
      buttonKey: MobileActivityIsland.timerKey,
      elapsed: elapsed,
      semanticLabel: '${messages.sidebarRunningTimerLabel}, $elapsed',
      semanticHint: messages.taskActionBarOpenRunningTimer,
      onTap: () => navigateToTimerTarget(
        current: entry,
        linkedFrom: linkedFrom,
        ref: ref,
      ),
      glyph: Container(
        width: tokens.spacing.step4,
        height: tokens.spacing.step4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.colors.alert.error.defaultColor,
        ),
      ),
    );
  }
}

class _RecordingCapsule extends ConsumerWidget {
  const _RecordingCapsule({required this.state, required this.elapsed});

  final AudioRecorderState state;
  final String elapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final linkedId = state.linkedId;
    // Watched, not only read at tap time: the provider is autoDispose, and
    // the subscription is what keeps the linked entry loaded and warm for
    // as long as this capsule is on screen.
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

    return _Capsule(
      buttonKey: MobileActivityIsland.recordingKey,
      elapsed: elapsed,
      semanticLabel:
          '${context.messages.taskActionBarAudioRecordingActive}, $elapsed',
      onTap: () => unawaited(reopen()),
      glyph: AudioRecordingOrb(dBFS: state.dBFS, size: tokens.spacing.step6),
    );
  }
}
