/// Holds every import in `lib/` to a declared layer order.
///
/// `knowledge/architecture/overview.md` describes the intended dependency
/// directions; this guard is what makes them more than prose. Every
/// `lib/features/<name>` module has a rank in [featureOrder], bottom to top,
/// and a file may import a feature only at its own rank or below. Around the
/// features sit two fixed layers: the shared [foundation] directories rank
/// below every feature, and the [shell] — router, composition root, app
/// entry points — ranks above all of them.
///
/// Three kinds of import break the order:
///
/// - **upward**: a file imports a feature ranked above its own;
/// - **shell** / **shared_ui**: a file imports the [shell], or foundation code
///   imports [sharedUi] — both rank above it. The [serviceLocator] is exempt;
/// - **ui**: non-UI code (models, repositories, services, state) imports
///   another feature's UI, whatever the ranks.
///
/// The imports that already break it are listed in the baseline. A new one
/// fails CI, and one that is gone fails too until the baseline drops it, so
/// the list only ever shrinks.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Feature modules from the bottom layer up. A feature may import the ones
/// before it, never the ones after.
///
/// The order is the one that leaves the fewest upward imports in the tree it
/// was introduced against, checked by hand where the domain has a clear
/// answer: the design system and categories at the bottom, the agent runtime
/// above the AI layer it calls, the journal — the logbook surface, its
/// repository now shared from `lib/logic` — above the speech and agent
/// features it composes, sync above the features whose entities it carries
/// (features reach it through its outbox), the aggregators — demo,
/// onboarding, Daily OS — near the top, and settings above them, since its
/// route table hosts every feature's settings pages. Moving a feature is a
/// design decision, and shows up as one in review.
const featureOrder = <String>[
  'provenance',
  'user_activity',
  'design_system',
  'recent_searches',
  'ratings',
  'notifications',
  'whats_new',
  'surveys',
  'keyboard',
  'categories',
  'labels',
  'speech_dictionary',
  'insights',
  'lockdown',
  'checklist',
  'ai_consumption',
  'ai',
  'dashboards',
  'tts',
  'agents',
  'speech',
  'journal',
  'profiles',
  'knowledge_graph',
  'sync',
  'nudges',
  'theming',
  'demo',
  'github',
  'tasks',
  'plaza',
  'habits',
  'goals',
  'projects',
  'daily_os_next',
  'onboarding',
  'system_health',
  'settings',
  'relationships',
  'events',
  'backup_restore',
];

/// Shared code every feature may use, so it must use none of them.
const foundation = <String>[
  'lib/classes/',
  'lib/database/',
  'lib/logic/',
  'lib/map/',
  'lib/providers/',
  'lib/services/',
  'lib/utils/',
];

/// Shared UI built on the design system: it ranks with `design_system`, so it
/// may use the design system and the features below it, but no domain
/// feature. The design system is a foundation library that lives under
/// `lib/features/` for its token pipeline and widgetbook.
const sharedUi = <String>['lib/themes/', 'lib/ui/', 'lib/widgets/'];

/// The app shell and composition root: they assemble the features, so they
/// may import any of them.
const shell = <String>[
  'lib/beamer/',
  'lib/widgetbook/',
  'lib/app_bootstrap.dart',
  'lib/app_root.dart',
  'lib/get_it.dart',
  'lib/get_it_helpers.dart',
  'lib/get_it_maintenance.dart',
  'lib/get_it_sync.dart',
  'lib/main.dart',
  'lib/service_disposer.dart',
  'lib/widgetbook.dart',
];

/// Directory names that make a file inside a feature part of its UI.
const uiDirectories = <String>{
  'pages',
  'routing',
  'ui',
  'view',
  'views',
  'widgetbook',
  'widgets',
};

/// Generated sources restate the hand-written ones.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.startsWith('lib/l10n/');

/// The feature a `lib/`-relative [path] belongs to, or null outside features.
String? featureOf(String path) {
  final parts = path.split('/');
  return parts.length > 3 && parts[0] == 'lib' && parts[1] == 'features'
      ? parts[2]
      : null;
}

/// Whether [path] (inside a feature) sits in one of its UI directories.
bool isUi(String path) {
  final parts = path.split('/');
  return parts.length > 3 &&
      parts.sublist(3, parts.length - 1).any(uiDirectories.contains);
}

/// The rank of the file at [path]: a feature's index in [featureOrder], -1
/// for [foundation], the design system's rank for [sharedUi], and
/// `featureOrder.length` for the [shell]. Null for a
/// file the order does not cover, which the guard reports.
int? rankOf(String path) {
  final feature = featureOf(path);
  if (feature != null) {
    final index = featureOrder.indexOf(feature);
    return index < 0 ? null : index;
  }
  if (foundation.any(path.startsWith)) return -1;
  if (sharedUi.any(path.startsWith)) {
    return featureOrder.indexOf('design_system');
  }
  if (shell.any(path.startsWith)) return featureOrder.length;
  return null;
}

