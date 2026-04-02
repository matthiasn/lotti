import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/widgetbook/set_time_blocks_mock_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// Accent color matching Figma: rgb(94, 212, 183).
const _accent = Color(0xFF5ED4B7);

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

/// Standalone "Set time blocks" page showcase.
///
/// Renders the full page with category rows, time chips, favourites/other
/// sections, and a save button. Uses mock data, no real controllers.
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
        _others.insert(
          0,
          MockCategory(
            id: cat.id,
            name: cat.name,
            color: cat.color,
            icon: cat.icon,
            timeBlocks: cat.timeBlocks,
          ),
        );
      } else {
        _others.removeWhere((c) => c.id == cat.id);
        _favourites.add(
          MockCategory(
            id: cat.id,
            name: cat.name,
            color: cat.color,
            icon: cat.icon,
            isFavourite: true,
            timeBlocks: cat.timeBlocks,
          ),
        );
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

// ---------------------------------------------------------------------------
// Page Header
// ---------------------------------------------------------------------------

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
          // Back row — Figma uses arrow_back_ios (thin chevron) + 4px gap
          Row(
            children: [
              Icon(
                Icons.arrow_back_ios,
                size: 17,
                color: Colors.white.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 4),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Set time blocks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Oct 17, 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.64),
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

// ---------------------------------------------------------------------------
// Section Divider (label left-aligned with line extending right)
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.label,
    required this.tokens,
  });
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.white.withValues(alpha: 0.24);

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.25,
            height: 16 / 12,
            color: Colors.white.withValues(alpha: 0.64),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Divider(color: lineColor, height: 1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category Row
// ---------------------------------------------------------------------------

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

    // Figma: rows with blocks get accent green border + green-tinted bg
    // Rows without blocks get subtle white border, no bg
    final borderColor = hasBlocks
        ? _accent
        : Colors.white.withValues(alpha: 0.12);
    final bgColor = hasBlocks
        ? _accent.withValues(alpha: 0.16)
        : Colors.transparent;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Category icon
          _CategoryIcon(category: category),
          SizedBox(width: tokens.spacing.step5),
          // Name + time chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasBlocks)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        for (
                          var i = 0;
                          i < category.timeBlocks.length;
                          i++
                        ) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _TimeChip(block: category.timeBlocks[i]),
                        ],
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tap to add time block',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Star icon — only shown for favourites
          if (category.isFavourite)
            GestureDetector(
              onTap: onStarTap,
              child: const Icon(
                Icons.star,
                size: 20,
                color: Color(0xFFFBA337),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Icon
// ---------------------------------------------------------------------------

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});
  final MockCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
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

// ---------------------------------------------------------------------------
// Time Chip (clock icon + time range label)
// ---------------------------------------------------------------------------

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.block});
  final MockTimeBlock block;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.64);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          block.label,
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save Plan Button
// ---------------------------------------------------------------------------

class _SavePlanButton extends StatelessWidget {
  const _SavePlanButton({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          child: const Text('Save plan'),
        ),
      ),
    );
  }
}
