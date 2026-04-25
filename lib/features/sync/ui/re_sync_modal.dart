import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ReSyncModalContent extends ConsumerStatefulWidget {
  const ReSyncModalContent({super.key});

  @override
  ConsumerState<ReSyncModalContent> createState() => _ReSyncModalContentState();
}

class _ReSyncModalContentState extends ConsumerState<ReSyncModalContent> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _includeJournalEntities = true;
  bool _includeAgentEntities = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = now.subtract(const Duration(hours: 24));
    _dateTo = now;
  }

  bool get _canStart =>
      _dateFrom != null &&
      _dateTo != null &&
      (_includeJournalEntities || _includeAgentEntities);

  @override
  Widget build(BuildContext context) {
    final dateFrom = _dateFrom;
    final dateTo = _dateTo;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateTimeField(
            dateTime: _dateFrom,
            labelText: context.messages.settingsHealthImportFromDate,
            setDateTime: (DateTime value) {
              setState(() {
                _dateFrom = value;
              });
            },
          ),
          const SizedBox(height: 20),
          DateTimeField(
            dateTime: _dateTo,
            labelText: context.messages.settingsHealthImportToDate,
            setDateTime: (DateTime value) {
              setState(() {
                _dateTo = value;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            context.messages.maintenanceReSyncEntityTypes,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          CheckboxListTile(
            key: const Key('reSyncJournalEntitiesCheckbox'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(context.messages.maintenanceReSyncJournalEntities),
            value: _includeJournalEntities,
            onChanged: (value) {
              setState(() {
                _includeJournalEntities = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            key: const Key('reSyncAgentEntitiesCheckbox'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(context.messages.maintenanceReSyncAgentEntities),
            value: _includeAgentEntities,
            onChanged: (value) {
              setState(() {
                _includeAgentEntities = value ?? false;
              });
            },
          ),
          if (!_includeJournalEntities && !_includeAgentEntities)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                context.messages.maintenanceReSyncSelectAtLeastOne,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 20),
          RoundedButton(
            'Start',
            onPressed: _canStart && dateFrom != null && dateTo != null
                ? () {
                    ref
                        .read(maintenanceProvider)
                        .reSyncInterval(
                          start: dateFrom,
                          end: dateTo,
                          agentRepository: ref.read(agentRepositoryProvider),
                          includeJournalEntities: _includeJournalEntities,
                          includeAgentEntities: _includeAgentEntities,
                        );
                    Navigator.of(context).pop();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class ReSyncModal {
  static Future<void> show(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: 'Re-sync entries',
      builder: (_) => const ReSyncModalContent(),
    );
  }
}
