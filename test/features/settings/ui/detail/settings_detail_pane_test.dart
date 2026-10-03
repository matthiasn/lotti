import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/domain/settings_tree_index.dart';
import 'package:lotti/features/settings/state/settings_tree_controller.dart';
import 'package:lotti/features/settings/ui/detail/category_empty.dart';
import 'package:lotti/features/settings/ui/detail/empty_root.dart';
import 'package:lotti/features/settings/ui/detail/leaf_panel.dart';
import 'package:lotti/features/settings/ui/detail/settings_detail_pane.dart';
import 'package:lotti/features/settings/ui/settings_tree_scope.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';
import '../../routing/test_route_table.dart';

Future<void> _pumpPane(
  WidgetTester tester, {
  Map<String, bool> flags = const {},
  List<String> initialPath = const [],
  bool guestProfile = false,
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
        if (guestProfile)
          profileContextProvider.overrideWithValue(
            ProfileContext.forProfile(
              profile: Profile(
                id: 'demo-guest',
                type: ProfileType.guest,
                name: 'Demo',
                dirName: 'guest_profiles/demo-guest',
                createdAt: DateTime(2026),
              ),
              root: Directory.systemTemp,
            ),
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
    testWidgets(
      'dispatches to CategoryEmpty when a pure branch (no landing panel) '
      'is selected',
      (tester) async {
        // `advanced`, `definitions`, and `sync` are pure branches without
        // their own landing panel — only `ai` and `agents` carry one and
        // fall through to the LeafPanel dispatch.
        await _pumpPane(
          tester,
          initialPath: ['advanced'],
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(CategoryEmpty), findsOneWidget);
        expect(find.byType(EmptyRoot), findsNothing);
      },
    );

    testWidgets(
      'leaves the detail pane empty when the Sync branch itself is selected '
      '(its provisioned-sync entry is a leaf, not a branch panel)',
      (tester) async {
        await _pumpPane(
          tester,
          flags: {enableMatrixFlag: true},
          initialPath: ['sync'],
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(CategoryEmpty), findsOneWidget);
        expect(find.byType(LeafPanel), findsNothing);
      },
    );

    testWidgets(
      'guest world: a stale sync leaf path falls back to EmptyRoot — '
      'no sync panel is ever mounted against the absent Matrix stack',
      (tester) async {
        // A deep link / persisted path pointing at a sync leaf. In a guest
        // world the tree carries no sync ids at all (only the inert
        // explainer tile), so the pane must dispatch to EmptyRoot instead
        // of a LeafPanel whose body would resolve matrixServiceProvider.
        await _pumpPane(
          tester,
          flags: {enableMatrixFlag: true},
          initialPath: ['sync', 'sync/outbox'],
          guestProfile: true,
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(EmptyRoot), findsOneWidget);
        expect(find.byType(LeafPanel), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SettingsDetailPane — panel dispatch from the route registry', () {
    // A scope tree shaped like the fake route table, so the dispatch reads
    // real registry entries without a real page's provider graph.
    SettingsNode node(String id, {List<SettingsNode>? children}) =>
        SettingsNode(
          id: id,
          icon: LottiIcons.star,
          title: 'title:$id',
          desc: '',
          children: children,
        );
    final scopeTree = [
      node('hub', children: [node('hub/list')]),
      node('section', children: [node('section/tab')]),
      node('inert'),
    ];

    Future<void> pumpAt(WidgetTester tester, List<String> path) async {
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);
      when(
        () => mocks.journalDb.watchConfigFlag(any()),
      ).thenAnswer((_) => Stream.value(false));
      final route = ValueNotifier<DesktopSettingsRoute?>(null);
      addTearDown(route.dispose);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Material(
            child: SizedBox(
              width: 1000,
              height: 800,
              child: SettingsTreeScope(
                tree: scopeTree,
                index: SettingsTreeIndex.build(scopeTree),
                child: SettingsDetailPane(
                  table: testRouteTable(),
                  listenable: route,
                ),
              ),
            ),
          ),
          overrides: [
            journalDbProvider.overrideWithValue(mocks.journalDb),
            settingsTreePathProvider.overrideWith(() => _SeededTreePath(path)),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('a leaf with a panel mounts its body in a LeafPanel', (
      tester,
    ) async {
      await pumpAt(tester, ['hub', 'hub/list']);
      expect(find.byType(LeafPanel), findsOneWidget);
      expect(find.text('panel:list:0'), findsOneWidget);
    });

    testWidgets('a branch with a landing panel shows that panel, not the '
        '"pick a section" hint', (tester) async {
      await pumpAt(tester, ['section']);
      expect(find.text('panel:section'), findsOneWidget);
      expect(find.byType(CategoryEmpty), findsNothing);
    });

    testWidgets('a branch without a panel shows the hint', (tester) async {
      await pumpAt(tester, ['hub']);
      expect(find.byType(CategoryEmpty), findsOneWidget);
      expect(find.text('title:hub'), findsOneWidget);
    });

    testWidgets('a leaf with no panel on this platform shows the empty root '
        'rather than a blank or placeholder body', (tester) async {
      await pumpAt(tester, ['inert']);
      expect(find.byType(EmptyRoot), findsOneWidget);
      expect(find.byType(LeafPanel), findsNothing);
    });
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
        // A deliberately tiny tree the gating flags would never produce.
        // The registry-dispatch group above proves the scope's index is
        // what resolves a path to a panel.
        const customLeaf = SettingsNode(
          id: 'custom-leaf',
          icon: LottiIcons.star,
          title: 'Custom',
          desc: '',
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

        // `custom-leaf` is in the scope's index but has no route, so the
        // pane resolves it (no crash, no fallback tree) and shows the empty
        // root for a leaf without a panel.
        expect(find.byType(EmptyRoot), findsOneWidget);
        expect(find.byType(LeafPanel), findsNothing);
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
