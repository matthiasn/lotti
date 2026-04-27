import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';

/// Tree-nav state for Settings V2 per spec §3.
///
/// Single source of truth: `List<String> path` — an ordered list of
/// node ids from root to the current focus. Open branches, selected
/// leaves, breadcrumbs, and the beam URL are all derivable from
/// [state]; the UI must not keep its own open/closed booleans (see
/// spec §10 "What NOT to do").
class SettingsTreePath extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  /// Applies the four click rules from spec §3:
  ///
  /// 1. Row is on the active path AND has children (currently open)
  ///    → collapse. `path = path.sublist(0, depth)`.
  /// 2. Row is off-path AND has children → open, replacing everything
  ///    at this depth and below. `path = [...path.sublist(0, depth),
  ///    nodeId]`.
  /// 3. Row is a leaf → select. Same shape as rule 2.
  /// 4. Tapping an already-selected leaf → no-op.
  void onNodeTap(
    String nodeId, {
    required int depth,
    required bool hasChildren,
  }) {
    final current = state;
    // Clamp into `[0, current.length]` so a stale depth from a
    // rebuilt tree (or a programmatic call) can't trip a
    // `sublist` RangeError. `safeDepth == current.length` falls
    // through to rules 2 + 3 and appends, which is the correct
    // behavior when tapping a row one level deeper than the
    // current open branch.
    final safeDepth = depth.clamp(0, current.length);

    // Rule 4: already-selected leaf (same id at same depth, no
    // children). Do nothing — leaves are never deselected by tap.
    if (!hasChildren &&
        safeDepth < current.length &&
        current[safeDepth] == nodeId) {
      return;
    }

    // Rule 1: this branch is currently open at [safeDepth] — collapse.
    if (hasChildren &&
        safeDepth < current.length &&
        current[safeDepth] == nodeId) {
      state = current.sublist(0, safeDepth);
      return;
    }

    // Rules 2 + 3: replace everything at this depth and below with
    // the tapped id. Keeps the spec §3 invariant "at most one node
    // is open per depth" — opening a sibling automatically closes
    // the current open node and everything below it.
    state = <String>[...current.sublist(0, safeDepth), nodeId];
  }

  /// Called by the URL-sync bridge (plan §1) when Beamer's path
  /// changes externally. Resolves [beamPath] to a tree path via
  /// [beamUrlToPath] and installs it when it differs from the
  /// current state — avoids emitting a redundant notification when
  /// the URL update was triggered *by* a prior tree mutation.
  void syncFromUrl(String beamPath) {
    final next = beamUrlToPath(beamPath);
    if (listEquals(next, state)) return;
    state = next;
  }

  /// Truncates the current path to the first [depth] segments.
  /// Used by breadcrumb chips: tapping `Settings › Sync` resets to
  /// `['sync']`; tapping `Settings` resets to `[]`.
  ///
  /// Clamps `depth` into `[0, state.length]` so callers needn't
  /// guard against stale depth values from a rebuilt tree.
  void truncateTo(int depth) {
    final clamped = depth.clamp(0, state.length);
    if (clamped == state.length) return;
    state = state.sublist(0, clamped);
  }

  /// Resets to the empty root. Useful after a deep link into a
  /// subtree that no longer exists (flag turned off between sessions).
  void clear() {
    if (state.isEmpty) return;
    state = const <String>[];
  }
}

final settingsTreePathProvider =
    NotifierProvider<SettingsTreePath, List<String>>(
      SettingsTreePath.new,
    );
