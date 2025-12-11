# Task Filtering in Lotti

This guide walks you through using filters to organize and find your tasks in Lotti. Learn how to focus on what matters most using status, priority, category, and label filters.

| What You'll Learn | Description |
|-------------------|-------------|
| **Accessing Filters** | Open the filter panel from the Tasks page |
| **Status Filtering** | Show tasks by their current status |
| **Priority Filtering** | Focus on urgent or important tasks |
| **Category Filtering** | View tasks from specific projects or areas |
| **Label Filtering** | Find tasks with specific tags |
| **Filter Persistence** | Your filters are saved automatically |

---

## Part 1: Understanding Task Filters

Before diving in, here's how filtering works in Lotti:

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  All Your Tasks │ ──▶ │  Apply Filters  │ ──▶ │  Focused View   │
│  (Full List)    │     │  (Your Choice)  │     │  (Matching Only)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

Filters help you narrow down your task list to show only what's relevant right now. Multiple filters combine to give you precise control.

---

## Part 2: Accessing the Filter Panel

### Step 1: Navigate to the Tasks Page

1. Launch Lotti on your device
2. Tap the **Tasks** icon in the bottom navigation bar
3. You'll see your task list with the default filters applied

<!-- Screenshot: Tasks page showing the task list with navigation bar visible -->
![Tasks Page](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/tasks_page.png)

### Step 2: Open the Filter Panel

1. Look for the **filter icon** (funnel) in the top-right corner of the Tasks page
2. Tap the filter icon to open the filter panel
3. A modal appears with all available filter options

<!-- Screenshot: Filter icon location in the app bar -->
![Filter Icon](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/filter_icon.png)

### Step 3: Understand the Filter Panel Layout

The filter panel contains several sections:

| Section | Purpose |
|---------|---------|
| **Journal Filter** | Toggle starred, flagged, or private entries |
| **Status Filter** | Filter by task status (Open, Done, etc.) |
| **Priority Filter** | Filter by priority level (P0-P3) |
| **Category Filter** | Filter by project or area category |
| **Label Filter** | Filter by assigned labels |

<!-- Screenshot: Full filter panel showing all sections -->
![Filter Panel](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/filter_panel.png)

---

## Part 3: Filtering by Task Status

Task status indicates where a task is in its lifecycle. By default, Lotti shows active tasks (Open, Groomed, In Progress).

### Available Task Statuses

| Status | Color | Description |
|--------|-------|-------------|
| **Open** | Orange | New tasks waiting to be worked on |
| **Groomed** | Light Green | Tasks that have been reviewed and prioritized |
| **In Progress** | Blue | Tasks currently being worked on |
| **Blocked** | Red | Tasks that can't proceed due to dependencies |
| **On Hold** | Red | Tasks temporarily paused |
| **Done** | Green | Completed tasks |
| **Rejected** | Red | Tasks that were cancelled or declined |

<!-- Screenshot: Status filter section with chips showing all statuses -->
![Status Filter](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/status_filter.png)

### How to Filter by Status

1. In the filter panel, find the **Status** section
2. **Tap a status chip** to toggle it on/off
3. Selected statuses appear highlighted
4. Tasks matching ANY selected status will appear

**Quick Actions:**
- **Tap "All"** to select all statuses at once
- **Long-press a status** to select ONLY that status

<!-- Screenshot: Status filter with some statuses selected and others deselected -->
![Status Selection](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/status_selection.png)

### Common Status Filter Scenarios

| Goal | Select These Statuses |
|------|----------------------|
| See only active work | Open, Groomed, In Progress |
| Review completed tasks | Done |
| Find blocked items | Blocked, On Hold |
| See everything | All |

---

## Part 4: Filtering by Priority

Priority helps you focus on urgent or important tasks first.

### Priority Levels

| Priority | Label | Color | Use For |
|----------|-------|-------|---------|
| **P0** | Urgent | Red | Critical issues, immediate attention needed |
| **P1** | High | Orange | Important tasks, do soon |
| **P2** | Medium | Blue | Standard priority (default for new tasks) |
| **P3** | Low | Grey | Nice-to-have, do when time permits |

<!-- Screenshot: Priority filter section showing P0-P3 chips -->
![Priority Filter](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/priority_filter.png)