/// The `lib/`-relative paths [source] imports or exports from this package,
/// including every URI behind a configuration (`if (dart.library.io) '…'`),
/// since any one of them may be the import a platform compiles.
List<String> lottiImports(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  return [
    for (final directive in unit.directives)
      if (directive is NamespaceDirective)
        for (final uri in [
          directive.uri.stringValue,
          for (final configuration in directive.configurations)
            configuration.uri.stringValue,
        ])
          if (uri != null && uri.startsWith('package:lotti/'))
            'lib/${uri.substring('package:lotti/'.length)}',
  ];
}

/// The service locator. Every layer still reads it while services move to
/// providers and constructor arguments, so it is exempt here: `tool/di`
/// counts those lookups instead, against a baseline of its own.
const serviceLocator = 'lib/get_it.dart';

/// The baseline entry for an upward import of a non-feature [target]:
/// `shell` or `shared_ui`, after the layer it reaches into.
String layerName(String target) =>
    shell.any(target.startsWith) ? 'shell' : 'shared_ui';

/// The layer-order breaks in the file at [path] with contents [source], as
/// baseline entries: a bare feature name for an upward import of a feature,
/// `shell` or `shared_ui` for one reaching into those layers, and
/// `<name>:ui` for non-UI code reaching another feature's UI.
Set<String> violationsIn(String path, String source) {
  final rank = rankOf(path);
  if (rank == null) return const {};
  final ownFeature = featureOf(path);
  final fromUi = ownFeature == null
      ? sharedUi.any(path.startsWith)
      : isUi(path);
  final found = <String>{};
  for (final target in lottiImports(source)) {
    final feature = featureOf(target);
    if (feature == null) {
      final targetRank = rankOf(target);
      if (target != serviceLocator && targetRank != null && targetRank > rank) {
        found.add(layerName(target));
      }
      continue;
    }
    if (feature == ownFeature) continue;
    final targetRank = featureOrder.indexOf(feature);
    if (targetRank > rank) found.add(feature);
    if (!fromUi && isUi(target) && rank < featureOrder.length) {
      found.add('$feature:ui');
    }
  }
  return found;
}

/// The outcome of a scan.
class LayerResult {
  const LayerResult({
    required this.current,
    required this.added,
    required this.removed,
    required this.unranked,
  });

  /// Every break in the tree, per file.
  final Map<String, Set<String>> current;

  /// Breaks the baseline does not list — the ones a change just introduced.
  final Map<String, Set<String>> added;

  /// Baseline entries that no longer occur and must be deleted from it.
  final Map<String, Set<String>> removed;

  /// Files under `lib/` that neither a feature, [foundation] nor [shell]
  /// covers, and features missing from [featureOrder].
  final List<String> unranked;

  int get total => current.values.fold(0, (sum, s) => sum + s.length);
}

/// Scans every hand-written Dart file under [root] and compares the breaks
/// against [baseline].
LayerResult scan({
  required Directory root,
  required Map<String, Set<String>> baseline,
  required String repoRoot,
}) {
  final current = <String, Set<String>>{};
  final unranked = <String>{};
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final rel = p.posix.joinAll(p.split(p.relative(file.path, from: repoRoot)));
    if (isGenerated(rel)) continue;
    if (rankOf(rel) == null) {
      unranked.add(featureOf(rel) ?? rel);
      continue;
    }
    final found = violationsIn(rel, file.readAsStringSync());
    if (found.isNotEmpty) current[rel] = found;
  }
  final added = <String, Set<String>>{};
  final removed = <String, Set<String>>{};
  for (final MapEntry(key: path, value: now) in current.entries) {
    final extra = now.difference(baseline[path] ?? const {});
    if (extra.isNotEmpty) added[path] = extra;
  }
  for (final MapEntry(key: path, value: listed) in baseline.entries) {
    final gone = listed.difference(current[path] ?? const {});
    if (gone.isNotEmpty) removed[path] = gone;
  }
  return LayerResult(
    current: current,
    added: added,
    removed: removed,
    unranked: unranked.toList()..sort(),
  );
}

/// Reads a baseline, treating a missing file as "nothing tolerated".
Map<String, Set<String>> readBaseline(File file) {
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map || decoded['files'] is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in (decoded['files'] as Map).entries)
      key as String: {for (final v in value as List) v as String},
  };
}

/// Serialises a baseline deterministically.
String encodeBaseline(Map<String, Set<String>> current) {
  final keys = current.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln(
      '  "_comment": "Imports that break the layer order in '
      'tool/architecture/layer_guard.dart: a bare feature name is an upward '
      'import, shell or shared_ui one reaching into those layers, and '
      "<feature>:ui is non-UI code reaching another feature's UI. "
      'Delete an entry when the import goes; regenerate with dart run '
      'tool/architecture/validate.dart --update-baseline. It only ever '
      'shrinks.",',
    )
    ..writeln('  "files": {');
  for (var i = 0; i < keys.length; i++) {
    final values = current[keys[i]]!.toList()..sort();
    final comma = i == keys.length - 1 ? '' : ',';
    buffer.writeln('    ${jsonEncode(keys[i])}: ${jsonEncode(values)}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}
