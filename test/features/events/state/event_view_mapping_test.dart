import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';

import '../../../test_data/test_data.dart';
import '../test_utils.dart';

JournalEvent _event({
  String id = 'e1',
  String title = 'Anna',
  double stars = 5,
  EventStatus status = EventStatus.completed,
  double coverArtCropX = 0.5,
  String? note,
  String? coverArtId,
}) {
  final now = DateTime(2026, 5, 12);
  return JournalEvent(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: EventData(
      title: title,
      stars: stars,
      status: status,
      coverArtCropX: coverArtCropX,
      coverArtId: coverArtId,
    ),
    entryText: note == null ? null : EntryText(plainText: note),
  );
}

AiResponseEntry _aiResponse(
  String response, {
  String id = 'ai-1',
  DateTime? dateFrom,
}) {
  final now = dateFrom ?? DateTime(2026, 5, 12);
  return AiResponseEntry(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: AiResponseData(
      model: 'm',
      systemMessage: '',
      prompt: '',
      thoughts: '',
      response: response,
    ),
  );
}

void main() {
  final now = DateTime(2026, 6, 19);
  String yearTitle(int year) => year == now.year ? 'Earlier in $year' : '$year';

  EventCardData card(
    String id, {
    DateTime? date,
    EventStatus status = EventStatus.completed,
  }) => buildEventCardData(id: id, sortDate: date, status: status);

  List<EventSection> sectionsFor(
    List<EventCardData> cards, {
    String? undatedTitle,
  }) => groupEventsIntoSections(
    cards,
    now: now,
    upcomingTitle: 'Upcoming',
    yearTitle: yearTitle,
    undatedTitle: undatedTitle,
  );

  group('groupEventsIntoSections', () {
    test('returns empty for no cards', () {
      expect(sectionsFor([]), isEmpty);
    });

    test(
      'future-dated events form a featured Upcoming section, soonest first',
      () {
        final sections = sectionsFor([
          card('a', date: DateTime(2026, 9)),
          card('b', date: DateTime(2026, 7)),
        ]);
        expect(sections.single.title, 'Upcoming');
        expect(sections.single.featured, isTrue);
        expect(sections.single.events.map((e) => e.id), ['b', 'a']);
      },
    );

    test('past events group by year, newest year and event first', () {
      final sections = sectionsFor([
        card('2025a', date: DateTime(2025, 3)),
        card('2026a', date: DateTime(2026, 5)),
        card('2026b', date: DateTime(2026, 2)),
      ]);
      expect(sections.map((s) => s.title), ['Earlier in 2026', '2025']);
      expect(sections.first.featured, isFalse);
      expect(sections.first.events.map((e) => e.id), ['2026a', '2026b']);
      expect(sections.last.events.single.id, '2025a');
    });

    test('undated upcoming-status events go to Upcoming', () {
      final sections = sectionsFor([card('plan', status: EventStatus.planned)]);
      expect(sections.single.title, 'Upcoming');
      expect(sections.single.events.single.id, 'plan');
    });

    test('undated past events go to the undated section when titled', () {
      final sections = sectionsFor([card('done')], undatedTitle: 'Undated');
      expect(sections.single.title, 'Undated');
      expect(sections.single.featured, isFalse);
    });

    test('drops undated past events when no undated title is given', () {
      expect(sectionsFor([card('done')]), isEmpty);
    });

    test('undated upcoming sorts after dated upcoming', () {
      final sections = sectionsFor([
        card('plan', status: EventStatus.planned),
        card('soon', date: DateTime(2026, 7)),
      ]);
      expect(sections.single.events.map((e) => e.id), ['soon', 'plan']);
    });

    test('keeps a dated upcoming ahead of an undated one listed first', () {
      // Dated card first exercises the comparator's `bd == null` arm (the
      // mirror of the case above, where the undated card leads).
      final sections = sectionsFor([
        card('soon', date: DateTime(2026, 7)),
        card('plan', status: EventStatus.planned),
      ]);
      expect(sections.single.events.map((e) => e.id), ['soon', 'plan']);
    });

    test('mixes upcoming and past sections in order', () {
      final sections = sectionsFor([
        card('future', date: DateTime(2026, 12)),
        card('thisYear', date: DateTime(2026)),
        card('lastYear', date: DateTime(2025, 6)),
      ]);
      expect(
        sections.map((s) => s.title),
        ['Upcoming', 'Earlier in 2026', '2025'],
      );
      expect(sections.first.featured, isTrue);
    });
  });

  group('eventDateLabel', () {
    test('uses day + month within the current year', () {
      expect(
        eventDateLabel(DateTime(2026, 5, 12), DateTime(2026, 6)),
        '12 May',
      );
    });

    test('uses month + year for other years', () {
      expect(
        eventDateLabel(DateTime(2025, 8), DateTime(2026, 6)),
        'Aug 2025',
      );
    });
  });

  group('eventCardDataFromEvent', () {
    test('maps core fields and uses the note as a summary', () {
      final data = eventCardDataFromEvent(
        _event(note: 'Surprise party!', coverArtCropX: 0.3),
        dateLabel: '12 May',
        categoryColor: const Color(0xFF112233),
        categoryName: 'Friends',
        fallbackTitle: 'Untitled event',
        photoCount: 4,
        taskCount: 2,
      );
      expect(data.id, 'e1');
      expect(data.title, 'Anna');
      expect(data.dateLabel, '12 May');
      expect(data.sortDate, DateTime(2026, 5, 12));
      expect(data.stars, 5);
      expect(data.categoryName, 'Friends');
      expect(data.categoryColor, const Color(0xFF112233));
      expect(data.coverCropX, 0.3);
      expect(data.summary, 'Surprise party!');
      expect(data.photoCount, 4);
      expect(data.taskCount, 2);
    });

    test('falls back to the localized title when the event has no title', () {
      final data = eventCardDataFromEvent(
        _event(title: '   '),
        dateLabel: '12 May',
        categoryColor: const Color(0xFF112233),
        fallbackTitle: 'Untitled event',
      );
      expect(data.title, 'Untitled event');
    });

    test('leaves summary null when there is no note', () {
      final data = eventCardDataFromEvent(
        _event(),
        dateLabel: '12 May',
        categoryColor: const Color(0xFF112233),
        fallbackTitle: 'Untitled event',
      );
      expect(data.summary, isNull);
    });
  });

  group('eventTimelineEntryFor', () {
    ImageProvider fakeImage(JournalImage image) => const AssetImage('x');

    test('maps an image entry to a photo timeline entry', () {
      final entry = eventTimelineEntryFor(
        testImageEntry,
        timeLabel: '20:15',
        imageProviderFor: fakeImage,
      );
      expect(entry, isNotNull);
      expect(entry!.kind, EventTimelineKind.photo);
      expect(entry.photos, hasLength(1));
      // Carries the source id so the detail view can open the entry.
      expect(entry.entryId, testImageEntry.meta.id);
    });

    test('maps a text entry to a note timeline entry', () {
      final entry = eventTimelineEntryFor(
        testTextEntry,
        timeLabel: '20:40',
        imageProviderFor: fakeImage,
      );
      expect(entry!.kind, EventTimelineKind.note);
      expect(entry.text, 'test entry text');
    });

    test('maps an audio entry to an audio timeline entry with a duration', () {
      final entry = eventTimelineEntryFor(
        testAudioEntry,
        timeLabel: '21:30',
        imageProviderFor: fakeImage,
      );
      expect(entry!.kind, EventTimelineKind.audio);
      expect(entry.durationLabel, isNotNull);
      expect(entry.entryId, testAudioEntry.meta.id);
    });

    test('clamps a reversed audio range to a 0:00 duration', () {
      final reversed = testAudioEntry.copyWith(
        data: testAudioEntry.data.copyWith(
          dateFrom: DateTime(2026, 1, 1, 10, 0, 30),
          dateTo: DateTime(2026, 1, 1, 10),
        ),
      );
      final entry = eventTimelineEntryFor(
        reversed,
        timeLabel: '21:30',
        imageProviderFor: fakeImage,
      );
      expect(entry!.durationLabel, '0:00');
    });

    test('returns null for non-timeline entries such as tasks', () {
      expect(
        eventTimelineEntryFor(
          testTask,
          timeLabel: '21:30',
          imageProviderFor: fakeImage,
        ),
        isNull,
      );
    });
  });

  group('eventTaskRefFor', () {
    test('maps a Task to a task ref (open task is not done)', () {
      final ref = eventTaskRefFor(testTask, dueLabel: 'Due Fri');
      expect(ref, isNotNull);
      expect(ref!.title, 'Add tests for journal page');
      expect(ref.done, isFalse);
      expect(ref.dueLabel, 'Due Fri');
    });

    test('returns null for non-task entries', () {
      expect(eventTaskRefFor(testTextEntry), isNull);
    });
  });

  group('eventDetailDataFromEntities', () {
    ImageProvider fakeImage(JournalImage image) => NetworkImage(image.meta.id);

    EventDetailData detail(JournalEvent event, List<JournalEntity> linked) =>
        eventDetailDataFromEntities(
          event: event,
          linked: linked,
          now: now,
          categoryColor: const Color(0xFF112233),
          categoryName: 'Friends',
          fallbackTitle: 'Untitled event',
          imageProviderFor: fakeImage,
        );

    test('builds card, timeline, tasks and a when label from links', () {
      final data = detail(_event(note: 'A lovely night.'), [
        testTextEntry,
        testImageEntry,
        testAudioEntry,
        testTask,
      ]);
      expect(data.card.title, 'Anna');
      expect(data.whenLabel, isNotNull);
      // photo + note + audio map to the timeline; the task does not.
      expect(data.timeline, hasLength(3));
      expect(data.tasks.single.title, 'Add tests for journal page');
      // No coverArtId → the first linked image is the cover.
      expect(
        (data.card.coverImage! as NetworkImage).url,
        testImageEntry.meta.id,
      );
      // No AI response → the event note is the summary.
      expect(data.summary, 'A lovely night.');
    });

    test('formats a linked task due date in the tasks section', () {
      final dueTask = testTask.copyWith(
        data: testTask.data.copyWith(due: DateTime(2026, 6, 25)),
      );
      final data = detail(_event(), [dueTask]);
      expect(data.tasks.single.dueLabel, '25 Jun');
    });

    test('uses the image matching coverArtId as the cover', () {
      final data = detail(_event(coverArtId: testImageEntry.meta.id), [
        testImageEntry,
      ]);
      expect(
        (data.card.coverImage! as NetworkImage).url,
        testImageEntry.meta.id,
      );
    });

    test('collects all linked photos oldest-first for the gallery', () {
      final later = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(
          id: 'img-later',
          dateFrom: DateTime(2026, 5, 12, 21),
        ),
      );
      // Out-of-order input with a non-image mixed in; only images appear,
      // oldest first.
      final data = detail(_event(), [later, testTextEntry, testImageEntry]);
      expect(
        data.photos.map((p) => (p.image as NetworkImage).url).toList(),
        [testImageEntry.meta.id, 'img-later'],
      );
    });

    test('has no cover when there are no linked images', () {
      final data = detail(_event(), [testTextEntry]);
      expect(data.card.coverImage, isNull);
    });

    test('prefers a linked AI response over the note for the summary', () {
      final data = detail(_event(note: 'note'), [
        _aiResponse('AI generated recap'),
      ]);
      expect(data.summary, 'AI generated recap');
    });

    test('selects the newest AI response when several are linked', () {
      // Pass them out of timestamp order to prove the selection sorts rather
      // than relying on link/iteration order.
      final data = detail(_event(note: 'note'), [
        _aiResponse(
          'Newest recap',
          id: 'ai-new',
          dateFrom: DateTime(2026, 5, 12),
        ),
        _aiResponse(
          'Oldest recap',
          id: 'ai-old',
          dateFrom: DateTime(2026, 5, 10),
        ),
        _aiResponse(
          'Middle recap',
          id: 'ai-mid',
          dateFrom: DateTime(2026, 5, 11),
        ),
      ]);
      expect(data.summary, 'Newest recap');
    });

    test('summary is null with no note and no AI response', () {
      final data = detail(_event(), const []);
      expect(data.summary, isNull);
    });
  });
}
