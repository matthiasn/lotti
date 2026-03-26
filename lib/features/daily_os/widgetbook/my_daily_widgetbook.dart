import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/intl.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

const _holidayCategoryId = 'holiday';
const _tasksCategoryId = 'lotti-tasks';
const _hikingCategoryId = 'hiking';
const _meetingsCategoryId = 'meetings';
const _previewUserName = 'Matthias';
const _previewAvatar = AssetImage(
  'assets/design_system/avatar_placeholder.png',
);
const _myDailyFrameWidth = 402.0;
const _myDailyFrameHeight = 1368.0;
const _myDailyContentInset = 16.0;
const _myDailyHeaderHeight = 224.0;
const _myDailyFilteredHeaderHeight = 248.0;
const _myDailyTimelineHeight = 1046.0;
const _myDailyFilteredTimelineHeight = 1018.0;
const _myDailySummaryTop = 232.0;
const _myDailyFilteredSummaryTop = 256.0;
const _myDailyTimelinePanelLeft = 48.0;
const _myDailyTimelinePanelWidth = 354.0;
const _myDailyTimelineBandWidth = 32.0;
const _myDailyTimelineLabelLineOffset = 25.0;
const _myDailyTimelineHourRowTop = 16.0;
const _myDailyTimelineHourRowHeight = 52.0;
const _myDailyTimelineDimmedOpacity = 0.22;
const _myDailyTimelineConnectorInset = 24.0;
const _myDailyTimelineConnectorStrokeWidth = 1.5;
const _myDailyTimelineConnectorEndpointRadius = 3.0;
const _myDailyDefaultBadgeColor = Color(0xFF46B4FF);
const _myDailyTimelineNowIndicatorTop = 273.0;

enum _MyDailyPreviewVariant {
  ongoingDay,
  filterByTimeBlock,
  filtered,
}

enum MyDailyTimelineBlockDensity {
  compact,
  regular,
  expanded,
}

WidgetbookFolder buildMyDailyWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'My Daily',
    children: [
      buildMyDailyWidgetbookComponent(),
    ],
  );
}

WidgetbookComponent buildMyDailyWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'My Daily',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _MyDailyOverviewUseCase(),
      ),
      WidgetbookUseCase(
        name: 'Ongoing Day',
        builder: (context) => _MyDailyUseCase(
          fixture: _buildMyDailyPreviewFixture(
            variant: _MyDailyPreviewVariant.ongoingDay,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Filter By Time Block',
        builder: (context) => _MyDailyUseCase(
          fixture: _buildMyDailyPreviewFixture(
            variant: _MyDailyPreviewVariant.filterByTimeBlock,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Filtered',
        builder: (context) => _MyDailyUseCase(
          fixture: _buildMyDailyPreviewFixture(
            variant: _MyDailyPreviewVariant.filtered,
          ),
        ),
      ),
    ],
  );
}

class _MyDailyUseCase extends StatelessWidget {
  const _MyDailyUseCase({
    required this.fixture,
    // ignore: unused_element_parameter
    this.viewportWidth = 470,
  });

  final _MyDailyPreviewFixture fixture;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: _buildMyDailyPreviewOverrides(fixture),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: WidgetbookViewport(
            width: viewportWidth,
            child: _MyDailyPreviewScreen(fixture: fixture),
          ),
        ),
      ),
    );
  }
}

class _MyDailyOverviewUseCase extends StatelessWidget {
  const _MyDailyOverviewUseCase();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fixtures = [
      (
        label: 'My Daily - filled/ongoing',
        fixture: _buildMyDailyPreviewFixture(
          variant: _MyDailyPreviewVariant.ongoingDay,
        ),
      ),
      (
        label: 'My Daily - filter by time block',
        fixture: _buildMyDailyPreviewFixture(
          variant: _MyDailyPreviewVariant.filterByTimeBlock,
        ),
      ),
      (
        label: 'My Daily - filtered',
        fixture: _buildMyDailyPreviewFixture(
          variant: _MyDailyPreviewVariant.filtered,
        ),
      ),
    ];

    return WidgetbookViewport(
      width: 1480,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A),
            borderRadius: BorderRadius.circular(tokens.radii.m),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < fixtures.length; index++) ...[
                  ProviderScope(
                    overrides: _buildMyDailyPreviewOverrides(
                      fixtures[index].fixture,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 12),
                          child: Text(
                            fixtures[index].label,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                        _MyDailyPreviewScreen(fixture: fixtures[index].fixture),
                      ],
                    ),
                  ),
                  if (index != fixtures.length - 1) const SizedBox(width: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDailyPreviewScreen extends ConsumerStatefulWidget {
  const _MyDailyPreviewScreen({required this.fixture});

  final _MyDailyPreviewFixture fixture;

  @override
  ConsumerState<_MyDailyPreviewScreen> createState() =>
      _MyDailyPreviewScreenState();
}

class _MyDailyPreviewScreenState extends ConsumerState<_MyDailyPreviewScreen> {
  late Set<String> _selectedCategoryIds;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = {...widget.fixture.initialSelectedCategoryIds};
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final dailyState = ref.watch(dailyOsControllerProvider).value;
    final historyData = ref.watch(timeHistoryHeaderControllerProvider).value;
    final showFilterRow = widget.fixture.showFilterRow;
    final headerHeight = showFilterRow
        ? _myDailyFilteredHeaderHeight
        : _myDailyHeaderHeight;
    final timelineHeight = showFilterRow
        ? _myDailyFilteredTimelineHeight
        : _myDailyTimelineHeight;
    final summaryTop = showFilterRow
        ? _myDailyFilteredSummaryTop
        : _myDailySummaryTop;

    return SizedBox(
      width: _myDailyFrameWidth,
      height: _myDailyFrameHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.colors.background.level01,
              tokens.colors.background.level02.withValues(alpha: 0.96),
            ],
          ),
        ),
        child: dailyState == null || historyData == null
            ? const Center(
                child: CircularProgressIndicator(
                  key: Key('my-daily-loading'),
                ),
              )
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: headerHeight,
                    child: _MyDailyHeader(
                      selectedDate: selectedDate,
                      historyData: historyData,
                      now: widget.fixture.now,
                      showFilterRow: showFilterRow,
                      selectedCategoryIds: _selectedCategoryIds,
                      onCategoryPressed: _toggleCategory,
                      onEditPlanPressed: widgetbookNoop,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: headerHeight,
                    height: timelineHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _myDailyContentInset,
                      ),
                      child: _MyDailyTimeline(
                        state: dailyState,
                        now: widget.fixture.now,
                        selectedCategoryIds: _selectedCategoryIds,
                        filterEnabled: showFilterRow,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _myDailyContentInset,
                    right: _myDailyContentInset,
                    top: summaryTop,
                    child: const _MyDailySummaryCard(),
                  ),
                  const Positioned(
                    right: 8,
                    top: 1178,
                    child: _MyDailyActionButton(
                      onPressed: widgetbookNoop,
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 102,
                    child: _MyDailyBottomNavigation(),
                  ),
                ],
              ),
      ),
    );
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }
}

