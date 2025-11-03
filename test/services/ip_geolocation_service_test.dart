import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import '../test_utils/retry_fake_time.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeUri extends Fake implements Uri {}

class FakeException extends Fake implements Exception {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeException());
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockHttpClient = MockHttpClient();

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Stub captureException to prevent errors in tests
    when(() => mockLoggingService.captureException(
          any<Exception>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
  });

  tearDown(getIt.reset);

  group('IpGeolocationService', () {
    group('getLocationFromIp', () {
      test('returns Geolocation when ipapi.co responds successfully', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 37.7749,
                'longitude': -122.4194,
                'timezone': 'America/Los_Angeles',
                'utc_offset': '-0800',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNotNull);
        expect(result!.latitude, 37.7749);
        expect(result.longitude, -122.4194);
        expect(result.timezone, 'America/Los_Angeles');
        expect(result.utcOffset, -480); // -8 hours in minutes
        expect(result.accuracy, 50000); // IP location accuracy
        expect(result.geohashString, isNotEmpty);
      });

      test('falls back to ip-api.com when ipapi.co fails', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Error', 500));

        when(() => mockHttpClient.get(
              Uri.parse('https://ip-api.com/json'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'status': 'success',
                'lat': 51.5074,
                'lon': -0.1278,
                'timezone': 'Europe/London',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNotNull);
        expect(result!.latitude, 51.5074);
        expect(result.longitude, -0.1278);
        expect(result.timezone, 'Europe/London');
        expect(result.accuracy, 50000);
        expect(result.geohashString, isNotEmpty);
      });

      test('returns null when both services fail', () async {
        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Error', 500));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNull);
      });

      test('handles timeout gracefully', () {
        fakeAsync((async) {
          when(() => mockHttpClient.get(
                any(),
                headers: any(named: 'headers'),
              )).thenAnswer((_) async {
            // Exceed the 10s timeout to deterministically trigger onTimeout
            await Future<void>.delayed(const Duration(seconds: 11));
            return http.Response('Timeout', 200);
          });

          Geolocation? result;
          // Kick off under fake time.
          IpGeolocationService.getLocationFromIp(httpClient: mockHttpClient)
              .then((r) => result = r);

          // Elapse timeout + epsilon via the retry helper (single attempt)
          final plan = buildRetryBackoffPlan(
            maxRetries: 1,
            timeout: const Duration(seconds: 10),
            baseDelay: Duration.zero,
            epsilon: const Duration(seconds: 1),
          );
          async.elapseRetryPlan(plan);

          expect(result, isNull);
        });
      });

      test('handles malformed JSON response', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Invalid JSON {[}]', 200));

        when(() => mockHttpClient.get(
              Uri.parse('https://ip-api.com/json'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Also invalid JSON', 200));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNull);

        verify(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: 'IP_GEOLOCATION',
              subDomain: any<String>(named: 'subDomain'),
            )).called(2);
      });

      test('handles missing location data in response', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'timezone': 'America/Los_Angeles',
                'utc_offset': '-0800',
              }),
              200,
            ));

        when(() => mockHttpClient.get(
              Uri.parse('https://ip-api.com/json'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'status': 'success',
                'timezone': 'Europe/London',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNull);
      });

      test('handles various UTC offset formats correctly', () async {
        final testCases = [
          ('+0530', 330), // India
          ('-0430', -270), // Venezuela
          ('+0000', 0), // UTC
          ('+1200', 720), // New Zealand
          ('-1100', -660), // Samoa
          ('+0045', 45), // Nepal (45 minutes)
        ];

        for (final testCase in testCases) {
          when(() => mockHttpClient.get(
                Uri.parse('https://ipapi.co/json/'),
                headers: any(named: 'headers'),
              )).thenAnswer((_) async => http.Response(
                json.encode({
                  'latitude': 0.0,
                  'longitude': 0.0,
                  'utc_offset': testCase.$1,
                }),
                200,
              ));

          final result = await IpGeolocationService.getLocationFromIp(
              httpClient: mockHttpClient);

          expect(result, isNotNull);
          expect(result!.utcOffset, testCase.$2,
              reason: 'Failed for offset ${testCase.$1}');
        }
      });

      test('handles invalid UTC offset formats gracefully', () async {
        final invalidOffsets = ['invalid', '12', '+12', '-12'];

        for (final offset in invalidOffsets) {
          when(() => mockHttpClient.get(
                Uri.parse('https://ipapi.co/json/'),
                headers: any(named: 'headers'),
              )).thenAnswer((_) async => http.Response(
                json.encode({
                  'latitude': 0.0,
                  'longitude': 0.0,
                  'utc_offset': offset,
                }),
                200,
              ));

          final result = await IpGeolocationService.getLocationFromIp(
              httpClient: mockHttpClient);

          expect(result, isNotNull);
          expect(result!.utcOffset, DateTime.now().timeZoneOffset.inMinutes,
              reason: 'Failed for invalid offset: $offset');
        }

        // Test edge case that gets parsed as valid
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 0.0,
                'longitude': 0.0,
                'utc_offset': '++1200',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);
        expect(result, isNotNull);
        expect(result!.utcOffset,
            720); // ++1200 gets parsed as +1200 = 720 minutes
      });

      test('ip-api.com fallback handles failed status correctly', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response('Error', 500));

        when(() => mockHttpClient.get(
              Uri.parse('https://ip-api.com/json'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'status': 'fail',
                'message': 'private range',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);

        expect(result, isNull);
      });
    });

    group('_parseUtcOffset', () {
      test('parses positive offsets correctly', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 0.0,
                'longitude': 0.0,
                'utc_offset': '+0530',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);
        expect(result?.utcOffset, 330);
      });

      test('parses negative offsets correctly', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 0.0,
                'longitude': 0.0,
                'utc_offset': '-0430',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);
        expect(result?.utcOffset, -270);
      });

      test('handles empty offset string', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 0.0,
                'longitude': 0.0,
                'utc_offset': '',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);
        expect(result?.utcOffset, 0);
      });

      test('handles malformed offset string', () async {
        when(() => mockHttpClient.get(
              Uri.parse('https://ipapi.co/json/'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => http.Response(
              json.encode({
                'latitude': 0.0,
                'longitude': 0.0,
                'utc_offset': 'invalid',
              }),
              200,
            ));

        final result = await IpGeolocationService.getLocationFromIp(
            httpClient: mockHttpClient);
        expect(result?.utcOffset, DateTime.now().timeZoneOffset.inMinutes);

        verify(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: 'IP_GEOLOCATION',
              subDomain: '_parseUtcOffset',
            )).called(1);
      });
    });
  });
}
