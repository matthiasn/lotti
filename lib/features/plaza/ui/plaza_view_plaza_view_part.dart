part of 'plaza_view.dart';

/// Reusable GPU explorer. All content comes from [world]; the demo launcher
/// and the app are independent clients of this same rendering pipeline.
class PlazaView extends StatefulWidget {
  const PlazaView({
    required this.world,
    this.ticks,
    this.onOpenTask,
    this.onExit,
    this.mode = HarnessMode.interactive,
    this.hidden = const {},
    this.trace = false,
    this.tourOnly,
    this.shotDir,
    this.initialFrameRate = PlazaFrameRate.auto,
    this.initialSkyMode = PlazaSkyMode.night,
    this.initialToolbarOpen = false,
    this.onSkyModeChanged,
    super.key,
  });

  final PlazaWorld world;
  final ChecklistTicks? ticks;
  final ValueChanged<PlazaTask>? onOpenTask;
  final VoidCallback? onExit;
  final HarnessMode mode;
  final Set<String> hidden;
  final bool trace;
  final Set<String>? tourOnly;

  /// Fixture-only: where a settled tour stop writes its PNG.
  ///
  /// The frame is read back from the widget tree rather than off the screen,
  /// so a capture needs no display server, no window manager and no screen
  /// recording permission — and both skies are framed identically, which is
  /// the whole point of a before/after pair.
  final String? shotDir;
  final PlazaFrameRate initialFrameRate;

  /// The sky the world boots under.
  final PlazaSkyMode initialSkyMode;

  /// Whether the toolbar is showing on arrival. Closed everywhere the app
  /// opens the world — the street is what was asked for. The harness opens
  /// it so a screenshot run can frame the toolbar without pressing a key.
  final bool initialToolbarOpen;

  /// Told when the walker changes the sky, so a host can remember it.
  final ValueChanged<PlazaSkyMode>? onSkyModeChanged;

  @override
  State<PlazaView> createState() => _PlazaViewState();
}

/// What the harness is doing: driven by hand, stepping through the tour's
/// screenshot poses, or running the benchmark. A scripted run takes no
/// input and paints on every vsync.
enum HarnessMode {
  interactive,
  tour,
  bench;

  /// `PLAZA_BENCH=1` wins over `PLAZA_TOUR=1`; neither is interactive.
  static HarnessMode fromEnvironment(Map<String, String> env) {
    if (env['PLAZA_BENCH'] == '1') return HarnessMode.bench;
    if (env['PLAZA_TOUR'] == '1') return HarnessMode.tour;
    return HarnessMode.interactive;
  }

  bool get scripted => this != HarnessMode.interactive;
}
