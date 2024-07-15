import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/time_by_category_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/tasks_counts.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String version = '';
  String buildNumber = '';

  final JournalDb _db = getIt<JournalDb>();
  late Stream<int> countStream;

  Future<void> getVersions() async {
    if (!(isWindows && isTestEnv)) {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        version = packageInfo.version;
        buildNumber = packageInfo.buildNumber;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getVersions();
    countStream = _db.watchJournalCount();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        return SliverBoxAdapterPage(
          title: context.messages.settingsAboutTitle,
          showBackButton: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Version: $version ($buildNumber)',
                  style: searchLabelStyle(),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Entries: ${snapshot.data}, ',
                      style: searchLabelStyle(),
                    ),
                    const FlaggedCount(),
                  ],
                ),
                const SizedBox(height: 10),
                const TaskCounts(),
                const TimeByCategoryChart(),
              ],
            ),
          ),
        );
      },
    );
  }
}
