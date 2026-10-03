import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        any;
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/domain/settings_tree_data.dart';
import 'package:lotti/features/settings/domain/settings_urls.dart';
import 'package:lotti/features/settings/routing/settings_routes.dart';

enum _GeneratedSettingsUrlSuffix {
  none,
  trailingSlash,
  detailSegment,
  nestedDetailSegment,
}

class _GeneratedSettingsUrl {
  const _GeneratedSettingsUrl({
    required this.entry,
    required this.suffix,
    required this.withQuery,
    required this.withFragment,
  });

  final MapEntry<String, String> entry;
  final _GeneratedSettingsUrlSuffix suffix;
  final bool withQuery;
  final bool withFragment;

  String get url {
    final suffixValue = switch (suffix) {
      _GeneratedSettingsUrlSuffix.none => '',
      _GeneratedSettingsUrlSuffix.trailingSlash => '/',
      _GeneratedSettingsUrlSuffix.detailSegment => '/generated-detail',
      _GeneratedSettingsUrlSuffix.nestedDetailSegment =>
        '/generated-detail/edit',
    };

    final query = withQuery ? '?focus=generated' : '';
    final fragment = withFragment ? '#section' : '';
    return '${entry.value}$suffixValue$query$fragment';
  }

  List<String> get expectedPath => _idToPathModel(entry.key);

  @override
  String toString() {
    return '_GeneratedSettingsUrl('
        'entry: ${entry.key} -> ${entry.value}, '
        'suffix: $suffix, '
        'withQuery: $withQuery, '
        'withFragment: $withFragment)';
  }
}

extension _AnySettingsTreeIndexScenario on Any {
  Generator<_GeneratedSettingsUrlSuffix> get settingsUrlSuffix =>
      choose(_GeneratedSettingsUrlSuffix.values);

  Generator<_GeneratedSettingsUrl> get settingsUrl => combine4(
    choose(settingsRoutes.nodeUrls.entries.toList()),
    settingsUrlSuffix,
    this.bool,
    this.bool,
    (
      MapEntry<String, String> entry,
      _GeneratedSettingsUrlSuffix suffix,
      bool withQuery,
      bool withFragment,
    ) => _GeneratedSettingsUrl(
      entry: entry,
      suffix: suffix,
      withQuery: withQuery,
      withFragment: withFragment,
    ),
  );
}

List<String> _idToPathModel(String id) {
  final segments = id.split('/');
  return [
    for (var index = 0; index < segments.length; index++)
      segments.take(index + 1).join('/'),
  ];
}

/// Every node of the tree with every flag on — the superset any platform
/// or flag combination draws from — plus the demo world's Sync stand-in.
List<SettingsNode> _allNodes() {
  List<SettingsNode> build({required bool syncAvailable}) => buildSettingsTree(
    labels: (id) => (title: id, desc: id),
    enableHabits: true,
    enableDashboards: true,
    enableMatrix: true,
    enableWhatsNew: true,
    enableSpeechTts: true,
    enableGitHub: true,
    enableHealthImport: true,
    syncFeatureAvailable: syncAvailable,
  );
  final nodes = <String, SettingsNode>{};
  void walk(List<SettingsNode> level) {
    for (final node in level) {
      nodes[node.id] = node;
      walk(node.children ?? const []);
    }
  }

  walk(build(syncAvailable: true));
  walk(build(syncAvailable: false));
  return nodes.values.toList();
}

/// Every URL the registry answers on, with each `:param` filled in — the
/// node URLs, every sub-route and every alias.
List<String> _everyConcreteUrl() => [
  for (final pattern in settingsRoutes.patterns)
    pattern.replaceAllMapped(RegExp(r':(\w+)'), (m) => 'id-${m[1]}'),
];

