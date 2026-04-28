import 'package:flutter/material.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';

/// (title, desc) pair resolved for a single tree node.
typedef SettingsTreeLabel = ({String title, String desc});

/// Resolves a node id into its localized title + description. Keeps
/// [buildSettingsTree] pure (no `BuildContext` / `AppLocalizations`
/// dependency) so the tree data is trivially testable with fake
/// labels and independent of the locale load path.
///
/// Production wires this to an `AppLocalizations`-backed switch at
/// the UI layer; tests pass `(id) => (title: id, desc: id)` or
/// similar.
typedef SettingsTreeLabelResolver = SettingsTreeLabel Function(String nodeId);

/// Builds the full Settings tree per the plan in
/// `docs/design/settings/settings_v2_implementation_plan.md` §2.
///
/// The tree is rebuilt whenever the set of enabled feature flags
/// changes — nodes that depend on a disabled flag are dropped from
/// the output. Node identities (ids) are stable across rebuilds so
/// callers can compare paths / persist them.
List<SettingsNode> buildSettingsTree({
  required SettingsTreeLabelResolver labels,
  required bool enableAgents,
  required bool enableHabits,
  required bool enableDashboards,
  required bool enableMatrix,
  required bool enableWhatsNew,
}) {
  SettingsNode leaf(
    String id,
    IconData icon, {
    required String panel,
    NodeBadge? badge,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      panel: panel,
      badge: badge,
    );
  }

  SettingsNode branch(
    String id,
    IconData icon, {
    required List<SettingsNode> children,
    NodeBadge? badge,
    String? panel,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      children: children,
      badge: badge,
      panel: panel,
    );
  }

  // Badges carry localized marketing copy (e.g. "v2.4", "Live") and
  // stay off the tree until the i18n sweep lands. The [NodeBadge]
  // type and rendering path remain in place so re-introducing them
  // later is a one-liner per node.

  return [
    if (enableWhatsNew)
      leaf(
        'whats-new',
        Icons.new_releases_outlined,
        panel: 'whats-new',
      ),
    branch(
      'ai',
      Icons.psychology_rounded,
      panel: 'ai',
      children: [
        leaf('ai/profiles', Icons.tune_rounded, panel: 'ai-profiles'),
      ],
    ),
    if (enableAgents)
      branch(
        'agents',
        Icons.smart_toy_outlined,
        panel: 'agents',
        children: [
          leaf(
            'agents/templates',
            Icons.article_outlined,
            panel: 'agents-templates',
          ),
          leaf('agents/souls', Icons.auto_awesome, panel: 'agents-souls'),
          leaf(
            'agents/instances',
            Icons.hub_outlined,
            panel: 'agents-instances',
          ),
        ],
      ),
    if (enableHabits) leaf('habits', Icons.repeat_rounded, panel: 'habits'),
    leaf('categories', Icons.category_rounded, panel: 'categories'),
    leaf('labels', Icons.label_rounded, panel: 'labels'),
    // The Sync branch is always visible. Conflict resolution is a
    // sync-domain concept that can produce divergence even without
    // Matrix (e.g. legacy or local-only conflicts), so the conflicts
    // leaf stays reachable regardless of `enableMatrix`. The
    // matrix-specific leaves (backfill / stats / outbox /
    // matrix-maintenance) are gated by the flag — they describe
    // matrix-only surfaces that have no meaning when Matrix sync is
    // off.
    branch(
      'sync',
      Icons.sync_rounded,
      children: [
        if (enableMatrix) ...[
          leaf(
            'sync/backfill',
            Icons.cloud_download_outlined,
            panel: 'sync-backfill',
          ),
          leaf('sync/stats', Icons.bar_chart_rounded, panel: 'sync-stats'),
          leaf('sync/outbox', Icons.outbox_rounded, panel: 'sync-outbox'),
        ],
        // Conflict resolution stays in Sync regardless of the flag.
        // The Beamer URL is still `/settings/advanced/conflicts` for
        // legacy-deep-link compatibility — the URL ↔ id mapping in
        // `settingsNodeUrls` does the translation, and the column
        // stack keeps using the existing route patterns.
        leaf(
          'sync/conflicts',
          Icons.call_split_rounded,
          panel: 'sync-conflicts',
        ),
        if (enableMatrix)
          leaf(
            'sync/matrix-maintenance',
            Icons.build_outlined,
            panel: 'sync-matrix-maintenance',
          ),
      ],
    ),
    if (enableDashboards)
      leaf('dashboards', Icons.dashboard_rounded, panel: 'dashboards'),
    leaf('measurables', Icons.straighten_rounded, panel: 'measurables'),
    leaf('theming', Icons.palette_outlined, panel: 'theming'),
    leaf('flags', Icons.flag_outlined, panel: 'flags'),
    branch(
      'advanced',
      Icons.settings_suggest_outlined,
      children: [
        leaf(
          'advanced/logging',
          Icons.bug_report_outlined,
          panel: 'advanced-logging',
        ),
        leaf(
          'advanced/maintenance',
          Icons.handyman_outlined,
          panel: 'advanced-maintenance',
        ),
        leaf(
          'advanced/about',
          Icons.info_outline_rounded,
          panel: 'advanced-about',
        ),
      ],
    ),
  ];
}
