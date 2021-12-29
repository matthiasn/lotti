import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:research_package/model.dart';

void main() {
  DateTime dt = DateTime.fromMillisecondsSinceEpoch(1638265606966);

  Metadata testMeta = Metadata(
    createdAt: dt,
    id: 'test-id',
    dateTo: dt,
    dateFrom: dt,
    updatedAt: dt,
  );

  test('JSON file name for journal entry should be correct', () async {
    JournalEntity testEntity = JournalEntity.journalEntry(
      meta: testMeta,
      entryText: EntryText(plainText: 'test'),
    );

    final String path = entityPath(testEntity, Directory(''));
    expect(path, '/text_entries/2021-11-30/test-id.text.json');
  });

  test('JSON file name for survey entry should be correct', () async {
    JournalEntity testEntity = JournalEntity.survey(
      meta: testMeta,
      data: SurveyData(
        scoreDefinitions: {},
        calculatedScores: {},
        taskResult: RPTaskResult(identifier: ''),
      ),
    );

    final String path = entityPath(testEntity, Directory(''));
    expect(path, '/surveys/2021-11-30/test-id.survey.json');
  });

  test('JSON file name for quantitative entry should be correct', () async {
    JournalEntity testEntity = JournalEntity.quantitative(
      meta: testMeta,
      data: QuantitativeData.cumulativeQuantityData(
        dateFrom: dt,
        dateTo: dt,
        value: 1,
        dataType: 'dataType',
        unit: 'unit',
      ),
    );

    final String path = entityPath(testEntity, Directory(''));
    expect(path, '/quantitative/2021-11-30/test-id.quantitative.json');
  });

  test('JSON file name for image entry should be correct', () async {
    JournalEntity testEntity = JournalEntity.journalImage(
      meta: testMeta,
      data: ImageData(
        imageFile: 'some-image-id.IMG_9999.JPG',
        imageId: '',
        capturedAt: dt,
        imageDirectory: '/images/2021-11-29/',
      ),
    );

    final String path = entityPath(testEntity, Directory(''));
    expect(path, '/images/2021-11-29/some-image-id.IMG_9999.JPG.json');
  });

  test('JSON file name for image entry should be correct', () async {
    JournalEntity testEntity = JournalEntity.journalAudio(
      meta: testMeta,
      data: AudioData(
        audioDirectory: '/audio/2021-11-29/',
        dateFrom: dt,
        dateTo: dt,
        duration: const Duration(seconds: 1),
        audioFile: '2021-11-29_20-35-12-957.aac',
      ),
    );

    final String path = entityPath(testEntity, Directory(''));
    expect(path, '/audio/2021-11-29/2021-11-29_20-35-12-957.aac.json');
  });
}
