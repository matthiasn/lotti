import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_width_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/settings_v2_detail_placeholder.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_view.dart';
import 'package:lotti/features/settings_v2/ui/widgets/settings_tree_resize_handle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Fixed height of the Settings V2 page header (spec §2). Kept as a
/// top-level const so existing callers (and tests) can reference it
/// without reaching into [SettingsV2Constants].
const double kSettingsV2HeaderHeight = SettingsV2Constants.headerHeight;

/// Root chrome for Settings V2 per spec §1-4: a 56 dp header above
/// a two-column body (tree-nav on the left, detail pane on the
/// right) separated by a 1 dp divider with a 6 dp draggable resize
/// handle centered on it.
///
/// This widget owns **only layout**. The tree itself, the detail
/// pane panels, and the breadcrumb trail are filled in by later
/// PRs (steps 4-9 in the implementation plan). Until then the
/// tree slot shows a placeholder and the detail slot shows a
/// neutral empty-state.
class SettingsV2Page extends ConsumerWidget {
  const SettingsV2Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final treeWidth = ref.watch(settingsTreeNavWidthProvider);
    final dividerColor = tokens.colors.decorative.level01;

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            -(SettingsV2Constants.resizeHandleHitWidth - 1) / 2,
                        top: 0,
                        bottom: 0,
                        child: SettingsTreeResizeHandle(),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: SettingsV2DetailPlaceholder()),
              ],
            ),
          ),
        ],
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
      height: kSettingsV2HeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
          child: Row(
            children: [
              Text(
                context.messages.navTabTitleSettings,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              // Spacer reserves the right-aligned slot for header
              // actions that later steps wire in (breadcrumbs,
              // account switcher). Removing it today would force a
              // layout change when those land.
              const Spacer(),
            ],
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
