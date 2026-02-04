import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';

class HabitsSearchWidget extends ConsumerStatefulWidget {
  const HabitsSearchWidget({super.key});

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
