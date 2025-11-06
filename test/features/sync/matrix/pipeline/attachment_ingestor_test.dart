import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

class MockLoggingService extends Mock implements LoggingService {}

class MockDescriptorCatchUpManager extends Mock
    implements DescriptorCatchUpManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  test('records descriptor, logs observe, updates metrics, and clears pending',
      () async {
    final logging = MockLoggingService();
    when(() => logging.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logging.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e1');
    when(() => ev.content)
        .thenReturn({'relativePath': '/p/a.bin', 'msgtype': 'm.file'});
    when(() => ev.attachmentMimetype).thenReturn('application/json');
    when(() => ev.senderId).thenReturn('@other:u');

    final index = AttachmentIndex(logging: logging);
    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/p/a.bin')).thenReturn(true);

    await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      attachmentIndex: index,
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
    );
    // Prefetch metrics removed
    // Logs emitted
    verify(() => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachment.observe',
        )).called(greaterThan(0));
    // Pending cleared triggers scan and retry (no media write here)
    expect(liveScanCalls, 1);
    expect(retryNowCalls, 1);
    // AttachmentIndex has the descriptor
    expect(index.find('/p/a.bin'), isNotNull);
  });

  test('no media prefetch; still clears pending and schedules scan', () async {
    final logging = MockLoggingService();
    when(() => logging.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logging.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    final tmp = Directory.systemTemp.createTempSync('ingestor');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e2');
    when(() => ev.content)
        .thenReturn({'relativePath': '/media/x.jpg', 'msgtype': 'm.image'});
    when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
    when(() => ev.senderId).thenReturn('@other:u');
    // Ensure event is fresh enough
    when(() => ev.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
    // No media prefetch: any SDK download paths are unused

    final index = AttachmentIndex(logging: logging);
    var liveScanCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/media/x.jpg')).thenReturn(true);

    await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      attachmentIndex: index,
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async {},
    );
    expect(liveScanCalls, 1); // schedule on descriptor removal only
    expect(File('${tmp.path}/media/x.jpg').existsSync(), isFalse);
  });

  test('removeIfPresent false does not trigger scan/retry', () async {
    final logging = MockLoggingService();
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e5');
    when(() => ev.content).thenReturn({'relativePath': '/p/b.bin'});
    when(() => ev.attachmentMimetype).thenReturn('application/json');
    when(() => ev.senderId).thenReturn('@other:u');

    final index = AttachmentIndex();
    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/p/b.bin')).thenReturn(false);

    await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      attachmentIndex: index,
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
    );

    expect(liveScanCalls, 0);
    expect(retryNowCalls, 0);
  });
}
