import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/audio_transcription/audio_transcription_progress_list_tile.dart';

import '../../../../test_helper.dart';

void main() {
  late JournalAudio mockJournalAudio;

  setUp(() {
    mockJournalAudio = JournalAudio(
      meta: Metadata(
        id: 'test-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
      data: AudioData(
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        audioFile: 'test-file',
        audioDirectory: 'test/dir',
        duration: const Duration(minutes: 1),
      ),
    );
  });

  testWidgets('renders correctly with expected elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: ProviderScope(
          child: AudioTranscriptionProgressListTile(
            journalAudio: mockJournalAudio,
            onTap: () {},
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
      WidgetTestBench(
        child: ProviderScope(
          child: AudioTranscriptionProgressListTile(
            journalAudio: mockJournalAudio,
            linkedFromId: 'linked-id',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(ListTile), findsOneWidget);
  });
}