### How to Filter by Priority

1. In the filter panel, find the **Priority** section
2. **Tap a priority chip** to toggle it on/off
3. When no priorities are selected, all tasks show (no filter applied)
4. Selected priorities appear highlighted

**Quick Action:**
- **Tap "All"** to clear priority filtering (show all priorities)

<!-- Screenshot: Priority filter with P0 and P1 selected -->
![Priority Selection](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/priority_selection.png)

### Priority Filter Tips

| Scenario | Recommended Filter |
|----------|-------------------|
| Morning planning | P0, P1 (focus on urgent/high) |
| End of day wrap-up | P2, P3 (tackle smaller items) |
| Crisis mode | P0 only |
| Full overview | All (no filter) |

---

## Part 5: Filtering by Category

Categories organize tasks by project, area of life, or any grouping you define.

### Understanding Categories

- Categories are defined in **Settings** → **Categories**
- Each task can belong to one category (or none)
- Categories can have custom colors for visual distinction
- You can mark categories as **favorites** for quick access

<!-- Screenshot: Category filter section showing several category chips -->
![Category Filter](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/category_filter.png)

### How to Filter by Category

1. In the filter panel, find the **Category** section
2. By default, favorite categories are shown
3. **Tap "..."** to expand and see all categories
4. **Tap a category chip** to toggle it on/off
5. Tasks matching ANY selected category will appear

**Special Options:**
- **"Unassigned"** - Shows tasks without any category
- **"All"** - Clears category filtering (shows all categories)

<!-- Screenshot: Expanded category filter showing all available categories -->
![Category Expanded](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/category_expanded.png)

### Category Filter Examples

| Use Case | Categories to Select |
|----------|---------------------|
| Focus on work | Work, Projects |
| Personal time | Personal, Health, Home |
| Find uncategorized tasks | Unassigned |
| See everything | All |

---

## Part 6: Filtering by Labels

Labels provide flexible tagging for cross-cutting concerns that span multiple categories.

### Understanding Labels

- Labels are defined in **Settings** → **Labels**
- A task can have multiple labels (unlike categories)
- Labels have custom colors for visual identification
- Use labels for things like: `urgent`, `waiting-on`, `quick-win`, `review-needed`

<!-- Screenshot: Label filter section showing several label chips -->
![Label Filter](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/label_filter.png)

### How to Filter by Labels

1. In the filter panel, find the **Label** section
2. First 8 labels are shown by default
3. **Tap "..."** to expand and see all labels
4. **Tap a label chip** to toggle it on/off
5. Tasks with ANY selected label will appear

**Special Options:**
- **"Unlabeled"** - Shows tasks without any labels
- **"All"** - Clears label filtering (shows all tasks)

<!-- Screenshot: Label filter with some labels selected -->
![Label Selection](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/label_selection.png)

### Label Quick Filter

When you have active label filters, a **quick filter bar** appears below the search bar:

- Shows currently active label filters
- Displays filter count
- **Tap X** on individual labels to remove them quickly
- **Tap the clear button** to remove all label filters

<!-- Screenshot: Quick filter bar showing active label filters below search -->
![Label Quick Filter](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/label_quick_filter.png)

---

## Part 7: Combining Multiple Filters

Filters work together to give you precise control over your task view.

### How Filters Combine

| Filter Type | Combination Logic |
|-------------|-------------------|
| **Within a filter** | OR (match any selected option) |
| **Between filters** | AND (must match all filter types) |

**Example:**
If you select:
- Status: `Open`, `In Progress`
- Priority: `P0`, `P1`
- Category: `Work`

You'll see tasks that are:
- (Open OR In Progress) AND (P0 OR P1) AND (Work category)

<!-- Screenshot: Filter panel with multiple filter types active -->
![Combined Filters](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/combined_filters.png)

### Filter Combination Examples

| Goal | Status | Priority | Category | Labels |
|------|--------|----------|----------|--------|
| Urgent work tasks | Open, In Progress | P0, P1 | Work | - |
| Completed personal items | Done | - | Personal | - |
| Blocked items needing review | Blocked | - | - | review-needed |
| Quick wins for today | Open | P2, P3 | - | quick-win |

---

## Part 8: Filter Persistence

Your filter selections are automatically saved and restored.

### What Gets Saved

