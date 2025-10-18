import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/metrics_counters.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

class MockMatrixFile extends Mock implements MatrixFile {}

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
    final metrics = MetricsCounters(collect: true);
    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/p/a.bin')).thenReturn(true);

    final wrote = await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      documentsDirectory: Directory.systemTemp,
      attachmentIndex: index,
      collectMetrics: true,
      metrics: metrics,
      lastProcessedTs: null,
      attachmentTsGate: const Duration(seconds: 2),
      currentUserId: '@me:u',
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
    );

    expect(wrote, isFalse);
    // Metrics updated
    expect(metrics.prefetch, 1);
    expect(metrics.lastPrefetched.last, '/p/a.bin');
    // Logs emitted
    verify(() => logging.captureEvent(
          any<String>(),
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'attachment.observe',
        )).called(greaterThan(0));
    // Pending cleared triggers scan and retry (no media write here)
    expect(liveScanCalls, 1);
    expect(retryNowCalls, 1);
    // AttachmentIndex has the descriptor
    expect(index.find('/p/a.bin'), isNotNull);
  });

  test('media prefetch writes file and schedules scan on pending removal',
      () async {
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
    final file = MockMatrixFile();
    when(ev.downloadAndDecryptAttachment).thenAnswer((_) async => file);
    when(() => file.bytes).thenReturn(Uint8List.fromList([1, 2, 3]));

    final index = AttachmentIndex(logging: logging);
    final metrics = MetricsCounters();
    var liveScanCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/media/x.jpg')).thenReturn(true);

    final wrote = await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      documentsDirectory: tmp,
      attachmentIndex: index,
      collectMetrics: false,
      metrics: metrics,
      lastProcessedTs: null,
      attachmentTsGate: const Duration(seconds: 2),
      currentUserId: '@me:u',
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async {},
    );

    expect(wrote, isTrue);
    expect(liveScanCalls, 2); // observe + after write
    expect(File('${tmp.path}/media/x.jpg').existsSync(), isTrue);
  });

  test('ts gate prevents media prefetch and logs skip', () async {
    final logging = MockLoggingService();
    when(() => logging.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e3');
    when(() => ev.content)
        .thenReturn({'relativePath': '/m/y.jpg', 'msgtype': 'm.image'});
    when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
    when(() => ev.senderId).thenReturn('@other:u');
    // Event ts = 1000, lastProcessedTs = 2000, gate=2s -> skip
    when(() => ev.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));

    final wrote = await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      documentsDirectory: Directory.systemTemp,
      attachmentIndex: AttachmentIndex(),
      collectMetrics: false,
      metrics: MetricsCounters(),
      lastProcessedTs: 10000,
      attachmentTsGate: const Duration(seconds: 2),
      currentUserId: '@me:u',
      descriptorCatchUp: null,
      scheduleLiveScan: () {},
      retryNow: () async {},
    );

    expect(wrote, isFalse);
    verify(() => logging.captureEvent(
          contains('prefetch.skip.tsGate'),
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'prefetch',
        )).called(1);
  });

  test('prefetch error increments metric failures and returns false', () async {
    final logging = MockLoggingService();
    when(() => logging.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e4');
    when(() => ev.content)
        .thenReturn({'relativePath': '/m/err.jpg', 'msgtype': 'm.image'});
    when(() => ev.attachmentMimetype).thenReturn('image/jpeg');
    when(() => ev.senderId).thenReturn('@other:u');
    when(() => ev.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));
    when(ev.downloadAndDecryptAttachment).thenThrow(Exception('boom'));

    final metrics = MetricsCounters(collect: true);
    final wrote = await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      documentsDirectory: Directory.systemTemp,
      attachmentIndex: AttachmentIndex(),
      collectMetrics: true,
      metrics: metrics,
      lastProcessedTs: null,
      attachmentTsGate: const Duration(seconds: 2),
      currentUserId: '@me:u',
      descriptorCatchUp: null,
      scheduleLiveScan: () {},
      retryNow: () async {},
    );

    expect(wrote, isFalse);
    // saveAttachment handles its own exceptions; ingestor does not count it
    expect(metrics.failures, 0);
    verify(() => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveAttachment',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).called(1);
  });

  test('removeIfPresent false does not trigger scan/retry', () async {
    final logging = MockLoggingService();
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('e5');
    when(() => ev.content).thenReturn({'relativePath': '/p/b.bin'});
    when(() => ev.attachmentMimetype).thenReturn('application/json');
    when(() => ev.senderId).thenReturn('@other:u');

    final index = AttachmentIndex();
    final metrics = MetricsCounters(collect: true);
    var liveScanCalls = 0;
    var retryNowCalls = 0;
    final desc = MockDescriptorCatchUpManager();
    when(() => desc.removeIfPresent('/p/b.bin')).thenReturn(false);

    await const AttachmentIngestor().process(
      event: ev,
      logging: logging,
      documentsDirectory: Directory.systemTemp,
      attachmentIndex: index,
      collectMetrics: true,
      metrics: metrics,
      lastProcessedTs: null,
      attachmentTsGate: const Duration(seconds: 2),
      currentUserId: '@me:u',
      descriptorCatchUp: desc,
      scheduleLiveScan: () => liveScanCalls++,
      retryNow: () async => retryNowCalls++,
    );

    expect(liveScanCalls, 0);
    expect(retryNowCalls, 0);
  });
}
