import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Create handler for the filter modal. Receives the trimmed name and the
/// route-scoped draft currently visible in the flow.
typedef DesignSystemFilterCreateHandler =
    FutureOr<void> Function(String name, DesignSystemTaskFilterState state);

/// Update handler for an existing saved filter. Naming is intentionally absent:
/// renaming belongs to the saved-filter manager, not the filter composer.
typedef DesignSystemFilterUpdateHandler =
    FutureOr<void> Function(DesignSystemTaskFilterState state);

/// Decides whether the current route-scoped draft supports a save operation.
typedef DesignSystemFilterSavePredicate =
    bool Function(DesignSystemTaskFilterState state);

/// Stable keys for the same-modal saved-filter flow.
@visibleForTesting
abstract final class DesignSystemFilterSavePageKeys {
  static const Key choicePage = ValueKey('design-system-filter-save-choice');
  static const Key existingName = ValueKey(
    'design-system-filter-save-existing-name',
  );
  static const Key update = ValueKey('design-system-filter-save-update');
  static const Key saveAsNew = ValueKey(
    'design-system-filter-save-as-new',
  );
  static const Key namePage = ValueKey('design-system-filter-save-name-page');
  static const Key nameField = ValueKey(
    'design-system-filter-save-name-field',
  );
  static const Key cancel = ValueKey('design-system-filter-save-cancel');
  static const Key commit = ValueKey('design-system-filter-save-commit');
  static const Key error = ValueKey('design-system-filter-save-error');
}

/// Loads fresher option data after the modal has opened from its synchronous
/// snapshot. The current draft is supplied so refreshed catalogs can preserve
/// edits already made while the load was in flight.
typedef DesignSystemFilterStateRefresh =
    Future<DesignSystemTaskFilterState> Function(
      DesignSystemTaskFilterState current,
    );

