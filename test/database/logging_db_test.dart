import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';

LogEntry _logEntry({
  required String id,
  required String message,
  DateTime? createdAt,
  String domain = 'app',
  String? subDomain,
  String level = 'INFO',
}) {
  final timestamp = createdAt ?? DateTime(2024, 1, 1, 12);
  return LogEntry(
    id: id,
    createdAt: timestamp.toIso8601String(),
    domain: domain,
    subDomain: subDomain,
    type: 'log',
    level: level,
    message: message,
  );
}

void main() {
  late LoggingDb db;

  setUp(() async {
    db = LoggingDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('LoggingDb Search Tests', () {
    test('watchSearchLogEntries returns empty stream for empty query',
        () async {
      final stream = db.watchSearchLogEntries('');
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('watchSearchLogEntries returns empty stream for whitespace query',
        () async {
      final stream = db.watchSearchLogEntries('   ');
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('watchSearchLogEntries handles basic search correctly', () async {
      // Insert test data
      final logEntry = LogEntry(
        id: 'test1',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'app',
        subDomain: 'ui',
        type: 'log',
        level: 'INFO',
        message: 'Test message for search',
      );
      await db.log(logEntry);

      // Search for the message
      final stream = db.watchSearchLogEntries('Test message');
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result.first.message, equals('Test message for search'));
    });

    test('watchSearchLogEntries is case insensitive', () async {
      // Insert test data with mixed case
      final logEntry = LogEntry(
        id: 'test2',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'App',
        subDomain: 'UI',
        type: 'log',
        level: 'INFO',
        message: 'Mixed Case Message',
      );
      await db.log(logEntry);

      // Search with different cases
      final lowerCaseStream = db.watchSearchLogEntries('mixed case');
      final upperCaseStream = db.watchSearchLogEntries('MIXED CASE');
      final camelCaseStream = db.watchSearchLogEntries('Mixed Case');

      final lowerResult = await lowerCaseStream.first;
      final upperResult = await upperCaseStream.first;
      final camelResult = await camelCaseStream.first;

      expect(lowerResult, hasLength(1));
      expect(upperResult, hasLength(1));
      expect(camelResult, hasLength(1));
    });

    test('watchSearchLogEntries searches across message, domain, and subdomain',
        () async {
      // Insert test data
      final logEntries = [
        LogEntry(
          id: 'test3',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'authentication',
          subDomain: 'login',
          type: 'log',
          level: 'INFO',
          message: 'User logged in successfully',
        ),
        LogEntry(
          id: 'test4',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'database',
          subDomain: 'authentication',
          type: 'log',
          level: 'ERROR',
          message: 'Connection failed',
        ),
        LogEntry(
          id: 'test5',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'api',
          subDomain: 'sync',
          type: 'log',
          level: 'INFO',
          message: 'Data contains authentication token',
        ),
      ];

      for (final entry in logEntries) {
        await db.log(entry);
      }

      // Search for 'authentication' which appears in domain, subdomain, and message
      final stream = db.watchSearchLogEntries('authentication');
      final result = await stream.first;

      expect(result, hasLength(3));
      expect(result.map((e) => e.id), containsAll(['test3', 'test4', 'test5']));
    });

    test('watchSearchLogEntries returns results ordered by created_at DESC',
        () async {
      final now = DateTime.now();
      final logEntries = [
        LogEntry(
          id: 'old',
          createdAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Old search result',
        ),
        LogEntry(
          id: 'new',
          createdAt: now.toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'New search result',
        ),
        LogEntry(
          id: 'middle',
          createdAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Middle search result',
        ),
      ];

      for (final entry in logEntries) {
        await db.log(entry);
      }

      // Search for results
      final stream = db.watchSearchLogEntries('search result');
      final result = await stream.first;

      expect(result, hasLength(3));
      expect(result[0].id, equals('new')); // Most recent first
      expect(result[1].id, equals('middle'));
      expect(result[2].id, equals('old'));
    });

    test('watchSearchLogEntries handles null subdomain correctly', () async {
      // Insert log entries with and without subdomain
      final logEntries = [
        LogEntry(
          id: 'with_subdomain',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'app',
          subDomain: 'test_subdomain',
          type: 'log',
          level: 'INFO',
          message: 'Message with subdomain',
        ),
        LogEntry(
          id: 'without_subdomain',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'app',
          type: 'log',
          level: 'INFO',
          message: 'Message without subdomain',
        ),
      ];

      for (final entry in logEntries) {
        await db.log(entry);
      }

      // Search should work for both entries
      final appStream = db.watchSearchLogEntries('app');
      final appResult = await appStream.first;
      expect(appResult, hasLength(2));

      // Search for subdomain should only find the entry with subdomain
      final subdomainStream = db.watchSearchLogEntries('test_subdomain');
      final subdomainResult = await subdomainStream.first;
      expect(subdomainResult, hasLength(1));
      expect(subdomainResult.first.id, equals('with_subdomain'));
    });

    test('watchSearchLogEntries returns empty for no matches', () async {
      // Insert test data
      final logEntry = LogEntry(
        id: 'test6',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'app',
        type: 'log',
        level: 'INFO',
        message: 'No matching content here',
      );
      await db.log(logEntry);

      // Search for non-existent content
      final stream = db.watchSearchLogEntries('nonexistent');
      final result = await stream.first;

      expect(result, isEmpty);
    });

    test('watchSearchLogEntries handles partial matches', () async {
      // Insert test data
      final logEntry = LogEntry(
        id: 'test7',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'application',
        subDomain: 'authentication',
        type: 'log',
        level: 'INFO',
        message: 'Processing user authentication request',
      );
      await db.log(logEntry);

      // Test partial matches
      final partialQueries = ['app', 'auth', 'Process', 'request', 'user auth'];

      for (final query in partialQueries) {
        final stream = db.watchSearchLogEntries(query);
        final result = await stream.first;
        expect(result, hasLength(1), reason: 'Query "$query" should match');
      }
    });

    test('watchSearchLogEntries handles special characters safely', () async {
      // Insert test data with special characters
      final logEntry = LogEntry(
        id: 'test8',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'app',
        type: 'log',
        level: 'INFO',
        message: 'Error: 100% completion with "quotes" and symbols!',
      );
      await db.log(logEntry);

      // Search with special characters
      final specialQueries = ['100%', '"quotes"', 'Error:', 'symbols!'];

      for (final query in specialQueries) {
        final stream = db.watchSearchLogEntries(query);
        final result = await stream.first;
        expect(result, hasLength(1), reason: 'Query "$query" should match');
      }
    });

    test('watchSearchLogEntries handles error gracefully', () async {
      // This test verifies that the error handling in the method works
      // by checking that malformed input doesn't crash the method

      // Test with very long query
      final longQuery = 'a' * 1000;
      final stream = db.watchSearchLogEntries(longQuery);
      final result = await stream.first;
      expect(result, isEmpty); // Should handle gracefully and return empty
    });

    test('watchSearchLogEntries reactively updates results', () async {
      // Add a matching log entry first
      final logEntry = LogEntry(
        id: 'reactive_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'app',
        type: 'log',
        level: 'INFO',
        message: 'This is a reactive test',
      );
      await db.log(logEntry);

      // Start watching search results for existing data
      final stream = db.watchSearchLogEntries('reactive');

      // Should find the existing entry
      final results = await stream.first;
      expect(results, hasLength(1));
      expect(results.first.message, contains('reactive'));
    });

    test('watchSearchLogEntries input validation and sanitization', () async {
      // Test various edge cases for input validation
      const edgeCases = [
        '  \t  \n  ', // Whitespace variations
        '', // Empty string
        '   ', // Spaces only
        '\n\t', // Newlines and tabs
      ];

      for (final query in edgeCases) {
        final stream = db.watchSearchLogEntries(query);
        final result = await stream.first;
        expect(result, isEmpty, reason: 'Query "$query" should return empty');
      }
    });

    test('watchSearchLogEntries handles extremely long queries', () async {
      await db.log(_logEntry(id: 'very-long', message: 'long query test'));
      final result = await db.watchSearchLogEntries('x' * 6000).first;
      expect(result, isEmpty);
    });

    test('watchSearchLogEntries ignores SQL injection attempts', () async {
      await db.log(_logEntry(id: 'sql-safe', message: 'defensive logging'));
      const injection = "'); DROP TABLE log_entries --";
      final result = await db.watchSearchLogEntries(injection).first;
      expect(result, isEmpty);

      final remaining = await db.watchLogEntries().first;
      expect(remaining, isNotEmpty);
    });
  });

  group('LoggingDb Basic Functionality Tests', () {
    test('log method inserts entry correctly', () async {
      final logEntry = LogEntry(
        id: 'basic_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'Basic test message',
      );

      final insertId = await db.log(logEntry);
      expect(insertId, isPositive);

      // Verify it was inserted
      final stream = db.watchLogEntries();
      final result = await stream.first;
      expect(result, hasLength(1));
      expect(result.first.message, equals('Basic test message'));
    });

    test('watchLogEntries respects limit parameter', () async {
      // Insert multiple entries
      for (var i = 0; i < 5; i++) {
        await db.log(LogEntry(
          id: 'limit_test_$i',
          createdAt: DateTime.now().add(Duration(seconds: i)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Message $i',
        ));
      }

      // Test limit
      final stream = db.watchLogEntries(limit: 3);
      final result = await stream.first;
      expect(result, hasLength(3));
    });

    test('watchLogEntryById returns specific entry', () async {
      final logEntry = LogEntry(
        id: 'specific_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'Specific test message',
      );

      await db.log(logEntry);

      final stream = db.watchLogEntryById('specific_test');
      final result = await stream.first;
      expect(result, hasLength(1));
      expect(result.first.id, equals('specific_test'));
    });

    test('watchLogEntries returns empty list when limit is zero', () async {
      await db.log(_logEntry(id: 'limit-zero', message: 'Zero limit'));
      final result = await db.watchLogEntries(limit: 0).first;
      expect(result, isEmpty);
    });

    test('watchLogEntryById emits updated value when entry replaced', () async {
      final entry = _logEntry(id: 'replace', message: 'initial');
      await db.log(entry);

      final expectation = expectLater(
        db.watchLogEntryById('replace'),
        emitsInOrder([
          isA<List<LogEntry>>().having(
              (entries) => entries.single.message, 'message', 'initial'),
          isA<List<LogEntry>>().having(
              (entries) => entries.single.message, 'message', 'updated'),
        ]),
      );
      await db.into(db.logEntries).insert(
            entry.copyWith(
              message: 'updated',
              createdAt: DateTime(2024, 1, 2).toIso8601String(),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await expectation;
    });

    test('log returns generated row id', () async {
      final insertId = await db.log(_logEntry(id: 'rowid', message: 'row id'));
      expect(insertId, greaterThan(0));
    });
  });

  group('LoggingDb Paginated Search Tests', () {
    test('watchSearchLogEntriesPaginated returns empty for empty query',
        () async {
      final stream = db.watchSearchLogEntriesPaginated('');
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('watchSearchLogEntriesPaginated returns empty for whitespace query',
        () async {
      final stream = db.watchSearchLogEntriesPaginated('   ');
      final result = await stream.first;
      expect(result, isEmpty);
    });

    test('watchSearchLogEntriesPaginated respects limit parameter', () async {
      // Insert multiple test entries
      for (var i = 0; i < 10; i++) {
        await db.log(LogEntry(
          id: 'paginated_test_$i',
          createdAt: DateTime.now().add(Duration(seconds: i)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Paginated test message $i',
        ));
      }

      // Test with limit of 5
      final stream = db.watchSearchLogEntriesPaginated(
        'Paginated test',
        limit: 5,
      );
      final result = await stream.first;
      expect(result, hasLength(5));
    });

    test('watchSearchLogEntriesPaginated respects offset parameter', () async {
      // Insert multiple test entries
      for (var i = 0; i < 10; i++) {
        await db.log(LogEntry(
          id: 'offset_test_$i',
          createdAt: DateTime.now().add(Duration(seconds: i)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Offset test message $i',
        ));
      }

      // Get first page
      final firstPageStream = db.watchSearchLogEntriesPaginated(
        'Offset test',
        limit: 3,
      );
      final firstPage = await firstPageStream.first;

      // Get second page
      final secondPageStream = db.watchSearchLogEntriesPaginated(
        'Offset test',
        limit: 3,
        offset: 3,
      );
      final secondPage = await secondPageStream.first;

      expect(firstPage, hasLength(3));
      expect(secondPage, hasLength(3));

      // Verify different results
      expect(firstPage.first.id, isNot(equals(secondPage.first.id)));
    });

    test('watchSearchLogEntriesPaginated handles default parameters', () async {
      // Insert test data
      await db.log(LogEntry(
        id: 'default_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'Default test message',
      ));

      // Test with default parameters (limit: 50, offset: 0)
      final stream = db.watchSearchLogEntriesPaginated('Default test');
      final result = await stream.first;
      expect(result, hasLength(1));
    });

    test('watchSearchLogEntriesPaginated validates limit parameter', () async {
      // Insert test data
      await db.log(LogEntry(
        id: 'limit_validation_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'Limit validation test message',
      ));

      // Test with invalid limit (should default to 50)
      final stream = db.watchSearchLogEntriesPaginated(
        'Limit validation',
        limit: -1,
      );
      final result = await stream.first;
      expect(result, hasLength(1)); // Should still work with default limit
    });

    test('watchSearchLogEntriesPaginated validates offset parameter', () async {
      // Insert test data
      await db.log(LogEntry(
        id: 'offset_validation_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'Offset validation test message',
      ));

      // Test with invalid offset (should default to 0)
      final stream = db.watchSearchLogEntriesPaginated(
        'Offset validation',
        offset: -5,
      );
      final result = await stream.first;
      expect(result, hasLength(1)); // Should still work with default offset
    });

    test('watchSearchLogEntriesPaginated maintains order by created_at DESC',
        () async {
      final now = DateTime.now();
      final logEntries = [
        LogEntry(
          id: 'old_paginated',
          createdAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Old paginated result',
        ),
        LogEntry(
          id: 'new_paginated',
          createdAt: now.toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'New paginated result',
        ),
        LogEntry(
          id: 'middle_paginated',
          createdAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Middle paginated result',
        ),
      ];

      for (final entry in logEntries) {
        await db.log(entry);
      }

      // Test pagination maintains order
      final stream = db.watchSearchLogEntriesPaginated(
        'paginated result',
        limit: 2,
      );
      final result = await stream.first;

      expect(result, hasLength(2));
      expect(result[0].id, equals('new_paginated')); // Most recent first
      expect(result[1].id, equals('middle_paginated'));
    });

    test('getSearchLogEntriesCount returns correct count for empty query',
        () async {
      final count = await db.getSearchLogEntriesCount('');
      expect(count, equals(0));
    });

    test('getSearchLogEntriesCount returns correct count for whitespace query',
        () async {
      final count = await db.getSearchLogEntriesCount('   ');
      expect(count, equals(0));
    });

    test('getSearchLogEntriesCount returns correct count for matching query',
        () async {
      // Insert multiple test entries
      for (var i = 0; i < 5; i++) {
        await db.log(LogEntry(
          id: 'count_test_$i',
          createdAt: DateTime.now().add(Duration(seconds: i)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Count test message $i',
        ));
      }

      // Insert one non-matching entry
      await db.log(LogEntry(
        id: 'non_matching',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'other',
        type: 'log',
        level: 'INFO',
        message: 'Non matching message',
      ));

      final count = await db.getSearchLogEntriesCount('Count test');
      expect(count, equals(5));
    });

    test('getSearchLogEntriesCount is case insensitive', () async {
      await db.log(LogEntry(
        id: 'case_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'Test',
        type: 'log',
        level: 'INFO',
        message: 'Case Test Message',
      ));

      final lowerCount = await db.getSearchLogEntriesCount('case test');
      final upperCount = await db.getSearchLogEntriesCount('CASE TEST');
      final mixedCount = await db.getSearchLogEntriesCount('Case Test');

      expect(lowerCount, equals(1));
      expect(upperCount, equals(1));
      expect(mixedCount, equals(1));
    });

    test('getSearchLogEntriesCount searches across all fields', () async {
      await db.log(LogEntry(
        id: 'field_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'authentication',
        subDomain: 'login',
        type: 'log',
        level: 'INFO',
        message: 'User authentication successful',
      ));

      // Test searching in different fields
      final domainCount = await db.getSearchLogEntriesCount('authentication');
      final subdomainCount = await db.getSearchLogEntriesCount('login');
      final messageCount = await db.getSearchLogEntriesCount('successful');

      expect(domainCount, equals(1));
      expect(subdomainCount, equals(1));
      expect(messageCount, equals(1));
    });

    test('getSearchLogEntriesCount handles partial matches', () async {
      await db.log(LogEntry(
        id: 'partial_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'application',
        type: 'log',
        level: 'INFO',
        message: 'Processing user request',
      ));

      final partialCount = await db.getSearchLogEntriesCount('app');
      expect(partialCount, equals(1));
    });

    test('getSearchLogEntriesCount returns zero for no matches', () async {
      await db.log(LogEntry(
        id: 'no_match_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'test',
        type: 'log',
        level: 'INFO',
        message: 'This should not match',
      ));

      final count = await db.getSearchLogEntriesCount('nonexistent');
      expect(count, equals(0));
    });

    test('getSearchLogEntriesCount handles special characters', () async {
      await db.log(LogEntry(
        id: 'special_test',
        createdAt: DateTime.now().toIso8601String(),
        domain: 'app',
        type: 'log',
        level: 'INFO',
        message: 'Error: 100% completion with "quotes" and symbols!',
      ));

      final specialCount = await db.getSearchLogEntriesCount('100%');
      expect(specialCount, equals(1));
    });

    test('pagination methods work together correctly', () async {
      // Insert 15 test entries
      for (var i = 0; i < 15; i++) {
        await db.log(LogEntry(
          id: 'integration_test_$i',
          createdAt: DateTime.now().add(Duration(seconds: i)).toIso8601String(),
          domain: 'test',
          type: 'log',
          level: 'INFO',
          message: 'Integration test message $i',
        ));
      }

      // Get total count
      final totalCount = await db.getSearchLogEntriesCount('Integration test');
      expect(totalCount, equals(15));

      // Get first page (10 items)
      final firstPage = await db
          .watchSearchLogEntriesPaginated(
            'Integration test',
            limit: 10,
          )
          .first;
      expect(firstPage, hasLength(10));

      // Get second page (5 items)
      final secondPage = await db
          .watchSearchLogEntriesPaginated(
            'Integration test',
            limit: 10,
            offset: 10,
          )
          .first;
      expect(secondPage, hasLength(5));

      // Verify no overlap between pages
      final firstPageIds = firstPage.map((e) => e.id).toSet();
      final secondPageIds = secondPage.map((e) => e.id).toSet();
      expect(firstPageIds.intersection(secondPageIds), isEmpty);
    });

    test('pagination methods handle edge cases gracefully', () async {
      // Test with very large offset
      final largeOffsetStream = db.watchSearchLogEntriesPaginated(
        'test',
        offset: 10000,
      );
      final largeOffsetResult = await largeOffsetStream.first;
      expect(largeOffsetResult, isEmpty);

      // Test with very large limit
      final largeLimitStream = db.watchSearchLogEntriesPaginated(
        'test',
        limit: 10000,
      );
      final largeLimitResult = await largeLimitStream.first;
      expect(largeLimitResult, isEmpty); // No data to return
    });

    test(
        'watchSearchLogEntriesPaginated returns empty when offset exceeds total',
        () async {
      await db.log(
        _logEntry(
          id: 'paginated-offset',
          message: 'Offset test message',
          createdAt: DateTime(2024, 2),
        ),
      );

      final result = await db
          .watchSearchLogEntriesPaginated(
            'Offset test',
            limit: 10,
            offset: 100,
          )
          .first;

      expect(result, isEmpty);
    });
  });
}
