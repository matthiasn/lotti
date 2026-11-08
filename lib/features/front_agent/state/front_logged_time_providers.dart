import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/service/front_logged_time_reader.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';

/// The series a reply's chart draws, read while the chart is shown — so
/// time in a private category shows only while private entries do.
///
/// Read again on the notifications the Insights page refetches on: an
/// entry, a task or a link changing what is attributed where, and the
/// private toggle changing what the read may return. Unthrottled, unlike
/// that page, so hiding private entries takes their time off the chart at
/// once; a chart's read is at most a month.
final StreamProviderFamily<InsightsChartData, FrontLoggedTimeChart>
frontLoggedTimeChartProvider = StreamProvider.autoDispose
    .family<InsightsChartData, FrontLoggedTimeChart>((ref, chart) {
      final journalDb = ref.watch(journalDbProvider);
      final notifications = ref.watch(maybeUpdateNotificationsProvider);

      Future<InsightsChartData> fetch() async {
        final read = await readFrontLoggedTime(
          journalDb,
          chart.range,
          chart.categoryIds,
          namedCategoryIds: chart.namedCategoryIds,
        );
        return buildChartData(read.buckets, chart.range);
      }

      if (notifications == null) return Stream.fromFuture(fetch());
      return notificationDrivenItemStream<InsightsChartData>(
        notifications: notifications,
        notificationKeys: const {
          textEntryNotification,
          taskNotification,
          linkNotification,
          privateToggleNotification,
        },
        fetcher: fetch,
      ).where((data) => data != null).cast<InsightsChartData>();
    }, name: 'frontLoggedTimeChartProvider');
