import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/widgetbook/set_time_blocks_mock_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildSetTimeBlocksWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Set Time Blocks',
    children: [
      WidgetbookComponent(
        name: 'Set time blocks page',
        useCases: [
          WidgetbookUseCase(
            name: 'Interactive',
            builder: (context) => const SetTimeBlocksShowcasePage(),
          ),
        ],
      ),
    ],
  );
}

/// Standalone "Set time blocks" page showcase using mock data.
class SetTimeBlocksShowcasePage extends StatefulWidget {
  const SetTimeBlocksShowcasePage({super.key});

  @override
  State<SetTimeBlocksShowcasePage> createState() =>
      _SetTimeBlocksShowcasePageState();
}

class _SetTimeBlocksShowcasePageState extends State<SetTimeBlocksShowcasePage> {
  late List<MockCategory> _favourites;
  late List<MockCategory> _others;

  @override
  void initState() {
    super.initState();
    _favourites = List.of(SetTimeBlocksMockData.favourites);
    _others = List.of(SetTimeBlocksMockData.otherCategories);
  }

  void _toggleFavourite(MockCategory cat) {
    setState(() {
      if (cat.isFavourite) {
        _favourites.removeWhere((c) => c.id == cat.id);
        _others.insert(0, cat.copyWith(isFavourite: false));
      } else {
        _others.removeWhere((c) => c.id == cat.id);
        _favourites.add(cat.copyWith(isFavourite: true));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              _PageHeader(tokens: tokens),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    left: tokens.spacing.step5,
                    right: tokens.spacing.step5,
                    top: tokens.spacing.step5,
                  ),
                  children: [
                    _SectionDivider(
                      label: 'Favourites',
                      tokens: tokens,
                    ),
                    for (final cat in _favourites) ...[
                      SizedBox(height: tokens.spacing.step5),
                      _CategoryRow(
                        category: cat,
                        tokens: tokens,
                        onStarTap: () => _toggleFavourite(cat),
                      ),
                    ],
                    SizedBox(height: tokens.spacing.step5),
                    _SectionDivider(
                      label: 'Other categories',
                      tokens: tokens,
                    ),
                    for (final cat in _others) ...[
                      SizedBox(height: tokens.spacing.step5),
                      _CategoryRow(
                        category: cat,
                        tokens: tokens,
                        onStarTap: () => _toggleFavourite(cat),
                      ),
                    ],
                    SizedBox(height: tokens.spacing.step5),
                    _SavePlanButton(tokens: tokens),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step6,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_back_ios,
                size: 17,
                color: tokens.colors.text.highEmphasis,
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                'Back',
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Set time blocks',
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Today',
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Text(
                    'Oct 17, 2026',
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.label,
    required this.tokens,
  });
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Divider(
            color: tokens.colors.decorative.level01,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.tokens,
    required this.onStarTap,
  });
  final MockCategory category;
  final DsTokens tokens;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    final hasBlocks = category.hasBlocks;
    final accent = tokens.colors.interactive.enabled;

    final borderColor = hasBlocks ? accent : tokens.colors.decorative.level01;
    final bgColor = hasBlocks
        ? accent.withValues(alpha: 0.16)
        : Colors.transparent;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: EdgeInsets.all(tokens.spacing.step3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _CategoryIcon(category: category, tokens: tokens),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.step1),
                if (hasBlocks)
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    children: [
                      for (final block in category.timeBlocks)
                        _TimeChip(block: block, tokens: tokens),
                    ],
                  )
                else
                  Text(
                    'Tap to add time block',
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
              ],
            ),
          ),
          if (category.isFavourite)
            GestureDetector(
              onTap: onStarTap,
              child: Icon(
                Icons.star,
                size: 20,
                color: tokens.colors.alert.warning.defaultColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.tokens});
  final MockCategory category;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(
          color: category.color.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(
        category.icon,
        size: 20,
        color: category.iconColor ?? category.color.withValues(alpha: 0.88),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.block, required this.tokens});
  final MockTimeBlock block;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final accent = tokens.colors.interactive.enabled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 12, color: accent),
        SizedBox(width: tokens.spacing.step1),
        Text(
          block.label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _SavePlanButton extends StatelessWidget {
  const _SavePlanButton({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: SizedBox(
          width: double.infinity,
          height: tokens.spacing.step9,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: tokens.colors.interactive.enabled,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.m),
              ),
            ),
            child: Text(
              'Save plan',
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
