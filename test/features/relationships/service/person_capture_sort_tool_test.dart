import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:openai_dart/openai_dart.dart';

ChatCompletionMessageToolCall _call({
  List<Object?>? items,
  String? arguments,
  String name = personCaptureSortToolName,
}) => ChatCompletionMessageToolCall(
  id: 'call-1',
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: arguments ?? jsonEncode({'items': items ?? const []}),
  ),
);

void main() {
  String rejection(List<ChatCompletionMessageToolCall> calls) {
    try {
      parsePersonCaptureSortToolCall(calls);
    } on PersonCaptureSortToolException catch (e) {
      return e.reason;
    }
    fail('the call was accepted');
  }

  test('says what was wrong with the call, never what was in it', () {
    expect(rejection([]), 'no $personCaptureSortToolName call');
    expect(
      rejection([_call(name: 'something_else')]),
      'no $personCaptureSortToolName call',
    );
    expect(rejection([_call(arguments: 'not json')]), 'arguments are not JSON');
    expect(
      rejection([_call(arguments: '[1]')]),
      'arguments are not an object',
    );
    expect(
      rejection([_call(arguments: '{"items": "a note"}')]),
      'items is not a list',
    );
    expect(
      const PersonCaptureSortToolException('x').toString(),
      'PersonCaptureSortToolException: x',
    );
  });

  test('reads every kind, trimmed, with its checked fields', () {
    final items = parsePersonCaptureSortToolCall([
      _call(
        items: [
          {
            'kind': 'checkIn',
            'interactionType': 'call',
            'startedAt': '2026-08-13T12:40',
            'durationMinutes': 10,
            'topics': [' the launch ', '', 7, 'krill'],
            'bringUp': ' The krill contract. ',
            'avoid': 'Pad 3.',
            'summary': ' Talked through the launch. ',
          },
          {'kind': 'meeting', 'title': 'Coffee', 'start': '2026-08-16T15:00'},
          {'kind': 'task', 'title': 'Send the draft', 'dueDate': '2026-08-20'},
        ],
      ),
    ]);

    final checkIn = items[0] as PersonCaptureCheckIn;
    expect(checkIn.interactionType, CheckInInteractionType.call);
    expect(checkIn.startedAt, DateTime(2026, 8, 13, 12, 40));
    expect(checkIn.duration, const Duration(minutes: 10));
    expect(checkIn.topics, ['the launch', 'krill']);
    expect(checkIn.bringUp, 'The krill contract.');
    expect(checkIn.avoid, 'Pad 3.');
    expect(checkIn.summary, 'Talked through the launch.');

    final meeting = items[1] as PersonCaptureMeeting;
    expect(meeting.title, 'Coffee');
    expect(meeting.start, DateTime(2026, 8, 16, 15));
    expect(meeting.duration, isNull);

    final task = items[2] as PersonCaptureTask;
    expect(task.title, 'Send the draft');
    expect(task.due, DateTime(2026, 8, 20));
  });

  test('a note keeps its words', () {
    final items = parsePersonCaptureSortToolCall([
      _call(
        items: [
          {'kind': 'note', 'text': ' Collects brass sextants. '},
        ],
      ),
    ]);

    expect(
      (items.single as PersonCaptureNote).text,
      'Collects brass sextants.',
    );
  });

  test('a field that fails its check drops, never the item', () {
    final items = parsePersonCaptureSortToolCall([
      _call(
        items: [
          {
            'kind': 'checkIn',
            'interactionType': 'carrier pigeon',
            'startedAt': '2026-02-30T12:00',
            'durationMinutes': 900,
            'topics': 'not a list',
            'summary': 'Talked.',
          },
          {
            'kind': 'meeting',
            'title': 'Coffee',
            'start': '2026-08-16T15:00Z',
            'durationMinutes': 0,
          },
          {'kind': 'task', 'title': 'Send it', 'dueDate': '2026-13-01'},
        ],
      ),
    ]);

    final checkIn = items[0] as PersonCaptureCheckIn;
    expect(checkIn.interactionType, CheckInInteractionType.other);
    expect(checkIn.startedAt, isNull);
    expect(checkIn.duration, isNull);
    expect(checkIn.topics, isEmpty);
    final meeting = items[1] as PersonCaptureMeeting;
    expect(meeting.start, isNull);
    expect(meeting.duration, isNull);
    expect((items[2] as PersonCaptureTask).due, isNull);
  });

  test('an item without the words it is about, or of no known kind, '
      'drops; at most three are kept', () {
    final items = parsePersonCaptureSortToolCall([
      _call(
        items: [
          {'kind': 'checkIn', 'summary': '  '},
          {'kind': 'note'},
          {'kind': 'meeting', 'title': ''},
          {'kind': 'task'},
          {'kind': 'mood', 'text': 'happy'},
          'a stray string',
          {'kind': 'note', 'text': 'one'},
          {'kind': 'note', 'text': 'two'},
          {'kind': 'note', 'text': 'three'},
          {'kind': 'note', 'text': 'four'},
        ],
      ),
    ]);

    expect(
      items.map((item) => (item as PersonCaptureNote).text),
      ['one', 'two', 'three'],
    );
  });

  test('over-long words are cut to their field', () {
    final items = parsePersonCaptureSortToolCall([
      _call(
        items: [
          {'kind': 'task', 'title': 'x' * 400},
          {'kind': 'note', 'text': 'y' * 5000},
        ],
      ),
    ]);

    expect((items[0] as PersonCaptureTask).title.length, 160);
    expect((items[1] as PersonCaptureNote).text.length, 2000);
  });

  test('the tool is pinned for models that honour a pin', () {
    final choice = personCaptureSortToolChoiceFor('gemini-2.5-flash');
    expect(choice, isNotNull);
    expect(personCaptureSortToolChoiceFor('deepseek-chat'), isNull);
    expect(personCaptureSortTool.function.name, personCaptureSortToolName);
  });
}
