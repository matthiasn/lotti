import 'dart:convert';

import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/speech/helpers/transcript_term_corrector.dart';
import 'package:openai_dart/openai_dart.dart';

/// Name of the tool the thinking model calls to propose name corrections.
const transcriptNameCorrectionToolName = 'correct_misheard_names';

/// Wire argument names for [transcriptNameCorrectionToolName].
abstract final class TranscriptNameCorrectionToolArgs {
  static const corrections = 'corrections';
  static const heard = 'heard';
  static const term = 'term';
  static const context = 'context';
}

/// One proposal: `heard` became `term` where it occurs inside `context`, an
/// exact quote of a few words around it — which is what says *which*
/// occurrence the model meant ("May called" is a name, "in May" is not).
typedef TranscriptNameProposal = ({String heard, String term, String? context});

/// Longest stretch of transcript, in words, one proposal may replace: a name
/// misheard as a few short words ("Kel son"), never a phrase.
const transcriptNameCorrectionMaxHeardWords = 3;

final _word = RegExp(r'\p{L}+', unicode: true);
final _upperInitial = RegExp(r'^\p{Lu}', unicode: true);

/// The tool definition handed to the thinking model.
const ChatCompletionTool transcriptNameCorrectionTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: transcriptNameCorrectionToolName,
    description:
        'Report the names in this transcript that speech recognition '
        'misheard. You MUST call this tool exactly once, and respond with '
        'nothing else. Report nothing when every name is already right.',
    parameters: {
      'type': 'object',
      'properties': {
        TranscriptNameCorrectionToolArgs.corrections: {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              TranscriptNameCorrectionToolArgs.heard: {
                'type': 'string',
                'description':
                    'The misheard name exactly as it is written in the '
                    'transcript, at most $transcriptNameCorrectionMaxHeardWords '
                    'words.',
              },
              TranscriptNameCorrectionToolArgs.term: {
                'type': 'string',
                'description':
                    'The name from the list that was said instead, spelled '
                    'exactly as in the list.',
              },
              TranscriptNameCorrectionToolArgs.context: {
                'type': 'string',
                'description':
                    'An exact quote from the transcript of a few words '
                    'around this occurrence, including the misheard name. '
                    'Report each misheard occurrence separately, with its '
                    'own quote.',
              },
            },
            'required': [
              TranscriptNameCorrectionToolArgs.heard,
              TranscriptNameCorrectionToolArgs.term,
              TranscriptNameCorrectionToolArgs.context,
            ],
            'additionalProperties': false,
          },
        },
      },
      'required': [TranscriptNameCorrectionToolArgs.corrections],
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [transcriptNameCorrectionTool]; null for the models that
/// answer a pinned choice with prose anyway (see [forcedToolChoiceFor]).
ChatCompletionToolChoiceOption? transcriptNameCorrectionToolChoiceFor(
  String modelId,
) => forcedToolChoiceFor(
  modelId: modelId,
  toolName: transcriptNameCorrectionToolName,
);

/// The system and user messages asking for corrections of [transcript]
/// against [terms].
({String system, String user}) transcriptNameCorrectionMessages({
  required String transcript,
  required List<String> terms,
}) => (
  system:
      'You check speech-recognition transcripts for misheard names. You are '
      'given the names the speaker is likely to mention. Report a word only '
      'when it is one of those names written wrongly — misheard, misspelled '
      'or split into pieces — and the context makes clear that name was '
      'meant. Never report an ordinary word, a name that is not in the '
      'list, or a name that is already spelled as listed.',
  user:
      'Names the speaker is likely to mention:\n'
      '${terms.map((term) => '- $term').join('\n')}\n\n'
      'Transcript:\n$transcript',
);

/// Decodes the proposals out of [toolCalls]; empty when there is no usable
/// call. A failed check is no correction, never an error: the phonetic pass
/// has already run, and this one only adds to it.
List<TranscriptNameProposal> parseTranscriptNameCorrections(
  List<ChatCompletionMessageToolCall> toolCalls,
) {
  final call = toolCalls
      .where((c) => c.function.name == transcriptNameCorrectionToolName)
      .firstOrNull;
  if (call == null) return const [];
  try {
    final args = jsonDecode(call.function.arguments);
    if (args is! Map<String, dynamic>) return const [];
    final items = args[TranscriptNameCorrectionToolArgs.corrections];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item[TranscriptNameCorrectionToolArgs.heard] is String &&
            item[TranscriptNameCorrectionToolArgs.term] is String)
          (
            heard: (item[TranscriptNameCorrectionToolArgs.heard] as String)
                .trim(),
            term: (item[TranscriptNameCorrectionToolArgs.term] as String)
                .trim(),
            context: switch (item[TranscriptNameCorrectionToolArgs.context]) {
              final String context when context.trim().isNotEmpty =>
                context.trim(),
              _ => null,
            },
          ),
    ];
  } on FormatException {
    return const [];
  }
}

/// Applies the [proposals] the model made for [transcript], keeping only
/// those a check in code can stand behind — the model proposes, it never
/// writes freely:
///
/// * the replacement is one of [terms], or one word of a multi-word term,
///   spelled exactly as listed;
/// * what it replaces is written in the transcript as whole words, at most
///   [transcriptNameCorrectionMaxHeardWords] of them, starting with a capital
///   — a name, not an ordinary lower-case word;
/// * what it replaces is not itself a known name, so a correct name is never
///   swapped for another;
/// * it names its occurrence: only the occurrence inside the proposal's
///   quoted context is replaced, and a context that is not in the transcript
///   rejects the proposal. Without a context, a word that occurs more than
///   once is left alone — one proposal must not rewrite an occurrence the
///   model never looked at ("May called me in May").
///
/// Returns the text and the proposals that were applied, in the order given.
TranscriptTermCorrectionResult applyTranscriptNameCorrections(
  String transcript,
  List<TranscriptNameProposal> proposals,
  List<String> terms,
) {
  final targets = <String>{};
  final knownLower = <String>{};
  for (final term in terms) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) continue;
    targets.add(trimmed);
    knownLower.add(trimmed.toLowerCase());
    for (final match in _word.allMatches(trimmed)) {
      final word = match.group(0)!;
      if (word.length < 3) continue;
      targets.add(word);
      knownLower.add(word.toLowerCase());
    }
  }

  var text = transcript;
  final applied = <TranscriptTermCorrection>[];
  for (final proposal in proposals) {
    final heard = proposal.heard;
    if (!targets.contains(proposal.term)) continue;
    if (heard.isEmpty || heard == proposal.term) continue;
    if (!_upperInitial.hasMatch(heard)) continue;
    if (knownLower.contains(heard.toLowerCase())) continue;
    if (_word.allMatches(heard).length >
        transcriptNameCorrectionMaxHeardWords) {
      continue;
    }
    final pattern = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(heard)}(?![\\p{L}\\p{N}])',
      unicode: true,
    );
    final context = proposal.context;
    if (context == null) {
      if (pattern.allMatches(text).length != 1) continue;
      text = text.replaceFirst(pattern, proposal.term);
    } else {
      final at = text.indexOf(context);
      if (at < 0 || !pattern.hasMatch(context)) continue;
      text = text.replaceRange(
        at,
        at + context.length,
        context.replaceAll(pattern, proposal.term),
      );
    }
    applied.add((heard: heard, term: proposal.term));
  }
  return (text: text, corrections: applied);
}
