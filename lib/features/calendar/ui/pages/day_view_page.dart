import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/calendar/ui/widgets/time_by_category_chart_card.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:visibility_detector/visibility_detector.dart';

const lowerLimit = 0.25;
const upperLimit = 5.0;

class DayViewPage extends ConsumerStatefulWidget {
  const DayViewPage({
    required this.initialDayYmd,
    required this.timeSpanDays,
    super.key,
  });

  final String initialDayYmd;
  final int timeSpanDays;

  @override
  DayViewPageState createState() => DayViewPageState();
}

class DayViewPageState extends ConsumerState<DayViewPage> {
  final _eventController = EventController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(dayViewControllerProvider).value;

    if (events != null) {
      _eventController
        ..removeWhere((_) => true)
        ..addAll(events);
    }

    return CalendarControllerProvider(
      controller: _eventController,
      child: const Scaffold(
        body: DayViewWidget(),
      ),
    );
  }
}

class DayViewWidget extends ConsumerStatefulWidget {
  const DayViewWidget({
    super.key,
    this.state,
  });

  final GlobalKey<DayViewState>? state;

  @override
  ConsumerState<DayViewWidget> createState() => _DayViewWidgetState();
}

class _DayViewWidgetState extends ConsumerState<DayViewWidget> {
  var _heightPerMinute = .5;

  Widget timeLineBuilder(DateTime date) {
    if (date.minute == 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: -8,
            right: 8,
            child: Text(
              hhMmFormat.format(date),
              textAlign: TextAlign.right,
              style: chartTitleStyleMonospace,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  DateTime _lastScaleUpdate = DateTime.now();

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (DateTime.now().difference(_lastScaleUpdate).abs() <
        const Duration(milliseconds: 50)) {
      return;
    }
    setState(() {
      final verticalScale = -(1 - details.verticalScale) / 5;
      final heightPerMinute = _heightPerMinute * (1 + verticalScale);
      _heightPerMinute = heightPerMinute.clamp(lowerLimit, upperLimit);
    });
    _lastScaleUpdate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('DayViewPage'),
      onVisibilityChanged:
          ref.read(dayViewControllerProvider.notifier).onVisibilityChanged,
      child: GestureDetector(
        onScaleUpdate: onScaleUpdate,
        child: Stack(
          children: [
            DayView(
              backgroundColor: Colors.transparent,
              key: ref.watch(calendarGlobalKeyControllerProvider),
              showHalfHours: true,
              heightPerMinute: _heightPerMinute,
              keepScrollOffset: true,
              headerStyle: HeaderStyle(
                headerTextStyle: chartTitleStyleMonospace.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.primary,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainer,
                ),
                leftIconConfig: IconDataConfig(
                  color: context.colorScheme.primary,
                ),
                rightIconConfig: IconDataConfig(
                  color: context.colorScheme.primary,
                ),
              ),
              dateStringBuilder: (date, {DateTime? secondaryDate}) => date.ymwd,
              timeLineBuilder: timeLineBuilder,
              hourIndicatorSettings: HourIndicatorSettings(
                color: Theme.of(context).dividerColor,
              ),
              halfHourIndicatorSettings: HourIndicatorSettings(
                color: Theme.of(context).dividerColor,
                lineStyle: LineStyle.dashed,
              ),
              onEventTap: (events, date) {
                final event = events.firstOrNull?.event as CalendarEvent?;
                final id = event?.entity.id;
                final linkedFrom = event?.linkedFrom;
                linkedFrom != null
                    ? linkedFrom is Task
                        ? beamToNamed('/tasks/${linkedFrom.meta.id}')
                        : beamToNamed('/journal/${linkedFrom.meta.id}')
                    : beamToNamed('/journal/$id');
              },
              verticalLineOffset: 0,
              timeLineWidth: 65,
              liveTimeIndicatorSettings: LiveTimeIndicatorSettings(
                color: Colors.redAccent,
                showTime: true,
                showTimeBackgroundView: true,
                timeStringBuilder: (date, {DateTime? secondaryDate}) =>
                    '  ${hhMmFormat.format(date)}',
              ),
            ),
            const Positioned(
              bottom: 50,
              right: 20,
              child: TimeByCategoryChartCard(),
            ),
            Positioned(
              bottom: 10,
              right: 20,
              child: GlassContainer.clearGlass(
                width: 200,
                height: 32,
                elevation: 0,
                color: Theme.of(context).shadowColor.withAlpha(51),
                borderRadius: BorderRadius.circular(15),
                child: Slider(
                  inactiveColor: Theme.of(context).dividerColor,
                  min: lowerLimit,
                  max: upperLimit,
                  value: _heightPerMinute,
                  onChanged: (double value) {
                    setState(() {
                      _heightPerMinute = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
