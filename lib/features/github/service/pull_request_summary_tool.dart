import 'dart:convert';

import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:openai_dart/openai_dart.dart';

/// Name of the tool a pull request summary is published through.
const pullRequestSummaryToolName = 'publish_pull_request_summary';

/// Wire argument names for [pullRequestSummaryToolName]: the JSON keys the
/// model emits.
abstract final class PullRequestSummaryToolArgs {
  static const oneLiner = 'oneLiner';
  static const tldr = 'tldr';

  static const required = <String>[oneLiner, tldr];
}

/// A tool call that cannot be turned into a [PullRequestSummary]. The
/// reason names what was wrong with its shape, never its content, so it is
/// safe to log and to tell the model.
class PullRequestSummaryToolException implements Exception {
  const PullRequestSummaryToolException(this.reason);

  final String reason;

  @override
  String toString() => 'PullRequestSummaryToolException: $reason';
}

/// The tool handed to the model.
const ChatCompletionTool pullRequestSummaryTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: pullRequestSummaryToolName,
    description:
        'Publish the summary of this pull request. You MUST call this tool '
        'exactly once, and respond with nothing else.',
    parameters: {
      'type': 'object',
      'properties': {
        PullRequestSummaryToolArgs.oneLiner: {
          'type': 'string',
          'description':
              'ONE plain sentence saying what the pull request does, at most '
              '$pullRequestOneLinerMaxChars characters. Shown under its title '
              'in the task, so do not repeat the title: say what it changes. '
              'No markdown, no leading label.',
        },
        PullRequestSummaryToolArgs.tldr: {
          'type': 'string',
          'description':
              'Three to six sentences, at most $pullRequestTldrMaxChars '
              'characters: what the pull request changes and why, where it '
              'stands — open, a draft, merged, or closed without merging — '
              'and how it got there. Say so when it saw a lot of discussion '
              'or several rounds of requested changes. An assistant tracking '
              'the task reads it to know what work is done or under way, so '
              'it must stand on its own. Plain prose, no headings.',
        },
      },
      'required': PullRequestSummaryToolArgs.required,
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [pullRequestSummaryTool], or null for a model that
/// answers a pin in prose (see [forcedToolChoiceFor]).
ChatCompletionToolChoiceOption? pullRequestSummaryToolChoiceFor(
  String modelId,
) => forcedToolChoiceFor(
  modelId: modelId,
  toolName: pullRequestSummaryToolName,
);

/// Decodes the [pullRequestSummaryToolName] call out of [toolCalls].
///
/// Throws [PullRequestSummaryToolException] when it is missing, malformed,
/// empty or over length: each is worth one retry. A later duplicate call is
/// ignored.
PullRequestSummary parsePullRequestSummaryToolCall(
  List<ChatCompletionMessageToolCall> toolCalls,
) {
  final call = toolCalls
      .where((c) => c.function.name == pullRequestSummaryToolName)
      .firstOrNull;
  if (call == null) {
    throw const PullRequestSummaryToolException(
      'no $pullRequestSummaryToolName call',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(call.function.arguments);
  } on FormatException {
    throw const PullRequestSummaryToolException('arguments are not JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const PullRequestSummaryToolException(
      'arguments are not an object',
    );
  }
  String field(String name, int max) {
    final value = decoded! as Map<String, dynamic>;
    final text = value[name];
    if (text is! String || text.trim().isEmpty) {
      throw PullRequestSummaryToolException('$name is missing or empty');
    }
    final trimmed = text.trim();
    if (trimmed.length > max) {
      throw PullRequestSummaryToolException(
        '$name is longer than $max characters',
      );
    }
    return trimmed;
  }

  return PullRequestSummary(
    oneLiner: field(
      PullRequestSummaryToolArgs.oneLiner,
      pullRequestOneLinerMaxChars,
    ),
    tldr: field(PullRequestSummaryToolArgs.tldr, pullRequestTldrMaxChars),
  );
}