class _MyDailyHeader extends StatelessWidget {
  const _MyDailyHeader({
    required this.selectedDate,
    required this.historyData,
    required this.now,
    required this.showFilterRow,
    required this.selectedCategoryIds,
    required this.onCategoryPressed,
    required this.onEditPlanPressed,
  });

  final DateTime selectedDate;
  final TimeHistoryData historyData;
  final DateTime now;
  final bool showFilterRow;
  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onCategoryPressed;
  final VoidCallback onEditPlanPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 38,
              vertical: 12,
            ),
            child: _MyDailyStatusBar(now: now),
          ),
        ),
        const SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _myDailyContentInset,
              vertical: 9,
            ),
            child: _MyDailyGreetingRow(
              userName: _previewUserName,
              onNotificationsPressed: widgetbookNoop,
            ),
          ),
        ),
        SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _myDailyContentInset,
              vertical: 8,
            ),
            child: _MyDailyDateStrip(
              selectedDate: selectedDate,
              historyData: historyData,
            ),
          ),
        ),
        _MyDailyDateHeader(
          selectedDate: selectedDate,
          showFilterRow: showFilterRow,
          selectedCategoryIds: selectedCategoryIds,
          onCategoryPressed: onCategoryPressed,
          onEditPlanPressed: onEditPlanPressed,
        ),
      ],
    );
  }
}

class _MyDailyStatusBar extends StatelessWidget {
  const _MyDailyStatusBar({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        Text(
          _formatLocalizedPreviewTime(context, now),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.signal_cellular_alt_rounded,
          size: tokens.typography.lineHeight.caption,
          color: tokens.colors.text.highEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Icon(
          Icons.wifi_rounded,
          size: tokens.typography.lineHeight.caption,
          color: tokens.colors.text.highEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Icon(
          Icons.battery_full_rounded,
          size: tokens.typography.lineHeight.caption,
          color: tokens.colors.text.highEmphasis,
        ),
      ],
    );
  }
}

class _MyDailyGreetingRow extends StatelessWidget {
  const _MyDailyGreetingRow({
    required this.userName,
    required this.onNotificationsPressed,
  });

  final String userName;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final greetingStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      height: 1,
    );

