import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_chat_pane.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the owning detail mounted while its discussion is open.
///
/// Two readable columns dock side by side; smaller hosts use an attached
/// draggable sheet. The detail's parent never changes. Chat is reparented with
/// its key when the window changes mode, and its scroll bucket survives Close.
/// Closing unmounts chat so a hidden composer cannot consume another chat's
/// recording result. Drafts and running requests remain controller-owned.
class QueryCompanion extends ConsumerStatefulWidget {
  const QueryCompanion({required this.scope, required this.child, super.key});

  final QueryScope scope;
  final Widget child;

  /// Reuses the existing chat and detail reading measures at the active text
  /// scale. Hosts use the same budget before deciding to hide their task list.
  static double minimumDockedWidth(BuildContext context) =>
      minimumChatWidth(context) +
      kActionListContentMaxWidth * _textScale(context) +
      context.designTokens.spacing.step2;

  static double minimumChatWidth(BuildContext context) =>
      kGoalChatDrawerWidth * _textScale(context);

  static double _textScale(BuildContext context) {
    final size =
        context.designTokens.typography.styles.body.bodySmall.fontSize!;
    return math.max(1, MediaQuery.textScalerOf(context).scale(size) / size);
  }

  @override
  ConsumerState<QueryCompanion> createState() => _QueryCompanionState();
}

class _QueryCompanionState extends ConsumerState<QueryCompanion> {
  final GlobalKey<State<StatefulWidget>> _chatKey = GlobalKey();
  final _storage = PageStorageBucket();
  final _panelFocus = FocusNode(debugLabel: 'query-companion');
  final _sheet = DraggableScrollableController();
  FocusNode? _returnFocus;
  ChatRecorderController? _recorder;
  double _preferredWidth = kGoalChatDrawerWidth;

  @override
  void dispose() {
    // Navigation away must not leave an invisible recording behind.
    if (_recorder != null) unawaited(_recorder!.cancel());
    _sheet.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final recorder = _recorder;
    _recorder = null;
    await recorder?.cancel();
    if (!mounted) return;
    ref.read(queryPaneOpenProvider(widget.scope).notifier).open = false;
    final restore = _returnFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && restore?.context != null && restore!.canRequestFocus) {
        restore.requestFocus();
      }
    });
  }

  void _toggleSheet() {
    if (!_sheet.isAttached) return;
    if (_sheet.size == 1) {
      FocusManager.instance.primaryFocus?.unfocus();
      _sheet.animateTo(
        .5,
        duration: MotionDurations.medium2,
        curve: MotionCurves.standard,
      );
    } else {
      _sheet.animateTo(
        1,
        duration: MotionDurations.medium2,
        curve: MotionCurves.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(queryPaneOpenProvider(widget.scope));
    ref.listen(queryPaneOpenProvider(widget.scope), (previous, next) {
      if (!next && previous == true) {
        final recorder = _recorder;
        _recorder = null;
        unawaited(recorder?.cancel());
      }
      if (next && previous != true) {
        _returnFocus = FocusManager.instance.primaryFocus;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(queryPaneOpenProvider(widget.scope))) {
            _panelFocus.requestFocus();
          }
        });
      }
    });
    if (open) {
      _recorder = ref.watch(chatRecorderControllerProvider.notifier);
    }
    final tokens = context.designTokens;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final docked =
            constraints.maxWidth >= QueryCompanion.minimumDockedWidth(context);
        final minimum = QueryCompanion.minimumChatWidth(context);
        final maximum = math.max(
          minimum,
          math.min(
            kUnifiedGoalsContentMaxWidth,
            constraints.maxWidth -
                (QueryCompanion.minimumDockedWidth(context) - minimum),
          ),
        );
        final width = _preferredWidth.clamp(minimum, maximum);
        Widget chat({VoidCallback? onToggleExpanded, bool expanded = false}) =>
            KeyboardFocusRegion(
              debugLabel: 'task-query-chat',
              preferredFocusNode: _panelFocus,
              child: Focus(
                focusNode: _panelFocus,
                child: QueryChatPane(
                  key: _chatKey,
                  scope: widget.scope,
                  onClose: _close,
                  companion: true,
                  storageBucket: _storage,
                  onToggleExpanded: onToggleExpanded,
                  expanded: expanded,
                ),
              ),
            );

        return ListenableBuilder(
          listenable: _sheet,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                right: open && docked ? width + tokens.spacing.step2 : 0,
                child: ExcludeFocus(
                  excluding:
                      open &&
                      !docked &&
                      (keyboardVisible ||
                          (_sheet.isAttached && _sheet.size == 1)),
                  child: ExcludeSemantics(
                    excluding:
                        open &&
                        !docked &&
                        (keyboardVisible ||
                            (_sheet.isAttached && _sheet.size == 1)),
                    child: widget.child,
                  ),
                ),
              ),
              if (open)
                Positioned.fill(
                  left: docked ? constraints.maxWidth - width : 0,
                  child: docked
                      ? chat()
                      : DraggableScrollableSheet(
                          controller: _sheet,
                          minChildSize: keyboardVisible ? 1 : .5,
                          // Start with Flutter's default half-height detent.
                          // A keyboard already occupying the page needs the
                          // full available reading area instead.
                          initialChildSize: keyboardVisible ? 1 : .5,
                          builder: (context, scrollController) => Material(
                            color: tokens.colors.background.level01,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(tokens.radii.l),
                              ),
                              side: BorderSide(
                                color: tokens.colors.decorative.level01,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CustomScrollView(
                              controller: scrollController,
                              slivers: [
                                SliverFillRemaining(
                                  child: ListenableBuilder(
                                    listenable: _sheet,
                                    builder: (context, _) => chat(
                                      onToggleExpanded: keyboardVisible
                                          ? null
                                          : _toggleSheet,
                                      expanded:
                                          _sheet.isAttached && _sheet.size == 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              if (open && docked)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: width,
                  width: tokens.spacing.step2,
                  child: ResizableDivider(
                    currentValue: width,
                    minValue: minimum,
                    maxValue: maximum,
                    reverse: true,
                    onDrag: (delta) => setState(
                      () => _preferredWidth = (width + delta).clamp(
                        minimum,
                        maximum,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
