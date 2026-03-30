import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/category_block_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Full-screen page for manual time-block planning.
///
/// Users see all categories (favourites first), tap to expand and
/// add time blocks, then batch-save via "Save plan".
class SetTimeBlocksPage extends ConsumerStatefulWidget {
  const SetTimeBlocksPage({super.key});

  @override
  ConsumerState<SetTimeBlocksPage> createState() => _SetTimeBlocksPageState();
}

class _SetTimeBlocksPageState extends ConsumerState<SetTimeBlocksPage> {
  /// Pending blocks keyed by category ID, saved on "Save plan".
  final Map<String, List<PlannedBlock>> _pendingBlocks = {};
  String? _expandedCategoryId;
  bool _isSaving = false;
  DateTime? _initializedDate;
  bool _hadExistingBlocks = false;

  DateTime get _date => ref.watch(dailyOsSelectedDateProvider);

  void _initFromExistingPlan() {
    final date = _date;
    if (_initializedDate == date) return;

    ref.watch(unifiedDailyOsDataControllerProvider(date: date)).whenData((d) {
      if (_initializedDate == date) return;
      _initializedDate = date;
      _pendingBlocks.clear();
      final existing = d.dayPlan.data.plannedBlocks;
      _hadExistingBlocks = existing.isNotEmpty;
      for (final block in existing) {
        _pendingBlocks.putIfAbsent(block.categoryId, () => []).add(block);
      }
    });
  }

  bool get _hasChanges =>
      _initializedDate != null &&
      (_pendingBlocks.values.any((b) => b.isNotEmpty) || _hadExistingBlocks);

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final allBlocks = _pendingBlocks.values.expand((b) => b).toList();

      await ref
          .read(unifiedDailyOsDataControllerProvider(date: _date).notifier)
          .setPlannedBlocks(allBlocks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: DesignSystemToast(
              tone: DesignSystemToastTone.success,
              title: context.messages.dailyOsPlanCreated,
              description: context.messages.dailyOsPlanCreatedDescription,
              onDismiss: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } on Exception {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: DesignSystemToast(
              tone: DesignSystemToastTone.error,
              title: context.messages.dailyOsSaveError,
              description: context.messages.dailyOsSaveErrorDescription,
              onDismiss: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromExistingPlan();

    final tokens = context.designTokens;
    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final favorites = categories.where((c) => c.favorite ?? false).toList();
    final others = categories.where((c) => !(c.favorite ?? false)).toList();

    final dateFormat = DateFormat.yMMMd();
    final isToday = _date.dayAtMidnight == DateTime.now().dayAtMidnight;

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              tokens: tokens,
              dateLabel: isToday
                  ? '${context.messages.dailyOsTodayButton}  ${dateFormat.format(_date)}'
                  : dateFormat.format(_date),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: tokens.spacing.step6 * 3,
                ),
                children: [
                  if (favorites.isNotEmpty) ...[
                    _SectionHeader(
                      label: context.messages.dailyOsSetTimeBlocksFavourites,
                      tokens: tokens,
                    ),
                    ..._buildCategoryRows(favorites, isFavorite: true),
                  ],
                  if (others.isNotEmpty) ...[
                    _SectionHeader(
                      label: context.messages.dailyOsSetTimeBlocksOther,
                      tokens: tokens,
                    ),
                    ..._buildCategoryRows(others, isFavorite: false),
                  ],
                ],
              ),
            ),
            _SaveButton(
              tokens: tokens,
              enabled: _hasChanges && !_isSaving,
              onTap: _handleSave,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryRows(
    List<CategoryDefinition> categories, {
    required bool isFavorite,
  }) {
    return categories.map((category) {
      final blocks = _pendingBlocks[category.id] ?? [];
      return CategoryBlockRow(
        key: ValueKey(category.id),
        category: category,
        blocks: blocks,
        planDate: _date,
        isExpanded: _expandedCategoryId == category.id,
        isFavorite: isFavorite,
        onToggleExpand: () => setState(() {
          _expandedCategoryId = _expandedCategoryId == category.id
              ? null
              : category.id;
        }),
        onBlocksChanged: (newBlocks) => setState(() {
          if (newBlocks.isEmpty) {
            _pendingBlocks.remove(category.id);
          } else {
            _pendingBlocks[category.id] = newBlocks;
          }
        }),
      );
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens, required this.dateLabel});

  final DsTokens tokens;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            color: tokens.colors.text.highEmphasis,
          ),
          Expanded(
            child: Text(
              context.messages.dailyOsSetTimeBlocks,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          Text(
            dateLabel,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.tokens});

  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step3,
      ),
      child: Row(
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
              height: 1,
              thickness: 1,
              color: tokens.colors.decorative.level01,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.tokens,
    required this.enabled,
    required this.onTap,
  });

  final DsTokens tokens;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: SizedBox(
        width: double.infinity,
        height: tokens.spacing.step9,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.colors.interactive.enabled,
            disabledBackgroundColor: tokens.colors.interactive.enabled
                .withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
          child: Text(
            context.messages.dailyOsSavePlan,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