    return Row(
      children: [
        DesignSystemAvatar(
          image: _previewAvatar,
          semanticsLabel:
              context.messages.designSystemMyDailyProfileActionLabel,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: context.messages
                          .designSystemMyDailyGreetingWithName(
                            userName,
                          ),
                      style: greetingStyle,
                    ),
                    const TextSpan(text: ' 👋'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                context.messages.designSystemMyDailyGreetingMorning,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  height: 0.95,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: context.messages.designSystemHeaderNotificationsActionLabel,
          child: SizedBox.square(
            dimension: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 36,
                height: 36,
              ),
              splashRadius: 18,
              onPressed: onNotificationsPressed,
              icon: Icon(
                Icons.notifications_none_rounded,
                size: tokens.typography.lineHeight.subtitle1,
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyDateStrip extends ConsumerWidget {
  const _MyDailyDateStrip({
    required this.selectedDate,
    required this.historyData,
  });

  final DateTime selectedDate;
  final TimeHistoryData historyData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = [...historyData.days]
      ..sort((left, right) => left.day.compareTo(right.day));

    return SizedBox(
      height: tokens.spacing.step10,
      child: Stack(
        children: [
          ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => SizedBox(width: tokens.spacing.step2),
            itemBuilder: (context, index) {
              final day = DateUtils.dateOnly(days[index].day);
              return DesignSystemCalendarDateCard(
                key: Key(
                  'my-daily-date-${DateFormat('yyyy-MM-dd').format(day)}',
                ),
                weekdayLabel: DateFormat('EEE', locale).format(day),
                dayLabel: DateFormat('d', locale).format(day),
                selected: day == DateUtils.dateOnly(selectedDate),
                onPressed: () {
                  ref
                      .read(dailyOsSelectedDateProvider.notifier)
                      .selectDate(day);
                },
              );
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 42,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDailyDateHeader extends StatelessWidget {
  const _MyDailyDateHeader({
    required this.selectedDate,
    required this.showFilterRow,
    required this.selectedCategoryIds,
    required this.onCategoryPressed,
    required this.onEditPlanPressed,
  });

  final DateTime selectedDate;
  final bool showFilterRow;
  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onCategoryPressed;
  final VoidCallback onEditPlanPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final dateHeader = Row(
      children: [
        Expanded(
          child: Text(
            DateFormat('EEEE, MMMM d', locale).format(selectedDate),
            key: const Key('my-daily-date-header'),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        if (showFilterRow)
          SizedBox.square(
            dimension: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 24,
                height: 24,
              ),
              splashRadius: 16,
              onPressed: onEditPlanPressed,
              icon: Icon(
                Icons.expand_less_rounded,
                size: 24,
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          )
        else
          TextButton.icon(
            onPressed: onEditPlanPressed,
            style: TextButton.styleFrom(
              foregroundColor: tokens.colors.interactive.enabled,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step2,
                vertical: tokens.spacing.step1,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.edit_outlined,
              size: tokens.typography.lineHeight.caption,
            ),
            label: Text(
              context.messages.designSystemMyDailyEditPlanLabel,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.interactive.enabled,
              ),
            ),
          ),
      ],
    );

    return SizedBox(
      height: showFilterRow ? 68 : 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _myDailyContentInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: dateHeader,
              ),
            ),
            if (showFilterRow) ...[
              SizedBox(height: tokens.spacing.step2),
              _MyDailyFilterRow(
                selectedCategoryIds: selectedCategoryIds,
                onCategoryPressed: onCategoryPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyDailySummaryCard extends StatelessWidget {
  const _MyDailySummaryCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF122029),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF5ED4B7).withValues(alpha: 0.24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(77, 77, 77, 0.25),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.messages.dailyOsDaySummary,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: const Color.fromRGBO(255, 255, 255, 0.88),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.messages.designSystemMyDailyTapToExpandLabel,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: const Color.fromRGBO(255, 255, 255, 0.32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MyDailyMetricPill(
                  leading: const Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 16,
                    color: Color(0xFF4AB6E8),
                  ),
                  value: '4',
                  label: ' ${context.messages.dailyOsTasks}',
                ),
                const SizedBox(width: 8),
                _MyDailyRecordedMetricPill(
                  value: '6',
                  limitLabel:
                      '10h ${context.messages.dailyOsRecorded.toLowerCase()}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDailyMetricPill extends StatelessWidget {
  const _MyDailyMetricPill({
    required this.leading,
    required this.value,
    required this.label,
  });

  final Widget leading;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              TextSpan(
                text: label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyDailyRecordedMetricPill extends StatelessWidget {
  const _MyDailyRecordedMetricPill({
    required this.value,
    required this.limitLabel,
  });

  final String value;
  final String limitLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: Stack(
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: 0.6,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5ED4B7)),
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              TextSpan(
                text: '/$limitLabel',
                style: tokens.typography.styles.others.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyDailyFilterRow extends StatelessWidget {
  const _MyDailyFilterRow({
    required this.selectedCategoryIds,
    required this.onCategoryPressed,
  });

  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onCategoryPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final categories = [
      _holidayCategoryId,
      _tasksCategoryId,
      _hikingCategoryId,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            _MyDailyFilterChip(
              key: Key('my-daily-filter-${categories[index]}'),
              categoryId: categories[index],
              active: selectedCategoryIds.contains(categories[index]),
              onPressed: () => onCategoryPressed(categories[index]),
            ),
            if (index != categories.length - 1)
              SizedBox(width: tokens.spacing.step2),
          ],
        ],
      ),
    );
  }
}

class _MyDailyFilterChip extends StatelessWidget {
  const _MyDailyFilterChip({
    required this.categoryId,
    required this.active,
    required this.onPressed,
    super.key,
  });

  final String categoryId;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = _colorForCategory(categoryId);
    final foreground = Colors.white.withValues(alpha: active ? 0.88 : 0.42);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Ink(
          height: 20,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 0.24 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: active ? 1 : 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _iconForCategory(categoryId),
                size: 16,
                color: foreground,
              ),
              const SizedBox(width: 4),
              Text(
                _labelForCategory(context, categoryId),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: foreground,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyDailyTimeline extends StatelessWidget {
  const _MyDailyTimeline({
    required this.state,
    required this.now,
    required this.selectedCategoryIds,
    required this.filterEnabled,
  });

  final DailyOsState state;
  final DateTime now;
  final Set<String> selectedCategoryIds;
  final bool filterEnabled;

  @override
  Widget build(BuildContext context) {
    final sections = _buildTimelineSections(context);
    final blocks = _buildTimelineBlockSpecs(context);
    final showFilter = filterEnabled && selectedCategoryIds.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var hour = 7; hour <= 26; hour++)
          Positioned(
            left: 0,
            right: 0,
            top:
                _myDailyTimelineHourRowTop +
                ((hour - 7) * _myDailyTimelineHourRowHeight),
            child: _MyDailyTimelineHourRule(hour: hour),
          ),
        for (final section in sections)
          Positioned(
            left: _myDailyTimelinePanelLeft,
            top: section.top,
            width: _myDailyTimelinePanelWidth,
            height: section.height,
            child: Opacity(
              key: Key('my-daily-category-opacity-${section.filterId}'),
              opacity: _resolveTimelineOpacity(
                filterId: section.filterId,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
              child: _MyDailyTimelineSectionPanel(section: section),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _MyDailyTimelineConnectorPainter(
                blocks: blocks,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
            ),
          ),
        ),
        for (final block in blocks)
          Positioned(
            left: block.left,
            top: block.top,
            width: block.width,
            height: block.height,
            child: Opacity(
              opacity: _resolveTimelineOpacity(
                filterId: block.filterId,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
              child: _MyDailyTimelineBlock(block: block),
            ),
          ),
        if (DateUtils.dateOnly(now) == DateUtils.dateOnly(state.selectedDate))
          Positioned(
            left: 0,
            right: 0,
            top: _myDailyTimelineNowIndicatorTop,
            child: _NowIndicator(now: now),
          ),
      ],
    );
  }
}

class _MyDailyTimelineHourRule extends StatelessWidget {
  const _MyDailyTimelineHourRule({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final uses24HourClock = _uses24HourClock(context);
    final labelWidth = uses24HourClock ? 18.0 : _myDailyTimelineLabelLineOffset;
    final lineInset = _myDailyTimelineLabelLineOffset - labelWidth;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            _formatTimelineHour(context, hour),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: tokens.typography.styles.others.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 7, left: lineInset),
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyTimelineSectionPanel extends StatelessWidget {
  const _MyDailyTimelineSectionPanel({required this.section});

  final _MyDailyTimelineSectionSpec section;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            section.color.withValues(alpha: 0.18),
            section.color.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: section.color.withValues(alpha: 0.26),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _myDailyTimelineBandWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _myDailyTimelineBandWidth,
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section.icon,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.label,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDailyTimelineBlock extends StatelessWidget {
  const _MyDailyTimelineBlock({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('my-daily-block-${block.id}'),
      decoration: BoxDecoration(
        color: block.fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: block.strokeColor),
        boxShadow: block.glowColor == null
            ? null
            : [
                BoxShadow(
                  color: block.glowColor!,
                  blurRadius: 4,
                ),
              ],
      ),
      child: Padding(
        padding: block.padding,
        child: switch (block.style) {
          _MyDailyTimelineBlockStyle.detailed => _MyDailyDetailedBlockContent(
            block: block,
          ),
          _MyDailyTimelineBlockStyle.pill => _MyDailyPillBlockContent(
            block: block,
          ),
          _MyDailyTimelineBlockStyle.split => _MyDailySplitBlockContent(
            block: block,
          ),
        },
      ),
    );
  }
}

class _MyDailyDetailedBlockContent extends StatelessWidget {
  const _MyDailyDetailedBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      block.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _timelineBlockTitleStyle,
                    ),
                  ),
                  if (block.badgeLabel != null) ...[
                    const SizedBox(width: 4),
                    _TimelineBadge(
                      label: block.badgeLabel!,
                      tint: block.badgeColor ?? _myDailyDefaultBadgeColor,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TimelineTrailingLabel(
              label: block.trailingLabel,
              showWarning: block.showWarning,
            ),
          ],
        ),
        if (block.subtitle != null) ...[
          const SizedBox(height: 2),
          _TimelineIconText(
            label: block.subtitle!,
            icon: Icons.schedule_rounded,
          ),
        ],
        if (block.metaLabel != null) ...[
          const SizedBox(height: 2),
          _TimelineIconText(
            label: block.metaLabel!,
            icon: Icons.timelapse_rounded,
          ),
        ],
      ],
    );
  }
}

class _MyDailyPillBlockContent extends StatelessWidget {
  const _MyDailyPillBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      children: [
        Expanded(
          child: Row(
            children: [
              if (block.leadingIcon != null) ...[
                Icon(
                  block.leadingIcon,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.64),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _timelineBlockTitleStyle,
                ),
              ),
              if (block.inlineChip != null) ...[
                const SizedBox(width: 6),
                _TimelineInlineChip(chip: block.inlineChip!),
              ],
              if (block.metaLabel != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: _TimelineIconText(
                    label: block.metaLabel!,
                    icon: Icons.timelapse_rounded,
                    inline: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TimelineTrailingLabel(
          label: block.trailingLabel,
          showWarning: block.showWarning,
        ),
      ],
    );
  }
}

class _MyDailySplitBlockContent extends StatelessWidget {
  const _MyDailySplitBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TimelineIconText(
                label: block.title,
                icon: Icons.schedule_rounded,
                inline: true,
              ),
            ),
            const SizedBox(width: 8),
            _TimelineTrailingLabel(
              label: block.trailingLabel,
              showWarning: block.showWarning,
            ),
          ],
        ),
        if (block.metaLabel != null) ...[
          const SizedBox(height: 4),
          _TimelineIconText(
            label: block.metaLabel!,
            icon: Icons.timelapse_rounded,
          ),
        ],
      ],
    );
  }
}

class _TimelineIconText extends StatelessWidget {
  const _TimelineIconText({
    required this.label,
    required this.icon,
    this.inline = false,
  });

  final String label;
  final IconData icon;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white.withValues(alpha: 0.32),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _timelineBlockMetaStyle,
          ),
        ),
      ],
    );
  }
}

class _TimelineInlineChip extends StatelessWidget {
  const _TimelineInlineChip({required this.chip});

