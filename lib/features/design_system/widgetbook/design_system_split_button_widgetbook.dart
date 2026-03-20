import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/split_buttons/design_system_split_button.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemSplitButtonWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Split Buttons',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _SplitButtonOverviewPage(),
      ),
    ],
  );
}

class _SplitButtonOverviewPage extends StatelessWidget {
  const _SplitButtonOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _SplitButtonSection(
            title: 'Size Scale',
            child: _SplitButtonSizeScale(),
          ),
          SizedBox(height: 32),
          _SplitButtonSection(
            title: 'Variant Matrix',
            child: _SplitButtonVariantMatrix(),
          ),
        ],
      ),
    );
  }
}

class _SplitButtonSection extends StatelessWidget {
  const _SplitButtonSection({
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

class _SplitButtonSizeScale extends StatelessWidget {
  const _SplitButtonSizeScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _SplitButtonPreview(
          size: DesignSystemSplitButtonSize.small,
          isDropdownOpen: false,
        ),
        _SplitButtonPreview(
          size: DesignSystemSplitButtonSize.small2,
          isDropdownOpen: false,
        ),
        _SplitButtonPreview(
          size: DesignSystemSplitButtonSize.defaultSize,
          isDropdownOpen: false,
        ),
      ],
    );
  }
}

class _SplitButtonVariantMatrix extends StatelessWidget {
  const _SplitButtonVariantMatrix();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SplitButtonMatrixRow(
          label: 'Small + Default',
          size: DesignSystemSplitButtonSize.small,
          isDropdownOpen: false,
        ),
        _SplitButtonMatrixRow(
          label: 'Small2 + Open',
          size: DesignSystemSplitButtonSize.small2,
          isDropdownOpen: true,
        ),
        _SplitButtonMatrixRow(
          label: 'Default + Default',
          size: DesignSystemSplitButtonSize.defaultSize,
          isDropdownOpen: false,
        ),
        _SplitButtonMatrixRow(
          label: 'Default + Open',
          size: DesignSystemSplitButtonSize.defaultSize,
          isDropdownOpen: true,
        ),
      ],
    );
  }
}

class _SplitButtonMatrixRow extends StatelessWidget {
  const _SplitButtonMatrixRow({
    required this.label,
    required this.size,
    required this.isDropdownOpen,
  });

  final String label;
  final DesignSystemSplitButtonSize size;
  final bool isDropdownOpen;

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
          _SplitButtonPreview(
            size: size,
            isDropdownOpen: isDropdownOpen,
          ),
        ],
      ),
    );
  }
}

class _SplitButtonPreview extends StatelessWidget {
  const _SplitButtonPreview({
    required this.size,
    required this.isDropdownOpen,
  });

  final DesignSystemSplitButtonSize size;
  final bool isDropdownOpen;

  @override
  Widget build(BuildContext context) {
    return DesignSystemSplitButton(
      label: _labelForSize(size),
      size: size,
      isDropdownOpen: isDropdownOpen,
      onPressed: _noop,
      onDropdownPressed: _noop,
    );
  }
}

String _labelForSize(DesignSystemSplitButtonSize size) {
  return switch (size) {
    DesignSystemSplitButtonSize.small => 'Small',
    DesignSystemSplitButtonSize.small2 => 'Small2',
    DesignSystemSplitButtonSize.defaultSize => 'Default',
  };
}

void _noop() {}
