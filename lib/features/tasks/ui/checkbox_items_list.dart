import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../themes/theme.dart';

class CheckboxItemsList extends StatelessWidget {
  const CheckboxItemsList({
    required this.itemIds,
    super.key,
  });

  final List<String> itemIds;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Checklist'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: TextField(
            decoration: inputDecoration(
              labelText: context.messages.checklistAddItem,
              semanticsLabel: 'Add item to checklist',
              themeData: Theme.of(context),
            ),
          ),
        ),
        ...itemIds.map(CheckboxItemWrapper.new),
      ],
    );
  }
}
