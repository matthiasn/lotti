import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemDropdownWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Dropdowns',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _DropdownOverviewPage(),
      ),
    ],
  );
}

class _DropdownOverviewPage extends StatelessWidget {
  const _DropdownOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 24,
        runSpacing: 32,
        children: [
          _DropdownPreviewColumn(
            title: context.messages.designSystemDropdownComboboxTitle,
            child: const _ComboboxPreview(),
          ),
          _DropdownPreviewColumn(
            title: context.messages.designSystemDropdownListTitle,
            child: const _DropdownListPreview(),
          ),
          _DropdownPreviewColumn(
            title: context.messages.designSystemDropdownMultiselectTitle,
            child: const _DropdownMultiselectPreview(),
          ),
        ],
      ),
    );
  }
}

class _DropdownPreviewColumn extends StatelessWidget {
  const _DropdownPreviewColumn({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ComboboxPreview extends StatefulWidget {
  const _ComboboxPreview();

  @override
  State<_ComboboxPreview> createState() => _ComboboxPreviewState();
}

class _ComboboxPreviewState extends State<_ComboboxPreview> {
  var _inputLabel = '';

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: _inputLabel.isEmpty
          ? messages.designSystemDropdownInputLabel
          : _inputLabel,
      items: [
        for (final index in List<int>.generate(7, (index) => index))
          DesignSystemDropdownItem(
            id: 'combobox-$index',
            label: messages.designSystemDropdownOptionLabel,
          ),
      ],
      onItemPressed: (item) {
        setState(() => _inputLabel = item.label);
      },
    );
  }
}

class _DropdownListPreview extends StatefulWidget {
  const _DropdownListPreview();

  @override
  State<_DropdownListPreview> createState() => _DropdownListPreviewState();
}

class _DropdownListPreviewState extends State<_DropdownListPreview> {
  String? _inputLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inputLabel ??= context.messages.designSystemDropdownInputLabel;
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: _inputLabel!,
      initiallyExpanded: true,
      items: [
        for (final index in List<int>.generate(7, (index) => index))
          DesignSystemDropdownItem(
            id: 'dropdown-$index',
            label: messages.designSystemDropdownOptionLabel,
          ),
      ],
      onItemPressed: (item) {
        setState(() => _inputLabel = item.label);
      },
    );
  }
}

class _DropdownMultiselectPreview extends StatefulWidget {
  const _DropdownMultiselectPreview();

  @override
  State<_DropdownMultiselectPreview> createState() =>
      _DropdownMultiselectPreviewState();
}

class _DropdownMultiselectPreviewState extends State<_DropdownMultiselectPreview> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {'multiselect-1', 'multiselect-2'};
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final items = [
      for (final index in List<int>.generate(7, (index) => index))
        DesignSystemDropdownItem(
          id: 'multiselect-$index',
          label: messages.designSystemDropdownOptionLabel,
          chipLabel: messages.designSystemDropdownChipLabel,
          selected: _selectedIds.contains('multiselect-$index'),
        ),
    ];

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: messages.designSystemDropdownInputLabel,
      type: DesignSystemDropdownType.multiselect,
      initiallyExpanded: true,
      items: items,
      onItemPressed: (item) {
        setState(() {
          if (_selectedIds.contains(item.id)) {
            _selectedIds.remove(item.id);
          } else {
            _selectedIds.add(item.id);
          }
        });
      },
      onChipRemoved: (item) {
        setState(() => _selectedIds.remove(item.id));
      },
    );
  }
}
