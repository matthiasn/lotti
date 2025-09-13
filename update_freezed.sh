#!/bin/bash

# List of files to update
files=(
"/Users/mn/github/lotti/lib/features/ai_chat/models/chat_session.dart"
"/Users/mn/github/lotti/lib/features/ai/model/ai_config.dart"
"/Users/mn/github/lotti/lib/features/ai_chat/models/task_summary_tool.dart"
"/Users/mn/github/lotti/lib/features/ai_chat/models/chat_message.dart"
"/Users/mn/github/lotti/lib/features/speech/state/recorder_state.dart"
"/Users/mn/github/lotti/lib/features/categories/state/category_details_controller.dart"
"/Users/mn/github/lotti/lib/features/ai/model/ai_input.dart"
"/Users/mn/github/lotti/lib/features/ai/functions/task_functions.dart"
"/Users/mn/github/lotti/lib/features/ai/functions/checklist_completion_functions.dart"
"/Users/mn/github/lotti/lib/classes/task.dart"
"/Users/mn/github/lotti/lib/classes/entity_definitions.dart"
"/Users/mn/github/lotti/lib/blocs/theming/theming_state.dart"
"/Users/mn/github/lotti/lib/features/ai/ui/settings/ai_settings_filter_state.dart"
"/Users/mn/github/lotti/lib/blocs/sync/outbox_state.dart"
"/Users/mn/github/lotti/lib/blocs/journal/journal_page_state.dart"
"/Users/mn/github/lotti/lib/blocs/dashboards/dashboards_page_state.dart"
"/Users/mn/github/lotti/lib/classes/config.dart"
"/Users/mn/github/lotti/lib/classes/audio_note.dart"
"/Users/mn/github/lotti/lib/features/sync/model/sync_message.dart"
"/Users/mn/github/lotti/lib/features/sync/model/validation/config_form_state.dart"
"/Users/mn/github/lotti/lib/classes/journal_entities.dart"
"/Users/mn/github/lotti/lib/classes/checklist_item_data.dart"
"/Users/mn/github/lotti/lib/features/journal/model/entry_state.dart"
"/Users/mn/github/lotti/lib/classes/entry_link.dart"
"/Users/mn/github/lotti/lib/features/tasks/model/task_progress_state.dart"
"/Users/mn/github/lotti/lib/features/speech/state/player_state.dart"
"/Users/mn/github/lotti/lib/classes/tag_type_definitions.dart"
"/Users/mn/github/lotti/lib/classes/checklist_data.dart"
"/Users/mn/github/lotti/lib/classes/event_data.dart"
"/Users/mn/github/lotti/lib/blocs/habits/habits_state.dart"
"/Users/mn/github/lotti/lib/classes/health.dart"
"/Users/mn/github/lotti/lib/classes/geolocation.dart"
"/Users/mn/github/lotti/lib/classes/entry_text.dart"
"/Users/mn/github/lotti/lib/blocs/settings/habits/habit_settings_state.dart"
)

for file in "${files[@]}"; do
  # Update the file - add abstract before class
  sed -i '' 's/@freezed[[:space:]]*\n[[:space:]]*class/@freezed\nabstract class/g' "$file"
done

echo "Updated all files"
