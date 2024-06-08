import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

// ignore: avoid_positional_boolean_parameters
typedef BoolCallback = void Function(bool);

class CheckboxItemWidget extends StatefulWidget {
  const CheckboxItemWidget({
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onEdit,
    super.key,
  });

  final String title;
  final bool isChecked;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;

  @override
  State<CheckboxItemWidget> createState() => _CheckboxItemWidgetState();
}

class _CheckboxItemWidgetState extends State<CheckboxItemWidget> {
  late bool _isChecked;

  @override
  void initState() {
    _isChecked = widget.isChecked;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(widget.title),
      value: _isChecked,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: widget.onEdit != null
          ? IconButton(
              icon: const Icon(
                Icons.edit,
                size: 20,
              ),
              onPressed: widget.onEdit,
            )
          : null,
      onChanged: (bool? value) {
        setState(() {
          _isChecked = value ?? false;
        });
        widget.onChanged(_isChecked);
      },
    );
  }
}

class CheckboxItemWrapper extends ConsumerWidget {
  const CheckboxItemWrapper(
    this.itemId, {
    super.key,
  });

  final String itemId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = checklistItemControllerProvider(id: itemId);
    final item = ref.watch(provider);

    return item.map(
      data: (data) {
        final item = data.value;
        if (item == null) {
          return const SizedBox();
        }
        return CheckboxItemWidget(
          title: item.data.title,
          isChecked: item.data.isChecked,
          onChanged: (checked) => ref.read(provider.notifier).toggleChecked(),
        );
      },
      error: ErrorWidget.new,
      loading: (_) => const CircularProgressIndicator(),
    );
  }
}

class CheckboxItemsList extends StatelessWidget {
  const CheckboxItemsList({
    required this.itemIds,
    super.key,
  });

  final List<String> itemIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: itemIds.map(CheckboxItemWrapper.new).toList(),
    );
  }
}
