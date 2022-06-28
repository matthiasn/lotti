import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LoggingPage extends StatefulWidget {
  const LoggingPage({super.key});

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
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsLogsTitle),
      body: StreamBuilder<List<LogEntry>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<LogEntry>> snapshot,
        ) {
          final logEntries = snapshot.data ?? [];

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
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
  const LogLineCard({
    super.key,
    required this.logEntry,
    required this.index,
  });

  final LogEntry logEntry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final timestamp = logEntry.createdAt.substring(0, 23);
    final domain = logEntry.domain;
    final subDomain = logEntry.subDomain;
    final message = logEntry.message;
    final color = logEntry.level == 'ERROR'
        ? getIt<ThemeService>().colors.error
        : getIt<ThemeService>().colors.entryTextColor;

    return GestureDetector(
      onTap: () {
        pushNamedRoute('/settings/logging/${logEntry.id}');
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(
          '$timestamp: $domain $subDomain $message',
          style: TextStyle(
            color: color,
            fontFamily: 'ShareTechMono',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class LogDetailPage extends StatelessWidget {
  LogDetailPage({
    super.key,
    @PathParam() required this.logEntryId,
  });

  final LoggingDb _db = getIt<LoggingDb>();

  final String logEntryId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsLogsTitle),
      body: StreamBuilder(
        stream: _db.watchLogEntryById(logEntryId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<LogEntry>> snapshot,
        ) {
          LogEntry? logEntry;
          final data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            logEntry = data.first;
          }

          if (logEntry == null) {
            return const EmptyScaffoldWithTitle('');
          }

          final timestamp = logEntry.createdAt.substring(0, 23);
          final domain = logEntry.domain;
          final level = logEntry.level;
          final subDomain = logEntry.subDomain;
          final message = logEntry.message;
          final stacktrace = logEntry.stacktrace;

          final clipboardText =
              '$timestamp $level $domain $subDomain\n\n$message\n\n$stacktrace';

          final headerStyle = level == 'ERROR'
              ? logDetailStyle.copyWith(
                  color: getIt<ThemeService>().colors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )
              : logDetailStyle.copyWith(fontSize: 20);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
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
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Message:', style: formLabelStyle),
                ),
                SelectableText(message, style: logDetailStyle),
                if (stacktrace != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Stack Trace:', style: formLabelStyle),
                  ),
                  SelectableText(stacktrace, style: logDetailStyle),
                ],
                IconButton(
                  icon: const Icon(MdiIcons.clipboardOutline),
                  iconSize: 48,
                  color: getIt<ThemeService>().colors.entryTextColor,
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
