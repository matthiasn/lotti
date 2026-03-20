import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

const _chipAvatarSampleAsset = 'assets/design_system/chip_avatar_sample.png';

WidgetbookComponent buildDesignSystemChipWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Chips',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ChipOverviewPage(),
      ),
    ],
  );
}

class _ChipOverviewPage extends StatelessWidget {
  const _ChipOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _ChipSection(
            title: 'Combination Scale',
            child: _ChipCombinationScale(),
          ),
          SizedBox(height: 32),
          _ChipSection(
            title: 'State Matrix',
            child: _ChipStateMatrix(),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
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

class _ChipCombinationScale extends StatelessWidget {
  const _ChipCombinationScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
          ),
        ),
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
            showRemove: true,
          ),
        ),
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
            leading: _ChipLeadingKind.icon,
          ),
        ),
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
            leading: _ChipLeadingKind.icon,
            showRemove: true,
          ),
        ),
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
            leading: _ChipLeadingKind.avatar,
            showRemove: true,
          ),
        ),
        _ChipPreviewTile(
          config: _ChipPreviewConfig(
            label: 'Chip label',
            leading: _ChipLeadingKind.avatar,
          ),
        ),
      ],
    );
  }
}

class _ChipStateMatrix extends StatelessWidget {
  const _ChipStateMatrix();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipStateRow(
          label: 'Enabled',
          config: _ChipRowConfig(),
        ),
        _ChipStateRow(
          label: 'Hover',
          config: _ChipRowConfig(
            state: DesignSystemChipVisualState.hover,
          ),
        ),
        _ChipStateRow(
          label: 'Pressed',
          config: _ChipRowConfig(
            state: DesignSystemChipVisualState.pressed,
          ),
        ),
        _ChipStateRow(
          label: 'Activated',
          config: _ChipRowConfig(
            state: DesignSystemChipVisualState.activated,
          ),
        ),
        _ChipStateRow(
          label: 'Disabled',
          config: _ChipRowConfig(enabled: false),
        ),
      ],
    );
  }
}

class _ChipStateRow extends StatelessWidget {
  const _ChipStateRow({
    required this.label,
    required this.config,
  });

  final String label;
  final _ChipRowConfig config;

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
            spacing: 16,
            runSpacing: 16,
            children: [
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  showRemove: true,
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  leading: _ChipLeadingKind.icon,
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  leading: _ChipLeadingKind.icon,
                  showRemove: true,
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  leading: _ChipLeadingKind.avatar,
                  showRemove: true,
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
              _ChipPreviewTile(
                config: _ChipPreviewConfig(
                  label: 'Chip label',
                  leading: _ChipLeadingKind.avatar,
                  state: config.state,
                  enabled: config.enabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChipLeadingKind {
  none,
  icon,
  avatar,
}

class _ChipRowConfig {
  const _ChipRowConfig({
    this.state,
    this.enabled = true,
  });

  final DesignSystemChipVisualState? state;
  final bool enabled;
}

class _ChipPreviewConfig {
  const _ChipPreviewConfig({
    required this.label,
    this.leading = _ChipLeadingKind.none,
    this.showRemove = false,
    this.enabled = true,
    this.state,
  });

  final String label;
  final _ChipLeadingKind leading;
  final bool showRemove;
  final bool enabled;
  final DesignSystemChipVisualState? state;
}

class _ChipPreviewTile extends StatelessWidget {
  const _ChipPreviewTile({
    required this.config,
  });

  final _ChipPreviewConfig config;

  @override
  Widget build(BuildContext context) {
    return DesignSystemChip(
      label: config.label,
      leadingIcon: switch (config.leading) {
        _ChipLeadingKind.icon => Icons.location_on_rounded,
        _ChipLeadingKind.none || _ChipLeadingKind.avatar => null,
      },
      avatar: switch (config.leading) {
        _ChipLeadingKind.avatar => const _ChipAvatarSample(),
        _ChipLeadingKind.none || _ChipLeadingKind.icon => null,
      },
      showRemove: config.showRemove,
      forcedState: config.enabled ? config.state : null,
      onPressed: config.enabled ? _noop : null,
    );
  }
}

class _ChipAvatarSample extends StatelessWidget {
  const _ChipAvatarSample();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.colors.decorative.level02,
          width: tokens.spacing.step1 / 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          _chipAvatarSampleAsset,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

void _noop() {}