/// Shows an adaptive, multi-page filter flow in one Wolt route.
///
/// Every available status/category/label/project field becomes a prebuilt
/// child page. The root and child pages edit one [ValueNotifier] draft, so
/// navigation never stacks a second barrier or flashes while initializing a
/// page. Closing discards the draft; Apply commits once and closes.
Future<void> showDesignSystemFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  Map<DesignSystemTaskFilterSection, DesignSystemFilterFieldPageConfig>
      fieldPageConfigs =
      const {},
  Widget Function(Widget)? modalDecorator,
  DesignSystemFilterCreateHandler? onCreateSavedFilter,
  DesignSystemFilterUpdateHandler? onUpdateSavedFilter,
  DesignSystemFilterSavePredicate? canCreateSavedFilter,
  DesignSystemFilterSavePredicate? canUpdateSavedFilter,
  String? existingSavedFilterName,
  DesignSystemFilterStateRefresh? refreshInitialState,
}) async {
  assert(
    existingSavedFilterName == null || onUpdateSavedFilter != null,
    'An existing saved filter requires an update handler.',
  );
  final stateNotifier = ValueNotifier(initialState);
  final pageIndexNotifier = ValueNotifier(0);
  var acceptsRefresh = true;
  final sections = [
    for (final section in DesignSystemTaskFilterSection.values)
      if (initialState.fieldFor(section) != null) section,
  ];
  final pageIndexForSection = {
    for (final (index, section) in sections.indexed) section: index + 1,
  };
  final hasSaveFlow = onCreateSavedFilter != null;
  final hasUpdateChoice =
      existingSavedFilterName != null && onUpdateSavedFilter != null;
  final saveChoicePageIndex = hasUpdateChoice ? sections.length + 1 : null;
  final saveNamePageIndex = hasSaveFlow
      ? sections.length + 1 + (hasUpdateChoice ? 1 : 0)
      : null;
  final fieldFocusNodes = {
    for (final section in sections)
      section: FocusNode(debugLabel: 'filter-${section.name}'),
  };

  void returnToOverview([DesignSystemTaskFilterSection? section]) {
    final previousPage = pageIndexNotifier.value;
    final sectionToRestore =
        section ??
        (previousPage > 0 && previousPage <= sections.length
            ? sections[previousPage - 1]
            : null);
    pageIndexNotifier.value = 0;
    if (sectionToRestore == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusNode = fieldFocusNodes[sectionToRestore];
      if (focusNode?.canRequestFocus ?? false) {
        focusNode!.requestFocus();
      }
    });
  }

  void returnFromSaveName() {
    pageIndexNotifier.value = saveChoicePageIndex ?? 0;
  }

  void navigateBack() {
    if (pageIndexNotifier.value == saveNamePageIndex &&
        saveChoicePageIndex != null) {
      returnFromSaveName();
      return;
    }
    returnToOverview();
  }

  void openSaveFlow() {
    pageIndexNotifier.value = saveChoicePageIndex ?? saveNamePageIndex!;
  }

  Widget decorateFlow(Widget child) {
    final backAware = _FilterFlowBackHandler(
      pageIndexNotifier: pageIndexNotifier,
      onNavigateBack: navigateBack,
      child: child,
    );
    return _FilterFlowLifetime(
      stateNotifier: stateNotifier,
      pageIndexNotifier: pageIndexNotifier,
      fieldFocusNodes: fieldFocusNodes.values.toList(growable: false),
      child: modalDecorator?.call(backAware) ?? backAware,
    );
  }

  if (refreshInitialState != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!acceptsRefresh) return;
      unawaited(
        refreshInitialState(stateNotifier.value).then((refreshedState) {
          if (acceptsRefresh) {
            stateNotifier.value = refreshedState;
          }
        }),
      );
    });
  }

  await ModalUtils.showMultiPageModal<void>(
    context: context,
    pageIndexNotifier: pageIndexNotifier,
    modalDecorator: decorateFlow,
    pageListBuilder: (modalContext) {
      final modalNavigator = Navigator.of(modalContext);
      final spacing = modalContext.designTokens.spacing;
      final pagePadding = EdgeInsets.fromLTRB(
        spacing.step5,
        spacing.step2,
        spacing.step5,
        spacing.step5,
      );
      final selectionPagePadding = EdgeInsets.fromLTRB(
        0,
        spacing.step2,
        0,
        spacing.step5,
      );
      final isBottomSheet = ModalUtils.shouldUseRootNavigatorForBottomSheet(
        modalContext,
      );
      final hasLargeText = MediaQuery.textScalerOf(modalContext).scale(1) > 1.3;
      final overviewFooterClearance = isBottomSheet
          ? hasLargeText
                ? spacing.step13 + spacing.step12
                : spacing.step13
          : spacing.step12;

      return [
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: initialState.title,
          showCloseButton: true,
          padding: pagePadding,
          stickyActionBar: ValueListenableBuilder(
            valueListenable: stateNotifier,
            builder: (context, state, _) {
              return DesignSystemTaskFilterActionBar(
                state: state,
                onChanged: (next) => stateNotifier.value = next,
                onApplyPressed: (next) {
                  onApplied(next);
                  Navigator.of(context).pop();
                },
                onClearAllPressed: (next) => stateNotifier.value = next,
                onSavePressed: hasSaveFlow ? openSaveFlow : null,
                canSave:
                    hasSaveFlow &&
                    ((canCreateSavedFilter?.call(state) ?? true) ||
                        (hasUpdateChoice &&
                            (canUpdateSavedFilter?.call(state) ?? true))),
              );
            },
          ),
          child: ValueListenableBuilder(
            valueListenable: stateNotifier,
            builder: (context, state, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DesignSystemTaskFilterSheet(
                    state: state,
                    fieldFocusNodes: fieldFocusNodes,
                    onChanged: (next) => stateNotifier.value = next,
                    onFieldPressed: (section) {
                      final nextPage = pageIndexForSection[section];
                      if (nextPage != null) {
                        pageIndexNotifier.value = nextPage;
                      }
                    },
                  ),
                  SizedBox(height: overviewFooterClearance),
                ],
              );
            },
          ),
        ),
        for (final section in sections)
          ModalUtils.modalSheetPage(
            context: modalContext,
            title: initialState.fieldFor(section)!.label,
            showCloseButton: true,
            onTapBack: () => returnToOverview(section),
            padding: selectionPagePadding,
            stickyActionBar: _SelectionPageActionBar(
              onDone: () => returnToOverview(section),
            ),
            child: DesignSystemFilterSelectionPage(
              stateNotifier: stateNotifier,
              section: section,
              config:
                  fieldPageConfigs[section] ??
                  const DesignSystemFilterFieldPageConfig(),
            ),
          ),
        if (hasUpdateChoice)
          ModalUtils.modalSheetPage(
            context: modalContext,
            title: modalContext.messages.tasksSavedFiltersSaveChoiceTitle,
            showCloseButton: true,
            onTapBack: returnToOverview,
            padding: pagePadding,
            child: ValueListenableBuilder(
              valueListenable: stateNotifier,
              builder: (context, state, _) {
                return _SaveFilterChoicePage(
                  existingName: existingSavedFilterName,
                  canUpdate: canUpdateSavedFilter?.call(state) ?? true,
                  canSaveAsNew: canCreateSavedFilter?.call(state) ?? true,
                  onUpdate: () => _handleUpdatePressed(
                    modalNavigator,
                    stateNotifier: stateNotifier,
                    onApplied: onApplied,
                    onUpdateSavedFilter: onUpdateSavedFilter,
                  ),
                  onSaveAsNew: () {
                    pageIndexNotifier.value = saveNamePageIndex!;
                  },
                );
              },
            ),
          ),
        if (hasSaveFlow)
          ModalUtils.modalSheetPage(
            context: modalContext,
            title: modalContext.messages.tasksSavedFiltersSavePopupTitle,
            showCloseButton: true,
            onTapBack: returnFromSaveName,
            padding: pagePadding,
            child: _SaveFilterNamePage(
              onCancel: returnFromSaveName,
              onCommit: (name) => _handleCreatePressed(
                modalNavigator,
                name: name,
                stateNotifier: stateNotifier,
                onApplied: onApplied,
                onCreateSavedFilter: onCreateSavedFilter,
              ),
            ),
          ),
      ];
    },
  );
  acceptsRefresh = false;
}

