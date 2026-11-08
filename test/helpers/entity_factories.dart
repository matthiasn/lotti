import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';

// The demo seed's entity factories, plus the ones only tests use.
export 'package:lotti/features/demo/seed/demo_entity_factories.dart';

/// Factory for creating [ProjectEntry] instances in tests.
///
/// ```dart
/// final project = TestProjectFactory.create(id: 'proj-1', title: 'Alpha');
/// ```
class TestProjectFactory {
  static ProjectEntry create({
    String id = 'test-project-1',
    String title = 'Test Project',
    String? categoryId,
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final date = createdAt ?? testFixedDate;
    return ProjectEntry(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: dateFrom ?? date,
        dateTo: dateTo ?? date,
        categoryId: categoryId,
      ),
      data: ProjectData(
        title: title,
        status: ProjectStatus.active(
          id: 'status-1',
          createdAt: date,
          utcOffset: 0,
        ),
        dateFrom: dateFrom ?? date,
        dateTo: dateTo ?? date,
      ),
    );
  }
}

/// Factory for creating [JournalImage] instances in tests.
///
/// ```dart
/// final image = TestImageFactory.create(id: 'img-1');
/// ```
class TestImageFactory {
  static JournalImage create({
    String id = 'test-image-1',
    String? plainText,
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final date = createdAt ?? testFixedDate;
    final from = dateFrom ?? date;
    return JournalImage(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: from,
        dateTo: dateTo ?? from,
      ),
      data: ImageData(
        capturedAt: from,
        imageId: 'image-id-$id',
        imageFile: '$id.jpg',
        imageDirectory: '/images/',
      ),
      entryText: plainText == null ? null : EntryText(plainText: plainText),
    );
  }
}

/// Factory for creating [AiResponseEntry] instances in tests — e.g. the image
/// analyses (summary/OCR) linked from an image entry.
///
/// ```dart
/// final ocr = TestAiResponseFactory.create(
///   id: 'ocr-1',
///   model: 'mistral-ocr-latest',
///   response: 'Datum: 05.10.2026',
/// );
/// ```
class TestAiResponseFactory {
  static AiResponseEntry create({
    String id = 'test-ai-response-1',
    String model = 'test-model',
    String response = 'Test analysis',
    AiResponseType? type = AiResponseType.imageAnalysis,
    DateTime? dateFrom,
    DateTime? deletedAt,
  }) {
    final date = dateFrom ?? testFixedDate;
    return AiResponseEntry(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: date,
        dateTo: date,
      ).copyWith(deletedAt: deletedAt),
      data: AiResponseData(
        model: model,
        systemMessage: 'system',
        prompt: 'prompt',
        thoughts: '',
        response: response,
        type: type,
      ),
    );
  }
}

/// Factory for creating [ChecklistItemData] instances in tests.
///
/// ```dart
/// final item = TestChecklistItemFactory.create(title: 'Buy milk');
/// ```
class TestChecklistItemFactory {
  static ChecklistItemData create({
    String title = 'Test Item',
    bool isChecked = false,
    List<String> linkedChecklists = const [],
    bool isArchived = false,
    String? id,
  }) {
    return ChecklistItemData(
      title: title,
      isChecked: isChecked,
      linkedChecklists: linkedChecklists,
      isArchived: isArchived,
      id: id,
    );
  }
}
