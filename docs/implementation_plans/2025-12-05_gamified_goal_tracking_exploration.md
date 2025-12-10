# Gamified Goal Tracking — Exploration Plan

## Vision Summary

A gamified goal tracking system where users:
- Declare goals with deadlines and milestones
- Define tangible rewards for goal completion (e.g., wine, ice cream, vacation, BMW X5 PHV)
- Receive scheduled check-in prompts (daily, weekly, or custom)
- Self-assess progress with structured reflection (what went well, what could improve)
- Link key habits to goals (with win/loss tracking, not just checkboxes)
- View a dashboard showing "health" of each goal
- Interact conversationally with AI for goal coaching
- Potentially use Gen UI for dynamic, generated interfaces per goal

The system should feel emotionally engaging and frictionless, primarily using voice input with AI assistance.

---

## Goals (Meta)

- Gamify goal pursuit with rewards, milestones, and emotional stakes
- Enable frictionless input (voice-first, AI-assisted)
- Provide accountability via scheduled check-ins with notifications
- Surface goal health in a scannable dashboard (fits on one screen)
- Link habits to goals with win/loss tracking
- Generate AI summaries of progress over time
- Support limited concurrent goals (1-4 active) to maintain focus

## Non-Goals (For This Exploration)

- Replacing the existing habit system (habits remain independent but can link to goals)
- Social/sharing features
- Integration with external productivity tools
- Complex dependency graphs between goals

---

## Route Analysis

We identify four primary architectural routes, plus variations on gamification and AI integration.

---

## Route A: Extend the Habit System

### Concept

Treat goals as "meta-habits" with an extended data model. Habits already have:
- Schedules (daily/weekly/monthly)
- Completion tracking (success/skip/fail)
- Streak counting
- Dashboard integration
- Notifications

Goals would become a new habit variant with:
- Deadline
- Milestones as sub-habits
- Reward definition
- Check-in entries instead of completion entries

### Architecture

```
HabitDefinition (existing)
  └─ Extended with:
       ├─ habitType: 'habit' | 'goal'
       ├─ deadline: DateTime?
       ├─ milestones: List<Milestone>?
       ├─ reward: RewardDefinition?
       └─ checkInSchedule: CheckInSchedule?

HabitCompletionEntry → extended or new GoalCheckInEntry
```

### Pros

- Leverages existing habit infrastructure (UI, cubit, database)
- Minimal new entity types
- Habits already support dashboard integration
- Notification system already wired for habits
- Existing streak logic can be reused

### Cons

- Conflates two conceptually different things (habits = recurring, goals = finite)
- HabitDefinition becomes bloated with optional fields
- UI would need significant branching logic
- Check-ins are conceptually different from completions
- Risk of confusing users with "habit" terminology for goals

### Viability: ⚠️ Medium

Good for rapid prototyping but may create tech debt. The conceptual mismatch between recurring habits and deadline-bound goals suggests this is not the cleanest path.

### Key Files to Modify

- `lib/classes/entity_definitions.dart` (extend HabitDefinition)
- `lib/classes/journal_entities.dart` (extend or add entry type)
- `lib/blocs/habits/habits_cubit.dart`
- `lib/features/habits/ui/` (significant UI changes)
- `lib/services/notification_service.dart`

---

## Route B: First-Class Goal Entity (Recommended)

### Concept

Introduce `GoalDefinition` as a new entity definition type alongside `HabitDefinition`, `DashboardDefinition`, etc. Goals are distinct from habits but can reference them.

### Architecture

