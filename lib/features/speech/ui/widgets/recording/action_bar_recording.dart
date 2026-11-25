import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';

/// Builds a sticky action bar's row of actions; [mic] is the bar's record
/// button, or null while the take runs here — then the mic has become the
/// recording row's Stop.
typedef ActionBarActionsBuilder =
    Widget Function(BuildContext context, Widget? mic);

/// A sticky action bar's actions, and the take running for its subject at
/// the bar's foot: the live dot, the level, the running time, pause, and a
/// round Stop — the bar's own mic, moved down and turned into Stop.
///
/// While a take linked to [linkedId] runs and the bar's page ([route]) is
/// the one on screen, the mic leaves the row of [actions] and the recording
/// row shows under it; the mic flies there, turning from the accent ring
/// into the red Stop, and Stop flies back into the mic when the take ends
/// (at once under reduced motion).
///
/// While its page is on screen the bar is its subject's home
/// ([recordingHomesProvider]) — whether or not anything records, so a take
/// started here never shows on the strip, not even for a frame. The
/// recording strip and the sidebar's way back stand down for the subject's
/// takes there. Leaving the page gives that back, and the take shows on the
/// strip — or, on a wide window, in the sidebar's activity — with the way
/// back here.
class ActionBarRecording extends ConsumerStatefulWidget {
  const ActionBarRecording({
    required this.linkedId,
    required this.route,
    required this.mic,
    required this.actions,
    this.between,
    super.key,
  });

  /// The subject whose bar this is: its takes, and only those, show here.
  final String linkedId;

  /// The route of the page the bar is on. The bar holds the take only while
  /// that page is the one on screen (`NavService.activeRoute`).
  final String route;

  /// The bar's record button.
  final Widget mic;

  /// The bar's row of actions, given the [mic] to place in it.
  final ActionBarActionsBuilder actions;

  /// What sits between the actions and the recording row, if anything.
  final Widget? between;

  static const Key bandKey = ValueKey('action-bar-recording');
  static const Key timeKey = ValueKey('action-bar-recording-time');
  static const Key pauseKey = ValueKey('action-bar-recording-pause');
  static const Key stopKey = ValueKey('action-bar-recording-stop');
  static const Key flightKey = ValueKey('action-bar-recording-flight');

  /// How long the mic takes to fly down into Stop, and back.
  static const Duration flight = MotionDurations.medium4;

  @override
  ConsumerState<ActionBarRecording> createState() => _ActionBarRecordingState();
}

