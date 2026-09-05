import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the design-system date picker anchored to [selected] and returns
/// the picked day, or null when dismissed.
///
/// The shared modal carries its own "Today" quick action in the header,
/// which is what lets the phone header drop the standalone Today button
/// without losing the way back to today.
///
/// The picker window is anchored to the current [selected] day (not today)
/// so the prev/next chevrons can never drift past `firstDate` or
/// `lastDate` — but today is always kept inside the window: a selection
/// more than a year out would otherwise fall outside it, and the picker
/// disables its own Today action when today is out of range, exactly the
/// case where a phone, which carries no Today button, needs it most. Day
/// arithmetic via the `DateTime` constructor stays DST-safe.
Future<DateTime?> showDailyOsDayPicker(
  BuildContext context, {
  required DateTime selected,
}) async {
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final firstDate = _earlier(
    DateTime(selected.year - 1, selected.month, selected.day),
    today,
  );
  final lastDate = _later(
    DateTime(selected.year + 1, selected.month, selected.day),
    today,
  );
  final picked = await showDesignSystemDatePicker(
    context: context,
    title: context.messages.dailyOsNextDayTitle,
    initialDate: selected,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  return picked?.date;
}

DateTime _earlier(DateTime a, DateTime b) => a.isAfter(b) ? b : a;

DateTime _later(DateTime a, DateTime b) => a.isBefore(b) ? b : a;

/// Compact date strip — prev arrow, tappable date label that opens the
/// design-system date picker (long-press returns to today), next arrow, and
/// on desktop a "Today" button once the selection has left today.
///
/// Shared by the Daily OS surface header (`DailyOsNextRoot`) and the docked
/// day-view column (`DayViewSidePanel`), so stepping through days looks and
/// behaves the same wherever a day is chosen. The strip is presentation only:
/// hosts own the selected day and hand in the callbacks.
///
/// Layout is stable across dates: the label reserves the width of the
/// *widest* date this locale, style and text scale can produce (see
/// [_stableDateLabelWidth]), so neither chevron moves as the user steps
/// through days and the next chevron can be clicked repeatedly. The Today
/// button sits after the chevrons, so its appearance cannot push them
/// either; on a phone it is left out altogether and the picker's own
/// Today action is the way back.
class DailyOsDateStrip extends StatelessWidget {
  const DailyOsDateStrip({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
    this.compact = false,
    super.key,
  });

  /// Tighter geometry for a narrow host — the docked day-view column, where
  /// the strip shares one row with the timeline's own buttons. The label
  /// sits in a tighter inset, prefers weekday + month + day and falls back
  /// to month + day (measured, like the regular tiers), and the standalone
  /// Today button is left out: a long press on the label and the picker's
  /// own Today action remain the way back. The chevrons keep their full
  /// 48dp box — a glyph-only control owes the `TapTargets.minimum` floor.
  final bool compact;

  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // The pane, not the window. `MediaQuery` reports the whole window, but
      // the desktop sidebar is user-resizable up to 500 px, so a "desktop"
      // window can leave this strip barely 460 px — where the year and the
      // Today button do not fit even though the breakpoint says they should.
      builder: (context, constraints) => _build(context, constraints.maxWidth),
    );
  }

  Widget _build(BuildContext context, double available) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    // Tabular figures keep the day and year digits from re-flowing the
    // label between dates of equal character count.
    final labelStyle = tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final locale = Localizations.localeOf(context).toString();
    final todayLabel = messages.dailyOsTodayButton;
    const chevrons = kMinInteractiveDimension * 2;
    // The label's own chrome counts too: it sits in an inset on each side,
    // so a pane between `reserved + chevrons` and that plus the insets would
    // pick a format and then ellipsize it.
    final labelInset = compact ? tokens.spacing.step2 : tokens.spacing.step3;
    final labelChrome = labelInset * 2;

    // Two variants only. A third, numeric tier was tried and removed: in
    // every width/scale it actually engaged, the room left was already below
    // even "Wed, 5/27", so the label ellipsized anyway — and at those sizes
    // the rest of the surface overflows independently. The ellipsis is the
    // honest floor here, not a missing tier. The compact host starts one
    // tier down (no year) and falls back to month + day.
    final wideFormat = compact
        ? DateFormat.MMMEd(locale)
        : DateFormat.yMMMEd(locale);
    final narrowFormat = compact
        ? DateFormat.MMMd(locale)
        : DateFormat.MMMEd(locale);
    final wideReserved = _stableDateLabelWidth(
      context,
      format: wideFormat,
      style: labelStyle,
      todayLabel: todayLabel,
    );
    bool fits({double extra = 0}) =>
        available >= wideReserved + chevrons + labelChrome + extra;

    // Unbounded width (an intrinsics pass) cannot be measured against; fall
    // back to the window breakpoint there.
    final wide = available.isFinite ? fits() : isDesktopLayout(context);
    final showToday =
        !compact &&
        !isToday &&
        wide &&
        (!available.isFinite ||
            fits(extra: _todayControlWidth(context, tokens)));
    final format = wide ? wideFormat : narrowFormat;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(LottiIcons.chevronLeft),
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
                horizontal: labelInset,
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
          icon: const Icon(LottiIcons.chevronRight),
          tooltip: material.nextPageTooltip,
          onPressed: onNext,
        ),
        // Desktop only, and only off-today. A phone header has no width to
        // spare beside the date — the button squeezed the date into an
        // ellipsis — and the picker this label opens carries its own Today
        // quick action, so nothing is lost by leaving it out there.
        if (showToday) ...[
          SizedBox(width: tokens.spacing.step2),
          DesignSystemButton(
            key: const Key('daily_os_date_strip_today'),
            label: messages.dailyOsTodayButton,
            leadingIcon: LottiIcons.today,
            variant: DesignSystemButtonVariant.outlined,
            size: DesignSystemButtonSize.dense,
            // The row is already 48dp tall because of the chevrons, so the
            // padded target costs no height and keeps Today no harder to hit
            // than either arrow.
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: onToday,
          ),
        ],
      ],
    );
  }
}

/// Width the jump-to-today control occupies, derived from the design
/// system's `dense` button spec (caption label, caption-height icon, a
/// `step2` inset on each side and a `step2` icon gap) plus the `step2`
/// lead-in the strip puts before it.
///
/// Measured rather than assumed so the fit check follows the user's
/// font-size setting, and deliberately whole-token rather than pixel-exact:
/// erring high hides the button slightly early, which is the safe direction.
double _todayControlWidth(BuildContext context, DsTokens tokens) {
  final painter = TextPainter(
    text: TextSpan(
      text: context.messages.dailyOsTodayButton,
      style: tokens.typography.styles.others.caption,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final labelWidth = painter.width;
  painter.dispose();
  return labelWidth +
      tokens.typography.lineHeight.caption +
      tokens.spacing.step2 * 4;
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
