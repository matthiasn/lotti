import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  test('record and find works with and without leading slash', () {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final e = MockEvent();
    when(() => e.attachmentMimetype).thenReturn('image/jpeg');
    when(() => e.content).thenReturn({'relativePath': 'images/a.jpg'});
    when(() => e.eventId).thenReturn('ev1');

    index.record(e);

    // Hit with slash
    final hit1 = index.find('/images/a.jpg');
    expect(hit1, isNotNull);
    // Hit without slash
    final hit2 = index.find('images/a.jpg');
    expect(hit2, isNotNull);

    // Miss logs a miss
    final miss = index.find('/images/missing.jpg');
    expect(miss, isNull);
    verify(() => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachmentIndex.find',
        )).called(greaterThanOrEqualTo(1));
  });
}
