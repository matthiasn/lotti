import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The flag-gated People tab (`enable_relationships`): the list of tracked
/// relationships and the per-person detail with its check-in log.
class RelationshipsLocation extends BeamLocation<BeamState> {
  RelationshipsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/people',
    '/people/:relationshipId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final relationshipId = state.pathParameters['relationshipId'];
    final messages = context.messages;
    return [
      BeamPage(
        key: const ValueKey('people'),
        title: messages.relationshipsPageTitle,
        child: const RelationshipsPage(),
      ),
      if (relationshipId != null)
        BeamPage(
          key: ValueKey('people-details-$relationshipId'),
          title: messages.relationshipsPageTitle,
          child: RelationshipDetailsPage(relationshipId: relationshipId),
        ),
    ];
  }
}
