import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/service/front_logged_time_reader.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/providers/service_providers.dart';

/// The series a reply's chart draws, read when the chart is drawn — so time
/// in a private category shows only while private entries do.
///
/// shortcut: read once per mount, not on journal notifications; a reply's
/// chart is a past answer, so it catches up the next time it is drawn.
final FutureProviderFamily<InsightsChartData, FrontLoggedTimeChart>
frontLoggedTimeChartProvider = FutureProvider.autoDispose
    .family<InsightsChartData, FrontLoggedTimeChart>((ref, chart) async {
      final read = await readFrontLoggedTime(
        ref.watch(journalDbProvider),
        chart.range,
        chart.categoryIds,
      );
      return buildChartData(read.buckets, chart.range);
    }, name: 'frontLoggedTimeChartProvider');
