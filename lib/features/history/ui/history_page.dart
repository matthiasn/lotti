import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/domain/history_filter.dart';
import 'package:lotti/features/history/state/history_controller.dart';
import 'package:lotti/features/history/ui/history_timestamp.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the history over the app, behind the shared modal scrim.
///
/// Tapping a row closes the page and navigates to the entity; Escape, the
/// close button or a tap on the scrim closes it without navigating.
Future<void> showHistoryModal(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: ModalUtils.getModalBarrierColor(
    isDark: Theme.of(context).brightness == Brightness.dark,
    context: context,
  ),
  builder: (_) => const HistoryPage(),
);

/// Rows left below the viewport when the next page is requested.
const _loadMoreThreshold = 5;

/// The history: every entity the user opened, newest first, under a title
/// search and a time filter.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final availableHeight =
        MediaQuery.sizeOf(context).height - (tokens.spacing.step6 * 2);

    return Dialog(
      insetPadding: EdgeInsets.all(tokens.spacing.step6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: WoltModalConfig.pageBreakpoint.toDouble(),
          maxHeight: availableHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      messages.historyTitle,
                      style: tokens.typography.styles.heading.heading3.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  DesignSystemIconAction(
                    key: const ValueKey('history-close'),
                    icon: LottiIcons.close,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step5),
              DesignSystemSearch(
                hintText: messages.historySearchHint,
                autofocus: isDesktopLayout(context),
                onChanged: controller.setQuery,
                onClear: () => controller.setQuery(''),
              ),
              SizedBox(height: tokens.spacing.step4),
              _RangeFilter(filter: state.filter),
              SizedBox(height: tokens.spacing.step4),
              Expanded(child: _HistoryList(state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeFilter extends ConsumerWidget {
  const _RangeFilter({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final controller = ref.read(historyControllerProvider.notifier);
    final start = filter.customStart;
    final end = filter.customEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSegmentedToggle<HistoryTimeRange>(
          expand: true,
          selected: filter.range,
          segments: [
            DsSegment(
              HistoryTimeRange.last7Days,
              messages.historyRangeLast7Days,
            ),
            DsSegment(
              HistoryTimeRange.last30Days,
              messages.historyRangeLast30Days,
            ),
            DsSegment(
              HistoryTimeRange.last90Days,
              messages.historyRangeLast90Days,
            ),
            DsSegment(HistoryTimeRange.allTime, messages.historyRangeAllTime),
            DsSegment(HistoryTimeRange.custom, messages.historyRangeCustom),
          ],
          onChanged: (range) {
            if (range == HistoryTimeRange.custom) {
              _pickCustomRange(context, ref);
            } else {
              controller.setRange(range);
            }
          },
        ),
        if (filter.range == HistoryTimeRange.custom &&
            start != null &&
            end != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Center(
            child: Builder(
              builder: (context) {
                final label = messages.historyCustomRangeLabel(
                  _dayLabel(context, start),
                  _dayLabel(context, end),
                );
                return DesignSystemInlineAction(
                  key: const ValueKey('history-custom-range'),
                  label: label,
                  semanticsLabel: label,
                  leadingIcon: LottiIcons.calendar,
                  onTap: () => _pickCustomRange(context, ref),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Asks for the first day, then the last. Dismissing either picker keeps
  /// the window that was there before.
  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final messages = context.messages;
    final controller = ref.read(historyControllerProvider.notifier);
    final today = clock.now();
    final firstDate = DateTime(2000);
    final start = await showDesignSystemDatePicker(
      context: context,
      title: messages.historyCustomRangeStartTitle,
      initialDate:
          filter.customStart ??
          DateTime(today.year, today.month, today.day - 6),
      firstDate: firstDate,
      lastDate: today,
    );
    final startDate = start?.date;
    if (startDate == null || !context.mounted) return;
    final end = await showDesignSystemDatePicker(
      context: context,
      title: messages.historyCustomRangeEndTitle,
      initialDate: filter.customEnd ?? today,
      firstDate: firstDate,
      lastDate: today,
    );
    final endDate = end?.date;
    if (endDate == null) return;
    await controller.setCustomRange(startDate, endDate);
  }

  String _dayLabel(BuildContext context, DateTime day) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(day);
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.state});

  final HistoryViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final items = state.items;

    if (items.isEmpty) {
      if (state.isLoading) {
        return const Center(child: DesignSystemSpinner());
      }
      if (state.hasError) {
        return DesignSystemEmptyState(
          icon: LottiIcons.warning,
          title: messages.historyLoadError,
        );
      }
      return state.filter.hasQuery
          ? DesignSystemEmptyState(
              icon: LottiIcons.search,
              title: messages.historyNoMatchesTitle,
              hint: messages.historyNoMatchesHint,
            )
          : DesignSystemEmptyState(
              icon: LottiIcons.restore,
              title: messages.historyEmptyTitle,
              hint: messages.historyEmptyHint,
            );
    }

    final now = clock.now();
    final locale = Localizations.localeOf(context).toString();
    final indexOfKey = <Key, int>{
      for (final (index, item) in items.indexed) _rowKey(item): index,
    };
    return ListView.builder(
      itemCount: items.length + (state.hasMore ? 1 : 0),
      // A delete or a narrower search shifts rows; this lets each keep its
      // element instead of being rebuilt by index.
      findChildIndexCallback: (key) => indexOfKey[key],
      itemBuilder: (context, index) {
        if (state.hasMore && index >= items.length - _loadMoreThreshold) {
          // Requested after the frame: loading more changes the state this
          // build reads. The controller ignores repeats while a page loads.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (context.mounted) {
              await ref.read(historyControllerProvider.notifier).loadMore();
            }
          });
        }
        if (index == items.length) {
          return const Center(child: DesignSystemSpinner());
        }
        return _HistoryRow(
          key: _rowKey(items[index]),
          item: items[index],
          timestamp: historyTimestampLabel(
            items[index].entry.visitedAt,
            now: now,
            messages: messages,
            locale: locale,
          ),
          showDivider: index < items.length - 1,
        );
      },
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.item,
    required this.timestamp,
    required this.showDivider,
    super.key,
  });

  final ResolvedHistoryEntry item;
  final String timestamp;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final target = item.entry.target;
    final title = switch (item.title) {
      null => messages.historyEntityGone,
      '' => messages.historyUntitled,
      final title => title,
    };

    return DesignSystemListItem(
      title: title,
      subtitle: '${_sectionLabel(messages, target.kind)} · $timestamp',
      leading: Icon(
        _kindIcon(target.kind),
        color: item.isGone
            ? tokens.colors.text.lowEmphasis
            : tokens.colors.text.mediumEmphasis,
      ),
      trailing: DesignSystemIconAction(
        key: ValueKey('history-delete-${item.entry.id}'),
        icon: LottiIcons.delete,
        tooltip: messages.historyDeleteTooltip,
        tone: tokens.colors.alert.error.defaultColor,
        onPressed: () => _confirmDelete(context, ref),
      ),
      showDivider: showDivider,
      onTap: item.isGone ? null : () => _open(context, ref, target),
    );
  }

  /// Closes the page, then beams to the entity.
  ///
  /// A task that is the base of the desktop detail stack is brought back by
  /// popping the linked tasks above it: beaming to its own route keeps the
  /// stack (`resetDesktopTaskDetail` preserves pushes on an unchanged base),
  /// which would leave the linked task on screen.
  void _open(BuildContext context, WidgetRef ref, HistoryTarget target) {
    final navService = ref.read(navServiceProvider);
    Navigator.of(context).pop();
    if (target.kind == HistoryEntityKind.task) {
      final stack = navService.desktopTaskDetailStack.value;
      if (stack.length > 1 && stack.first == target.entityId) {
        for (var i = 1; i < stack.length; i++) {
          navService.popDesktopTaskDetail();
        }
      }
    }
    navService.beamToNamed(target.route);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messages = context.messages;
    final controller = ref.read(historyControllerProvider.notifier);
    final confirmed = await showConfirmationModal(
      context: context,
      title: messages.historyDeleteConfirmTitle,
      message: messages.historyDeleteConfirmMessage,
      confirmLabel: messages.historyDeleteConfirmAction,
    );
    if (confirmed) await controller.delete(item.entry);
  }
}

/// A row's identity: its visit, wherever the list has moved it.
Key _rowKey(ResolvedHistoryEntry item) =>
    ValueKey('history-row-${item.entry.id}');

/// The section of the app an entity lives in, as the navigation names it.
String _sectionLabel(AppLocalizations messages, HistoryEntityKind kind) =>
    switch (kind) {
      HistoryEntityKind.task => messages.navTabTitleTasks,
      HistoryEntityKind.entry => messages.navTabTitleJournal,
      HistoryEntityKind.project => messages.navTabTitleProjects,
      HistoryEntityKind.event => messages.navTabTitleEvents,
      HistoryEntityKind.person => messages.navTabTitlePeople,
      HistoryEntityKind.dashboard => messages.navTabTitleInsights,
      HistoryEntityKind.habit => messages.navTabTitleHabits,
    };

/// The navigation's own glyph for an entity's section.
IconData _kindIcon(HistoryEntityKind kind) => switch (kind) {
  HistoryEntityKind.task => LottiIcons.list,
  HistoryEntityKind.entry => LottiIcons.book,
  HistoryEntityKind.project => LottiIcons.folder,
  HistoryEntityKind.event => LottiIcons.calendar,
  HistoryEntityKind.person => LottiIcons.people,
  HistoryEntityKind.dashboard => LottiIcons.chart,
  HistoryEntityKind.habit => LottiIcons.checkAll,
};
