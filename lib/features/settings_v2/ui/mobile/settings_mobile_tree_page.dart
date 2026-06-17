import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_shell.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_node_indicators.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';

/// Presentational mobile settings level — one rung of the drill-down.
///
/// Renders [nodes] (a single level of the shared [SettingsNode] tree) as
/// full-width [SettingsTreeRow]s on the page surface, with no card, so
/// the rows read exactly like the desktop tree column. It owns no
/// navigation: each row delegates to [onNodeTap], and the host turns
/// that into a `beamToNamed` so Beamer builds the page stack (and the URL
/// / back behaviour) for every level. Keeping it stateless and
/// route-agnostic is what lets the same widget render the root and every
/// branch hub, and makes it trivial to screenshot in isolation.
///
/// A branch that carries its own landing panel (currently only `sync`)
/// passes that panel body as [header] so its content — e.g. the
/// provisioned-sync QR card — renders above the child rows, mirroring the
/// desktop detail pane. Branches without a landing panel pass `null` and
/// render the bare row list.
class SettingsMobileTreePage extends StatelessWidget {
  const SettingsMobileTreePage({
    required this.title,
    required this.nodes,
    required this.onNodeTap,
    this.header,
    this.showBack = false,
    super.key,
  });

  final String title;
  final List<SettingsNode> nodes;
  final void Function(SettingsNode node) onNodeTap;

  /// Optional content rendered above the row list — the branch's landing
  /// panel body when it has one. `null` for pure-navigation branches.
  final Widget? header;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SettingsMobileShell(
      title: title,
      showBack: showBack,
      // `top: false` — the shell header already claims the top inset; this
      // guards the list against the home indicator / landscape notches.
      child: SafeArea(
        top: false,
        child: ListView(
          // Only vertical outer padding: the row supplies its own
          // horizontal content inset, and dropping the active rail
          // (showActiveRail: false) lets the icon tile line up with the
          // header title instead of sitting behind an extra left gutter.
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
          children: [
            ?header,
            for (final node in nodes)
              SettingsTreeRow(
                key: ValueKey(node.id),
                node: node,
                depth: 0,
                onActivePath: false,
                isExpanded: false,
                trailing: settingsNodeIndicatorFor(node.id),
                showActiveRail: false,
                showLeafChevron: true,
                // 3 lines so even the longest section summary stays fully
                // legible at large OS text sizes (at 1x descriptions fit in
                // 1–2 lines, so this is just a higher ceiling, not extra
                // height). The row's min-height grows to fit.
                descMaxLines: 3,
                onTap: () => onNodeTap(node),
              ),
          ],
        ),
      ),
    );
  }
}