void main() {
  group('pathToBeamUrl', () {
    test('empty path returns /settings', () {
      expect(pathToBeamUrl(const []), '/settings');
    });

    test('leaf path uses the last id', () {
      expect(
        pathToBeamUrl(['sync', 'sync/backfill']),
        '/settings/sync/backfill',
      );
    });

    test('branch-only path uses the branch url', () {
      expect(pathToBeamUrl(['sync']), '/settings/sync');
    });

    test('unknown id falls back to /settings (e.g. in-pane whats-new)', () {
      expect(pathToBeamUrl(['whats-new']), '/settings');
    });

    test('advanced/logging maps to the canonical logging_domains url', () {
      expect(
        pathToBeamUrl(['advanced', 'advanced/logging']),
        '/settings/advanced/logging_domains',
      );
    });

    test('advanced/system-health maps to /settings/advanced/system_health', () {
      expect(
        pathToBeamUrl(['advanced', 'advanced/system-health']),
        '/settings/advanced/system_health',
      );
    });

    test('sync/matrix-maintenance maps to the slash-split matrix url', () {
      expect(
        pathToBeamUrl(['sync', 'sync/matrix-maintenance']),
        '/settings/sync/matrix/maintenance',
      );
    });

    test('advanced/maintenance maps to /settings/advanced/maintenance', () {
      expect(
        pathToBeamUrl(['advanced', 'advanced/maintenance']),
        '/settings/advanced/maintenance',
      );
    });

    test('preference leaves keep their flat, pre-branch URLs', () {
      // The tree reparented them under `preferences`, but every URL that
      // shipped before the branch existed still has to be the one the app
      // navigates to — otherwise old deep links and what's-new releases
      // would point at routes that no longer exist.
      expect(
        pathToBeamUrl(['preferences', 'preferences/theming']),
        '/settings/theming',
      );
      expect(
        pathToBeamUrl(['preferences', 'preferences/keyboard-shortcuts']),
        '/settings/keyboard-shortcuts',
      );
      expect(
        pathToBeamUrl(['preferences', 'preferences/recording-style']),
        '/settings/recording-style',
      );
      expect(
        pathToBeamUrl(['preferences', 'preferences/notifications']),
        '/settings/notifications',
      );
      expect(
        pathToBeamUrl(['preferences', 'preferences/speech']),
        '/settings/speech',
      );
    });

    test('animations keeps its legacy advanced/* URL under Preferences', () {
      // The node moved branches; the URL did not. Same treatment as
      // `sync/conflicts`, and for the same reason.
      expect(
        pathToBeamUrl(['preferences', 'preferences/animations']),
        '/settings/advanced/animations',
      );
    });

    test('the preferences branch itself maps to /settings/preferences', () {
      expect(pathToBeamUrl(['preferences']), '/settings/preferences');
    });
  });

  group('beamUrlToPath — base cases', () {
    test('exact /settings returns an empty path', () {
      expect(beamUrlToPath('/settings'), isEmpty);
    });

    test('URL outside /settings returns an empty path', () {
      expect(beamUrlToPath('/tasks'), isEmpty);
      expect(beamUrlToPath('/settingsx'), isEmpty);
      expect(beamUrlToPath('/'), isEmpty);
    });

    test('trailing slash on /settings/ is canonicalized to /settings', () {
      expect(beamUrlToPath('/settings/'), isEmpty);
    });

    test('unknown leaf under /settings returns an empty path', () {
      expect(beamUrlToPath('/settings/completely-unknown'), isEmpty);
    });

    test('query string is stripped before prefix matching', () {
      expect(beamUrlToPath('/settings/categories?focus=new'), [
        'definitions',
        'definitions/categories',
      ]);
    });

    test('fragment is stripped before prefix matching', () {
      expect(beamUrlToPath('/settings/sync/backfill#anchor'), [
        'sync',
        'sync/backfill',
      ]);
    });

    test('query and fragment together both stripped', () {
      expect(beamUrlToPath('/settings/flags?x=1#top'), [
        'advanced',
        'advanced/flags',
      ]);
    });

    test(
      'a malformed URL that crashes Uri.parse falls back to the raw input',
      () {
        // A non-numeric port makes Uri.parse throw a FormatException
        // (a stray `%` in a path does not — Uri.parse re-encodes it);
        // the canonicalizer must catch it and treat the raw string as
        // the path. The raw input does not match the /settings prefix,
        // so we expect an empty path rather than a crash.
        const malformed = 'http://host:port/settings/advanced';
        expect(() => Uri.parse(malformed), throwsFormatException);
        expect(beamUrlToPath(malformed), isEmpty);
      },
    );
  });

  group('beamUrlToPath — greedy longest-prefix', () {
    test('/settings/advanced → [advanced]', () {
      expect(beamUrlToPath('/settings/advanced'), ['advanced']);
    });

    test(
      '/settings/advanced/maintenance wins over /settings/advanced (longest prefix)',
      () {
        expect(beamUrlToPath('/settings/advanced/maintenance'), [
          'advanced',
          'advanced/maintenance',
        ]);
      },
    );

    test(
      '/settings/advanced/logging_domains → [advanced, advanced/logging]',
      () {
        expect(beamUrlToPath('/settings/advanced/logging_domains'), [
          'advanced',
          'advanced/logging',
        ]);
      },
    );

    test(
      '/settings/sync/matrix/maintenance → [sync, sync/matrix-maintenance]',
      () {
        expect(beamUrlToPath('/settings/sync/matrix/maintenance'), [
          'sync',
          'sync/matrix-maintenance',
        ]);
      },
    );
  });

  group('beamUrlToPath — the preferences branch', () {
    test('/settings/preferences → [preferences]', () {
      expect(beamUrlToPath('/settings/preferences'), ['preferences']);
    });

    test('the animations URL resolves under Preferences, not Advanced', () {
      // `/settings/advanced/animations` is longer than `/settings/advanced`,
      // so the greedy longest-prefix walk must pick the Preferences leaf.
      // Getting this wrong would open the wrong branch on desktop and push
      // the wrong hub on mobile.
      expect(beamUrlToPath('/settings/advanced/animations'), [
        'preferences',
        'preferences/animations',
      ]);
      expect(beamUrlToPath('/settings/advanced'), ['advanced']);
    });

    test('each flat preference URL resolves under the branch', () {
      // The greedy resolver has to reach a two-segment tree path from a
      // one-segment URL: this is what opens the Preferences branch in the
      // desktop sidebar when a legacy `/settings/theming` link is followed.
      expect(beamUrlToPath('/settings/theming'), [
        'preferences',
        'preferences/theming',
      ]);
      expect(beamUrlToPath('/settings/keyboard-shortcuts'), [
        'preferences',
        'preferences/keyboard-shortcuts',
      ]);
      expect(beamUrlToPath('/settings/recording-style'), [
        'preferences',
        'preferences/recording-style',
      ]);
      expect(beamUrlToPath('/settings/notifications'), [
        'preferences',
        'preferences/notifications',
      ]);
      expect(beamUrlToPath('/settings/speech'), [
        'preferences',
        'preferences/speech',
      ]);
    });

    test('/settings/preferences does not swallow the flat leaf URLs', () {
      // The branch URL shares no prefix with its children, so the greedy
      // longest-first walk must never resolve a leaf to the bare branch.
      for (final url in const [
        '/settings/theming',
        '/settings/keyboard-shortcuts',
        '/settings/notifications',
        '/settings/recording-style',
        '/settings/speech',
      ]) {
        expect(beamUrlToPath(url), hasLength(2), reason: url);
      }
    });
  });

  group('beamUrlToPath — panel-local trailing segments', () {
    test('category detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/categories/abc-123'),
        ['definitions', 'definitions/categories'],
      );
    });

    test('label detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/labels/some-label-id'),
        ['definitions', 'definitions/labels'],
      );
    });

    test('habit detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/habits/by_id/some-habit'),
        ['definitions', 'definitions/habits'],
      );
    });

    test('agents template detail UUID is treated as panel-local', () {
      expect(
        beamUrlToPath('/settings/agents/templates/tpl-1'),
        ['agents', 'agents/templates'],
      );
    });

    test(
      'advanced/conflicts/:id resolves under the Sync branch (the leaf '
      'lives under sync/* in the tree even though the URL still wears '
      'the legacy advanced/* path)',
      () {
        expect(
          beamUrlToPath('/settings/advanced/conflicts/conflict-id'),
          ['sync', 'sync/conflicts'],
        );
      },
    );
  });

  group('beamUrlToPath ↔ pathToBeamUrl round-trip', () {
    test('every registered node id round-trips through URL and back', () {
      for (final entry in settingsRoutes.nodeUrls.entries) {
        final roundTrip = beamUrlToPath(entry.value);
        expect(
          pathToBeamUrl(roundTrip),
          entry.value,
          reason: 'round-trip for ${entry.key}',
        );
      }
    });

    Glados(any.settingsUrl, ExploreConfig(numRuns: 180)).test(
      'greedily resolves generated registered URLs with local suffixes',
      (scenario) {
        final path = beamUrlToPath(scenario.url);

        expect(
          path,
          scenario.expectedPath,
          reason:
              'Generated URL should resolve to its registered node path: '
              '$scenario',
        );
        expect(pathToBeamUrl(path), scenario.entry.value);
      },
      tags: 'glados',
    );
  });

  group('settingsRoutes covers the tree, and nothing else', () {
    final nodes = _allNodes();

    test('every node is either an action or has a route entry', () {
      for (final node in nodes) {
        expect(
          node.action != null || settingsRoutes.routes.containsKey(node.id),
          isTrue,
          reason: '${node.id} is unreachable: add a settingsRoutes entry',
        );
      }
    });

    test('every route entry belongs to a tree node', () {
      final ids = {for (final node in nodes) node.id};
      expect(ids, containsAll(settingsRoutes.routes.keys));
    });

    test('an action node has no route — it never becomes a page', () {
      for (final node in nodes.where((n) => n.action != null)) {
        expect(settingsRoutes.routes.containsKey(node.id), isFalse);
      }
    });

    test('every leaf has a desktop panel, except the ones that are '
        'deliberately not desktop pages', () {
      const notOnDesktop = {
        // Phone-only: HealthKit / Health Connect have no desktop path.
        'advanced/health-import',
        // The demo world's inert explainer tile.
        'sync-unavailable',
      };
      for (final node in nodes) {
        if (node.hasChildren || node.action != null) continue;
        final panel = settingsRoutes.routes[node.id]?.panel;
        expect(
          panel == null,
          notOnDesktop.contains(node.id),
          reason: node.id,
        );
      }
    });

    test('every route except the explainer tile has a URL', () {
      for (final MapEntry(:key, :value) in settingsRoutes.routes.entries) {
        expect(value.url == null, key == 'sync-unavailable', reason: key);
      }
    });

    test('the literal URLs match the constants code outside the registry '
        'uses', () {
      expect(settingsRoutes.root.url, settingsRootUrl);
      expect(settingsRoutes.nodeUrls['ai'], aiSettingsParentRoute);
    });

    test('no two nodes share a URL', () {
      final urls = settingsRoutes.nodeUrls.values.toList();
      expect(urls.toSet(), hasLength(urls.length));
    });

    test("each sub-route pattern sits below its node's URL", () {
      for (final MapEntry(:key, :value) in settingsRoutes.routes.entries) {
        for (final sub in value.subRoutes) {
          expect(sub.pattern, startsWith('${value.url}/'), reason: key);
        }
      }
      for (final sub in settingsRoutes.root.subRoutes) {
        expect(sub.pattern, startsWith('/settings/'));
      }
    });
  });

  group('back navigation, over every registered URL', () {
    final urls = _everyConcreteUrl();

    test('the URL list is the full registry', () {
      expect(urls.length, settingsRoutes.patterns.length);
      expect(urls, contains('/settings/sync/matrix/maintenance'));
      expect(urls, contains('/settings/agents/templates/id-templateId/review'));
    });

    // The invariant behind every "the page I left came back" bug: a page's
    // pop target must resolve to exactly the pages beneath it. Then a back
    // gesture only ever uncovers a page — Navigator never has to swap one
    // in or push an identical one back, which is what played a push
    // animation on a back tap (AI details, flat Definitions leaves, and
    // Sync → Matrix maintenance, each found and patched on its own before).
    for (final url in urls) {
      test('every page of $url pops to the stack beneath it', () {
        final stack = settingsRoutes.resolve(Uri.parse(url)).stack;
        for (var i = 1; i < stack.length; i++) {
          final beneath = settingsRoutes
              .resolve(Uri.parse(stack[i].popUrl))
              .stack;
          expect(
            [for (final e in beneath) e.key],
            [for (final e in stack.take(i)) e.key],
            reason: '${stack[i].key} pops to ${stack[i].popUrl}',
          );
        }
      });
    }

    test('every node URL shows its own page, or its section page when it is '
        'a tab of one', () {
      for (final MapEntry(:key, :value) in settingsRoutes.nodeUrls.entries) {
        final match = settingsRoutes.resolve(Uri.parse(value));
        expect(match.nodePath.last, key, reason: value);
        final ownPage = settingsRoutes.routes[key]!.page != null;
        expect(
          match.stack.last.key,
          ownPage ? 'settings-$key' : 'settings-${match.nodePath.first}',
          reason: value,
        );
      }
    });
  });
}