class _SaveFilterChoicePage extends StatefulWidget {
  const _SaveFilterChoicePage({
    required this.existingName,
    required this.canUpdate,
    required this.canSaveAsNew,
    required this.onUpdate,
    required this.onSaveAsNew,
  });

  final String existingName;
  final bool canUpdate;
  final bool canSaveAsNew;
  final Future<void> Function() onUpdate;
  final VoidCallback onSaveAsNew;

  @override
  State<_SaveFilterChoicePage> createState() => _SaveFilterChoicePageState();
}

class _SaveFilterChoicePageState extends State<_SaveFilterChoicePage> {
  bool _updating = false;
  bool _hasError = false;

  Future<void> _update() async {
    if (_updating || !widget.canUpdate) return;
    setState(() {
      _updating = true;
      _hasError = false;
    });
    try {
      await widget.onUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      key: DesignSystemFilterSavePageKeys.choicePage,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.tasksSavedFiltersSaveChoiceIntro,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.surface.enabled,
            borderRadius: BorderRadius.circular(tokens.radii.m),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_rounded,
                  size: tokens.spacing.step5,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    widget.existingName,
                    key: DesignSystemFilterSavePageKeys.existingName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.tasksSavedFiltersUpdateExistingTitle,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.tasksSavedFiltersUpdateExistingDescription,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        DesignSystemButton(
          key: DesignSystemFilterSavePageKeys.update,
          label: messages.tasksSavedFiltersUpdateButtonLabel,
          leadingIcon: Icons.update_rounded,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          isLoading: _updating,
          onPressed: widget.canUpdate ? () => unawaited(_update()) : null,
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        Text(
          messages.tasksSavedFiltersSaveAsNewTitle,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.tasksSavedFiltersSaveAsNewDescription,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        DesignSystemButton(
          key: DesignSystemFilterSavePageKeys.saveAsNew,
          label: messages.tasksSavedFiltersSaveAsNewButtonLabel,
          leadingIcon: Icons.add_rounded,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: widget.canSaveAsNew && !_updating
              ? widget.onSaveAsNew
              : null,
        ),
        if (_hasError) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            messages.tasksSavedFiltersSaveError,
            key: DesignSystemFilterSavePageKeys.error,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _SaveFilterNamePage extends StatefulWidget {
  const _SaveFilterNamePage({
    required this.onCancel,
    required this.onCommit,
  });

  final VoidCallback onCancel;
  final Future<void> Function(String name) onCommit;

  @override
  State<_SaveFilterNamePage> createState() => _SaveFilterNamePageState();
}

class _SaveFilterNamePageState extends State<_SaveFilterNamePage> {
  final TextEditingController _controller = TextEditingController();
  bool _canSave = false;
  bool _saving = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNameChanged(String value) {
    final canSave = value.trim().isNotEmpty;
    if (canSave == _canSave && !_hasError) return;
    setState(() {
      _canSave = canSave;
      _hasError = false;
    });
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _hasError = false;
    });
    try {
      await widget.onCommit(name);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      key: DesignSystemFilterSavePageKeys.namePage,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.tasksSavedFiltersSavePageHelper,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextInput(
          key: DesignSystemFilterSavePageKeys.nameField,
          controller: _controller,
          label: messages.tasksSavedFiltersFilterNameLabel,
          hintText: messages.tasksSavedFiltersSavePopupHint,
          errorText: _hasError ? messages.tasksSavedFiltersSaveError : null,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _handleNameChanged,
          onSubmitted: (_) => unawaited(_submit()),
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              key: DesignSystemFilterSavePageKeys.cancel,
              label: messages.tasksSavedFiltersSavePopupCancel,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              onPressed: _saving ? null : widget.onCancel,
            ),
          ],
          primary: DesignSystemButton(
            key: DesignSystemFilterSavePageKeys.commit,
            label: messages.tasksSavedFiltersSavePopupSave,
            leadingIcon: Icons.bookmark_add_rounded,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            isLoading: _saving,
            onPressed: _canSave ? () => unawaited(_submit()) : null,
          ),
        ),
      ],
    );
  }
}

