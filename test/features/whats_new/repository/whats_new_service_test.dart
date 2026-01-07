import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/repository/whats_new_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockHttpClient;
  late MockLoggingService mockLoggingService;
  late WhatsNewService service;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockLoggingService = MockLoggingService();

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    when(() => mockLoggingService.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        )).thenReturn(null);

    service = WhatsNewService(httpClient: mockHttpClient);
  });

  tearDown(getIt.reset);

  group('WhatsNewService', () {
    group('fetchIndex', () {
      test('returns list of releases when response is successful', () async {
        final indexJson = {
          'releases': [
            {
              'version': '0.9.980',
              'date': '2026-01-07T00:00:00.000',
              'title': 'January Update',
              'folder': '0.9.980',
            },
            {
              'version': '0.9.970',
              'date': '2025-12-15T00:00:00.000',
              'title': 'December Update',
              'folder': '0.9.970',
            },
          ],
        };

        when(() => mockHttpClient.get(
              Uri.parse('${WhatsNewService.baseUrl}/index.json'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(indexJson),
              200,
            ));

        final releases = await service.fetchIndex();

        expect(releases, isNotNull);
        expect(releases, hasLength(2));
        // Should be sorted by date descending
        expect(releases![0].version, equals('0.9.980'));
        expect(releases[1].version, equals('0.9.970'));
      });

      test('returns null when response status is not 200', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Not Found', 404));

        final releases = await service.fetchIndex();

        expect(releases, isNull);
      });

      test('returns null when releases key is missing', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'other': 'data'}),
              200,
            ));

        final releases = await service.fetchIndex();

        expect(releases, isNull);
      });

      test('returns null and logs error on exception', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Network error'));

        final releases = await service.fetchIndex();

        expect(releases, isNull);
        verify(() => mockLoggingService.captureException(
              any<Object>(),
              domain: 'WHATS_NEW',
              subDomain: 'fetchIndex',
            )).called(1);
      });

      test('returns null on malformed JSON', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              'Invalid JSON {[}',
              200,
            ));

        final releases = await service.fetchIndex();

        expect(releases, isNull);
        verify(() => mockLoggingService.captureException(
              any<Object>(),
              domain: 'WHATS_NEW',
              subDomain: 'fetchIndex',
            )).called(1);
      });

      test('returns empty list when releases array is empty', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'releases': <dynamic>[]}),
              200,
            ));

        final releases = await service.fetchIndex();

        expect(releases, isNotNull);
        expect(releases, isEmpty);
      });
    });

    group('fetchContent', () {
      test('returns parsed content when response is successful', () async {
        const markdownContent = '''
# January Update
*Released: January 7, 2026*

---

## New Feature

This is a great new feature.

---

## Bug Fixes

Fixed some bugs.
''';

        when(() => mockHttpClient.get(
              Uri.parse('${WhatsNewService.baseUrl}/0.9.980/content.md'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              markdownContent,
              200,
            ));

        final release = _createRelease('0.9.980');
        final content = await service.fetchContent(release);

        expect(content, isNotNull);
        expect(content!.release.version, equals('0.9.980'));
        expect(content.headerMarkdown, contains('January Update'));
        expect(content.sections, hasLength(2));
        expect(content.sections[0], contains('New Feature'));
        expect(content.sections[1], contains('Bug Fixes'));
        expect(
          content.bannerImageUrl,
          equals('${WhatsNewService.baseUrl}/0.9.980/banner.jpg'),
        );
      });

      test('returns null when response status is not 200', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Not Found', 404));

        final release = _createRelease('0.9.980');
        final content = await service.fetchContent(release);

        expect(content, isNull);
      });

      test('returns null and logs error on exception', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Network error'));

        final release = _createRelease('0.9.980');
        final content = await service.fetchContent(release);

        expect(content, isNull);
        verify(() => mockLoggingService.captureException(
              any<Object>(),
              domain: 'WHATS_NEW',
              subDomain: 'fetchContent',
            )).called(1);
      });
    });
  });
}

/// Helper to create a test release.
WhatsNewRelease _createRelease(String version) {
  return WhatsNewRelease(
    version: version,
    date: DateTime(2026, 1, 7),
    title: 'Test Update',
    folder: version,
  );
}
