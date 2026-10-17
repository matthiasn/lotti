import 'dart:convert';

import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:openai_dart/openai_dart.dart';

/// Name of the tool a sorted capture is published through.
const personCaptureSortToolName = 'sort_person_capture';

/// Wire argument names for [personCaptureSortToolName]: the JSON keys the
/// model emits.
abstract final class PersonCaptureSortToolArgs {
  static const oneLiner = 'oneLiner';
  static const items = 'items';
  static const kind = 'kind';
  static const interactionType = 'interactionType';
  static const startedAt = 'startedAt';
  static const durationMinutes = 'durationMinutes';
  static const topics = 'topics';
  static const bringUp = 'bringUp';
  static const avoid = 'avoid';
  static const summary = 'summary';
  static const text = 'text';
  static const title = 'title';
  static const start = 'start';
  static const dueDate = 'dueDate';
}

/// The four kinds an item can be, as the model names them.
abstract final class PersonCaptureKinds {
  static const checkIn = 'checkIn';
  static const note = 'note';
  static const meeting = 'meeting';
  static const task = 'task';

  static const List<String> all = [checkIn, note, meeting, task];
}

/// The longest a text field may run before it is cut: a summary or a note
/// is a paragraph, a title a line.
const _maxProse = 2000;
const _maxLine = 160;
const _maxTopics = 5;

/// The longest the capture's one-line summary may run.
const personCaptureOneLinerMaxChars = 140;

/// What a sort call published: the capture's one-line `summary` — the voice
/// note's label on the timeline — or null when the model gave none, and the
/// `items` to review.
typedef PersonCaptureSortResult = ({
  String? summary,
  List<PersonCaptureItem> items,
});

/// A tool call that cannot be read as a sorted capture at all. The reason
/// names what was wrong with its shape, never its content, so it is safe to
/// log and to tell the model.
class PersonCaptureSortToolException implements Exception {
  const PersonCaptureSortToolException(this.reason);

  final String reason;

  @override
  String toString() => 'PersonCaptureSortToolException: $reason';
}

