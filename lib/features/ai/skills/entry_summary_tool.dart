import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

/// Name of the tool a summary skill must call to publish its result.
const entrySummaryToolName = 'publish_entry_summary';

/// Wire argument names for [entrySummaryToolName].
///
/// These are the JSON keys the model emits, so they are wire values: renaming
/// one silently breaks every model that has already been prompted with the
/// schema, and there is no migration to run because nothing persists them
/// under these names.
abstract final class EntrySummaryToolArgs {
  static const oneLiner = 'oneLiner';
  static const tldr = 'tldr';
  static const summary = 'summary';

  static const required = <String>[oneLiner, tldr, summary];
}

/// Upper bound on the one-liner, in characters.
///
/// The collapsed audio card renders it on a single ellipsized line, so
/// anything past roughly this length is invisible anyway. Enforced as a
/// *rejection* rather than a truncation: a one-liner that needs cutting is
/// a model that ignored the instruction, and the retry usually fixes it,
/// whereas a mid-word truncation is permanent.
const entrySummaryOneLinerMaxChars = 140;

/// The typed result of a successful [entrySummaryToolName] call.
///
/// Deliberately not a Freezed class: it never crosses a persistence or sync
/// boundary. It exists only between decoding the tool call and writing the
/// three values onto `AiResponseData`, so JSON round-tripping and `copyWith`
/// would be unused ceremony.
class EntrySummary {
  const EntrySummary({
    required this.oneLiner,
    required this.tldr,
    required this.summary,
  });

  /// Single sentence, plain text. The collapsed-card label.
  final String oneLiner;

  /// One to three sentences. Shown on the expanded summary card.
  final String tldr;

  /// The full structured markdown body.
  final String summary;
}

/// Raised when a tool call cannot be turned into an [EntrySummary].
///
/// Carries a reason that is safe to log verbatim — it names *what* was wrong
/// with the shape, never the transcript content that produced it.
class EntrySummaryToolException implements Exception {
  const EntrySummaryToolException(this.reason);

  final String reason;

  @override
  String toString() => 'EntrySummaryToolException: $reason';
}

/// The JSON-Schema tool definition handed to the model.
///
/// `additionalProperties: false` plus an explicit `required` list is what lets
/// [parseEntrySummaryToolCall] treat a decode failure as a real error rather
/// than a shape it should tolerate.
const ChatCompletionTool entrySummaryTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: entrySummaryToolName,
    description:
        'Publish the summary of this recording. You MUST call this tool '
        'exactly once, and respond with nothing else. Provide all three '
        'tiers: a one-line label, a short TLDR, and the full markdown '
        'summary.',
    parameters: {
      'type': 'object',
      'properties': {
        EntrySummaryToolArgs.oneLiner: {
          'type': 'string',
          'description':
              'ONE plain sentence naming what this recording is about, at '
              'most $entrySummaryOneLinerMaxChars characters. This is shown '
              'as the collapsed label for the recording in the task log, so '
              'it must stand alone and be specific — never "a voice note" or '
              '"the user discusses several topics". No markdown, no bullet '
              'points, no leading label, no trailing ellipsis.',
        },
        EntrySummaryToolArgs.tldr: {
          'type': 'string',
          'description':
              'One to three sentences covering what was said and what it '
              'means for the task. Shown when the recording is expanded but '
              'the full summary is still collapsed, so it must stand on its '
              'own. Plain prose, no headings.',
        },
        EntrySummaryToolArgs.summary: {
          'type': 'string',
          'description':
              'The full summary as a markdown document. Organise it under '
              'headings and bullets so a long recording stays scannable; up '
              'to about half a page for a long meeting, much shorter for a '
              'brief note. Do not repeat the TLDR verbatim as the opening '
              'line, and do not transcribe the recording back — summarise '
              'it.',
        },
      },
      'required': EntrySummaryToolArgs.required,
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [entrySummaryTool] so the summary cannot come back as
/// prose the caller would have to parse.
const ChatCompletionToolChoiceOption entrySummaryToolChoice =
    ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: entrySummaryToolName,
        ),
      ),
    );

/// Decodes and validates the [entrySummaryToolName] call out of [toolCalls].
///
/// Throws [EntrySummaryToolException] when the call is missing, malformed, or
/// violates the contract the schema states. Throwing rather than returning
/// null is deliberate: every failure here is worth one forced retry, and the
/// caller distinguishes "no summary this time" from "something is wrong with
/// this model" by the reason string.
///
/// Extra tool calls beyond the first matching one are ignored rather than
/// rejected — some providers echo a duplicate final call, and a usable first
/// result should not be thrown away over it.
EntrySummary parseEntrySummaryToolCall(
  List<ChatCompletionMessageToolCall> toolCalls,
) {
  final call = toolCalls
      .where((toolCall) => toolCall.function.name == entrySummaryToolName)
      .firstOrNull;
  if (call == null) {
    final seen = toolCalls.map((c) => c.function.name).join(', ');
    throw EntrySummaryToolException(
      seen.isEmpty
          ? 'model published no tool call'
          : 'model called [$seen] but not $entrySummaryToolName',
    );
  }

  Object? decoded;
  try {
    decoded = jsonDecode(call.function.arguments);
  } on FormatException catch (e) {
    throw EntrySummaryToolException(
      'arguments are not valid JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const EntrySummaryToolException('arguments are not a JSON object');
  }
  final args = decoded;

  String requireField(String key) {
    final value = args[key];
    if (value is! String) {
      throw EntrySummaryToolException(
        value == null ? 'missing "$key"' : '"$key" is not a string',
      );
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw EntrySummaryToolException('"$key" is empty');
    }
    return trimmed;
  }

  final oneLiner = requireField(EntrySummaryToolArgs.oneLiner);
  if (oneLiner.length > entrySummaryOneLinerMaxChars) {
    throw EntrySummaryToolException(
      '"${EntrySummaryToolArgs.oneLiner}" is ${oneLiner.length} chars, '
      'over the $entrySummaryOneLinerMaxChars limit',
    );
  }

  return EntrySummary(
    oneLiner: oneLiner,
    tldr: requireField(EntrySummaryToolArgs.tldr),
    summary: requireField(EntrySummaryToolArgs.summary),
  );
}
