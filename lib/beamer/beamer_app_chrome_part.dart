part of 'beamer_app.dart';

/// Reserves the top strip of the shell for the goal/relationship agents'
/// banner dock, above the sidebar and every page.
///
/// Structural, never an overlay: the dock is the first child of a [Column]
/// whose second child is the whole app shell, so a speaking banner pushes
/// the sidebar and the content down instead of covering them. Scrolling
/// content therefore cannot pass underneath it, and the dock cannot collide
/// with the bottom bar or a page-owned action bar the way the old
/// bottom-docked mini-player could.
///
/// This mirrors [DemoModeScaffold], which anchors the demo strip the same
/// way one level higher (in `MaterialApp.router`'s builder). Because this
/// lane nests INSIDE that one, the two stack vertically on their own — demo
/// strip first, agent banner beneath it — with no coordination between them.
///
/// While a banner speaks the lane absorbs the top safe-area inset itself and
/// hands the shell a zero top padding via [MediaQuery.removePadding], so the
/// shell does not pad a second time for a status bar the banner already
/// covers — the same mechanism, for the same reason, as the demo strip. With
/// nothing speaking the inset stays with the shell where it belongs.
///
/// Only that inset handling is gated on whether a banner speaks; the wrapper
/// hierarchy itself is not. See the note in [build] for why, and for what the
/// dock's own slot does differently.
///
/// The gate uses the dock's own [visibleNudgeBannerEntries] contract rather
/// than a second rule, so the lane and the dock can never disagree about
/// whether a banner speaks — if they did, the lane would strip the shell's top
/// padding for a banner that never rendered.
class _NudgeBannerTopLane extends ConsumerWidget {
  const _NudgeBannerTopLane({
    required this.surface,
    required this.compact,
    required this.child,
  });

  /// The banner surface of the active tab, or null on a tab no banner kind
  /// speaks on (settings, dashboards, …).
  final NudgeBannerSurface? surface;

  /// Phone layout for the dock; see [NudgeBannerDock.compact].
  final bool compact;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dockSurface = surface;
    final speaking =
        dockSurface != null &&
        visibleNudgeBannerEntries(
          entries: ref.watch(activeNudgeBannersProvider),
          locallySnoozedDeadlines: ref.watch(
            locallySnoozedNudgeDeadlinesProvider,
          ),
          surface: dockSurface,
        ).isNotEmpty;

    // The shell's slot keeps the SAME hierarchy in every case — Expanded,
    // MediaQuery.removePadding, child — and only `removeTop` varies. Wrapping
    // the child only while a banner speaks would change the widget type in
    // that slot, so Flutter would deactivate the subtree and inflate a fresh
    // one: the shell's Beamers, scroll offsets and half-typed fields would
    // reset every time a synced banner arrived or left.
    //
    // The dock's slot is stable within an eligible surface (SafeArea stays
    // mounted, only `top` varies), which is what preserves the dock's rotation
    // and tenure state. An ineligible surface mounts no dock at all, as
    // before; Column reconciles positionally, so that cannot reach the shell.
    return Column(
      children: [
        if (dockSurface == null)
          const SizedBox.shrink()
        else
          SafeArea(
            top: speaking,
            bottom: false,
            child: NudgeBannerDock(compact: compact, surface: dockSurface),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: speaking,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Feeds [DesignSystemBottomNavigationOverlayHeight] with the estate the
/// activity island claims above the mobile nav bar, mirroring the island's
/// own visibility rules: it shows while [TimeService] streams a running
/// entry or while a recording runs outside its modal (and outside the
/// Flatpak sandbox, which omits the recording half). While the shell hides
/// the bar — task-detail routes — the island is hidden with it, so no
/// height applies. [child] is a prebuilt subtree; only widgets depending on
/// the inherited height rebuild when the island appears or disappears.
class _MobileNavOverlayHeightScope extends ConsumerWidget {
  const _MobileNavOverlayHeightScope({
    required this.navBarVisible,
    required this.barDocked,
    required this.child,
  });

  final bool navBarVisible;

  /// Whether the bar is docked at the bottom edge rather than slid away;
  /// see [DesignSystemBottomNavigationOverlayHeight.barDocked].
  final bool barDocked;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The island's own rule decides which recordings count, so this scope
    // and the island can never disagree. Same guard as the island: if the
    // recorder controller fails to build (MediaKit/audio issues), no
    // recording shows, so no height applies for it either.
    bool recordingVisible;
    try {
      recordingVisible = ref.watch(
        audioRecorderControllerProvider.select(
          (state) => MobileActivityIsland.showsRecording(
            state,
            omitAudio: _isRunningInFlatpak(),
          ),
        ),
      );
    } catch (_) {
      recordingVisible = false;
    }

    final timeService = ref.read(timeServiceProvider);
    return StreamBuilder<JournalEntity?>(
      // Seeded like the island, so a timer already running on the first
      // frame reserves its room on that frame too.
      initialData: timeService.getCurrent(),
      stream: timeService.getStream(),
      builder: (context, snapshot) {
        final islandVisible =
            navBarVisible && (snapshot.data != null || recordingVisible);
        final height = islandVisible
            ? MobileActivityIsland.reservedHeight(context)
            : 0.0;
        return DesignSystemBottomNavigationOverlayHeight(
          height: height,
          barDocked: barDocked,
          child: child,
        );
      },
    );
  }
}

/// Slides the docked bottom nav bar below the screen edge when [hidden],
/// and back up when shown again. The bar stays mounted throughout so both
/// directions animate; while hidden it is inert for pointers and screen
/// readers. When the platform asks for reduced motion the slide snaps.
class _SlideAwayBottomNav extends StatelessWidget {
  const _SlideAwayBottomNav({required this.hidden, required this.child});

  static const Duration slideDuration = Duration(milliseconds: 450);

  /// easeOutQuart — the ease the mobile navigation's transitions have
  /// always used.
  static const Curve slideCurve = MotionCurves.easeOutQuart;

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeFocus(
      excluding: hidden,
      // A bar translated off-screen must leave keyboard traversal too, or
      // Tab still reaches its slots and Enter navigates away from the page
      // the user is on.
      child: ExcludeSemantics(
        excluding: hidden,
        child: IgnorePointer(
          ignoring: hidden,
          child: AnimatedSlide(
            // Offset is in multiples of the child's own size, so (0, 1)
            // moves the bar down by exactly its rendered height — flush
            // off-screen, since it docks at the bottom edge.
            offset: hidden ? const Offset(0, 1) : Offset.zero,
            duration: reduceMotion ? Duration.zero : slideDuration,
            curve: slideCurve,
            child: child,
          ),
        ),
      ),
    );
  }
}