  final _TimelineInlineChipSpec chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: chip.width,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chip.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: chip.label == null
          ? null
          : Text(
              chip.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _timelineChipLabelStyle,
            ),
    );
  }
}

class _TimelineTrailingLabel extends StatelessWidget {
  const _TimelineTrailingLabel({
    required this.label,
    required this.showWarning,
  });

  final String label;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showWarning) ...[
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Color(0xFFFFB43A),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: _timelineTrailingStyle,
        ),
      ],
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({
    required this.label,
    required this.tint,
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: _timelineChipLabelStyle.copyWith(
          color: const Color(0xFF122029),
        ),
      ),
    );
  }
}

class _MyDailyTimelineConnectorPainter extends CustomPainter {
  const _MyDailyTimelineConnectorPainter({
    required this.blocks,
    required this.selectedCategoryIds,
    required this.showFilter,
  });

  final List<_MyDailyTimelineBlockSpec> blocks;
  final Set<String> selectedCategoryIds;
  final bool showFilter;

  @override
  void paint(Canvas canvas, Size size) {
    final groups = <String, List<_MyDailyTimelineBlockSpec>>{};
    for (final block in blocks) {
      final connectorGroupId = block.connectorGroupId;
      if (connectorGroupId == null) {
        continue;
      }
      groups.putIfAbsent(connectorGroupId, () => []).add(block);
    }

    for (final entries in groups.values) {
      entries.sort((left, right) => left.top.compareTo(right.top));
      for (var index = 0; index < entries.length - 1; index++) {
        final current = entries[index];
        final next = entries[index + 1];
        final opacity = _resolveTimelineOpacity(
          filterId: current.filterId,
          selectedCategoryIds: selectedCategoryIds,
          showFilter: showFilter,
        );
        final paint = Paint()
          ..color = current.strokeColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _myDailyTimelineConnectorStrokeWidth;
        final connectorX =
            math.max(current.left + current.width, next.left + next.width) +
            _myDailyTimelineConnectorInset;
        final currentCenterY = current.top + (current.height / 2);
        final nextCenterY = next.top + (next.height / 2);
        final path = Path()
          ..moveTo(current.left + current.width, currentCenterY)
          ..lineTo(connectorX, currentCenterY)
          ..lineTo(connectorX, nextCenterY)
          ..lineTo(next.left + next.width, nextCenterY);
        canvas
          ..drawPath(path, paint)
          ..drawCircle(
            Offset(next.left + next.width, nextCenterY),
            _myDailyTimelineConnectorEndpointRadius,
            Paint()..color = current.badgeColor ?? current.strokeColor,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MyDailyTimelineConnectorPainter oldDelegate) {
    return oldDelegate.blocks != blocks ||
        oldDelegate.selectedCategoryIds != selectedCategoryIds ||
        oldDelegate.showFilter != showFilter;
  }
}

enum _MyDailyTimelineBlockStyle {
  detailed,
  pill,
  split,
}

class _MyDailyTimelineSectionSpec {
  const _MyDailyTimelineSectionSpec({
    required this.filterId,
    required this.label,
    required this.icon,
    required this.color,
    required this.top,
    required this.height,
  });

  final String filterId;
  final String label;
  final IconData icon;
  final Color color;
  final double top;
  final double height;
}

class _MyDailyTimelineBlockSpec {
  const _MyDailyTimelineBlockSpec({
    required this.id,
    required this.filterId,
    required this.style,
    required this.density,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.title,
    required this.trailingLabel,
    required this.fillColor,
    required this.strokeColor,
    required this.padding,
    this.subtitle,
    this.metaLabel,
    this.badgeLabel,
    this.badgeColor,
    this.glowColor,
    this.leadingIcon,
    this.inlineChip,
    this.showWarning = false,
    this.connectorGroupId,
  });

  final String id;
  final String filterId;
  final _MyDailyTimelineBlockStyle style;
  final MyDailyTimelineBlockDensity density;
  final double left;
  final double top;
  final double width;
  final double height;
  final String title;
  final String trailingLabel;
  final String? subtitle;
  final String? metaLabel;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color fillColor;
  final Color strokeColor;
  final Color? glowColor;
  final EdgeInsets padding;
  final IconData? leadingIcon;
  final _TimelineInlineChipSpec? inlineChip;
  final bool showWarning;
  final String? connectorGroupId;
}

class _TimelineInlineChipSpec {
  const _TimelineInlineChipSpec({
    required this.color,
    required this.width,
    // ignore: unused_element_parameter
    this.label,
  });

  final Color color;
  final double width;
  final String? label;
}

const _timelineBlockTitleStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.88),
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.333,
);

const _timelineBlockMetaStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.32),
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.6,
);

