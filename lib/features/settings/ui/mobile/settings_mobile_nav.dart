import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';
import 'package:lotti/features/settings/ui/settings_node_action_handler.dart';
import 'package:lotti/services/nav_service.dart';

/// Turns a tap on a settings tree node (from the mobile drill-down) into
/// navigation.
///
/// Action nodes (the Manual, What's New) perform their action. Every other
/// node beams to its URL from [settingsRoutes], and `SettingsLocation` builds
/// the resulting page stack — which is what gives the drill-down its native
/// back behaviour and deep links. A node without a URL (the demo world's
/// sync explainer tile) is inert.
void handleSettingsNodeTap(
  BuildContext context,
  WidgetRef ref,
  SettingsNode node,
) {
  if (handleSettingsNodeAction(context, ref, node)) return;
  final url = settingsRoutes.nodeUrls[node.id];
  if (url != null) {
    beamToNamed(url);
  }
}