```dart
// New sealed class member in entity_definitions.dart
EntityDefinition.goal(
  GoalDefinition goal,
) = GoalDefinitionEntity;

@freezed
class GoalDefinition with _$GoalDefinition {
  const factory GoalDefinition({
    required String id,
    required String name,
    required String description,
    required DateTime deadline,
    required GoalStatus status,  // active, achieved, abandoned
    required List<Milestone> milestones,
    required RewardDefinition reward,
    required CheckInSchedule checkInSchedule,
    List<String>? linkedHabitIds,  // habits that contribute to this goal
    String? categoryId,
    bool? private,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _GoalDefinition;
}

@freezed
class Milestone with _$Milestone {
  const factory Milestone({
    required String id,
    required String title,
    required String? description,
    required DateTime? targetDate,
    required MilestoneStatus status,  // pending, achieved
    RewardDefinition? reward,  // optional milestone reward
  }) = _Milestone;
}

@freezed
class RewardDefinition with _$RewardDefinition {
  const factory RewardDefinition({
    required String title,
    String? description,
    String? imageUrl,  // for visual motivation
    RewardTier? tier,  // small, medium, large, epic
  }) = _RewardDefinition;
}

@freezed
sealed class CheckInSchedule with _$CheckInSchedule {
  const factory CheckInSchedule.daily({
    required DateTime alertAtTime,
  }) = DailyCheckIn;

  const factory CheckInSchedule.weekly({
    required int dayOfWeek,  // 1-7, Monday = 1
    required DateTime alertAtTime,
  }) = WeeklyCheckIn;

  const factory CheckInSchedule.custom({
    required Duration interval,
    DateTime? nextCheckIn,
  }) = CustomCheckIn;
}
```

### Journal Entry for Check-ins

```dart
// New entry type in journal_entities.dart
JournalEntity.goalCheckIn(
  Metadata meta,
  GoalCheckInData data,
  EntryText? entryText,
  Geolocation? geolocation,
) = GoalCheckInEntry;

@freezed
class GoalCheckInData with _$GoalCheckInData {
  const factory GoalCheckInData({
    required String goalId,
    required int progressRating,  // 1-5 or 1-10
    required String reflection,  // free-form or structured
    String? whatWentWell,
    String? whatCouldImprove,
    List<String>? accomplishments,
    DateTime? nextCheckInOverride,  // user can adjust next check-in
    GoalHealthSnapshot? healthSnapshot,  // AI-computed at check-in time
  }) = _GoalCheckInData;
}

@freezed
class GoalHealthSnapshot with _$GoalHealthSnapshot {
  const factory GoalHealthSnapshot({
    required double overallHealth,  // 0.0-1.0
    required double habitAdherence,  // linked habits win rate
    required double milestoneProgress,  // achieved/total
    required int daysRemaining,
    String? aiSummary,
  }) = _GoalHealthSnapshot;
}
```

### Database Changes

New tables in `database.drift`:

```sql
CREATE TABLE goal_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  serialized TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  private INTEGER NOT NULL DEFAULT 0,
  deadline INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
) AS GoalDefinitionDbEntity;

CREATE INDEX goal_deadline ON goal_definitions (deadline);
CREATE INDEX goal_status ON goal_definitions (status);
```

Check-in entries stored in existing `journal` table with `type = 'GoalCheckInEntry'`.

### State Management

New Riverpod providers:

```dart
// Goal definitions provider
@riverpod
class GoalDefinitionsController extends _$GoalDefinitionsController {
  @override
  Future<List<GoalDefinition>> build() async {
    // Watch active goals
  }
}

// Individual goal with check-ins
@riverpod
class GoalDetailController extends _$GoalDetailController {
  @override
  Future<GoalDetail> build(String goalId) async {
    // Fetch goal + recent check-ins + health
  }
}

// Goal health computation
@riverpod
class GoalHealthController extends _$GoalHealthController {
  @override
  Future<GoalHealth> build(String goalId) async {
    // Compute health from linked habits, milestones, check-ins
  }
}
```

### UI Components

