part of 'my_daily_widgetbook.dart';

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
              userName: '',
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
            '${DateFormat('EEEE', locale).format(selectedDate)}, '
            '${DateFormat.yMMMd(locale).format(selectedDate)}',
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
