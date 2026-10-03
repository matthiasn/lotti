import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/settings_tree_width_controller.dart';
import 'package:lotti/features/settings/ui/detail/settings_detail_pane.dart';
import 'package:lotti/features/settings/ui/settings_tree_constants.dart';
import 'package:lotti/features/settings/ui/settings_tree_scope.dart';
import 'package:lotti/features/settings/ui/tree/settings_tree_view.dart';
import 'package:lotti/features/settings/ui/url_sync/settings_tree_url_sync.dart';
import 'package:lotti/features/settings/ui/widgets/settings_top_crumbs.dart';
import 'package:lotti/features/settings/ui/widgets/settings_tree_resize_handle.dart';
import 'package:material_ui/material_ui.dart';

/// Fixed height of the Settings V2 page header (spec §2). Kept as a
/// top-level const so existing callers (and tests) can reference it
/// without reaching into [SettingsTreeConstants].
const double kSettingsDesktopHeaderHeight = SettingsTreeConstants.headerHeight;

/// Root chrome for Settings V2 per spec §1-4: a 56 dp header above
/// a two-column body (tree-nav on the left, detail pane on the
/// right) separated by a 1 dp divider with a 6 dp draggable resize
/// handle centered on it.
///
/// This widget owns **only layout**. The header hosts the
/// breadcrumb title via [SettingsTopCrumbs]; the tree slot is
/// filled by [SettingsTreeView]; the detail slot is filled by
/// [SettingsDetailPane], which dispatches to per-leaf panels via
/// the registry. Tree state, URL sync, and the shared tree/index
/// snapshot are wired in by [SettingsTreeScopeHost] and
/// [SettingsTreeUrlSync].
class SettingsDesktopPage extends ConsumerWidget {
  const SettingsDesktopPage({this.beamToReplacementNamed, super.key});

  /// Test-only override for the layout-neutral URL-sync bridge.
  ///
  /// Production leaves this null so [SettingsTreeUrlSync] uses Beamer. Widget
  /// tests and screenshot harnesses can provide a no-op or spy while still
  /// rendering this complete production shell.
  @visibleForTesting
  final BeamToReplacementNamed? beamToReplacementNamed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final treeWidth = ref.watch(settingsTreeNavWidthProvider);
    final dividerColor = tokens.colors.decorative.level01;

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      // Hoist the tree + index to a shared InheritedWidget so the
      // tree view and detail pane observe the same snapshot and the
      // 5 flag subscriptions only happen once per page mount.
      body: SettingsTreeScopeHost(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zero-size bridge widget — keeps tree path and Beamer
            // URL in sync in both directions. Listens rather than
            // renders, so placement inside the Column is purely a
            // matter of where in the widget tree the `ref.listen`
            // hook needs to live.
            if (beamToReplacementNamed == null)
              const SettingsTreeUrlSync()
            else
              SettingsTreeUrlSync(
                beamToReplacementNamed: beamToReplacementNamed!,
              ),
            _SettingsV2Header(dividerColor: dividerColor, tokens: tokens),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: treeWidth,
                    child: const SettingsTreeView(),
                  ),
                  // Stack the 6 dp draggable handle on top of the 1 dp
                  // divider so the hit target is centered on the line
                  // per spec §3. `clipBehavior: Clip.none` lets the
                  // handle overhang the divider column without
                  // hit-testing into the tree.
                  SizedBox(
                    width: 1,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        _VerticalDivider(color: dividerColor),
                        const Positioned(
                          left:
                              -(SettingsTreeConstants.resizeHandleHitWidth -
                                  1) /
                              2,
                          top: 0,
                          bottom: 0,
                          child: SettingsTreeResizeHandle(),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: SettingsDetailPane()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsV2Header extends StatelessWidget {
  const _SettingsV2Header({
    required this.dividerColor,
    required this.tokens,
  });

  final Color dividerColor;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSettingsDesktopHeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        // Crumbs are the page title now — the trail expands as the
        // user drills into the tree, and tapping a non-leaf segment
        // truncates the path. The crumb widget keeps the trail on a
        // single line and ellipsizes the terminal segment when
        // constrained; the header itself just supplies the fixed
        // height, divider, and the standard step6 horizontal gutter.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
          child: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SettingsTopCrumbs(),
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 1, color: color);
}
