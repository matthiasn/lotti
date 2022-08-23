import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshots.dart';

Future<JournalEntity?> createTextEntry({String? linkedId}) async {
  final entry = await getIt<PersistenceLogic>().createTextEntry(
    EntryText(plainText: ''),
    id: uuid.v1(),
    linkedId: linkedId,
    started: DateTime.now(),
  );

  if (linkedId == null) {
    navigateNamedRoute('/journal/${entry?.meta.id}');
  }
  return entry;
}

Future<JournalEntity?> createTimerEntry({String? linkedId}) async {
  final timerItem = await createTextEntry(linkedId: linkedId);
  if (linkedId != null) {
    if (timerItem != null) {
      await getIt<TimeService>().start(timerItem);
    }
  }
  return timerItem;
}

Future<Task?> createTask({String? linkedId}) async {
  final now = DateTime.now();

  final task = await getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(''),
      title: '',
      statusHistory: [],
      dateTo: now,
      dateFrom: now,
      estimate: Duration.zero,
    ),
    entryText: EntryText(plainText: ''),
    linkedId: linkedId,
  );

  return task;
}

Future<JournalEntity?> createScreenshot({String? linkedId}) async {
  final persistenceLogic = getIt<PersistenceLogic>();
  final imageData = await takeScreenshotMac();
  final entry = await persistenceLogic.createImageEntry(
    imageData,
    linkedId: linkedId,
  );

  if (entry != null) {
    persistenceLogic.addGeolocation(entry.meta.id);
  }

  return entry;
}
