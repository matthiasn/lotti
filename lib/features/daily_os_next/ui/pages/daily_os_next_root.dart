import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_result.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

/// Entry point for the Daily OS Next surface.
///
/// Shows the [DayPage] for the selected date: the real plan when one
/// exists, otherwise the empty Day surface (its timeline still reflects
/// any tracked time) whose footer CTA opens the day-planning modal
/// ([showDayPlanningModal]) for the Capture → Reconcile → Drafting ritual.
/// A small date strip lets the user pick the day first.
class DailyOsNextRoot extends ConsumerStatefulWidget {
  const DailyOsNextRoot({super.key});

  @override
  ConsumerState<DailyOsNextRoot> createState() => _DailyOsNextRootState();
}

class _DailyOsNextRootState extends ConsumerState<DailyOsNextRoot> {
  DateTime get _today {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _shiftDay(int days) {
    ref.read(dailyOsNextSelectedDateProvider.notifier).shiftDays(days);
  }

  /// Opens the create ritual and routes its typed outcome through the Daily OS
  /// onboarding session controller.
  ///
  /// For an ordinary user (no active walkthrough session) both branches are
  /// no-ops — `complete`/`dismiss` return immediately — so this behaves exactly
  /// like the previous fire-and-forget open. During a walkthrough it records
  /// completion (retiring the auto-show cadence) or a dismissal skip.
  Future<void> _runCheckIn(DateTime date) async {
    final setupStatus = await ref.read(dailyOsSetupStatusProvider.future);
    if (!mounted) return;
    if (!setupStatus.hasInferenceRoute) {
      nav_service.beamToNamed('/settings/daily-os');
      return;
    }
    final result = await showDayPlanningModal(
      context: context,
      dayDate: date,
      intent: const DayPlanningCreate(),
    );
    if (!mounted) return;
    final controller = ref.read(
      dailyOsOnboardingSessionControllerProvider.notifier,
    );
    if (result is DayPlanningCreated) {
      await controller.complete(createdTaskIds: result.createdTaskIds);
    } else {
      controller.dismiss();
    }
  }

  /// Opens the design-system date picker.
  ///
  /// The shared modal carries its own "Today" quick action in the header,
  /// which is what lets the phone header drop the standalone Today button
  /// without losing the way back to today.
  Future<void> _pickDate() async {
    // Anchor the picker window to the current selection (not `_today`)
    // so the prev/next chevrons can never drift past `firstDate` or
    // `lastDate`. Day arithmetic via the `DateTime` constructor stays
    // DST-safe.
    final selected = ref.read(dailyOsNextSelectedDateProvider);
    final picked = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.dailyOsNextDayTitle,
      initialDate: selected,
      firstDate: DateTime(
        selected.year - 1,
        selected.month,
        selected.day,
      ),
      lastDate: DateTime(
        selected.year + 1,
        selected.month,
        selected.day,
      ),
    );
    final date = picked?.date;
    if (date != null) {
      ref.read(dailyOsNextSelectedDateProvider.notifier).select(date);
    }
  }

  void _goToToday() {
    ref.read(dailyOsNextSelectedDateProvider.notifier).goToToday();
  }

  @override
  Widget build(BuildContext context) {
    // Day selection lives in a provider so the desktop sidebar's
    // month calendar can drive it.
    final selectedDate = ref.watch(dailyOsNextSelectedDateProvider);
    final asyncPlan = ref.watch(currentDraftPlanProvider(selectedDate));
    if (asyncPlan.hasValue) {
      return _buildSurface(selectedDate, asyncPlan.requireValue);
    }
    if (asyncPlan.hasError) return _ErrorShell(error: '${asyncPlan.error}');
    return const _LoadingShell();
  }

  Widget _buildSurface(DateTime selectedDate, DraftPlan? plan) {
    final strip = _DateStrip(
      selected: selectedDate,
      isToday: selectedDate.isAtSameMomentAs(_today),
      onPrev: () => _shiftDay(-1),
      onNext: () => _shiftDay(1),
      onPick: _pickDate,
      onToday: _goToToday,
    );
    if (plan != null) {
      return DayPage(
        key: ValueKey(selectedDate.toIso8601String()),
        draft: plan,
        dateStrip: strip,
      );
    }
    // No plan for the selected date — show the Day surface in its empty
    // mode so any recorded sessions are still visible on the timeline.
    // The footer CTA opens the day-planning modal (Capture → Reconcile →
    // Drafting), a full-height layer that covers the bottom nav.
    return DayPage(
      key: ValueKey('empty-${selectedDate.toIso8601String()}'),
      draft: DraftPlan.emptyForDay(selectedDate),
      hasPlan: false,
      onCheckIn: () => unawaited(_runCheckIn(selectedDate)),
      dateStrip: strip,
    );
  }
}