```
lib/features/goals/
├── README.md
├── model/
│   └── goal_detail.dart
├── state/
│   ├── goal_definitions_controller.dart
│   ├── goal_detail_controller.dart
│   └── goal_health_controller.dart
├── repository/
│   └── goal_repository.dart
├── ui/
│   ├── pages/
│   │   ├── goals_page.dart          # Dashboard view
│   │   ├── goal_detail_page.dart    # Individual goal view
│   │   ├── goal_check_in_page.dart  # Check-in flow
│   │   └── goal_settings_page.dart  # Create/edit goal
│   └── widgets/
│       ├── goal_health_card.dart    # Health indicator
│       ├── goal_progress_ring.dart  # Visual progress
│       ├── milestone_list.dart      # Milestones view
│       ├── reward_display.dart      # Show reward
│       ├── check_in_prompt.dart     # Check-in modal
│       └── linked_habits_card.dart  # Linked habits status
└── helpers/
    └── goal_health_calculator.dart
```

### Pros

- Clean separation of concerns
- Goals are conceptually distinct from habits
- Can evolve independently
- Clear data model
- Follows existing patterns (HabitDefinition, DashboardDefinition)
- Syncs naturally with existing infrastructure

### Cons

- More upfront work
- New database table and migration
- New feature module to build
- More tests to write

### Viability: ✅ High

This is the recommended route. It provides the cleanest architecture and follows established patterns in the codebase.

### Key Files to Add/Modify

**New Files:**
- `lib/features/goals/` (entire feature module)
- `lib/classes/goal.dart` (data models)
- Database migration in `database.drift`

**Modified Files:**
- `lib/classes/entity_definitions.dart` (add GoalDefinition)
- `lib/classes/journal_entities.dart` (add GoalCheckInEntry)
- `lib/services/notification_service.dart` (add goal check-in scheduling)
- `lib/beamer/locations/` (add goals_location.dart)
- Navigation in `app_screen.dart`

---

## Route C: Task-Based Goals

### Concept

Model goals as special Tasks with child tasks representing milestones. Leverage the existing task infrastructure (status, priority, time tracking, summaries).

### Architecture

```dart
// Extend Task with goal-specific fields
Task {
  ...existing fields...
  GoalMetadata? goalMetadata,  // null for regular tasks
}

@freezed
class GoalMetadata with _$GoalMetadata {
  const factory GoalMetadata({
    required DateTime deadline,
    required RewardDefinition reward,
    required CheckInSchedule checkInSchedule,
    List<String>? linkedHabitIds,
  }) = _GoalMetadata;
}
```

Milestones are child tasks linked via `linked_entries`.

### Pros

- Leverages existing task UI and infrastructure
- Task summaries work automatically
- Time tracking included
- Linking system already exists

### Cons

- Tasks are designed for discrete work items, not ongoing pursuits
- Task status model (Open → Done) doesn't fit goal lifecycle
- Milestones as child tasks is clunky
- Task UI not designed for goal dashboard views
- Conflates "things to do" with "outcomes to achieve"

### Viability: ⚠️ Low-Medium

Technically possible but conceptually strained. Goals and tasks serve different purposes.

---

## Route D: Hybrid Entity with Linked Habits

### Concept

Goals as first-class entities (like Route B) but with deep integration with habits. Habits can be "promoted" to goal-linked status, making win/loss tracking more emotionally significant.

### Architecture

Same as Route B, plus:

```dart
@freezed
class LinkedHabit with _$LinkedHabit {
  const factory LinkedHabit({
    required String habitId,
    required double weight,  // contribution to goal health
    required bool isKeyHabit,  // highlighted in dashboard
  }) = _LinkedHabit;
}

// Extend HabitDefinition
HabitDefinition {
  ...existing...
  String? linkedGoalId,  // optional link back to goal
}

// Win/Loss becomes more emotional
HabitCompletionType {
  success → "WIN" 🏆
  skip → "SKIP" ⏭️
  fail → "LOSS" 💔
  open → "OPEN" ⏳
}
```

### Habit-Goal Health Integration

When a habit is linked to a goal:
- Success = contributes positively to goal health
- Fail = damages goal health
- UI shows goal context when completing habit

