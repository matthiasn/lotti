import 'package:flutter/widgets.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart'
    show NodeBadge;
import 'package:lotti/features/settings_v2/ui/tree/outbox_count_indicator.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart'
    show SettingsTreeRow;

/// Builds a live trailing indicator for a settings-tree row, by node id.
///
/// Most rows have no live indicator; the static [NodeBadge] on the node
/// covers fixed pills. This registry is for the handful of rows that need
/// a *reactive* trailing widget (a stream-backed count, status dot, …) —
/// e.g. the `sync/outbox` pending count. Keyed by node id so the desktop
/// tree view and the mobile drill-down render the same indicator from one
/// definition, and [SettingsTreeRow] itself stays presentational (it just
/// paints whatever widget it is handed).
typedef SettingsNodeIndicatorBuilder = Widget Function();

const Map<String, SettingsNodeIndicatorBuilder> kSettingsNodeIndicators =
    <String, SettingsNodeIndicatorBuilder>{
      'sync/outbox': _outboxIndicator,
    };

/// Returns the live trailing widget for [nodeId], or `null` when the node
/// has no registered indicator (the common case).
Widget? settingsNodeIndicatorFor(String nodeId) =>
    kSettingsNodeIndicators[nodeId]?.call();

Widget _outboxIndicator() => const OutboxCountIndicator();
