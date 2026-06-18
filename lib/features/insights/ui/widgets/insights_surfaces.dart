import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';

/// Conventional elevation for the Time Analysis dashboard in **both** themes:
/// a darker page canvas with the cards a step lighter sitting on it.
///
/// Thin, named aliases over the shared [dsPageSurface] / [dsCardSurface]
/// design-system helpers so the dashboard's call sites keep their intent-
/// revealing names while the elevation logic stays single-sourced (Habits and
/// any future calm surface read the same helpers). See [dsPageSurface] for why
/// the page/card levels swap by brightness.
Color insightsPageSurface(BuildContext context) => dsPageSurface(context);

/// The card/elevated surface — always a step lighter than [insightsPageSurface]
/// in the active theme. See [dsPageSurface] for why this swaps by brightness.
Color insightsCardSurface(BuildContext context) => dsCardSurface(context);
