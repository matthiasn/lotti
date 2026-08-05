import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/health_import_controller.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';

/// Manual health-data import screen.
///
/// A date range, one row per data family (activity, sleep, heart rate, blood
/// pressure, body measurements, workouts), and an "import all" action. Each row
/// reports its own progress and outcome — a sample count, a permission refusal,
/// or an error — because the page's previous incarnation fired every import
/// without awaiting it and rendered nothing afterwards, which made a working
/// import and a failing one look identical.
class HealthImportPage extends StatelessWidget {
  const HealthImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsHealthImportTitle,
      subtitle: context.messages.settingsHealthImportSubtitle,
      showBackButton: true,
      child: const HealthImportBody(),
    );
  }
}

/// Chrome-free body of the health import page, so the surface can be pumped in
/// tests (and hosted elsewhere) without the sliver scaffold around it.
class HealthImportBody extends ConsumerWidget {
  const HealthImportBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(healthImportControllerProvider);
    final controller = ref.read(healthImportControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      // Shares the app's reading measure, so a wide desktop window does not
      // stretch a six-row list across 1200px of empty space. Owns the
      // horizontal gutter, so nothing inside adds one of its own.
      child: DetailContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDesktop) ...[
              DesignSystemInlineCallout(
                icon: Icons.desktop_access_disabled_outlined,
                text: messages.settingsHealthImportUnavailable,
              ),
              SizedBox(height: tokens.spacing.sectionGap),
            ],
            _SectionLabel(messages.settingsHealthImportRangeSectionTitle),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DateTimeField(
                    dateTime: state.dateFrom,
                    labelText: messages.settingsHealthImportFromDate,
                    setDateTime: controller.setDateFrom,
                    mode: CupertinoDatePickerMode.date,
                  ),
                  SizedBox(height: tokens.spacing.cardItemSpacing),
                  DateTimeField(
                    dateTime: state.dateTo,
                    labelText: messages.settingsHealthImportToDate,
                    setDateTime: controller.setDateTo,
                    mode: CupertinoDatePickerMode.date,
                  ),
                  SizedBox(height: tokens.spacing.cardItemSpacing),
                  _QuickRanges(
                    dateFrom: state.dateFrom,
                    dateTo: state.dateTo,
                    onSelected: controller.selectQuickRange,
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.sectionGap),
            _SectionLabel(messages.settingsHealthImportDataSectionTitle),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemGroupedList(
              padding: EdgeInsets.zero,
              children: [
                for (final (index, category)
                    in HealthImportCategory.values.indexed)
                  _CategoryRow(
                    category: category,
                    categoryState: state.stateFor(category),
                    // Null once the range moves on — the row falls back to
                    // describing what it *will* import.
                    result: state.resultFor(category),
                    // Every row is inert while any import runs — the controller
                    // refuses overlapping runs, so an enabled row would promise
                    // something the tap could not deliver.
                    enabled: !state.isAnyRunning,
                    // The last row owns the bottom-of-list slot, which has no
                    // divider beneath it.
                    showDivider: index < HealthImportCategory.values.length - 1,
                    onTap: () => unawaited(controller.runImport(category)),
                  ),
              ],
            ),
            // Only once a run has actually come back empty. Offering the
            // permission escape hatch unprompted would imply something is wrong
            // on a page that has not yet tried anything.
            if (state.needsAccessCheck) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              DesignSystemInlineCallout(
                icon: Icons.privacy_tip_outlined,
                text: messages.settingsHealthImportAccessHint,
              ),
              SizedBox(height: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.settingsHealthImportOpenSettings,
                leadingIcon: Icons.settings_outlined,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
                onPressed: () => unawaited(controller.openHealthSettings()),
              ),
            ],
            SizedBox(height: tokens.spacing.sectionGap),
            DesignSystemButton(
              label: messages.settingsHealthImportAll,
              leadingIcon: Icons.download_rounded,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              isLoading: state.isAnyRunning,
              onPressed: () => unawaited(controller.runAll()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase eyebrow above a band of content.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text.toUpperCase(),
      style: tokens.typography.styles.others.overline.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

/// The "last N days" shortcuts under the two date fields.
///
/// A pill is selected when the current range *is* that range, so tapping one
/// and then nudging a date visibly deselects it rather than leaving a lie on
/// screen.
class _QuickRanges extends StatelessWidget {
  const _QuickRanges({
    required this.dateFrom,
    required this.dateTo,
    required this.onSelected,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final ValueChanged<int> onSelected;

  bool _isSelected(int days) {
    final expectedFrom = HealthImportController.startOfDay(
      dateTo.subtract(Duration(days: days)),
    );
    return dateFrom == expectedFrom;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final days in healthImportQuickRangeDays)
          DsPill(
            variant: DsPillVariant.outline,
            color: tokens.colors.interactive.enabled,
            label: context.messages.settingsHealthImportQuickRange(days),
            selected: _isSelected(days),
            onTap: () => onSelected(days),
          ),
      ],
    );
  }
}

/// One data-family row: glyph, name, and a subtitle that switches from "what
/// this imports" to "what just happened" once a run has produced a result.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.categoryState,
    required this.result,
    required this.showDivider,
    required this.enabled,
    required this.onTap,
  });

  final HealthImportCategory category;
  final HealthImportCategoryState categoryState;
  final HealthImportResult? result;
  final bool showDivider;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final outcome = result;
    return DesignSystemListItem(
      title: healthImportCategoryTitle(messages, category),
      subtitle: categoryState.isRunning
          ? messages.settingsHealthImportStatusRunning
          : outcome == null
          ? healthImportCategoryDescription(messages, category)
          : healthImportResultLabel(messages, outcome),
      subtitleEmphasis: outcome == null || categoryState.isRunning
          ? null
          : healthImportResultTone(tokens, outcome),
      subtitleMaxLines: 2,
      leading: SettingsIcon(icon: healthImportCategoryIcon(category)),
      trailing: _CategoryTrailing(
        isRunning: categoryState.isRunning,
        result: result,
        tokens: tokens,
      ),
      showDivider: showDivider,
      dividerIndent: SettingsIcon.dividerIndent(tokens),
      onTap: enabled ? onTap : null,
    );
  }
}

