/// Deterministic manual captures for the production knowledge-graph workspace.
///
/// The fixture uses the same checksum-pinned R2 cover art as demo seeding. It
/// deliberately has no bundled fallback so a documentation run fails when the
/// published seed-media catalog is incomplete.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph/ui/knowledge_graph_view.dart';
import 'package:lotti/features/knowledge_graph/ui/task_knowledge_graph_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/image_utils.dart';

import '../../../helpers/manual_demo_world.dart';
import '../../daily_os_next/screenshot_harness.dart';

const _subdir = 'knowledge_graph';

TaskGraphData _graphData(
  ManualDemoWorld world,
  Directory documentsDirectory,
) {
  final entities = <String, JournalEntity>{
    for (final entity in <JournalEntity>[
      ...world.coverImages,
      ...world.checklistItems,
      ...world.checklists,
      ...world.tasks,
      ...world.timeRecords,
      ...world.entries,
    ])
      entity.id: entity,
  };
  final coverPathById = <String, String>{
    for (final image in world.coverImages)
      image.id: getFullImagePath(
        image,
        documentsDirectory: documentsDirectory.path,
      ),
  };

  final edges = <GraphEdge>[
    for (final link in world.links)
      if (entities.containsKey(link.fromId) && entities.containsKey(link.toId))
        GraphEdge(
          fromId: link.fromId,
          toId: link.toId,
          kind: edgeKindFor(
            link,
            entities[link.fromId]!,
            entities[link.toId]!,
          ),
        ),
    for (final task in world.tasks)
      for (final checklistId in task.data.checklistIds ?? const <String>[])
        if (entities.containsKey(checklistId))
          GraphEdge(
            fromId: task.id,
            toId: checklistId,
            kind: GraphEdgeKind.association,
          ),
    for (final checklist in world.checklists)
      for (final itemId in checklist.data.linkedChecklistItems)
        if (entities.containsKey(itemId))
          GraphEdge(
            fromId: checklist.id,
            toId: itemId,
            kind: GraphEdgeKind.checklist,
          ),
  ];

  final directImagePathsByTask = <String, List<String>>{};
  for (final edge in edges) {
    final from = entities[edge.fromId];
    final to = entities[edge.toId];
    if (from is Task && to is JournalImage) {
      directImagePathsByTask
          .putIfAbsent(from.id, () => <String>[])
          .add(coverPathById[to.id]!);
    } else if (to is Task && from is JournalImage) {
      directImagePathsByTask
          .putIfAbsent(to.id, () => <String>[])
          .add(coverPathById[from.id]!);
    }
  }

  final scenario = GraphScenario(
    name: graphNodeLabelFor(world.orbitalHabitatTask),
    seedId: world.orbitalHabitatTask.id,
    nodes: [
      for (final entity in entities.values)
        GraphNode(
          id: entity.id,
          type: graphNodeTypeFor(entity),
          label: graphNodeLabelFor(entity),
          categoryId: entity.categoryId ?? kUncategorized,
          createdAt: entity.meta.createdAt,
          imagePath: entity is JournalImage ? coverPathById[entity.id] : null,
          coverImagePath: entity is Task
              ? coverPathById[entity.data.coverArtId]
              : null,
          coverImageCropX: entity is Task ? entity.data.coverArtCropX : 0.5,
          taskStatus: entity is Task
              ? graphTaskStatusFor(entity.data.status)
              : null,
          mediaPaths: entity is Task
              ? <String>{
                  ?coverPathById[entity.data.coverArtId],
                  ...directImagePathsByTask[entity.id] ?? const <String>[],
                }.toList(growable: false)
              : const [],
        ),
    ],
    edges: edges,
    now: manualDemoNow,
  );

  return TaskGraphData(
    scenario: scenario,
    categoryColors: {
      for (final category in world.categories)
        if (category.color case final color? when color.isNotEmpty)
          category.id: categoryColorFromHex(color),
    },
    categoryNames: {
      for (final category in world.categories) category.id: category.name,
    },
    layout: computeLayoutForScenario(scenario),
  );
}

