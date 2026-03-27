import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemBadgeWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Badges',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _BadgeOverviewPage(),
      ),
    ],
  );
}

class _BadgeOverviewPage extends StatelessWidget {
  const _BadgeOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _BadgeSection(
            title: 'Type Scale',
            child: _BadgeTypeScale(),
          ),
          SizedBox(height: 32),
          _BadgeSection(
            title: 'Status Matrix',
            child: _BadgeStatusMatrix(),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection({
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

class _BadgeTypeScale extends StatelessWidget {
  const _BadgeTypeScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 32,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DesignSystemBadge.dot(),
        DesignSystemBadge.number(value: '3'),
        DesignSystemBadge.number(value: '10'),
        DesignSystemBadge.number(value: '99+'),
        DesignSystemBadge.number(value: '999+'),
        DesignSystemBadge.filled(label: 'Primary'),
        DesignSystemBadge.icon(icon: Icons.check_rounded),
        DesignSystemBadge.outlined(label: 'Outlined'),
      ],
    );
  }
}

class _BadgeStatusMatrix extends StatelessWidget {
  const _BadgeStatusMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BadgeMatrixRow(
          label: 'Dot',
          children: [
            for (final tone in DesignSystemBadgeTone.values)
              DesignSystemBadge.dot(tone: tone),
          ],
        ),
        _BadgeMatrixRow(
          label: 'Number',
          children: [
            for (final tone in DesignSystemBadgeTone.values)
              DesignSystemBadge.number(tone: tone, value: '10'),
          ],
        ),
        _BadgeMatrixRow(
          label: 'Filled',
          children: [
            for (final tone in DesignSystemBadgeTone.values)
              DesignSystemBadge.filled(
                tone: tone,
                label: _labelForTone(tone),
              ),
          ],
        ),
        _BadgeMatrixRow(
          label: 'Outlined',
          children: [
            for (final tone in DesignSystemBadgeTone.values)
              DesignSystemBadge.outlined(
                tone: tone,
                label: 'Outlined',
              ),
          ],
        ),
        _BadgeMatrixRow(
          label: 'Icon',
          children: [
            for (final tone in DesignSystemBadgeTone.values)
              DesignSystemBadge.icon(
                tone: tone,
                icon: _iconForTone(tone),
              ),
          ],
        ),
      ],
    );
  }
}

class _BadgeMatrixRow extends StatelessWidget {
  const _BadgeMatrixRow({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}

String _labelForTone(DesignSystemBadgeTone tone) {
  return switch (tone) {
    DesignSystemBadgeTone.primary => 'Primary',
    DesignSystemBadgeTone.secondary => 'Secondary',
    DesignSystemBadgeTone.danger => 'Danger',
    DesignSystemBadgeTone.warning => 'Warning',
    DesignSystemBadgeTone.success => 'Success',
  };
}

IconData _iconForTone(DesignSystemBadgeTone tone) {
  return switch (tone) {
    DesignSystemBadgeTone.primary => Icons.check_rounded,
    DesignSystemBadgeTone.secondary => Icons.check_rounded,
    DesignSystemBadgeTone.danger => Icons.error_rounded,
    DesignSystemBadgeTone.warning => Icons.warning_amber_rounded,
    DesignSystemBadgeTone.success => Icons.check_rounded,
  };
}
