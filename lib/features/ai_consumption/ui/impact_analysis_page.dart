import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_body.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';

/// Full-screen AI Impact dashboard, routed at `/calendar/impact` — the same
/// push pattern as the Time Analysis page it sits beside in the sidebar.
///
/// Thin route host around [ImpactAnalysisBody]; the Settings `ai-usage` panel
/// embeds the body directly, so all dashboard behavior lives there.
class ImpactAnalysisPage extends StatelessWidget {
  const ImpactAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: insightsPageSurface(context),
      body: const SafeArea(child: ImpactAnalysisBody()),
    );
  }
}
