import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/day_view_controller.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../../../../services/nav_service.dart';

class DayViewPage extends ConsumerStatefulWidget {
  const DayViewPage({
    required this.initialDayYmd,
    super.key,
  });

  final String initialDayYmd;

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
      child: Scaffold(
        appBar: const TitleAppBar(
          title: 'Day View',
        ),
        body: DayViewWidget(
          initialDay: DateUtilsExtension.fromYmd(widget.initialDayYmd) ??
              DateTime.now(),
        ),
      ),
    );
  }
}

class DayViewWidget extends StatelessWidget {
  const DayViewWidget({
    required this.initialDay,
    super.key,
    this.state,
    this.width,
  });

  final GlobalKey<DayViewState>? state;
  final double? width;
  final DateTime initialDay;

  @override
  Widget build(BuildContext context) {
    return DayView(
      key: state,
      width: width,
      startDuration: const Duration(hours: 8),
      showHalfHours: true,
      heightPerMinute: 2,
      keepScrollOffset: true,
      initialDay: initialDay,
      timeLineBuilder: _timeLineBuilder,
      hourIndicatorSettings: HourIndicatorSettings(
        color: Theme.of(context).dividerColor,
      ),
      onEventTap: (events, date) {
        final event = events.firstOrNull?.event as JournalEntity?;
        final id = event?.id;
        if (id != null) {
          beamToNamed('/journal/$id');
        }
      },
      onEventLongTap: (events, date) {
        const snackBar = SnackBar(content: Text('on LongTap'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
      verticalLineOffset: 0,
      timeLineWidth: 65,
      liveTimeIndicatorSettings: const LiveTimeIndicatorSettings(
        color: Colors.redAccent,
        showBullet: false,
        showTime: true,
        showTimeBackgroundView: true,
      ),
    );
  }

  Widget _timeLineBuilder(DateTime date) {
    if (date.minute != 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: -8,
            right: 8,
            child: Text(
              '${date.hour}:${date.minute}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black.withAlpha(50),
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    final hour = ((date.hour - 1) % 12) + 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: -8,
          right: 8,
          child: Text(
            "$hour ${date.hour ~/ 12 == 0 ? "am" : "pm"}",
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
