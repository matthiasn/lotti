import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';

TaskListData buildTaskListDetailMockData() {
  final work = _category(
    id: 'work',
    name: 'Work',
    color: '#4AB6E8',
    icon: CategoryIcon.work,
  );
  final study = _category(
    id: 'study',
    name: 'Study',
    color: '#FBA337',
    icon: CategoryIcon.school,
  );
  final leisure = _category(
    id: 'leisure',
    name: 'Leisure',
    color: '#E84D47',
    icon: CategoryIcon.social,
  );
  final meals = _category(
    id: 'meals',
    name: 'Meals',
    color: '#7AB889',
    icon: CategoryIcon.cooking,
  );
  final household = _category(
    id: 'household',
    name: 'Household',
    color: '#1F9CF5',
    icon: CategoryIcon.home,
  );
  final meeting = _category(
    id: 'meeting',
    name: 'Meeting',
    color: '#C1C700',
    icon: CategoryIcon.meeting,
  );

  return TaskListData(
    currentTime: DateTime(2026, 4, 1, 10, 30),
    categories: [
      work,
      study,
      leisure,
      meals,
      household,
      meeting,
    ],
    tasks: [
      _taskRecord(
        id: 'user-testing',
        category: study,
        title: 'User Testing',
        projectTitle: 'Customer Journey Validation',
        sectionTitle: 'Today',
        sectionDate: DateTime(2026, 4),
        createdAt: DateTime(2026, 4, 1, 8),
        due: DateTime(2026, 4),
        priority: TaskPriority.p2Medium,
        status: _taskBlocked(DateTime(2026, 4, 1, 9), 'Recruiting gap'),
        timeRange: '8:00-9:30am',
        labels: const [],
        aiSummary:
            'Recruiting fell short this morning. Move the remaining interviews to tomorrow and reuse the payment flow prototype for the final pass.',
        description:
            'Validate the onboarding and checkout steps with a fresh batch of participants before the QA handoff.',
        trackedDurationLabel: '6m 10s',
        trackerEntries: const [
          TaskShowcaseTimeEntry(
            title: 'Session 1 of 1',
            subtitle: '1 Apr 26, 09:12',
            durationLabel: '6m 10s',
            note:
                'Prepared prompts, aligned note-taking, and captured the final blocker for the next iteration.',
            active: true,
          ),
        ],
        checklistItems: const [
          TaskShowcaseChecklistItem(
            title: 'Confirm remaining interview slots',
            done: false,
          ),
        ],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'payment-confirmation',
        category: work,
        title: 'Payment confirmation',
        projectTitle: 'Device Sync - Lotti Mobile App Implementation',
        sectionTitle: 'Today',
        sectionDate: DateTime(2026, 4),
        createdAt: DateTime(2026, 4, 1, 10),
        due: DateTime(2026, 4),
        priority: TaskPriority.p1High,
        status: _taskOpen(DateTime(2026, 4, 1, 10)),
        timeRange: '10:00-11:30am',
        labels: const [
          TaskShowcaseLabel(
            id: 'bug-fix',
            label: 'Bug fix',
            color: Color(0xFF1F9CF5),
          ),
          TaskShowcaseLabel(
            id: 'release-blocker',
            label: 'Release blocker',
            color: Color(0xFFFBA337),
          ),
        ],
        aiSummary:
            'TLDR: The fix for the payment status bug is currently sitting on the main branch. Your next step is to push this work to the QA environment for final testing before a production release.',
        description:
            'We are excited to announce a new initiative aimed at enhancing user experience by implementing payment confirmation across all platforms. This improvement will ensure that every transaction is securely verified, providing our users with peace of mind and a seamless experience. Stay tuned for more updates!',
        trackedDurationLabel: '11m 38s',
        trackerEntries: const [
          TaskShowcaseTimeEntry(
            title: 'Session 1 of 2',
            subtitle: '1 Aug 26, 11:45',
            durationLabel: '7m 24s',
            note:
                'It centered around fixing the bug in the payment status update within the admin solution.',
          ),
          TaskShowcaseTimeEntry(
            title: 'Session 2 of 2',
            subtitle: '1 Aug 26, 11:45',
            durationLabel: '4m 14s',
            note:
                'It centered around fixing the bug in the payment status update within the admin solution.',
          ),
        ],
        checklistItems: const [
          TaskShowcaseChecklistItem(
            title: 'Fix payment status update bug',
            done: false,
          ),
          TaskShowcaseChecklistItem(
            title: 'Fix handover status update bug',
            done: false,
          ),
        ],
        audioEntries: const [
          TaskShowcaseAudioEntry(
            title: 'Recording 1',
            subtitle: '1 Aug 26, 11:45',
            durationLabel: '01:59',
            transcriptPreview:
                'So this is my recording for the new task I’m about to work on. It centered around fixing the bug in the payment status update within the admin solution.',
            waveform: [
              0.24,
              0.58,
              0.73,
              0.45,
              0.67,
              0.8,
              0.48,
              0.69,
              0.78,
              0.52,
              0.3,
            ],
          ),
          TaskShowcaseAudioEntry(
            title: 'Recording 2',
            subtitle: '2 Aug 26, 14:30',
            durationLabel: '03:22',
            transcriptPreview:
                'So I’m proposing to push the fix I worked on to the main branch to QA, then I’ll progress it to the production branch as well.',
            waveform: [
              0.18,
              0.42,
              0.76,
              0.54,
              0.36,
              0.72,
              0.82,
              0.64,
              0.46,
              0.7,
              0.61,
            ],
          ),
          TaskShowcaseAudioEntry(
            title: 'Recording 3',
            subtitle: '2 Aug 26, 09:15',
            durationLabel: '00:45',
            transcriptPreview:
                'Need to double-check the QA status after the payment confirmation patch lands.',
            waveform: [
              0.16,
              0.26,
              0.43,
              0.69,
              0.4,
              0.58,
              0.72,
              0.35,
              0.22,
              0.4,
              0.63,
            ],
          ),
        ],
      ),
      _taskRecord(
        id: 'team-lunch',
        category: leisure,
        title: 'Team Lunch',
        projectTitle: 'Ops Planning',
        sectionTitle: 'Today',
        sectionDate: DateTime(2026, 4),
        createdAt: DateTime(2026, 4, 1, 12),
        due: DateTime(2026, 4),
        priority: TaskPriority.p3Low,
        status: _taskOnHold(DateTime(2026, 4, 1, 12), 'Waiting on RSVPs'),
        timeRange: '12:30-1:15pm',
        labels: const [],
        aiSummary: 'Pause until the venue shortlist is confirmed.',
        description: 'Coordinate lunch logistics and confirm final attendees.',
        trackedDurationLabel: '0m',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'design-meeting',
        category: meals,
        title: 'Design Meeting',
        projectTitle: 'Weekly Menu Review',
        sectionTitle: 'Yesterday',
        sectionDate: DateTime(2026, 3, 31),
        createdAt: DateTime(2026, 3, 31, 9),
        due: DateTime(2026, 3, 31),
        priority: TaskPriority.p2Medium,
        status: _taskOpen(DateTime(2026, 3, 31, 9)),
        timeRange: '9:00-10:00am',
        labels: const [],
        aiSummary: 'Review the draft and send final notes.',
        description: 'Align on the remaining layout feedback with the team.',
        trackedDurationLabel: '3m 08s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'client-meeting',
        category: meals,
        title: 'Client Meeting',
        projectTitle: 'Partner Planning',
        sectionTitle: 'Yesterday',
        sectionDate: DateTime(2026, 3, 31),
        createdAt: DateTime(2026, 3, 31, 14),
        due: DateTime(2026, 3, 31),
        priority: TaskPriority.p2Medium,
        status: _taskOpen(DateTime(2026, 3, 31, 14)),
        timeRange: '2:00-3:30pm',
        labels: const [],
        aiSummary: 'Open items remain around scheduling.',
        description: 'Prepare follow-ups for the remaining action items.',
        trackedDurationLabel: '5m 21s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'investor-meeting',
        category: meals,
        title: 'Investor Meeting',
        projectTitle: 'Weekly Finance Review',
        sectionTitle: 'Dec 26, 2024',
        sectionDate: DateTime(2024, 12, 26),
        createdAt: DateTime(2024, 12, 26, 11),
        due: DateTime(2024, 12, 26),
        priority: TaskPriority.p2Medium,
        status: _taskOpen(DateTime(2024, 12, 26, 11)),
        timeRange: '11:00am-12:00pm',
        labels: const [],
        aiSummary: 'Deck updates are ready for review.',
        description: 'Confirm the final finance narrative and slides.',
        trackedDurationLabel: '9m 11s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'code-review',
        category: household,
        title: 'Code Review',
        projectTitle: 'Household Automations',
        sectionTitle: 'Dec 26, 2024',
        sectionDate: DateTime(2024, 12, 26),
        createdAt: DateTime(2024, 12, 26, 15),
        due: DateTime(2024, 12, 26),
        priority: TaskPriority.p3Low,
        status: _taskOnHold(DateTime(2024, 12, 26, 15), 'Awaiting patch'),
        timeRange: '3:00-5:00pm',
        labels: const [],
        aiSummary: 'Blocked until the follow-up patch arrives.',
        description: 'Review the automation patch once the updated diff lands.',
        trackedDurationLabel: '0m',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'sprint-planning',
        category: work,
        title: 'Sprint Planning',
        projectTitle: 'Lotti Mobile App Implementation',
        sectionTitle: 'Dec 04, 2024',
        sectionDate: DateTime(2024, 12, 4),
        createdAt: DateTime(2024, 12, 4, 9),
        due: DateTime(2024, 12, 4),
        priority: TaskPriority.p1High,
        status: _taskGroomed(DateTime(2024, 12, 4, 9)),
        timeRange: '9:30-11:00am',
        labels: const [],
        aiSummary: 'The sprint backlog is groomed and ready.',
        description: 'Finalize scope and assignment before kickoff.',
        trackedDurationLabel: '12m 02s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'customer-onboarding',
        category: work,
        title: 'Customer Onboarding',
        projectTitle: 'Lotti Mobile App Implementation',
        sectionTitle: 'Dec 04, 2024',
        sectionDate: DateTime(2024, 12, 4),
        createdAt: DateTime(2024, 12, 4, 13),
        due: DateTime(2024, 12, 4),
        priority: TaskPriority.p1High,
        status: _taskGroomed(DateTime(2024, 12, 4, 13)),
        timeRange: '1:00-2:30pm',
        labels: const [],
        aiSummary: 'Prep is complete and ready for handoff.',
        description:
            'Close the onboarding checklist and ship the handoff note.',
        trackedDurationLabel: '4m 09s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'team-presentation',
        category: study,
        title: 'Team Presentation',
        projectTitle: 'Internal Learning',
        sectionTitle: 'Nov 2024',
        sectionDate: DateTime(2024, 11, 20),
        createdAt: DateTime(2024, 11, 20, 10),
        due: DateTime(2024, 11, 20),
        priority: TaskPriority.p2Medium,
        status: _taskBlocked(DateTime(2024, 11, 20, 10), 'Need final deck'),
        timeRange: '10:00-11:00am',
        labels: const [],
        aiSummary: 'Deck is blocked until the final examples arrive.',
        description:
            'Update the internal presentation with the latest examples.',
        trackedDurationLabel: '0m',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
      _taskRecord(
        id: 'marketing-campaign',
        category: meeting,
        title: 'Marketing Campaign',
        projectTitle: 'Launch Coordination',
        sectionTitle: 'Nov 2024',
        sectionDate: DateTime(2024, 11, 20),
        createdAt: DateTime(2024, 11, 20, 14),
        due: DateTime(2024, 11, 20),
        priority: TaskPriority.p1High,
        status: _taskOpen(DateTime(2024, 11, 20, 14)),
        timeRange: '2:00-4:00pm',
        labels: const [],
        aiSummary: 'Ready for the final review round.',
        description: 'Prepare launch assets and scheduling details.',
        trackedDurationLabel: '7m 46s',
        trackerEntries: const [],
        checklistItems: const [],
        audioEntries: const [],
      ),
    ],
  );
}

DesignSystemTaskFilterState buildTaskShowcaseFilterState() {
  return DesignSystemTaskFilterState(
    title: 'Apply filter',
    clearAllLabel: 'Clear all',
    applyLabel: 'Apply',
    sortLabel: 'Sort by',
    sortOptions: const [
      DesignSystemTaskFilterOption(
        id: 'due-date',
        label: 'Due Date',
      ),
      DesignSystemTaskFilterOption(
        id: 'created-date',
        label: 'Created',
      ),
      DesignSystemTaskFilterOption(
        id: 'priority',
        label: 'Priority',
      ),
    ],
    selectedSortId: 'due-date',
    statusField: const DesignSystemTaskFilterFieldState(
      label: 'Status',
      options: [
        DesignSystemTaskFilterOption(id: 'open', label: 'Open'),
        DesignSystemTaskFilterOption(id: 'in-progress', label: 'In Progress'),
        DesignSystemTaskFilterOption(id: 'blocked', label: 'Blocked'),
        DesignSystemTaskFilterOption(id: 'on-hold', label: 'On Hold'),
      ],
    ),
    priorityLabel: 'Priority',
    priorityOptions: const [
      DesignSystemTaskFilterOption(
        id: 'p0',
        label: 'P0',
        glyph: DesignSystemTaskFilterGlyph.priorityP0,
      ),
      DesignSystemTaskFilterOption(
        id: 'p1',
        label: 'P1',
        glyph: DesignSystemTaskFilterGlyph.priorityP1,
      ),
      DesignSystemTaskFilterOption(
        id: 'p2',
        label: 'P2',
        glyph: DesignSystemTaskFilterGlyph.priorityP2,
      ),
      DesignSystemTaskFilterOption(
        id: 'p3',
        label: 'P3',
        glyph: DesignSystemTaskFilterGlyph.priorityP3,
      ),
      DesignSystemTaskFilterOption(
        id: DesignSystemTaskFilterState.allPriorityId,
        label: 'All',
      ),
    ],
    selectedPriorityId: DesignSystemTaskFilterState.allPriorityId,
    categoryField: const DesignSystemTaskFilterFieldState(
      label: 'Category',
      options: [
        DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
        DesignSystemTaskFilterOption(id: 'study', label: 'Study'),
        DesignSystemTaskFilterOption(id: 'leisure', label: 'Leisure'),
        DesignSystemTaskFilterOption(id: 'meals', label: 'Meals'),
        DesignSystemTaskFilterOption(id: 'household', label: 'Household'),
        DesignSystemTaskFilterOption(id: 'meeting', label: 'Meeting'),
      ],
    ),
    labelField: const DesignSystemTaskFilterFieldState(
      label: 'Labels',
      options: [
        DesignSystemTaskFilterOption(id: 'bug-fix', label: 'Bug fix'),
        DesignSystemTaskFilterOption(
          id: 'release-blocker',
          label: 'Release blocker',
        ),
        DesignSystemTaskFilterOption(id: 'qa', label: 'QA'),
      ],
    ),
  );
}

CategoryDefinition _category({
  required String id,
  required String name,
  required String color,
  required CategoryIcon icon,
}) {
  final createdAt = DateTime(2026, 3, 30, 8);
  return EntityDefinition.categoryDefinition(
        id: id,
        createdAt: createdAt,
        updatedAt: createdAt,
        name: name,
        vectorClock: null,
        private: false,
        active: true,
        color: color,
        icon: icon,
      )
      as CategoryDefinition;
}

TaskRecord _taskRecord({
  required String id,
  required CategoryDefinition category,
  required String title,
  required String projectTitle,
  required String sectionTitle,
  required DateTime sectionDate,
  required DateTime createdAt,
  required DateTime due,
  required TaskPriority priority,
  required TaskStatus status,
  required String timeRange,
  required List<TaskShowcaseLabel> labels,
  required String aiSummary,
  required String description,
  required String trackedDurationLabel,
  required List<TaskShowcaseTimeEntry> trackerEntries,
  required List<TaskShowcaseChecklistItem> checklistItems,
  required List<TaskShowcaseAudioEntry> audioEntries,
}) {
  final task =
      JournalEntity.task(
            meta: Metadata(
              id: id,
              createdAt: createdAt,
              updatedAt: createdAt,
              dateFrom: createdAt,
              dateTo: createdAt.add(const Duration(minutes: 30)),
              categoryId: category.id,
            ),
            data: TaskData(
              status: status,
              statusHistory: const [],
              title: title,
              dateFrom: createdAt,
              dateTo: createdAt.add(const Duration(minutes: 30)),
              due: due,
              priority: priority,
            ),
            entryText: EntryText(
              plainText: '$projectTitle\n$description\n$timeRange',
            ),
          )
          as Task;

  return TaskRecord(
    task: task,
    category: category,
    sectionTitle: sectionTitle,
    sectionDate: sectionDate,
    projectTitle: projectTitle,
    timeRange: timeRange,
    labels: labels,
    aiSummary: aiSummary,
    description: description,
    trackedDurationLabel: trackedDurationLabel,
    trackerEntries: trackerEntries,
    checklistItems: checklistItems,
    audioEntries: audioEntries,
  );
}

TaskStatus _taskOpen(DateTime createdAt) {
  return TaskStatus.open(
    id: 'open-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
  );
}

TaskStatus _taskBlocked(DateTime createdAt, String reason) {
  return TaskStatus.blocked(
    id: 'blocked-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
    reason: reason,
  );
}

TaskStatus _taskOnHold(DateTime createdAt, String reason) {
  return TaskStatus.onHold(
    id: 'on-hold-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
    reason: reason,
  );
}

TaskStatus _taskGroomed(DateTime createdAt) {
  return TaskStatus.groomed(
    id: 'groomed-${createdAt.microsecondsSinceEpoch}',
    createdAt: createdAt,
    utcOffset: 0,
  );
}
