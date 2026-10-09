import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/skills/recording_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:openai_dart/openai_dart.dart';

/// Name of the tool a transcript that is handed straight back to its caller
/// — a Daily OS capture, not a recording that is summarized — reports its
/// misheard speech dictionary terms through.
const transcriptCorrectionToolName = 'report_transcript_corrections';

/// The JSON-Schema of the corrections a transcript's post-processing reports,
/// shared by [recordingSummaryTool] and [transcriptCorrectionTool].
const Map<String, Object> transcriptCorrectionsProperty = {
  'type': 'array',
  'description':
      'Each place where the transcript has a speech dictionary term '
      'misheard, misspelled or split into pieces.',
  'items': {
    'type': 'object',
    'properties': {
      TranscriptNameCorrectionToolArgs.heard: {
        'type': 'string',
        'description':
            'The misheard words exactly as they are written in the '
            'transcript, at most '
            '$transcriptNameCorrectionMaxHeardWords words.',
      },
      TranscriptNameCorrectionToolArgs.term: {
        'type': 'string',
        'description':
            'The dictionary term that was said instead, spelled '
            'exactly as in the dictionary.',
      },
      TranscriptNameCorrectionToolArgs.context: {
        'type': 'string',
        'description':
            'An exact quote from the transcript of a few words '
            'around this occurrence, including the misheard words. '
            'Report each occurrence separately, with its own quote.',
      },
    },
    'required': [
      TranscriptNameCorrectionToolArgs.heard,
      TranscriptNameCorrectionToolArgs.term,
      TranscriptNameCorrectionToolArgs.context,
    ],
    'additionalProperties': false,
  },
};

/// The correction-only tool: the corrections of [recordingSummaryTool]
/// without the summary, for a transcript nothing summarizes. Code applies
/// them ([applyRecordingCorrections]); the model never rewrites the text.
const ChatCompletionTool transcriptCorrectionTool = ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: transcriptCorrectionToolName,
    description:
        'Report the speech dictionary terms this transcript misheard. You '
        'MUST call this tool exactly once, and respond with nothing else. '
        'Report an empty list when every term is already right.',
    parameters: {
      'type': 'object',
      'properties': {
        TranscriptNameCorrectionToolArgs.corrections:
            transcriptCorrectionsProperty,
      },
      'required': [TranscriptNameCorrectionToolArgs.corrections],
      'additionalProperties': false,
    },
  ),
);

/// Pins the model to [transcriptCorrectionTool]; null for the models that
/// answer a pinned choice with prose anyway (see [forcedToolChoiceFor]).
ChatCompletionToolChoiceOption? transcriptCorrectionToolChoiceFor(
  String modelId,
) => forcedToolChoiceFor(
  modelId: modelId,
  toolName: transcriptCorrectionToolName,
);

/// The system and user messages asking for the corrections of [transcript]
/// against [entries], in the words the recording summary uses for them.
({String system, String user}) transcriptCorrectionMessages({
  required String transcript,
  required List<SpeechDictionaryEntry> entries,
}) => (
  system:
      'You check a speech-recognition transcript for misheard speech '
      'dictionary terms. Report them through the '
      '$transcriptCorrectionToolName tool, and nothing else.',
  user:
      '**Entry Notes:**\n$transcript\n\n'
      '${recordingCorrectionPrompt(entries)}',
);