/// Compact date strip — prev arrow, tappable date label that opens the
/// design-system date picker, next arrow, and on desktop a "Today" button
/// once the selection has left today.
///
/// Layout is stable across dates: the label reserves the width of the
/// *widest* date this locale, style and text scale can produce (see
/// [_stableDateLabelWidth]), so neither chevron moves as the user steps
/// through days and the next chevron can be clicked repeatedly. The Today
/// button sits after the chevrons, so its appearance cannot push them
/// either; on a phone it is left out altogether and the picker's own
/// Today action is the way back.
class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    // Tabular figures keep the day and year digits from re-flowing the
    // label between dates of equal character count.
    final labelStyle = tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final wide = isDesktopLayout(context);
    // A phone drops the year: reserving the widest possible "Wed, Sep 30,
    // 2026" plus two chevrons does not fit 390 pt, and the year is the least
    // useful part of it while stepping through nearby days.
    final locale = Localizations.localeOf(context).toString();
    final format = wide ? DateFormat.yMMMEd(locale) : DateFormat.MMMEd(locale);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: material.previousPageTooltip,
          onPressed: onPrev,
        ),
        Flexible(
          child: InkWell(
            onTap: onPick,
            onLongPress: onToday,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: ConstrainedBox(
                // Reserved, measured width — not a hardcoded pixel value —
                // so the chevrons hold still for every date and grow with
                // the user's font-size setting.
                constraints: BoxConstraints(
                  minWidth: _stableDateLabelWidth(
                    context,
                    format: format,
                    style: labelStyle,
                    todayLabel: messages.dailyOsTodayButton,
                  ),
                ),
                child: Text(
                  isToday
                      ? messages.dailyOsTodayButton
                      : format.format(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: material.nextPageTooltip,
          onPressed: onNext,
        ),
        // Desktop only, and only off-today. A phone header has no width to
        // spare beside the date — the button squeezed the date into an
        // ellipsis — and the picker this label opens carries its own Today
        // quick action, so nothing is lost by leaving it out there.
        if (!isToday && wide) ...[
          SizedBox(width: tokens.spacing.step2),
          DesignSystemButton(
            key: const Key('daily_os_date_strip_today'),
            label: messages.dailyOsTodayButton,
            leadingIcon: Icons.today_rounded,
            variant: DesignSystemButtonVariant.outlined,
            size: DesignSystemButtonSize.dense,
            onPressed: onToday,
          ),
        ],
      ],
    );
  }
}

/// Cache of measured label widths, keyed by everything that can change one:
/// locale, the resolved text style, and the ambient text scale.
final Map<String, double> _dateLabelWidthCache = <String, double>{};

/// The width the widest label this strip can ever show needs, measured with
/// the real style and text scaler rather than assumed.
///
/// Date strings differ in width by weekday and month name ("Sun, May 3" vs.
/// "Wednesday, September 11"), which is what makes an unreserved label push
/// the next chevron around as the user navigates. Laying out every
/// weekday × month combination [format] can produce (plus the "Today" label)
/// yields an exact upper bound that follows the font, the locale and the
/// user's font-size setting — where a hardcoded pixel width would clip or
/// wobble the moment any of those changed.
double _stableDateLabelWidth(
  BuildContext context, {
  required DateFormat format,
  required TextStyle style,
  required String todayLabel,
}) {
  final locale = Localizations.localeOf(context).toString();
  final textScaler = MediaQuery.textScalerOf(context);
  final key =
      '$locale|${format.pattern}|$todayLabel|${style.hashCode}'
      '|${textScaler.scale(100)}';
  final cached = _dateLabelWidthCache[key];
  if (cached != null) return cached;

  final candidates = <String>[todayLabel];
  for (var month = 1; month <= 12; month++) {
    // Seven consecutive two-digit days cover all seven weekday names, and
    // the loop covers all twelve month names.
    for (var day = 20; day <= 26; day++) {
      candidates.add(format.format(DateTime(2027, month, day)));
    }
  }

  final painter = TextPainter(
    textDirection: Directionality.of(context),
    textScaler: textScaler,
    maxLines: 1,
  );
  var widest = 0.0;
  for (final candidate in candidates) {
    painter
      ..text = TextSpan(text: candidate, style: style)
      ..layout();
    widest = math.max(widest, painter.width);
  }
  painter.dispose();
  // Sub-pixel rounding on a fractional width can still nudge neighbours by a
  // physical pixel; ceil once here so the reserved box is integral.
  final width = widest.ceilToDouble();
  _dateLabelWidthCache[key] = width;
  return width;
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: Text(
            error,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ),
      ),
    );
  }
}
