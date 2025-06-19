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
    required this.name,
    required this.systemMessage,
    required this.userMessage,
    required this.requiredInputData,
    required this.aiResponseType,
    required this.useReasoning,
    required this.description,
    this.defaultVariables,
  });

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

Start with a single H1 header (# Title) that suggests a concise, descriptive title 
for this task. The title should be a single line, ideally under 80-100 characters. 
If the task already has a title, suggest an improved version that better captures 
the essence of the task based on the details and logs. Use only one H1 in the 
entire response. This H1 title is for internal suggestion purposes and will be 
processed separately; it will not appear directly in the summary text shown to 
the user. After this, get straight to the point, e.g. no greetings. 
Keep it short and succinct. 
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
  name: 'Image Analysis',
  systemMessage: '''
You are a helpful AI assistant specialized in analyzing images in the context of tasks and projects. 
Your goal is to extract only the information from images that is relevant to the user's current task.''',
  userMessage: '''
Analyze the provided image(s) in the context of this task:

**Task Context:**
```json
{{task}}
```

Extract ONLY information from the image that is relevant to this task. Be concise and focus on task-related content.

If the image is NOT relevant to the task:
- Provide a brief 1-2 sentence summary explaining why it's off-topic
- Use a slightly humorous or salty tone if appropriate
- Example: "This appears to be a photo of ducks by a lake, which seems unrelated to your database migration task. Moving on..."

If the image IS relevant:
- Extract key information that helps with the task
- Be direct and concise
- Focus on actionable insights or important details''',
  requiredInputData: [InputDataType.images],
  aiResponseType: AiResponseType.imageAnalysis,
  useReasoning: false,
  description:
      'Analyze images in task context, extracting only relevant information',
);

/// Audio Transcription prompt template
const audioTranscriptionPrompt = PreconfiguredPrompt(
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
