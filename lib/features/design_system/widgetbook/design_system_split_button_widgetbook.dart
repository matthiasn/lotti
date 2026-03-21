import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/split_buttons/design_system_split_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
        ),
        _SplitButtonPreview(
          size: DesignSystemSplitButtonSize.small2,
        ),
        _SplitButtonPreview(
          size: DesignSystemSplitButtonSize.defaultSize,
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
        ),
        _SplitButtonMatrixRow(
          label: 'Small2 + Open',
          size: DesignSystemSplitButtonSize.small2,
          initiallyOpen: true,
        ),
        _SplitButtonMatrixRow(
          label: 'Default + Default',
          size: DesignSystemSplitButtonSize.defaultSize,
        ),
        _SplitButtonMatrixRow(
          label: 'Default + Open',
          size: DesignSystemSplitButtonSize.defaultSize,
          initiallyOpen: true,
        ),
      ],
    );
  }
}

class _SplitButtonMatrixRow extends StatelessWidget {
  const _SplitButtonMatrixRow({
    required this.label,
    required this.size,
    this.initiallyOpen = false,
  });

  final String label;
  final DesignSystemSplitButtonSize size;
  final bool initiallyOpen;

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
            initiallyOpen: initiallyOpen,
          ),
        ],
      ),
    );
  }
}

class _SplitButtonPreview extends StatefulWidget {
  const _SplitButtonPreview({
    required this.size,
    this.initiallyOpen = false,
  });

  final DesignSystemSplitButtonSize size;
  final bool initiallyOpen;

  @override
  State<_SplitButtonPreview> createState() => _SplitButtonPreviewState();
}

class _SplitButtonPreviewState extends State<_SplitButtonPreview> {
  late bool _isDropdownOpen = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignSystemSplitButton(
            label: _labelForSize(widget.size),
            size: widget.size,
            isDropdownOpen: _isDropdownOpen,
            onPressed: () {},
            onDropdownPressed: () {
              setState(() => _isDropdownOpen = !_isDropdownOpen);
            },
          ),
          if (_isDropdownOpen) ...[
            SizedBox(height: tokens.spacing.step2),
            _SplitButtonMenu(tokens: tokens),
          ],
        ],
      ),
    );
  }
}

class _SplitButtonMenu extends StatelessWidget {
  const _SplitButtonMenu({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.decorative.level01,
            blurRadius: tokens.spacing.step4,
            offset: Offset(0, tokens.spacing.step1),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in const ['Option A', 'Option B', 'Option C'])
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    tokens.radii.sectionCards,
                  ),
                  onTap: () {},
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step5,
                      vertical: tokens.spacing.step4,
                    ),
                    child: Text(
                      label,
                      style: tokens.typography.styles.body.bodyLarge.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