/// The tool handed to the model.
const ChatCompletionTool personCaptureSortTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: personCaptureSortToolName,
    description:
        'Publish what the spoken capture contains. You MUST call this tool '
        'exactly once, and respond with nothing else.',
    parameters: {
      'type': 'object',
      'properties': {
        PersonCaptureSortToolArgs.oneLiner: {
          'type': 'string',
          'description':
              'ONE plain sentence, at most $personCaptureOneLinerMaxChars '
              'characters, saying what the whole capture is about, in the '
              'language spoken. It labels the recording on the timeline of '
              'the person it is about. No markdown, no leading label.',
        },
        PersonCaptureSortToolArgs.items: {
          'type': 'array',
          'maxItems': personCaptureMaxItems,
          'description':
              'At most $personCaptureMaxItems items, in the order they were '
              'spoken. An empty list when the capture holds nothing to file.',
          'items': {
            'type': 'object',
            'properties': {
              PersonCaptureSortToolArgs.kind: {
                'type': 'string',
                'enum': PersonCaptureKinds.all,
                'description':
                    'checkIn: a conversation with the person that already '
                    'took place. note: something to remember about them. '
                    'meeting: a future meeting with them that has a time. '
                    'task: something the user means to do.',
              },
              PersonCaptureSortToolArgs.interactionType: {
                'type': 'string',
                'enum': ['inPerson', 'call', 'videoCall', 'message', 'other'],
                'description': 'checkIn only: how the conversation happened.',
              },
              PersonCaptureSortToolArgs.startedAt: {
                'type': 'string',
                'description':
                    'checkIn only, when it was said: local time '
                    'YYYY-MM-DDTHH:MM.',
              },
              PersonCaptureSortToolArgs.durationMinutes: {
                'type': 'integer',
                'description':
                    'checkIn or meeting, when it was said: whole minutes.',
              },
              PersonCaptureSortToolArgs.topics: {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'checkIn only: up to $_maxTopics short topics, one to '
                    'three words each.',
              },
              PersonCaptureSortToolArgs.bringUp: {
                'type': 'string',
                'description':
                    'checkIn only, when it was said: what to bring up next '
                    'time.',
              },
              PersonCaptureSortToolArgs.avoid: {
                'type': 'string',
                'description':
                    'checkIn only, when it was said: what to leave alone '
                    'next time.',
              },
              PersonCaptureSortToolArgs.summary: {
                'type': 'string',
                'description':
                    'checkIn: what the conversation was about, in the '
                    "user's own words where possible, in the language "
                    'they spoke.',
              },
              PersonCaptureSortToolArgs.text: {
                'type': 'string',
                'description':
                    'note: what to remember, in the language they spoke.',
              },
              PersonCaptureSortToolArgs.title: {
                'type': 'string',
                'description':
                    'meeting or task: a short title, in the language they '
                    'spoke.',
              },
              PersonCaptureSortToolArgs.start: {
                'type': 'string',
                'description':
                    'meeting: when it starts, local time YYYY-MM-DDTHH:MM.',
              },
              PersonCaptureSortToolArgs.dueDate: {
                'type': 'string',
                'description': 'task only, when it was said: YYYY-MM-DD.',
              },
            },
            'required': [PersonCaptureSortToolArgs.kind],
          },
        },
      },
      'required': [
        PersonCaptureSortToolArgs.oneLiner,
        PersonCaptureSortToolArgs.items,
      ],
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [personCaptureSortTool], or null for a model that
/// answers a pin in prose (see [forcedToolChoiceFor]).
ChatCompletionToolChoiceOption? personCaptureSortToolChoiceFor(
  String modelId,
) => forcedToolChoiceFor(
  modelId: modelId,
  toolName: personCaptureSortToolName,
);

/// Decodes the [personCaptureSortToolName] call out of [toolCalls] into the
/// capture's one-line summary and at most [personCaptureMaxItems] items.
/// A missing or blank summary is null, never a reason to retry: the items
/// are what the review needs.
///
/// Throws [PersonCaptureSortToolException] only when the call as a whole is
/// unreadable — missing, not JSON, no item list — which is worth one retry.
/// Within it the model is taken at its word as far as it can be checked: an
/// item without the words it is about (a check-in without a summary, a task
/// without a title, an unknown kind) is dropped, and a field that fails its
/// check — a date that does not round-trip, a length out of range — is
/// dropped from its item, never the item with it.
PersonCaptureSortResult parsePersonCaptureSortToolCall(
  List<ChatCompletionMessageToolCall> toolCalls,
) {
  final call = toolCalls
      .where((c) => c.function.name == personCaptureSortToolName)
      .firstOrNull;
  if (call == null) {
    throw const PersonCaptureSortToolException(
      'no $personCaptureSortToolName call',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(call.function.arguments);
  } on FormatException {
    throw const PersonCaptureSortToolException('arguments are not JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const PersonCaptureSortToolException('arguments are not an object');
  }
  final items = decoded[PersonCaptureSortToolArgs.items];
  if (items is! List) {
    throw const PersonCaptureSortToolException('items is not a list');
  }
  final oneLiner = decoded[PersonCaptureSortToolArgs.oneLiner];
  final summary = oneLiner is String ? oneLiner.trim() : '';
  return (
    summary: summary.isEmpty
        ? null
        : summary.length > personCaptureOneLinerMaxChars
        ? summary.substring(0, personCaptureOneLinerMaxChars).trim()
        : summary,
    items: [
      for (final raw in items)
        if (raw is Map<String, dynamic>) ?_item(raw),
    ].take(personCaptureMaxItems).toList(),
  );
}

List<String> _topics(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final topic in raw)
      if (topic is String && topic.trim().isNotEmpty)
        if (topic.trim().length > _maxLine)
          topic.trim().substring(0, _maxLine)
        else
          topic.trim(),
  ].take(_maxTopics).toList();
}

PersonCaptureItem? _item(Map<String, dynamic> raw) {
  String? text(String key, int max) {
    final value = raw[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > max ? trimmed.substring(0, max).trim() : trimmed;
  }

  switch (raw[PersonCaptureSortToolArgs.kind]) {
    case PersonCaptureKinds.checkIn:
      final summary = text(PersonCaptureSortToolArgs.summary, _maxProse);
      if (summary == null) return null;
      final topics = raw[PersonCaptureSortToolArgs.topics];
      return PersonCaptureCheckIn(
        interactionType: CheckInInteractionType.values.firstWhere(
          (type) => type.name == raw[PersonCaptureSortToolArgs.interactionType],
          orElse: () => CheckInInteractionType.other,
        ),
        summary: summary,
        startedAt: parsePersonCaptureLocalTime(
          raw[PersonCaptureSortToolArgs.startedAt],
        ),
        duration: parsePersonCaptureMinutes(
          raw[PersonCaptureSortToolArgs.durationMinutes],
        ),
        topics: _topics(topics),
        bringUp: text(PersonCaptureSortToolArgs.bringUp, _maxProse),
        avoid: text(PersonCaptureSortToolArgs.avoid, _maxProse),
      );
    case PersonCaptureKinds.note:
      final note = text(PersonCaptureSortToolArgs.text, _maxProse);
      return note == null ? null : PersonCaptureNote(text: note);
    case PersonCaptureKinds.meeting:
      final title = text(PersonCaptureSortToolArgs.title, _maxLine);
      if (title == null) return null;
      return PersonCaptureMeeting(
        title: title,
        start: parsePersonCaptureLocalTime(
          raw[PersonCaptureSortToolArgs.start],
        ),
        duration: parsePersonCaptureMinutes(
          raw[PersonCaptureSortToolArgs.durationMinutes],
        ),
      );
    case PersonCaptureKinds.task:
      final title = text(PersonCaptureSortToolArgs.title, _maxLine);
      if (title == null) return null;
      return PersonCaptureTask(
        title: title,
        due: parsePersonCaptureDay(raw[PersonCaptureSortToolArgs.dueDate]),
      );
  }
  return null;
}
