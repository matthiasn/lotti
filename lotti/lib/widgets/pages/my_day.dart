import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_detail_route.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class MyDayPage extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();

  MyDayPage({Key? key}) : super(key: key);

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
        ids: null,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>?> snapshot,
      ) {
        final List<Meeting> meetings = <Meeting>[];
        List<JournalEntity>? entities = snapshot.data;
        if (entities == null) {
          return const SizedBox.shrink();
        }
        for (JournalEntity journalEntity in entities) {
          Duration dur = entryDuration(journalEntity);
          if (dur > const Duration()) {
            String eventName = journalEntity.map(
              journalEntry: (journalEntry) => journalEntry.entryText.plainText,
              journalImage: (journalImage) => '',
              journalAudio: (journalAudio) => '',
              task: (task) => task.data.title,
              quantitative: (quantitative) => quantitative.data.dataType,
              measurement: (measurement) =>
                  measurement.data.dataType.displayName,
              habitCompletion: (habitCompletion) => '',
              survey: (survey) => survey.data.taskResult.identifier,
            );
            Color background = journalEntity.map(
              journalEntry: (journalEntry) => Colors.lightGreen,
              journalImage: (journalImage) => Colors.lightBlue,
              journalAudio: (journalAudio) => AppColors.error,
              task: (task) => Colors.lightBlue,
              quantitative: (quantitative) => Colors.lightBlue,
              measurement: (measurement) => Colors.lightBlue,
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

        return Scaffold(
          appBar: const VersionAppBar(title: 'My Day'),
          body: SfCalendar(
            view: CalendarView.timelineWeek,
            dataSource: MeetingDataSource(meetings),
            onTap: (CalendarTapDetails cal) {
              cal.appointments?.forEach((element) {
                Meeting meeting = element as Meeting;
                debugPrint(meeting.journalEntity.toString());

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return EntryDetailRoute(
                        item: meeting.journalEntity,
                        index: 0,
                      );
                    },
                  ),
                );
              });
            },
          ),
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
