import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../themes/theme.dart';

class CheckboxItemsList extends StatefulWidget {
  const CheckboxItemsList({
    required this.itemIds,
    super.key,
  });

  final List<String> itemIds;

  @override
  State<CheckboxItemsList> createState() => _CheckboxItemsListState();
}

class _CheckboxItemsListState extends State<CheckboxItemsList> {
  final _controller = TextEditingController();
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Checklist'),
      subtitle: const LinearProgressIndicator(
        value: 0.87,
        semanticsLabel: 'Checklist progress',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: TextField(
            controller: _controller,
            onChanged: (value) {
              setState(() {
                _isEditing = value.isNotEmpty;
              });
            },
            decoration: inputDecoration(
              labelText: context.messages.checklistAddItem,
              semanticsLabel: 'Add item to checklist',
              themeData: Theme.of(context),
            ).copyWith(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              suffixIcon: AnimatedOpacity(
                curve: Curves.easeInOutQuint,
                opacity: _isEditing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, size: 30),
                      onPressed: () {
                        debugPrint('Add item to checklist');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, size: 30),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _isEditing = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            showCursor: true,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              debugPrint('Submitted: $value');
            },
          ),
        ),
        ...widget.itemIds.map(CheckboxItemWrapper.new),
      ],
    );
  }
}