### Pros

- Deep integration between goals and habits
- Habits gain emotional weight when goal-linked
- Goal health reflects actual behavior
- Unified motivation system

### Cons

- More complex data model
- Bidirectional relationships to maintain
- More UI complexity

### Viability: ✅ High

This is essentially Route B with enhanced habit integration. Recommended as the full vision.

---

## Gamification Approaches

### Approach G1: Reward-Centric (Recommended)

Focus on the reward as the primary motivator:
- Visual reward display (image, description, tier)
- Progress toward "claiming" the reward
- Celebration animation on goal achievement
- Reward history (past rewards earned)

### Approach G2: Streak-Based

Leverage streak psychology:
- Check-in streaks
- Linked habit streaks
- Streak multipliers for goal health
- Streak recovery mechanics

### Approach G3: Points & Levels

Traditional gamification:
- XP for check-ins, habit completions, milestone achievements
- Levels with unlocks
- Badges/achievements

### Approach G4: Health Metaphor (Recommended)

Treat goals as living things:
- Goal "health" 0-100%
- Health influenced by: check-ins, linked habits, milestone progress
- Visual health indicator (color gradient, icon state)
- "Critical" state when health drops too low
- Recovery mechanics

**Recommendation:** Combine G1 (Reward-Centric) with G4 (Health Metaphor). This provides emotional stakes (reward) with ongoing feedback (health), without the complexity of points systems.

---

## AI Integration Options

### AI Option 1: Check-in Coaching (Recommended)

AI assists during check-ins:
- Structured prompts for reflection
- Suggestions based on past check-ins
- Encouragement and course correction
- Summary generation

### AI Option 2: Goal Definition Assistant

AI helps create goals:
- SMART goal refinement
- Milestone suggestions
- Reward tier recommendations
- Deadline reasonableness check

### AI Option 3: Conversational Goal Companion

Each goal has an AI "personality":
- Ongoing conversation about the goal
- Proactive check-ins
- Pattern recognition across entries
- Integration with existing AI chat feature

### AI Option 4: Gen UI (Exploratory)

Dynamic UI generation per goal:
- Unique visual theme per goal
- Generated motivational imagery
- Custom dashboard layouts
- Experimental: Use Gemini to generate Flutter widgets

**Recommendation:** Start with AI Option 1 (Check-in Coaching) and AI Option 2 (Goal Definition Assistant). These integrate naturally with existing AI infrastructure. Gen UI is interesting but experimental.

### AI Implementation Details

```dart
// New AI response types
AiResponseType {
  ...existing...
  goalCheckInCoaching,
  goalDefinitionAssistant,
  goalProgressSummary,
}

// Prompt templates
'goal_check_in_coaching': AiConfig.prompt(
  inputType: InputDataType.goal,
  outputType: AiResponseType.goalCheckInCoaching,
  systemMessage: '''
You are a supportive goal coach. The user is checking in on their progress
toward a goal. Help them reflect meaningfully on their progress, acknowledge
wins, and constructively address challenges. Be encouraging but honest.
''',
  userMessage: '''
Goal: {{goal_name}}
Deadline: {{deadline}}
Days remaining: {{days_remaining}}
Current health: {{health_percentage}}%
Recent check-ins: {{recent_checkins}}
Linked habits performance: {{habit_summary}}

User's reflection: {{user_input}}

Provide coaching feedback and suggestions for the coming period.
''',
),
```

---

## Notification & Check-in System

### Implementation Approach

Extend `NotificationService` with goal-aware scheduling:

```dart
// notification_service.dart additions
Future<void> scheduleGoalCheckIn(GoalDefinition goal) async {
  final schedule = goal.checkInSchedule;
  final nextTime = _computeNextCheckInTime(schedule);

  await scheduleNotification(
    id: goal.id.hashCode,
    title: 'Goal Check-in: ${goal.name}',
    body: 'Time to reflect on your progress',
    scheduledDate: nextTime,
    payload: 'goal_checkin:${goal.id}',
  );
}
```

