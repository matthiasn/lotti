import 'dart:async';

import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/location.dart';

/// Applies a change to the stored journal entity [journalEntityId] and writes
/// the result on that row; whether the change is stored. `change` answers
/// `null` when there is nothing to write (`PersistenceLogic.updateEntity`).
///
/// This allows GeolocationService to delegate persistence to the caller,
/// avoiding circular dependencies with PersistenceLogic.
typedef EntityChange =
    Future<bool> Function(
      String journalEntityId,
      JournalEntity? Function(JournalEntity stored) change,
    );

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
    required this._loggingService,
    this.deviceLocation,
  });

  final DomainLogger _loggingService;

  /// Optional device location provider. Null on platforms without location
  /// support (e.g., Windows).
  final DeviceLocation? deviceLocation;

  /// Tracks entity IDs currently having geolocation added to prevent
  /// concurrent additions which could cause race conditions.
  final Set<String> _pendingGeolocationAdds = {};

  /// Fire-and-forget: add geolocation to entry.
  ///
  /// This is a convenience wrapper around [addGeolocationAsync] that doesn't
  /// await the result. Use this when you don't need to know when the
  /// geolocation has been added.
  ///
  /// The [persist] callback writes the change on the stored entry. This
  /// allows the caller (typically PersistenceLogic) to handle persistence
  /// with all its side effects (sync, notifications, etc.).
  void addGeolocation(String journalEntityId, EntityChange persist) {
    unawaited(addGeolocationAsync(journalEntityId, persist));
  }

  /// Adds geolocation to a journal entry asynchronously.
  ///
  /// Returns the geolocation the entry has afterwards — the one added, or
  /// the one it already had — or null if:
  /// - Another geolocation add is already pending for this entry (race
  ///   condition prevention)
  /// - Location services are unavailable or returned no location
  /// - The entry doesn't exist, or the write failed
  ///
  /// The geolocation is set on the entry as stored when the write lands
  /// ([persist]): the location fix takes a while, and a field written
  /// meanwhile — a checklist listed on a task just created, its title, its
  /// labels — is kept, not put back from a copy read before the fix
  /// (`specs/tla/ChecklistMembership.tla`, MetaOnStored). Geolocation is
  /// set once and never overwritten.
  Future<Geolocation?> addGeolocationAsync(
    String journalEntityId,
    EntityChange persist,
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
        _loggingService.error(
          LogDomain.location,
          e,
          subDomain: 'getCurrentGeoLocation',
        );
      }

      if (geolocation == null) {
        return null;
      }

      Geolocation? result;
      final stored = await persist(journalEntityId, (stored) {
        result = stored.geolocation ?? geolocation;
        return stored.geolocation == null
            ? stored.copyWith(geolocation: geolocation)
            : null;
      });
      return stored ? result : null;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.location,
        exception,
        stackTrace: stackTrace,
        subDomain: 'addGeolocation',
      );
      return null;
    } finally {
      _pendingGeolocationAdds.remove(journalEntityId);
    }
  }
}
