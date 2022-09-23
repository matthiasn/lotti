// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/task_utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    this.task,
    this.data,
    this.focusOnTitle = false,
  });

  final TaskData? data;
  final Task? task;
  final bool focusOnTitle;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final save = context.read<EntryCubit>().save;
        final formKey = context.read<EntryCubit>().formKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: FormBuilder(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: <Widget>[
                    FormBuilderTextField(
                      autofocus: widget.focusOnTitle,
                      initialValue: widget.data?.title ?? '',
                      decoration: InputDecoration(
                        labelText: localizations.taskNameLabel,
                        labelStyle: labelStyle(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardAppearance: Brightness.dark,
                      maxLines: null,
                      style: inputStyle().copyWith(
                        fontFamily: 'Oswald',
                        fontSize: 25,
                        fontWeight: FontWeight.normal,
                      ),
                      name: 'title',
                      onChanged: context.read<EntryCubit>().setDirty,
                    ),
                    FormBuilderCupertinoDateTimePicker(
                      name: 'estimate',
                      alwaysUse24HourFormat: true,
                      format: hhMmFormat,
                      inputType: CupertinoDateTimePickerInputType.time,
                      style: inputStyle().copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Oswald',
                      ),
                      onChanged: (_) => save(),
                      decoration: InputDecoration(
                        labelText: localizations.taskEstimateLabel,
                        labelStyle: labelStyle(),
                      ),
                      initialValue: DateTime.fromMillisecondsSinceEpoch(
                        widget.data?.estimate?.inMilliseconds ?? 0,
                        isUtc: true,
                      ),
                      theme: datePickerTheme(),
                    ),
                    FormBuilderChoiceChip(
                      name: 'status',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      backgroundColor: colorConfig().unselectedChoiceChipColor,
                      initialValue: widget.data?.status.map(
                            open: (_) => 'OPEN',
                            groomed: (_) => 'GROOMED',
                            started: (_) => 'STARTED',
                            inProgress: (_) => 'IN PROGRESS',
                            blocked: (_) => 'BLOCKED',
                            onHold: (_) => 'ON HOLD',
                            done: (_) => 'DONE',
                            rejected: (_) => 'REJECTED',
                          ) ??
                          'OPEN',
                      decoration: InputDecoration(
                        labelText: localizations.taskStatusLabel,
                        labelStyle: labelStyle().copyWith(
                          height: 0.6,
                          fontFamily: 'Oswald',
                        ),
                      ),
                      onChanged: (dynamic _) => save(),
                      selectedColor: widget.data?.status != null
                          ? taskColor(widget.data!.status)
                          : colorConfig().unselectedChoiceChipColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      runSpacing: 6,
                      spacing: 4,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Oswald',
                        color: colorConfig().unselectedChoiceChipColor,
                      ),
                      options: [
                        FormBuilderChipOption<String>(
                          value: 'OPEN',
                          child: Text(
                            localizations.taskStatusOpen,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'GROOMED',
                          child: Text(
                            localizations.taskStatusGroomed,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'IN PROGRESS',
                          child: Text(
                            localizations.taskStatusInProgress,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'BLOCKED',
                          child: Text(
                            localizations.taskStatusBlocked,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'ON HOLD',
                          child: Text(
                            localizations.taskStatusOnHold,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'DONE',
                          child: Text(
                            localizations.taskStatusDone,
                            style: taskFormFieldStyle,
                          ),
                        ),
                        FormBuilderChipOption<String>(
                          value: 'REJECTED',
                          child: Text(
                            localizations.taskStatusRejected,
                            style: taskFormFieldStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const EditorWidget(),
          ],
        );
      },
    );
  }
}
