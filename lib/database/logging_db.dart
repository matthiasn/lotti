import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/database/common.dart';

part 'logging_db.g.dart';

const loggingDbFileName = 'logging_db.sqlite';

enum InsightLevel {
  error,
  warn,
  info,
  trace,
}

enum InsightType {
  log,
  exception,
}

@DriftDatabase(include: {'logging_db.drift'})
class LoggingDb extends _$LoggingDb {
  LoggingDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            loggingDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  LoggingDb.connect(super.c) : super.connect();

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 1;

  Future<int> log(LogEntry logEntry) async {
    return into(logEntries).insert(_normalizeTimestamp(logEntry));
  }

  Stream<List<LogEntry>> watchLogEntryById(String id) {
    return logEntryById(id).watch();
  }

  Stream<List<LogEntry>> watchLogEntries({
    int limit = 1000,
  }) {
    return allLogEntries(limit).watch();
  }

  /// Search through the entire log database using SQL LIKE queries
  ///
  /// This method searches across message, domain, and subdomain fields
  /// and returns ALL matching results (no limit) to ensure comprehensive search.
  ///
  /// Performance is managed through:
  /// - Debouncing in the UI layer
  /// - Efficient SQL queries with proper indexing
  /// - Case-insensitive matching
  Stream<List<LogEntry>> watchSearchLogEntries(String searchQuery) {
    try {
      // Validate input
      if (searchQuery.isEmpty) {
        return Stream.value([]);
      }

      // Sanitize input to prevent potential issues
      final sanitizedQuery = searchQuery.trim();
      if (sanitizedQuery.isEmpty) {
        return Stream.value([]);
      }

      // Add wildcards for partial matching and convert to lowercase
      final searchPattern = '%${sanitizedQuery.toLowerCase()}%';

      return searchLogEntries(searchPattern)
          .watch()
          .map(_sortEntriesByCreatedAtDesc);
    } catch (e) {
      // Log error and return empty stream to prevent app crashes
      debugPrint('Error in watchSearchLogEntries: $e');
      return Stream.value([]);
    }
  }

  /// Search through the log database with pagination for better performance
  ///
  /// This method is optimized for large datasets and prevents memory issues
  /// by loading only a subset of results at a time.
  ///
  /// Parameters:
  /// - searchQuery: The search term to look for
  /// - limit: Maximum number of results to return (default: 50)
  /// - offset: Number of results to skip (for pagination)
  Stream<List<LogEntry>> watchSearchLogEntriesPaginated(
    String searchQuery, {
    int limit = 50,
    int offset = 0,
  }) {
    try {
      // Validate input
      if (searchQuery.isEmpty) {
        return Stream.value([]);
      }

      // Sanitize input to prevent potential issues
      final sanitizedQuery = searchQuery.trim();
      if (sanitizedQuery.isEmpty) {
        return Stream.value([]);
      }

      // Validate pagination parameters and use local variables
      final validatedLimit = limit <= 0 ? 50 : limit;
      final validatedOffset = offset < 0 ? 0 : offset;

      // Add wildcards for partial matching and convert to lowercase
      final searchPattern = '%${sanitizedQuery.toLowerCase()}%';

      return searchLogEntriesPaginated(
              searchPattern, validatedLimit, validatedOffset)
          .watch()
          .map(_sortEntriesByCreatedAtDesc);
    } catch (e) {
      // Log error and return empty stream to prevent app crashes
      debugPrint('Error in watchSearchLogEntriesPaginated: $e');
      return Stream.value([]);
    }
  }

  /// Get the total count of matching search results
  ///
  /// This method is used for pagination to show total results count
  /// without loading all the actual data.
  Future<int> getSearchLogEntriesCount(String searchQuery) async {
    try {
      // Validate input
      if (searchQuery.isEmpty) {
        return 0;
      }

      // Sanitize input to prevent potential issues
      final sanitizedQuery = searchQuery.trim();
      if (sanitizedQuery.isEmpty) {
        return 0;
      }

      // Add wildcards for partial matching and convert to lowercase
      final searchPattern = '%${sanitizedQuery.toLowerCase()}%';

      final result = await searchLogEntriesCount(searchPattern).getSingle();
      return result;
    } catch (e) {
      // Log error and return 0 to prevent app crashes
      debugPrint('Error in getSearchLogEntriesCount: $e');
      return 0;
    }
  }
}

List<LogEntry> _sortEntriesByCreatedAtDesc(List<LogEntry> entries) {
  final sorted = [...entries]..sort((a, b) {
      DateTime parse(String value) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      return parse(b.createdAt).compareTo(parse(a.createdAt));
    });
  return sorted;
}

LogEntry _normalizeTimestamp(LogEntry entry) {
  try {
    final parsed = DateTime.parse(entry.createdAt);
    final normalized = parsed.toUtc().toIso8601String();
    if (normalized == entry.createdAt) {
      return entry;
    }
    return entry.copyWith(createdAt: normalized);
  } catch (_) {
    return entry;
  }
}
