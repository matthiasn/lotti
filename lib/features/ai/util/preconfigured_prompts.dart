/// Preconfigured prompt templates for common AI tasks.
///
/// This file contains the templates for the four main prompt types:
/// - Task Summary
/// - Action Item Suggestions
/// - Image Analysis
/// - Audio Transcription
///
/// These templates are used when creating new prompts through the
/// "Add Preconfigured Prompt" functionality.
library;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Represents a preconfigured prompt template that can be used
/// to quickly create common prompt types.
class PreconfiguredPrompt {
  const PreconfiguredPrompt({
    required this.type,
    required this.name,
    required this.systemMessage,
    required this.userMessage,
    required this.requiredInputData,
    required this.aiResponseType,
    required this.useReasoning,
    required this.description,
    this.defaultVariables,
  });

  final String type;
  final String name;
  final String systemMessage;
  final String userMessage;
  final List<InputDataType> requiredInputData;
  final AiResponseType aiResponseType;
  final bool useReasoning;
  final String description;
  final Map<String, String>? defaultVariables;
}

/// All available preconfigured prompts
const List<PreconfiguredPrompt> preconfiguredPrompts = [
  taskSummaryPrompt,
  actionItemSuggestionsPrompt,
  imageAnalysisPrompt,
  audioTranscriptionPrompt,
];

/// Task Summary prompt template
const taskSummaryPrompt = PreconfiguredPrompt(
  type: 'task_summary',
  name: 'Task Summary',
  systemMessage: '''
You are a helpful AI assistant that creates clear, concise task summaries. 
Your goal is to help users quickly understand the current state of their tasks, 
including what has been accomplished and what remains to be done.''',
  userMessage: '''
Create a task summary as a TLDR for the provided task details and log entries. 
Imagine the user has not been involved in the task for a long time, and you want to refresh their memory. 
Summarize the task, the achieved results, and the remaining steps that have not been completed yet, if any. 
Also note when the task is done. Note any learnings or insights that can be drawn from the task, if anything is significant. 
Talk to the user directly, instead of referring to them as "the user" or "they". 
Don't start with a greeting, don't repeat the task title, get straight to the point. 
Keep it short and succinct. Assume the task title is shown directly above in the UI, so starting with the title is not necessary and would feel redundant. 
While staying succinct, give the output some structure and organization. 
Use a bullet point list for the achieved results, and a numbered list for the remaining steps. 
If there are any learnings or insights that can be drawn from the task, include them in the output. 
If the task is done, end the output with a concluding statement.

Try to use emojis instead of individual list item bullet points, e.g. ✅ for completed items, or 💡for learnings, 🤯 for annoyances, etc. 
Use the emojis on the individual list item, not on the headline for each list section.

Example:
Achieved results:
✅ Completed step 1
✅ Completed step 2
✅ Completed step 3

Remaining steps:
1. Step 1
2. Step 2
3. Step 3

Learnings:
💡 Learned something interesting
💡 Learned something else

Annoyances:
🤯 Annoyed by something

**Task Details:**
```json
{{task}}
```''',
  requiredInputData: [InputDataType.task],
  aiResponseType: AiResponseType.taskSummary,
  useReasoning: false,
  description:
      'Generate a comprehensive summary of a task including progress, remaining work, and insights',
);

/// Action Item Suggestions prompt template
const actionItemSuggestionsPrompt = PreconfiguredPrompt(
  type: 'action_item_suggestions',
  name: 'Action Item Suggestions',
  systemMessage: '''
You are a helpful AI assistant that identifies actionable items from task logs and conversations. 
Your goal is to help users capture important action items they may have mentioned but not yet formally tracked.''',
  userMessage: '''
Based on the provided task details and log entries, identify potential action items that are mentioned in the text of the logs but have not yet been captured as existing action items. 
These suggestions should be formatted as a list of new action items, each containing a title and completion status. 
Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format.

**Task Details:**
```json
{{task}}
```

Provide these suggested action items in JSON format, adhering to the structure defined by the given classes.
Double check that the returned JSON ONLY contains action items that are not already listed under `actionItems` array in the task details. 
Do not simply return the example response, but the open action items you have found. 
If there are none, return an empty array. 
Double check the items you want to return. 
If any is very similar to an item already listed in the actionItems array of the task details, then remove it from the response.

**Example Response:**

```json
[
  {
    "title": "Review project documentation",
    "completed": false
  },
  {
    "title": "Schedule team meeting for next week",
    "completed": true
  }
]
```''',
  requiredInputData: [InputDataType.task],
  aiResponseType: AiResponseType.actionItemSuggestions,
  useReasoning: true,
  description:
      "Extract actionable items from task logs that haven't been formally captured yet",
);

/// Image Analysis prompt template
const imageAnalysisPrompt = PreconfiguredPrompt(
  type: 'image_analysis',
  name: 'Image Analysis',
  systemMessage: '''
You are a helpful AI assistant specialized in analyzing images. 
Your goal is to provide clear, accurate descriptions of images to help users understand and document visual content.''',
  userMessage: '''
Please analyze the provided image(s) and describe what you see in detail. 
Include information about:
- Main subjects or objects in the image
- Colors, lighting, and composition  
- Any text visible in the image
- Context or setting
- Notable details or interesting features

Be objective and descriptive. If there are multiple images, analyze each one separately.

{{#images}}
Image {{index}}: [Image will be provided]
{{/images}}''',
  requiredInputData: [InputDataType.images],
  aiResponseType: AiResponseType.imageAnalysis,
  useReasoning: false,
  description: 'Analyze and describe the contents of one or more images',
);

/// Audio Transcription prompt template
const audioTranscriptionPrompt = PreconfiguredPrompt(
  type: 'audio_transcription',
  name: 'Audio Transcription',
  systemMessage: '''
You are a helpful AI assistant that transcribes audio content. 
Your goal is to provide accurate, well-formatted transcriptions of audio recordings.''',
  userMessage: '''
Please transcribe the provided audio file(s). 
Format the transcription clearly with proper punctuation and paragraph breaks where appropriate. 
If there are multiple speakers, try to indicate speaker changes. 
Note any significant non-speech audio events [in brackets].

{{#audioFiles}}
Audio File {{index}}: [Audio will be provided]
{{/audioFiles}}''',
  requiredInputData: [InputDataType.audioFiles],
  aiResponseType: AiResponseType.audioTranscription,
  useReasoning: false,
  description: 'Transcribe audio recordings into text format',
);
