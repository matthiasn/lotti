import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/category_empty.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/empty_root.dart';
import 'package:lotti/features/settings_v2/ui/detail/leaf_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/settings_detail_pane.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

Future<void> _pumpPane(
  WidgetTester tester, {
  Map<String, bool> flags = const {},
  List<String> initialPath = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mocks = await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer((invocation) {
    final name = invocation.positionalArguments.first as String;
    return Stream.value(flags[name] ?? false);
  });

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Material(
        child: SizedBox(
          width: 1000,
          height: 800,
          child: SettingsDetailPane(),
        ),
      ),
      overrides: [
        journalDbProvider.overrideWithValue(mocks.journalDb),
        settingsTreePathProvider.overrideWith(
          () => _SeededTreePath(initialPath),
        ),
      ],
    ),
  );
  await tester.pump();
}

class _SeededTreePath extends SettingsTreePath {
  _SeededTreePath(this._seed);

  final List<String> _seed;

  @override
  List<String> build() => _seed;
}

void main() {
  group('SettingsDetailPane — empty path', () {
    testWidgets('dispatches to EmptyRoot when the tree path is empty', (
      tester,
    ) async {
      await _pumpPane(tester);
      expect(find.byType(EmptyRoot), findsOneWidget);
      expect(find.byType(CategoryEmpty), findsNothing);
      expect(find.byType(LeafPanel), findsNothing);
    });
  });

  group('SettingsDetailPane — branch selection', () {
    testWidgets('dispatches to CategoryEmpty when a branch is selected', (
      tester,
    ) async {
      await _pumpPane(
        tester,
        flags: {enableMatrixFlag: true},
        initialPath: ['sync'],
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CategoryEmpty), findsOneWidget);
      expect(find.byType(EmptyRoot), findsNothing);
    });
  });

  group('SettingsDetailPane — leaf selection', () {
    testWidgets(
      'dispatches to LeafPanel with DefaultPanel fallback for a leaf '
      'whose panel id is not yet registered',
      (tester) async {
        // `whats-new` is the only remaining tree leaf whose panel id
        // is not in `kSettingsPanels` — it lands in a later polish
        // step. Until then the dispatcher falls back through
        // [DefaultPanel], which is exactly the contract under test.
        await _pumpPane(
          tester,
          flags: {enableWhatsNewFlag: true},
          initialPath: ['whats-new'],
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(LeafPanel), findsOneWidget);
        expect(find.byType(DefaultPanel), findsOneWidget);
      },
    );
  });

  group('SettingsDetailPane — unknown id', () {
    testWidgets(
      'dispatches to EmptyRoot when the path references an id not in '
      'the current (flag-gated) tree',
      (tester) async {
        // Path wants sync/backfill but the Matrix flag is off, so
        // the tree has no sync/* nodes — the dispatcher must fall
        // back gracefully rather than crashing.
        await _pumpPane(
          tester,
          initialPath: ['sync', 'sync/backfill'],
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(EmptyRoot), findsOneWidget);
      },
    );
  });

  group('SettingsDetailPane — scope-provided index', () {
    testWidgets(
      'consumes the index published by SettingsTreeScope rather than '
      'rebuilding a fallback from the gating flags',
      (tester) async {
        // Build a deliberately-tiny tree the gating flags would never
        // produce (single custom leaf, no real ids). If the dispatcher
        // resolves the path against this scope-provided index, it will
        // render LeafPanel for the custom id; if it ignored the scope
        // and built its own fallback from the gating flags, the id
        // would be unknown and the dispatcher would land on EmptyRoot.
        const customLeaf = SettingsNode(
          id: 'custom-leaf',
          icon: Icons.star_rounded,
          title: 'Custom',
          desc: '',
          panel: 'custom-panel',
        );
        final scopeTree = <SettingsNode>[customLeaf];
        final scopeIndex = SettingsTreeIndex.build(scopeTree);

        final mocks = await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        when(() => mocks.journalDb.watchConfigFlag(any())).thenAnswer(
          (_) => Stream.value(false),
        );

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Material(
              child: SizedBox(
                width: 1000,
                height: 800,
                child: SettingsTreeScope(
                  tree: scopeTree,
                  index: scopeIndex,
                  child: const SettingsDetailPane(),
                ),
              ),
            ),
            overrides: [
              journalDbProvider.overrideWithValue(mocks.journalDb),
              settingsTreePathProvider.overrideWith(
                () => _SeededTreePath(['custom-leaf']),
              ),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(LeafPanel), findsOneWidget);
        expect(find.byType(EmptyRoot), findsNothing);
      },
    );
  });

  group('SettingsDetailPane — swap animation', () {
    testWidgets(
      'uses a FadeTransition inside an AnimatedSwitcher so the detail '
      'surface cross-fades between states',
      (tester) async {
        await _pumpPane(tester);
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
        // FadeTransition is emitted by the switcher's default
        // transitionBuilder — asserting the widget type is a proxy
        // for the "fade only, no slide" spec §10 rule.
        expect(find.byType(FadeTransition), findsWidgets);
      },
    );
  });
}
