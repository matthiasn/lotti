import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// The people an entry sits on the timeline of — for an event, who was
/// there — by name.
///
/// Read through [PersonTimelineRepository.getPeopleOn]: the live
/// relationship links to the entry, so the same rows that put an event on a
/// person's page answer who the event was with. Re-read when a link to the
/// entry is written or tombstoned (both notify the entry's id), when any
/// person is written — which covers a rename or a new avatar on someone shown,
/// but also a person who was not shown yet: one whose link synced before
/// their entry, or a private one made public while private entries are
/// hidden — and when private entries are shown or hidden.
final FutureProviderFamily<List<RelationshipEntry>, String>
peopleOnEntryProvider = FutureProvider.autoDispose
    .family<List<RelationshipEntry>, String>((ref, entryId) async {
      var shownIds = <String>{};
      final subscription = ref
          .read(updateNotificationsProvider)
          .updateStream
          .listen((affectedIds) {
            if (affectedIds.contains(entryId) ||
                affectedIds.contains(relationshipNotification) ||
                affectedIds.contains(privateToggleNotification) ||
                affectedIds.any(shownIds.contains) ||
                shownIds.any(
                  (id) => affectedIds.contains(
                    relationshipEntityUpdateNotification(id),
                  ),
                )) {
              ref.invalidateSelf();
            }
          });
      ref.onDispose(subscription.cancel);
      final people = await ref
          .watch(personTimelineRepositoryProvider)
          .getPeopleOn(entryId);
      shownIds = {for (final person in people) person.meta.id};
      return people;
    }, name: 'peopleOnEntryProvider');
