import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesktopTaskHeaderWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Desktop task header',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (_) => _HeaderFrame(
          child: DesktopTaskHeader(
            data: _fixtureData(),
            onTitleSaved: _noop,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Hover',
        builder: (_) => _HeaderFrame(
          child: DesktopTaskHeader(
            data: _fixtureData(),
            onTitleSaved: _noop,
            initialHover: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Editing',
        builder: (_) => _HeaderFrame(
          child: DesktopTaskHeader(
            data: _fixtureData(),
            onTitleSaved: _noop,
            initialEditing: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (_) => const _HeaderPlayground(),
      ),
    ],
  );
}

void _noop(String _) {}

final DateTime _fixtureCreatedAt = DateTime.utc(2026);

TaskStatus _statusOpen() => TaskStatus.open(
  id: 'fixture-open',
  createdAt: _fixtureCreatedAt,
  utcOffset: 0,
);

TaskStatus _statusInProgress() => TaskStatus.inProgress(
  id: 'fixture-in-progress',
  createdAt: _fixtureCreatedAt,
  utcOffset: 0,
);

TaskStatus _statusBlocked() => TaskStatus.blocked(
  id: 'fixture-blocked',
  createdAt: _fixtureCreatedAt,
  utcOffset: 0,
  reason: 'Waiting on API',
);

TaskStatus _statusOnHold() => TaskStatus.onHold(
  id: 'fixture-on-hold',
  createdAt: _fixtureCreatedAt,
  utcOffset: 0,
  reason: 'Paused',
);

TaskStatus _statusDone() => TaskStatus.done(
  id: 'fixture-done',
  createdAt: _fixtureCreatedAt,
  utcOffset: 0,
);

DesktopTaskHeaderData _fixtureData({
  String title = 'Payment confirmation',
  TaskPriority priority = TaskPriority.p1High,
  TaskStatus? status,
  bool showProject = true,
  bool showCategory = true,
  bool showDueDate = true,
  bool urgentDueDate = false,
  bool showLabels = true,
}) {
  return DesktopTaskHeaderData(
    title: title,
    priority: priority,
    status: status ?? _statusOpen(),
    project: showProject
        ? const DesktopTaskHeaderProject(
            label: 'Device Sync - Lotti Mobile App Implementation',
            icon: Icons.folder_outlined,
          )
        : null,
    category: showCategory
        ? const DesktopTaskHeaderCategory(
            label: 'Work',
            color: Color(0xFF1CA3E3),
            icon: Icons.work_outline_rounded,
          )
        : null,
    dueDate: showDueDate
        ? DesktopTaskHeaderDueDate(
            label: 'Due: Apr 1, 2026',
            isUrgent: urgentDueDate,
          )
        : null,
    labels: showLabels
        ? const [
            DesktopTaskHeaderLabel(
              id: 'bug-fix',
              label: 'Bug fix',
              color: Color(0xFF1CA3E3),
            ),
            DesktopTaskHeaderLabel(
              id: 'release-blocker',
              label: 'Release blocker',
              color: Color(0xFFFA8C05),
            ),
          ]
        : const [],
  );
}

/// Wraps the header in the page surface (level01) and a fixed-width
/// viewport that matches the Figma 1280px desktop layout.
class _HeaderFrame extends StatelessWidget {
  const _HeaderFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: WidgetbookViewport(
        width: 1280,
        child: ColoredBox(
          color: TaskShowcasePalette.page(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HeaderPlayground extends StatefulWidget {
  const _HeaderPlayground();

  @override
  State<_HeaderPlayground> createState() => _HeaderPlaygroundState();
}

class _HeaderPlaygroundState extends State<_HeaderPlayground> {
  static const _statusLabels = <String>[
    'Open',
    'In Progress',
    'Blocked',
    'On Hold',
    'Done',
  ];

  String _title = 'Payment confirmation';
  TaskPriority _priority = TaskPriority.p1High;
  int _statusIndex = 0;
  bool _showProject = true;
  bool _showCategory = true;
  bool _showDueDate = true;
  bool _showLabels = true;
  bool _urgentDueDate = false;
  bool _startHover = false;
  bool _startEditing = false;

  TaskStatus _statusFor(int index) {
    switch (index) {
      case 0:
        return _statusOpen();
      case 1:
        return _statusInProgress();
      case 2:
        return _statusBlocked();
      case 3:
        return _statusOnHold();
      case 4:
        return _statusDone();
    }
    return _statusOpen();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final data = _fixtureData(
      title: _title,
      priority: _priority,
      status: _statusFor(_statusIndex),
      showProject: _showProject,
      showCategory: _showCategory,
      showDueDate: _showDueDate,
      urgentDueDate: _urgentDueDate,
      showLabels: _showLabels,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: WidgetbookViewport(
        width: 1280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Controls(
              priority: _priority,
              onPriorityChanged: (p) => setState(() => _priority = p),
              statusIndex: _statusIndex,
              statusLabels: _statusLabels,
              onStatusIndexChanged: (i) => setState(() => _statusIndex = i),
              showProject: _showProject,
              onShowProjectChanged: (v) => setState(() => _showProject = v),
              showCategory: _showCategory,
              onShowCategoryChanged: (v) => setState(() => _showCategory = v),
              showDueDate: _showDueDate,
              onShowDueDateChanged: (v) => setState(() => _showDueDate = v),
              urgentDueDate: _urgentDueDate,
              onUrgentDueDateChanged: (v) => setState(() => _urgentDueDate = v),
              showLabels: _showLabels,
              onShowLabelsChanged: (v) => setState(() => _showLabels = v),
              startHover: _startHover,
              onStartHoverChanged: (v) => setState(() => _startHover = v),
              startEditing: _startEditing,
              onStartEditingChanged: (v) => setState(() => _startEditing = v),
            ),
            SizedBox(height: tokens.spacing.step6),
            ColoredBox(
              color: TaskShowcasePalette.page(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                child: DesktopTaskHeader(
                  // Rebuild whenever a knob forces a fresh initial state.
                  key: ValueKey('$_startHover:$_startEditing'),
                  data: data,
                  onTitleSaved: (next) => setState(() => _title = next),
                  initialHover: _startHover,
                  initialEditing: _startEditing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.priority,
    required this.onPriorityChanged,
    required this.statusIndex,
    required this.statusLabels,
    required this.onStatusIndexChanged,
    required this.showProject,
    required this.onShowProjectChanged,
    required this.showCategory,
    required this.onShowCategoryChanged,
    required this.showDueDate,
    required this.onShowDueDateChanged,
    required this.urgentDueDate,
    required this.onUrgentDueDateChanged,
    required this.showLabels,
    required this.onShowLabelsChanged,
    required this.startHover,
    required this.onStartHoverChanged,
    required this.startEditing,
    required this.onStartEditingChanged,
  });

  final TaskPriority priority;
  final ValueChanged<TaskPriority> onPriorityChanged;
  final int statusIndex;
  final List<String> statusLabels;
  final ValueChanged<int> onStatusIndexChanged;
  final bool showProject;
  final ValueChanged<bool> onShowProjectChanged;
  final bool showCategory;
  final ValueChanged<bool> onShowCategoryChanged;
  final bool showDueDate;
  final ValueChanged<bool> onShowDueDateChanged;
  final bool urgentDueDate;
  final ValueChanged<bool> onUrgentDueDateChanged;
  final bool showLabels;
  final ValueChanged<bool> onShowLabelsChanged;
  final bool startHover;
  final ValueChanged<bool> onStartHoverChanged;
  final bool startEditing;
  final ValueChanged<bool> onStartEditingChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _Dropdown<TaskPriority>(
          label: 'Priority',
          value: priority,
          items: TaskPriority.values
              .map(
                (p) => DropdownMenuItem(value: p, child: Text(p.short)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onPriorityChanged(v);
          },
        ),
        _Dropdown<int>(
          label: 'Status',
          value: statusIndex,
          items: [
            for (var i = 0; i < statusLabels.length; i++)
              DropdownMenuItem(value: i, child: Text(statusLabels[i])),
          ],
          onChanged: (v) {
            if (v != null) onStatusIndexChanged(v);
          },
        ),
        _Toggle(
          label: 'Show project',
          value: showProject,
          onChanged: onShowProjectChanged,
        ),
        _Toggle(
          label: 'Show category',
          value: showCategory,
          onChanged: onShowCategoryChanged,
        ),
        _Toggle(
          label: 'Show due date',
          value: showDueDate,
          onChanged: onShowDueDateChanged,
        ),
        _Toggle(
          label: 'Urgent due',
          value: urgentDueDate,
          onChanged: onUrgentDueDateChanged,
        ),
        _Toggle(
          label: 'Show labels',
          value: showLabels,
          onChanged: onShowLabelsChanged,
        ),
        _Toggle(
          label: 'Start hover',
          value: startHover,
          onChanged: onStartHoverChanged,
        ),
        _Toggle(
          label: 'Start editing',
          value: startEditing,
          onChanged: onStartEditingChanged,
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(label),
      ),
    );
  }
}
