import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/calendar/ui/time_by_category_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class TimeByCategoryChartCard extends ConsumerWidget {
  const TimeByCategoryChartCard({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    void onExpandPressed() {
      WoltModalSheet.show<void>(
        context: context,
        pageListBuilder: (modalSheetContext) {
          return [
            NonScrollingWoltModalSheetPage(
              topBarTitle: Text(
                context.messages.timeByCategoryChartTitle,
                style: context.textTheme.titleMedium,
              ),
              hasTopBarLayer: true,
              trailingNavBarWidget: IconButton(
                padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
                icon: const Icon(Icons.close),
                onPressed: Navigator.of(modalSheetContext).pop,
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: TimeByCategoryChart(height: 260),
              ),
            ),
          ];
        },
        modalTypeBuilder: (_) => WoltModalType.dialog(),
        barrierDismissible: true,
      );
    }

    return GlassContainer.clearGlass(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 140,
      elevation: 0,
      borderRadius: BorderRadius.circular(15),
      color: Theme.of(context).shadowColor.withOpacity(0.2),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: TimeByCategoryChart(
              showLegend: false,
              showTimeframeSelector: false,
              height: 120,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              onPressed: onExpandPressed,
              icon: Icon(
                Icons.expand,
                size: 16,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
