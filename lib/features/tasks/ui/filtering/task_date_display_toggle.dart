import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskDateDisplayToggle extends StatelessWidget {
  const TaskDateDisplayToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return Row(
          children: [
            Expanded(
              child: Text(
                context.messages.tasksShowCreationDate,
                style: context.textTheme.bodySmall,
              ),
            ),
            Switch(
              value: snapshot.showCreationDate,
              onChanged: (value) {
                cubit.setShowCreationDate(show: value);
                HapticFeedback.selectionClick();
              },
            ),
          ],
        );
      },
    );
  }
}
