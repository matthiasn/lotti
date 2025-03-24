String createActionItemSuggestionsPrompt(String jsonString) {
  return '''
**Prompt:**

"Based on the provided task details and log entries, identify potential action items that are mentioned in
the text of the logs but have not yet been captured as existing action items. These suggestions should be
formatted as a list of new `AiInputActionItemObject` instances, each containing a title and completion
status. Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format, adhering to the structure defined by the given classes."

**Task Details:**
```json
$jsonString
```

Provide these suggested action items in JSON format, adhering to the structure 
defined by the given classes.
Double check that the returned JSON ONLY contains action items that are not 
already listed under `actionItems` array in the task details. Do not simply
return the example response, but the open action items you have found. If there 
are none, return an empty array. Double check the items you want to return. If 
any is very similar to an item already listed in the in actionItems array of the 
task details, then remove it from the response. 

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
```
    ''';
}

String createTaskSummaryPrompt(String jsonString) {
  return '''
**Prompt:**

Create a task summary as a TLDR; for the provided task details and log entries. Imagine the
user has not been involved in the task for a long time, and you want to refresh
their memory. Summarize the task, the achieved results, and the remaining steps
that have not been completed yet, if any. Also note when the task is done. Note any 
learnings or insights that can be drawn from the task, if anything is 
significant. Talk to the user directly, instead of referring to them as "the user"
or "they". Don't start with a greeting, don't repeat the task title, get straight 
to the point. Keep it short and succinct. Assume the the task title is shown 
directly above in the UI, so starting with the title is not necessary and would 
feel redundant. While staying succinct, give the output some structure and 
organization. Use a bullet point list for the achieved results, and a numbered 
list for the remaining steps. If there are any learnings or insights that can be 
drawn from the task, include them in the output. If the task is done, end the 
output with a concluding statement.

Try to use emojis instead of individual list item bullet points, e.g. ✅ for completed 
items, or 💡for learnings, 🤯 for annoyances, etc. Use the emojis on the individual 
list item, not on the headline for each list section.

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
$jsonString
```
    ''';
}
