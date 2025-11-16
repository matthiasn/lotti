import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskTitleHeader extends ConsumerStatefulWidget {
  const TaskTitleHeader({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<TaskTitleHeader> createState() => _TaskTitleHeaderState();
}

class _TaskTitleHeaderState extends ConsumerState<TaskTitleHeader> {
  bool _isEditing = false;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (entryState == null || task is! Task) {
      return const SizedBox.shrink();
    }

    final title = task.data.title;

    return Material(
      elevation: 2,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).appBarTheme.backgroundColor,
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
        child: AnimatedCrossFade(
          duration: checklistCrossFadeDuration,
          firstChild: TitleTextField(
            initialValue: title,
            resetToInitialValue: true,
            onSave: (newTitle) async {
              await notifier.save(title: newTitle);
              setState(() {
                _isEditing = false;
              });
            },
            focusNode: _titleFocusNode,
            hintText: context.messages.taskNameHint,
            onTapOutside: (_) => setState(() {
              _isEditing = false;
            }),
            onCancel: () => setState(() {
              _isEditing = false;
            }),
          ),
          secondChild: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  softWrap: true,
                  style: context.textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: context.colorScheme.outline,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                  _titleFocusNode.requestFocus();
                },
              ),
            ],
          ),
          crossFadeState: _isEditing || title.isEmpty
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
        ),
      ),
    );
  }
}
