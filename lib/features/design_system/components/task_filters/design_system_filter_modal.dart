import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Save handler for the filter modal. Receives the trimmed name and the
/// route-scoped draft currently visible in the flow.
typedef DesignSystemFilterSaveHandler =
    FutureOr<void> Function(String name, DesignSystemTaskFilterState state);

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
  DesignSystemFilterSaveHandler? onSavePressed,
  bool canSave = false,
  String? initialSaveName,
  DesignSystemFilterStateRefresh? refreshInitialState,
}) async {
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

  Widget decorateFlow(Widget child) {
    final backAware = _FilterFlowBackHandler(
      pageIndexNotifier: pageIndexNotifier,
      onReturnToRoot: returnToOverview,
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
                onSavePressed: onSavePressed == null
                    ? null
                    : (name) {
                        unawaited(
                          _handleSavePressed(
                            context,
                            name: name,
                            stateNotifier: stateNotifier,
                            onApplied: onApplied,
                            onSavePressed: onSavePressed,
                          ),
                        );
                      },
                canSave: canSave,
                initialSaveName: initialSaveName,
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
                  SizedBox(height: spacing.step12),
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
      ];
    },
  );
  acceptsRefresh = false;
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
    required this.onReturnToRoot,
    required this.child,
  });

  final ValueNotifier<int> pageIndexNotifier;
  final VoidCallback onReturnToRoot;
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
              onReturnToRoot();
            }
          },
          child: child!,
        );
        if (pageIndex == 0) return body;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): onReturnToRoot,
          },
          child: Focus(autofocus: true, child: body),
        );
      },
    );
  }
}

Future<void> _handleSavePressed(
  BuildContext context, {
  required String name,
  required ValueNotifier<DesignSystemTaskFilterState> stateNotifier,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required DesignSystemFilterSaveHandler onSavePressed,
}) async {
  final draft = stateNotifier.value;
  onApplied(draft);
  try {
    await onSavePressed(name, draft);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
}