| Setting | Persisted? |
|---------|-----------|
| Selected statuses | Yes |
| Selected priorities | Yes |
| Selected categories | Yes |
| Selected labels | Yes |
| Search text | No (clears on navigation) |
| Starred/Flagged toggles | No (runtime only) |

### How Persistence Works

1. **Automatic saving**: Filters save immediately when changed
2. **App restart**: Your filters are restored when you reopen Lotti
3. **Cross-session**: Filter preferences persist between sessions
4. **Per-tab**: Tasks and Journal tabs have separate filter settings

<!-- Screenshot: Tasks page showing restored filters after app restart -->
![Persisted Filters](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/persisted_filters.png)

---

## Part 9: Searching Tasks

In addition to filters, you can search tasks by text content.

### Using the Search Bar

1. **Tap the search icon** in the top app bar
2. **Type your search term**
3. Results update as you type
4. Search combines with your active filters

<!-- Screenshot: Search bar active with search results -->
![Search Bar](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/search_bar.png)

### What Search Covers

- Task titles
- Task descriptions
- Transcribed audio content
- Notes and journal text

> **Tip:** Combine search with filters for powerful queries. For example, search "meeting" with status "Done" to find completed meeting-related tasks.

---

## Part 10: Tips for Effective Filtering

### Daily Workflow Tips

| Time of Day | Recommended Filter Setup |
|-------------|-------------------------|
| **Morning** | Status: Open, In Progress; Priority: P0, P1 |
| **Focus time** | Single category; Status: In Progress |
| **End of day** | Status: Done (to review accomplishments) |
| **Weekly review** | All statuses; specific category |

### Filter Strategy Tips

| Tip | Why It Helps |
|-----|--------------|
| Use default filters for active tasks | See Open, Groomed, In Progress by default |
| Create focused categories | Makes filtering by project easy |
| Use labels for cross-cutting concerns | Tags like "urgent" work across categories |
| Review blocked tasks regularly | Filter by Blocked status weekly |

<!-- Screenshot: Well-organized task list with effective filter setup -->
![Effective Filtering](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_filtering/effective_filtering.png)

---

## Troubleshooting

### Common Issues

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| No tasks showing | Filters too restrictive | Tap "All" on each filter section |
| Can't find a task | Wrong status selected | Include "Done" or "Rejected" statuses |
| Missing category | Not marked as favorite | Tap "..." to see all categories |
| Filters reset unexpectedly | App update or data migration | Re-apply your preferred filters |

### Resetting Filters

To reset all filters to defaults:

1. Open the filter panel
2. Tap **"All"** on each filter section
3. Or select only: Open, Groomed, In Progress statuses

---

## Quick Reference Card

### Filter Panel Access
| Action | Steps |
|--------|-------|
| Open filters | Tap filter icon (funnel) in top-right |
| Close filters | Tap outside the panel or swipe down |

### Status Filter
| Action | Steps |
|--------|-------|
| Toggle status | Tap the status chip |
| Select only one | Long-press the status chip |
| Select all | Tap "All" chip |

### Priority Filter
| Action | Steps |
|--------|-------|
| Toggle priority | Tap the priority chip |
| Clear filter | Tap "All" chip |

### Category Filter
| Action | Steps |
|--------|-------|
| Toggle category | Tap the category chip |
| See all categories | Tap "..." to expand |
| Clear filter | Tap "All" chip |

### Label Filter
| Action | Steps |
|--------|-------|
| Toggle label | Tap the label chip |
| See all labels | Tap "..." to expand |
| Quick remove | Tap X on label in quick filter bar |
| Clear filter | Tap "All" chip |

---

## Next Steps

Now that you've mastered task filtering, explore these related features:

| Feature | Description | Where to Find |
|---------|-------------|---------------|
| **Creating Tasks** | Add new tasks to your list | **+** button → **Create Task** |
| **Task Statuses** | Change task status as you work | Task detail → Status dropdown |
| **Categories** | Create and manage categories | **Settings** → **Categories** |
| **Labels** | Create and manage labels | **Settings** → **Labels** |

← Back to [Main README](../README.md) | [Getting Started with AI](../GETTING_STARTED.md)

---

*This guide covers Lotti version 0.9.751 and later. UI may vary slightly between versions.*
