import 'package:flutter/widgets.dart';

/// Single accessibility text-scale policy for the Daily OS surfaces.
///
/// All squeeze adaptations key off these named thresholds so the voice
/// steps adapt in lockstep — two surfaces hiding their headers at
/// different scales would make the shared headline baseline jump between
/// steps.
double dailyOsTextScaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) / 100;

/// At/above this scale the per-step header is removed from layout
/// entirely (never height-clipped) and squeeze fades engage.
const double kDailyOsHideHeaderScale = 1.8;

/// At/above this scale multi-pill action bars stack vertically — paired
/// intrinsic pills no longer fit a phone or a narrow side sheet.
const double kDailyOsStackBarPillsScale = 1.5;

/// At/above this scale secondary coaching copy (e.g. the day footer
/// hint) is dropped so the first actionable row stays above the fold.
const double kDailyOsHideCoachingScale = 1.4;
