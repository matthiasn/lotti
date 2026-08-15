import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';

/// The unified Goals tab (flag: `enable_unified_goals`): goals at the top
/// level with their habits inside. Phase 1 carries only the list root;
/// goal detail keeps living under `/agents/details/:id` until the surfaces
/// merge fully.
class GoalsLocation extends BeamLocation<BeamState> {
  GoalsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/goals',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      const BeamPage(
        key: ValueKey('goals'),
        title: 'Goals',
        child: UnifiedGoalsPage(),
      ),
    ];
  }
}
