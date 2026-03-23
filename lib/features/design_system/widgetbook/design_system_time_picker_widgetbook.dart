import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTimePickerWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Time picker',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TimePickerOverviewPage(),
      ),
    ],
  );
}

class _TimePickerOverviewPage extends StatelessWidget {
  const _TimePickerOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TimePickerSection(
            title: context.messages.designSystemTimePickerFormatsTitle,
            child: const _TimePickerFormats(),
          ),
        ],
      ),
    );
  }
}

class _TimePickerSection extends StatelessWidget {
  const _TimePickerSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _TimePickerFormats extends StatelessWidget {
  const _TimePickerFormats();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    return Wrap(
      spacing: 48,
      runSpacing: 24,
      children: [
        for (final format in DesignSystemTimeFormat.values)
          SizedBox(
            width: 375,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelForFormat(context, format),
                  style: descriptionStyle,
                ),
                const SizedBox(height: 8),
                DesignSystemTimePicker(
                  format: format,
                  initialTime: const TimeOfDay(hour: 9, minute: 41),
                  onTimeChanged: (_) {},
                  semanticsLabel: _labelForFormat(context, format),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _labelForFormat(
    BuildContext context,
    DesignSystemTimeFormat format,
  ) {
    final messages = context.messages;
    return switch (format) {
      DesignSystemTimeFormat.twelveHour =>
        messages.designSystemTimePickerTwelveHourLabel,
      DesignSystemTimeFormat.twentyFourHour =>
        messages.designSystemTimePickerTwentyFourHourLabel,
    };
  }
}
