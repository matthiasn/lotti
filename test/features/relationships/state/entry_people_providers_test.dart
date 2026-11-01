import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/state/entry_people_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../helpers/test_people.dart';

void main() {
  const eventId = 'event-1';

  late MockPersonTimelineRepository timeline;
  late MockUpdateNotifications notifications;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;
  ProviderSubscription<AsyncValue<Object?>>? keepAlive;

  /// Keeps the provider alive across notifications, as a page watching it
  /// would; subscribed only after a test has stubbed what it reads.
  Future<void> watchPeople() async {
    keepAlive = container.listen(peopleOnEntryProvider(eventId), (_, _) {});
    await container.read(peopleOnEntryProvider(eventId).future);
  }

  setUp(() {
    timeline = MockPersonTimelineRepository();
    notifications = MockUpdateNotifications();
    // Synchronous delivery: `add` runs the listener — and its
    // `invalidateSelf` — before it returns.
    updates = StreamController<Set<String>>.broadcast(sync: true);
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    getIt.registerSingleton<UpdateNotifications>(notifications);
    container = ProviderContainer(
      overrides: withServiceOverrides([
        personTimelineRepositoryProvider.overrideWithValue(timeline),
      ]),
    );
  });

  tearDown(() async {
    keepAlive?.close();
    keepAlive = null;
    container.dispose();
    await updates.close();
    await getIt.unregister<UpdateNotifications>();
  });

  final pip = makeTestPerson(id: 'pip', title: 'Pip Penguin');

  test("reads the people on the entry's relationship links", () async {
    when(() => timeline.getPeopleOn(eventId)).thenAnswer((_) async => [pip]);

    await watchPeople();
    final people = await container.read(peopleOnEntryProvider(eventId).future);

    expect(people.map((p) => p.meta.id), ['pip']);
  });

  group('re-reads', () {
    setUp(() async {
      when(() => timeline.getPeopleOn(eventId)).thenAnswer((_) async => [pip]);
      await watchPeople();
      clearInteractions(timeline);
    });

    Future<void> notify(Set<String> ids) async {
      updates.add(ids);
      await container.read(peopleOnEntryProvider(eventId).future);
    }

    test('when a link to the entry is written or tombstoned', () async {
      await notify({eventId});
      verify(() => timeline.getPeopleOn(eventId)).called(1);
    });

    test('when a person shown changes', () async {
      await notify({'pip'});
      verify(() => timeline.getPeopleOn(eventId)).called(1);
      await notify({relationshipEntityUpdateNotification('pip')});
      verify(() => timeline.getPeopleOn(eventId)).called(1);
    });

    test('when private entries are shown or hidden', () async {
      await notify({privateToggleNotification});
      verify(() => timeline.getPeopleOn(eventId)).called(1);
    });

    test('but not for anyone or anything else', () async {
      await notify({'someone-else', 'other-event'});
      verifyNever(() => timeline.getPeopleOn(eventId));
    });
  });
}
