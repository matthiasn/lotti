import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/tasks/tasks_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/tags/tags_modal.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);
  bool pathContains(String s) => state.uri.path.contains(s);

  @override
  List<String> get pathPatterns => [
        '/tasks/:taskId',
        '/tasks/:taskId/manage_tags',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final taskId = state.pathParameters['taskId'];

    return [
      const BeamPage(
        key: ValueKey('tasks'),
        title: 'Tasks',
        type: BeamPageType.noTransition,
        child: TasksPage(),
      ),
      if (state.pathParameters.containsKey('taskId'))
        BeamPage(
          key: ValueKey('tasks-$taskId'),
          child: EntryDetailPage(
            itemId: taskId!,
          ),
        ),
      if (pathContains('/manage_tags'))
        BeamPage(
          routeBuilder: (
            BuildContext context,
            RouteSettings settings,
            Widget child,
          ) {
            return CupertinoModalBottomSheetRoute<void>(
              expanded: false,
              duration: const Duration(seconds: 1),
              animationCurve: Curves.ease,
              builder: (context) {
                final data = context.currentBeamLocation.data;

                if (data == null) {
                  return const SizedBox.shrink();
                }

                return BlocProvider.value(
                  value: data as EntryCubit,
                  child: child,
                );
              },
              settings: settings,
              modalBarrierColor: styleConfig().negspace.withOpacity(0.54),
            );
          },
          key: ValueKey('task-manage-tags-$taskId'),
          child: const TagsModal(),
          onPopPage: (context, delegate, _, page) {
            tasksBeamerDelegate.beamBack();
            return false;
          },
        ),
    ];
  }
}
