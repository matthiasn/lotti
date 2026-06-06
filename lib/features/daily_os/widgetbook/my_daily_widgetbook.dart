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

part 'my_daily_preview_screen.dart';
part 'my_daily_preview_timeline.dart';
part 'my_daily_widgetbook_fixtures.dart';

const _holidayCategoryId = 'holiday';
const _tasksCategoryId = 'lotti-tasks';
const _hikingCategoryId = 'hiking';
const _meetingsCategoryId = 'meetings';
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
