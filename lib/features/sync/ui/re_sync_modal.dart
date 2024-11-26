import 'package:flutter/material.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ReSyncModalContent extends StatefulWidget {
  const ReSyncModalContent({super.key});

  @override
  State<ReSyncModalContent> createState() => _ReSyncModalContentState();
}

class _ReSyncModalContentState extends State<ReSyncModalContent> {
  final _maintenanceService = getIt<Maintenance>();

  DateTime? _dateFrom;
  DateTime? _dateTo;

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
                    _maintenanceService.reSyncInterval(
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
  static SliverWoltModalSheetPage page1(
    BuildContext modalSheetContext,
    TextTheme textTheme,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        'Re-sync entries',
        style: textTheme.titleSmall,
      ),
      isTopBarLayerAlwaysVisible: true,
      trailingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
        icon: const Icon(Icons.close),
        onPressed: Navigator.of(modalSheetContext).pop,
      ),
      child: const ReSyncModalContent(),
    );
  }

  static Future<void> show(BuildContext context) async {
    await WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          page1(modalSheetContext, context.textTheme),
        ];
      },
      modalTypeBuilder: (context) {
        final size = MediaQuery.of(context).size.width;
        if (size < WoltModalConfig.pageBreakpoint) {
          return WoltModalType.bottomSheet();
        } else {
          return WoltModalType.dialog();
        }
      },
      barrierDismissible: true,
    );
  }
}
