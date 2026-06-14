import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/services/nav_service.dart';

/// Turns a tap on a settings tree node (from the mobile drill-down) into
/// navigation.
///
/// `whats-new` opens its modal — it deliberately has no URL in
/// [settingsNodeUrls]. Every other node routes through the top-level
/// [beamToNamed] to its canonical settings URL, and `SettingsLocation`
/// builds the resulting page stack (which is what gives the drill-down its
/// native back behaviour and deep links). Nodes with no registered URL
/// are inert — the same contract `pathToBeamUrl` already relies on.
void handleSettingsNodeTap(
  BuildContext context,
  WidgetRef ref,
  SettingsNode node,
) {
  if (node.id == 'whats-new') {
    WhatsNewModal.show(context, ref);
    return;
  }
  final url = settingsNodeUrls[node.id];
  if (url != null) {
    beamToNamed(url);
  }
}
