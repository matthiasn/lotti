import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class MyDayPage extends StatelessWidget {
  MyDayPage({super.key});

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchJournalEntities(
        types: [
          'JournalEntry',
          'JournalAudio',
          'JournalImage',
          'SurveyEntry',
          'Task',
          'MeasurementEntry',
          'QuantitativeEntry',
          'SurveyEntry',
        ],
        starredStatuses: [true, false],
        privateStatuses: [true, false],
        flaggedStatuses: [0, 1],
        ids: null,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>?> snapshot,
      ) {
        final meetings = <Meeting>[];
        final entities = snapshot.data;
        if (entities == null) {
          return const SizedBox.shrink();
        }
        for (final journalEntity in entities) {
          final dur = entryDuration(journalEntity);
          if (dur > Duration.zero) {
            final eventName = journalEntity.map(
              journalEntry: (journalEntry) =>
                  '${journalEntry.entryText?.plainText}',
              journalImage: (journalImage) => '',
              journalAudio: (journalAudio) => '',
              task: (task) => task.data.title,
              quantitative: (quantitative) => quantitative.data.dataType,
              workout: (workout) => workout.data.workoutType,
              measurement: (measurement) => measurement.data.dataTypeId,
              habitCompletion: (habitCompletion) => '',
              survey: (survey) => survey.data.taskResult.identifier,
            );
            final background = journalEntity.map(
              journalEntry: (journalEntry) => Colors.lightGreen,
              journalImage: (journalImage) => Colors.lightBlue,
              journalAudio: (journalAudio) =>
                  getIt<ThemeService>().colors.error,
              task: (task) => Colors.lightBlue,
              quantitative: (quantitative) => Colors.lightBlue,
              measurement: (measurement) => Colors.lightBlue,
              workout: (workout) => Colors.lightGreen,
              habitCompletion: (habitCompletion) => Colors.lightBlue,
              survey: (survey) => Colors.pink,
            );

            if (!eventName.contains('SLEEP_IN_BED') &&
                !eventName.contains('cumulative_')) {
              meetings.add(
                Meeting(
                  isAllDay: false,
                  to: journalEntity.meta.dateTo,
                  background: background,
                  eventName: eventName.replaceAll('HealthDataType.', ''),
                  from: journalEntity.meta.dateFrom,
                  journalEntity: journalEntity,
                ),
              );
            }
          }
        }

        return SfCalendar(
          backgroundColor: Colors.white,
          view: CalendarView.timelineWeek,
          dataSource: MeetingDataSource(meetings),
          onTap: (CalendarTapDetails cal) {
            cal.appointments?.forEach((element) {
              final meeting = element as Meeting;
              final entryId = meeting.journalEntity.meta.id;
              pushNamedRoute('/journal/$entryId');
            });
          },
        );
      },
    );
  }
}

// adapted from calendar sample page
class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return _getMeetingData(index).from;
  }

  @override
  DateTime getEndTime(int index) {
    return _getMeetingData(index).to;
  }

  @override
  String getSubject(int index) {
    return _getMeetingData(index).eventName;
  }

  @override
  Color getColor(int index) {
    return _getMeetingData(index).background;
  }

  @override
  bool isAllDay(int index) {
    return _getMeetingData(index).isAllDay;
  }

  Meeting _getMeetingData(int index) {
    final dynamic meeting = appointments![index];
    late final Meeting meetingData;
    if (meeting is Meeting) {
      meetingData = meeting;
    }

    return meetingData;
  }
}

class Meeting {
  Meeting({
    required this.eventName,
    required this.from,
    required this.to,
    required this.background,
    required this.isAllDay,
    required this.journalEntity,
  });
  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;
  JournalEntity journalEntity;
}
