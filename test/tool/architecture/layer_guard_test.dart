import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package.
import '../../../tool/architecture/layer_guard.dart';

String imports(List<String> paths) =>
    paths.map((p) => "import 'package:lotti/$p';").join('\n');

LayerResult scanFixture(
  Map<String, String> files, {
  Map<String, Set<String>> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('layer_guard');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final entry in files.entries) {
    File('${root.path}/${entry.key}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return scan(
    root: Directory('${root.path}/lib'),
    baseline: baseline,
    repoRoot: root.path,
  );
}

void main() {
  group('rankOf', () {
    test('features rank by featureOrder; foundation below, shell above', () {
      expect(
        rankOf('lib/features/agents/model/x.dart'),
        featureOrder.indexOf('agents'),
      );
      expect(rankOf('lib/classes/task.dart'), -1);
      expect(
        rankOf('lib/widgets/a.dart'),
        featureOrder.indexOf('design_system'),
      );
      expect(rankOf('lib/beamer/beamer_app.dart'), featureOrder.length);
      expect(rankOf('lib/get_it.dart'), featureOrder.length);
    });

    test('an unknown feature or top-level path has no rank', () {
      expect(rankOf('lib/features/brand_new/x.dart'), isNull);
      expect(rankOf('lib/somewhere_new/x.dart'), isNull);
    });
  });

  group('violationsIn', () {
    test('a feature may import itself and features ranked below it', () {
      expect(
        violationsIn(
          'lib/features/agents/state/a.dart',
          imports([
            'features/agents/model/b.dart',
            'features/ai/repository/c.dart',
            'features/design_system/components/d.dart',
          ]),
        ),
        isEmpty,
      );
    });

    test('importing a feature ranked above is an upward break', () {
      expect(
        violationsIn(
          'lib/features/ai/state/a.dart',
          imports(['features/agents/model/b.dart']),
        ),
        {'agents'},
      );
    });

    test('foundation code may import no feature at all', () {
      expect(
        violationsIn(
          'lib/classes/a.dart',
          imports(['features/design_system/tokens.dart']),
        ),
        {'design_system'},
      );
    });

    test('shared UI may use the design system but no domain feature', () {
      expect(
        violationsIn(
          'lib/widgets/a.dart',
          imports([
            'features/design_system/components/b.dart',
            'features/journal/state/c.dart',
          ]),
        ),
        {'journal'},
      );
    });

    test("non-UI code reaching another feature's UI breaks the order", () {
      expect(
        violationsIn(
          'lib/features/onboarding/state/a.dart',
          imports(['features/categories/ui/picker.dart']),
        ),
        {'categories:ui'},
      );
      // UI importing UI below it is ordinary composition.
      expect(
        violationsIn(
          'lib/features/onboarding/ui/a.dart',
          imports(['features/categories/ui/picker.dart']),
        ),
        isEmpty,
      );
    });

    test('every configured URI of a conditional import counts', () {
      expect(
        violationsIn(
          'lib/features/ai/a.dart',
          "import 'package:lotti/features/ai/stub.dart'\n"
              "    if (dart.library.io) 'package:lotti/features/agents/impl.dart'\n"
              "    if (dart.library.js_interop) 'package:lotti/features/sync/web.dart';",
        ),
        {'agents', 'sync'},
      );
    });

    test('the shell may import anything', () {
      expect(
        violationsIn(
          'lib/beamer/a.dart',
          imports(['features/backup_restore/ui/page.dart']),
        ),
        isEmpty,
      );
    });

    test('reaching up into the shell breaks the order, from any layer', () {
      for (final path in [
        'lib/services/a.dart',
        'lib/widgets/a.dart',
        'lib/features/backup_restore/service/a.dart',
      ]) {
        expect(
          violationsIn(
            path,
            imports(['beamer/beamer_delegates.dart', 'app_bootstrap.dart']),
          ),
          {'shell'},
          reason: path,
        );
      }
    });

    test('the service locator is exempt: tool/di counts its lookups', () {
      expect(
        violationsIn('lib/classes/a.dart', imports(['get_it.dart'])),
        isEmpty,
      );
      // Only the locator itself: its helpers are composition-root code.
      expect(
        violationsIn('lib/classes/a.dart', imports(['get_it_helpers.dart'])),
        {'shell'},
      );
    });

    test('foundation may not use shared UI; features above it may', () {
      expect(
        violationsIn('lib/classes/a.dart', imports(['themes/colors.dart'])),
        {'shared_ui'},
      );
      expect(
        violationsIn(
          'lib/features/journal/state/a.dart',
          imports(['themes/colors.dart', 'utils/b.dart']),
        ),
        isEmpty,
      );
    });

    test('exports count, and comments or strings do not', () {
      expect(
        violationsIn(
          'lib/features/ai/a.dart',
          "export 'package:lotti/features/agents/b.dart';\n"
              "// import 'package:lotti/features/sync/c.dart';\n"
              "const s = \"import 'package:lotti/features/tasks/d.dart';\";",
        ),
        {'agents'},
      );
    });
  });

  group('scan', () {
    const upward = {
      'lib/features/ai/a.dart':
          "import 'package:lotti/features/agents/b.dart';",
    };

    test('a break the baseline lists passes; a new one is reported', () {
      final listed = scanFixture(
        upward,
        baseline: {
          'lib/features/ai/a.dart': {'agents'},
        },
      );
      expect(listed.added, isEmpty);
      expect(listed.removed, isEmpty);

      final fresh = scanFixture(upward);
      expect(fresh.added, {
        'lib/features/ai/a.dart': {'agents'},
      });
    });

    test('a baseline entry whose import is gone must be removed', () {
      final result = scanFixture(
        {'lib/features/ai/a.dart': ''},
        baseline: {
          'lib/features/ai/a.dart': {'agents'},
        },
      );
      expect(result.removed, {
        'lib/features/ai/a.dart': {'agents'},
      });
    });

    test('a file without a rank is reported, generated files are skipped', () {
      final result = scanFixture({
        'lib/features/brand_new/a.dart': '',
        'lib/features/ai/a.g.dart':
            "import 'package:lotti/features/agents/b.dart';",
      });
      expect(result.unranked, ['brand_new']);
      expect(result.current, isEmpty);
    });
  });

  test('the baseline round-trips deterministically', () {
    final current = {
      'lib/b.dart': {'sync', 'agents'},
      'lib/a.dart': {'tasks:ui'},
    };
    final file = File(
      '${Directory.systemTemp.createTempSync('layer_baseline').path}/b.json',
    )..writeAsStringSync(encodeBaseline(current));
    addTearDown(() => file.parent.deleteSync(recursive: true));

    expect(readBaseline(file), current);
    expect(encodeBaseline(readBaseline(file)), encodeBaseline(current));
    expect(file.readAsStringSync(), isNot(contains('_total')));
  });

  test('every feature directory has a rank', () {
    final features = Directory('lib/features')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
        .toSet();
    expect(features.difference(featureOrder.toSet()), isEmpty);
    expect(featureOrder.toSet().difference(features), isEmpty);
  });
}
