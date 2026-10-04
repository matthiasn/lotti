part of 'create_goal_agent_page.dart';

class _MeasurableTargetInput extends StatefulWidget {
  const _MeasurableTargetInput({
    required this.measurableId,
    required this.value,
    required this.unitName,
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String measurableId;
  final num? value;
  final String unitName;
  final String? errorText;

  /// Scroll anchor for validation: the page scrolls this input into view
  /// when its target fails the continue check.
  final Key anchorKey;
  final ValueChanged<num?> onChanged;

  @override
  State<_MeasurableTargetInput> createState() => _MeasurableTargetInputState();
}

class _MeasurableTargetInputState extends State<_MeasurableTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widget.anchorKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kInlineTargetInputWidth),
        child: DesignSystemTextInput(
          key: ValueKey('goal-form-measurable-target-${widget.measurableId}'),
          controller: _controller,
          label: widget.unitName,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: widget.errorText,
          onChanged: (raw) {
            final value = num.tryParse(raw.replaceAll(',', '.'));
            widget.onChanged(value);
          },
        ),
      ),
    );
  }
}

class _HealthTargetInput extends StatefulWidget {
  const _HealthTargetInput({
    required this.dataType,
    required this.value,
    required this.unit,
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
    this.label,
  });

  final String dataType;
  final num? value;
  final String unit;

  /// Overrides the generic "Target (unit)" label — the paired blood-pressure
  /// inputs need to say which half of the reading they are.
  final String? label;
  final String? errorText;
  final Key anchorKey;
  final ValueChanged<num?> onChanged;

  @override
  State<_HealthTargetInput> createState() => _HealthTargetInputState();
}

class _HealthTargetInputState extends State<_HealthTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.anchorKey,
    child: DesignSystemTextInput(
      key: ValueKey('goal-form-health-target-${widget.dataType}'),
      controller: _controller,
      label: widget.label ?? context.messages.goalFormHealthTarget(widget.unit),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      errorText: widget.errorText,
      onChanged: (raw) => widget.onChanged(
        num.tryParse(raw.trim().replaceAll(',', '.')),
      ),
    ),
  );
}

class _CategoryTimeTargetCard extends StatelessWidget {
  const _CategoryTimeTargetCard({
    required this.categoryId,
    required this.categoryName,
    required this.value,
    required this.direction,
    required this.errorText,
    required this.anchorKey,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onRemove,
    super.key,
  });

  final String categoryId;
  final String categoryName;
  final num? value;
  final GoalDirection direction;
  final String? errorText;
  final Key anchorKey;
  final ValueChanged<num?> onTargetChanged;
  final ValueChanged<GoalDirection> onDirectionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.schedule,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    Text(
                      context.messages.goalFormCategoryTimeSource,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              DesignSystemIconAction(
                icon: LottiIcons.close,
                tooltip: context.messages.aiCardProposalKindRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DsSegmentedToggle<GoalDirection>(
            key: ValueKey('goal-form-category-time-direction-$categoryId'),
            segments: [
              DsSegment(
                GoalDirection.atMost,
                context.messages.goalFormDirectionAtMost,
              ),
              DsSegment(
                GoalDirection.atLeast,
                context.messages.goalFormDirectionAtLeast,
              ),
            ],
            selected: direction,
            onChanged: onDirectionChanged,
            expand: true,
          ),
          SizedBox(height: tokens.spacing.step3),
          _CategoryTimeTargetInput(
            categoryId: categoryId,
            value: value,
            errorText: errorText,
            anchorKey: anchorKey,
            onChanged: onTargetChanged,
          ),
        ],
      ),
    );
  }
}

