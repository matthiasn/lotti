// The writers the TLA+ models call MetaWrite (`specs/tla/TaskFieldWrites.tla`
// and `ChecklistMembership.tla`, MetaOnStored), each through its real code,
// for the model-conformance traces that drive them over a real JournalDb.

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// How many writers [runMetaWriter] picks from.
const metaWriterCount = 4;

/// The name of writer [which], for test titles.
String metaWriterName(int which) => const [
  'a category',
  'a date',
  'a geolocation',
  "the agent's label",
][which % metaWriterCount];

/// Writes the task [taskId] through metadata writer [which] — the category
/// (`JournalRepository.updateCategoryId`), the date
/// (`updateJournalEntityDate`), the geolocation added after creation
/// (`GeolocationService`) or the agent's labels
/// (`LabelsRepository.addLabels`) — and checks its own change is stored.
/// [stored] reads the row without triggering anything a trace armed.
Future<void> runMetaWriter(
  int which,
  String taskId, {
  required Future<JournalEntity?> Function(String id) stored,
}) async {
  final persistence = getIt<PersistenceLogic>();
  final repository = JournalRepository();
  switch (which % metaWriterCount) {
    case 0:
      final category = 'category-$which';
      expect(
        await repository.updateCategoryId(taskId, categoryId: category),
        isTrue,
      );
      expect((await stored(taskId))!.meta.categoryId, category);
    case 1:
      final from = DateTime(2026, 9, 27, which % 12);
      expect(
        await repository.updateJournalEntityDate(
          taskId,
          dateFrom: from,
          dateTo: from.add(const Duration(hours: 1)),
        ),
        isTrue,
      );
      expect((await stored(taskId))!.meta.dateFrom, from);
    case 2:
      final fix = Geolocation(
        createdAt: DateTime(2026, 9, 27),
        latitude: 52.52,
        longitude: 13.405 + which,
        geohashString: 'u33db2',
      );
      final location = MockDeviceLocation();
      when(location.getCurrentGeoLocation).thenAnswer((_) async => fix);
      final had = (await stored(taskId))!.geolocation;
      final added = await GeolocationService(
        loggingService: getIt<DomainLogger>(),
        deviceLocation: location,
      ).addGeolocationAsync(taskId, persistence.updateEntity);
      expect(added, had ?? fix);
      expect((await stored(taskId))!.geolocation, had ?? fix);
    default:
      final label = 'label-$which';
      final labels = LabelsRepository(
        persistence,
        getIt<JournalDb>(),
        getIt<EntitiesCacheService>(),
        getIt<DomainLogger>(),
        getIt<UpdateNotifications>(),
      );
      expect(
        await labels.addLabels(journalEntityId: taskId, addedLabelIds: [label]),
        isTrue,
      );
      expect((await stored(taskId))!.meta.labelIds, contains(label));
  }
}
