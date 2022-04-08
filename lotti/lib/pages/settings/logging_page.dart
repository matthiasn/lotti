import 'package:flutter/material.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';

class LoggingPage extends StatefulWidget {
  const LoggingPage({Key? key}) : super(key: key);

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  final InsightsDb _db = getIt<InsightsDb>();
  late Stream<List<LogEntry>> stream = _db.watchLogEntries();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LogEntry>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<LogEntry>> snapshot,
      ) {
        List<LogEntry> logEntries = snapshot.data ?? [];

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8.0),
          children: List.generate(
            logEntries.length,
            (int index) {
              return LogLineCard(
                logEntry: logEntries.elementAt(index),
                index: index,
              );
            },
          ),
        );
      },
    );
  }
}

class LogLineCard extends StatelessWidget {
  final LogEntry logEntry;
  final int index;

  const LogLineCard({
    Key? key,
    required this.logEntry,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Text(
        '${logEntry.createdAt.substring(0, 23)}: ${logEntry.message}',
        style: TextStyle(
          color: AppColors.entryTextColor,
          fontFamily: 'ShareTechMono',
          fontSize: 16.0,
        ),
      ),
    );
  }
}
