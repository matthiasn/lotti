import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:material_ui/material_ui.dart';

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

/// Builds the full Settings tree: what exists, how it is grouped, and which
/// flags gate it. Both the desktop tree-nav and the mobile drill-down render
/// it; where each node leads is declared on its `settingsRoutes` entry.
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
    SettingsNodeAction? action,
    bool sectionBreakBefore = false,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      action: action,
      sectionBreakBefore: sectionBreakBefore,
    );
  }

  SettingsNode branch(
    String id,
    IconData icon, {
    required List<SettingsNode> children,
  }) {
    final l = labels(id);
    return SettingsNode(
      id: id,
      icon: icon,
      title: l.title,
      desc: l.desc,
      children: children,
    );
  }

  return [
    if (enableWhatsNew)
      leaf(
        'whats-new',
        LottiIcons.verified,
        action: SettingsNodeAction.openWhatsNew,
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
    ),
    // Sections sits second, directly under the welcome flow, because it is
    // the page that decides what the rest of the app even contains. The
    // toggles behind it (Habits, Projects, Daily OS, …) used to be seven
    // rows among twenty-three on Advanced → Config Flags, which made the
    // app's progressive disclosure undiscoverable: a feature nobody can find
    // the switch for is a feature that is off forever. Unconditional and
    // unflagged — a page whose whole job is turning features on cannot
    // itself be gated.
    leaf(
      'sections',
      LottiIcons.layers,
    ),
    branch(
      'ai',
      LottiIcons.reasoning,
      // Children mirror the three tabs inside the v3 AI Settings
      // page so the desktop sidebar shows the same three list views
      // (Providers / Models / Profiles) without the in-pane TabBar.
      children: [
        leaf('ai/providers', LottiIcons.bolt),
        leaf('ai/models', LottiIcons.reasoning),
        leaf('ai/profiles', LottiIcons.tune),
        leaf('ai/usage', LottiIcons.eco),
      ],
    ),
    branch(
      'agents',
      LottiIcons.aiModel,
      // Children mirror the tab order inside `AgentSettingsBody`
      // (templates, instances, souls, pending-wakes) so the tree
      // shape matches what the right pane shows under Agents.
      children: [
        leaf(
          'agents/templates',
          LottiIcons.description,
        ),
        leaf(
          'agents/instances',
          LottiIcons.hub,
        ),
        leaf('agents/souls', LottiIcons.aiSpark),
        // Trailing path segment is hyphenated (`pending-wakes`)
        // rather than nested (`pending/wakes`); the `_idToPath`
        // walker splits ids on `/` and would otherwise look up a
        // non-existent `agents/pending` parent.
        leaf(
          'agents/pending-wakes',
          LottiIcons.timer,
        ),
      ],
    ),
    leaf(
      'daily-os',
      LottiIcons.today,
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
          ),
          leaf(
            'sync/node-profile',
            LottiIcons.devices,
          ),
          leaf(
            'sync/backfill',
            LottiIcons.cloudDownload,
          ),
          leaf('sync/stats', LottiIcons.chart),
          // Mail-envelope leading glyph (as the standalone Sync page used),
          // rounded to match the other tree icons; the teal postbox +
          // pending-count badge lives in the row's trailing slot via
          // OutboxCountIndicator.
          leaf('sync/outbox', LottiIcons.mail),
          // Still answers on `/settings/advanced/conflicts`, the URL it
          // shipped with — see its `settingsRoutes` entry.
          leaf(
            'sync/conflicts',
            LottiIcons.split,
          ),
          leaf(
            'sync/matrix-maintenance',
            LottiIcons.build,
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
    // (`/settings/habits`, …) on their `settingsRoutes` entries.
    branch(
      'definitions',
      LottiIcons.tree,
      children: [
        leaf(
          'definitions/categories',
          LottiIcons.category,
        ),
        leaf('definitions/labels', LottiIcons.label),
        leaf('definitions/speech-dictionary', LottiIcons.book),
        if (enableHabits)
          leaf(
            'definitions/habits',
            LottiIcons.repeat,
          ),
        if (enableDashboards)
          leaf(
            'definitions/dashboards',
            LottiIcons.dashboard,
          ),
        leaf(
          'definitions/measurables',
          LottiIcons.measure,
        ),
      ],
    ),
    // Personal-preference branch — groups the settings that shape how the
    // app looks, sounds and responds to you behind a single "Preferences"
    // entry, directly above Advanced.
    //
    // Four of them used to sit loose at the root (theming, keyboard
    // shortcuts, recording style, speech), where they separated Definitions
    // from Advanced and made the top level read as a menu plus leftovers.
    // Animations came the other way, out of Advanced: completion
    // celebrations are a matter of taste, not a maintenance tool, and they
    // belong beside theming rather than beside the log domains.
    //
    // Order is look → feel → capture → voice → input.
    //
    // Leaf ids are namespaced under `preferences/` (e.g.
    // `preferences/theming`) but their public Beamer URLs are unchanged —
    // flat for the four that were at the root (`/settings/theming`, …) and
    // still `/settings/advanced/animations` for animations, because a URL
    // that has shipped is not worth breaking to tidy a menu.
    // Their `settingsRoutes` entries carry those URLs, exactly as
    // `sync/conflicts` keeps its own.
    branch(
      'preferences',
      LottiIcons.tune,
      children: [
        leaf('preferences/theming', LottiIcons.palette),
        leaf(
          'preferences/animations',
          LottiIcons.animation,
        ),
        leaf(
          'preferences/notifications',
          LottiIcons.notificationActive,
        ),
        leaf(
          'preferences/recording-style',
          LottiIcons.waveform,
        ),
        if (enableSpeechTts) leaf('preferences/speech', LottiIcons.voice),
        leaf(
          'preferences/keyboard-shortcuts',
          LottiIcons.keyboard,
        ),
      ],
    ),
    branch(
      'advanced',
      LottiIcons.settings,
      children: [
        // Config flags moved here from the top level so casual users
        // aren't faced with a "Configure flags" entry alongside genuinely
        // first-class settings. Power users still reach it through
        // Advanced. URL stays `/settings/flags` for deep-link compat.
        leaf('advanced/flags', LottiIcons.flag),
        leaf('advanced/github', LottiIcons.merge),
        leaf(
          'advanced/manual-language',
          LottiIcons.language,
        ),
        leaf(
          'advanced/logging',
          LottiIcons.bug,
        ),
        leaf(
          'advanced/system-health',
          LottiIcons.healthShield,
        ),
        // Health import is iOS/Android only — the underlying HealthKit /
        // Health Connect import has no desktop path — so the leaf is
        // gated on the mobile platform (see `enableHealthImport`, fed
        // from `isMobile`), and its route has no desktop panel.
        if (enableHealthImport)
          leaf(
            'advanced/health-import',
            LottiIcons.healthShield,
          ),
        leaf(
          'advanced/maintenance',
          LottiIcons.build,
        ),
        leaf(
          'advanced/onboarding-metrics',
          LottiIcons.trendingUp,
        ),
        leaf(
          'advanced/about',
          LottiIcons.info,
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
