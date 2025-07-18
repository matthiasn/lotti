/// Preconfigured prompt templates for common AI tasks.
///
/// This file contains the templates for the six main prompt types:
/// - Task Summary
/// - Action Item Suggestions
/// - Image Analysis
/// - Image Analysis in Task Context
/// - Audio Transcription
/// - Audio Transcription with Task Context
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
  imageAnalysisInTaskContextPrompt,
  audioTranscriptionPrompt,
  audioTranscriptionWithTaskContextPrompt,
];

/// Task Summary prompt template
const taskSummaryPrompt = PreconfiguredPrompt(
  name: 'Task Summary',
  systemMessage: '''
You are a helpful AI assistant that creates clear, concise task summaries. 
Your goal is to help users quickly understand the current state of their tasks, 
including what has been accomplished and what remains to be done.

You have access to a function that can suggest checklist items be marked as completed.
When you find evidence in the task logs that a checklist item has been completed,
use the suggest_checklist_completion function to notify the user.''',
  userMessage: '''
Create a task summary for the provided task details and log entries. 
Imagine the user has not been involved in the task for a long time, and you want to refresh their memory. 
Talk to the user directly, instead of referring to them as "the user" or "they". 

Start with a single H1 header (# Title) that suggests a concise, descriptive title 
for this task. The title should be a single line, ideally under 80-100 characters. 
If the task already has a title, suggest an improved version that better captures 
the essence of the task based on the details and logs. Use only one H1 in the 
entire response. This H1 title is for internal suggestion purposes and will be 
processed separately; it will not appear directly in the summary text shown to 
the user.

After the title, immediately provide a TLDR paragraph that MUST be exactly 3-4 lines maximum (approximately 50-80 words total). 
This paragraph must:
- Start with "**TLDR:** " (with the entire paragraph in bold using double asterisks)
- Be extremely concise - focus only on: current status (1 line) + immediate next step (1-2 lines)
- Use short, punchy sentences without filler words
- Be slightly motivational without being cheesy (e.g., "Almost there!" or "Great progress!")
- Include 1-2 relevant emojis that match the task's current state
- Prioritize clarity over completeness - it's better to be brief than comprehensive
- End the paragraph with a line break

Example TLDR format:
**TLDR:** **Core auth system and database done. Next: email verification and password reset.
Almost there - just these two features left! 🚀 Focus on the email flow first. 💪**

After the TLDR, provide the detailed summary with:
- Achieved results (use ✅ emoji for each completed item)
- Remaining steps (numbered list)
- Any learnings or insights (use 💡 emoji)
- Any annoyances or blockers (use 🤯 emoji)

Keep the detailed summary succinct while maintaining good structure and organization.
If the task is done, end with a concluding statement.

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
Your goal is to help users capture important action items they may have mentioned but not yet formally tracked.

You have access to a function that can suggest checklist items be marked as completed.
When analyzing the task logs, if you find evidence that an existing checklist item (action item) 
has been completed, use the suggest_checklist_completion function to notify the user.
Look for past tense verbs, explicit statements of completion, or results that imply a task is done.''',
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
  systemMessage:
      'You are a helpful AI assistant specialized in analyzing images in the context of tasks and projects.',
  userMessage: '''
Analyze the provided image(s) in detail, focusing on both the content and style of the image.
''',
  requiredInputData: [InputDataType.images],
  aiResponseType: AiResponseType.imageAnalysis,
  useReasoning: false,
  description: 'Analyze images in detail',
);

/// Image Analysis in Task Context prompt template
const imageAnalysisInTaskContextPrompt = PreconfiguredPrompt(
  name: 'Image Analysis in Task Context',
  systemMessage: '''
You are a helpful AI assistant specialized in analyzing images in the context of tasks and projects. 
Your goal is to extract only the information from images that is relevant to the user's current task.

You have access to a function that can suggest checklist items be marked as completed.
If the image shows evidence that a checklist item from the task has been completed
(e.g., a screenshot showing a completed feature, test results, or deployment confirmation),
use the suggest_checklist_completion function to notify the user.''',
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
- Focus on actionable insights or important details
- If a browser window is visible in the image, extract and include the full URL from its address bar''',
  requiredInputData: [InputDataType.images, InputDataType.task],
  aiResponseType: AiResponseType.imageAnalysis,
  useReasoning: false,
  description: 'Analyze images specifically for task-relevant details',
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
Note any significant non-speech audio events [in brackets]. Remove filler words.
''',
  requiredInputData: [InputDataType.audioFiles],
  aiResponseType: AiResponseType.audioTranscription,
  useReasoning: false,
  description: 'Transcribe audio recordings into text format',
);

/// Audio Transcription with Task Context prompt template
const audioTranscriptionWithTaskContextPrompt = PreconfiguredPrompt(
  name: 'Audio Transcription with Task Context',
  systemMessage: '''
You are a helpful AI assistant that transcribes audio content. 
Your goal is to provide accurate, well-formatted transcriptions of audio recordings.

You have access to a function that can suggest checklist items be marked as completed.
When transcribing audio in the context of a task, listen for evidence that checklist items 
have been completed. This might include statements like "I finished...", "I've completed...", 
"That's done", or descriptions of completed work. Use the suggest_checklist_completion 
function to notify the user when you detect such evidence.''',
  userMessage: '''
Please transcribe the provided audio. 
Format the transcription clearly with proper punctuation and paragraph breaks where appropriate. 
If there are multiple speakers, try to indicate speaker changes. 
Note any significant non-speech audio events [in brackets]. Remove filler words.

Take into account the following task context:

**Task Context:**
```json
{{task}}
```

The task context will provide additional information about the task, such as the project, 
goal, and any relevant details such as names of people or places. If in doubt 
about names or concepts mentioned in the audio, then the task context should
be consulted to ensure accuracy.
''',
  requiredInputData: [InputDataType.audioFiles, InputDataType.task],
  aiResponseType: AiResponseType.audioTranscription,
  useReasoning: false,
  description:
      'Transcribe audio recordings into text format, taking into account task context',
);
