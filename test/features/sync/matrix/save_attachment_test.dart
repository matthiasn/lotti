import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

class MockMatrixFile extends Mock implements MatrixFile {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late Directory tempDir;
  late MockEvent mockEvent;
  late MockLoggingService mockLoggingService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('save_attachment_test');
    mockEvent = MockEvent();
    mockLoggingService = MockLoggingService();

    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('saves attachment to documents directory and logs success', () async {
    final matrixFile = MockMatrixFile();
    final bytes = Uint8List.fromList([1, 2, 3]);

    when(() => mockEvent.attachmentMimetype).thenReturn('image/png');
    when(() => mockEvent.content)
        .thenReturn({'relativePath': '/matrix/file.bin'});
    when(() => mockEvent.downloadAndDecryptAttachment())
        .thenAnswer((_) async => matrixFile);
    when(() => matrixFile.bytes).thenReturn(bytes);

    final wrote = await saveAttachment(
      mockEvent,
      loggingService: mockLoggingService,
      documentsDirectory: tempDir,
    );

    final outputFile = File('${tempDir.path}/matrix/file.bin');
    expect(outputFile.existsSync(), isTrue);
    expect(await outputFile.readAsBytes(), bytes);

    verify(
      () => mockLoggingService.captureEvent(
        'downloading /matrix/file.bin',
        domain: 'MATRIX_SERVICE',
        subDomain: 'writeToFile',
      ),
    ).called(1);
    verify(
      () => mockLoggingService.captureEvent(
        'wrote file /matrix/file.bin',
        domain: 'MATRIX_SERVICE',
        subDomain: 'saveAttachment',
      ),
    ).called(1);
    expect(wrote, isTrue);
  });

  test('captures exception when download fails', () async {
    when(() => mockEvent.attachmentMimetype).thenReturn('application/pdf');
    when(() => mockEvent.content)
        .thenReturn({'relativePath': '/matrix/failure.bin'});
    when(() => mockEvent.downloadAndDecryptAttachment())
        .thenThrow(const FileSystemException('permission denied'));

    final wrote = await saveAttachment(
      mockEvent,
      loggingService: mockLoggingService,
      documentsDirectory: tempDir,
    );

    verify(
      () => mockLoggingService.captureException(
        'failed to save attachment application/pdf /matrix/failure.bin',
        domain: 'MATRIX_SERVICE',
        subDomain: 'saveAttachment',
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).called(1);
    expect(wrote, isFalse);
  });
}
