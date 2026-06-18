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
  required bool enableHabits,
  required bool enableDashboards,
  required bool enableMatrix,
  required bool enableWhatsNew,
  bool enableSpeechTts = false,
  bool enableHealthImport = false,
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
      // Children mirror the three tabs inside the v3 AI Settings
      // page so the desktop sidebar shows the same three list views
      // (Providers / Models / Profiles) without the in-pane TabBar.
      children: [
        leaf('ai/providers', Icons.bolt_rounded, panel: 'ai-providers'),
        leaf('ai/models', Icons.psychology_alt_rounded, panel: 'ai-models'),
        leaf('ai/profiles', Icons.tune_rounded, panel: 'ai-profiles'),
      ],
    ),
    branch(
      'agents',
      Icons.smart_toy_outlined,
      panel: 'agents',
      // Children mirror the tab order inside `AgentSettingsBody`
      // (stats, templates, instances, souls, pending-wakes) so the
      // tree shape matches what the right pane shows under Agents.
      children: [
        leaf(
          'agents/stats',
          Icons.insights_rounded,
          panel: 'agents-stats',
        ),
        leaf(
          'agents/templates',
          Icons.article_outlined,
          panel: 'agents-templates',
        ),
        leaf(
          'agents/instances',
          Icons.hub_outlined,
          panel: 'agents-instances',
        ),
        leaf('agents/souls', Icons.auto_awesome, panel: 'agents-souls'),
        // Trailing path segment is hyphenated (`pending-wakes`)
        // rather than nested (`pending/wakes`); the `_idToPath`
        // walker splits ids on `/` and would otherwise look up a
        // non-existent `agents/pending` parent. The full leaf id is
        // `agents/pending-wakes`, the panel id is
        // `agents-pending-wakes`, and the URL is
        // `/settings/agents/pending-wakes`.
        leaf(
          'agents/pending-wakes',
          Icons.timer_outlined,
          panel: 'agents-pending-wakes',
        ),
      ],
    ),
    // Sync sits directly below Agents — both are runtime / system
    // concerns and read better as a pair than separated by the
    // taxonomy leaves (habits / categories / labels). The entire Sync
    // branch is gated by `enableMatrix`: sync is either on (the user
    // gets the full surface, including conflict resolution) or off
    // (no Sync entry at all). This keeps desktop and mobile in sync
    // — previously desktop showed a bare Sync branch with only
    // Conflicts while mobile hid Sync entirely.
    if (enableMatrix)
      branch(
        'sync',
        Icons.sync_rounded,
        // The Sync branch has no landing panel of its own — selecting it
        // leaves the desktop detail pane empty. The provisioned-sync
        // (QR-pairing) entry point is the first child leaf instead, so it
        // reads as a normal row in the list (Provisioned Sync · This
        // device · Backfill · …) rather than as a default pane body.
        children: [
          // QR-pairing / provisioning-bundle setup. First in the list so
          // it stays the natural starting point for a fresh device.
          leaf(
            'sync/provisioned',
            Icons.qr_code_scanner,
            panel: 'sync-provisioned',
          ),
          leaf(
            'sync/node-profile',
            Icons.devices_rounded,
            panel: 'sync-node-profile',
          ),
          leaf(
            'sync/backfill',
            Icons.cloud_download_outlined,
            panel: 'sync-backfill',
          ),
          leaf('sync/stats', Icons.bar_chart_rounded, panel: 'sync-stats'),
          // Mail-envelope leading glyph (as the standalone Sync page used),
          // rounded to match the other tree icons; the teal postbox +
          // pending-count badge lives in the row's trailing slot via
          // OutboxCountIndicator.
          leaf('sync/outbox', Icons.mail_rounded, panel: 'sync-outbox'),
          // The Beamer URL is still `/settings/advanced/conflicts`
          // for legacy-deep-link compatibility — the URL ↔ id mapping
          // in `settingsNodeUrls` does the translation, and the
          // column stack keeps using the existing route patterns.
          leaf(
            'sync/conflicts',
            Icons.call_split_rounded,
            panel: 'sync-conflicts',
          ),
          leaf(
            'sync/matrix-maintenance',
            Icons.build_outlined,
            panel: 'sync-matrix-maintenance',
          ),
        ],
      ),
    // Entity definitions branch — groups habits / categories / labels /
    // dashboards / measurables behind a single "Definitions" entry so the
    // root list reads as: AI · Agents · Sync · Definitions · Theming ·
    // Advanced. New users see five entity types fewer at the top level.
    //
    // Leaf ids are namespaced under `definitions/` (e.g.
    // `definitions/habits`) but their public Beamer URLs stay flat
    // (`/settings/habits`, …) — `settingsNodeUrls` does the translation.
    // Panel ids (`habits`, `categories`, …) stay unchanged so the
    // panel_registry continues to dispatch on stable keys.
    branch(
      'definitions',
      Icons.account_tree_outlined,
      children: [
        leaf(
          'definitions/categories',
          Icons.category_rounded,
          panel: 'categories',
        ),
        leaf('definitions/labels', Icons.label_rounded, panel: 'labels'),
        if (enableHabits)
          leaf(
            'definitions/habits',
            Icons.repeat_rounded,
            panel: 'habits',
          ),
        if (enableDashboards)
          leaf(
            'definitions/dashboards',
            Icons.dashboard_rounded,
            panel: 'dashboards',
          ),
        leaf(
          'definitions/measurables',
          Icons.straighten_rounded,
          panel: 'measurables',
        ),
      ],
    ),
    leaf('theming', Icons.palette_outlined, panel: 'theming'),
    if (enableSpeechTts)
      leaf('speech', Icons.record_voice_over_outlined, panel: 'speech'),
    branch(
      'advanced',
      Icons.settings_suggest_outlined,
      children: [
        // Config flags moved here from the top level so casual users
        // aren't faced with a "Configure flags" entry alongside genuinely
        // first-class settings. Power users still reach it through
        // Advanced. URL stays `/settings/flags` for deep-link compat.
        leaf('advanced/flags', Icons.flag_outlined, panel: 'flags'),
        leaf(
          'advanced/logging',
          Icons.bug_report_outlined,
          panel: 'advanced-logging',
        ),
        // Health import is iOS/Android only — the underlying HealthKit /
        // Health Connect import has no desktop path — so the leaf is
        // gated on the mobile platform (see `enableHealthImport`, fed
        // from `isMobile`). Its panel is never rendered on desktop, so it
        // intentionally has no panel_registry entry; mobile beams to the
        // existing `/settings/health_import` route.
        if (enableHealthImport)
          leaf(
            'advanced/health-import',
            Icons.health_and_safety_rounded,
            panel: 'health-import',
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
