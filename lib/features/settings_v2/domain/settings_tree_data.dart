import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
  bool syncFeatureAvailable = true,
}) {
  SettingsNode leaf(
    String id,
    IconData icon, {
    String? panel,
    SettingsNodeAction? action,
    bool sectionBreakBefore = false,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      panel: panel,
      action: action,
      sectionBreakBefore: sectionBreakBefore,
    );
  }

  SettingsNode branch(
    String id,
    IconData icon, {
    required List<SettingsNode> children,
    String? panel,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      children: children,
      panel: panel,
    );
  }

  return [
    if (enableWhatsNew)
      leaf(
        'whats-new',
        LottiIcons.verified,
        panel: 'whats-new',
      ),
    // Top-level entry point back to the FTUE welcome flow. Unconditional: the
    // welcome itself is always on, and this is the only way back to it once the
    // auto-show budget has been exhausted (or the rollout retired it for an
    // already-configured install), so gating it would strand exactly the users
    // who need it. A leaf rather than a branch: only one onboarding flow exists
    // today. Should a second one land, this is a one-line conversion to a
    // branch with children (see `sync`, `ai`).
    leaf(
      'onboarding',
      LottiIcons.rocket,
      panel: 'onboarding',
    ),
    branch(
      'ai',
      LottiIcons.reasoning,
      panel: 'ai',
      // Children mirror the three tabs inside the v3 AI Settings
      // page so the desktop sidebar shows the same three list views
      // (Providers / Models / Profiles) without the in-pane TabBar.
      children: [
        leaf('ai/providers', LottiIcons.bolt, panel: 'ai-providers'),
        leaf('ai/models', LottiIcons.reasoning, panel: 'ai-models'),
        leaf('ai/profiles', LottiIcons.tune, panel: 'ai-profiles'),
        leaf('ai/usage', LottiIcons.eco, panel: 'ai-usage'),
      ],
    ),
    branch(
      'agents',
      LottiIcons.aiModel,
      panel: 'agents',
      // Children mirror the tab order inside `AgentSettingsBody`
      // (templates, instances, souls, pending-wakes) so the tree
      // shape matches what the right pane shows under Agents.
      children: [
        leaf(
          'agents/templates',
          LottiIcons.description,
          panel: 'agents-templates',
        ),
        leaf(
          'agents/instances',
          LottiIcons.hub,
          panel: 'agents-instances',
        ),
        leaf('agents/souls', LottiIcons.aiSpark, panel: 'agents-souls'),
        // Trailing path segment is hyphenated (`pending-wakes`)
        // rather than nested (`pending/wakes`); the `_idToPath`
        // walker splits ids on `/` and would otherwise look up a
        // non-existent `agents/pending` parent. The full leaf id is
        // `agents/pending-wakes`, the panel id is
        // `agents-pending-wakes`, and the URL is
        // `/settings/agents/pending-wakes`.
        leaf(
          'agents/pending-wakes',
          LottiIcons.timer,
          panel: 'agents-pending-wakes',
        ),
      ],
    ),
    leaf(
      'daily-os',
      LottiIcons.today,
      panel: 'daily-os',
    ),
    // Sync sits directly below Agents — both are runtime / system
    // concerns and read better as a pair than separated by the
    // taxonomy leaves (habits / categories / labels). The entire Sync
    // branch is gated by `enableMatrix`: sync is either on (the user
    // gets the full surface, including conflict resolution) or off
    // (no Sync entry at all). This keeps desktop and mobile in sync
    // — previously desktop showed a bare Sync branch with only
    // Conflicts while mobile hid Sync entirely.
    // Guest/demo worlds run without the Matrix stack (see
    // `ProfileCapabilities.guest`): the entire Sync section collapses into
    // a single non-interactive explainer tile — no panel, no action — so
    // the tree never routes anywhere that would resolve the absent
    // MatrixService. The tile shows regardless of `enableMatrix` because
    // the flag row itself is filtered out of the Flags page in demo mode.
    if (!syncFeatureAvailable)
      leaf('sync-unavailable', LottiIcons.syncProblem)
    else if (enableMatrix)
      branch(
        'sync',
        LottiIcons.sync,
        // The Sync branch has no landing panel of its own — selecting it
        // leaves the desktop detail pane empty. The provisioned-sync
        // (QR-pairing) entry point is the first child leaf instead, so it
        // reads as a normal row in the list (Devices · This device ·
        // Backfill · …) rather than as a default pane body.
        children: [
          // QR-pairing / provisioning-bundle setup. First in the list so
          // it stays the natural starting point for a fresh device.
          leaf(
            'sync/provisioned',
            LottiIcons.scanQr,
            panel: 'sync-provisioned',
          ),
          leaf(
            'sync/node-profile',
            LottiIcons.devices,
            panel: 'sync-node-profile',
          ),
          leaf(
            'sync/backfill',
            LottiIcons.cloudDownload,
            panel: 'sync-backfill',
          ),
          leaf('sync/stats', LottiIcons.chart, panel: 'sync-stats'),
          // Mail-envelope leading glyph (as the standalone Sync page used),
          // rounded to match the other tree icons; the teal postbox +
          // pending-count badge lives in the row's trailing slot via
          // OutboxCountIndicator.
          leaf('sync/outbox', LottiIcons.mail, panel: 'sync-outbox'),
          // The Beamer URL is still `/settings/advanced/conflicts`
          // for legacy-deep-link compatibility — the URL ↔ id mapping
          // in `settingsNodeUrls` does the translation, and the
          // column stack keeps using the existing route patterns.
          leaf(
            'sync/conflicts',
            LottiIcons.split,
            panel: 'sync-conflicts',
          ),
          leaf(
            'sync/matrix-maintenance',
            LottiIcons.build,
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
      LottiIcons.tree,
      children: [
        leaf(
          'definitions/categories',
          LottiIcons.category,
          panel: 'categories',
        ),
        leaf('definitions/labels', LottiIcons.label, panel: 'labels'),
        if (enableHabits)
          leaf(
            'definitions/habits',
            LottiIcons.repeat,
            panel: 'habits',
          ),
        if (enableDashboards)
          leaf(
            'definitions/dashboards',
            LottiIcons.dashboard,
            panel: 'dashboards',
          ),
        leaf(
          'definitions/measurables',
          LottiIcons.measure,
          panel: 'measurables',
        ),
      ],
    ),
    leaf(
      'recording-style',
      LottiIcons.waveform,
      panel: 'recording-style',
    ),
    leaf('theming', LottiIcons.palette, panel: 'theming'),
    leaf(
      'keyboard-shortcuts',
      LottiIcons.keyboard,
      panel: 'keyboard-shortcuts',
    ),
    if (enableSpeechTts) leaf('speech', LottiIcons.voice, panel: 'speech'),
    branch(
      'advanced',
      LottiIcons.settings,
      children: [
        // Config flags moved here from the top level so casual users
        // aren't faced with a "Configure flags" entry alongside genuinely
        // first-class settings. Power users still reach it through
        // Advanced. URL stays `/settings/flags` for deep-link compat.
        leaf('advanced/flags', LottiIcons.flag, panel: 'flags'),
        leaf(
          'advanced/animations',
          LottiIcons.animation,
          panel: 'advanced-animations',
        ),
        leaf(
          'advanced/manual-language',
          LottiIcons.language,
          panel: 'advanced-manual-language',
        ),
        leaf(
          'advanced/logging',
          LottiIcons.bug,
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
            LottiIcons.healthShield,
            panel: 'health-import',
          ),
        leaf(
          'advanced/maintenance',
          LottiIcons.build,
          panel: 'advanced-maintenance',
        ),
        leaf(
          'advanced/onboarding-metrics',
          LottiIcons.trendingUp,
          panel: 'advanced-onboarding-metrics',
        ),
        leaf(
          'advanced/about',
          LottiIcons.info,
          panel: 'advanced-about',
        ),
      ],
    ),
    // The Manual is a support resource rather than a configuration surface.
    // Keep it at the bottom of the root Settings level, visually separated
    // from configuration entries while still available on every platform.
    leaf(
      'manual',
      LottiIcons.book,
      action: SettingsNodeAction.openManual,
      sectionBreakBefore: true,
    ),
  ];
}