### Deep Linking

When notification tapped:
1. Parse payload `goal_checkin:<goalId>`
2. Navigate to `GoalCheckInPage(goalId)`
3. Show structured check-in form with AI coaching

### Rescheduling

After each check-in:
1. User can accept default next check-in or override
2. Schedule next notification
3. Handle app restart by rescheduling all active goal check-ins in `get_it.dart`

---

## Dashboard Design Options

### Dashboard Option 1: Cards Grid (Recommended)

```
┌─────────────────────────────────────────┐
│  GOALS                          [+ Add] │
├─────────────────────────────────────────┤
│ ┌─────────────┐  ┌─────────────┐        │
│ │ 💰 Money    │  │ 📝 Blog     │        │
│ │ ████████░░  │  │ ██████░░░░  │        │
│ │ 80% health  │  │ 60% health  │        │
│ │ 45 days     │  │ 12 days     │        │
│ │ 🍷 Wine     │  │ 🍦 Ice cream│        │
│ └─────────────┘  └─────────────┘        │
│ ┌─────────────┐                         │
│ │ 💪 Health   │                         │
│ │ ██████████  │                         │
│ │ 95% health  │                         │
│ │ 90 days     │                         │
│ │ 🚗 BMW X5   │                         │
│ └─────────────┘                         │
└─────────────────────────────────────────┘
```

### Dashboard Option 2: List with Progress Bars

```
┌─────────────────────────────────────────┐
│  GOALS                                  │
├─────────────────────────────────────────┤
│ 💰 Client Project Delivery              │
│    ████████████████░░░░  80% │ 45d │ 🍷 │
├─────────────────────────────────────────┤
│ 📝 Publish Blog Post                    │
│    ████████████░░░░░░░░  60% │ 12d │ 🍦 │
├─────────────────────────────────────────┤
│ 💪 Reach Target Weight                  │
│    ██████████████████░░  95% │ 90d │ 🚗 │
└─────────────────────────────────────────┘
```

### Dashboard Option 3: Radial Health Display

```
       ┌────────────────┐
       │   ┌────┐       │
       │  /  💰  \  80% │
       │ │ Money │      │
       │  \      /      │
       │   └────┘       │
       │                │
  ┌────┴────┐    ┌────┴────┐
 /    📝    \   /    💪    \
│   Blog    │  │  Health   │
 \   60%   /    \   95%   /
  └────────┘     └────────┘
```

**Recommendation:** Start with Dashboard Option 1 (Cards Grid). It's scannable, fits the constraint of "one screen," and provides clear visual hierarchy.

---

## Win/Loss Habit Tracking

### Emotional Framing

Transform habit completion from checkbox to declaration:

```
Current:  [✓] Floss  [✓] Gym  [ ] Read

Proposed:
┌─────────────────────────────────────┐
│ Today's Habits                      │
├─────────────────────────────────────┤
│ 🦷 Floss          [DECLARE WIN] 🏆  │
│ 🏋️ Gym            [DECLARE WIN] 🏆  │
│ 📚 Read           [DECLARE LOSS] 💔 │
│                   [Still time...]    │
└─────────────────────────────────────┘
```

### Auto-Loss Behavior

When the day ends without a declaration:
- Auto-record as LOSS
- Notify user (optional): "You didn't declare a win for Gym yesterday"
- Impact goal health if linked

### Implementation

Extend `HabitCompletionEntry` display:
- "DECLARE WIN" button with celebration micro-animation
- "DECLARE LOSS" with acknowledgment animation
- Skip option for legitimate skips (travel, sick, etc.)

---

## Data Migration & Sync

### Migration Strategy

1. Add new tables/columns with migration
2. Existing data unaffected (goals are additive)
3. Sync via Matrix like other entities

### Sync Considerations

