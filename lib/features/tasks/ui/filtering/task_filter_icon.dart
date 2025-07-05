import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/features/tasks/ui/filtering/organized_task_filter_layout.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskFilterIcon extends StatelessWidget {
  const TaskFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.tasksFilterTitle,
            builder: (_) => const OrganizedTaskFilterLayout(),
            modalDecorator: (child) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: context.read<JournalPageCubit>(),
                  ),
                ],
                child: child,
              );
            },
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