const _timelineTrailingStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.64),
  fontSize: 10,
  fontWeight: FontWeight.w500,
  height: 1.6,
);

const _timelineChipLabelStyle = TextStyle(
  color: Color(0xFF122029),
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.6,
);

double _resolveTimelineOpacity({
  required String filterId,
  required Set<String> selectedCategoryIds,
  required bool showFilter,
}) {
  if (!showFilter || selectedCategoryIds.contains(filterId)) {
    return 1;
  }
  return _myDailyTimelineDimmedOpacity;
}

List<_MyDailyTimelineSectionSpec> _buildTimelineSections(BuildContext context) {
  return [
    _MyDailyTimelineSectionSpec(
      filterId: _holidayCategoryId,
      label: _labelForCategory(context, _holidayCategoryId),
      icon: _iconForCategory(_holidayCategoryId),
      color: _colorForCategory(_holidayCategoryId),
      top: 75,
      height: 209,
    ),
    _MyDailyTimelineSectionSpec(
      filterId: _tasksCategoryId,
      label: _labelForCategory(context, _tasksCategoryId),
      icon: _iconForCategory(_tasksCategoryId),
      color: _colorForCategory(_tasksCategoryId),
      top: 309,
      height: 105,
    ),
    _MyDailyTimelineSectionSpec(
      filterId: _hikingCategoryId,
      label: _labelForCategory(context, _hikingCategoryId),
      icon: _iconForCategory(_hikingCategoryId),
      color: _colorForCategory(_hikingCategoryId),
      top: 414,
      height: 414,
    ),
  ];
}

List<_MyDailyTimelineBlockSpec> _buildTimelineBlockSpecs(BuildContext context) {
  final holidayBase = _colorForCategory(_holidayCategoryId);
  final holidayFill = holidayBase.withValues(alpha: 0.16);
  final holidayStroke = holidayBase.withValues(alpha: 0.4);
  final holidayGlow = holidayBase.withValues(alpha: 0.55);
  final tasksBase = _colorForCategory(_tasksCategoryId);
  final tasksFill = tasksBase.withValues(alpha: 0.16);
  final tasksStroke = tasksBase.withValues(alpha: 0.8);
  final tasksGlow = tasksBase.withValues(alpha: 0.35);
  final hikingBase = _colorForCategory(_hikingCategoryId);
  final hikingFill = hikingBase.withValues(alpha: 0.16);
  final hikingStroke = hikingBase.withValues(alpha: 0.4);
  final hikingGlow = hikingBase.withValues(alpha: 0.55);
  const neutralFill = Color(0xFF2C2C2C);
  const neutralStroke = Color.fromRGBO(255, 255, 255, 0.12);

  return [
    _MyDailyTimelineBlockSpec(
      id: 'skiing',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.expanded,
      left: 88,
      top: 78,
      width: 274,
      height: 87,
      title: context.messages.designSystemMyDailySkiWithMattTitle,
      badgeLabel: 'P1',
      badgeColor: _myDailyDefaultBadgeColor,
      trailingLabel: '1h 35m',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 8,
        startMinute: 5,
        endHour: 9,
        endMinute: 40,
      ),
      metaLabel: '4 sessions',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'skiing-recap',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 179,
      width: 274,
      height: 24,
      title: '2 of 4',
      trailingLabel: '25m',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'lunch-break',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 311,
      width: 274,
      height: 16,
      title: context.messages.designSystemMyDailyLunchBreakTitle,
      trailingLabel: '15m',
      metaLabel: '3 sessions',
      fillColor: tasksFill,
      strokeColor: tasksStroke,
      glowColor: tasksGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      inlineChip: const _TimelineInlineChipSpec(
        color: Color(0xFF2094FF),
        width: 28,
      ),
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'tasks-progress',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 336,
      width: 136,
      height: 24,
      title: '2 of 3',
      trailingLabel: '25m',
      fillColor: tasksFill,
      strokeColor: tasksStroke,
      glowColor: tasksGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'holiday-progress',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 226,
      top: 346,
      width: 136,
      height: 24,
      title: '3 of 4',
      trailingLabel: '20m',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      showWarning: true,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'focus-left',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.split,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 439,
      width: 136,
      height: 53,
      title: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 15,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      ),
      trailingLabel: '1h',
      metaLabel: '3 of 3',
      fillColor: const Color.fromRGBO(52, 68, 65, 0.72),
      strokeColor: const Color.fromRGBO(116, 143, 137, 0.28),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      showWarning: true,
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'focus-right',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.split,
      density: MyDailyTimelineBlockDensity.regular,
      left: 226,
      top: 439,
      width: 136,
      height: 53,
      title: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 15,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      ),
      trailingLabel: '1h',
      metaLabel: '4 of 4',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      showWarning: true,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'hiking',
      filterId: _hikingCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 517,
      width: 274,
      height: 53,
      title: context.messages.designSystemMyDailyHikeWithDanielaTitle,
      badgeLabel: 'P2',
      badgeColor: const Color(0xFF2094FF),
      trailingLabel: '1h',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 16,
        startMinute: 30,
        endHour: 17,
        endMinute: 30,
      ),
      fillColor: hikingFill,
      strokeColor: hikingStroke,
      glowColor: hikingGlow,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    ),
    _MyDailyTimelineBlockSpec(
      id: 'meeting',
      filterId: _hikingCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 577,
      width: 274,
      height: 53,
      title: context.messages.designSystemMyDailyMeetingWithDannyTitle,
      badgeLabel: 'P0',
      badgeColor: const Color(0xFFF06A74),
      trailingLabel: '1h',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 17,
        startMinute: 40,
        endHour: 18,
        endMinute: 40,
      ),
      fillColor: neutralFill,
      strokeColor: neutralStroke,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      showWarning: true,
    ),
  ];
}