Widget _app({
  required TaskGraphData data,
  required ScreenshotDevice device,
  required Brightness brightness,
  required GraphImageLoader imageLoader,
}) => RepaintBoundary(
  key: screenshotBoundaryKey,
  child: ProviderScope(
    overrides: [
      taskGraphProvider(manualOrbitalHabitatTaskId).overrideWith(
        (ref) async => data,
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: device.size,
        disableAnimations: true,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark
            ? DesignSystemTheme.dark()
            : DesignSystemTheme.light(),
        locale: manualScreenshotLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TaskKnowledgeGraphPage(
          taskId: manualOrbitalHabitatTaskId,
          imageLoader: imageLoader,
        ),
      ),
    ),
  ),
);

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required TaskGraphData data,
  required ManualDemoWorld world,
  required Directory documentsDirectory,
  required ScreenshotDevice device,
  required Brightness brightness,
}) async {
  await primeManualDemoCoverArt(
    tester,
    documentsDirectory: documentsDirectory,
    world: world,
    // Inspector tiles are 224 logical px wide. Prime the explicit test
    // MediaQuery key plus the 2x desktop and 3x mobile device-ratio keys.
    extents: const [224, 448, 672],
    includeRawFileImage: true,
    includeExactResizeKeys: true,
  );
  final imagePaths = <String>{
    for (final node in data.scenario.nodes) ...[
      ?node.imagePath,
      ?node.coverImagePath,
      ...node.mediaPaths,
    ],
  };
  final decoded = <String, ui.Image>{};
  await tester.runAsync(() async {
    for (final path in imagePaths) {
      decoded[path] = await decodeGraphImageFile(path, 512);
    }
  });
  addTearDown(() {
    for (final image in decoded.values) {
      image.dispose();
    }
  });

  applyScreenshotDevice(tester, device);
  await tester.pumpWidget(
    _app(
      data: data,
      device: device,
      brightness: brightness,
      imageLoader: (path, _) async => decoded[path]!.clone(),
    ),
  );
  await settleFrames(tester, 24);
}

KnowledgeGraphPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(KnowledgeGraphView),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is KnowledgeGraphPainter,
      ),
    ),
  );
  return paint.painter! as KnowledgeGraphPainter;
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'knowledge-graph manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late ManualDemoWorld world;
  late Directory documentsDirectory;
  late TaskGraphData data;

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    documentsDirectory = Directory.systemTemp.createTempSync(
      'lotti-manual-knowledge-graph-',
    );
    final installed = await world.installMediaFromRemote(
      documentsDirectory,
      fetchUrl: fetchManualDemoSeedMedia,
    );
    await transcodeManualDemoMediaToPng(installed);
    data = _graphData(world, documentsDirectory);
  });

  tearDown(() async {
    if (documentsDirectory.existsSync()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  for (final device in [miniDevice, desktopDevice]) {
    final formFactor = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in Brightness.values) {
      final theme = brightness.name;

      testWidgets('$formFactor graph — $theme', (tester) async {
        await _pumpWorkspace(
          tester,
          data: data,
          world: world,
          documentsDirectory: documentsDirectory,
          device: device,
          brightness: brightness,
        );

        final painter = _painter(tester);
        expect(painter.scenario.nodes, isNotEmpty);
        expect(
          painter.scenario.nodeById(manualOrbitalHabitatTaskId).coverImagePath,
          isNotNull,
        );
        expect(painter.images, hasLength(manualDemoCoverMedia.length));

        await captureScreenshot(
          tester,
          'knowledge_graph_${formFactor}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$formFactor connections — $theme', (tester) async {
        await _pumpWorkspace(
          tester,
          data: data,
          world: world,
          documentsDirectory: documentsDirectory,
          device: device,
          brightness: brightness,
        );
        await tester.tap(
          find.byKey(const ValueKey('knowledge-graph-mode-connections')),
        );
        await settleFrames(tester);

        expect(
          find.byKey(const ValueKey('knowledge-graph-connections-list')),
          findsOneWidget,
        );
        expect(
          find.text(world.orbitalHabitatTask.data.title),
          findsWidgets,
        );

        await captureScreenshot(
          tester,
          'knowledge_graph_connections_${formFactor}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
