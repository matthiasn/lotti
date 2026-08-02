import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';

/// The projection (Agenda / Day / Activity) the user last picked on the
/// Daily OS surface.
///
/// Lives outside the day page's `State` because the route-level root re-keys
/// that page on every date change: a `State` field would be discarded — and
/// the view silently reset — each time the user stepped to another day. Holding
/// it here makes the choice survive every date-change path (chevrons, the
/// jump-to-today button, the date picker, the sidebar calendar).
///
/// `null` means "the user has not chosen yet", in which case the page falls
/// back to its per-day default (Agenda with a plan, Activity without one).
/// The provider is deliberately in-memory only, so a fresh app start lands on
/// that default again.
class DailyOsNextPlanView extends Notifier<PlanView?> {
  @override
  PlanView? build() => null;

  /// Records an explicit view switch by the user.
  // ignore: use_setters_to_change_properties
  void select(PlanView view) {
    state = view;
  }
}

final NotifierProvider<DailyOsNextPlanView, PlanView?>
dailyOsNextPlanViewProvider = NotifierProvider<DailyOsNextPlanView, PlanView?>(
  DailyOsNextPlanView.new,
);
