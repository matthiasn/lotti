import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/service/front_pull_request_reader.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';

/// The days a reply's pull request chart draws, read from the device while
/// the chart is shown — so a private task's pull requests show only while
/// private entries do.
///
/// Read again when a pull request is refreshed, linked or unlinked, a task
/// changes its category or privacy, or private entries are shown or hidden.
final StreamProviderFamily<FrontPullRequestDays, FrontPullRequestChart>
frontPullRequestChartProvider = StreamProvider.autoDispose
    .family<FrontPullRequestDays, FrontPullRequestChart>((ref, chart) {
      final journalDb = ref.watch(journalDbProvider);
      final notifications = ref.watch(maybeUpdateNotificationsProvider);

      Future<FrontPullRequestDays> fetch() async {
        final read = await readFrontPullRequests(journalDb, chart);
        return frontPullRequestDays(read.pullRequests, chart.range);
      }

      if (notifications == null) return Stream.fromFuture(fetch());
      return notificationDrivenItemStream<FrontPullRequestDays>(
        notifications: notifications,
        notificationKeys: const {
          pullRequestNotification,
          taskNotification,
          linkNotification,
          privateToggleNotification,
        },
        fetcher: fetch,
      ).where((data) => data != null).cast<FrontPullRequestDays>();
    }, name: 'frontPullRequestChartProvider');
