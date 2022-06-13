import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LoggingPage extends StatefulWidget {
  const LoggingPage({Key? key}) : super(key: key);

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  final LoggingDb _db = getIt<LoggingDb>();
  late Stream<List<LogEntry>> stream = _db.watchLogEntries();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsLogsTitle),
      body: StreamBuilder<List<LogEntry>>(
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
      ),
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
    String timestamp = logEntry.createdAt.substring(0, 23);
    String domain = logEntry.domain;
    String? subDomain = logEntry.subDomain;
    String message = logEntry.message;
    Color color =
        logEntry.level == 'ERROR' ? AppColors.error : AppColors.entryTextColor;

    return GestureDetector(
      onTap: () {
        pushNamedRoute('/settings/logging/${logEntry.id}');
      },
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Text(
          '$timestamp: $domain $subDomain $message',
          style: TextStyle(
            color: color,
            fontFamily: 'ShareTechMono',
            fontSize: 11.0,
          ),
        ),
      ),
    );
  }
}

class LogDetailPage extends StatelessWidget {
  final LoggingDb _db = getIt<LoggingDb>();

  LogDetailPage({
    Key? key,
    @PathParam() required this.logEntryId,
  }) : super(key: key);

  final String logEntryId;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsLogsTitle),
      body: StreamBuilder(
        stream: _db.watchLogEntryById(logEntryId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<LogEntry>> snapshot,
        ) {
          LogEntry? logEntry;
          var data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            logEntry = data.first;
          }

          if (logEntry == null) {
            return const EmptyScaffoldWithTitle('');
          }

          String timestamp = logEntry.createdAt.substring(0, 23);
          String domain = logEntry.domain;
          String level = logEntry.level;
          String? subDomain = logEntry.subDomain;
          String message = logEntry.message;
          String? stacktrace = logEntry.stacktrace;

          String clipboardText =
              '$timestamp $level $domain $subDomain\n\n$message\n\n$stacktrace';

          TextStyle headerStyle = level == 'ERROR'
              ? logDetailStyle.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )
              : logDetailStyle.copyWith(fontSize: 20);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Wrap(
                  children: [
                    Text(timestamp, style: headerStyle),
                    const SizedBox(width: 10),
                    Text(level, style: headerStyle),
                    const SizedBox(width: 10),
                    Text(domain, style: headerStyle),
                    if (subDomain != null) ...[
                      const SizedBox(width: 10),
                      Text(subDomain, style: headerStyle),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text('Message:', style: formLabelStyle),
                ),
                SelectableText(message, style: logDetailStyle),
                if (stacktrace != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text('Stack Trace:', style: formLabelStyle),
                  ),
                  SelectableText(stacktrace, style: logDetailStyle),
                ],
                IconButton(
                  icon: const Icon(MdiIcons.clipboardOutline),
                  iconSize: 48,
                  color: AppColors.entryTextColor,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clipboardText));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
