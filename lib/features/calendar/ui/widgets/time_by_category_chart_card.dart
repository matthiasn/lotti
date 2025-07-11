import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/calendar/ui/widgets/time_by_category_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TimeByCategoryChartCard extends ConsumerWidget {
  const TimeByCategoryChartCard({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    void onExpandPressed() {
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.timeByCategoryChartTitle,
        padding: ModalUtils.defaultPadding + const EdgeInsets.only(top: 20),
        builder: (BuildContext _) {
          return const TimeByCategoryChart(height: 260);
        },
      );
    }

    return GlassContainer.clearGlass(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 140,
      elevation: 0,
      borderRadius: BorderRadius.circular(15),
      color: Theme.of(context).shadowColor.withAlpha(51),
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