```dart
// Sync event types
'goal_definition_created'
'goal_definition_updated'
'goal_definition_deleted'
'goal_check_in_created'
```

Goals sync the same way as habits/tasks using the existing Matrix sync infrastructure.

---

## Testing Strategy

### Unit Tests

- `GoalDefinition` serialization/deserialization
- `GoalHealthCalculator` computation logic
- `CheckInSchedule` next time calculation
- Notification scheduling logic

### Widget Tests

- `GoalHealthCard` renders correctly for various health levels
- `GoalCheckInPage` form validation
- `GoalsDashboard` displays correct number of goals
- Milestone completion interactions
- Reward display variants

### Integration Tests

- Create goal → schedule notification → receive notification → complete check-in
- Link habit to goal → complete habit → goal health updates
- Achieve milestone → health and progress update

### AI Tests

- Check-in coaching prompt generation
- Goal definition assistant suggestions
- Summary generation accuracy

---

## Implementation Phases

### Phase 0: Foundation (Data Model)

1. Design and implement `GoalDefinition` data model
2. Design and implement `GoalCheckInData` entry type
3. Add database table and migration
4. Implement basic repository with CRUD operations
5. Unit tests for models and repository

### Phase 1: Core Goal Management

1. Create `GoalDefinitionsController` (Riverpod)
2. Build `GoalsPage` (dashboard view)
3. Build `GoalSettingsPage` (create/edit)
4. Implement milestone management UI
5. Reward definition UI
6. Widget tests

### Phase 2: Check-in System

1. Implement `CheckInSchedule` computation
2. Extend `NotificationService` for goal check-ins
3. Build `GoalCheckInPage` with structured form
4. Implement check-in history view
5. Add startup rescheduling in `get_it.dart`
6. Integration tests

### Phase 3: Health & Gamification

1. Implement `GoalHealthCalculator`
2. Build `GoalHealthCard` widget
3. Milestone progress tracking
4. Reward progress visualization
5. Goal achievement celebration flow
6. Widget tests

### Phase 4: Habit Linking

1. Add `linkedGoalId` to `HabitDefinition`
2. Modify habit completion UI for goal context
3. Win/Loss emotional framing
4. Health calculation with habit integration
5. Bidirectional navigation (goal → habits, habit → goal)

### Phase 5: AI Integration

1. Add goal-related AI response types
2. Create check-in coaching prompt
3. Create goal definition assistant prompt
4. Integrate AI into check-in flow
5. Goal progress summaries
6. Tests

### Phase 6: Polish & Gen UI (Experimental)

1. Animations and transitions
2. Accessibility audit
3. Localization
4. Gen UI experimentation (if pursuing)
5. Documentation

---

## Open Questions

1. **Goal Limit**: Should we enforce a maximum number of concurrent active goals (e.g., 4)?
   - Proposed: Yes, enforce limit with clear rationale ("focus is key")

2. **Habit Linking Direction**: Should habits know about goals, or only goals know about habits?
   - Proposed: Bidirectional – habits optionally link to goals, goals reference habit IDs

3. **Check-in Persistence**: Should check-ins be editable after submission?
   - Proposed: Allow editing within same day, then read-only

4. **Reward Claiming**: Is reward claiming a manual action, or automatic on goal achievement?
   - Proposed: Manual "claim reward" action with celebration

5. **Goal Abandonment**: How do users abandon goals without shame?
   - Proposed: "Archive" with optional reflection entry

6. **Gen UI Priority**: Should Gen UI exploration be Phase 6, or parallel track?
   - Proposed: Phase 6 (after core features stable)

7. **Feature Flag**: Should goals be gated behind a feature flag initially?
   - Proposed: Yes, `enableGoalsPageFlag`, default off until stable

8. **Category Integration**: Should goals be categorizable like other entities?
   - Proposed: Yes, same category system as habits

9. **Offline Check-ins**: How do scheduled notifications work when offline?
   - Proposed: Local notifications fire regardless; sync on reconnect

