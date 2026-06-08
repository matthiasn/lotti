part of 'my_daily_widgetbook.dart';

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
