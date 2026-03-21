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
    final options = _sampleDropdownOptions(context);

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: _inputLabel.isEmpty
          ? messages.designSystemDropdownInputLabel
          : _inputLabel,
      items: [
        for (final option in options)
          DesignSystemDropdownItem(
            id: option.id,
            label: option.label,
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
    final options = _sampleDropdownOptions(context);

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: _inputLabel!,
      initiallyExpanded: true,
      items: [
        for (final option in options)
          DesignSystemDropdownItem(
            id: option.id,
            label: option.label,
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

class _DropdownMultiselectPreviewState
    extends State<_DropdownMultiselectPreview> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {'design', 'analytics'};
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final options = _sampleDropdownOptions(context);
    final items = [
      for (final option in options)
        DesignSystemDropdownItem(
          id: option.id,
          label: option.label,
          selected: _selectedIds.contains(option.id),
        ),
    ];

    return DesignSystemDropdown(
      label: messages.designSystemDropdownFieldLabel,
      inputLabel: messages.designSystemDropdownMultiselectInputLabel,
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

List<_DropdownOptionData> _sampleDropdownOptions(BuildContext context) {
  final messages = context.messages;

  return [
    _DropdownOptionData(
      id: 'design',
      label: messages.designSystemDropdownOptionDesign,
    ),
    _DropdownOptionData(
      id: 'frontend',
      label: messages.designSystemDropdownOptionFrontend,
    ),
    _DropdownOptionData(
      id: 'mobile',
      label: messages.designSystemDropdownOptionMobile,
    ),
    _DropdownOptionData(
      id: 'backend',
      label: messages.designSystemDropdownOptionBackend,
    ),
    _DropdownOptionData(
      id: 'growth',
      label: messages.designSystemDropdownOptionGrowth,
    ),
    _DropdownOptionData(
      id: 'analytics',
      label: messages.designSystemDropdownOptionAnalytics,
    ),
    _DropdownOptionData(
      id: 'qa',
      label: messages.designSystemDropdownOptionQa,
    ),
  ];
}

class _DropdownOptionData {
  const _DropdownOptionData({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}
