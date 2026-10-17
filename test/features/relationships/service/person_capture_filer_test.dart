import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/service/person_capture_filer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  final now = DateTime(2026, 8, 13, 14, 5);
  final person = testRelationship.copyWith(
    meta: testRelationship.meta.copyWith(id: 'pip', categoryId: 'cat-1'),
  );

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: now,
    updatedAt: now,
    dateFrom: now,
    dateTo: now,
  );

  final checkInEntry = CheckInEntry(
    meta: meta('check-in-1'),
    data: const CheckInData(
      relationshipId: 'pip',
      interactionType: CheckInInteractionType.call,
    ),
  );
  final meetingEntry =
      JournalEntity.event(
            meta: meta('meeting-1'),
            data: const EventData(
              title: 'Coffee',
              stars: 0,
              status: EventStatus.planned,
            ),
          )
          as JournalEvent;
  final taskEntry =
      JournalEntity.task(
            meta: meta('task-1'),
            data: TaskData(
              status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
              dateFrom: now,
              dateTo: now,
              statusHistory: const [],
              title: 'Send the draft',
            ),
          )
          as Task;
  final noteEntry =
      JournalEntity.journalEntry(
            meta: meta('note-1'),
            entryText: const EntryText(plainText: 'Sextants.'),
          )
          as JournalEntry;

  late MockRelationshipRepository relationships;
  late MockPersonTimelineRepository timeline;
  late MockDomainLogger logger;
  late List<({String title, DateTime? due, String? categoryId, String from})>
  tasksWritten;
  late List<(String, String)> links;
  late Task? taskAnswer;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    relationships = MockRelationshipRepository();
    timeline = MockPersonTimelineRepository();
    logger = MockDomainLogger();
    tasksWritten = [];
    links = [];
    taskAnswer = taskEntry;
    when(
      () => relationships.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => checkInEntry);
    when(
      () => relationships.attachEntriesToCheckIn(
        checkInId: any(named: 'checkInId'),
        entryIds: any(named: 'entryIds'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => relationships.linkTask(
        relationshipId: any(named: 'relationshipId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => timeline.removeFromTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => timeline.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async => noteEntry);
    when(
      () => timeline.createMeeting(
        person: any(named: 'person'),
        title: any(named: 'title'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async => meetingEntry);
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String>(named: 'message'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => logger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  PersonCaptureFiler filer() => PersonCaptureFiler(
    relationships: relationships,
    timeline: timeline,
    createTask:
        ({
          required title,
          required due,
          required categoryId,
          required inheritContextFrom,
        }) async {
          tasksWritten.add((
            title: title,
            due: due,
            categoryId: categoryId,
            from: inheritContextFrom,
          ));
          return taskAnswer;
        },
    link: ({required fromId, required toId}) async {
      links.add((fromId, toId));
      return true;
    },
    logger: logger,
  );

  Future<List<PersonCaptureItem>> file(List<PersonCaptureItem> items) =>
      filer().file(person: person, audioId: 'audio-1', items: items, now: now);

  test('a check-in carries the summary and the next-time notes, holds the '
      'recording, and the voice note leaves the timeline', () async {
    final unfiled = await file([
      PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.call,
        summary: 'Talked about the launch.',
        startedAt: DateTime(2026, 8, 13, 12, 40),
        duration: const Duration(minutes: 10),
        topics: const ['launch'],
        bringUp: 'Krill.',
        avoid: 'Pad 3.',
      ),
    ]);

    expect(unfiled, isEmpty);
    final call = verify(
      () => relationships.createCheckIn(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        dateFrom: captureAny(named: 'dateFrom'),
        dateTo: captureAny(named: 'dateTo'),
      ),
    ).captured;
    final data = call[0] as CheckInData;
    expect(data.relationshipId, 'pip');
    expect(data.interactionType, CheckInInteractionType.call);
    expect(data.topics, ['launch']);
    expect(data.payAttentionTo, 'Krill.');
    expect(data.avoid, 'Pad 3.');
    expect(data.sentiment, isNull);
    expect((call[1] as EntryText).plainText, 'Talked about the launch.');
    expect(call[2], DateTime(2026, 8, 13, 12, 40));
    expect(call[3], DateTime(2026, 8, 13, 12, 50));
    verify(
      () => relationships.attachEntriesToCheckIn(
        checkInId: 'check-in-1',
        entryIds: ['audio-1'],
      ),
    ).called(1);
    verify(
      () => timeline.removeFromTimeline(personId: 'pip', entryId: 'audio-1'),
    ).called(1);
  });

  test('an untimed check-in ended when it was spoken about', () async {
    await file(const [
      PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.inPerson,
        summary: 'Walked the pier.',
        duration: Duration(minutes: 30),
      ),
    ]);

    final call = verify(
      () => relationships.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: captureAny(named: 'dateFrom'),
        dateTo: captureAny(named: 'dateTo'),
      ),
    ).captured;
    expect(call, [DateTime(2026, 8, 13, 13, 35), now]);
  });

  test('a recording that will not attach stays on the timeline, and the '
      'check-in still counts as filed', () async {
    when(
      () => relationships.attachEntriesToCheckIn(
        checkInId: any(named: 'checkInId'),
        entryIds: any(named: 'entryIds'),
      ),
    ).thenAnswer((_) async => false);

    final unfiled = await file(const [
      PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.call,
        summary: 'Talked.',
      ),
      PersonCaptureNote(text: 'Sextants.'),
    ]);

    expect(unfiled, isEmpty);
    verifyNever(
      () => timeline.removeFromTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    );
    // The recording is still the voice note, so the note needs no copy.
    verifyNever(
      () => timeline.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
      ),
    );
  });

  test('a note is the voice note itself and writes nothing', () async {
    expect(await file(const [PersonCaptureNote(text: 'Sextants.')]), isEmpty);
    verifyNever(
      () => timeline.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
      ),
    );
  });

  test('a check-in goes first and takes the recording, so a note beside it '
      'is written as a note of its own; only the first check-in gets the '
      'recording', () async {
    final unfiled = await file(const [
      PersonCaptureNote(text: 'Sextants.'),
      PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.call,
        summary: 'Talked.',
      ),
      PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.message,
        summary: 'Texted after.',
      ),
    ]);

    expect(unfiled, isEmpty);
    verify(
      () => timeline.createNote(person: person, text: 'Sextants.'),
    ).called(1);
    verify(
      () => relationships.attachEntriesToCheckIn(
        checkInId: any(named: 'checkInId'),
        entryIds: any(named: 'entryIds'),
      ),
    ).called(1);
  });

  test('a meeting is planned on the timeline and leads back to the '
      'recording; with no time it takes the default slot', () async {
    await file([
      PersonCaptureMeeting(
        title: 'Coffee',
        start: DateTime(2026, 8, 16, 15),
        duration: const Duration(hours: 2),
      ),
      const PersonCaptureMeeting(title: 'Walk'),
    ]);

    final calls = verify(
      () => timeline.createMeeting(
        person: person,
        title: captureAny(named: 'title'),
        start: captureAny(named: 'start'),
        duration: captureAny(named: 'duration'),
      ),
    ).captured;
    expect(calls, [
      'Coffee',
      DateTime(2026, 8, 16, 15),
      const Duration(hours: 2),
      'Walk',
      DateTime(2026, 8, 14, 15),
      const Duration(hours: 1),
    ]);
    expect(links, [('meeting-1', 'audio-1'), ('meeting-1', 'audio-1')]);
  });

  test("a task is written in the person's category and privacy, linked to "
      'them and to the recording', () async {
    final unfiled = await file([
      PersonCaptureTask(title: 'Send the draft', due: DateTime(2026, 8, 20)),
    ]);

    expect(unfiled, isEmpty);
    expect(tasksWritten.single, (
      title: 'Send the draft',
      due: DateTime(2026, 8, 20),
      categoryId: 'cat-1',
      from: 'pip',
    ));
    verify(
      () => relationships.linkTask(relationshipId: 'pip', taskId: 'task-1'),
    ).called(1);
    expect(links, [('task-1', 'audio-1')]);
  });

  test('a task whose person link fails is still filed — a retry would '
      'write it twice — and the miss is logged', () async {
    when(
      () => relationships.linkTask(
        relationshipId: any(named: 'relationshipId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => false);

    expect(await file(const [PersonCaptureTask(title: 'Send it')]), isEmpty);
    verify(
      () => logger.log(
        LogDomain.persistence,
        any<String>(),
        subDomain: 'personCaptureFiler',
      ),
    ).called(1);
  });

  test('what could not be written, or threw, is handed back in its order; '
      'the rest is filed', () async {
    taskAnswer = null;
    when(
      () => timeline.createMeeting(
        person: any(named: 'person'),
        title: any(named: 'title'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
      ),
    ).thenThrow(StateError('database locked'));
    when(
      () => relationships.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => null);
    const task = PersonCaptureTask(title: 'Send it');
    const meeting = PersonCaptureMeeting(title: 'Coffee');
    const checkIn = PersonCaptureCheckIn(
      interactionType: CheckInInteractionType.call,
      summary: 'Talked.',
    );
    const note = PersonCaptureNote(text: 'Sextants.');

    final unfiled = await file(const [task, meeting, checkIn, note]);

    expect(unfiled, [task, meeting, checkIn]);
    verify(
      () => logger.error(
        LogDomain.persistence,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'personCaptureFiler',
        message: any<String>(named: 'message'),
      ),
    ).called(1);
  });

  test('a meeting that could not be planned is handed back', () async {
    when(
      () => timeline.createMeeting(
        person: any(named: 'person'),
        title: any(named: 'title'),
        start: any(named: 'start'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async => null);
    const meeting = PersonCaptureMeeting(title: 'Coffee');

    expect(await file(const [meeting]), [meeting]);
    expect(links, isEmpty);
  });
}
