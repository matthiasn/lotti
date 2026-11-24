import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

/// Watches the running timer once and hands the shell whether one runs, so
/// the launcher's reserved centre, the island's position and the estate
/// pages pad by all read the same rule as what the island renders.
///
/// The timer stream ticks every second while a timer runs, but only whether
/// one runs matters here — the island ticks its own digits — so [builder]
/// runs when a timer starts or stops, not on every tick. [child] is a
/// prebuilt subtree passed through untouched.
class MobileActivityBuilder extends ConsumerStatefulWidget {
  const MobileActivityBuilder({
    required this.builder,
    required this.child,
    super.key,
  });

  final Widget Function(
    BuildContext context,
    Widget child, {
    required bool timerRuns,
  })
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
  Widget build(BuildContext context) => StreamBuilder<bool>(
    initialData: _timerAtStart,
    stream: _timerRuns,
    builder: (context, snapshot) => widget.builder(
      context,
      widget.child,
      timerRuns: snapshot.data ?? false,
    ),
  );
}

/// The mobile shell's running-timer island: a glass capsule that sits in the
/// bottom navigation row, centred between the leading chips and the page
/// action, while a time recording runs.
///
/// It is built from the launcher chips' own vocabulary
/// ([DsGlassChipSurface], [dsGlassChipFill], [dsGlassChipBorder]) so the row
/// reads as one glass dialect, a step shorter than the chips so it reads as
/// their subordinate rather than a third peer.
///
/// A red dot and the elapsed time, one button that opens the running entry
/// ([navigateToTimerTarget]). A voice recording has an indicator of its own,
/// the recording strip, so the island never shows one.
///
/// Only when the row has no room for the capsule does it float above the bar
/// ([MobileIslandLayout.resolve]). With no timer running the island renders
/// nothing and reserves nothing.
///
/// The island belongs to the launcher row, so it shows only while that row
/// is docked. A page that owns the bottom edge with a sticky action bar (a
/// task, entry or event detail, a settings editor, a project, goal, habit or
/// person page) has no such row, and the island never shows there. The
/// shell applies this rule.
class MobileActivityIsland extends ConsumerWidget {
  const MobileActivityIsland({super.key});

  static const Key islandKey = ValueKey('mobileActivityIsland');
  static const Key timerKey = ValueKey('mobileActivityIslandTimer');

  /// Rendered height of the capsule, which is also its tap height: a step
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

  /// Air between the bar and the island when it floats above the row
  /// because the row has no band wide enough for it.
  static double floatGap(BuildContext context) =>
      context.designTokens.spacing.step3;

  /// The island's bottom offset while it sits in the row: centred on the
  /// launcher's row, level with the chips.
  static double dockedBottom(BuildContext context) =>
      MobileNavigationLauncher.rowBottom(context) +
      (MobileNavigationLauncher.chipHeight(context) - capsuleHeight(context)) /
          2;

  /// Vertical estate the island claims above the launcher, which pages pad
  /// their scrollables by through the shell's overlay-height scope: nothing
  /// in the row, the capsule and its [floatGap] floating above it, and
  /// nothing with no timer running.
  static double heightAboveBar(
    BuildContext context, {
    required bool timerRuns,
    required bool inRow,
  }) => !timerRuns || inRow ? 0 : capsuleHeight(context) + floatGap(context);

  /// Width the capsule takes, measured as it will paint at the current text
  /// scale; nothing with no timer running.
  ///
  /// The elapsed time is measured on a fixed `00:00:00`: the digits are
  /// tabular, so every reading below a hundred hours paints at that width,
  /// and the reserve does not jitter as the clock ticks. Beyond that — or in
  /// a band too narrow even for this — the capsule scales its content down
  /// to fit rather than clipping a digit.
  static double width(BuildContext context, {required bool timerRuns}) {
    if (!timerRuns) return 0;
    final tokens = context.designTokens;
    final digits = _measure(context, '00:00:00', _elapsedStyle(tokens));
    return _outerInset(context) * 2 +
        _glyphWidth(context) +
        tokens.spacing.step3 +
        digits;
  }

  /// Air between the capsule's ends and its content.
  static double _outerInset(BuildContext context) =>
      context.designTokens.spacing.step4;

  static double _glyphWidth(BuildContext context) =>
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
    return StreamBuilder<JournalEntity?>(
      // Seeded so an already-running timer shows on the first frame instead
      // of waiting a second for the stream's next tick.
      initialData: timeService.getCurrent(),
      stream: timeService.getStream(),
      builder: (context, snapshot) {
        final timer = snapshot.data;
        if (timer == null) return const SizedBox.shrink();
        return Center(
          child: _TimerCapsule(
            key: islandKey,
            entry: timer,
            elapsed: formatDuration(entryDuration(timer)),
            linkedFrom: timeService.linkedFrom,
          ),
        );
      },
    );
  }
}

/// How the shell lays the island out for one frame: whether it sits in the
/// launcher row or floats, and the launcher that goes with it.
@immutable
class MobileIslandLayout {
  const MobileIslandLayout({required this.launcher, required this.inRow});

  /// The capsule in the row while the row has room for it (the page action
  /// keeping its word if it can, else down to its glyph); past that, floating
  /// above the bar with the launcher reserving nothing.
  ///
  /// Always resolved for the docked row: the island only shows while the
  /// launcher does, and a launcher sliding away carries the island off in
  /// the layout it already had.
  ///
  /// [buildLauncher] builds the row with a given reserved centre width.
  factory MobileIslandLayout.resolve(
    BuildContext context, {
    required bool timerRuns,
    required MobileNavigationLauncher Function(double reservedCenterWidth)
    buildLauncher,
  }) {
    if (!timerRuns) {
      return MobileIslandLayout(launcher: buildLauncher(0), inRow: true);
    }
    final launcher = buildLauncher(
      MobileActivityIsland.width(context, timerRuns: true),
    );
    if (launcher.centerFits(context)) {
      return MobileIslandLayout(launcher: launcher, inRow: true);
    }
    return MobileIslandLayout(launcher: buildLauncher(0), inRow: false);
  }

  final MobileNavigationLauncher launcher;
  final bool inRow;
}

/// The elapsed-time style: the chip register, in the tabular figures that
/// keep the digits from shifting width as they tick.
TextStyle _elapsedStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

/// The running timer's capsule: the launcher chips' glass, a red dot and the
/// elapsed time, one button end to end that opens the running entry.
class _TimerCapsule extends ConsumerWidget {
  const _TimerCapsule({
    required this.entry,
    required this.elapsed,
    required this.linkedFrom,
    super.key,
  });

  final JournalEntity entry;
  final String elapsed;
  final JournalEntity? linkedFrom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final height = MobileActivityIsland.capsuleHeight(context);
    final glyph = MobileActivityIsland._glyphWidth(context);
    void open() =>
        navigateToTimerTarget(current: entry, linkedFrom: linkedFrom, ref: ref);

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
                // Last resort beneath the shell's layout: in a space too
                // narrow even for one elapsed time — the largest text scale
                // on the narrowest phone — the content shrinks rather than
                // clipping a digit. At every size the row holds, a no-op.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MobileActivityIsland._outerInset(context),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: glyph,
                            height: glyph,
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
            ),
          ),
        ),
      ),
    );
  }
}
