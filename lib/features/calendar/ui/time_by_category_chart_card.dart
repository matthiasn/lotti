import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/calendar/ui/time_by_category_chart.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class TimeByCategoryChartCard extends StatelessWidget {
  const TimeByCategoryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    void onExpandPressed() {
      WoltModalSheet.show<void>(
        context: context,
        pageListBuilder: (modalSheetContext) {
          final textTheme = Theme.of(context).textTheme;
          return [
            WoltModalSheetPage(
              hasSabGradient: false,
              topBarTitle: Text(
                'Time by Category',
                style: textTheme.titleMedium,
              ),
              isTopBarLayerAlwaysVisible: true,
              trailingNavBarWidget: IconButton(
                padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
                icon: const Icon(Icons.close),
                onPressed: Navigator.of(modalSheetContext).pop,
              ),
              child: const Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  right: 20,
                ),
                child: TimeByCategoryChart(height: 260),
              ),
            ),
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
        onModalDismissedWithBarrierTap: Navigator.of(context).pop,
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
