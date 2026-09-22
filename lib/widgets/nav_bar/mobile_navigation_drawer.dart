import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the mobile navigation drawer.
@visibleForTesting
abstract final class MobileNavigationDrawerKeys {
  static const Key panel = Key('mobile-navigation-drawer-panel');
  static const Key scrim = Key('mobile-navigation-drawer-scrim');
  static const Key page = Key('mobile-navigation-drawer-page');
}

/// Whether the mobile navigation drawer is open. The shell opens it from the
/// menu lane's button and closes it when a choice is made.
class MobileNavigationDrawerController extends ValueNotifier<bool> {
  MobileNavigationDrawerController() : super(false);

  bool get isOpen => value;

  void open() => value = true;

  void close() => value = false;
}

/// The app's one drawer controller, shared by the shell that hosts the
/// drawer and the root back-button dispatcher, which has to close an open
/// drawer before any tab's own router hears a back press.
final mobileNavigationDrawerControllerProvider =
    Provider<MobileNavigationDrawerController>((ref) {
      final controller = MobileNavigationDrawerController();
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Hosts the mobile sidebar navigation: a panel that slides in from the
/// leading edge and pushes the page aside, dimmed, instead of covering it.
///
/// The page leaves its place as a card: its leading corners round off in
/// step with the slide, over a backdrop in the panel's own colour, so the
/// rounded corner reveals more sidebar rather than whatever lies behind the
/// shell. At rest nothing is clipped.
///
/// The page ([child]) keeps one position in the tree whether the drawer is
/// open, closed or mid-slide — it is translated, never rebuilt under a
/// different parent — so every tab's scroll offset and in-flight state
/// survive a visit to the drawer. While the drawer is showing, the page is
/// inert: the scrim over it takes every pointer, it holds no focus, and it
/// is hidden from assistive tech, which sees the panel and one "close"
/// target instead.
///
/// Four ways out, all ending in [MobileNavigationDrawerController.close]: a
/// tap on the dimmed page, a leftward drag or fling anywhere, the system
/// back gesture, and whatever the panel's own rows do. Back is the one this
/// host does not handle: every tab's nested router hears a back press before
/// anything inside the page could, so the app's root dispatcher
/// (`DrawerFirstBackButtonDispatcher`) closes the drawer instead. There is
/// deliberately no edge-swipe *in*: pushed pages own the leading edge for iOS
/// back, and habit rows and the Daily OS timeline own horizontal drags of
/// their own.
///
/// The controller never says "open" while no drawer is showing: a drag that
/// carries the panel all the way shut closes it, and so does this host going
/// away — crossing into the desktop layout, or the flag being switched off.
class MobileNavigationDrawerHost extends StatefulWidget {
  const MobileNavigationDrawerHost({
    required this.controller,
    required this.drawerBuilder,
    required this.child,
    super.key,
  });

  final MobileNavigationDrawerController controller;

  /// Builds the panel's content at [drawerWidth]. Only called while the
  /// drawer is at least partly on screen, so a closed drawer costs nothing,
  /// and once per build of this host rather than per frame: the slide moves
  /// the built panel, it never rebuilds it.
  final WidgetBuilder drawerBuilder;

  /// The page the drawer pushes aside.
  final Widget child;

  /// How fast a horizontal fling must be, in logical pixels per second, to
  /// decide the drawer's fate regardless of where the drag let go. The
  /// threshold Material's own drawer uses, so the gesture feels like the
  /// platform's rather than like a second opinion about what a fling is.
  static const double flingVelocity = 365;

  /// The panel's width: the window less a strip of page left showing — what
  /// tells the user the page is still there and gives the tap-to-close
  /// somewhere to land — held inside the sidebar's own width limits.
  static double drawerWidth(BuildContext context) {
    final available =
        MediaQuery.sizeOf(context).width - context.designTokens.spacing.step11;
    return math.max(minSidebarWidth, math.min(maxSidebarWidth, available));
  }

  @override
  State<MobileNavigationDrawerHost> createState() =>
      _MobileNavigationDrawerHostState();
}

class _MobileNavigationDrawerHostState extends State<MobileNavigationDrawerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: MotionDurations.medium2,
    value: widget.controller.isOpen ? 1 : 0,
  )..addListener(_onSlide);

  /// Whether the panel, the scrim and the backdrop are mounted: from the
  /// moment the slide leaves the closed position until it is back there.
  /// Held here and changed only when that happens, so what depends on it is
  /// built once per visit to the drawer rather than on every frame. Read off
  /// the slide's value, not its status: a slide run back with `animateTo(0)`
  /// ends `completed`, never `dismissed`.
  late bool _showing;

  @override
  void initState() {
    super.initState();
    _showing = _slide.value > 0;
    widget.controller.addListener(_syncToController);
  }

  @override
  void didUpdateWidget(covariant MobileNavigationDrawerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncToController);
      widget.controller.addListener(_syncToController);
      _syncToController();
    }
  }

  @override
  void dispose() {
    widget.controller
      ..removeListener(_syncToController)
      // With no host left to show it, the drawer is closed. Left open, the
      // next host would start open unasked and the back dispatcher would
      // spend a press closing a drawer nobody can see.
      ..close();
    _slide.dispose();
    super.dispose();
  }

  /// Runs the panel to where the controller says it belongs.
  void _syncToController() {
    final target = widget.controller.isOpen ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = target;
    } else {
      _slide.animateTo(target, curve: MotionCurves.emphasizedDecelerate);
    }
  }

  void _onSlide() {
    final showing = _slide.value > 0;
    if (showing != _showing) setState(() => _showing = showing);
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    _slide.value += details.primaryDelta! / width;
    // A drag can carry the panel all the way shut. Its gesture detector
    // leaves with the panel, so no drag end will arrive to tell the
    // controller; tell it now.
    if (_slide.value == 0 && widget.controller.isOpen) {
      widget.controller.close();
    }
  }

  /// A fling decides by direction; a slow release decides by which half the
  /// panel was left in. Either way the controller is told, and when it
  /// already agrees the panel is walked back from wherever the drag left it.
  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity.abs() >= MobileNavigationDrawerHost.flingVelocity
        ? velocity > 0
        : _slide.value >= 0.5;
    if (widget.controller.isOpen == open) {
      _syncToController();
    } else {
      widget.controller.value = open;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final width = MobileNavigationDrawerHost.drawerWidth(context);
    final barrier = ModalUtils.getModalBarrierColor(
      isDark: Theme.of(context).brightness == Brightness.dark,
      context: context,
    );
    final showing = _showing;

    // Built here, not in the per-frame builder below: the slide moves, clips
    // and dims these, and never needs them rebuilt to do it.
    //
    // No IgnorePointer on the page: the opaque scrim above it already takes
    // every pointer for as long as the page is pushed aside.
    final page = ExcludeFocus(
      excluding: showing,
      child: ExcludeSemantics(excluding: showing, child: widget.child),
    );
    final panel = showing
        ? GestureDetector(
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
            onHorizontalDragEnd: _onDragEnd,
            // The sidebar's own surface, continued under the status bar and
            // the home indicator the safe area keeps its rows clear of. A
            // Material, not a bare ColoredBox: the panel sits outside the
            // page's Scaffold, and plain text inside it needs a text style to
            // inherit.
            child: Material(
              color: tokens.colors.background.level02,
              child: SafeArea(
                right: false,
                child: widget.drawerBuilder(context),
              ),
            ),
          )
        : null;

    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _slide.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // The surface the page slides across: the panel's own, so the
            // page's rounded corner reveals more sidebar rather than whatever
            // happens to lie behind the shell. Always in the tree, painted
            // only while the page is off its resting place.
            if (showing)
              ColoredBox(color: tokens.colors.background.level02)
            else
              const SizedBox.shrink(),
            Transform.translate(
              key: MobileNavigationDrawerKeys.page,
              offset: Offset(width * t, 0),
              // The page leaves its place as a card: its leading corners
              // round off in step with the slide. The scrim is clipped with
              // it, so the revealed corner stays the panel's colour.
              child: ClipRRect(
                clipBehavior: showing ? Clip.antiAlias : Clip.none,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(tokens.radii.xl * t),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    page,
                    if (showing)
                      Semantics(
                        button: true,
                        label: context.messages.navSidebarCloseLabel,
                        child: GestureDetector(
                          key: MobileNavigationDrawerKeys.scrim,
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.controller.close,
                          onHorizontalDragUpdate: (d) =>
                              _onDragUpdate(d, width),
                          onHorizontalDragEnd: _onDragEnd,
                          child: ColoredBox(
                            color: barrier.withValues(alpha: barrier.a * t),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (panel != null)
              Positioned(
                key: MobileNavigationDrawerKeys.panel,
                left: -width * (1 - t),
                top: 0,
                bottom: 0,
                width: width,
                child: panel,
              ),
          ],
        );
      },
    );
  }
}
