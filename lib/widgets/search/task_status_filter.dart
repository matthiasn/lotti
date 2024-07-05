import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:quiver/collection.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class TaskStatusFilter extends StatelessWidget {
  const TaskStatusFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(
              'Status',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 10,
              spacing: 5,
              children: [
                ...snapshot.taskStatuses.map(
                  (status) => TaskStatusChip(
                    status,
                    onlySelected: false,
                  ),
                ),
                const TaskStatusAllChip(),
                const SizedBox(width: 5),
              ],
            ),
          ],
        );
      },
    );
  }
}

class TaskCategoryFilter extends StatelessWidget {
  const TaskCategoryFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        final cubit = context.read<JournalPageCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Divider(),
            Text(
              'Category',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 10,
              children: [
                ...categories.map((category) {
                  final color = colorFromCssHex(category.color);
                  return Opacity(
                    opacity: state.selectedCategoryIds.contains(category.id)
                        ? 1
                        : 0.4,
                    child: ActionChip(
                      onPressed: () => cubit.toggleSelectedCategoryIds(
                        category.id,
                      ),
                      label: Text(
                        category.name,
                        style: TextStyle(
                          color: color.isLight ? Colors.black : Colors.white,
                          fontSize: fontSizeMedium,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      backgroundColor: color,
                    ),
                  );
                }),
                Opacity(
                  opacity: state.selectedCategoryIds.contains('') ? 1 : 0.4,
                  child: ActionChip(
                    onPressed: () => cubit.toggleSelectedCategoryIds(''),
                    label: const Text(
                      'unassigned',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSizeMedium,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class TaskListToggle extends StatelessWidget {
  const TaskListToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final iconColor = Theme.of(context).textTheme.titleLarge?.color;
        final inactiveIconColor = iconColor?.withOpacity(0.5);
        final taskAsListView = snapshot.taskAsListView;

        return Row(
          children: [
            const SizedBox(width: 15),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                cubit.toggleTaskAsListView();
              },
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Icon(
                    Icons.density_small_rounded,
                    color: taskAsListView ? iconColor : inactiveIconColor,
                  ),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Icon(
                    Icons.density_medium_rounded,
                    color: taskAsListView ? inactiveIconColor : iconColor,
                  ),
                ),
              ],
              selected: {taskAsListView},
            ),
          ],
        );
      },
    );
  }
}

class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip(
    this.status, {
    required this.onlySelected,
    super.key,
  });

  final String status;
  final bool onlySelected;

  @override
  Widget build(BuildContext context) {
    final localizationLookup = {
      'OPEN': context.messages.taskStatusOpen,
      'GROOMED': context.messages.taskStatusGroomed,
      'IN PROGRESS': context.messages.taskStatusInProgress,
      'BLOCKED': context.messages.taskStatusBlocked,
      'ON HOLD': context.messages.taskStatusOnHold,
      'DONE': context.messages.taskStatusDone,
      'REJECTED': context.messages.taskStatusRejected,
    };

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        void onTap() {
          cubit.toggleSelectedTaskStatus(status);
          HapticFeedback.heavyImpact();
        }

        void onLongPress() {
          cubit.selectSingleTaskStatus(status);
          HapticFeedback.heavyImpact();
        }

        final isSelected = snapshot.selectedTaskStatuses.contains(status);

        if (onlySelected && !isSelected) {
          return const SizedBox.shrink();
        }

        final backgroundColor = switch (status) {
          'OPEN' => Colors.orange,
          'GROOMED' => Colors.lightGreenAccent,
          'IN PROGRESS' => Colors.blue,
          'BLOCKED' => Colors.red,
          'ON HOLD' => Colors.red,
          'DONE' => Colors.green,
          'REJECTED' => Colors.red,
          String() => Colors.grey,
        };

        return FilterChoiceChip(
          label: '${localizationLookup[status]}',
          isSelected: isSelected,
          onTap: onTap,
          onLongPress: onLongPress,
          selectedColor: backgroundColor,
        );
      },
    );
  }
}

class TaskStatusAllChip extends StatelessWidget {
  const TaskStatusAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        final isSelected = setsEqual(
          snapshot.selectedTaskStatuses,
          snapshot.taskStatuses.toSet(),
        );

        void onTap() {
          if (isSelected) {
            cubit.clearSelectedTaskStatuses();
          } else {
            cubit.selectAllTaskStatuses();
          }
          HapticFeedback.heavyImpact();
        }

        return FilterChoiceChip(
          label: context.messages.taskStatusAll,
          isSelected: isSelected,
          selectedColor: Theme.of(context).colorScheme.secondary,
          onTap: onTap,
        );
      },
    );
  }
}

class TaskFilterIcon extends StatelessWidget {
  const TaskFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final pageIndexNotifier = ValueNotifier(0);

    SliverWoltModalSheetPage page1(
      BuildContext modalSheetContext,
      TextTheme textTheme,
    ) {
      return WoltModalSheetPage(
        hasSabGradient: false,
        topBarTitle: Text('Tasks Filter', style: textTheme.titleSmall),
        isTopBarLayerAlwaysVisible: true,
        trailingNavBarWidget: IconButton(
          padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
          icon: const Icon(Icons.close),
          onPressed: Navigator.of(modalSheetContext).pop,
        ),
        child: const Padding(
          padding: EdgeInsets.only(
            bottom: 30,
            left: 20,
            top: 10,
            right: 20,
          ),
          child: Column(
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          WoltModalSheet.show<void>(
            pageIndexNotifier: pageIndexNotifier,
            context: context,
            pageListBuilder: (modalSheetContext) {
              final textTheme = Theme.of(context).textTheme;
              return [
                page1(modalSheetContext, textTheme),
              ];
            },
            decorator: (child) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: context.read<JournalPageCubit>(),
                  ),
                ],
                child: child,
              );
            },
            modalTypeBuilder: (context) {
              final size = MediaQuery.of(context).size.width;
              if (size < WoltModalConfig.pageBreakpoint) {
                return WoltModalType.bottomSheet();
              } else {
                return WoltModalType.dialog();
              }
            },
            onModalDismissedWithBarrierTap: () {
              Navigator.of(context).pop();
            },
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
