import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The heading that names a block of metric tiles — "Top KPIs", each grouped
/// section, "Sent messages", and the diagnostics disclosure.
///
/// One function rather than the expression repeated per call site: the four
/// headings sit on the same page and must read as one level, so a retune has
/// to move all of them or none. `metrics_section_test.dart` asserts they
/// agree, and a test that keeps copies in sync is the signal to stop copying.
///
/// Deliberately does **not** set a weight: `subtitle2` already carries
/// `semiBold`, so an override here would be a no-op that reads as if it were
/// load-bearing.
TextStyle metricsGroupHeading(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
