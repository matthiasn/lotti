import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';

/// Search bar for filtering the habits list by name/description.
///
/// Two-way binds a [TextEditingController] to the controller's search string
/// (via [HabitsController.setSearchString]): typing pushes the query into
/// state, and an external change to the state string (e.g. a clear
/// triggered elsewhere) is mirrored back into the field with the cursor moved
/// to the end. Seeds the field with the current search string on init so the
/// query survives toggling the bar closed and open.
class HabitsSearchWidget extends ConsumerStatefulWidget {
  const HabitsSearchWidget({this.padding, super.key});

  /// Outer padding. Defaults to a comfortable inset when the bar stands on its
  /// own; pass [EdgeInsets.zero] to drop it inline into the header row.
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<HabitsSearchWidget> createState() => _HabitsSearchWidgetState();
}

class _HabitsSearchWidgetState extends ConsumerState<HabitsSearchWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialSearch = ref.read(habitsControllerProvider).searchString;
    _controller = TextEditingController(text: initialSearch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habitsController = ref.read(habitsControllerProvider.notifier);

    // Sync controller text with state when state changes externally
    // (e.g., clear button pressed elsewhere)
    ref.listen<String>(
      habitsControllerProvider.select((s) => s.searchString),
      (previous, next) {
        if (_controller.text != next) {
          _controller.text = next;
          // Move cursor to end when syncing
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: next.length),
          );
        }
      },
    );

    return Padding(
      padding:
          widget.padding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: LottiSearchBar(
        controller: _controller,
        hintText: context.messages.searchHint,
        onChanged: habitsController.setSearchString,
        onClear: () {
          habitsController.setSearchString('');
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
