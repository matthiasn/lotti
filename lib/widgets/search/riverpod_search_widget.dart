import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/riverpod/journal_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A Riverpod-compatible version of the search widget
class RiverpodSearchWidget extends ConsumerWidget {
  const RiverpodSearchWidget({
    super.key,
    this.margin,
  });

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final filtersNotifier = ref.read(journalFiltersProvider.notifier);

    return Container(
      margin: margin,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (value) {
                filtersNotifier.update(
                  (state) => state.copyWith(searchQuery: value),
                );
              },
              controller: TextEditingController(text: filters.searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: filters.searchQuery.length),
                ),
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: context.messages.journalSearchHint,
              ),
            ),
          ),
          if (filters.searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                filtersNotifier.update(
                  (state) => state.copyWith(searchQuery: ''),
                );
              },
            ),
        ],
      ),
    );
  }
}
