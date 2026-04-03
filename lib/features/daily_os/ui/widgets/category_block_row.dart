import 'package:flutter/material.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_block_editor.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:uuid/uuid.dart';

/// Expandable row for a category in the "Set time blocks" page.
///
/// Collapsed: shows category icon, name, and time block summary chips.
/// Expanded: shows block list with inline editors and "Add new" button.
class CategoryBlockRow extends StatelessWidget {
  const CategoryBlockRow({
    required this.category,
    required this.blocks,
    required this.planDate,
    required this.isExpanded,
    required this.isFavorite,
    required this.onToggleExpand,
    required this.onBlocksChanged,
    super.key,
  });

  final CategoryDefinition category;
  final List<PlannedBlock> blocks;
  final DateTime planDate;
  final bool isExpanded;
  final bool isFavorite;
  final VoidCallback onToggleExpand;
  final ValueChanged<List<PlannedBlock>> onBlocksChanged;

  static const _iconSize = 40.0;

  void _addBlock() {
    final midnight = planDate.dayAtMidnight;
    // Default: next available hour block, or 9-10am if no blocks yet
    final lastEnd = blocks.isNotEmpty
        ? TimeOfDay(
            hour: blocks.last.endTime.hour,
            minute: blocks.last.endTime.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final startHour = lastEnd.hour.clamp(0, 22);
    final endHour = (startHour + 1).clamp(1, 23);

    final newBlock = PlannedBlock(
      id: const Uuid().v1(),
      categoryId: category.id,
      startTime: midnight.add(
        Duration(hours: startHour, minutes: lastEnd.minute),
      ),
      endTime: midnight.add(
        Duration(hours: endHour, minutes: lastEnd.minute),
      ),
    );
    onBlocksChanged([...blocks, newBlock]);
  }

  void _updateBlock(int index, PlannedBlock updated) {
    final newList = [...blocks];
    newList[index] = updated;
    onBlocksChanged(newList);
  }

  void _removeBlock(int index) {
    final newList = [...blocks]..removeAt(index);
    onBlocksChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: _CollapsedHeader(
              category: category,
              blocks: blocks,
              isFavorite: isFavorite,
              isExpanded: isExpanded,
              tokens: tokens,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? _ExpandedContent(
                    blocks: blocks,
                    planDate: planDate,
                    tokens: tokens,
                    onUpdateBlock: _updateBlock,
                    onRemoveBlock: _removeBlock,
                    onAddBlock: _addBlock,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  const _CollapsedHeader({
    required this.category,
    required this.blocks,
    required this.isFavorite,
    required this.isExpanded,
    required this.tokens,
  });

  final CategoryDefinition category;
  final List<PlannedBlock> blocks;
  final bool isFavorite;
  final bool isExpanded;
  final DsTokens tokens;

  String _formatBlockTime(BuildContext context, PlannedBlock block) {
    final localizations = MaterialLocalizations.of(context);
    final start = TimeOfDay(
      hour: block.startTime.hour,
      minute: block.startTime.minute,
    );
    final end = TimeOfDay(
      hour: block.endTime.hour,
      minute: block.endTime.minute,
    );
    final s = localizations.formatTimeOfDay(start);
    final e = localizations.formatTimeOfDay(end);
    return '$s–$e';
  }

  @override
  Widget build(BuildContext context) {
    final hasBlocks = blocks.isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Row(
        children: [
          CategoryIconCompactFromDefinition(
            category,
            size: CategoryBlockRow._iconSize,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                if (hasBlocks)
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    children: blocks.map((block) {
                      return _TimeChip(
                        label: _formatBlockTime(context, block),
                        tokens: tokens,
                      );
                    }).toList(),
                  )
                else
                  Text(
                    context.messages.dailyOsSetTimeBlocksTapHint,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
              ],
            ),
          ),
          if (isFavorite)
            Padding(
              padding: EdgeInsets.only(left: tokens.spacing.step2),
              child: Icon(
                Icons.star,
                color: tokens.colors.alert.warning.defaultColor,
                size: 20,
              ),
            ),
          if (hasBlocks)
            Padding(
              padding: EdgeInsets.only(left: tokens.spacing.step2),
              child: Icon(
                Icons.check_circle,
                color: tokens.colors.interactive.enabled,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.tokens});

  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.interactive.enabled.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: tokens.colors.interactive.enabled,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.interactive.enabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.blocks,
    required this.planDate,
    required this.tokens,
    required this.onUpdateBlock,
    required this.onRemoveBlock,
    required this.onAddBlock,
  });

  final List<PlannedBlock> blocks;
  final DateTime planDate;
  final DsTokens tokens;
  final void Function(int index, PlannedBlock block) onUpdateBlock;
  final void Function(int index) onRemoveBlock;
  final VoidCallback onAddBlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: tokens.colors.decorative.level01,
        ),
        SizedBox(height: tokens.spacing.step3),
        for (var i = 0; i < blocks.length; i++) ...[
          TimeBlockEditor(
            key: ValueKey(blocks[i].id),
            block: blocks[i],
            planDate: planDate,
            onChanged: (updated) => onUpdateBlock(i, updated),
            onDelete: () => onRemoveBlock(i),
          ),
          if (i < blocks.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              indent: tokens.spacing.step4,
              color: tokens.colors.decorative.level01,
            ),
        ],
        SizedBox(height: tokens.spacing.step3),
        _AddBlockButton(tokens: tokens, onTap: onAddBlock),
        SizedBox(height: tokens.spacing.step3),
      ],
    );
  }
}

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({required this.tokens, required this.onTap});

  final DsTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.dailyOsSetTimeBlocksAddNew,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