10. **Historical Goals**: How do we handle completed/archived goals for reflection?
    - Proposed: Separate "Past Goals" section with achievement history

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep | High | High | Strict phase gating, feature flag |
| Performance with many check-ins | Low | Medium | Pagination, efficient queries |
| Notification reliability | Medium | High | Platform-specific testing, fallback reminders |
| AI integration complexity | Medium | Medium | Start simple, iterate |
| User confusion with habits | Medium | Medium | Clear UI differentiation, onboarding |
| Sync conflicts with goals | Low | Medium | Existing conflict resolution applies |

---

## Recommendation Summary

**Recommended Route:** Route B (First-Class Goal Entity) with Route D enhancements (Habit Linking)

**Recommended Gamification:** Reward-Centric (G1) + Health Metaphor (G4)

**Recommended AI:** Check-in Coaching (AI1) + Goal Definition Assistant (AI2), with Conversational Companion (AI3) as future enhancement

**Recommended Dashboard:** Cards Grid (Option 1)

**Recommended Phases:** 0→1→2→3→4→5→6 as outlined, with feature flag gating

---

## Files to Add

```
lib/features/goals/
├── README.md
├── model/
│   ├── goal_detail.dart
│   └── goal_health.dart
├── state/
│   ├── goal_definitions_controller.dart
│   ├── goal_detail_controller.dart
│   ├── goal_health_controller.dart
│   └── goal_check_in_controller.dart
├── repository/
│   └── goal_repository.dart
├── ui/
│   ├── pages/
│   │   ├── goals_page.dart
│   │   ├── goal_detail_page.dart
│   │   ├── goal_check_in_page.dart
│   │   └── goal_settings_page.dart
│   └── widgets/
│       ├── goal_health_card.dart
│       ├── goal_progress_ring.dart
│       ├── milestone_list.dart
│       ├── milestone_item.dart
│       ├── reward_display.dart
│       ├── check_in_prompt.dart
│       ├── linked_habits_card.dart
│       ├── goal_dashboard_card.dart
│       └── win_loss_habit_button.dart
├── helpers/
│   ├── goal_health_calculator.dart
│   └── check_in_scheduler.dart
└── constants/
    └── goal_constants.dart

lib/classes/goal.dart  (Freezed models)
lib/beamer/locations/goals_location.dart
```

## Files to Modify

```
lib/classes/entity_definitions.dart  (add GoalDefinition)
lib/classes/journal_entities.dart    (add GoalCheckInEntry)
lib/database/database.drift          (add goal_definitions table)
lib/services/notification_service.dart (add goal check-in scheduling)
lib/features/habits/state/...        (optional linkedGoalId support)
lib/features/ai/util/preconfigured_prompts.dart (goal prompts)
lib/features/ai/state/consts.dart    (goal AI response types)
lib/widgets/app_bottom_nav.dart      (add Goals tab)
lib/beamer/beamer_app.dart           (add goals route)
lib/get_it.dart                      (goal notification rescheduling)
lib/l10n/*.arb                       (localization keys)
```

---

## Next Steps

1. Review this exploration document together
2. Decide on route (recommend Route B+D)
3. Decide on gamification approach (recommend G1+G4)
4. Decide on AI integration scope (recommend AI1+AI2 initially)
5. Decide on open questions
6. Create implementation plan for Phase 0
7. Begin implementation

---

## Implementation Discipline

- Always ensure the analyzer has no complaints and everything compiles
- Run formatter frequently
- Prefer running commands via the dart-mcp server
- Only move on to adding new files when already created tests are all green
- Write meaningful tests that assert on valuable information
- Aim for full coverage of every code path
- Every widget we touch should get close to full test coverage
- Add CHANGELOG entry
- Update feature README files to match reality
- In most cases prefer one test file for one implementation file
- When creating l10n labels edit the arb files
- Keep the checklist in the plan updated as items are completed
