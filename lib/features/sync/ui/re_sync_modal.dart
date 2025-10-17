import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = now.subtract(const Duration(hours: 24));
    _dateTo = now;
  }

  @override
  Widget build(BuildContext context) {
    final dateFrom = _dateFrom;
    final dateTo = _dateTo;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
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
          RoundedButton(
            'Start',
            onPressed: dateFrom != null && dateTo != null
                ? () {
                    ref.read(maintenanceProvider).reSyncInterval(
                          start: dateFrom,
                          end: dateTo,
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
