import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_image_analysis.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_list_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockAiImageAnalysisController extends Mock
    implements AiImageAnalysisController {}

void main() {
  late JournalImage mockJournalImage;

  setUp(() {
    mockJournalImage = JournalImage(
      meta: Metadata(
        id: 'test-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
      data: ImageData(
        capturedAt: DateTime.now(),
        imageId: 'test-id',
        imageFile: 'test-file',
        imageDirectory: 'test/dir',
      ),
    );
  });

  testWidgets('renders correctly with expected elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestApp(
        ProviderScope(
          child: AiImageAnalysisListTile(
            journalImage: mockJournalImage,
          ),
        ),
      ),
    );

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.byIcon(Icons.assistant), findsOneWidget);
  });

  testWidgets('linkedFromId is optional', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestApp(
        ProviderScope(
          child: AiImageAnalysisListTile(
            journalImage: mockJournalImage,
            linkedFromId: 'linked-id',
          ),
        ),
      ),
    );

    expect(find.byType(ListTile), findsOneWidget);
  });
}
