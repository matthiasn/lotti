import 'dart:async';

import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/location.dart';

/// Callback type for persisting a journal entity.
///
/// This allows GeolocationService to delegate persistence to the caller,
/// avoiding circular dependencies with PersistenceLogic.
typedef EntityPersister = Future<bool?> Function(JournalEntity entity);

/// Service responsible for adding geolocation data to journal entries.
///
/// This service handles:
/// - Race condition prevention for concurrent geolocation additions
/// - Device location capture via [DeviceLocation]
/// - Checking whether an entry already has geolocation data
///
/// Persistence is delegated to a callback to avoid circular dependencies
/// with PersistenceLogic.
class GeolocationService {
  GeolocationService({
    required JournalDb journalDb,
    required LoggingService loggingService,
    required MetadataService metadataService,
    this.deviceLocation,
  })  : _journalDb = journalDb,
        _loggingService = loggingService,
        _metadataService = metadataService;

  final JournalDb _journalDb;
  final LoggingService _loggingService;
  final MetadataService _metadataService;

  /// Optional device location provider. Null on platforms without location
  /// support (e.g., Windows).
  final DeviceLocation? deviceLocation;

  /// Tracks entity IDs currently having geolocation added to prevent
  /// concurrent additions which could cause race conditions.
  final Set<String> _pendingGeolocationAdds = {};

  /// Returns true if a geolocation add operation is pending for the given
  /// entity ID.
  bool isPending(String journalEntityId) =>
      _pendingGeolocationAdds.contains(journalEntityId);

  /// Fire-and-forget: add geolocation to entry.
  ///
  /// This is a convenience wrapper around [addGeolocationAsync] that doesn't
  /// await the result. Use this when you don't need to know when the
  /// geolocation has been added.
  ///
  /// The [persister] callback is used to persist the updated entity. This
  /// allows the caller (typically PersistenceLogic) to handle persistence
  /// with all its side effects (sync, notifications, etc.).
  void addGeolocation(String journalEntityId, EntityPersister persister) {
    unawaited(addGeolocationAsync(journalEntityId, persister));
  }

  /// Adds geolocation to a journal entry asynchronously.
  ///
  /// Returns the geolocation that was added, or null if:
  /// - Another geolocation add is already pending for this entry (race
  ///   condition prevention)
  /// - Location services are unavailable or returned no location
  /// - The entry doesn't exist
  /// - The entry already has a geolocation (to prevent overwriting)
  ///
  /// The [persister] callback is used to persist the updated entity.
  Future<Geolocation?> addGeolocationAsync(
    String journalEntityId,
    EntityPersister persister,
  ) async {
    // Prevent concurrent geolocation additions for the same entity.
    // This avoids race conditions where multiple async calls could
    // both see geolocation == null and then both try to update.
    if (_pendingGeolocationAdds.contains(journalEntityId)) {
      return null;
    }
    _pendingGeolocationAdds.add(journalEntityId);

    try {
      Geolocation? geolocation;
      try {
        geolocation = await deviceLocation?.getCurrentGeoLocation();
      } catch (e) {
        _loggingService.captureException(
          e,
          domain: 'geolocation_service',
          subDomain: 'getCurrentGeoLocation',
        );
      }

      if (geolocation == null) {
        return null;
      }

      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      // Only add geolocation if the entry doesn't already have one.
      // Geolocation should be set once at creation and never overwritten.
      if (journalEntity != null && journalEntity.geolocation == null) {
        final updatedMeta =
            await _metadataService.updateMetadata(journalEntity.meta);
        await persister(
          journalEntity.copyWith(
            meta: updatedMeta,
            geolocation: geolocation,
          ),
        );
        return geolocation;
      }

      return journalEntity?.geolocation;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'geolocation_service',
        subDomain: 'addGeolocation',
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _pendingGeolocationAdds.remove(journalEntityId);
    }
  }

  /// Gets the count of pending geolocation additions.
  ///
  /// Useful for testing and debugging.
  int get pendingCount => _pendingGeolocationAdds.length;
}