class _ActionBarRecordingState extends ConsumerState<ActionBarRecording>
    with SingleTickerProviderStateMixin {
  late final RecordingHomes _homes;

  /// Whether this bar has its subject's home on screen now.
  bool _home = false;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _stopKey = GlobalKey();

  /// 0 at the mic, 1 at Stop.
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: ActionBarRecording.flight,
  )..addStatusListener(_landed);

  /// Where the flight runs between, in the bar's own coordinates.
  Rect? _micRect;
  Rect? _stopRect;

  /// Where a flight on its way goes: true to Stop, false to the mic, null
  /// while nothing flies.
  bool? _towardStop;

  /// Whether the take was here at the last build, to see it arrive or go.
  bool? _wasHere;

  @override
  void initState() {
    super.initState();
    _homes = ref.read(recordingHomesProvider.notifier);
  }

  @override
  void dispose() {
    _flight.dispose();
    // A page closed mid-take hands the take back to the strip — after the
    // frame: a provider may not change while the tree is torn down either.
    if (_home) {
      final homes = _homes;
      final subjectId = widget.linkedId;
      scheduleMicrotask(() {
        try {
          homes.leave(subjectId);
        } on Object {
          // The app went with it, torn down in the same frame: there is no
          // strip left to hand the take to.
        }
      });
    }
    super.dispose();
  }

  void _landed(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      setState(() => _towardStop = null);
    }
  }

  /// Puts the subject's home on screen while the bar's page is, or takes
  /// it off, after the frame: a provider may not change while the tree
  /// builds.
  void _settle({required bool onPage}) {
    if (onPage == _home) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || onPage == _home) return;
      _home = onPage;
      if (onPage) {
        _homes.enter(widget.linkedId);
      } else {
        _homes.leave(widget.linkedId);
      }
    });
  }

  /// Where [key]'s box sits in the bar, or null when it is not laid out.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || stack is! RenderBox) return null;
    if (!box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  /// Sends the mic down into Stop ([towardStop]), or Stop back into the
  /// mic. Where it leaves from is still laid out from the last frame; where
  /// it lands is measured once the next frame has laid it out.
  void _launch({required bool towardStop}) {
    final from = _rectOf(towardStop ? _micKey : _stopKey);
    if (from == null) return;
    if (towardStop) {
      _micRect = from;
    } else {
      _stopRect = from;
    }
    _towardStop = towardStop;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final to = _rectOf(towardStop ? _stopKey : _micKey);
      if (to == null) {
        setState(() => _towardStop = null);
        return;
      }
      // Both ends known: the disc can be drawn.
      setState(() {
        if (towardStop) {
          _stopRect = to;
        } else {
          _micRect = to;
        }
      });
      if (towardStop) {
        _flight.forward(from: 0);
      } else {
        _flight.reverse(from: 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final take = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.isActiveSessionFor(widget.linkedId),
      ),
    );
    NavService? nav;
    try {
      nav = ref.watch(navServiceProvider);
    } on ProviderException {
      // Navigation not wired up — a bar on its own, in a story or on a
      // test bench: it is the page on screen.
      nav = null;
    }
    final routes = nav;
    // Only while the bar's page is the one on screen: a page kept mounted
    // behind another tab gives the take back to the strip.
    return ListenableBuilder(
      listenable: routes?.activeRouteChanges ?? const _Still(),
      builder: (context, _) {
        final onPage =
            routes == null ||
            isSameRecordingRoute(routes.activeRoute, widget.route);
        _settle(onPage: onPage);
        final here = take && onPage;
        final wasHere = _wasHere;
        _wasHere = here;
        if (wasHere != null &&
            wasHere != here &&
            !MediaQuery.disableAnimationsOf(context)) {
          _launch(towardStop: here);
        }
        final flying = _towardStop != null;
        // The row stays while Stop flies back into the mic, fading out.
        final showRow = here || _towardStop == false;
        return Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.actions(
                  context,
                  here
                      ? null
                      : KeyedSubtree(
                          key: _micKey,
                          child: Opacity(
                            opacity: flying ? 0 : 1,
                            child: widget.mic,
                          ),
                        ),
                ),
                ?widget.between,
                if (showRow)
                  FadeTransition(
                    key: ActionBarRecording.bandKey,
                    // Until the flight is under way — a frame, while where
                    // it lands is laid out — the row holds where it starts:
                    // unseen on the way in, whole on the way out.
                    opacity: _flight.isAnimating || !flying
                        ? (flying
                              ? _flight
                              : const AlwaysStoppedAnimation<double>(1))
                        : AlwaysStoppedAnimation<double>(
                            _towardStop! ? 0 : 1,
                          ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: context.designTokens.spacing.step4,
                      ),
                      child: _RecordingRow(
                        stop: KeyedSubtree(
                          key: _stopKey,
                          child: Opacity(
                            opacity: flying ? 0 : 1,
                            child: const _Stop(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (flying && _micRect != null && _stopRect != null)
              AnimatedBuilder(
                animation: _flight,
                builder: (context, _) {
                  // Quick off the mark both ways: on the way back the
                  // curve runs mirrored, so Stop leaves as briskly as the
                  // mic did.
                  final v = _flight.value;
                  final t = _towardStop ?? true
                      ? MotionCurves.standard.transform(v)
                      : 1 - MotionCurves.standard.transform(1 - v);
                  return Positioned.fromRect(
                    key: ActionBarRecording.flightKey,
                    rect: Rect.lerp(_micRect, _stopRect, t)!,
                    child: IgnorePointer(child: _FlyingDisc(t: t)),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// The recording row at the bar's foot: the live dot, the level over all
/// the room it leaves, the running time as words, pause, then [stop].
class _RecordingRow extends ConsumerWidget {
  const _RecordingRow({required this.stop});

  final Widget stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    // Whole seconds, which is all the time shows: a level sample must not
    // rebuild the row.
    final progress = Duration(
      seconds: ref.watch(
        audioRecorderControllerProvider.select(
          (state) => state.progress.inSeconds,
        ),
      ),
    );
    final gap = SizedBox(width: tokens.spacing.step3);
    // At most the prose measure wide, centred under the bar's buttons.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
        child: SizedBox(
          height: RecordingStrip.height(context),
          child: Row(
            children: [
              const RecordingStripLeading(compact: true),
              gap,
              const Expanded(child: RecordingStripBars()),
              gap,
              // Stop carries the time for a screen reader; the words are
              // for the eye.
              ExcludeSemantics(
                child: Text(
                  formatElapsed(progress),
                  key: ActionBarRecording.timeKey,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontFeatures: numericBadgeFontFeatures,
                  ),
                ),
              ),
              gap,
              const RecordingPauseRing(key: ActionBarRecording.pauseKey),
              gap,
              stop,
            ],
          ),
        ),
      ),
    );
  }
}

/// The row's Stop: round, the time beside it rather than in it.
class _Stop extends ConsumerWidget {
  const _Stop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.status == AudioRecorderStatus.paused,
      ),
    );
    final progress = Duration(
      seconds: ref.watch(
        audioRecorderControllerProvider.select(
          (state) => state.progress.inSeconds,
        ),
      ),
    );
    return RecordingStopButton(
      key: ActionBarRecording.stopKey,
      paused: paused,
      progressSemanticsLabel: spokenClockLabel(context.messages, progress),
      onTap: () => ref.read(recordingSessionProvider).stop(),
    );
  }
}

/// The mic on its way to Stop ([t] 0 → 1), or back: the accent ring and
/// glyph on the glass becoming the red disc with the stop square.
class _FlyingDisc extends StatelessWidget {
  const _FlyingDisc({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final red = RecordingStopButton.fill(tokens, paused: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(dsGlassChipFill(tokens), red, t),
        border: Border.all(
          color: Color.lerp(accent, red, t)!,
          width: tokens.spacing.step1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1 - t,
            child: Icon(LottiIcons.mic, size: IconSizes.l, color: accent),
          ),
          Opacity(
            opacity: t,
            child: Icon(
              LottiIconsFilled.square,
              size: IconSizes.m,
              color: RecordingStopButton.ink(tokens, paused: false),
            ),
          ),
        ],
      ),
    );
  }
}

/// A listenable that never changes: the route of a bar with no navigation.
class _Still implements Listenable {
  const _Still();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
