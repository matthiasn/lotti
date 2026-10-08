import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_correction_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Name of the tool the audio summary publishes through: the three summary
/// tiers of [entrySummaryTool], plus the dictionary terms the speech
/// recognition misheard.
const recordingSummaryToolName = 'publish_recording_summary';

/// The tool definition handed to the audio summary's model.
///
/// One call does two jobs a recording needs after speech recognition: it
/// summarizes the transcript and, against the speech dictionary, reports
/// where a term was misheard. The corrections come back as quoted edits
/// rather than a rewritten transcript, for two reasons: retyping a long
/// transcript would cost as many output tokens as it has words, and a model
/// asked to return a transcript may silently shorten or paraphrase it. Code
/// applies the edits ([applyTranscriptNameCorrections]), so every other word
/// is the one the speaker said.
const ChatCompletionTool recordingSummaryTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: recordingSummaryToolName,
    description:
        'Publish the summary of this recording and the speech dictionary '
        'terms its transcript misheard. You MUST call this tool exactly '
        'once, and respond with nothing else. Provide all three summary '
        'tiers, and the corrections — an empty list when there is no '
        'speech dictionary or every term is already right.',
    parameters: {
      'type': 'object',
      'properties': {
        ...entrySummaryToolProperties,
        TranscriptNameCorrectionToolArgs.corrections:
            transcriptCorrectionsProperty,
      },
      'required': [
        ...EntrySummaryToolArgs.required,
        TranscriptNameCorrectionToolArgs.corrections,
      ],
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [recordingSummaryTool]; null for the models that answer
/// a pinned choice with prose anyway (see [forcedToolChoiceFor]).
ChatCompletionToolChoiceOption? recordingSummaryToolChoiceFor(String modelId) =>
    forcedToolChoiceFor(modelId: modelId, toolName: recordingSummaryToolName);

/// What a [recordingSummaryTool] call published.
typedef RecordingSummary = ({
  EntrySummary summary,
  List<TranscriptNameProposal> corrections,
});

/// Decodes a [recordingSummaryToolName] call. The tiers are validated as
/// strictly as [parseEntrySummaryToolCall] does, and a failure throws
/// [EntrySummaryToolException]; the corrections are best effort — a missing
/// or malformed list is no correction, never a reason to discard a summary.
RecordingSummary parseRecordingSummaryToolCall(
  List<ChatCompletionMessageToolCall> toolCalls,
) => (
  summary: parseEntrySummaryToolCall(
    toolCalls,
    toolName: recordingSummaryToolName,
  ),
  corrections: parseTranscriptNameCorrections(
    toolCalls,
    toolName: recordingSummaryToolName,
  ),
);

/// The part of the summary prompt that asks for corrections: each term that
/// reaches the recording, with the spellings it has been misheard as before.
/// Empty when no term reaches it.
String recordingCorrectionPrompt(List<SpeechDictionaryEntry> entries) {
  if (entries.isEmpty) return '';
  final lines = [
    for (final entry in entries)
      switch (entry.misheardAs) {
        final forms? when forms.isNotEmpty =>
          '- ${entry.term} (misheard before as: ${forms.join(', ')})',
        _ => '- ${entry.term}',
      },
  ];
  return '**Speech Dictionary:**\n'
      'The recording was transcribed by speech recognition, which often '
      'mishears the terms below. Each is spelled as it must be, followed by '
      'spellings it has come out as before.\n'
      '${lines.join('\n')}\n\n'
      'Report in `${TranscriptNameCorrectionToolArgs.corrections}` every '
      'place in the Entry Notes where one of these terms was misheard. '
      'Report a word only when the context above and the surrounding words '
      'make clear the term was meant: a spelling listed above can also be a '
      'real word '
      'the speaker said. Never report an ordinary word that is not a '
      'mishearing, and leave the list empty when every term is already right.';
}

/// [entries] plus [knownTerms] — the names a caller expects, such as the
/// person a check-in is about — as entries the correction can name.
///
/// A known term that is already an entry keeps that entry and its misheard
/// spellings. The others get an uncategorized entry under their own id that
/// is never stored, so a correction to one is applied to the transcript but
/// learning it as a misheard spelling finds no entry and skips it: a name a
/// check-in expects is not a dictionary term.
List<SpeechDictionaryEntry> withKnownTerms(
  List<SpeechDictionaryEntry> entries,
  List<String> knownTerms,
) {
  final have = {for (final entry in entries) entry.term.toLowerCase()};
  final epoch = DateTime.utc(1970);
  return [
    ...entries,
    for (final term in {
      for (final raw in knownTerms)
        if (raw.trim() case final t when t.isNotEmpty) t,
    })
      if (!have.contains(term.toLowerCase()))
        SpeechDictionaryEntry(
          id: speechDictionaryEntryId(term),
          createdAt: epoch,
          updatedAt: epoch,
          term: term,
          vectorClock: null,
        ),
  ];
}

/// The misheard spellings of [entries] by term, lower-cased, as
/// [applyTranscriptNameCorrections] reads them.
Map<String, Set<String>> knownMisheardForms(
  List<SpeechDictionaryEntry> entries,
) => {
  for (final entry in entries)
    if (entry.misheardAs?.isNotEmpty ?? false)
      entry.term: {for (final form in entry.misheardAs!) form.toLowerCase()},
};

/// Applies [corrections] to [transcript] against [entries] — the checks of
/// [applyTranscriptNameCorrections], with each term's known misheard
/// spellings as evidence — and returns the text and what was applied.
({String text, List<TermCorrection> applied}) applyRecordingCorrections(
  String transcript,
  List<TranscriptNameProposal> corrections,
  List<SpeechDictionaryEntry> entries,
) {
  if (corrections.isEmpty || entries.isEmpty) {
    return (text: transcript, applied: const []);
  }
  final result = applyTranscriptNameCorrections(
    transcript,
    corrections,
    [for (final entry in entries) entry.term],
    knownMisheard: knownMisheardForms(entries),
  );
  return (
    text: result.text,
    applied: [
      for (final correction in result.corrections)
        (from: correction.heard, to: correction.term),
    ],
  );
}
