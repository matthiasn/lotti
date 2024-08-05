import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/day_view_controller.dart';
import 'package:lotti/features/tasks/ui/time_by_category_chart.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

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
  final EventController _eventController = EventController();

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

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(daySelectionControllerProvider);

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              DayView(
                backgroundColor: Colors.transparent,
                key: Key(selectedDay.ymd),
                showHalfHours: true,
                heightPerMinute: _heightPerMinute,
                keepScrollOffset: true,
                initialDay: selectedDay,
                headerStyle: HeaderStyle(
                  headerTextStyle: chartTitleStyleMonospace.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  leftIcon: const Icon(
                    Icons.arrow_back,
                    size: 24,
                  ),
                  leftIconPadding: const EdgeInsets.only(
                    left: 30,
                    top: 10,
                    bottom: 10,
                  ),
                  rightIconPadding: const EdgeInsets.only(
                    right: 30,
                    top: 10,
                    bottom: 10,
                  ),
                  rightIcon: const Icon(
                    Icons.arrow_forward,
                    size: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                dateStringBuilder: (date, {DateTime? secondaryDate}) =>
                    date.ymwd,
                timeLineBuilder: timeLineBuilder,
                hourIndicatorSettings: HourIndicatorSettings(
                  color: Theme.of(context).dividerColor,
                ),
                halfHourIndicatorSettings: HourIndicatorSettings(
                  color: Theme.of(context).dividerColor,
                  lineStyle: LineStyle.dashed,
                ),
                onEventTap: (events, date) {
                  final event = events.firstOrNull?.event as JournalEntity?;
                  final id = event?.id;
                  if (id != null) {
                    beamToNamed('/journal/$id');
                  }
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
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  width: 180,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Theme.of(context).shadowColor.withOpacity(0.2),
                  ),
                  child: Slider(
                    inactiveColor: Theme.of(context).dividerColor,
                    min: 0.25,
                    max: 5,
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
        const CollapsibleTimeChart(),
      ],
    );
  }
}
