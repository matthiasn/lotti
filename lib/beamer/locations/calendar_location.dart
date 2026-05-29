import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os/ui/pages/set_time_blocks_page.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_next_root.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

class CalendarLocation extends BeamLocation<BeamState> {
  CalendarLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/calendar',
    '/calendar/set-time-blocks',
    '/calendar/refine/:date',
    '/calendar/commit/:date',
    '/calendar/shutdown/:date',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final dailyOsNextRoute = _dailyOsNextRouteFrom(state.uri);
    final pages = [
      const BeamPage(
        key: ValueKey('calendar_page'),
        child: CalendarRoot(),
      ),
    ];

    if (state.uri.path == '/calendar/set-time-blocks') {
      pages.add(
        const BeamPage(
          key: ValueKey('set_time_blocks_page'),
          child: SetTimeBlocksPage(),
        ),
      );
    }
    if (dailyOsNextRoute != null) {
      pages.add(
        BeamPage(
          key: ValueKey(
            'daily_os_next_${dailyOsNextRoute.target.name}_'
            '${dailyOsNextRoute.datePath}',
          ),
          child: _DailyOsNextRoutePage(
            target: dailyOsNextRoute.target,
            date: dailyOsNextRoute.date,
          ),
        ),
      );
    }

    return pages;
  }
}

({DailyOsNextRouteTarget target, DateTime date, String datePath})?
_dailyOsNextRouteFrom(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length != 3 || segments.first != 'calendar') return null;

  DailyOsNextRouteTarget? target;
  for (final value in DailyOsNextRouteTarget.values) {
    if (value.name == segments[1]) {
      target = value;
      break;
    }
  }
  if (target == null) return null;

  final date = parseDailyOsNextRouteDate(segments[2]);
  if (date == null) return null;

  return (target: target, date: date, datePath: segments[2]);
}

class _DailyOsNextRoutePage extends ConsumerWidget {
  const _DailyOsNextRoutePage({
    required this.target,
    required this.date,
  });

  final DailyOsNextRouteTarget target;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(currentDraftPlanProvider(date));
    if (asyncPlan.hasValue) return _buildSurface(asyncPlan.requireValue);
    if (asyncPlan.hasError) {
      return _DailyOsNextRouteErrorPage(error: asyncPlan.error!);
    }
    return const _DailyOsNextRouteLoadingPage();
  }

  Widget _buildSurface(DraftPlan? plan) {
    if (plan == null) {
      return CapturePage(forDate: date);
    }
    return switch (target) {
      DailyOsNextRouteTarget.refine => RefinePage(draft: plan),
      DailyOsNextRouteTarget.commit => CommitPage(draft: plan),
      DailyOsNextRouteTarget.shutdown => ShutdownPage(forDate: date),
    };
  }
}

class _DailyOsNextRouteLoadingPage extends StatelessWidget {
  const _DailyOsNextRouteLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      appBar: _dailyOsNextRouteAppBar(context),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

AppBar _dailyOsNextRouteAppBar(BuildContext context) {
  final tokens = context.designTokens;
  return AppBar(
    backgroundColor: tokens.colors.background.level01,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: context.messages.dailyOsNextDayBack,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

class _DailyOsNextRouteErrorPage extends StatelessWidget {
  const _DailyOsNextRouteErrorPage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: _dailyOsNextRouteAppBar(context),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: Text(
            context.messages.dailyOsNextReconcileError(error.toString()),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Branches between the current Daily OS surface and the next-gen
/// agentic Capture flow based on [dailyOsNextEnabledFlag].
///
/// Kept as a thin wrapper so the [BeamPage] key stays stable across
/// flag flips — pushing/popping inside Capture / Reconcile doesn't
/// blow away the calendar tab's navigation history.
@visibleForTesting
class CalendarRoot extends StatefulWidget {
  const CalendarRoot({super.key});

  @override
  State<CalendarRoot> createState() => _CalendarRootState();
}

class _CalendarRootState extends State<CalendarRoot> {
  // Cached once so the StreamBuilder doesn't re-subscribe to a fresh
  // `watchConfigFlag` query on every rebuild of the tab.
  late final Stream<bool> _flagStream = getIt<JournalDb>().watchConfigFlag(
    dailyOsNextEnabledFlag,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _flagStream,
      initialData: false,
      builder: (context, snapshot) {
        final useNext = snapshot.data ?? false;
        return useNext ? const DailyOsNextRoot() : const DailyOsPage();
      },
    );
  }
}
