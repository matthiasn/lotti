import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_image_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_task_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return id == 'test-category-id'
        ? CategoryDefinition(
            id: 'test-category-id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test Category',
            vectorClock: null,
            private: false,
            active: true,
            color: '#FF0000',
          )
        : null;
  }
}

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTimeService implements TimeService {
  JournalEntity? _linkedFrom;

  @override
  JournalEntity? get linkedFrom => _linkedFrom;

  @override
  Stream<JournalEntity?> getStream() {
    return Stream.value(null);
  }

  // Implement other required methods with default implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> tagsById = {};

  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

void main() {
  late JournalEntry testJournalEntry;
  late Task testTask;
  late JournalEvent testEvent;
  late JournalImage testImage;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockTagsService mockTagsService;
  late Directory mockDirectory;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockTagsService = MockTagsService();

    // Create and register mock directory for image tests
    final tempDir = Directory.systemTemp.createTempSync('card_wrapper_test');
    mockDirectory = tempDir;

    // Register mock services
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<Directory>(mockDirectory);

    // Create test data
    final now = DateTime.now();
    const categoryId = 'test-category-id';
    const entryId = 'test-entry-id';
    const taskId = 'test-task-id';
    const eventId = 'test-event-id';
    const imageId = 'test-image-id';

    // Create a journal entry for testing
    final metadata = Metadata(
      id: entryId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
      starred: true,
    );

    const entryText = EntryText(
      plainText: 'Test Journal Entry',
      markdown: 'Test Journal Entry',
    );

    testJournalEntry = JournalEntry(
      meta: metadata,
      entryText: entryText,
    );

    // Create a task for testing
    final taskMetadata = Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final taskStatus = TaskStatus.open(
      id: 'status-id',
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      statusHistory: [],
      title: 'Test Task Title',
    );

    testTask = Task(
      meta: taskMetadata,
      data: taskData,
      entryText: entryText,
    );

    // Create an event for testing
    final eventMetadata = Metadata(
      id: eventId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    const eventData = EventData(
      title: 'Test Event Title',
      status: EventStatus.tentative,
      stars: 3.5,
    );

    testEvent = JournalEvent(
      meta: eventMetadata,
      data: eventData,
      entryText: entryText,
    );

    // Create a journal image for testing
    final imageMetadata = Metadata(
      id: imageId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final imageData = ImageData(
      capturedAt: now,
      imageId: 'image-uuid',
      imageFile: 'test-image.jpg',
      imageDirectory: '/images/2023-01-01/',
    );

    testImage = JournalImage(
      meta: imageMetadata,
      data: imageData,
      entryText: entryText,
    );

    // Create directory structure for image
    Directory(
      p.join(mockDirectory.path, 'images', '2023-01-01'),
    ).createSync(recursive: true);

    // Create mock image file
    final filePath =
        p.join(mockDirectory.path, 'images', '2023-01-01', 'test-image.jpg');
    File(filePath).createSync();
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>()
      ..unregister<NavService>()
      ..unregister<TagsService>()
      ..unregister<Directory>();

    try {
      mockDirectory.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('CardWrapperWidget', () {
    testWidgets('renders ModernJournalImageCard for JournalImage entity',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: CardWrapperWidget(
            item: testImage,
            taskAsListView: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernJournalImageCard), findsOneWidget);
      expect(find.byType(ModernJournalCard), findsNothing);
      expect(find.byType(ModernTaskCard), findsNothing);
    });

    testWidgets('renders ModernTaskCard for Task when taskAsListView is true',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: CardWrapperWidget(
            item: testTask,
            taskAsListView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernTaskCard), findsOneWidget);
      expect(find.byType(ModernJournalCard), findsNothing);
      expect(find.byType(ModernJournalImageCard), findsNothing);
    });

    testWidgets('renders ModernJournalCard for Task when taskAsListView is false',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: CardWrapperWidget(
            item: testTask,
            taskAsListView: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(ModernTaskCard), findsNothing);
      expect(find.byType(ModernJournalImageCard), findsNothing);
    });

    testWidgets('renders ModernJournalCard for JournalEntry entity',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: CardWrapperWidget(
            item: testJournalEntry,
            taskAsListView: false, // value doesn't matter for non-Task types
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(ModernTaskCard), findsNothing);
      expect(find.byType(ModernJournalImageCard), findsNothing);
    });

    testWidgets('renders ModernJournalCard for JournalEvent entity',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: CardWrapperWidget(
            item: testEvent,
            taskAsListView: false, // value doesn't matter for non-Task types
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(ModernTaskCard), findsNothing);
      expect(find.byType(ModernJournalImageCard), findsNothing);
    });
  });
}
