import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/search/task_category_filter.dart';
import 'package:lotti/widgets/search/task_list_toggle.dart';
import 'package:lotti/widgets/search/task_status_filter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskFilterIcon extends StatelessWidget {
  const TaskFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal(
            context: context,
            title: context.messages.tasksFilterTitle,
            builder: (_) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    JournalFilter(),
                    SizedBox(width: 10),
                    TaskListToggle(),
                  ],
                ),
                SizedBox(height: 10),
                TaskStatusFilter(),
                TaskCategoryFilter(),
              ],
            ),
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