/// Owns the route-scoped notifiers until Wolt's exit animation has actually
/// removed the route subtree. The modal future can complete as soon as pop is
/// requested, which is too early to dispose listenables still used by fading
/// pages and sticky action bars.
class _FilterFlowLifetime extends StatefulWidget {
  const _FilterFlowLifetime({
    required this.stateNotifier,
    required this.pageIndexNotifier,
    required this.fieldFocusNodes,
    required this.child,
  });

  final ValueNotifier<DesignSystemTaskFilterState> stateNotifier;
  final ValueNotifier<int> pageIndexNotifier;
  final List<FocusNode> fieldFocusNodes;
  final Widget child;

  @override
  State<_FilterFlowLifetime> createState() => _FilterFlowLifetimeState();
}

class _FilterFlowLifetimeState extends State<_FilterFlowLifetime> {
  @override
  void dispose() {
    widget.stateNotifier.dispose();
    widget.pageIndexNotifier.dispose();
    for (final focusNode in widget.fieldFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SelectionPageActionBar extends StatelessWidget {
  const _SelectionPageActionBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(spacing.step5),
      primary: DesignSystemButton(
        key: const ValueKey('design-system-filter-selection-apply'),
        label: context.messages.doneButton,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}

class _FilterFlowBackHandler extends StatelessWidget {
  const _FilterFlowBackHandler({
    required this.pageIndexNotifier,
    required this.onNavigateBack,
    required this.child,
  });

  final ValueNotifier<int> pageIndexNotifier;
  final VoidCallback onNavigateBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pageIndexNotifier,
      child: child,
      builder: (context, pageIndex, child) {
        final body = PopScope<void>(
          canPop: pageIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && pageIndexNotifier.value != 0) {
              onNavigateBack();
            }
          },
          child: child!,
        );
        if (pageIndex == 0) return body;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): onNavigateBack,
          },
          child: Focus(autofocus: true, child: body),
        );
      },
    );
  }
}

Future<void> _handleCreatePressed(
  NavigatorState modalNavigator, {
  required String name,
  required ValueNotifier<DesignSystemTaskFilterState> stateNotifier,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required DesignSystemFilterCreateHandler onCreateSavedFilter,
}) async {
  final draft = stateNotifier.value;
  await onCreateSavedFilter(name, draft);
  if (!modalNavigator.mounted) return;
  onApplied(draft);
  modalNavigator.pop();
}

Future<void> _handleUpdatePressed(
  NavigatorState modalNavigator, {
  required ValueNotifier<DesignSystemTaskFilterState> stateNotifier,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required DesignSystemFilterUpdateHandler onUpdateSavedFilter,
}) async {
  final draft = stateNotifier.value;
  await onUpdateSavedFilter(draft);
  if (!modalNavigator.mounted) return;
  onApplied(draft);
  modalNavigator.pop();
}