/// Trailing affordance: a spinner while running, an outcome glyph once a run
/// has finished, and the "run me" glyph otherwise.
class _CategoryTrailing extends StatelessWidget {
  const _CategoryTrailing({
    required this.isRunning,
    required this.result,
    required this.tokens,
  });

  final bool isRunning;
  final HealthImportResult? result;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (isRunning) {
      return DesignSystemSpinner(
        size: IconSizes.l,
        strokeWidth: tokens.spacing.step1,
        semanticsLabel: context.messages.settingsHealthImportStatusRunning,
      );
    }

    final outcome = result;
    if (outcome == null) {
      return Icon(
        Icons.download_rounded,
        size: tokens.spacing.step6,
        color: tokens.colors.text.lowEmphasis,
      );
    }

    return Icon(
      healthImportResultIcon(outcome),
      size: tokens.spacing.step6,
      color: healthImportResultTone(tokens, outcome),
    );
  }
}

/// Outcome glyph for a finished run.
///
/// A padlock rather than an error cross for the two access outcomes: neither is
/// a malfunction, and both are fixed in the same place — the system's health
/// privacy settings — which the glyph should point at rather than alarm about.
IconData healthImportResultIcon(HealthImportResult result) =>
    switch (result.status) {
      HealthImportStatus.imported => Icons.check_circle_outline_rounded,
      HealthImportStatus.permissionDenied ||
      HealthImportStatus.noDataOrAccess => Icons.lock_outline_rounded,
      HealthImportStatus.unsupportedPlatform ||
      HealthImportStatus.noMatchingTypes ||
      HealthImportStatus.failed => Icons.error_outline_rounded,
    };

/// Row glyph per data family.
IconData healthImportCategoryIcon(HealthImportCategory category) =>
    switch (category) {
      HealthImportCategory.activity => Icons.directions_walk_rounded,
      HealthImportCategory.sleep => Icons.bedtime_outlined,
      HealthImportCategory.heartRate => Icons.favorite_outline_rounded,
      HealthImportCategory.bloodPressure => Icons.monitor_heart_outlined,
      HealthImportCategory.bodyMeasurement => Icons.straighten_rounded,
      HealthImportCategory.workout => Icons.fitness_center_rounded,
    };

/// Row title per data family.
String healthImportCategoryTitle(
  AppLocalizations messages,
  HealthImportCategory category,
) => switch (category) {
  HealthImportCategory.activity => messages.settingsHealthImportActivity,
  HealthImportCategory.sleep => messages.settingsHealthImportSleep,
  HealthImportCategory.heartRate => messages.settingsHealthImportHeartRate,
  HealthImportCategory.bloodPressure =>
    messages.settingsHealthImportBloodPressure,
  HealthImportCategory.bodyMeasurement =>
    messages.settingsHealthImportBodyMeasurement,
  HealthImportCategory.workout => messages.settingsHealthImportWorkout,
};

/// Resting subtitle: what this row will pull in.
String healthImportCategoryDescription(
  AppLocalizations messages,
  HealthImportCategory category,
) => switch (category) {
  HealthImportCategory.activity =>
    messages.settingsHealthImportActivityDescription,
  HealthImportCategory.sleep => messages.settingsHealthImportSleepDescription,
  HealthImportCategory.heartRate =>
    messages.settingsHealthImportHeartRateDescription,
  HealthImportCategory.bloodPressure =>
    messages.settingsHealthImportBloodPressureDescription,
  HealthImportCategory.bodyMeasurement =>
    messages.settingsHealthImportBodyMeasurementDescription,
  HealthImportCategory.workout =>
    messages.settingsHealthImportWorkoutDescription,
};

/// Post-run subtitle: what happened.
String healthImportResultLabel(
  AppLocalizations messages,
  HealthImportResult result,
) => switch (result.status) {
  HealthImportStatus.imported => messages.settingsHealthImportStatusImported(
    result.sampleCount,
  ),
  HealthImportStatus.permissionDenied =>
    messages.settingsHealthImportStatusPermissionDenied,
  HealthImportStatus.noDataOrAccess =>
    messages.settingsHealthImportStatusNoDataOrAccess,
  HealthImportStatus.unsupportedPlatform =>
    messages.settingsHealthImportUnavailable,
  HealthImportStatus.noMatchingTypes =>
    messages.settingsHealthImportStatusUnsupportedType,
  HealthImportStatus.failed => messages.settingsHealthImportStatusFailed,
};

/// Alert ramp tone for an outcome: success for a completed run, warning for a
/// refusal or an unavailable platform (nothing is broken, but nothing was
/// imported either), error for a genuine failure.
Color healthImportResultTone(DsTokens tokens, HealthImportResult result) =>
    switch (result.status) {
      HealthImportStatus.imported => tokens.colors.alert.success.defaultColor,
      HealthImportStatus.permissionDenied ||
      HealthImportStatus.noDataOrAccess ||
      HealthImportStatus.unsupportedPlatform =>
        tokens.colors.alert.warning.defaultColor,
      HealthImportStatus.noMatchingTypes ||
      HealthImportStatus.failed => tokens.colors.alert.error.defaultColor,
    };