class _CategoryTimeTargetInput extends StatefulWidget {
  const _CategoryTimeTargetInput({
    required this.categoryId,
    required this.value,
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String categoryId;
  final num? value;
  final String? errorText;
  final Key anchorKey;
  final ValueChanged<num?> onChanged;

  @override
  State<_CategoryTimeTargetInput> createState() =>
      _CategoryTimeTargetInputState();
}

class _CategoryTimeTargetInputState extends State<_CategoryTimeTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.anchorKey,
    child: DesignSystemTextInput(
      key: ValueKey('goal-form-category-time-target-${widget.categoryId}'),
      controller: _controller,
      label: context.messages.goalFormCategoryTimeTarget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      errorText: widget.errorText,
      onChanged: (raw) => widget.onChanged(
        num.tryParse(raw.trim().replaceAll(',', '.')),
      ),
    ),
  );
}

class _LabelTimeTargetCard extends StatelessWidget {
  const _LabelTimeTargetCard({
    required this.labelId,
    required this.labelName,
    required this.categories,
    required this.categoryId,
    required this.value,
    required this.direction,
    required this.errorText,
    required this.anchorKey,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onCategoryChanged,
    required this.onRemove,
    super.key,
  });

  final String labelId;
  final String labelName;
  final List<CategoryDefinition> categories;
  final String? categoryId;
  final num? value;
  final GoalDirection direction;
  final String? errorText;
  final Key anchorKey;
  final ValueChanged<num?> onTargetChanged;
  final ValueChanged<GoalDirection> onDirectionChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final selectedCategoryName = categories
        .where((category) => category.id == categoryId)
        .map((category) => category.name)
        .firstOrNull;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.label,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelName,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    Text(
                      messages.goalFormLabelTimeSource,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              DesignSystemIconAction(
                icon: LottiIcons.close,
                tooltip: context.messages.aiCardProposalKindRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemDropdown(
            key: ValueKey('goal-form-label-time-category-$labelId'),
            label: messages.dailyOsNextBlockEditCategoryLabel,
            inputLabel:
                selectedCategoryName ??
                categoryId ??
                messages.dailyOsNextCategoryFilterAll,
            items: [
              DesignSystemDropdownItem(
                id: '',
                label: messages.dailyOsNextCategoryFilterAll,
                selected: categoryId == null,
              ),
              for (final category in categories)
                DesignSystemDropdownItem(
                  id: category.id,
                  label: category.name,
                  selected: category.id == categoryId,
                ),
              if (categoryId != null && selectedCategoryName == null)
                DesignSystemDropdownItem(
                  id: categoryId!,
                  label: categoryId!,
                  selected: true,
                ),
            ],
            onItemPressed: (item) =>
                onCategoryChanged(item.id.isEmpty ? null : item.id),
          ),
          SizedBox(height: tokens.spacing.step3),
          DsSegmentedToggle<GoalDirection>(
            key: ValueKey('goal-form-label-time-direction-$labelId'),
            segments: [
              DsSegment(
                GoalDirection.atLeast,
                context.messages.goalFormDirectionAtLeast,
              ),
              DsSegment(
                GoalDirection.atMost,
                context.messages.goalFormDirectionAtMost,
              ),
            ],
            selected: direction,
            onChanged: onDirectionChanged,
            expand: true,
          ),
          SizedBox(height: tokens.spacing.step3),
          _LabelTimeTargetInput(
            labelId: labelId,
            value: value,
            errorText: errorText,
            anchorKey: anchorKey,
            onChanged: onTargetChanged,
          ),
        ],
      ),
    );
  }
}

class _LabelTimeTargetInput extends StatefulWidget {
  const _LabelTimeTargetInput({
    required this.labelId,
    required this.value,
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String labelId;
  final num? value;
  final String? errorText;
  final Key anchorKey;
  final ValueChanged<num?> onChanged;

  @override
  State<_LabelTimeTargetInput> createState() => _LabelTimeTargetInputState();
}

class _LabelTimeTargetInputState extends State<_LabelTimeTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.anchorKey,
    child: DesignSystemTextInput(
      key: ValueKey('goal-form-label-time-target-${widget.labelId}'),
      controller: _controller,
      label: context.messages.goalFormLabelTimeTarget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      errorText: widget.errorText,
      onChanged: (raw) => widget.onChanged(
        num.tryParse(raw.trim().replaceAll(',', '.')),
      ),
    ),
  );
}
