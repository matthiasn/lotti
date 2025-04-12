import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../../../test_helper.dart';

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTagsService extends Mock implements TagsService {
  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return null;
  }
}

void main() {
  late JournalImage testImage;
  late Directory mockDirectory;
  late MockNavService mockNavService;
  late MockTagsService mockTagsService;
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create mock directory for CardImageWidget
    final tempDir =
        Directory.systemTemp.createTempSync('journal_image_card_test');
    mockDirectory = tempDir;

    // Create and register mock services
    mockNavService = MockNavService();
    mockTagsService = MockTagsService();
    mockEntitiesCacheService = MockEntitiesCacheService();

    // Register mocks with GetIt
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<Directory>(mockDirectory)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

    // Create test data
    final now = DateTime.now();
    testImage = JournalImage(
      meta: Metadata(
        id: 'test-image-id',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        capturedAt: now,
        imageId: 'test-image-id',
        imageFile: 'test_image.jpg',
        imageDirectory: '/images/2023/',
      ),
      entryText: const EntryText(plainText: 'Test image'),
    );

    // Create the directory structure and file needed by CardImageWidget
    Directory(
      p.join(
        mockDirectory.path,
        testImage.data.imageDirectory.replaceFirst('/', ''),
      ),
    ).createSync(recursive: true);

    // Create an empty file to make existsSync() return true
    final filePath = p
        .join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
          testImage.data.imageFile,
        )
        .replaceAll(r'\', '/');

    File(filePath).createSync();
  });

  tearDown(() {
    // Clean up
    getIt
      ..unregister<Directory>()
      ..unregister<NavService>()
      ..unregister<TagsService>()
      ..unregister<EntitiesCacheService>();
    try {
      mockDirectory.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('JournalImageCard', () {
    testWidgets('renders correctly for non-deleted items',
        (WidgetTester tester) async {
      // Build the actual widget
      await tester.pumpWidget(
        WidgetTestBench(
          child: JournalImageCard(item: testImage),
        ),
      );
      await tester.pumpAndSettle();

      // Verify correct widget structure
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(CardImageWidget), findsOneWidget);
      expect(find.byType(JournalCardTitle), findsOneWidget);

      // Verify CardImageWidget has correct parameters
      final cardImageWidget =
          tester.widget<CardImageWidget>(find.byType(CardImageWidget));
      expect(cardImageWidget.journalImage, equals(testImage));
      expect(cardImageWidget.height, equals(160));
      expect(cardImageWidget.fit, equals(BoxFit.cover));
    });

    testWidgets('returns SizedBox.shrink for deleted items',
        (WidgetTester tester) async {
      // Create a deleted test image
      final deletedTestImage = JournalImage(
        meta: Metadata(
          id: 'deleted-test-id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          deletedAt: DateTime.now(), // Mark as deleted
        ),
        data: testImage.data,
        entryText: testImage.entryText,
      );

      // Build the actual widget with deleted item
      await tester.pumpWidget(
        WidgetTestBench(
          child: JournalImageCard(item: deletedTestImage),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it returns a SizedBox.shrink for deleted items
      expect(find.byType(SizedBox), findsOneWidget);

      // Verify no other widgets from the normal rendering are visible
      expect(find.byType(Card), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(CardImageWidget), findsNothing);
    });

    testWidgets('navigates to correct route on tap',
        (WidgetTester tester) async {
      // Build the actual widget
      await tester.pumpWidget(
        WidgetTestBench(
          child: JournalImageCard(item: testImage),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the ListTile
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify navigation was called with correct route
      expect(
        mockNavService.navigationHistory,
        contains('/journal/${testImage.meta.id}'),
      );
    });

    testWidgets('uses LimitedBox with correct constraints',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: JournalImageCard(item: testImage),
        ),
      );
      await tester.pumpAndSettle();

      // Find the specific LimitedBox we want to test (the one that contains the CardImageWidget)
      final limitedBox = tester.widget<LimitedBox>(
        find.ancestor(
          of: find.byType(CardImageWidget),
          matching: find.byType(LimitedBox),
        ),
      );

      // Verify LimitedBox has correct constraints
      expect(limitedBox.maxHeight, equals(160));
    });
  });
}