class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      key: const Key('my-daily-now-indicator'),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1 / 2,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.alert.error.defaultColor,
            borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          ),
          child: Text(
            _formatLocalizedPreviewTime(context, now),
            style: tokens.typography.styles.others.overline.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(left: tokens.spacing.step2),
            height: 2,
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ],
    );
  }
}

class _MyDailyActionButton extends StatelessWidget {
  const _MyDailyActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationNewLabel,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tokens.colors.interactive.enabled,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.interactive.enabled.withValues(alpha: 0.3),
                blurRadius: tokens.spacing.step4,
                offset: Offset(0, tokens.spacing.step2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Icon(
              Icons.add_rounded,
              color: tokens.colors.text.onInteractiveAlert,
              size: tokens.typography.lineHeight.subtitle1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDailyBottomNavigation extends StatelessWidget {
  const _MyDailyBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final items = widgetbookNavigationDestinations(context)
        .map(
          (destination) => DesignSystemNavigationTabBarItem(
            label: destination.label,
            icon: destination.icon,
            active: destination.active,
            onTap: widgetbookNoop,
          ),
        )
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 68,
          child: Center(
            child: SizedBox(
              width: 354,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 278,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == items.length - 1
                                      ? 0
                                      : tokens.spacing.step1,
                                ),
                                child: _MyDailyBottomNavigationItem(
                                  item: items[index],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label:
                        context.messages.designSystemMyDailyProfileActionLabel,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      child: SizedBox.square(
                        dimension: 60,
                        child: Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: tokens.typography.lineHeight.subtitle1,
                            color: tokens.colors.text.highEmphasis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: Center(
            child: Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: tokens.colors.text.mediumEmphasis,
                borderRadius: BorderRadius.circular(tokens.radii.xl),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyBottomNavigationItem extends StatelessWidget {
  const _MyDailyBottomNavigationItem({required this.item});

  final DesignSystemNavigationTabBarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final labelColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    return Semantics(
      button: true,
      selected: item.active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          onTap: item.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step1,
              vertical: tokens.spacing.step2,
            ),
            decoration: BoxDecoration(
              color: item.active
                  ? tokens.colors.background.level01
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 20, color: iconColor),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDailyPreviewFixture {
  const _MyDailyPreviewFixture({
    required this.initialDate,
    required this.now,
    required this.showFilterRow,
    required this.initialSelectedCategoryIds,
    required this.dailyDataByDate,
    required this.historyData,
  });

  final DateTime initialDate;
  final DateTime now;
  final bool showFilterRow;
  final Set<String> initialSelectedCategoryIds;
  final Map<DateTime, DailyOsData> dailyDataByDate;
  final TimeHistoryData historyData;
}

List<Override> _buildMyDailyPreviewOverrides(_MyDailyPreviewFixture fixture) {
  return [
    dailyOsSelectedDateProvider.overrideWith(
      () => _PreviewDailyOsSelectedDate(fixture.initialDate),
    ),
    dailyOsControllerProvider.overrideWith(
      () => _PreviewDailyOsController(fixture.dailyDataByDate),
    ),
    timeHistoryHeaderControllerProvider.overrideWith(
      () => _PreviewTimeHistoryHeaderController(fixture.historyData),
    ),
    for (final entry in fixture.dailyDataByDate.entries)
      unifiedDailyOsDataControllerProvider(date: entry.key).overrideWith(
        () => _PreviewUnifiedDailyOsDataController(entry.value),
      ),
  ];
}

_MyDailyPreviewFixture _buildMyDailyPreviewFixture({
  required _MyDailyPreviewVariant variant,
}) {
  final selectedDate = DateTime(2023, 10, 17);
  final visibleDates = [
    for (var offset = -2; offset <= 4; offset++)
      DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day + offset,
      ),
  ];
  final dailyDataByDate = <DateTime, DailyOsData>{
    for (final date in visibleDates) date: _buildDailyOsData(date),
  };

  return _MyDailyPreviewFixture(
    initialDate: selectedDate,
    now: DateTime(2023, 10, 17, 11),
    showFilterRow: variant != _MyDailyPreviewVariant.ongoingDay,
    initialSelectedCategoryIds: switch (variant) {
      _MyDailyPreviewVariant.ongoingDay => const {},
      _MyDailyPreviewVariant.filterByTimeBlock => {
        _holidayCategoryId,
        _tasksCategoryId,
        _hikingCategoryId,
      },
      _MyDailyPreviewVariant.filtered => {
        _holidayCategoryId,
        _hikingCategoryId,
      },
    },
    dailyDataByDate: dailyDataByDate,
    historyData: TimeHistoryData(
      days: [
        for (final date in visibleDates.reversed)
          DayTimeSummary(
            day: DateTime(date.year, date.month, date.day, 12),
            durationByCategoryId: const {},
            total: const Duration(hours: 6),
          ),
      ],
      earliestDay: visibleDates.first,
      latestDay: visibleDates.last,
      maxDailyTotal: const Duration(hours: 8),
      categoryOrder: const [
        _holidayCategoryId,
        _tasksCategoryId,
        _hikingCategoryId,
        _meetingsCategoryId,
      ],
      isLoadingMore: false,
      canLoadMore: false,
      stackedHeights: const {},
    ),
  );
}

DailyOsData _buildDailyOsData(DateTime date) {
  final categories = _buildPreviewCategories(date);
  final blocks = _buildPreviewBlocks(date);
  final actualSlots = _buildPreviewActualSlots(date);
  final budgetProgress = _buildPreviewBudgetProgress(
    date: date,
    categories: categories,
    blocks: blocks,
    actualSlots: actualSlots,
  );

  return DailyOsData(
    date: date,
    dayPlan: DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: DayPlanStatus.agreed(agreedAt: date),
        plannedBlocks: blocks,
      ),
    ),
    timelineData: DailyTimelineData(
      date: date,
      plannedSlots: [
        for (final block in blocks)
          PlannedTimeSlot(
            startTime: block.startTime,
            endTime: block.endTime,
            categoryId: block.categoryId,
            block: block,
          ),
      ],
      actualSlots: actualSlots,
      dayStartHour: 8,
      dayEndHour: 26,
    ),
    budgetProgress: budgetProgress,
  );
}

Map<String, CategoryDefinition> _buildPreviewCategories(DateTime date) {
  return {
    _holidayCategoryId: CategoryDefinition(
      id: _holidayCategoryId,
      name: _holidayCategoryId,
      color: '#8E2DE2',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _tasksCategoryId: CategoryDefinition(
      id: _tasksCategoryId,
      name: _tasksCategoryId,
      color: '#2ED8E2',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _hikingCategoryId: CategoryDefinition(
      id: _hikingCategoryId,
      name: _hikingCategoryId,
      color: '#D4B013',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _meetingsCategoryId: CategoryDefinition(
      id: _meetingsCategoryId,
      name: _meetingsCategoryId,
      color: '#6F6F74',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
  };
}

List<PlannedBlock> _buildPreviewBlocks(DateTime date) {
  DateTime at(int hour, int minute) {
    final dayOffset = hour >= 24 ? 1 : 0;
    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      hour % 24,
      minute,
    );
  }

  return [
    PlannedBlock(
      id: 'skiing',
      categoryId: _holidayCategoryId,
      startTime: at(8, 5),
      endTime: at(9, 40),
    ),
    PlannedBlock(
      id: 'skiing-recap',
      categoryId: _holidayCategoryId,
      startTime: at(10, 5),
      endTime: at(10, 35),
    ),
    PlannedBlock(
      id: 'lunch-break',
      categoryId: _tasksCategoryId,
      startTime: at(12, 20),
      endTime: at(12, 55),
    ),
    PlannedBlock(
      id: 'deep-work',
      categoryId: _tasksCategoryId,
      startTime: at(15, 0),
      endTime: at(16, 0),
    ),
    PlannedBlock(
      id: 'hiking',
      categoryId: _hikingCategoryId,
      startTime: at(16, 30),
      endTime: at(17, 30),
    ),
    PlannedBlock(
      id: 'meeting',
      categoryId: _meetingsCategoryId,
      startTime: at(17, 40),
      endTime: at(18, 40),
    ),
  ];
}

List<ActualTimeSlot> _buildPreviewActualSlots(DateTime date) {
  DateTime at(int hour, int minute) {
    final dayOffset = hour >= 24 ? 1 : 0;
    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      hour % 24,
      minute,
    );
  }

  ActualTimeSlot slot({
    required String id,
    required String categoryId,
    required DateTime start,
    required DateTime end,
  }) {
    return ActualTimeSlot(
      startTime: start,
      endTime: end,
      categoryId: categoryId,
      entry: JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: start,
          updatedAt: end,
          dateFrom: start,
          dateTo: end,
          categoryId: categoryId,
        ),
      ),
    );
  }

  return [
    slot(
      id: 'actual-ski-1',
      categoryId: _holidayCategoryId,
      start: at(8, 5),
      end: at(8, 20),
    ),
    slot(
      id: 'actual-ski-2',
      categoryId: _holidayCategoryId,
      start: at(8, 24),
      end: at(8, 40),
    ),
    slot(
      id: 'actual-ski-3',
      categoryId: _holidayCategoryId,
      start: at(8, 46),
      end: at(9, 5),
    ),
    slot(
      id: 'actual-ski-4',
      categoryId: _holidayCategoryId,
      start: at(9, 8),
      end: at(9, 32),
    ),
    slot(
      id: 'actual-lunch-1',
      categoryId: _tasksCategoryId,
      start: at(12, 20),
      end: at(12, 30),
    ),
    slot(
      id: 'actual-lunch-2',
      categoryId: _tasksCategoryId,
      start: at(12, 35),
      end: at(12, 45),
    ),
    slot(
      id: 'actual-lunch-3',
      categoryId: _tasksCategoryId,
      start: at(12, 47),
      end: at(12, 55),
    ),
    slot(
      id: 'actual-work-1',
      categoryId: _tasksCategoryId,
      start: at(15, 0),
      end: at(15, 20),
    ),
    slot(
      id: 'actual-work-2',
      categoryId: _tasksCategoryId,
      start: at(15, 24),
      end: at(15, 42),
    ),
    slot(
      id: 'actual-work-3',
      categoryId: _tasksCategoryId,
      start: at(15, 44),
      end: at(16, 0),
    ),
    slot(
      id: 'actual-hike-1',
      categoryId: _hikingCategoryId,
      start: at(16, 35),
      end: at(17, 25),
    ),
    slot(
      id: 'actual-meeting-1',
      categoryId: _meetingsCategoryId,
      start: at(17, 40),
      end: at(18, 20),
    ),
  ];
}

List<TimeBudgetProgress> _buildPreviewBudgetProgress({
  required DateTime date,
  required Map<String, CategoryDefinition> categories,
  required List<PlannedBlock> blocks,
  required List<ActualTimeSlot> actualSlots,
}) {
  return [
    _budgetProgressForCategory(
      date: date,
      categoryId: _holidayCategoryId,
      category: categories[_holidayCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _holidayCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _holidayCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-skiing',
          categoryId: _holidayCategoryId,
          priority: TaskPriority.p1High,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _tasksCategoryId,
      category: categories[_tasksCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _tasksCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _tasksCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-lunch',
          categoryId: _tasksCategoryId,
          priority: TaskPriority.p3Low,
        ),
        _task(
          date: date,
          id: 'task-deep-work',
          categoryId: _tasksCategoryId,
          priority: TaskPriority.p2Medium,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _hikingCategoryId,
      category: categories[_hikingCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _hikingCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _hikingCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-hiking',
          categoryId: _hikingCategoryId,
          priority: TaskPriority.p2Medium,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _meetingsCategoryId,
      category: categories[_meetingsCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _meetingsCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _meetingsCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-meeting',
          categoryId: _meetingsCategoryId,
          priority: TaskPriority.p0Urgent,
        ),
      ],
    ),
  ];
}

TimeBudgetProgress _budgetProgressForCategory({
  required DateTime date,
  required String categoryId,
  required CategoryDefinition? category,
  required List<PlannedBlock> blocks,
  required List<ActualTimeSlot> actualSlots,
  required List<Task> tasks,
}) {
  final plannedDuration = blocks.fold<Duration>(
    Duration.zero,
    (total, block) => total + block.duration,
  );
  final recordedDuration = actualSlots.fold<Duration>(
    Duration.zero,
    (total, slot) => total + slot.duration,
  );
  final remainingMinutes =
      plannedDuration.inMinutes - recordedDuration.inMinutes;
  final status = remainingMinutes < 0
      ? BudgetProgressStatus.overBudget
      : remainingMinutes <= 15
      ? BudgetProgressStatus.nearLimit
      : BudgetProgressStatus.underBudget;

  return TimeBudgetProgress(
    categoryId: categoryId,
    category: category,
    plannedDuration: plannedDuration,
    recordedDuration: recordedDuration,
    status: status,
    contributingEntries: actualSlots.map((slot) => slot.entry).toList(),
    taskProgressItems: [
      for (final task in tasks)
        TaskDayProgress(
          task: task,
          timeSpentOnDay: recordedDuration ~/ math.max(tasks.length, 1),
          wasCompletedOnDay: false,
        ),
    ],
    blocks: blocks,
  );
}

Task _task({
  required DateTime date,
  required String id,
  required String categoryId,
  required TaskPriority priority,
}) {
  final status = TaskStatus.inProgress(
    id: 'status-$id',
    createdAt: date,
    utcOffset: 0,
  );

  return Task(
    meta: Metadata(
      id: id,
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      categoryId: categoryId,
    ),
    data: TaskData(
      status: status,
      dateFrom: date,
      dateTo: date,
      statusHistory: [status],
      title: id,
      priority: priority,
    ),
  );
}

MyDailyTimelineBlockDensity myDailyTimelineBlockDensity({
  required DsTokens tokens,
  required double height,
  required Duration duration,
}) {
  if (duration <= const Duration(minutes: 35) ||
      height <= tokens.spacing.step9) {
    return MyDailyTimelineBlockDensity.compact;
  }
  if (duration >= const Duration(minutes: 90)) {
    return MyDailyTimelineBlockDensity.expanded;
  }
  if (height <= tokens.spacing.step10) {
    return MyDailyTimelineBlockDensity.regular;
  }
  return MyDailyTimelineBlockDensity.expanded;
}

String _formatTimelineHour(BuildContext context, int hour) {
  return _formatLocalizedPreviewTime(
    context,
    _previewClock(hour, 0),
    includeMinutes: false,
  );
}

DateTime _previewClock(int hour, int minute) {
  final dayOffset = hour >= 24 ? 1 : 0;
  return DateTime(2023, 10, 17 + dayOffset, hour % 24, minute);
}

String _formatLocalizedPreviewTime(
  BuildContext context,
  DateTime time, {
  bool includeMinutes = true,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = _uses24HourClock(context)
      ? (includeMinutes ? 'H:mm' : 'H')
      : (includeMinutes ? 'h:mma' : 'ha');

  return DateFormat(
    pattern,
    locale,
  ).format(time).toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _formatLocalizedPreviewTimeRange(
  BuildContext context, {
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) {
  final start = _formatLocalizedPreviewTime(
    context,
    _previewClock(startHour, startMinute),
  );
  final end = _formatLocalizedPreviewTime(
    context,
    _previewClock(endHour, endMinute),
  );
  return '$start-$end';
}

bool _uses24HourClock(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.alwaysUse24HourFormat ?? false) {
    return true;
  }

  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = DateFormat.jm(locale).pattern?.toLowerCase() ?? '';
  return !pattern.contains('a');
}

String _labelForCategory(BuildContext context, String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => context.messages.designSystemNavigationHolidayLabel,
    _tasksCategoryId => context.messages.designSystemNavigationLottiTasksLabel,
    _hikingCategoryId => context.messages.designSystemNavigationHikingLabel,
    _meetingsCategoryId => context.messages.designSystemMyDailyMeetingsLabel,
    _ => categoryId,
  };
}

IconData _iconForCategory(String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => Icons.flight_takeoff_rounded,
    _tasksCategoryId => Icons.work_outline_rounded,
    _hikingCategoryId => Icons.hiking_rounded,
    _meetingsCategoryId => Icons.forum_outlined,
    _ => Icons.label_outline_rounded,
  };
}

Color _colorForCategory(String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => const Color(0xFF9127F5),
    _tasksCategoryId => const Color(0xFF2CC6D3),
    _hikingCategoryId => const Color(0xFFD2AF20),
    _meetingsCategoryId => const Color(0xFF7B7B83),
    _ => const Color(0xFF888888),
  };
}

class _PreviewDailyOsSelectedDate extends DailyOsSelectedDate {
  _PreviewDailyOsSelectedDate(this._initialDate);

  final DateTime _initialDate;

  @override
  DateTime build() => _initialDate;
}

class _PreviewDailyOsController extends DailyOsController {
  _PreviewDailyOsController(this._dailyDataByDate);

  final Map<DateTime, DailyOsData> _dailyDataByDate;

  @override
  Future<DailyOsState> build() async {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final dailyData = _dailyDataByDate[selectedDate];

    if (dailyData == null) {
      throw StateError('Missing preview data for $selectedDate.');
    }

    return DailyOsState(
      selectedDate: selectedDate,
      dayPlan: dailyData.dayPlan,
      budgetProgress: dailyData.budgetProgress,
      timelineData: dailyData.timelineData,
    );
  }
}

class _PreviewUnifiedDailyOsDataController
    extends UnifiedDailyOsDataController {
  _PreviewUnifiedDailyOsDataController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async => _data;
}

class _PreviewTimeHistoryHeaderController extends TimeHistoryHeaderController {
  _PreviewTimeHistoryHeaderController(this._data);

  final TimeHistoryData _data;

  @override
  Future<TimeHistoryData> build() async => _data;
}
