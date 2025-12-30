import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';

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
    final state = ref.watch(habitsControllerProvider);
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Theme(
            data: Theme.of(context).copyWith(),
            child: SearchBar(
              elevation: WidgetStateProperty.all(5),
              controller: _controller,
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                Visibility(
                  visible: state.searchString.isNotEmpty,
                  child: GestureDetector(
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.close_rounded),
                    ),
                    onTap: () {
                      habitsController.setSearchString('');
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                  ),
                ),
              ],
              onChanged: habitsController.setSearchString,
            ),
          ),
        ),
      ),
    );
  }
}
